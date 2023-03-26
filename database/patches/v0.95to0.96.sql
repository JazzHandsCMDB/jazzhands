--
-- Copyright (c) 2023 Todd Kover
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

	--suffix=v96
	--scan
	--final
	final
	--pre
	pre
	--post
	post
	--reinsert-dir=i
	layer3_interface
	component_type
	dns_record
	logical_volume
	volume_group
	volume_group_physicalish_volume:volume_group_block_storage_device
	val_physicalish_volume_type:val_block_storage_device_type
	physicalish_volume:block_storage_device
	physicalish_volume
	volume_group_physicalish_volume
	jazzhands_legacy.volume_group_physicalish_vol
	--last
	jazzhands_legacy.device_management_controller
	--last
	jazzhands_legacy.v_property
	--last
	jazzhands_legacy.v_device_coll_hier_detail
	--last
	jazzhands_legacy.v_dev_col_root
	--last
	jazzhands_legacy.v_device_col_acct_col_expanded
	--last
	jazzhands_legacy.v_acct_coll_expanded
	--last
	jazzhands_legacy.v_acct_coll_acct_expanded
	--last
	jazzhands_legacy.v_device_collection_root
	--last
	jazzhands_legacy.v_dev_col_device_root
	--last
	jazzhands_legacy.v_dev_col_user_prop_expanded
	--postschema
	property_utils
	--last
	jazzhands_legacy.v_unix_account_overrides
	--last
	jazzhands_legacy.v_device_col_acct_col_unixgroup
	--last
	jazzhands_legacy.v_device_col_acct_col_unixlogin
	--last
	jazzhands_legacy.v_device_collection_account_ssh_key
	--last
	jazzhands_legacy.v_unix_group_overrides
	--last
	jazzhands_legacy.v_device_col_account_cart
	--last
	jazzhands_legacy.v_device_col_account_col_cart
	--last
	jazzhands_legacy.v_unix_mclass_settings
	--last
	jazzhands_legacy.v_unix_passwd_mappings
	--last
	jazzhands_legacy.v_unix_group_mappings
	--last
	jazzhands_legacy.v_hotpants_account_attribute
	--last
	jazzhands_legacy.v_hotpants_client
	--last
	jazzhands_legacy.v_hotpants_dc_attribute
	--last
	jazzhands_legacy.v_hotpants_device_collection
	--last
	jazzhands_legacy.v_lv_hier
	--last
	jazzhands_legacy.v_dns_fwd
	--last
	jazzhands_legacy.v_dns_rvs
	--last
	jazzhands_legacy.v_dns
	--last
	jazzhands_legacy.v_dns_sorted
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance(false);
select clock_timestamp(), now(), clock_timestamp() - now() AS len;


-- BEGIN Misc that does not apply to above

--
-- script should dig this stuff out, but it doesn't, so here we are.
--
DROP VIEW IF EXISTS jazzhands_legacy.account_auth_log;
DROP VIEW IF EXISTS audit.account_auth_log;

DO
$$
BEGIN
	PERFORM FROM device
	WHERE component_id IS NULL AND rack_location_id IS NOT NULL;
	IF FOUND THEN
		RAISE EXCEPTION 'May not have devices with rack_location_id set and component_id is not.';
	END IF;

	PERFORM FROM device
	JOIN component USING (component_id)
	JOIN component_type USING (component_type_id)
	WHERE is_virtual_component != is_virtual_device;
	IF FOUND THEN
		RAISE EXCEPTION 'device.is_virtual_device does not match component_type.is_virtual_component on some rows';
	END IF;

	PERFORM FROM  component_type
	WHERE is_virtual_component = true AND is_rack_mountable = true;
	IF FOUND THEN
		RAISE EXCEPTION 'some virtual components are marked as rack mountable';
	END IF;

END;

$$;


-- fix duplicates that got in because of weird trigger race conditions
DELETE FROM dns_record WHERE dns_record_id IN (
	SELECT dns_record_id FROM (
		SELECT dns_record_id, netblock_id,
			row_number() over (PARTITION BY dns_domain_id, dns_type, dns_class, netblock_id ORDER BY data_ins_date, data_upd_date, dns_record_id) AS rnk
		FROM dns_record
		WHERE should_generate_ptr
		AND netblock_id IS NOT NULL
	) i WHERE rnk > 1
);

-- fix mistakes, and this is kind of arbitrary.
UPDATE dns_record SET should_generate_ptr = false
WHERE dns_record_id IN (
	SELECT dns_record_id FROM (
		SELECT dns_record_id, netblock_id,
			row_number() over (PARTITION BY netblock_id ORDER BY data_ins_date, data_upd_date, dns_record_id) AS rnk
		FROM dns_record
		WHERE should_generate_ptr
		AND netblock_id IS NOT NULL
	) i WHERE rnk > 1
);

-- new constraint to enforce this.
UPDATE device SET is_virtual_device = false
WHERE is_virtual_device = true AND rack_location_id IS NOT NULL;


-- END Misc that does not apply to above
--
-- BEGIN: process_ancillary_schema(schema_support)
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'build_audit_table');
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_table');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_table ( character varying,character varying,character varying,boolean );
CREATE OR REPLACE FUNCTION schema_support.build_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying, first_time boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('build_audit_table');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc build_audit_table failed but that is ok';
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
	msg TEXT;
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

SELECT schema_support.save_dependent_objects_for_replay(schema := 'schema_support'::text, object := 'migrate_grants ( text,text,text,text )'::text, tags := ARRAY['process_all_procs_in_schema_schema_support'::text]);
DROP FUNCTION IF EXISTS schema_support.migrate_grants ( text,text,text,text );
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'rebuild_audit_table_finish');
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_table_finish');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_table_finish ( character varying,character varying,character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table_finish(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('rebuild_audit_table_finish');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc rebuild_audit_table_finish failed but that is ok';
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
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'relation_diff');
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_diff');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_diff ( text,text,text,text,text[],boolean );
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
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('relation_diff');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc relation_diff failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.save_dependent_objects_for_replay(schema := 'schema_support'::text, object := 'reset_table_sequence ( character varying,character varying )'::text, tags := ARRAY['process_all_procs_in_schema_schema_support'::text]);
DROP FUNCTION IF EXISTS schema_support.reset_table_sequence ( character varying,character varying );
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_schema_support']);
-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION schema_support.migrate_grants(username text, direction text, old_schema text, new_schema text, name_map jsonb DEFAULT NULL::jsonb, name_map_exception boolean DEFAULT true)
 RETURNS text[]
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
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
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION schema_support.migrate_identity_to_legacy_serial(schema text, relation text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
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
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION schema_support.migrate_identity_to_legacy_serials(tbl_schema text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
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
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION schema_support.reset_table_sequence(schema character varying, table_name character varying, lowerseq boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
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
$function$
;

-- DONE: process_ancillary_schema(schema_support)
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	_tal := 0;
	SELECT count(*) INTO _tal FROM pg_extension WHERE extname = 'plperl';

	-- certain schemas are optional and the first conditional
	-- is true if the schem is optional.
	IF false OR _tal = 1 THEN
		CREATE SCHEMA jazzhands_legacy_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA jazzhands_legacy_manip IS 'part of jazzhands';
	END IF;
EXCEPTION WHEN duplicate_schema THEN
	RAISE NOTICE 'Schema exists.  Skipping creation';
END;
			$$;--
-- Process middle (non-trigger) schema jazzhands_cache
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_cache']);
--
-- Process middle (non-trigger) schema account_collection_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_collection_manip']);
--
-- Process middle (non-trigger) schema account_password_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_password_manip']);
--
-- Process middle (non-trigger) schema approval_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_approval_utils']);
--
-- Process middle (non-trigger) schema auto_ac_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_auto_ac_manip']);
--
-- Process middle (non-trigger) schema backend_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_backend_utils']);
--
-- Process middle (non-trigger) schema company_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_company_manip']);
--
-- Process middle (non-trigger) schema component_connection_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_connection_utils']);
--
-- Process middle (non-trigger) schema component_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_manip']);
--
-- Process middle (non-trigger) schema component_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_utils']);
--
-- Process middle (non-trigger) schema device_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_manip']);
--
-- Process middle (non-trigger) schema device_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_utils']);
--
-- Process middle (non-trigger) schema dns_manip
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('dns_manip', 'add_dns_domain');
SELECT schema_support.save_grants_for_replay('dns_manip', 'add_dns_domain');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS dns_manip.add_dns_domain ( character varying,character varying,integer[],boolean );
CREATE OR REPLACE FUNCTION dns_manip.add_dns_domain(dns_domain_name character varying, dns_domain_type character varying DEFAULT NULL::character varying, ip_universes integer[] DEFAULT NULL::integer[], add_nameservers boolean DEFAULT NULL::boolean)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	elements		text[];
	parent_zone		text;
	short_name		TEXT;
	parent_id		dns_domain.dns_domain_id%type;
	domain_id		dns_domain.dns_domain_id%type;
	parent_type		TEXT;
	elem			text;
	sofar			text;
	rvs_nblk_id		netblock.netblock_id%type;
	univ			ip_universe.ip_universe_id%type;
	can_haz_generate	boolean;
BEGIN
	IF dns_domain_name IS NULL THEN
		RETURN NULL;
	END IF;

	elements := regexp_split_to_array(dns_domain_name, '\.');
	sofar := '';
	FOREACH elem in ARRAY elements
	LOOP
		IF octet_length(sofar) > 0 THEN
			sofar := sofar || '.';
		END IF;
		sofar := sofar || elem;
		parent_zone := regexp_replace(dns_domain_name, '^'||sofar||'.', '');
		EXECUTE 'SELECT dns_domain_id, dns_domain_type FROM dns_domain
			WHERE dns_domain_name = $1'
			INTO parent_id, parent_type
			USING parent_zone;
		IF parent_id IS NOT NULL THEN
			EXIT;
		END IF;
	END LOOP;

	short_name := regexp_replace(dns_domain_name, concat('.', parent_zone), '');

	IF ip_universes IS NULL THEN
		SELECT array_agg(ip_universe_id)
		INTO	ip_universes
		FROM	ip_universe
		WHERE	ip_universe_name = 'default';
	END IF;

	IF dns_domain_type IS NULL THEN
		IF dns_domain_name ~ '^.*(in-addr|ip6)\.arpa$' THEN
			dns_domain_type := 'reverse';
		ELSIF parent_type IS NOT NULL THEN
			dns_domain_type := parent_type;
		ELSE
			RAISE EXCEPTION 'Unable to guess dns_domain_type for %',
				dns_domain_name USING ERRCODE = 'not_null_violation';
		END IF;
	END IF;

	SELECT dt.can_generate
	INTO can_haz_generate
	FROM val_dns_domain_type dt
	WHERE dt.dns_domain_type = add_dns_domain.dns_domain_type;

	BEGIN
		INSERT INTO dns_domain (
			dns_domain_name,
			parent_dns_domain_id,
			dns_domain_type
		) VALUES (
			add_dns_domain.dns_domain_name,
			parent_id,
			add_dns_domain.dns_domain_type
		) RETURNING dns_domain_id INTO domain_id;
	EXCEPTION WHEN unique_violation THEN
		SELECT dns_domain_id
		INTO domain_id
		FROM dns_domain d
		WHERE d.dns_domain_name = add_dns_domain.dns_domain_name;
		RETURN domain_id;
	END;

	FOREACH univ IN ARRAY ip_universes
	LOOP
		EXECUTE '
			INSERT INTO dns_domain_ip_universe (
				dns_domain_id,
				ip_universe_id,
				soa_class,
				soa_mname,
				soa_rname,
				should_generate
			) VALUES (
				$1,
				$2,
				$3,
				$4,
				$5,
				$6
			);'
			USING domain_id, univ,
				'IN',
				(select property_value from property
					where property_type = 'Defaults'
					and property_name = '_dnsmname' ORDER BY property_id LIMIT 1),
				(select property_value from property
					where property_type = 'Defaults'
					and property_name = '_dnsrname' ORDER BY property_id LIMIT 1),
				can_haz_generate
		;
	END LOOP;

	IF dns_domain_type = 'reverse' THEN
		rvs_nblk_id := dns_manip.get_or_create_inaddr_domain_netblock_link(
			dns_domain_name, domain_id);
	END IF;

	--
	-- migrate any records _in_ the parent zone over to this zone.
	--
	IF short_name IS NOT NULL AND parent_id IS NOT NULL THEN
		UPDATE  dns_record
			SET dns_name =
				CASE WHEN lower(dns_name) = lower(short_name) THEN NULL
				ELSE regexp_replace(dns_name, concat('.', short_name, '$'), '')
				END,
				dns_domain_id =  domain_id
		WHERE dns_domain_id = parent_id
		AND lower(dns_name) ~ concat('\.?', lower(short_name), '$');

		--
		-- check to see if NS servers already exist, in which case, reuse them
		--
		IF add_nameservers IS NULL THEN
			PERFORM *
			FROM dns_record
			WHERE dns_domain_id = domain_id
			AND dns_type = 'NS'
			AND dns_name IS NULL;

			IF FOUND THEN
				add_nameservers := false;
			ELSE
				add_nameservers := true;
			END IF;
		END IF;
	ELSIF add_nameservers IS NULL THEN
		add_nameservers := true;
	END IF;

	IF add_nameservers THEN
		PERFORM dns_manip.add_ns_records(domain_id);
	END IF;

	-- XXX - need to reconsider how ip universes fit into this.
	IF parent_id IS NOT NULL THEN
		INSERT INTO dns_change_record (
			dns_domain_id
		) SELECT dns_domain_id
		FROM dns_domain
		WHERE dns_domain_id = parent_id
		AND dns_domain_id IN (
			SELECT dns_domain_id
			FROM dns_domain_ip_universe
			WHERE should_generate = true
		);
	END IF;

	RETURN domain_id;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'dns_manip' AND type = 'function' AND object IN ('add_dns_domain');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc add_dns_domain failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('dns_manip', 'add_domains_from_netblock');
SELECT schema_support.save_grants_for_replay('dns_manip', 'add_domains_from_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS dns_manip.add_domains_from_netblock ( integer );
CREATE OR REPLACE FUNCTION dns_manip.add_domains_from_netblock(netblock_id integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	nid	ALIAS FOR netblock_id;
	block	inet;
	_rv	TEXT;
BEGIN
	SELECT ip_address INTO block FROM netblock n WHERE n.netblock_id = nid;

	RAISE DEBUG 'Creating inverse DNS zones for %s', block;

	SELECT jsonb_agg(jsonb_build_object(
		'dns_domain_id', dns_domain_id,
		'dns_domain_name', dns_domain_name))
	FROM (
		SELECT
			dns_manip.add_dns_domain(
				dns_domain_name := x.dns_domain_name,
				dns_domain_type := 'reverse'
				) as dns_domain_id,
			x.dns_domain_name::text
		FROM dns_utils.get_all_domain_rows_for_cidr(block) x
		LEFT JOIN dns_domain d USING (dns_domain_name)
		WHERE d.dns_domain_id IS NULL
	) i INTO _rv;

	RETURN _rv;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'dns_manip' AND type = 'function' AND object IN ('add_domains_from_netblock');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc add_domains_from_netblock failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_manip']);
--
-- Process middle (non-trigger) schema dns_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_utils']);
--
-- Process middle (non-trigger) schema jazzhands
--
DROP TRIGGER IF EXISTS trigger_upd_v_hotpants_token ON jazzhands.v_hotpants_token;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands'::text, object := 'upd_v_hotpants_token (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands'::text]);
DROP FUNCTION IF EXISTS jazzhands.upd_v_hotpants_token (  );
DROP TRIGGER IF EXISTS trigger_verify_physicalish_volume ON jazzhands.physicalish_volume;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands'::text, object := 'verify_physicalish_volume (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands'::text]);
DROP FUNCTION IF EXISTS jazzhands.verify_physicalish_volume (  );
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands']);
--
-- Process middle (non-trigger) schema layerx_network_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_layerx_network_manip']);
--
-- Process middle (non-trigger) schema logical_port_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_logical_port_manip']);
--
-- Process middle (non-trigger) schema lv_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_lv_manip']);
--
-- Process middle (non-trigger) schema net_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_net_manip']);
--
-- Process middle (non-trigger) schema netblock_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_manip']);
--
-- Process middle (non-trigger) schema netblock_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_utils']);
--
-- Process middle (non-trigger) schema network_strings
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_network_strings']);
--
-- Process middle (non-trigger) schema obfuscation_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_obfuscation_utils']);
--
-- Process middle (non-trigger) schema person_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_person_manip']);
--
-- Process middle (non-trigger) schema pgcrypto
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_pgcrypto']);
--
-- Process middle (non-trigger) schema physical_address_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_physical_address_utils']);
--
-- Process middle (non-trigger) schema port_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_port_utils']);
--
-- Process middle (non-trigger) schema rack_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_rack_utils']);
--
-- Process middle (non-trigger) schema schema_support
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'build_audit_table');
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_table');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_table ( character varying,character varying,character varying,boolean );
CREATE OR REPLACE FUNCTION schema_support.build_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying, first_time boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('build_audit_table');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc build_audit_table failed but that is ok';
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
	msg TEXT;
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

SELECT schema_support.save_dependent_objects_for_replay(schema := 'schema_support'::text, object := 'migrate_grants ( text,text,text,text )'::text, tags := ARRAY['process_all_procs_in_schema_schema_support'::text]);
DROP FUNCTION IF EXISTS schema_support.migrate_grants ( text,text,text,text );
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'rebuild_audit_table_finish');
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_table_finish');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_table_finish ( character varying,character varying,character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table_finish(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('rebuild_audit_table_finish');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc rebuild_audit_table_finish failed but that is ok';
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
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'relation_diff');
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_diff');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_diff ( text,text,text,text,text[],boolean );
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
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('relation_diff');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc relation_diff failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.save_dependent_objects_for_replay(schema := 'schema_support'::text, object := 'reset_table_sequence ( character varying,character varying )'::text, tags := ARRAY['process_all_procs_in_schema_schema_support'::text]);
DROP FUNCTION IF EXISTS schema_support.reset_table_sequence ( character varying,character varying );
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_schema_support']);
-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION schema_support.migrate_grants(username text, direction text, old_schema text, new_schema text, name_map jsonb DEFAULT NULL::jsonb, name_map_exception boolean DEFAULT true)
 RETURNS text[]
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
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
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION schema_support.migrate_identity_to_legacy_serial(schema text, relation text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
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
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION schema_support.migrate_identity_to_legacy_serials(tbl_schema text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
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
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION schema_support.reset_table_sequence(schema character varying, table_name character varying, lowerseq boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
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
$function$
;

--
-- Process middle (non-trigger) schema script_hooks
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_script_hooks']);
--
-- Process middle (non-trigger) schema service_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_service_manip']);
--
-- Process middle (non-trigger) schema service_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_service_utils']);
--
-- Process middle (non-trigger) schema snapshot_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_snapshot_manip']);
--
-- Process middle (non-trigger) schema time_util
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_time_util']);
--
-- Process middle (non-trigger) schema token_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_token_utils']);
--
-- Process middle (non-trigger) schema versioning_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_versioning_utils']);
--
-- Process middle (non-trigger) schema x509_hash_manip
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('x509_hash_manip', 'get_or_create_public_key_hash_id');
SELECT schema_support.save_grants_for_replay('x509_hash_manip', 'get_or_create_public_key_hash_id');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS x509_hash_manip.get_or_create_public_key_hash_id ( jsonb );
CREATE OR REPLACE FUNCTION x509_hash_manip.get_or_create_public_key_hash_id(hashes jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_cnt BIGINT;
	_pkhid jazzhands.public_key_hash.public_key_hash_id%TYPE;
BEGIN
	IF NOT x509_hash_manip._validate_parameter_hashes(hashes) THEN
		RAISE EXCEPTION 'parameter "hashes" does not match JSON schema'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	WITH x AS (
		SELECT algorithm, hash
		FROM jsonb_to_recordset(hashes)
		AS jr(algorithm text, hash text)
	) SELECT count(DISTINCT pkhh.public_key_hash_id),
		min(pkhh.public_key_hash_id)
	INTO _cnt, _pkhid
	FROM jazzhands.public_key_hash_hash pkhh JOIN x
	ON  x.algorithm = pkhh.cryptographic_hash_algorithm
	AND x.hash = pkhh.calculated_hash;

	IF _cnt = 0 THEN
		INSERT INTO jazzhands.public_key_hash(description) VALUES(NULL)
		RETURNING public_key_hash_id INTO _pkhid;
	ELSIF _cnt > 1 THEN
		RAISE EXCEPTION 'multiple public_key_hash_id values found'
		USING ERRCODE = 'data_exception';
	END IF;

	WITH x AS (
		SELECT algorithm, hash
		FROM jsonb_to_recordset(hashes)
		AS jr(algorithm text, hash text)
	) INSERT INTO jazzhands.public_key_hash_hash AS pkhh (
		public_key_hash_id,
		cryptographic_hash_algorithm, calculated_hash
	) SELECT _pkhid, x.algorithm, x.hash FROM x
	ON CONFLICT ON CONSTRAINT pk_public_key_hash_hash
	DO UPDATE SET calculated_hash = EXCLUDED.calculated_hash
	WHERE pkhh.calculated_hash IS DISTINCT FROM EXCLUDED.calculated_hash;

RETURN _pkhid;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'x509_hash_manip' AND type = 'function' AND object IN ('get_or_create_public_key_hash_id');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc get_or_create_public_key_hash_id failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('x509_hash_manip', 'set_x509_signed_certificate_fingerprints');
SELECT schema_support.save_grants_for_replay('x509_hash_manip', 'set_x509_signed_certificate_fingerprints');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS x509_hash_manip.set_x509_signed_certificate_fingerprints ( integer,jsonb );
CREATE OR REPLACE FUNCTION x509_hash_manip.set_x509_signed_certificate_fingerprints(x509_cert_id integer, fingerprints jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE _cnt INTEGER;
BEGIN
	IF NOT x509_hash_manip._validate_parameter_hashes(fingerprints) THEN
		RAISE EXCEPTION 'parameter "fingerprints" does not match JSON schema'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	WITH x AS (
		SELECT algorithm, hash
		FROM jsonb_to_recordset(fingerprints)
		AS jr(algorithm text, hash text)
	) INSERT INTO x509_signed_certificate_fingerprint AS fp (
		x509_signed_certificate_id,
		x509_fingerprint_hash_algorighm, fingerprint
	) SELECT x509_cert_id, x.algorithm, x.hash FROM x
	ON CONFLICT ON CONSTRAINT pk_x509_signed_certificate_fingerprint
	DO UPDATE SET fingerprint = EXCLUDED.fingerprint
	WHERE fp.fingerprint IS DISTINCT FROM EXCLUDED.fingerprint;

	GET DIAGNOSTICS _cnt = ROW_COUNT;

	RETURN _cnt;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'x509_hash_manip' AND type = 'function' AND object IN ('set_x509_signed_certificate_fingerprints');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc set_x509_signed_certificate_fingerprints failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_hash_manip']);
--
-- Process middle (non-trigger) schema x509_plperl_cert_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_plperl_cert_utils']);
--
-- Process middle (non-trigger) schema audit
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_audit']);
--
-- Process middle (non-trigger) schema jazzhands_legacy
--
DROP TRIGGER IF EXISTS trigger_account_auth_log_del ON jazzhands_legacy.account_auth_log;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy'::text, object := 'account_auth_log_del (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy'::text]);
DROP FUNCTION IF EXISTS jazzhands_legacy.account_auth_log_del (  );
DROP TRIGGER IF EXISTS trigger_account_auth_log_ins ON jazzhands_legacy.account_auth_log;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy'::text, object := 'account_auth_log_ins (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy'::text]);
DROP FUNCTION IF EXISTS jazzhands_legacy.account_auth_log_ins (  );
DROP TRIGGER IF EXISTS trigger_account_auth_log_upd ON jazzhands_legacy.account_auth_log;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy'::text, object := 'account_auth_log_upd (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy'::text]);
DROP FUNCTION IF EXISTS jazzhands_legacy.account_auth_log_upd (  );
DROP TRIGGER IF EXISTS trigger_v_hotpants_token_del ON jazzhands_legacy.v_hotpants_token;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy'::text, object := 'v_hotpants_token_del (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy'::text]);
DROP FUNCTION IF EXISTS jazzhands_legacy.v_hotpants_token_del (  );
DROP TRIGGER IF EXISTS trigger_v_hotpants_token_ins ON jazzhands_legacy.v_hotpants_token;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy'::text, object := 'v_hotpants_token_ins (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy'::text]);
DROP FUNCTION IF EXISTS jazzhands_legacy.v_hotpants_token_ins (  );
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy']);
--
-- Process middle (non-trigger) schema jazzhands_legacy_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy_manip']);
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('jazzhands_legacy_manip', 'change_legacy_grants_for_users');
DROP FUNCTION IF EXISTS jazzhands_legacy_manip.change_legacy_grants_for_users ( text,text,boolean );
CREATE OR REPLACE FUNCTION jazzhands_legacy_manip.change_legacy_grants_for_users(username text, direction text, name_map_exception boolean DEFAULT true)
 RETURNS text[]
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	issuper	BOOLEAN;
	rv	TEXT[];
BEGIN
	--
	-- no need to map tables for revocation
	--
	IF direction = 'revoke' THEN
		SELECT  schema_support.migrate_grants(
			username := username,
			direction := direction,
			old_schema := 'jazzhands_legacy',
			new_schema := 'jazzhands'
		) INTO rv;
	ELSE
		SELECT  schema_support.migrate_grants(
			username := username,
			direction := direction,
			old_schema := 'jazzhands_legacy',
			new_schema := 'jazzhands',
			name_map := jazzhands_legacy_manip.relation_mapping(),
			name_map_exception := name_map_exception
		) INTO rv;
	END IF;
	RETURN rv;
END;
$function$
;

-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('jazzhands_legacy_manip', 'relation_mapping');
DROP FUNCTION IF EXISTS jazzhands_legacy_manip.relation_mapping (  );
CREATE OR REPLACE FUNCTION jazzhands_legacy_manip.relation_mapping()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO '_jazzhands_legacy_manip'
AS $function$
BEGIN
	RETURN '{
		"account_assignd_cert": "account_assigned_certificate",
		"account_auth_log": null,
		"account_coll_type_relation": "account_collection_type_relation",
		"account_realm_acct_coll_type": "account_realm_account_collection_type",
		"appaal_instance_device_coll": "appaal_instance_device_collection",
		"component_type_component_func": "component_type_component_function",
		"component_type_slot_tmplt": "component_type_slot_template",
		"device_collection_assignd_cert": "device_collection_assigned_certificate",
		"device_power_connection": null,
		"device_power_interface": null,
		"dns_domain_collection_dns_dom": "dns_domain_collection_dns_domain",
		"l2_network_coll_l2_network": "layer2_network_collection_layer2_network",
		"l3_network_coll_l3_network": "layer3_network_collection_layer3_network",
		"layer1_connection": null,
		"layer2_connection_l2_network": "layer2_connection_layer2_network",
		"network_interface": "layer3_interface",
		"network_interface_netblock": "layer3_interface_netblock",
		"network_interface_purpose": "layer3_interface_purpose",
		"person_auth_question": "person_authentication_question",
		"person_company_attr": "person_company_attribute",
		"physical_port": null,
		"property_collection": "property_name_collection",
		"property_collection_hier": "property_name_collection_hier",
		"property_collection_property": "property_name_collection_property_name",
		"service_environment_coll_hier": "service_environment_collection_hier",
		"shared_netblock_network_int": "shared_netblock_layer3_interface",
		"slot_type_prmt_comp_slot_type": "slot_type_permitted_component_slot_type",
		"slot_type_prmt_rem_slot_type": "slot_type_permitted_remote_slot_type",
		"snmp_commstr": null,
		"sudo_acct_col_device_collectio": "sudo_account_collection_device_collection",
		"svc_environment_coll_svc_env": "service_environment_collection_service_environment",
		"sw_package": null,
		"v_acct_coll_acct_expanded": null,
		"v_acct_coll_acct_expanded_detail": null,
		"v_acct_coll_expanded": null,
		"v_acct_coll_expanded_detail": null,
		"v_acct_coll_prop_expanded": null,
		"v_application_role": null,
		"v_application_role_member": null,
		"v_company_hier": null,
		"v_corp_family_account": null,
		"v_department_company_expanded": null,
		"v_dev_col_device_root": null,
		"v_dev_col_root": "v_device_collection_root",
		"v_dev_col_user_prop_expanded": null,
		"v_device_col_account_cart": null,
		"v_device_col_account_col_cart": null,
		"v_device_col_acct_col_expanded": null,
		"v_device_col_acct_col_unixgroup": null,
		"v_device_col_acct_col_unixlogin": null,
		"v_device_coll_device_expanded": null,
		"v_device_coll_hier_detail": null,
		"v_device_collection_account_ssh_key": null,
		"v_device_collection_hier_trans": null,
		"v_device_collection_root": null,
		"v_dns_changes_pending": null,
		"v_dns_domain_nouniverse": null,
		"v_dns": null,
		"v_dns_fwd": null,
		"v_dns_rvs": null,
		"v_dns_sorted": null,
		"v_hotpants_client": null,
		"v_hotpants_dc_attribute": null,
		"v_hotpants_device_collection": null,
		"v_hotpants_dc_attribute": null,
		"v_hotpants_token": null,
		"v_l1_all_physical_ports": null,
		"v_l2_network_coll_expanded": "v_layer2_network_collection_expanded",
		"v_l3_network_coll_expanded": "v_layer3_network_collection_expanded",
		"v_lv_hier": null,
		"v_nblk_coll_netblock_expanded": null,
		"v_netblock_coll_expanded": "v_netblock_collection_expanded",
		"v_network_interface_trans": null,
		"v_person_company": null,
		"v_unix_account_overrides": null,
		"v_unix_passwd_mappings": null,
		"v_token": null,
		"val_account_collection_relatio": "val_account_collection_relation",
		"val_app_key": "val_application_key",
		"val_app_key_values": "val_application_key_values",
		"val_approval_chain_resp_prd": "val_approval_chain_response_period",
		"val_auth_question": "val_authentication_question",
		"val_auth_resource": "val_authentication_resource",
		"val_device_auto_mgmt_protocol": null,
		"val_device_mgmt_ctrl_type": "val_device_management_controller_type",
		"val_key_usg_reason_for_assgn": "val_key_usage_reason_for_assignment",
		"val_layer2_network_coll_type": "val_layer2_network_collection_type",
		"val_layer3_network_coll_type": "val_layer3_network_collection_type",
		"val_network_interface_purpose": null,
		"val_network_interface_type": null,
		"val_os_snapshot_type": "val_operating_system_snapshot_type",
		"val_person_company_attr_dtype": "val_person_company_attribute_data_type",
		"val_person_company_attr_name": "val_person_company_attribute_name",
		"val_person_company_attr_value": "val_person_company_attribute_value",
		"val_person_contact_loc_type": "val_person_contact_location_type",
		"val_property_collection": "val_property_name_collection",
		"val_property_collection_type": "val_property_name_collection_type",
		"val_pvt_key_encryption_type": "val_private_key_encryption_type",
		"val_service_env_coll_type": "val_service_environment_collection_type",
		"val_snmp_commstr_type": null,
		"val_sw_package_type": null,
		"val_x509_certificate_file_fmt": "val_x509_certificate_file_format",
		"volume_group_physicalish_vol": "volume_group_physicalish_volume",
		"x509_certificate": null
	}'::jsonb;
END;
$function$
;

-- Processing tables in main schema...
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Processing minor changes to layer3_interface
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'layer3_interface');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'layer3_interface');
DROP INDEX IF EXISTS "jazzhands"."idx_netint_isifaceup";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_shouldmange";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_shouldmonitor";
DROP INDEX IF EXISTS "jazzhands"."idx_l3int_isifaceup";
CREATE INDEX idx_l3int_isifaceup ON jazzhands.layer3_interface USING btree (is_interface_up);
DROP INDEX IF EXISTS "jazzhands"."idx_l3int_shouldmange";
CREATE INDEX idx_l3int_shouldmange ON jazzhands.layer3_interface USING btree (should_manage);
DROP INDEX IF EXISTS "jazzhands"."idx_l3int_shouldmonitor";
CREATE INDEX idx_l3int_shouldmonitor ON jazzhands.layer3_interface USING btree (should_monitor);
ALTER TABLE layer3_interface
	RENAME CONSTRAINT ak_net_int_devid_netintid TO ak_l3int_devid_netintid;

ALTER TABLE layer3_interface DROP CONSTRAINT IF EXISTS fk_netint_devid_name;
ALTER TABLE layer3_interface
	RENAME CONSTRAINT pk_network_interface_id TO pk_layer3_interface_id;

ALTER TABLE layer3_interface
	RENAME CONSTRAINT uq_netint_device_id_logical_port_id TO uq_l3int_device_id_logical_port_id;

ALTER TABLE layer3_interface DROP CONSTRAINT IF EXISTS uq_l3int_devid_name;
ALTER TABLE layer3_interface
	ADD CONSTRAINT uq_l3int_devid_name
	UNIQUE (device_id, layer3_interface_name) DEFERRABLE;

ALTER TABLE device
	DROP CONSTRAINT IF EXISTS ckc_rack_location_component_non_virtual_474624417;
ALTER TABLE device
ADD CONSTRAINT ckc_rack_location_component_non_virtual_474624417
	CHECK ((((rack_location_id IS NOT NULL) AND (component_id IS NOT NULL) AND (NOT is_virtual_device)) OR (rack_location_id IS NULL)));

DROP INDEX IF EXISTS "jazzhands_audit"."aud_layer3_interface_ak_net_int_devid_netintid";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_layer3_interface_fk_netint_devid_name";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_layer3_interface_pk_network_interface_id";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_layer3_interface_uq_netint_device_id_logical_port_id";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_layer3_interface_ak_l3int_devid_netintid";
CREATE INDEX aud_layer3_interface_ak_l3int_devid_netintid ON jazzhands_audit.layer3_interface USING btree (layer3_interface_id, device_id);
DROP INDEX IF EXISTS "jazzhands_audit"."aud_layer3_interface_pk_layer3_interface_id";
CREATE INDEX aud_layer3_interface_pk_layer3_interface_id ON jazzhands_audit.layer3_interface USING btree (layer3_interface_id);
DROP INDEX IF EXISTS "jazzhands_audit"."aud_layer3_interface_uq_l3int_device_id_logical_port_id";
CREATE INDEX aud_layer3_interface_uq_l3int_device_id_logical_port_id ON jazzhands_audit.layer3_interface USING btree (device_id, logical_port_id);
DROP INDEX IF EXISTS "jazzhands_audit"."aud_layer3_interface_uq_l3int_devid_name";
CREATE INDEX aud_layer3_interface_uq_l3int_devid_name ON jazzhands_audit.layer3_interface USING btree (device_id, layer3_interface_name);
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Processing minor changes to component_type
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'component_type');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'component_type');
ALTER TABLE component_type DROP CONSTRAINT IF EXISTS ak_component_type_virtual;
ALTER TABLE component_type
	ADD CONSTRAINT ak_component_type_virtual
	UNIQUE (component_type_id, is_virtual_component);

ALTER TABLE device
	DROP CONSTRAINT IF EXISTS ckc_rack_location_component_non_virtual_474624417;
ALTER TABLE device
ADD CONSTRAINT ckc_rack_location_component_non_virtual_474624417
	CHECK ((((rack_location_id IS NOT NULL) AND (component_id IS NOT NULL) AND (NOT is_virtual_device)) OR (rack_location_id IS NULL)));

DROP INDEX IF EXISTS "jazzhands_audit"."aud_component_type_ak_component_type_virtual";
CREATE INDEX aud_component_type_ak_component_type_virtual ON jazzhands_audit.component_type USING btree (component_type_id, is_virtual_component);
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Processing minor changes to dns_record
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'dns_record');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'dns_record');
DROP INDEX IF EXISTS "jazzhands"."ak_dns_record_generate_ptr";
CREATE UNIQUE INDEX ak_dns_record_generate_ptr ON jazzhands.dns_record USING btree (netblock_id, should_generate_ptr) WHERE should_generate_ptr AND (dns_type::text = ANY (ARRAY['A'::character varying, 'AAAA'::character varying]::text[])) AND netblock_id IS NOT NULL;
ALTER TABLE component_type
	DROP CONSTRAINT IF EXISTS ckc_virtual_rack_mount_check_1365025208;
ALTER TABLE component_type
ADD CONSTRAINT ckc_virtual_rack_mount_check_1365025208
	CHECK ((((is_virtual_component = true) AND (is_rack_mountable = false)) OR (is_virtual_component = false)));

ALTER TABLE device
	DROP CONSTRAINT IF EXISTS ckc_rack_location_component_non_virtual_474624417;
ALTER TABLE device
ADD CONSTRAINT ckc_rack_location_component_non_virtual_474624417
	CHECK ((((rack_location_id IS NOT NULL) AND (component_id IS NOT NULL) AND (NOT is_virtual_device)) OR (rack_location_id IS NULL)));

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE logical_volume
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'logical_volume', 'logical_volume');

-- FOREIGN KEYS FROM
ALTER TABLE logical_volume_property DROP CONSTRAINT IF EXISTS fk_lvol_prop_lvid_fstyp;
ALTER TABLE logical_volume_purpose DROP CONSTRAINT IF EXISTS fk_lvpurp_lvid;
ALTER TABLE physicalish_volume DROP CONSTRAINT IF EXISTS fk_physvol_lvid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS fk_log_volume_log_vol_type;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_device_id;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_fstype;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_vgid;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'logical_volume', newobject := 'logical_volume', newmap := '{"ak_logical_volume_filesystem":{"columns":["logical_volume_id","filesystem_type"],"def":"UNIQUE (logical_volume_id, filesystem_type)","deferrable":false,"deferred":false,"name":"ak_logical_volume_filesystem","type":"u"},"ak_logvol_devid_lvname":{"columns":["device_id","logical_volume_name","logical_volume_type","volume_group_id"],"def":"UNIQUE (device_id, logical_volume_name, logical_volume_type, volume_group_id)","deferrable":false,"deferred":false,"name":"ak_logvol_devid_lvname","type":"u"},"ak_logvol_lv_devid":{"columns":["logical_volume_id"],"def":"UNIQUE (logical_volume_id)","deferrable":false,"deferred":false,"name":"ak_logvol_lv_devid","type":"u"},"pk_logical_volume":{"columns":["logical_volume_id"],"def":"PRIMARY KEY (logical_volume_id)","deferrable":false,"deferred":false,"name":"pk_logical_volume","type":"p"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS ak_logical_volume_filesystem;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS ak_logvol_devid_lvname;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS ak_logvol_lv_devid;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS pk_logical_volume;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif5logical_volume";
DROP INDEX IF EXISTS "jazzhands"."xif_logvol_device_id";
DROP INDEX IF EXISTS "jazzhands"."xif_logvol_fstype";
DROP INDEX IF EXISTS "jazzhands"."xif_logvol_vgid";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_logical_volume ON jazzhands.logical_volume;
DROP TRIGGER IF EXISTS trigger_audit_logical_volume ON jazzhands.logical_volume;
DROP FUNCTION IF EXISTS perform_audit_logical_volume();
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands.logical_volume ALTER COLUMN "logical_volume_id" DROP IDENTITY;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'logical_volume', tags := ARRAY['table_logical_volume']);
---- BEGIN jazzhands_audit.logical_volume TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'logical_volume', tags := ARRAY['table_logical_volume']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'logical_volume', 'logical_volume');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'logical_volume');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.logical_volume DROP CONSTRAINT IF EXISTS logical_volume_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_logical_volume_ak_logical_volume_filesystem";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_logical_volume_ak_logvol_devid_lvname";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_logical_volume_ak_logvol_lv_devid";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_logical_volume_pk_logical_volume";
DROP INDEX IF EXISTS "jazzhands_audit"."logical_volume_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."logical_volume_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."logical_volume_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.logical_volume ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.logical_volume TEARDOWN


ALTER TABLE logical_volume RENAME TO logical_volume_v96;
ALTER TABLE jazzhands_audit.logical_volume RENAME TO logical_volume_v96;

CREATE TABLE jazzhands.logical_volume
(
	logical_volume_id	integer NOT NULL,
	logical_volume_name	varchar(50) NOT NULL,
	logical_volume_type	varchar(50) NOT NULL,
	volume_group_id	integer NOT NULL,
	device_id	integer NOT NULL,
	logical_volume_size_in_bytes	bigint NOT NULL,
	logical_volume_offset_in_bytes	bigint  NULL,
	filesystem_type	varchar(50) NOT NULL,
	uuid	uuid  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'logical_volume', false);
ALTER TABLE logical_volume
	ALTER COLUMN logical_volume_id
	ADD GENERATED BY DEFAULT AS IDENTITY;
ALTER TABLE logical_volume
	ALTER logical_volume_type
	SET DEFAULT 'legacy'::character varying;

INSERT INTO logical_volume (
	logical_volume_id,
	logical_volume_name,
	logical_volume_type,
	volume_group_id,
	device_id,
	logical_volume_size_in_bytes,
	logical_volume_offset_in_bytes,
	filesystem_type,
	uuid,		-- new column (uuid)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	logical_volume_id,
	logical_volume_name,
	logical_volume_type,
	volume_group_id,
	device_id,
	logical_volume_size_in_bytes,
	logical_volume_offset_in_bytes,
	filesystem_type,
	NULL,		-- new column (uuid)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM logical_volume_v96;


INSERT INTO jazzhands_audit.logical_volume (
	logical_volume_id,
	logical_volume_name,
	logical_volume_type,
	volume_group_id,
	device_id,
	logical_volume_size_in_bytes,
	logical_volume_offset_in_bytes,
	filesystem_type,
	uuid,		-- new column (uuid)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#actor",		-- new column (aud#actor)
	"aud#seq"
) SELECT
	logical_volume_id,
	logical_volume_name,
	logical_volume_type,
	volume_group_id,
	device_id,
	logical_volume_size_in_bytes,
	logical_volume_offset_in_bytes,
	filesystem_type,
	NULL,		-- new column (uuid)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	NULL,		-- new column (aud#actor)
	"aud#seq"
FROM jazzhands_audit.logical_volume_v96;

ALTER TABLE jazzhands.logical_volume
	ALTER logical_volume_type
	SET DEFAULT 'legacy'::character varying;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.logical_volume ADD CONSTRAINT ak_logical_volume_filesystem UNIQUE (logical_volume_id, filesystem_type);
ALTER TABLE jazzhands.logical_volume ADD CONSTRAINT ak_logvol_devid_lvname UNIQUE (device_id, logical_volume_name, logical_volume_type, volume_group_id);
ALTER TABLE jazzhands.logical_volume ADD CONSTRAINT ak_logvol_lv_devid UNIQUE (logical_volume_id);
ALTER TABLE jazzhands.logical_volume ADD CONSTRAINT pk_logical_volume PRIMARY KEY (logical_volume_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif5logical_volume ON jazzhands.logical_volume USING btree (logical_volume_type);
CREATE INDEX xif_logvol_device_id ON jazzhands.logical_volume USING btree (device_id);
CREATE INDEX xif_logvol_fstype ON jazzhands.logical_volume USING btree (filesystem_type);
CREATE INDEX xif_logvol_vgid ON jazzhands.logical_volume USING btree (volume_group_id, device_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between logical_volume and jazzhands.block_storage_device
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.block_storage_device
--	ADD CONSTRAINT fk_block_storage_device_lv_lv_id
--	FOREIGN KEY (logical_volume_id) REFERENCES jazzhands.logical_volume(logical_volume_id);

-- consider FK between logical_volume and jazzhands.logical_volume_property
ALTER TABLE jazzhands.logical_volume_property
	ADD CONSTRAINT fk_lvol_prop_lvid_fstyp
	FOREIGN KEY (logical_volume_id, filesystem_type) REFERENCES jazzhands.logical_volume(logical_volume_id, filesystem_type) DEFERRABLE;
-- consider FK between logical_volume and jazzhands.logical_volume_purpose
ALTER TABLE jazzhands.logical_volume_purpose
	ADD CONSTRAINT fk_lvpurp_lvid
	FOREIGN KEY (logical_volume_id) REFERENCES jazzhands.logical_volume(logical_volume_id) DEFERRABLE;

-- FOREIGN KEYS TO
-- consider FK logical_volume and val_logical_volume_type
ALTER TABLE jazzhands.logical_volume
	ADD CONSTRAINT fk_log_volume_log_vol_type
	FOREIGN KEY (logical_volume_type) REFERENCES jazzhands.val_logical_volume_type(logical_volume_type);
-- consider FK logical_volume and device
ALTER TABLE jazzhands.logical_volume
	ADD CONSTRAINT fk_logvol_device_id
	FOREIGN KEY (device_id) REFERENCES jazzhands.device(device_id) DEFERRABLE;
-- consider FK logical_volume and val_filesystem_type
ALTER TABLE jazzhands.logical_volume
	ADD CONSTRAINT fk_logvol_fstype
	FOREIGN KEY (filesystem_type) REFERENCES jazzhands.val_filesystem_type(filesystem_type) DEFERRABLE;
-- consider FK logical_volume and volume_group
ALTER TABLE jazzhands.logical_volume
	ADD CONSTRAINT fk_logvol_vgid
	FOREIGN KEY (volume_group_id, device_id) REFERENCES jazzhands.volume_group(volume_group_id, device_id) DEFERRABLE;

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('logical_volume');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for logical_volume  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'logical_volume');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'logical_volume');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'logical_volume');
DROP TABLE IF EXISTS logical_volume_v96;
DROP TABLE IF EXISTS jazzhands_audit.logical_volume_v96;
-- DONE DEALING WITH TABLE logical_volume (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('logical_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old logical_volume failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('logical_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new logical_volume failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE volume_group
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'volume_group', 'volume_group');

-- FOREIGN KEYS FROM
ALTER TABLE logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_vgid;
ALTER TABLE volume_group_purpose DROP CONSTRAINT IF EXISTS fk_val_volgrp_purp_vgid;
ALTER TABLE volume_group_physicalish_volume DROP CONSTRAINT IF EXISTS fk_vgp_phy_vgrpid;
ALTER TABLE volume_group_physicalish_volume DROP CONSTRAINT IF EXISTS fk_vgp_phy_vgrpid_devid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS fk_vol_group_compon_id;
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS fk_volgrp_devid;
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS fk_volgrp_rd_type;
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS fk_volgrp_volgrp_type;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'volume_group', newobject := 'volume_group', newmap := '{"ak_volume_group_devid_vgid":{"columns":["volume_group_id","device_id"],"def":"UNIQUE (volume_group_id, device_id)","deferrable":false,"deferred":false,"name":"ak_volume_group_devid_vgid","type":"u"},"ak_volume_group_vg_devid":{"columns":["volume_group_id","device_id"],"def":"UNIQUE (volume_group_id, device_id)","deferrable":false,"deferred":false,"name":"ak_volume_group_vg_devid","type":"u"},"pk_volume_group":{"columns":["volume_group_id"],"def":"PRIMARY KEY (volume_group_id)","deferrable":false,"deferred":false,"name":"pk_volume_group","type":"p"},"uq_volgrp_devid_name_type":{"columns":["device_id","component_id","volume_group_name","volume_group_type"],"def":"UNIQUE (device_id, component_id, volume_group_name, volume_group_type)","deferrable":false,"deferred":false,"name":"uq_volgrp_devid_name_type","type":"u"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS ak_volume_group_devid_vgid;
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS ak_volume_group_vg_devid;
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS pk_volume_group;
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS uq_volgrp_devid_name_type;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xi_volume_group_name";
DROP INDEX IF EXISTS "jazzhands"."xif5volume_group";
DROP INDEX IF EXISTS "jazzhands"."xif_volgrp_devid";
DROP INDEX IF EXISTS "jazzhands"."xif_volgrp_rd_type";
DROP INDEX IF EXISTS "jazzhands"."xif_volgrp_volgrp_type";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_volume_group ON jazzhands.volume_group;
DROP TRIGGER IF EXISTS trigger_audit_volume_group ON jazzhands.volume_group;
DROP FUNCTION IF EXISTS perform_audit_volume_group();
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands.volume_group ALTER COLUMN "volume_group_id" DROP IDENTITY;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'volume_group', tags := ARRAY['table_volume_group']);
---- BEGIN jazzhands_audit.volume_group TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'volume_group', tags := ARRAY['table_volume_group']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'volume_group', 'volume_group');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'volume_group');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.volume_group DROP CONSTRAINT IF EXISTS volume_group_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_volume_group_ak_volume_group_devid_vgid";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_volume_group_ak_volume_group_vg_devid";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_volume_group_pk_volume_group";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_volume_group_uq_volgrp_devid_name_type";
DROP INDEX IF EXISTS "jazzhands_audit"."volume_group_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."volume_group_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."volume_group_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.volume_group ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.volume_group TEARDOWN


ALTER TABLE volume_group RENAME TO volume_group_v96;
ALTER TABLE jazzhands_audit.volume_group RENAME TO volume_group_v96;

CREATE TABLE jazzhands.volume_group
(
	volume_group_id	integer NOT NULL,
	device_id	integer  NULL,
	component_id	integer  NULL,
	volume_group_name	varchar(50) NOT NULL,
	volume_group_type	varchar(50)  NULL,
	volume_group_size_in_bytes	bigint NOT NULL,
	raid_type	varchar(50)  NULL,
	uuid	uuid  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'volume_group', false);
ALTER TABLE volume_group
	ALTER COLUMN volume_group_id
	ADD GENERATED BY DEFAULT AS IDENTITY;

INSERT INTO volume_group (
	volume_group_id,
	device_id,
	component_id,
	volume_group_name,
	volume_group_type,
	volume_group_size_in_bytes,
	raid_type,
	uuid,		-- new column (uuid)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	volume_group_id,
	device_id,
	component_id,
	volume_group_name,
	volume_group_type,
	volume_group_size_in_bytes,
	raid_type,
	NULL,		-- new column (uuid)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM volume_group_v96;


INSERT INTO jazzhands_audit.volume_group (
	volume_group_id,
	device_id,
	component_id,
	volume_group_name,
	volume_group_type,
	volume_group_size_in_bytes,
	raid_type,
	uuid,		-- new column (uuid)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#actor",		-- new column (aud#actor)
	"aud#seq"
) SELECT
	volume_group_id,
	device_id,
	component_id,
	volume_group_name,
	volume_group_type,
	volume_group_size_in_bytes,
	raid_type,
	NULL,		-- new column (uuid)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	NULL,		-- new column (aud#actor)
	"aud#seq"
FROM jazzhands_audit.volume_group_v96;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.volume_group ADD CONSTRAINT ak_volume_group_devid_vgid UNIQUE (volume_group_id, device_id);
ALTER TABLE jazzhands.volume_group ADD CONSTRAINT ak_volume_group_vg_devid UNIQUE (volume_group_id, device_id);
ALTER TABLE jazzhands.volume_group ADD CONSTRAINT pk_volume_group PRIMARY KEY (volume_group_id);
ALTER TABLE jazzhands.volume_group ADD CONSTRAINT uq_volgrp_devid_name_type UNIQUE (device_id, component_id, volume_group_name, volume_group_type);

-- Table/Column Comments
COMMENT ON COLUMN jazzhands.volume_group.component_id IS 'if applicable, the component that hosts this volume group.  This is primarily used to indicate the hardware raid controller component that hosts the volume group.';
-- INDEXES
CREATE INDEX xi_volume_group_name ON jazzhands.volume_group USING btree (volume_group_name);
CREATE INDEX xif5volume_group ON jazzhands.volume_group USING btree (component_id);
CREATE INDEX xif_volgrp_devid ON jazzhands.volume_group USING btree (device_id);
CREATE INDEX xif_volgrp_rd_type ON jazzhands.volume_group USING btree (raid_type);
CREATE INDEX xif_volgrp_volgrp_type ON jazzhands.volume_group USING btree (volume_group_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between volume_group and jazzhands.logical_volume
ALTER TABLE jazzhands.logical_volume
	ADD CONSTRAINT fk_logvol_vgid
	FOREIGN KEY (volume_group_id, device_id) REFERENCES jazzhands.volume_group(volume_group_id, device_id) DEFERRABLE;
-- consider FK between volume_group and jazzhands.volume_group_purpose
ALTER TABLE jazzhands.volume_group_purpose
	ADD CONSTRAINT fk_val_volgrp_purp_vgid
	FOREIGN KEY (volume_group_id) REFERENCES jazzhands.volume_group(volume_group_id) DEFERRABLE;
-- consider FK between volume_group and jazzhands.volume_group_block_storage_device
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.volume_group_block_storage_device
--	ADD CONSTRAINT fk_vg_blk_stg_dev_vgid_dev_id
--	FOREIGN KEY (volume_group_id, device_id) REFERENCES jazzhands.volume_group(volume_group_id, device_id);

-- consider FK between volume_group and jazzhands.volume_group_block_storage_device
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.volume_group_block_storage_device
--	ADD CONSTRAINT fk_vg_blk_stg_dev_vol_group_id
--	FOREIGN KEY (volume_group_id) REFERENCES jazzhands.volume_group(volume_group_id);


-- FOREIGN KEYS TO
-- consider FK volume_group and component
ALTER TABLE jazzhands.volume_group
	ADD CONSTRAINT fk_vol_group_compon_id
	FOREIGN KEY (component_id) REFERENCES jazzhands.component(component_id);
-- consider FK volume_group and device
ALTER TABLE jazzhands.volume_group
	ADD CONSTRAINT fk_volgrp_devid
	FOREIGN KEY (device_id) REFERENCES jazzhands.device(device_id) DEFERRABLE;
-- consider FK volume_group and val_raid_type
ALTER TABLE jazzhands.volume_group
	ADD CONSTRAINT fk_volgrp_rd_type
	FOREIGN KEY (raid_type) REFERENCES jazzhands.val_raid_type(raid_type) DEFERRABLE;
-- consider FK volume_group and val_volume_group_type
ALTER TABLE jazzhands.volume_group
	ADD CONSTRAINT fk_volgrp_volgrp_type
	FOREIGN KEY (volume_group_type) REFERENCES jazzhands.val_volume_group_type(volume_group_type) DEFERRABLE;

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('volume_group');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for volume_group  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'volume_group');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'volume_group');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'volume_group');
DROP TABLE IF EXISTS volume_group_v96;
DROP TABLE IF EXISTS jazzhands_audit.volume_group_v96;
-- DONE DEALING WITH TABLE volume_group (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('volume_group');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old volume_group failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('volume_group');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new volume_group failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE volume_group_physicalish_volume
-- ... renaming to volume_group_block_storage_device (jazzhands))
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'volume_group_physicalish_volume', 'volume_group_block_storage_device');
-- transfering grants from old object to new
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'volume_group_physicalish_volume', 'volume_group_block_storage_device');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.volume_group_physicalish_volume DROP CONSTRAINT IF EXISTS fk_physvol_vg_phsvol_dvid;
ALTER TABLE jazzhands.volume_group_physicalish_volume DROP CONSTRAINT IF EXISTS fk_vg_physvol_vgrel;
ALTER TABLE jazzhands.volume_group_physicalish_volume DROP CONSTRAINT IF EXISTS fk_vgp_phy_phyid;
ALTER TABLE jazzhands.volume_group_physicalish_volume DROP CONSTRAINT IF EXISTS fk_vgp_phy_vgrpid;
ALTER TABLE jazzhands.volume_group_physicalish_volume DROP CONSTRAINT IF EXISTS fk_vgp_phy_vgrpid_devid;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'volume_group_physicalish_volume', newobject := 'volume_group_block_storage_device', newmap := '{"pk_volume_group_block_storage_device":{"columns":["volume_group_id","block_storage_device_id"],"def":"PRIMARY KEY (volume_group_id, block_storage_device_id)","deferrable":false,"deferred":false,"name":"pk_volume_group_block_storage_device","type":"p"},"uq_volgrp_blk_stor_dev_position":{"columns":["volume_group_id","volume_group_primary_position"],"def":"UNIQUE (volume_group_id, volume_group_primary_position) DEFERRABLE","deferrable":true,"deferred":false,"name":"uq_volgrp_blk_stor_dev_position","type":"u"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.volume_group_physicalish_volume DROP CONSTRAINT IF EXISTS pk_volume_group_physicalish_vol;
ALTER TABLE jazzhands.volume_group_physicalish_volume DROP CONSTRAINT IF EXISTS uq_volgrp_pv_position;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_physvol_vg_phsvol_dvid";
DROP INDEX IF EXISTS "jazzhands"."xif_vg_physvol_vgrel";
DROP INDEX IF EXISTS "jazzhands"."xif_vgp_phy_phyid";
DROP INDEX IF EXISTS "jazzhands"."xif_vgp_phy_vgrpid";
DROP INDEX IF EXISTS "jazzhands"."xif_vgp_phy_vgrpid_devid";
DROP INDEX IF EXISTS "jazzhands"."xiq_volgrp_pv_position";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_volume_group_physicalish_volume ON jazzhands.volume_group_physicalish_volume;
DROP TRIGGER IF EXISTS trigger_audit_volume_group_physicalish_volume ON jazzhands.volume_group_physicalish_volume;
DROP FUNCTION IF EXISTS perform_audit_volume_group_physicalish_volume();
-- default sequences associations and sequences (values rebuilt at end, if needed)
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'volume_group_physicalish_volume', tags := ARRAY['table_volume_group_block_storage_device']);
---- BEGIN jazzhands_audit.volume_group_physicalish_volume TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'volume_group_physicalish_volume', tags := ARRAY['table_volume_group_block_storage_device']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'volume_group_physicalish_volume', 'volume_group_block_storage_device');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'volume_group_physicalish_volume');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.volume_group_physicalish_volume DROP CONSTRAINT IF EXISTS volume_group_physicalish_volume_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_0volume_group_physicalish_volume_pk_volume_group_physicalis";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_volume_group_physicalish_volume_uq_volgrp_pv_position";
DROP INDEX IF EXISTS "jazzhands_audit"."volume_group_physicalish_volume_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."volume_group_physicalish_volume_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."volume_group_physicalish_volume_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.volume_group_physicalish_volume ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.volume_group_physicalish_volume TEARDOWN


ALTER TABLE volume_group_physicalish_volume RENAME TO volume_group_physicalish_volume_v96;
ALTER TABLE jazzhands_audit.volume_group_physicalish_volume RENAME TO volume_group_physicalish_volume_v96;

CREATE TABLE jazzhands.volume_group_block_storage_device
(
	volume_group_id	integer NOT NULL,
	block_storage_device_id	integer NOT NULL,
	device_id	integer  NULL,
	volume_group_primary_position	integer  NULL,
	volume_group_secondary_position	integer  NULL,
	volume_group_relation	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'volume_group_block_storage_device', false);
--# no idea what I was thinking:SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'volume_group_block_storage_device');


-- BEGIN Manually written insert function
INSERT INTO volume_group_block_storage_device (
	volume_group_id,
	block_storage_device_id,		-- new column (block_storage_device_id)
	device_id,
	volume_group_primary_position,
	volume_group_secondary_position,
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	volume_group_id,
	physicalish_volume_id,		-- new column (block_storage_device_id)
	device_id,
	volume_group_primary_position,
	volume_group_secondary_position,
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM volume_group_physicalish_volume_v96;


INSERT INTO jazzhands_audit.volume_group_block_storage_device (
	volume_group_id,
	block_storage_device_id,		-- new column (block_storage_device_id)
	device_id,
	volume_group_primary_position,
	volume_group_secondary_position,
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#actor",
	"aud#seq"
) SELECT
	volume_group_id,
	physicalish_volume_id,		-- new column (block_storage_device_id)
	device_id,
	volume_group_primary_position,
	volume_group_secondary_position,
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	jsonb_build_object('user', regexp_replace("aud#user", '/.*$', '')) || CASE WHEN "aud#user" ~ '/' THEN jsonb_build_object('appuser', regexp_replace("aud#user", '^[^/]*', '')) ELSE '{}' END,
	"aud#seq"
FROM jazzhands_audit.volume_group_physicalish_volume_v96;



-- END Manually written insert function

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.volume_group_block_storage_device ADD CONSTRAINT pk_volume_group_block_storage_device PRIMARY KEY (volume_group_id, block_storage_device_id);
ALTER TABLE jazzhands.volume_group_block_storage_device ADD CONSTRAINT uq_volgrp_blk_stor_dev_position UNIQUE (volume_group_id, volume_group_primary_position) DEFERRABLE;

-- Table/Column Comments
COMMENT ON COLUMN jazzhands.volume_group_block_storage_device.volume_group_primary_position IS 'position within the primary raid, sometimes called span by at least one raid vendor.';
COMMENT ON COLUMN jazzhands.volume_group_block_storage_device.volume_group_secondary_position IS 'position within the secondary raid, sometimes called arm by at least one raid vendor.';
COMMENT ON COLUMN jazzhands.volume_group_block_storage_device.volume_group_relation IS 'purpose of volume in raid (member, hotspare, etc, based on val table)
';
-- INDEXES
CREATE INDEX xifbg_blk_stg_dev_blk_stg_dev_id ON jazzhands.volume_group_block_storage_device USING btree (block_storage_device_id, device_id);
CREATE INDEX xifvg_blk_stg_dev_blk_stg_dev_id ON jazzhands.volume_group_block_storage_device USING btree (block_storage_device_id);
CREATE INDEX xifvg_blk_stg_dev_vgid_dev_id ON jazzhands.volume_group_block_storage_device USING btree (device_id, volume_group_id);
CREATE INDEX xifvg_blk_stg_dev_vol_group_id ON jazzhands.volume_group_block_storage_device USING btree (volume_group_id);
CREATE INDEX xifvg_blk_stg_dev_vol_grp_relation ON jazzhands.volume_group_block_storage_device USING btree (volume_group_relation);
CREATE INDEX xiq_volgrp_blk_stor_dev_position ON jazzhands.volume_group_block_storage_device USING btree (volume_group_id, volume_group_primary_position);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK volume_group_block_storage_device and block_storage_device
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.volume_group_block_storage_device
--	ADD CONSTRAINT fk_bg_blk_stg_dev_blk_stg_dev_id
--	FOREIGN KEY (block_storage_device_id, device_id) REFERENCES jazzhands.block_storage_device(block_storage_device_id, device_id);

-- consider FK volume_group_block_storage_device and block_storage_device
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.volume_group_block_storage_device
--	ADD CONSTRAINT fk_vg_blk_stg_dev_blk_stg_dev_id
--	FOREIGN KEY (block_storage_device_id) REFERENCES jazzhands.block_storage_device(block_storage_device_id);

-- consider FK volume_group_block_storage_device and volume_group
ALTER TABLE jazzhands.volume_group_block_storage_device
	ADD CONSTRAINT fk_vg_blk_stg_dev_vgid_dev_id
	FOREIGN KEY (volume_group_id, device_id) REFERENCES jazzhands.volume_group(volume_group_id, device_id);
-- consider FK volume_group_block_storage_device and volume_group
ALTER TABLE jazzhands.volume_group_block_storage_device
	ADD CONSTRAINT fk_vg_blk_stg_dev_vol_group_id
	FOREIGN KEY (volume_group_id) REFERENCES jazzhands.volume_group(volume_group_id);
-- consider FK volume_group_block_storage_device and val_volume_group_relation
ALTER TABLE jazzhands.volume_group_block_storage_device
	ADD CONSTRAINT fk_vg_blk_stg_dev_vol_grp_relation
	FOREIGN KEY (volume_group_relation) REFERENCES jazzhands.val_volume_group_relation(volume_group_relation);

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('volume_group_block_storage_device');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for volume_group_block_storage_device  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'volume_group_block_storage_device');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'volume_group_block_storage_device');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'volume_group_block_storage_device');
DROP TABLE IF EXISTS volume_group_physicalish_volume_v96;
DROP TABLE IF EXISTS jazzhands_audit.volume_group_physicalish_volume_v96;
-- DONE DEALING WITH TABLE volume_group_block_storage_device (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('volume_group_physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old volume_group_physicalish_volume failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('volume_group_block_storage_device');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new volume_group_block_storage_device failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE val_physicalish_volume_type
-- ... renaming to val_block_storage_device_type (jazzhands))
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_physicalish_volume_type', 'val_block_storage_device_type');
-- transfering grants from old object to new
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'val_physicalish_volume_type', 'val_block_storage_device_type');

-- FOREIGN KEYS FROM
ALTER TABLE physicalish_volume DROP CONSTRAINT IF EXISTS fk_physicalish_vol_pvtype;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'val_physicalish_volume_type', newobject := 'val_block_storage_device_type', newmap := '{"pk_block_storage_device_type":{"columns":["block_storage_device_type"],"def":"PRIMARY KEY (block_storage_device_type)","deferrable":false,"deferred":false,"name":"pk_block_storage_device_type","type":"p"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_physicalish_volume_type DROP CONSTRAINT IF EXISTS pk_val_physicalish_volume_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_physicalish_volume_type ON jazzhands.val_physicalish_volume_type;
DROP TRIGGER IF EXISTS trigger_audit_val_physicalish_volume_type ON jazzhands.val_physicalish_volume_type;
DROP FUNCTION IF EXISTS perform_audit_val_physicalish_volume_type();
-- default sequences associations and sequences (values rebuilt at end, if needed)
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'val_physicalish_volume_type', tags := ARRAY['table_val_block_storage_device_type']);
---- BEGIN jazzhands_audit.val_physicalish_volume_type TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'val_physicalish_volume_type', tags := ARRAY['table_val_block_storage_device_type']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'val_physicalish_volume_type', 'val_block_storage_device_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'val_physicalish_volume_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.val_physicalish_volume_type DROP CONSTRAINT IF EXISTS val_physicalish_volume_type_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_val_physicalish_volume_type_pk_val_physicalish_volume_type";
DROP INDEX IF EXISTS "jazzhands_audit"."val_physicalish_volume_type_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."val_physicalish_volume_type_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."val_physicalish_volume_type_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.val_physicalish_volume_type ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.val_physicalish_volume_type TEARDOWN


ALTER TABLE val_physicalish_volume_type RENAME TO val_physicalish_volume_type_v96;
ALTER TABLE jazzhands_audit.val_physicalish_volume_type RENAME TO val_physicalish_volume_type_v96;

CREATE TABLE jazzhands.val_block_storage_device_type
(
	block_storage_device_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_block_storage_device_type', false);
--# no idea what I was thinking:SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_block_storage_device_type');


-- BEGIN Manually written insert function

INSERT INTO val_block_storage_device_type (
	block_storage_device_type,		-- new column (block_storage_device_type)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	physicalish_volume_type,		-- new column (block_storage_device_type)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_physicalish_volume_type_v96;


INSERT INTO jazzhands_audit.val_block_storage_device_type (
	block_storage_device_type,		-- new column (block_storage_device_type)
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
	"aud#actor",
	"aud#seq"
) SELECT
	physicalish_volume_type,		-- new column (block_storage_device_type)
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
	jsonb_build_object('user', regexp_replace("aud#user", '/.*$', '')) || CASE WHEN "aud#user" ~ '/' THEN jsonb_build_object('appuser', regexp_replace("aud#user", '^[^/]*', '')) ELSE '{}' END,
	"aud#seq"
FROM jazzhands_audit.val_physicalish_volume_type_v96;



-- END Manually written insert function

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_block_storage_device_type ADD CONSTRAINT pk_block_storage_device_type PRIMARY KEY (block_storage_device_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_block_storage_device_type and jazzhands.block_storage_device
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.block_storage_device
--	ADD CONSTRAINT fk_block_storage_device_blk_stg_dev_typ
--	FOREIGN KEY (block_storage_device_type) REFERENCES jazzhands.val_block_storage_device_type(block_storage_device_type);


-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_block_storage_device_type');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_block_storage_device_type  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_block_storage_device_type');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_block_storage_device_type');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_block_storage_device_type');
DROP TABLE IF EXISTS val_physicalish_volume_type_v96;
DROP TABLE IF EXISTS jazzhands_audit.val_physicalish_volume_type_v96;
-- DONE DEALING WITH TABLE val_block_storage_device_type (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_physicalish_volume_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_physicalish_volume_type failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_block_storage_device_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_block_storage_device_type failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE physicalish_volume
-- ... renaming to block_storage_device (jazzhands))
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'physicalish_volume', 'block_storage_device');
-- transfering grants from old object to new
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'physicalish_volume', 'block_storage_device');

-- FOREIGN KEYS FROM
ALTER TABLE volume_group_block_storage_device DROP CONSTRAINT IF EXISTS fk_physvol_vg_phsvol_dvid;
ALTER TABLE volume_group_block_storage_device DROP CONSTRAINT IF EXISTS fk_vgp_phy_phyid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.physicalish_volume DROP CONSTRAINT IF EXISTS fk_physicalish_vol_pvtype;
ALTER TABLE jazzhands.physicalish_volume DROP CONSTRAINT IF EXISTS fk_physvol_compid;
ALTER TABLE jazzhands.physicalish_volume DROP CONSTRAINT IF EXISTS fk_physvol_device_id;
ALTER TABLE jazzhands.physicalish_volume DROP CONSTRAINT IF EXISTS fk_physvol_lvid;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'physicalish_volume', newobject := 'block_storage_device', newmap := '{"ak_block_storage_device_blk_stg_dev_id_dev_id":{"columns":["device_id","block_storage_device_id"],"def":"UNIQUE (block_storage_device_id, device_id)","deferrable":false,"deferred":false,"name":"ak_block_storage_device_blk_stg_dev_id_dev_id","type":"u"},"ak_block_storage_device_blk_stg_name_type_devid":{"columns":["block_storage_device_name","block_storage_device_type","device_id"],"def":"UNIQUE (device_id, block_storage_device_name, block_storage_device_type) DEFERRABLE","deferrable":true,"deferred":false,"name":"ak_block_storage_device_blk_stg_name_type_devid","type":"u"},"ak_block_storage_device_device_uuid":{"columns":["uuid","device_id"],"def":"UNIQUE (device_id, uuid)","deferrable":false,"deferred":false,"name":"ak_block_storage_device_device_uuid","type":"u"},"pk_block_storage_device":{"columns":["block_storage_device_id"],"def":"PRIMARY KEY (block_storage_device_id)","deferrable":false,"deferred":false,"name":"pk_block_storage_device","type":"p"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.physicalish_volume DROP CONSTRAINT IF EXISTS ak_physicalish_volume_devid;
ALTER TABLE jazzhands.physicalish_volume DROP CONSTRAINT IF EXISTS ak_physvolname_type_devid;
ALTER TABLE jazzhands.physicalish_volume DROP CONSTRAINT IF EXISTS pk_physicalish_volume;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_physicalish_vol_pvtype";
DROP INDEX IF EXISTS "jazzhands"."xif_physvol_compid";
DROP INDEX IF EXISTS "jazzhands"."xif_physvol_device_id";
DROP INDEX IF EXISTS "jazzhands"."xif_physvol_lvid";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_physicalish_volume ON jazzhands.physicalish_volume;
DROP TRIGGER IF EXISTS trigger_audit_physicalish_volume ON jazzhands.physicalish_volume;
DROP FUNCTION IF EXISTS perform_audit_physicalish_volume();
DROP TRIGGER IF EXISTS trigger_verify_physicalish_volume ON jazzhands.physicalish_volume;
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands.physicalish_volume ALTER COLUMN "physicalish_volume_id" DROP IDENTITY;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'physicalish_volume', tags := ARRAY['table_block_storage_device']);
---- BEGIN jazzhands_audit.physicalish_volume TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'physicalish_volume', tags := ARRAY['table_block_storage_device']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'physicalish_volume', 'block_storage_device');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'physicalish_volume');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.physicalish_volume DROP CONSTRAINT IF EXISTS physicalish_volume_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_physicalish_volume_ak_physicalish_volume_devid";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_physicalish_volume_ak_physvolname_type_devid";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_physicalish_volume_pk_physicalish_volume";
DROP INDEX IF EXISTS "jazzhands_audit"."physicalish_volume_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."physicalish_volume_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."physicalish_volume_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.physicalish_volume ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.physicalish_volume TEARDOWN


ALTER TABLE physicalish_volume RENAME TO physicalish_volume_v96;
ALTER TABLE jazzhands_audit.physicalish_volume RENAME TO physicalish_volume_v96;

CREATE TABLE jazzhands.block_storage_device
(
	block_storage_device_id	integer NOT NULL,
	block_storage_device_name	varchar(50) NOT NULL,
	block_storage_device_type	varchar(50) NOT NULL,
	device_id	integer NOT NULL,
	component_id	integer  NULL,
	logical_volume_id	integer  NULL,
	encrypted_block_storage_device_id	integer  NULL,
	uuid	uuid  NULL,
	block_device_size_in_bytes	bigint  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'block_storage_device', false);
--# no idea what I was thinking:SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'block_storage_device');
ALTER TABLE block_storage_device
	ALTER COLUMN block_storage_device_id
	ADD GENERATED BY DEFAULT AS IDENTITY;


-- BEGIN Manually written insert function

INSERT INTO block_storage_device (
	block_storage_device_id,		-- new column (block_storage_device_id)
	block_storage_device_name,		-- new column (block_storage_device_name)
	block_storage_device_type,		-- new column (block_storage_device_type)
	device_id,
	component_id,
	logical_volume_id,
	encrypted_block_storage_device_id,		-- new column (encrypted_block_storage_device_id)
	uuid,		-- new column (uuid)
	block_device_size_in_bytes,		-- new column (block_device_size_in_bytes)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	physicalish_volume_id,		-- new column (block_storage_device_id)
	physicalish_volume_name,	-- new column (block_storage_device_name)
	physicalish_volume_type,	-- new column (block_storage_device_type)
	device_id,
	component_id,
	logical_volume_id,
	NULL,		-- new column (encrypted_block_storage_device_id)
	NULL,		-- new column (uuid)
	NULL,		-- new column (block_device_size_in_bytes)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM physicalish_volume_v96;


INSERT INTO jazzhands_audit.block_storage_device (
	block_storage_device_id,		-- new column (block_storage_device_id)
	block_storage_device_name,		-- new column (block_storage_device_name)
	block_storage_device_type,		-- new column (block_storage_device_type)
	device_id,
	component_id,
	logical_volume_id,
	encrypted_block_storage_device_id,		-- new column (encrypted_block_storage_device_id)
	uuid,		-- new column (uuid)
	block_device_size_in_bytes,		-- new column (block_device_size_in_bytes)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#actor",
	"aud#seq"
) SELECT
	physicalish_volume_id,		-- new column (block_storage_device_id)
	physicalish_volume_name,	-- new column (block_storage_device_name)
	physicalish_volume_type,	-- new column (block_storage_device_type)
	device_id,
	component_id,
	logical_volume_id,
	NULL,		-- new column (encrypted_block_storage_device_id)
	NULL,		-- new column (uuid)
	NULL,		-- new column (block_device_size_in_bytes)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	jsonb_build_object('user', regexp_replace("aud#user", '/.*$', '')) || CASE WHEN "aud#user" ~ '/' THEN jsonb_build_object('appuser', regexp_replace("aud#user", '^[^/]*', '')) ELSE '{}' END,
	"aud#seq"
FROM jazzhands_audit.physicalish_volume_v96;



-- END Manually written insert function
-- cleaning up sequences with droppe/renamed table
ALTER SEQUENCE IF EXISTS physicalish_volume_physicalish_volume_id_seq OWNED BY NONE;
DROP SEQUENCE IF EXISTS physicalish_volume_physicalish_volume_id_seq;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.block_storage_device ADD CONSTRAINT ak_block_storage_device_blk_stg_dev_id_dev_id UNIQUE (block_storage_device_id, device_id);
ALTER TABLE jazzhands.block_storage_device ADD CONSTRAINT ak_block_storage_device_blk_stg_name_type_devid UNIQUE (device_id, block_storage_device_name, block_storage_device_type) DEFERRABLE;
ALTER TABLE jazzhands.block_storage_device ADD CONSTRAINT ak_block_storage_device_device_uuid UNIQUE (device_id, uuid);
ALTER TABLE jazzhands.block_storage_device ADD CONSTRAINT pk_block_storage_device PRIMARY KEY (block_storage_device_id);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.block_storage_device IS 'Device that can be accessed as a block device from an operating sytem.  This could range from physical disks to encrypted logical volumes and everything in between.
';
COMMENT ON COLUMN jazzhands.block_storage_device.block_storage_device_name IS 'Unique (on the device) name of the block storage device.  This will vary based on ussage.';
COMMENT ON COLUMN jazzhands.block_storage_device.block_storage_device_type IS 'Type of block device.   There may be other tables with more information based on the type. ';
COMMENT ON COLUMN jazzhands.block_storage_device.device_id IS 'Device that has the block device on it.';
COMMENT ON COLUMN jazzhands.block_storage_device.component_id IS 'Only one of component, logical_volume,or encrypted_block_storage_device_id can be set.';
COMMENT ON COLUMN jazzhands.block_storage_device.logical_volume_id IS 'Only one of component, logical_volume,or encrypted_block_storage_device_id can be set.';
COMMENT ON COLUMN jazzhands.block_storage_device.encrypted_block_storage_device_id IS 'Only one of component, logical_volume,or encrypted_block_storage_device_id can be set.';
COMMENT ON COLUMN jazzhands.block_storage_device.uuid IS 'device wide uuid that is an alternate name for the device.';
-- INDEXES
CREATE INDEX xifblock_storage_device_blk_stg_dev_typ ON jazzhands.block_storage_device USING btree (block_storage_device_type);
CREATE INDEX xifblock_storage_device_component_component_id ON jazzhands.block_storage_device USING btree (component_id);
CREATE INDEX xifblock_storage_device_device_device_id ON jazzhands.block_storage_device USING btree (device_id);
CREATE INDEX xifblock_storage_device_enc_blk_stroage_device ON jazzhands.block_storage_device USING btree (encrypted_block_storage_device_id);
CREATE INDEX xifblock_storage_device_lv_lv_id ON jazzhands.block_storage_device USING btree (logical_volume_id);

-- CHECK CONSTRAINTS
ALTER TABLE jazzhands.block_storage_device ADD CONSTRAINT ckc_one_of_logical_device_id_or_component_id_or_enc__1214227068
	CHECK ((((logical_volume_id IS NOT NULL) AND (encrypted_block_storage_device_id IS NULL) AND (component_id IS NULL)) OR ((logical_volume_id IS NULL) AND (encrypted_block_storage_device_id IS NULL) AND (component_id IS NOT NULL)) OR ((logical_volume_id IS NULL) AND (encrypted_block_storage_device_id IS NOT NULL) AND (component_id IS NULL))));
ALTER TABLE jazzhands.block_storage_device ADD CONSTRAINT ckc_one_of_logical_device_id_or_component_id_or_enc__1396903461
	CHECK ((((logical_volume_id IS NOT NULL) AND (encrypted_block_storage_device_id IS NULL) AND (component_id IS NULL)) OR ((logical_volume_id IS NULL) AND (encrypted_block_storage_device_id IS NULL) AND (component_id IS NOT NULL)) OR ((logical_volume_id IS NULL) AND (encrypted_block_storage_device_id IS NOT NULL) AND (component_id IS NULL))));
ALTER TABLE jazzhands.block_storage_device ADD CONSTRAINT ckc_one_of_logical_device_id_or_component_id_or_enc_b_915371407
	CHECK ((((logical_volume_id IS NOT NULL) AND (encrypted_block_storage_device_id IS NULL) AND (component_id IS NULL)) OR ((logical_volume_id IS NULL) AND (encrypted_block_storage_device_id IS NULL) AND (component_id IS NOT NULL)) OR ((logical_volume_id IS NULL) AND (encrypted_block_storage_device_id IS NOT NULL) AND (component_id IS NULL))));

-- FOREIGN KEYS FROM
-- consider FK between block_storage_device and jazzhands.volume_group_block_storage_device
ALTER TABLE jazzhands.volume_group_block_storage_device
	ADD CONSTRAINT fk_bg_blk_stg_dev_blk_stg_dev_id
	FOREIGN KEY (block_storage_device_id, device_id) REFERENCES jazzhands.block_storage_device(block_storage_device_id, device_id);
-- consider FK between block_storage_device and jazzhands.block_storage_device_virtual_component
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.block_storage_device_virtual_component
--	ADD CONSTRAINT fk_block_storage_device_virtual_component_block_storage_device_
--	FOREIGN KEY (block_storage_device_id) REFERENCES jazzhands.block_storage_device(block_storage_device_id);

-- consider FK between block_storage_device and jazzhands.encrypted_block_storage_device
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.encrypted_block_storage_device
--	ADD CONSTRAINT fk_enc_block_storage_device_block_storage_device
--	FOREIGN KEY (block_storage_device_id) REFERENCES jazzhands.block_storage_device(block_storage_device_id);

-- consider FK between block_storage_device and jazzhands.filesystem
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.filesystem
--	ADD CONSTRAINT fk_filesystem_block_storage_device_id
--	FOREIGN KEY (block_storage_device_id, device_id) REFERENCES jazzhands.block_storage_device(block_storage_device_id, device_id);

-- consider FK between block_storage_device and jazzhands.volume_group_block_storage_device
ALTER TABLE jazzhands.volume_group_block_storage_device
	ADD CONSTRAINT fk_vg_blk_stg_dev_blk_stg_dev_id
	FOREIGN KEY (block_storage_device_id) REFERENCES jazzhands.block_storage_device(block_storage_device_id);

-- FOREIGN KEYS TO
-- consider FK block_storage_device and val_block_storage_device_type
ALTER TABLE jazzhands.block_storage_device
	ADD CONSTRAINT fk_block_storage_device_blk_stg_dev_typ
	FOREIGN KEY (block_storage_device_type) REFERENCES jazzhands.val_block_storage_device_type(block_storage_device_type);
-- consider FK block_storage_device and component
ALTER TABLE jazzhands.block_storage_device
	ADD CONSTRAINT fk_block_storage_device_component_component_id
	FOREIGN KEY (component_id) REFERENCES jazzhands.component(component_id);
-- consider FK block_storage_device and device
ALTER TABLE jazzhands.block_storage_device
	ADD CONSTRAINT fk_block_storage_device_device_device_id
	FOREIGN KEY (device_id) REFERENCES jazzhands.device(device_id);
-- consider FK block_storage_device and encrypted_block_storage_device
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.block_storage_device
--	ADD CONSTRAINT fk_block_storage_device_enc_blk_stroage_device
--	FOREIGN KEY (encrypted_block_storage_device_id) REFERENCES jazzhands.encrypted_block_storage_device(encrypted_block_storage_device_id);

-- consider FK block_storage_device and logical_volume
ALTER TABLE jazzhands.block_storage_device
	ADD CONSTRAINT fk_block_storage_device_lv_lv_id
	FOREIGN KEY (logical_volume_id) REFERENCES jazzhands.logical_volume(logical_volume_id);

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('block_storage_device');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for block_storage_device  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'block_storage_device');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'block_storage_device');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'block_storage_device');
DROP TABLE IF EXISTS physicalish_volume_v96;
DROP TABLE IF EXISTS jazzhands_audit.physicalish_volume_v96;
-- DONE DEALING WITH TABLE block_storage_device (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old physicalish_volume failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('block_storage_device');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new block_storage_device failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_block_storage_device_encryption_system (jazzhands)
CREATE TABLE jazzhands.val_block_storage_device_encryption_system
(
	block_storage_device_encryption_system	varchar(255) NOT NULL,
	description	varchar(4096)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_block_storage_device_encryption_system', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_block_storage_device_encryption_system ADD CONSTRAINT pk_val_block_storage_device_encryption_system PRIMARY KEY (block_storage_device_encryption_system);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_block_storage_device_encryption_system and jazzhands.encrypted_block_storage_device
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.encrypted_block_storage_device
--	ADD CONSTRAINT fl_enc_blk_storage_device_val_block_stg_dev_enc_type
--	FOREIGN KEY (block_storage_device_encryption_system) REFERENCES jazzhands.val_block_storage_device_encryption_system(block_storage_device_encryption_system);


-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_block_storage_device_encryption_system');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_block_storage_device_encryption_system  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_block_storage_device_encryption_system');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_block_storage_device_encryption_system');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_block_storage_device_encryption_system');
--
-- Copying initialization data
--

INSERT INTO val_block_storage_device_encryption_system (
block_storage_device_encryption_system,description
) VALUES
	('LUKS',NULL),
	('VeraCrypt',NULL),
	('ZFS',NULL)
;
-- DONE DEALING WITH TABLE val_block_storage_device_encryption_system (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_block_storage_device_encryption_system');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_block_storage_device_encryption_system failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_block_storage_device_encryption_system');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_block_storage_device_encryption_system failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_cipher (jazzhands)
CREATE TABLE jazzhands.val_cipher
(
	cipher	varchar(255) NOT NULL,
	description	varchar(4096)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_cipher', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_cipher ADD CONSTRAINT pk_val_cipher PRIMARY KEY (cipher);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.val_cipher IS 'Cipher algorithms used to encrypt data.  This is a liberal use of the word cipher and arguably this should be caled _encryption algorithm_ but that term is overloaded, too.
';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_cipher and jazzhands.val_cipher_permitted_cipher_chain_mode
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.val_cipher_permitted_cipher_chain_mode
--	ADD CONSTRAINT fk_cipher_permitted_cipher_chain_cipher
--	FOREIGN KEY (cipher) REFERENCES jazzhands.val_cipher(cipher);

-- consider FK between val_cipher and jazzhands.val_encryption_method
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.val_encryption_method
--	ADD CONSTRAINT fk_enc_mthod_cipher
--	FOREIGN KEY (cipher) REFERENCES jazzhands.val_cipher(cipher);

-- consider FK between val_cipher and jazzhands.val_cipher_permitted_cipher_padding
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.val_cipher_permitted_cipher_padding
--	ADD CONSTRAINT fk_val_cipher_permitted_cipher_padding_cipher_padding
--	FOREIGN KEY (cipher) REFERENCES jazzhands.val_cipher(cipher);

-- consider FK between val_cipher and jazzhands.val_cipher_permitted_key_size
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.val_cipher_permitted_key_size
--	ADD CONSTRAINT fk_val_cipher_permitted_key_size_cipher
--	FOREIGN KEY (cipher) REFERENCES jazzhands.val_cipher(cipher);


-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_cipher');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_cipher  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_cipher');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_cipher');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_cipher');
--
-- Copying initialization data
--

INSERT INTO val_cipher (
cipher,description
) VALUES
	('none',NULL),
	('des',NULL),
	('des3',NULL),
	('IDEA',NULL),
	('Blowfish',NULL),
	('CAST5',NULL),
	('AES','aka Rijndael'),
	('Camelia',NULL),
	('RSA',NULL),
	('ECC',NULL)
;
-- DONE DEALING WITH TABLE val_cipher (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_cipher');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_cipher failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_cipher');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_cipher failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_cipher_chain_mode (jazzhands)
CREATE TABLE jazzhands.val_cipher_chain_mode
(
	cipher_chain_mode	varchar(255) NOT NULL,
	description	varchar(4096)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_cipher_chain_mode', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_cipher_chain_mode ADD CONSTRAINT pk_val_cipher_chain_mode PRIMARY KEY (cipher_chain_mode);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.val_cipher_chain_mode IS 'possible chain modes with a given cipher algorithm.';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_cipher_chain_mode and jazzhands.val_cipher_permitted_cipher_chain_mode
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.val_cipher_permitted_cipher_chain_mode
--	ADD CONSTRAINT fk_v_permitted_cipher_chain_cipher_chain_mode
--	FOREIGN KEY (cipher_chain_mode) REFERENCES jazzhands.val_cipher_chain_mode(cipher_chain_mode);


-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_cipher_chain_mode');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_cipher_chain_mode  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_cipher_chain_mode');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_cipher_chain_mode');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_cipher_chain_mode');
--
-- Copying initialization data
--

INSERT INTO val_cipher_chain_mode (
cipher_chain_mode,description
) VALUES
	('none',NULL),
	('CBC','cipher-bock chaining'),
	('PCBC','plaintext cipher-block chaining'),
	('CFB','Cipher Feedback'),
	('OFB','Output Feedbacl'),
	('CTR','Counter')
;
-- DONE DEALING WITH TABLE val_cipher_chain_mode (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_cipher_chain_mode');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_cipher_chain_mode failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_cipher_chain_mode');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_cipher_chain_mode failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_cipher_padding (jazzhands)
CREATE TABLE jazzhands.val_cipher_padding
(
	cipher_padding	varchar(255) NOT NULL,
	description	varchar(4096)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_cipher_padding', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_cipher_padding ADD CONSTRAINT pk_val_cipher_padding PRIMARY KEY (cipher_padding);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.val_cipher_padding IS 'types of padding that can be used with ciphers.  Mapping to ciphers is handled elsewhere';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_cipher_padding and jazzhands.val_encryption_method
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.val_encryption_method
--	ADD CONSTRAINT fk_enc_method_cipher_padding
--	FOREIGN KEY (cipher_padding) REFERENCES jazzhands.val_cipher_padding(cipher_padding);

-- consider FK between val_cipher_padding and jazzhands.val_cipher_permitted_cipher_padding
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.val_cipher_permitted_cipher_padding
--	ADD CONSTRAINT fk_v_permitted_cipher_padding_cipher_padding
--	FOREIGN KEY (cipher_padding) REFERENCES jazzhands.val_cipher_padding(cipher_padding);


-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_cipher_padding');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_cipher_padding  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_cipher_padding');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_cipher_padding');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_cipher_padding');
--
-- Copying initialization data
--

INSERT INTO val_cipher_padding (
cipher_padding,description
) VALUES
	('none',NULL),
	('null','pad with zeros'),
	('Space','pad with 0x20'),
	('PKCS5','pads with number of bytes that should be truncated'),
	('Rijndael_Compat','Similar to ones and zeros, no padding on last full block'),
	('OneAndZeros','Pads with 0x80 followed by 0x00s to fill'),
	('X9.23','Zero followed by number of bytes of padding'),
	('W3C','arbitrary byte values ending with number of bytes padded')
;
-- DONE DEALING WITH TABLE val_cipher_padding (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_cipher_padding');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_cipher_padding failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_cipher_padding');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_cipher_padding failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_cipher_permitted_cipher_chain_mode (jazzhands)
CREATE TABLE jazzhands.val_cipher_permitted_cipher_chain_mode
(
	cipher	varchar(255) NOT NULL,
	cipher_chain_mode	varchar(255) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_cipher_permitted_cipher_chain_mode', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_cipher_permitted_cipher_chain_mode ADD CONSTRAINT pk_val_cipher_permitted_cipher_chain_mode PRIMARY KEY (cipher, cipher_chain_mode);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.val_cipher_permitted_cipher_chain_mode IS 'permitted chain modes for a given cipher.   valid cipher modes are specified elsewhere';
-- INDEXES
CREATE INDEX xifcipher_permitted_cipher_chain_cipher ON jazzhands.val_cipher_permitted_cipher_chain_mode USING btree (cipher);
CREATE INDEX xifv_permitted_cipher_chain_cipher_chain_mode ON jazzhands.val_cipher_permitted_cipher_chain_mode USING btree (cipher_chain_mode);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_cipher_permitted_cipher_chain_mode and jazzhands.val_encryption_method
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.val_encryption_method
--	ADD CONSTRAINT fk_enc_method_cipher_chain_mode
--	FOREIGN KEY (cipher, cipher_chain_mode) REFERENCES jazzhands.val_cipher_permitted_cipher_chain_mode(cipher, cipher_chain_mode);


-- FOREIGN KEYS TO
-- consider FK val_cipher_permitted_cipher_chain_mode and val_cipher
ALTER TABLE jazzhands.val_cipher_permitted_cipher_chain_mode
	ADD CONSTRAINT fk_cipher_permitted_cipher_chain_cipher
	FOREIGN KEY (cipher) REFERENCES jazzhands.val_cipher(cipher);
-- consider FK val_cipher_permitted_cipher_chain_mode and val_cipher_chain_mode
ALTER TABLE jazzhands.val_cipher_permitted_cipher_chain_mode
	ADD CONSTRAINT fk_v_permitted_cipher_chain_cipher_chain_mode
	FOREIGN KEY (cipher_chain_mode) REFERENCES jazzhands.val_cipher_chain_mode(cipher_chain_mode);

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_cipher_permitted_cipher_chain_mode');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_cipher_permitted_cipher_chain_mode  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_cipher_permitted_cipher_chain_mode');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_cipher_permitted_cipher_chain_mode');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_cipher_permitted_cipher_chain_mode');
--
-- Copying initialization data
--

INSERT INTO val_cipher_permitted_cipher_chain_mode (
cipher,cipher_chain_mode
) VALUES
	('none','none'),
	('AES','CBC')
;
-- DONE DEALING WITH TABLE val_cipher_permitted_cipher_chain_mode (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_cipher_permitted_cipher_chain_mode');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_cipher_permitted_cipher_chain_mode failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_cipher_permitted_cipher_chain_mode');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_cipher_permitted_cipher_chain_mode failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_cipher_permitted_cipher_padding (jazzhands)
CREATE TABLE jazzhands.val_cipher_permitted_cipher_padding
(
	cipher	varchar(255) NOT NULL,
	cipher_padding	varchar(255) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_cipher_permitted_cipher_padding', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_cipher_permitted_cipher_padding ADD CONSTRAINT pk_val_cipher_permitted_cipher_padding PRIMARY KEY (cipher, cipher_padding);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.val_cipher_permitted_cipher_padding IS 'Permitted padding algorithms for a given cipher/enryption algorithm
';
-- INDEXES
CREATE INDEX xifv_permitted_cipher_padding_cipher_padding ON jazzhands.val_cipher_permitted_cipher_padding USING btree (cipher_padding);
CREATE INDEX xifval_cipher_permitted_cipher_padding_cipher_padding ON jazzhands.val_cipher_permitted_cipher_padding USING btree (cipher);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK val_cipher_permitted_cipher_padding and val_cipher_padding
ALTER TABLE jazzhands.val_cipher_permitted_cipher_padding
	ADD CONSTRAINT fk_v_permitted_cipher_padding_cipher_padding
	FOREIGN KEY (cipher_padding) REFERENCES jazzhands.val_cipher_padding(cipher_padding);
-- consider FK val_cipher_permitted_cipher_padding and val_cipher
ALTER TABLE jazzhands.val_cipher_permitted_cipher_padding
	ADD CONSTRAINT fk_val_cipher_permitted_cipher_padding_cipher_padding
	FOREIGN KEY (cipher) REFERENCES jazzhands.val_cipher(cipher);

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_cipher_permitted_cipher_padding');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_cipher_permitted_cipher_padding  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_cipher_permitted_cipher_padding');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_cipher_permitted_cipher_padding');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_cipher_permitted_cipher_padding');
--
-- Copying initialization data
--

INSERT INTO val_cipher_permitted_cipher_padding (
cipher,cipher_padding
) VALUES
	('none','none'),
	('AES','PKCS5')
;
-- DONE DEALING WITH TABLE val_cipher_permitted_cipher_padding (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_cipher_permitted_cipher_padding');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_cipher_permitted_cipher_padding failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_cipher_permitted_cipher_padding');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_cipher_permitted_cipher_padding failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_cipher_permitted_key_size (jazzhands)
CREATE TABLE jazzhands.val_cipher_permitted_key_size
(
	cipher	varchar(255) NOT NULL,
	key_size	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_cipher_permitted_key_size', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_cipher_permitted_key_size ADD CONSTRAINT pk_val_cipher_permitted_key_size PRIMARY KEY (cipher, key_size);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.val_cipher_permitted_key_size IS 'Permitted key sizes for a given cipher/encryption algorithm
';
-- INDEXES
CREATE INDEX xifval_cipher_permitted_key_size_cipher ON jazzhands.val_cipher_permitted_key_size USING btree (cipher);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_cipher_permitted_key_size and jazzhands.val_encryption_method
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.val_encryption_method
--	ADD CONSTRAINT fk_enc_method_cipher_key_size
--	FOREIGN KEY (cipher, key_size) REFERENCES jazzhands.val_cipher_permitted_key_size(cipher, key_size);


-- FOREIGN KEYS TO
-- consider FK val_cipher_permitted_key_size and val_cipher
ALTER TABLE jazzhands.val_cipher_permitted_key_size
	ADD CONSTRAINT fk_val_cipher_permitted_key_size_cipher
	FOREIGN KEY (cipher) REFERENCES jazzhands.val_cipher(cipher);

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_cipher_permitted_key_size');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_cipher_permitted_key_size  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_cipher_permitted_key_size');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_cipher_permitted_key_size');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_cipher_permitted_key_size');
--
-- Copying initialization data
--

INSERT INTO val_cipher_permitted_key_size (
cipher,key_size
) VALUES
	('none','0'),
	('AES','128'),
	('AES','192'),
	('AES','256'),
	('RSA','1024'),
	('RSA','2048'),
	('RSA','4096')
;
-- DONE DEALING WITH TABLE val_cipher_permitted_key_size (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_cipher_permitted_key_size');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_cipher_permitted_key_size failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_cipher_permitted_key_size');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_cipher_permitted_key_size failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_cryptographic_hash_algorithm (jazzhands)
CREATE TABLE jazzhands.val_cryptographic_hash_algorithm
(
	cryptographic_hash_algorithm	varchar(255) NOT NULL,
	description	varchar(4096)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_cryptographic_hash_algorithm', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_cryptographic_hash_algorithm ADD CONSTRAINT pk_val_cryptographic_hash_algorithm PRIMARY KEY (cryptographic_hash_algorithm);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.val_cryptographic_hash_algorithm IS 'Algorithms used to create a cryptographic hash of text';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_cryptographic_hash_algorithm and jazzhands.val_encryption_method
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.val_encryption_method
--	ADD CONSTRAINT fk_enc_method_crypto_hash_algo
--	FOREIGN KEY (passphrase_cryptographic_hash_algorithm) REFERENCES jazzhands.val_cryptographic_hash_algorithm(cryptographic_hash_algorithm);

-- consider FK between val_cryptographic_hash_algorithm and jazzhands.val_x509_fingerprint_hash_algorithm
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.val_x509_fingerprint_hash_algorithm
--	ADD CONSTRAINT fk_x509_fprint_hash_algo_crypto_hash_algo
--	FOREIGN KEY (cryptographic_hash_algorithm) REFERENCES jazzhands.val_cryptographic_hash_algorithm(cryptographic_hash_algorithm);


-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_cryptographic_hash_algorithm');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_cryptographic_hash_algorithm  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_cryptographic_hash_algorithm');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_cryptographic_hash_algorithm');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_cryptographic_hash_algorithm');
--
-- Copying initialization data
--

INSERT INTO val_cryptographic_hash_algorithm (
cryptographic_hash_algorithm,description
) VALUES
	('none','not hashed'),
	('sha1','SHA1 hash'),
	('md5','MD5 hash'),
	('sha128','SHA128 hash'),
	('sha256','SHA256 hash')
;
-- DONE DEALING WITH TABLE val_cryptographic_hash_algorithm (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_cryptographic_hash_algorithm');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_cryptographic_hash_algorithm failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_cryptographic_hash_algorithm');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_cryptographic_hash_algorithm failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE val_encryption_method
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_encryption_method', 'val_encryption_method');

-- FOREIGN KEYS FROM
ALTER TABLE encryption_key DROP CONSTRAINT IF EXISTS fk_enckey_encmethod_val;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'val_encryption_method', newobject := 'val_encryption_method', newmap := '{"pk_val_encryption_method":{"columns":["encryption_method"],"def":"PRIMARY KEY (encryption_method)","deferrable":false,"deferred":false,"name":"pk_val_encryption_method","type":"p"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_encryption_method DROP CONSTRAINT IF EXISTS pk_val_encryption_method;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_encryption_method ON jazzhands.val_encryption_method;
DROP TRIGGER IF EXISTS trigger_audit_val_encryption_method ON jazzhands.val_encryption_method;
DROP FUNCTION IF EXISTS perform_audit_val_encryption_method();
-- default sequences associations and sequences (values rebuilt at end, if needed)
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'val_encryption_method', tags := ARRAY['table_val_encryption_method']);
---- BEGIN jazzhands_audit.val_encryption_method TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'val_encryption_method', tags := ARRAY['table_val_encryption_method']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'val_encryption_method', 'val_encryption_method');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'val_encryption_method');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.val_encryption_method DROP CONSTRAINT IF EXISTS val_encryption_method_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_val_encryption_method_pk_val_encryption_method";
DROP INDEX IF EXISTS "jazzhands_audit"."val_encryption_method_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."val_encryption_method_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."val_encryption_method_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.val_encryption_method ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.val_encryption_method TEARDOWN


ALTER TABLE val_encryption_method RENAME TO val_encryption_method_v96;
ALTER TABLE jazzhands_audit.val_encryption_method RENAME TO val_encryption_method_v96;

CREATE TABLE jazzhands.val_encryption_method
(
	encryption_method	varchar(50) NOT NULL,
	cipher	varchar(255) NOT NULL,
	key_size	integer NOT NULL,
	cipher_chain_mode	varchar(255) NOT NULL,
	cipher_padding	varchar(255) NOT NULL,
	passphrase_cryptographic_hash_algorithm	varchar(255) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_encryption_method', false);


-- BEGIN Manually written insert function
INSERT INTO val_encryption_method (
	encryption_method,
	cipher,		-- new column (cipher)
	key_size,		-- new column (key_size)
	cipher_chain_mode,		-- new column (cipher_chain_mode)
	cipher_padding,		-- new column (cipher_padding)
	passphrase_cryptographic_hash_algorithm,		-- new column (passphrase_cryptographic_hash_algorithm)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	encryption_method,
	CASE WHEN encryption_method = 'aes256-cbc-hmac-sha256-base64' THEN 'AES' ELSE 'none' END,		-- new column (cipher)
	CASE WHEN encryption_method = 'aes256-cbc-hmac-sha256-base64' THEN 256 ELSE 0 END,			-- new column (key_size)
	CASE WHEN encryption_method = 'aes256-cbc-hmac-sha256-base64' THEN 'CBC' ELSE 'none' END,		-- new column (cipher_chain_mode)
	CASE WHEN encryption_method = 'aes256-cbc-hmac-sha256-base64' THEN 'PKCS5' ELSE 'none' END,		-- new column (cipher_padding)
	CASE WHEN encryption_method = 'aes256-cbc-hmac-sha256-base64' THEN 'sha256' ELSE 'none' END,		-- new column (passphrase_cryptographic_hash_algorithm)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_encryption_method_v96;


INSERT INTO jazzhands_audit.val_encryption_method (
	encryption_method,
	cipher,		-- new column (cipher)
	key_size,		-- new column (key_size)
	cipher_chain_mode,		-- new column (cipher_chain_mode)
	cipher_padding,		-- new column (cipher_padding)
	passphrase_cryptographic_hash_algorithm,		-- new column (passphrase_cryptographic_hash_algorithm)
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
	"aud#actor",
	"aud#seq"
) SELECT
	encryption_method,
	CASE WHEN encryption_method = 'aes256-cbc-hmac-sha256-base64' THEN 'AES' ELSE 'none' END,		-- new column (cipher)
	CASE WHEN encryption_method = 'aes256-cbc-hmac-sha256-base64' THEN 256 ELSE 0 END,			-- new column (key_size)
	CASE WHEN encryption_method = 'aes256-cbc-hmac-sha256-base64' THEN 'CBC' ELSE 'none' END,		-- new column (cipher_chain_mode)
	CASE WHEN encryption_method = 'aes256-cbc-hmac-sha256-base64' THEN 'PKCS5' ELSE 'none' END,		-- new column (cipher_padding)
	CASE WHEN encryption_method = 'aes256-cbc-hmac-sha256-base64' THEN 'sha256' ELSE 'none' END,		-- new column (passphrase_cryptographic_hash_algorithm)
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
	jsonb_build_object('user', regexp_replace("aud#user", '/.*$', '')) || CASE WHEN "aud#user" ~ '/' THEN jsonb_build_object('appuser', regexp_replace("aud#user", '^[^/]*', '')) ELSE '{}' END,
	"aud#seq"
FROM jazzhands_audit.val_encryption_method_v96;



-- END Manually written insert function

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_encryption_method ADD CONSTRAINT pk_val_encryption_method PRIMARY KEY (encryption_method);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.val_encryption_method IS 'Describes the method of encryption.  Intended to use the format is the same as Kerberos uses such as in rfc3962 but it is possible to use different ones and it is possible two rows could describe the same algorithn used by different underlying algorithms.
';
COMMENT ON COLUMN jazzhands.val_encryption_method.encryption_method IS 'hashing algorithm used to encrypt the passphrase for use as the key to the underlying algorithm';
COMMENT ON COLUMN jazzhands.val_encryption_method.cipher IS 'cipher method (generous definition of cipher) for how data is encrypted';
COMMENT ON COLUMN jazzhands.val_encryption_method.key_size IS 'key size in bits; relates to cipher';
COMMENT ON COLUMN jazzhands.val_encryption_method.cipher_chain_mode IS 'if applicable, cipher chain mode used';
COMMENT ON COLUMN jazzhands.val_encryption_method.cipher_padding IS 'if applicable, padding used to fill out (or augent) blocks based on the undelying cipher.';
COMMENT ON COLUMN jazzhands.val_encryption_method.passphrase_cryptographic_hash_algorithm IS 'The known passphrase is hashed using this algorithm and that is used as the encrpytion key. ';
-- INDEXES
CREATE INDEX xifenc_method_cipher_chain_mode ON jazzhands.val_encryption_method USING btree (cipher, cipher_chain_mode);
CREATE INDEX xifenc_method_cipher_key_size ON jazzhands.val_encryption_method USING btree (key_size, cipher);
CREATE INDEX xifenc_method_cipher_padding ON jazzhands.val_encryption_method USING btree (cipher_padding);
CREATE INDEX xifenc_method_crypto_hash_algo ON jazzhands.val_encryption_method USING btree (passphrase_cryptographic_hash_algorithm);
CREATE INDEX xifenc_mthod_cipher ON jazzhands.val_encryption_method USING btree (cipher);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_encryption_method and jazzhands.encryption_key
ALTER TABLE jazzhands.encryption_key
	ADD CONSTRAINT fk_enckey_encmethod_val
	FOREIGN KEY (encryption_method) REFERENCES jazzhands.val_encryption_method(encryption_method);

-- FOREIGN KEYS TO
-- consider FK val_encryption_method and val_cipher_permitted_cipher_chain_mode
ALTER TABLE jazzhands.val_encryption_method
	ADD CONSTRAINT fk_enc_method_cipher_chain_mode
	FOREIGN KEY (cipher, cipher_chain_mode) REFERENCES jazzhands.val_cipher_permitted_cipher_chain_mode(cipher, cipher_chain_mode);
-- consider FK val_encryption_method and val_cipher_permitted_key_size
ALTER TABLE jazzhands.val_encryption_method
	ADD CONSTRAINT fk_enc_method_cipher_key_size
	FOREIGN KEY (cipher, key_size) REFERENCES jazzhands.val_cipher_permitted_key_size(cipher, key_size);
-- consider FK val_encryption_method and val_cipher_padding
ALTER TABLE jazzhands.val_encryption_method
	ADD CONSTRAINT fk_enc_method_cipher_padding
	FOREIGN KEY (cipher_padding) REFERENCES jazzhands.val_cipher_padding(cipher_padding);
-- consider FK val_encryption_method and val_cryptographic_hash_algorithm
ALTER TABLE jazzhands.val_encryption_method
	ADD CONSTRAINT fk_enc_method_crypto_hash_algo
	FOREIGN KEY (passphrase_cryptographic_hash_algorithm) REFERENCES jazzhands.val_cryptographic_hash_algorithm(cryptographic_hash_algorithm);
-- consider FK val_encryption_method and val_cipher
ALTER TABLE jazzhands.val_encryption_method
	ADD CONSTRAINT fk_enc_mthod_cipher
	FOREIGN KEY (cipher) REFERENCES jazzhands.val_cipher(cipher);

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_encryption_method');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_encryption_method  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_encryption_method');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_encryption_method');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_encryption_method');
DROP TABLE IF EXISTS val_encryption_method_v96;
DROP TABLE IF EXISTS jazzhands_audit.val_encryption_method_v96;
-- DONE DEALING WITH TABLE val_encryption_method (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_encryption_method');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_encryption_method failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_encryption_method');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_encryption_method failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE val_filesystem_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_filesystem_type', 'val_filesystem_type');

-- FOREIGN KEYS FROM
ALTER TABLE logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_fstype;
ALTER TABLE val_logical_volume_property DROP CONSTRAINT IF EXISTS fk_val_lvol_prop_fstype;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'val_filesystem_type', newobject := 'val_filesystem_type', newmap := '{"pk_val_filesytem_type":{"columns":["filesystem_type"],"def":"PRIMARY KEY (filesystem_type)","deferrable":false,"deferred":false,"name":"pk_val_filesytem_type","type":"p"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_filesystem_type DROP CONSTRAINT IF EXISTS pk_val_filesytem_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_filesystem_type ON jazzhands.val_filesystem_type;
DROP TRIGGER IF EXISTS trigger_audit_val_filesystem_type ON jazzhands.val_filesystem_type;
DROP FUNCTION IF EXISTS perform_audit_val_filesystem_type();
-- default sequences associations and sequences (values rebuilt at end, if needed)
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'val_filesystem_type', tags := ARRAY['table_val_filesystem_type']);
---- BEGIN jazzhands_audit.val_filesystem_type TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'val_filesystem_type', tags := ARRAY['table_val_filesystem_type']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'val_filesystem_type', 'val_filesystem_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'val_filesystem_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.val_filesystem_type DROP CONSTRAINT IF EXISTS val_filesystem_type_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_val_filesystem_type_pk_val_filesytem_type";
DROP INDEX IF EXISTS "jazzhands_audit"."val_filesystem_type_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."val_filesystem_type_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."val_filesystem_type_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.val_filesystem_type ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.val_filesystem_type TEARDOWN


ALTER TABLE val_filesystem_type RENAME TO val_filesystem_type_v96;
ALTER TABLE jazzhands_audit.val_filesystem_type RENAME TO val_filesystem_type_v96;

CREATE TABLE jazzhands.val_filesystem_type
(
	filesystem_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	permit_mountpoint	character(10) NOT NULL,
	permit_filesystem_label	character(10) NOT NULL,
	permit_filesystem_serial	character(10) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_filesystem_type', false);
ALTER TABLE val_filesystem_type
	ALTER permit_mountpoint
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_filesystem_type
	ALTER permit_filesystem_label
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_filesystem_type
	ALTER permit_filesystem_serial
	SET DEFAULT 'PROHIBITED'::bpchar;

INSERT INTO val_filesystem_type (
	filesystem_type,
	description,
	permit_mountpoint,		-- new column (permit_mountpoint)
	permit_filesystem_label,		-- new column (permit_filesystem_label)
	permit_filesystem_serial,		-- new column (permit_filesystem_serial)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	filesystem_type,
	description,
	'PROHIBITED'::bpchar,		-- new column (permit_mountpoint)
	'PROHIBITED'::bpchar,		-- new column (permit_filesystem_label)
	'PROHIBITED'::bpchar,		-- new column (permit_filesystem_serial)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_filesystem_type_v96;


INSERT INTO jazzhands_audit.val_filesystem_type (
	filesystem_type,
	description,
	permit_mountpoint,		-- new column (permit_mountpoint)
	permit_filesystem_label,		-- new column (permit_filesystem_label)
	permit_filesystem_serial,		-- new column (permit_filesystem_serial)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#actor",		-- new column (aud#actor)
	"aud#seq"
) SELECT
	filesystem_type,
	description,
	NULL,		-- new column (permit_mountpoint)
	NULL,		-- new column (permit_filesystem_label)
	NULL,		-- new column (permit_filesystem_serial)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	NULL,		-- new column (aud#actor)
	"aud#seq"
FROM jazzhands_audit.val_filesystem_type_v96;

ALTER TABLE jazzhands.val_filesystem_type
	ALTER permit_mountpoint
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_filesystem_type
	ALTER permit_filesystem_label
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_filesystem_type
	ALTER permit_filesystem_serial
	SET DEFAULT 'PROHIBITED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_filesystem_type ADD CONSTRAINT pk_val_filesytem_type PRIMARY KEY (filesystem_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_filesystem_type and jazzhands.filesystem
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.filesystem
--	ADD CONSTRAINT fk_filesystem_val_filesystem_type
--	FOREIGN KEY (filesystem_type) REFERENCES jazzhands.val_filesystem_type(filesystem_type);

-- consider FK between val_filesystem_type and jazzhands.logical_volume
ALTER TABLE jazzhands.logical_volume
	ADD CONSTRAINT fk_logvol_fstype
	FOREIGN KEY (filesystem_type) REFERENCES jazzhands.val_filesystem_type(filesystem_type) DEFERRABLE;
-- consider FK between val_filesystem_type and jazzhands.val_logical_volume_property
ALTER TABLE jazzhands.val_logical_volume_property
	ADD CONSTRAINT fk_val_lvol_prop_fstype
	FOREIGN KEY (filesystem_type) REFERENCES jazzhands.val_filesystem_type(filesystem_type);

-- FOREIGN KEYS TO

-- TRIGGERS
-- considering NEW jazzhands.validate_filesystem_type
CREATE OR REPLACE FUNCTION jazzhands.validate_filesystem_type()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	PERFORM	property_utils.validate_filesystem(f)
	FROM filesystem f
	WHERE f.filesystem_type = NEW.filesystem_type;
	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.validate_filesystem_type() FROM public;
CREATE CONSTRAINT TRIGGER trigger_validate_filesystem_type AFTER INSERT OR UPDATE OF filesystem_type, permit_mountpoint, permit_filesystem_label, permit_filesystem_serial ON jazzhands.val_filesystem_type NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_filesystem_type();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_filesystem_type');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_filesystem_type  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_filesystem_type');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_filesystem_type');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_filesystem_type');
DROP TABLE IF EXISTS val_filesystem_type_v96;
DROP TABLE IF EXISTS jazzhands_audit.val_filesystem_type_v96;
-- DONE DEALING WITH TABLE val_filesystem_type (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_filesystem_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_filesystem_type failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_filesystem_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_filesystem_type failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE val_x509_fingerprint_hash_algorithm
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_x509_fingerprint_hash_algorithm', 'val_x509_fingerprint_hash_algorithm');

-- FOREIGN KEYS FROM
ALTER TABLE public_key_hash_hash DROP CONSTRAINT IF EXISTS fk_public_key_hash_hash_algorithm;
ALTER TABLE x509_signed_certificate_fingerprint DROP CONSTRAINT IF EXISTS fk_x509_signed_cert_fprint_algorithm;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'val_x509_fingerprint_hash_algorithm', newobject := 'val_x509_fingerprint_hash_algorithm', newmap := '{"pk_val_x509_fingerprint_hash_algorithm":{"columns":["cryptographic_hash_algorithm","x509_fingerprint_hash_algorighm"],"def":"PRIMARY KEY (cryptographic_hash_algorithm, x509_fingerprint_hash_algorighm)","deferrable":false,"deferred":false,"name":"pk_val_x509_fingerprint_hash_algorithm","type":"p"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_x509_fingerprint_hash_algorithm DROP CONSTRAINT IF EXISTS pk_val_x509_fingerprint_hash_algorithm;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_x509_fingerprint_hash_algorithm ON jazzhands.val_x509_fingerprint_hash_algorithm;
DROP TRIGGER IF EXISTS trigger_audit_val_x509_fingerprint_hash_algorithm ON jazzhands.val_x509_fingerprint_hash_algorithm;
DROP FUNCTION IF EXISTS perform_audit_val_x509_fingerprint_hash_algorithm();
-- default sequences associations and sequences (values rebuilt at end, if needed)
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'val_x509_fingerprint_hash_algorithm', tags := ARRAY['table_val_x509_fingerprint_hash_algorithm']);
---- BEGIN jazzhands_audit.val_x509_fingerprint_hash_algorithm TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'val_x509_fingerprint_hash_algorithm', tags := ARRAY['table_val_x509_fingerprint_hash_algorithm']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'val_x509_fingerprint_hash_algorithm', 'val_x509_fingerprint_hash_algorithm');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'val_x509_fingerprint_hash_algorithm');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.val_x509_fingerprint_hash_algorithm DROP CONSTRAINT IF EXISTS val_x509_fingerprint_hash_algorithm_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_0val_x509_fingerprint_hash_algorithm_pk_val_x509_fingerprin";
DROP INDEX IF EXISTS "jazzhands_audit"."val_x509_fingerprint_hash_algorithm_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."val_x509_fingerprint_hash_algorithm_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."val_x509_fingerprint_hash_algorithm_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.val_x509_fingerprint_hash_algorithm ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.val_x509_fingerprint_hash_algorithm TEARDOWN


ALTER TABLE val_x509_fingerprint_hash_algorithm RENAME TO val_x509_fingerprint_hash_algorithm_v96;
ALTER TABLE jazzhands_audit.val_x509_fingerprint_hash_algorithm RENAME TO val_x509_fingerprint_hash_algorithm_v96;

CREATE TABLE jazzhands.val_x509_fingerprint_hash_algorithm
(
	cryptographic_hash_algorithm	varchar(255) NOT NULL,
	x509_fingerprint_hash_algorighm	varchar(255) NOT NULL,
	description	varchar(4096)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_x509_fingerprint_hash_algorithm', false);


-- BEGIN Manually written insert function
--
-- Note that the trigger taht deals with making sure only one of the first
-- two is set is not in place yet.
--
INSERT INTO val_x509_fingerprint_hash_algorithm (
	cryptographic_hash_algorithm,		-- new column (cryptographic_hash_algorithm)
	x509_fingerprint_hash_algorighm,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	x509_fingerprint_hash_algorighm,		-- new column (cryptographic_hash_algorithm)
	x509_fingerprint_hash_algorighm,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_x509_fingerprint_hash_algorithm_v96;


INSERT INTO jazzhands_audit.val_x509_fingerprint_hash_algorithm (
	cryptographic_hash_algorithm,		-- new column (cryptographic_hash_algorithm)
	x509_fingerprint_hash_algorighm,
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
	"aud#actor",
	"aud#seq"
) SELECT
	x509_fingerprint_hash_algorighm,		-- new column (cryptographic_hash_algorithm)
	x509_fingerprint_hash_algorighm,
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
	jsonb_build_object('user', regexp_replace("aud#user", '/.*$', '')) || CASE WHEN "aud#user" ~ '/' THEN jsonb_build_object('appuser', regexp_replace("aud#user", '^[^/]*', '')) ELSE '{}' END,
	"aud#seq"
FROM jazzhands_audit.val_x509_fingerprint_hash_algorithm_v96;



-- END Manually written insert function

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_x509_fingerprint_hash_algorithm ADD CONSTRAINT pk_val_x509_fingerprint_hash_algorithm PRIMARY KEY (cryptographic_hash_algorithm, x509_fingerprint_hash_algorighm);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.val_x509_fingerprint_hash_algorithm IS 'Algorithms that can be used to generate fingerprints for x509 certificate hash.  Also usable for other hashes in PKI in the schema.';
COMMENT ON COLUMN jazzhands.val_x509_fingerprint_hash_algorithm.x509_fingerprint_hash_algorighm IS 'This misspelled column is going away in a future version.';
-- INDEXES
CREATE INDEX xifx509_fprint_hash_algo_crypto_hash_algo ON jazzhands.val_x509_fingerprint_hash_algorithm USING btree (cryptographic_hash_algorithm);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_x509_fingerprint_hash_algorithm and jazzhands.public_key_hash_hash
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.public_key_hash_hash
--	ADD CONSTRAINT fk_public_key_hash_hash_algorithm
--	FOREIGN KEY (cryptographic_hash_algorithm, x509_fingerprint_hash_algorighm) REFERENCES jazzhands.val_x509_fingerprint_hash_algorithm(cryptographic_hash_algorithm, x509_fingerprint_hash_algorighm);

-- consider FK between val_x509_fingerprint_hash_algorithm and jazzhands.x509_signed_certificate_fingerprint
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.x509_signed_certificate_fingerprint
--	ADD CONSTRAINT fk_x509_signed_cert_fprint_algorithm
--	FOREIGN KEY (cryptographic_hash_algorithm, x509_fingerprint_hash_algorighm) REFERENCES jazzhands.val_x509_fingerprint_hash_algorithm(cryptographic_hash_algorithm, x509_fingerprint_hash_algorighm);


-- FOREIGN KEYS TO
-- consider FK val_x509_fingerprint_hash_algorithm and val_cryptographic_hash_algorithm
ALTER TABLE jazzhands.val_x509_fingerprint_hash_algorithm
	ADD CONSTRAINT fk_x509_fprint_hash_algo_crypto_hash_algo
	FOREIGN KEY (cryptographic_hash_algorithm) REFERENCES jazzhands.val_cryptographic_hash_algorithm(cryptographic_hash_algorithm);

-- TRIGGERS
-- considering NEW jazzhands.check_fingerprint_hash_algorithm
CREATE OR REPLACE FUNCTION jazzhands.check_fingerprint_hash_algorithm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
BEGIN
	--
	-- Give a release to deal with misspelling
	--
	IF TG_OP = 'INSERT' THEN
		IF NEW.x509_fingerprint_hash_algorighm IS NOT NULL AND NEW.cryptographic_hash_algorithm IS NOT NULL
		THEN
			RAISE EXCEPTION 'Should only set cryptographic_hash_algorithm'
				USING ERRCODE = 'invalid_parameter_value';
		ELSIF NEW.x509_fingerprint_hash_algorighm IS NULL THEN
			NEW.x509_fingerprint_hash_algorighm := NEW.cryptographic_hash_algorithm;
		ELSE
			NEW.cryptographic_hash_algorithm := NEW.x509_fingerprint_hash_algorighm;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.x509_fingerprint_hash_algorighm IS DISTINCT FROM NEW.x509_fingerprint_hash_algorighm AND
			OLD.x509_fingerprint_hash_algorighm IS DISTINCT FROM NEW.cryptographic_hash_algorithm
		THEN
			RAISE EXCEPTION 'Should only set cryptographic_hash_algorithm'
				USING ERRCODE = 'invalid_parameter_value';
		ELSIF OLD.x509_fingerprint_hash_algorighm IS DISTINCT FROM NEW.cryptographic_hash_algorithm THEN
			NEW.x509_fingerprint_hash_algorighm := NEW.cryptographic_hash_algorithm;
		ELSE
			NEW.cryptographic_hash_algorithm := NEW.x509_fingerprint_hash_algorighm;
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.check_fingerprint_hash_algorithm() FROM public;
CREATE TRIGGER trigger_fingerprint_hash_algorithm BEFORE INSERT OR UPDATE OF x509_fingerprint_hash_algorighm, cryptographic_hash_algorithm ON jazzhands.val_x509_fingerprint_hash_algorithm FOR EACH ROW EXECUTE FUNCTION jazzhands.check_fingerprint_hash_algorithm();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_x509_fingerprint_hash_algorithm');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_x509_fingerprint_hash_algorithm  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_x509_fingerprint_hash_algorithm');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_x509_fingerprint_hash_algorithm');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_x509_fingerprint_hash_algorithm');
DROP TABLE IF EXISTS val_x509_fingerprint_hash_algorithm_v96;
DROP TABLE IF EXISTS jazzhands_audit.val_x509_fingerprint_hash_algorithm_v96;
-- DONE DEALING WITH TABLE val_x509_fingerprint_hash_algorithm (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_x509_fingerprint_hash_algorithm');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_x509_fingerprint_hash_algorithm failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_x509_fingerprint_hash_algorithm');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_x509_fingerprint_hash_algorithm failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE account_authentication_log

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.account_authentication_log DROP CONSTRAINT IF EXISTS fk_acctauthlog_accid;
ALTER TABLE jazzhands.account_authentication_log DROP CONSTRAINT IF EXISTS fk_auth_resource;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands',  object := 'account_authentication_log');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.account_authentication_log DROP CONSTRAINT IF EXISTS pk_account_auth_log;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xieacctauthlog_ts_arsrc";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_account_authentication_log ON jazzhands.account_authentication_log;
DROP TRIGGER IF EXISTS trigger_audit_account_authentication_log ON jazzhands.account_authentication_log;
DROP FUNCTION IF EXISTS perform_audit_account_authentication_log();
-- default sequences associations and sequences (values rebuilt at end, if needed)
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'account_authentication_log', tags := ARRAY['table_account_authentication_log']);
---- BEGIN jazzhands_audit.account_authentication_log TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'account_authentication_log', tags := ARRAY['table_account_authentication_log']);

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'account_authentication_log');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.account_authentication_log DROP CONSTRAINT IF EXISTS account_authentication_log_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."account_authentication_log_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."account_authentication_log_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."account_authentication_log_aud#txid_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_account_authentication_log_pk_account_auth_log";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.account_authentication_log ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.account_authentication_log TEARDOWN


ALTER TABLE account_authentication_log RENAME TO account_authentication_log_v96;
ALTER TABLE jazzhands_audit.account_authentication_log RENAME TO account_authentication_log_v96;

DROP TABLE IF EXISTS account_authentication_log_v96;
DROP TABLE IF EXISTS jazzhands_audit.account_authentication_log_v96;
-- DONE DEALING WITH OLD TABLE account_authentication_log (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('account_authentication_log');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old account_authentication_log failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('account_authentication_log');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped account_authentication_log failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE block_storage_device_virtual_component (jazzhands)
CREATE TABLE jazzhands.block_storage_device_virtual_component
(
	block_storage_device_id	integer NOT NULL,
	component_id	integer NOT NULL,
	component_type_id	integer NOT NULL,
	is_virtual_component	boolean  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'block_storage_device_virtual_component', true);
ALTER TABLE block_storage_device_virtual_component
	ALTER is_virtual_component
	SET DEFAULT true;
ALTER TABLE jazzhands.block_storage_device_virtual_component
	ALTER is_virtual_component
	SET DEFAULT true;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.block_storage_device_virtual_component ADD CONSTRAINT ak_block_storage_device_virtual_component_component_id UNIQUE (component_id);
ALTER TABLE jazzhands.block_storage_device_virtual_component ADD CONSTRAINT xpkblock_storage_device_virtual_component PRIMARY KEY (block_storage_device_id);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.block_storage_device_virtual_component IS 'Map a block storage device in a parent to the virtual component of a child, such as for virtual disks';
-- INDEXES
CREATE UNIQUE INDEX xifblock_storage_device_virtual_component_block_storage_device_ ON jazzhands.block_storage_device_virtual_component USING btree (block_storage_device_id);
CREATE INDEX xifblock_storage_device_virtual_component_component ON jazzhands.block_storage_device_virtual_component USING btree (component_id, component_type_id);
CREATE INDEX xifblock_storage_device_virtual_component_component_type ON jazzhands.block_storage_device_virtual_component USING btree (component_type_id, is_virtual_component);

-- CHECK CONSTRAINTS
ALTER TABLE jazzhands.block_storage_device_virtual_component ADD CONSTRAINT ckc_force_true_2019398784
	CHECK ((is_virtual_component = true));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK block_storage_device_virtual_component and block_storage_device
ALTER TABLE jazzhands.block_storage_device_virtual_component
	ADD CONSTRAINT fk_block_storage_device_virtual_component_block_storage_device_
	FOREIGN KEY (block_storage_device_id) REFERENCES jazzhands.block_storage_device(block_storage_device_id);
-- consider FK block_storage_device_virtual_component and component
ALTER TABLE jazzhands.block_storage_device_virtual_component
	ADD CONSTRAINT fk_block_storage_device_virtual_component_component
	FOREIGN KEY (component_id, component_type_id) REFERENCES jazzhands.component(component_id, component_type_id);
-- consider FK block_storage_device_virtual_component and component_type
ALTER TABLE jazzhands.block_storage_device_virtual_component
	ADD CONSTRAINT fk_block_storage_device_virtual_component_component_type
	FOREIGN KEY (component_type_id, is_virtual_component) REFERENCES jazzhands.component_type(component_type_id, is_virtual_component);

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('block_storage_device_virtual_component');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for block_storage_device_virtual_component  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'block_storage_device_virtual_component');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'block_storage_device_virtual_component');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'block_storage_device_virtual_component');
-- DONE DEALING WITH TABLE block_storage_device_virtual_component (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('block_storage_device_virtual_component');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old block_storage_device_virtual_component failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('block_storage_device_virtual_component');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new block_storage_device_virtual_component failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE encrypted_block_storage_device (jazzhands)
CREATE TABLE jazzhands.encrypted_block_storage_device
(
	encrypted_block_storage_device_id	integer NOT NULL,
	block_storage_device_id	integer  NULL,
	block_storage_device_encryption_system	varchar(255) NOT NULL,
	encryption_key_id	integer NOT NULL,
	offset_sector	integer  NULL,
	sector_size	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'encrypted_block_storage_device', true);
ALTER TABLE encrypted_block_storage_device
	ALTER COLUMN encrypted_block_storage_device_id
	ADD GENERATED BY DEFAULT AS IDENTITY;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.encrypted_block_storage_device ADD CONSTRAINT pk_encrypted_block_storage_device PRIMARY KEY (encrypted_block_storage_device_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifenc_block_storage_device_block_storage_device ON jazzhands.encrypted_block_storage_device USING btree (block_storage_device_id);
CREATE INDEX xifenc_block_storage_device_encryption_key_id ON jazzhands.encrypted_block_storage_device USING btree (encryption_key_id);
CREATE INDEX xifl_enc_blk_storage_device_val_block_stg_dev_enc_type ON jazzhands.encrypted_block_storage_device USING btree (block_storage_device_encryption_system);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between encrypted_block_storage_device and jazzhands.block_storage_device
ALTER TABLE jazzhands.block_storage_device
	ADD CONSTRAINT fk_block_storage_device_enc_blk_stroage_device
	FOREIGN KEY (encrypted_block_storage_device_id) REFERENCES jazzhands.encrypted_block_storage_device(encrypted_block_storage_device_id);

-- FOREIGN KEYS TO
-- consider FK encrypted_block_storage_device and block_storage_device
ALTER TABLE jazzhands.encrypted_block_storage_device
	ADD CONSTRAINT fk_enc_block_storage_device_block_storage_device
	FOREIGN KEY (block_storage_device_id) REFERENCES jazzhands.block_storage_device(block_storage_device_id);
-- consider FK encrypted_block_storage_device and encryption_key
ALTER TABLE jazzhands.encrypted_block_storage_device
	ADD CONSTRAINT fk_enc_block_storage_device_encryption_key_id
	FOREIGN KEY (encryption_key_id) REFERENCES jazzhands.encryption_key(encryption_key_id);
-- consider FK encrypted_block_storage_device and val_block_storage_device_encryption_system
ALTER TABLE jazzhands.encrypted_block_storage_device
	ADD CONSTRAINT fl_enc_blk_storage_device_val_block_stg_dev_enc_type
	FOREIGN KEY (block_storage_device_encryption_system) REFERENCES jazzhands.val_block_storage_device_encryption_system(block_storage_device_encryption_system);

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('encrypted_block_storage_device');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for encrypted_block_storage_device  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'encrypted_block_storage_device');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'encrypted_block_storage_device');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'encrypted_block_storage_device');
-- DONE DEALING WITH TABLE encrypted_block_storage_device (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('encrypted_block_storage_device');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old encrypted_block_storage_device failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('encrypted_block_storage_device');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new encrypted_block_storage_device failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE filesystem (jazzhands)
CREATE TABLE jazzhands.filesystem
(
	block_storage_device_id	integer NOT NULL,
	device_id	integer NOT NULL,
	filesystem_type	varchar(50)  NULL,
	mountpoint	varchar(50)  NULL,
	filesystem_label	varchar(255)  NULL,
	filesystem_serial	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'filesystem', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.filesystem ADD CONSTRAINT ak_filesystem_block_storage_device_id UNIQUE (block_storage_device_id);
ALTER TABLE jazzhands.filesystem ADD CONSTRAINT pk_filesystem PRIMARY KEY (block_storage_device_id, device_id);

-- Table/Column Comments
COMMENT ON COLUMN jazzhands.filesystem.device_id IS 'Device that has the block device on it.';
-- INDEXES
CREATE UNIQUE INDEX xiffilesystem_block_storage_device_id ON jazzhands.filesystem USING btree (block_storage_device_id, device_id);
CREATE INDEX xiffilesystem_val_filesystem_type ON jazzhands.filesystem USING btree (filesystem_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK filesystem and block_storage_device
ALTER TABLE jazzhands.filesystem
	ADD CONSTRAINT fk_filesystem_block_storage_device_id
	FOREIGN KEY (block_storage_device_id, device_id) REFERENCES jazzhands.block_storage_device(block_storage_device_id, device_id);
-- consider FK filesystem and val_filesystem_type
ALTER TABLE jazzhands.filesystem
	ADD CONSTRAINT fk_filesystem_val_filesystem_type
	FOREIGN KEY (filesystem_type) REFERENCES jazzhands.val_filesystem_type(filesystem_type);

-- TRIGGERS
-- considering NEW jazzhands.validate_filesystem
CREATE OR REPLACE FUNCTION jazzhands.validate_filesystem()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	PERFORM property_utils.validate_filesystem(NEW);
	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.validate_filesystem() FROM public;
CREATE CONSTRAINT TRIGGER trigger_validate_filesystem AFTER INSERT OR UPDATE OF filesystem_type, mountpoint, filesystem_label, filesystem_serial ON jazzhands.filesystem NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_filesystem();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('filesystem');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for filesystem  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'filesystem');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'filesystem');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'filesystem');
-- DONE DEALING WITH TABLE filesystem (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('filesystem');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old filesystem failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('filesystem');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new filesystem failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
-- Processing minor changes to netblock
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'netblock');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'netblock');
ALTER TABLE "jazzhands"."netblock" ALTER COLUMN "netblock_status" SET DEFAULT 'Alloocated'::character varying;
ALTER TABLE component_type
	DROP CONSTRAINT IF EXISTS ckc_virtual_rack_mount_check_1365025208;
ALTER TABLE component_type
ADD CONSTRAINT ckc_virtual_rack_mount_check_1365025208
	CHECK ((((is_virtual_component = true) AND (is_rack_mountable = false)) OR (is_virtual_component = false)));

ALTER TABLE device
	DROP CONSTRAINT IF EXISTS ckc_rack_location_component_non_virtual_474624417;
ALTER TABLE device
ADD CONSTRAINT ckc_rack_location_component_non_virtual_474624417
	CHECK ((((rack_location_id IS NOT NULL) AND (component_id IS NOT NULL) AND (NOT is_virtual_device)) OR (rack_location_id IS NULL)));

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE public_key_hash_hash
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'public_key_hash_hash', 'public_key_hash_hash');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.public_key_hash_hash DROP CONSTRAINT IF EXISTS fk_public_key_hash_hash_algorithm;
ALTER TABLE jazzhands.public_key_hash_hash DROP CONSTRAINT IF EXISTS fk_public_key_hash_hash_hash;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'public_key_hash_hash', newobject := 'public_key_hash_hash', newmap := '{"ak_public_key_hash_method_hash":{"columns":["calculated_hash"],"def":"UNIQUE (calculated_hash)","deferrable":false,"deferred":false,"name":"ak_public_key_hash_method_hash","type":"u"},"pk_public_key_hash_hash":{"columns":["public_key_hash_id","x509_fingerprint_hash_algorighm","cryptographic_hash_algorithm"],"def":"PRIMARY KEY (public_key_hash_id, x509_fingerprint_hash_algorighm, cryptographic_hash_algorithm)","deferrable":false,"deferred":false,"name":"pk_public_key_hash_hash","type":"p"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.public_key_hash_hash DROP CONSTRAINT IF EXISTS pk_public_key_hash_hash;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifpublic_key_hash_hash_algorithm";
DROP INDEX IF EXISTS "jazzhands"."xifpublic_key_hash_hash_hash";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_public_key_hash_hash ON jazzhands.public_key_hash_hash;
DROP TRIGGER IF EXISTS trigger_audit_public_key_hash_hash ON jazzhands.public_key_hash_hash;
DROP FUNCTION IF EXISTS perform_audit_public_key_hash_hash();
-- default sequences associations and sequences (values rebuilt at end, if needed)
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'public_key_hash_hash', tags := ARRAY['table_public_key_hash_hash']);
---- BEGIN jazzhands_audit.public_key_hash_hash TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'public_key_hash_hash', tags := ARRAY['table_public_key_hash_hash']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'public_key_hash_hash', 'public_key_hash_hash');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'public_key_hash_hash');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.public_key_hash_hash DROP CONSTRAINT IF EXISTS public_key_hash_hash_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_public_key_hash_hash_pk_public_key_hash_hash";
DROP INDEX IF EXISTS "jazzhands_audit"."public_key_hash_hash_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."public_key_hash_hash_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."public_key_hash_hash_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.public_key_hash_hash ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.public_key_hash_hash TEARDOWN


ALTER TABLE public_key_hash_hash RENAME TO public_key_hash_hash_v96;
ALTER TABLE jazzhands_audit.public_key_hash_hash RENAME TO public_key_hash_hash_v96;

CREATE TABLE jazzhands.public_key_hash_hash
(
	public_key_hash_id	integer NOT NULL,
	x509_fingerprint_hash_algorighm	varchar(255) NOT NULL,
	cryptographic_hash_algorithm	varchar(255) NOT NULL,
	calculated_hash	varchar(255) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'public_key_hash_hash', false);


-- BEGIN Manually written insert function
INSERT INTO public_key_hash_hash (
	public_key_hash_id,
	x509_fingerprint_hash_algorighm,
	cryptographic_hash_algorithm,		-- new column (cryptographic_hash_algorithm)
	calculated_hash,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	public_key_hash_id,
	x509_fingerprint_hash_algorighm,
	x509_fingerprint_hash_algorighm,		-- new column (cryptographic_hash_algorithm)
	calculated_hash,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM public_key_hash_hash_v96;


INSERT INTO jazzhands_audit.public_key_hash_hash (
	public_key_hash_id,
	x509_fingerprint_hash_algorighm,
	cryptographic_hash_algorithm,		-- new column (cryptographic_hash_algorithm)
	calculated_hash,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#actor",
	"aud#seq"
) SELECT
	public_key_hash_id,
	x509_fingerprint_hash_algorighm,
	x509_fingerprint_hash_algorighm,		-- new column (cryptographic_hash_algorithm)
	calculated_hash,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	jsonb_build_object('user', regexp_replace("aud#user", '/.*$', '')) || CASE WHEN "aud#user" ~ '/' THEN jsonb_build_object('appuser', regexp_replace("aud#user", '^[^/]*', '')) ELSE '{}' END,
	"aud#seq"
FROM jazzhands_audit.public_key_hash_hash_v96;



-- END Manually written insert function

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.public_key_hash_hash ADD CONSTRAINT ak_public_key_hash_method_hash UNIQUE (calculated_hash);
ALTER TABLE jazzhands.public_key_hash_hash ADD CONSTRAINT pk_public_key_hash_hash PRIMARY KEY (public_key_hash_id, x509_fingerprint_hash_algorighm, cryptographic_hash_algorithm);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.public_key_hash_hash IS 'Cryptographic hash of the public key portain of a PKI certificate.  This can be used to tie together signed certificates, private keys, and certificaate signing requests.
';
COMMENT ON COLUMN jazzhands.public_key_hash_hash.public_key_hash_id IS 'Used as a unique id that identifies hashes on the same public key.  This is primarily used to correlate private keys and x509 certicates.';
COMMENT ON COLUMN jazzhands.public_key_hash_hash.calculated_hash IS 'hashing algorithm run over the der form of the public key components, which are algorithm independent.';
-- INDEXES
CREATE INDEX xifpublic_key_hash_hash_algorithm ON jazzhands.public_key_hash_hash USING btree (x509_fingerprint_hash_algorighm, cryptographic_hash_algorithm);
CREATE INDEX xifpublic_key_hash_hash_hash ON jazzhands.public_key_hash_hash USING btree (public_key_hash_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK public_key_hash_hash and val_x509_fingerprint_hash_algorithm
ALTER TABLE jazzhands.public_key_hash_hash
	ADD CONSTRAINT fk_public_key_hash_hash_algorithm
	FOREIGN KEY (cryptographic_hash_algorithm, x509_fingerprint_hash_algorighm) REFERENCES jazzhands.val_x509_fingerprint_hash_algorithm(cryptographic_hash_algorithm, x509_fingerprint_hash_algorighm);
-- consider FK public_key_hash_hash and public_key_hash
ALTER TABLE jazzhands.public_key_hash_hash
	ADD CONSTRAINT fk_public_key_hash_hash_hash
	FOREIGN KEY (public_key_hash_id) REFERENCES jazzhands.public_key_hash(public_key_hash_id);

-- TRIGGERS
-- considering NEW jazzhands.check_fingerprint_hash_algorithm
CREATE OR REPLACE FUNCTION jazzhands.check_fingerprint_hash_algorithm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
BEGIN
	--
	-- Give a release to deal with misspelling
	--
	IF TG_OP = 'INSERT' THEN
		IF NEW.x509_fingerprint_hash_algorighm IS NOT NULL AND NEW.cryptographic_hash_algorithm IS NOT NULL
		THEN
			RAISE EXCEPTION 'Should only set cryptographic_hash_algorithm'
				USING ERRCODE = 'invalid_parameter_value';
		ELSIF NEW.x509_fingerprint_hash_algorighm IS NULL THEN
			NEW.x509_fingerprint_hash_algorighm := NEW.cryptographic_hash_algorithm;
		ELSE
			NEW.cryptographic_hash_algorithm := NEW.x509_fingerprint_hash_algorighm;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.x509_fingerprint_hash_algorighm IS DISTINCT FROM NEW.x509_fingerprint_hash_algorighm AND
			OLD.x509_fingerprint_hash_algorighm IS DISTINCT FROM NEW.cryptographic_hash_algorithm
		THEN
			RAISE EXCEPTION 'Should only set cryptographic_hash_algorithm'
				USING ERRCODE = 'invalid_parameter_value';
		ELSIF OLD.x509_fingerprint_hash_algorighm IS DISTINCT FROM NEW.cryptographic_hash_algorithm THEN
			NEW.x509_fingerprint_hash_algorighm := NEW.cryptographic_hash_algorithm;
		ELSE
			NEW.cryptographic_hash_algorithm := NEW.x509_fingerprint_hash_algorighm;
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.check_fingerprint_hash_algorithm() FROM public;
CREATE TRIGGER trigger_fingerprint_hash_algorithm BEFORE INSERT OR UPDATE OF x509_fingerprint_hash_algorighm, cryptographic_hash_algorithm ON jazzhands.public_key_hash_hash FOR EACH ROW EXECUTE FUNCTION jazzhands.check_fingerprint_hash_algorithm();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('public_key_hash_hash');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for public_key_hash_hash  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'public_key_hash_hash');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'public_key_hash_hash');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'public_key_hash_hash');
DROP TABLE IF EXISTS public_key_hash_hash_v96;
DROP TABLE IF EXISTS jazzhands_audit.public_key_hash_hash_v96;
-- DONE DEALING WITH TABLE public_key_hash_hash (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('public_key_hash_hash');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old public_key_hash_hash failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('public_key_hash_hash');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new public_key_hash_hash failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE site_encapsulation_domain (jazzhands)
CREATE TABLE jazzhands.site_encapsulation_domain
(
	site_code	varchar(50) NOT NULL,
	encapsulation_domain	varchar(50) NOT NULL,
	encapsulation_type	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'site_encapsulation_domain', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.site_encapsulation_domain ADD CONSTRAINT pk_site_encapsulation_domain PRIMARY KEY (site_code, encapsulation_domain, encapsulation_type);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifsite_code_encap_domain_encap_domain ON jazzhands.site_encapsulation_domain USING btree (encapsulation_domain, encapsulation_type);
CREATE INDEX xifsite_code_encapsulation_domain_site_code ON jazzhands.site_encapsulation_domain USING btree (site_code);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK site_encapsulation_domain and encapsulation_domain
ALTER TABLE jazzhands.site_encapsulation_domain
	ADD CONSTRAINT fk_site_code_encap_domain_encap_domain
	FOREIGN KEY (encapsulation_domain, encapsulation_type) REFERENCES jazzhands.encapsulation_domain(encapsulation_domain, encapsulation_type);
-- consider FK site_encapsulation_domain and site
ALTER TABLE jazzhands.site_encapsulation_domain
	ADD CONSTRAINT fk_site_code_encapsulation_domain_site_code
	FOREIGN KEY (site_code) REFERENCES jazzhands.site(site_code);

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('site_encapsulation_domain');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for site_encapsulation_domain  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'site_encapsulation_domain');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'site_encapsulation_domain');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'site_encapsulation_domain');
-- DONE DEALING WITH TABLE site_encapsulation_domain (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('site_encapsulation_domain');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old site_encapsulation_domain failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('site_encapsulation_domain');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new site_encapsulation_domain failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE x509_signed_certificate_fingerprint
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'x509_signed_certificate_fingerprint', 'x509_signed_certificate_fingerprint');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.x509_signed_certificate_fingerprint DROP CONSTRAINT IF EXISTS fk_signed_cert_print_signed_cert;
ALTER TABLE jazzhands.x509_signed_certificate_fingerprint DROP CONSTRAINT IF EXISTS fk_x509_signed_cert_fprint_algorithm;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'x509_signed_certificate_fingerprint', newobject := 'x509_signed_certificate_fingerprint', newmap := '{"pk_x509_signed_certificate_fingerprint":{"columns":["x509_signed_certificate_id","x509_fingerprint_hash_algorighm","cryptographic_hash_algorithm"],"def":"PRIMARY KEY (x509_signed_certificate_id, x509_fingerprint_hash_algorighm, cryptographic_hash_algorithm)","deferrable":false,"deferred":false,"name":"pk_x509_signed_certificate_fingerprint","type":"p"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.x509_signed_certificate_fingerprint DROP CONSTRAINT IF EXISTS pk_x509_signed_certificate_fingerprint;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifsigned_cert_print_signed_cert";
DROP INDEX IF EXISTS "jazzhands"."xifx509_signed_cert_fprint_algorithm";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_x509_signed_certificate_fingerprint ON jazzhands.x509_signed_certificate_fingerprint;
DROP TRIGGER IF EXISTS trigger_audit_x509_signed_certificate_fingerprint ON jazzhands.x509_signed_certificate_fingerprint;
DROP FUNCTION IF EXISTS perform_audit_x509_signed_certificate_fingerprint();
-- default sequences associations and sequences (values rebuilt at end, if needed)
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'x509_signed_certificate_fingerprint', tags := ARRAY['table_x509_signed_certificate_fingerprint']);
---- BEGIN jazzhands_audit.x509_signed_certificate_fingerprint TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'x509_signed_certificate_fingerprint', tags := ARRAY['table_x509_signed_certificate_fingerprint']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'x509_signed_certificate_fingerprint', 'x509_signed_certificate_fingerprint');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'x509_signed_certificate_fingerprint');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.x509_signed_certificate_fingerprint DROP CONSTRAINT IF EXISTS x509_signed_certificate_fingerprint_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_0x509_signed_certificate_fingerprint_pk_x509_signed_certifi";
DROP INDEX IF EXISTS "jazzhands_audit"."x509_signed_certificate_fingerprint_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."x509_signed_certificate_fingerprint_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."x509_signed_certificate_fingerprint_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.x509_signed_certificate_fingerprint ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.x509_signed_certificate_fingerprint TEARDOWN


ALTER TABLE x509_signed_certificate_fingerprint RENAME TO x509_signed_certificate_fingerprint_v96;
ALTER TABLE jazzhands_audit.x509_signed_certificate_fingerprint RENAME TO x509_signed_certificate_fingerprint_v96;

CREATE TABLE jazzhands.x509_signed_certificate_fingerprint
(
	x509_signed_certificate_id	integer NOT NULL,
	x509_fingerprint_hash_algorighm	varchar(255) NOT NULL,
	cryptographic_hash_algorithm	varchar(255) NOT NULL,
	fingerprint	varchar(255) NOT NULL,
	description	varchar(4096)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'x509_signed_certificate_fingerprint', false);


-- BEGIN Manually written insert function
INSERT INTO x509_signed_certificate_fingerprint (
	x509_signed_certificate_id,
	x509_fingerprint_hash_algorighm,
	cryptographic_hash_algorithm,		-- new column (cryptographic_hash_algorithm)
	fingerprint,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	x509_signed_certificate_id,
	x509_fingerprint_hash_algorighm,
	x509_fingerprint_hash_algorighm,		-- new column (cryptographic_hash_algorithm)
	fingerprint,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM x509_signed_certificate_fingerprint_v96;


INSERT INTO jazzhands_audit.x509_signed_certificate_fingerprint (
	x509_signed_certificate_id,
	x509_fingerprint_hash_algorighm,
	cryptographic_hash_algorithm,		-- new column (cryptographic_hash_algorithm)
	fingerprint,
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
	"aud#actor",
	"aud#seq"
) SELECT
	x509_signed_certificate_id,
	x509_fingerprint_hash_algorighm,
	x509_fingerprint_hash_algorighm,		-- new column (cryptographic_hash_algorithm)
	fingerprint,
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
	jsonb_build_object('user', regexp_replace("aud#user", '/.*$', '')) || CASE WHEN "aud#user" ~ '/' THEN jsonb_build_object('appuser', regexp_replace("aud#user", '^[^/]*', '')) ELSE '{}' END,
	"aud#seq"
FROM jazzhands_audit.x509_signed_certificate_fingerprint_v96;



-- END Manually written insert function

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.x509_signed_certificate_fingerprint ADD CONSTRAINT pk_x509_signed_certificate_fingerprint PRIMARY KEY (x509_signed_certificate_id, x509_fingerprint_hash_algorighm, cryptographic_hash_algorithm);

-- Table/Column Comments
COMMENT ON COLUMN jazzhands.x509_signed_certificate_fingerprint.x509_signed_certificate_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN jazzhands.x509_signed_certificate_fingerprint.x509_fingerprint_hash_algorighm IS 'This misspelled column is going away in a future version.';
-- INDEXES
CREATE INDEX xifsigned_cert_print_signed_cert ON jazzhands.x509_signed_certificate_fingerprint USING btree (x509_signed_certificate_id);
CREATE INDEX xifx509_signed_cert_fprint_algorithm ON jazzhands.x509_signed_certificate_fingerprint USING btree (x509_fingerprint_hash_algorighm, cryptographic_hash_algorithm);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK x509_signed_certificate_fingerprint and x509_signed_certificate
ALTER TABLE jazzhands.x509_signed_certificate_fingerprint
	ADD CONSTRAINT fk_signed_cert_print_signed_cert
	FOREIGN KEY (x509_signed_certificate_id) REFERENCES jazzhands.x509_signed_certificate(x509_signed_certificate_id);
-- consider FK x509_signed_certificate_fingerprint and val_x509_fingerprint_hash_algorithm
ALTER TABLE jazzhands.x509_signed_certificate_fingerprint
	ADD CONSTRAINT fk_x509_signed_cert_fprint_algorithm
	FOREIGN KEY (cryptographic_hash_algorithm, x509_fingerprint_hash_algorighm) REFERENCES jazzhands.val_x509_fingerprint_hash_algorithm(cryptographic_hash_algorithm, x509_fingerprint_hash_algorighm);

-- TRIGGERS
-- considering NEW jazzhands.check_fingerprint_hash_algorithm
CREATE OR REPLACE FUNCTION jazzhands.check_fingerprint_hash_algorithm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
BEGIN
	--
	-- Give a release to deal with misspelling
	--
	IF TG_OP = 'INSERT' THEN
		IF NEW.x509_fingerprint_hash_algorighm IS NOT NULL AND NEW.cryptographic_hash_algorithm IS NOT NULL
		THEN
			RAISE EXCEPTION 'Should only set cryptographic_hash_algorithm'
				USING ERRCODE = 'invalid_parameter_value';
		ELSIF NEW.x509_fingerprint_hash_algorighm IS NULL THEN
			NEW.x509_fingerprint_hash_algorighm := NEW.cryptographic_hash_algorithm;
		ELSE
			NEW.cryptographic_hash_algorithm := NEW.x509_fingerprint_hash_algorighm;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.x509_fingerprint_hash_algorighm IS DISTINCT FROM NEW.x509_fingerprint_hash_algorighm AND
			OLD.x509_fingerprint_hash_algorighm IS DISTINCT FROM NEW.cryptographic_hash_algorithm
		THEN
			RAISE EXCEPTION 'Should only set cryptographic_hash_algorithm'
				USING ERRCODE = 'invalid_parameter_value';
		ELSIF OLD.x509_fingerprint_hash_algorighm IS DISTINCT FROM NEW.cryptographic_hash_algorithm THEN
			NEW.x509_fingerprint_hash_algorighm := NEW.cryptographic_hash_algorithm;
		ELSE
			NEW.cryptographic_hash_algorithm := NEW.x509_fingerprint_hash_algorighm;
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.check_fingerprint_hash_algorithm() FROM public;
CREATE TRIGGER trigger_fingerprint_hash_algorithm BEFORE INSERT OR UPDATE OF x509_fingerprint_hash_algorighm, cryptographic_hash_algorithm ON jazzhands.x509_signed_certificate_fingerprint FOR EACH ROW EXECUTE FUNCTION jazzhands.check_fingerprint_hash_algorithm();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('x509_signed_certificate_fingerprint');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for x509_signed_certificate_fingerprint  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'x509_signed_certificate_fingerprint');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'x509_signed_certificate_fingerprint');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'x509_signed_certificate_fingerprint');
DROP TABLE IF EXISTS x509_signed_certificate_fingerprint_v96;
DROP TABLE IF EXISTS jazzhands_audit.x509_signed_certificate_fingerprint_v96;
-- DONE DEALING WITH TABLE x509_signed_certificate_fingerprint (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('x509_signed_certificate_fingerprint');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old x509_signed_certificate_fingerprint failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('x509_signed_certificate_fingerprint');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new x509_signed_certificate_fingerprint failed but that is ok';
	NULL;
END;
$$;

-- Main loop processing views in account_collection_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in account_password_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in approval_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
--- about to process v_account_collection_account_audit_map in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_account_collection_account_audit_map
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('approval_utils', 'v_account_collection_account_audit_map', 'v_account_collection_account_audit_map');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'approval_utils', object := 'v_account_collection_account_audit_map', tags := ARRAY['view_v_account_collection_account_audit_map']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS approval_utils.v_account_collection_account_audit_map;
CREATE VIEW approval_utils.v_account_collection_account_audit_map AS
 SELECT all_audrecs."aud#seq" AS audit_seq_id,
    all_audrecs.account_collection_id,
    all_audrecs.account_id,
    all_audrecs.account_collection_relation,
    all_audrecs.account_id_rank,
    all_audrecs.start_date,
    all_audrecs.finish_date,
    all_audrecs."aud#seq",
    all_audrecs.rownum
   FROM ( SELECT acaa.account_collection_id,
            acaa.account_id,
            acaa.account_collection_relation,
            acaa.account_id_rank,
            acaa.start_date,
            acaa.finish_date,
            acaa."aud#seq",
            row_number() OVER (PARTITION BY aca.account_collection_id, aca.account_id ORDER BY acaa."aud#seq" DESC) AS rownum
           FROM jazzhands.account_collection_account aca
             JOIN jazzhands_audit.account_collection_account acaa USING (account_collection_id, account_id)
          WHERE acaa."aud#action" = ANY (ARRAY['UPD'::bpchar, 'INS'::bpchar])) all_audrecs
  WHERE all_audrecs.rownum = 1;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'approval_utils' AND type = 'view' AND object IN ('v_account_collection_account_audit_map','v_account_collection_account_audit_map');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_account_collection_account_audit_map failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'approval_utils' AND object IN ('v_account_collection_account_audit_map');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_account_collection_account_audit_map  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_account_collection_account_audit_map (approval_utils)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('approval_utils', 'jazzhands_audit') AND object IN ('v_account_collection_account_audit_map');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_account_collection_account_audit_map failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('approval_utils', 'jazzhands_audit') AND object IN ('v_account_collection_account_audit_map');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_account_collection_account_audit_map failed but that is ok';
	NULL;
END;
$$;

--- about to process v_person_company_audit_map in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_person_company_audit_map
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('approval_utils', 'v_person_company_audit_map', 'v_person_company_audit_map');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'approval_utils', object := 'v_person_company_audit_map', tags := ARRAY['view_v_person_company_audit_map']);
-- restore any missing random views that may be cached that this one needs.
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
    all_audrecs.position_title,
    all_audrecs.hire_date,
    all_audrecs.termination_date,
    all_audrecs.manager_person_id,
    all_audrecs.nickname,
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
            pca.position_title,
            pca.hire_date,
            pca.termination_date,
            pca.manager_person_id,
            pca.nickname,
            pca."aud#seq",
            row_number() OVER (PARTITION BY pc.person_id, pc.company_id ORDER BY pca."aud#seq" DESC) AS rownum
           FROM jazzhands.person_company pc
             JOIN jazzhands_audit.person_company pca USING (person_id, company_id)
          WHERE pca."aud#action" = ANY (ARRAY['UPD'::bpchar, 'INS'::bpchar])) all_audrecs
  WHERE all_audrecs.rownum = 1;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'approval_utils' AND type = 'view' AND object IN ('v_person_company_audit_map','v_person_company_audit_map');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_person_company_audit_map failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'approval_utils' AND object IN ('v_person_company_audit_map');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_person_company_audit_map  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_person_company_audit_map (approval_utils)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('approval_utils', 'jazzhands_audit') AND object IN ('v_person_company_audit_map');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_person_company_audit_map failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('approval_utils', 'jazzhands_audit') AND object IN ('v_person_company_audit_map');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_person_company_audit_map failed but that is ok';
	NULL;
END;
$$;

-- Main loop processing views in auto_ac_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in backend_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in company_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in component_connection_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in component_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in component_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in device_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in device_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in dns_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in dns_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in jazzhands
select clock_timestamp(), clock_timestamp() - now() AS len;
--- about to process physicalish_volume in set 1
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE physicalish_volume (jazzhands)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'physicalish_volume');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_audit', 'physicalish_volume');
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands.physicalish_volume;
CREATE VIEW jazzhands.physicalish_volume AS
 SELECT block_storage_device.block_storage_device_id AS physicalish_volume_id,
    block_storage_device.block_storage_device_name AS physicalish_volume_name,
    block_storage_device.block_storage_device_type AS physicalish_volume_type,
    block_storage_device.device_id,
    block_storage_device.logical_volume_id,
    block_storage_device.component_id,
    block_storage_device.data_ins_user,
    block_storage_device.data_ins_date,
    block_storage_device.data_upd_user,
    block_storage_device.data_upd_date
   FROM jazzhands.block_storage_device;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object IN ('physicalish_volume','physicalish_volume');
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
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('physicalish_volume');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for physicalish_volume  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE physicalish_volume (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old physicalish_volume failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new physicalish_volume failed but that is ok';
	NULL;
END;
$$;

--- about to process volume_group_physicalish_volume in set 1
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE volume_group_physicalish_volume (jazzhands)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'volume_group_physicalish_volume');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_audit', 'volume_group_physicalish_volume');
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands.volume_group_physicalish_volume;
CREATE VIEW jazzhands.volume_group_physicalish_volume AS
 SELECT volume_group_block_storage_device.volume_group_id,
    volume_group_block_storage_device.block_storage_device_id AS physicalish_volume_id,
    volume_group_block_storage_device.device_id,
    volume_group_block_storage_device.volume_group_primary_position,
    volume_group_block_storage_device.volume_group_secondary_position,
    volume_group_block_storage_device.volume_group_relation,
    volume_group_block_storage_device.data_ins_user,
    volume_group_block_storage_device.data_ins_date,
    volume_group_block_storage_device.data_upd_user,
    volume_group_block_storage_device.data_upd_date
   FROM jazzhands.volume_group_block_storage_device;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object IN ('volume_group_physicalish_volume','volume_group_physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of volume_group_physicalish_volume failed but that is ok';
	NULL;
END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('volume_group_physicalish_volume');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for volume_group_physicalish_volume  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE volume_group_physicalish_volume (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('volume_group_physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old volume_group_physicalish_volume failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('volume_group_physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new volume_group_physicalish_volume failed but that is ok';
	NULL;
END;
$$;

--- about to process v_account_collection_expanded in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_account_collection_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_account_collection_expanded', 'v_account_collection_expanded');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_account_collection_expanded', tags := ARRAY['view_v_account_collection_expanded']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands.v_account_collection_expanded;
CREATE VIEW jazzhands.v_account_collection_expanded AS
 WITH RECURSIVE acct_coll_recurse(level, root_account_collection_id, account_collection_id, array_path, rvs_array_path, cycle) AS (
         SELECT 0 AS level,
            ac.account_collection_id AS root_account_collection_id,
            ac.account_collection_id,
            ARRAY[ac.account_collection_id] AS array_path,
            ARRAY[ac.account_collection_id] AS rvs_array_path,
            false AS cycle
           FROM jazzhands.account_collection ac
        UNION ALL
         SELECT x.level + 1 AS level,
            x.root_account_collection_id,
            ach.account_collection_id,
            x.array_path || ach.account_collection_id AS array_path,
            ach.account_collection_id || x.rvs_array_path AS rvs_array_path,
            ach.account_collection_id = ANY (x.array_path) AS cycle
           FROM acct_coll_recurse x
             JOIN jazzhands.account_collection_hier ach ON x.account_collection_id = ach.child_account_collection_id
          WHERE NOT x.cycle
        )
 SELECT acct_coll_recurse.level,
    acct_coll_recurse.account_collection_id,
    acct_coll_recurse.root_account_collection_id,
    array_to_string(acct_coll_recurse.array_path, '/'::text) AS text_path,
    acct_coll_recurse.array_path,
    acct_coll_recurse.rvs_array_path
   FROM acct_coll_recurse;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object IN ('v_account_collection_expanded','v_account_collection_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_account_collection_expanded failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('v_account_collection_expanded');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_account_collection_expanded  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_account_collection_expanded (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_account_collection_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_account_collection_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_account_collection_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_account_collection_expanded failed but that is ok';
	NULL;
END;
$$;

--- about to process v_account_collection_expanded_detail in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_account_collection_expanded_detail
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_account_collection_expanded_detail', tags := ARRAY['view_v_account_collection_expanded_detail']);
DROP VIEW IF EXISTS jazzhands.v_account_collection_expanded_detail;
-- DONE DEALING WITH OLD TABLE v_account_collection_expanded_detail (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_account_collection_expanded_detail');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_account_collection_expanded_detail failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_account_collection_expanded_detail');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_account_collection_expanded_detail failed but that is ok';
	NULL;
END;
$$;

--- about to process v_department_company_expanded in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_department_company_expanded
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_department_company_expanded', tags := ARRAY['view_v_department_company_expanded']);
DROP VIEW IF EXISTS jazzhands.v_department_company_expanded;
-- DONE DEALING WITH OLD TABLE v_department_company_expanded (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_department_company_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_department_company_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_department_company_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_department_company_expanded failed but that is ok';
	NULL;
END;
$$;

--- about to process v_device_collection_device_expanded in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_collection_device_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_collection_device_expanded', 'v_device_collection_device_expanded');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_device_collection_device_expanded', tags := ARRAY['view_v_device_collection_device_expanded']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands.v_device_collection_device_expanded;
CREATE VIEW jazzhands.v_device_collection_device_expanded AS
 WITH RECURSIVE var_recurse(root_device_collection_id, device_collection_id, parent_device_collection_id, device_collection_level, array_path, cycle) AS (
         SELECT device_collection.device_collection_id AS root_device_collection_id,
            device_collection.device_collection_id,
            device_collection.device_collection_id AS parent_device_collection_id,
            0 AS device_collection_level,
            ARRAY[device_collection.device_collection_id] AS "array",
            false AS cycle
           FROM jazzhands.device_collection
        UNION ALL
         SELECT x.root_device_collection_id,
            dch.child_device_collection_id AS device_collection_id,
            dch.device_collection_id AS parent_device_colletion_id,
            x.device_collection_level + 1 AS device_collection_level,
            dch.device_collection_id || x.array_path AS array_path,
            dch.device_collection_id = ANY (x.array_path)
           FROM var_recurse x
             JOIN jazzhands.device_collection_hier dch ON x.device_collection_id = dch.device_collection_id
          WHERE NOT x.cycle
        )
 SELECT DISTINCT var_recurse.root_device_collection_id AS device_collection_id,
    device_collection_device.device_id
   FROM var_recurse
     JOIN jazzhands.device_collection_device USING (device_collection_id);

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object IN ('v_device_collection_device_expanded','v_device_collection_device_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_device_collection_device_expanded failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('v_device_collection_device_expanded');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_device_collection_device_expanded  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_device_collection_device_expanded (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_device_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_collection_device_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_device_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_device_collection_device_expanded failed but that is ok';
	NULL;
END;
$$;

--- about to process v_device_collection_hier_detail in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_collection_hier_detail
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_device_collection_hier_detail', tags := ARRAY['view_v_device_collection_hier_detail']);
DROP VIEW IF EXISTS jazzhands.v_device_collection_hier_detail;
-- DONE DEALING WITH OLD TABLE v_device_collection_hier_detail (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_hier_detail');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_collection_hier_detail failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_hier_detail');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_device_collection_hier_detail failed but that is ok';
	NULL;
END;
$$;

--- about to process v_dns_changes_pending in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_dns_changes_pending
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_dns_changes_pending', tags := ARRAY['view_v_dns_changes_pending']);
DROP VIEW IF EXISTS jazzhands.v_dns_changes_pending;
-- DONE DEALING WITH OLD TABLE v_dns_changes_pending (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_dns_changes_pending');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_dns_changes_pending failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_dns_changes_pending');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_dns_changes_pending failed but that is ok';
	NULL;
END;
$$;

--- about to process v_dns_fwd in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_dns_fwd
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_dns_fwd', tags := ARRAY['view_v_dns_fwd']);
DROP VIEW IF EXISTS jazzhands.v_dns_fwd;
-- DONE DEALING WITH OLD TABLE v_dns_fwd (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_dns_fwd');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_dns_fwd failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_dns_fwd');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_dns_fwd failed but that is ok';
	NULL;
END;
$$;

--- about to process v_dns_rvs in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_dns_rvs
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_dns_rvs', tags := ARRAY['view_v_dns_rvs']);
DROP VIEW IF EXISTS jazzhands.v_dns_rvs;
-- DONE DEALING WITH OLD TABLE v_dns_rvs (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_dns_rvs');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_dns_rvs failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_dns_rvs');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_dns_rvs failed but that is ok';
	NULL;
END;
$$;

--- about to process v_hotpants_token in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_hotpants_token
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_hotpants_token', tags := ARRAY['view_v_hotpants_token']);
DROP VIEW IF EXISTS jazzhands.v_hotpants_token;
-- DONE DEALING WITH OLD TABLE v_hotpants_token (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_hotpants_token');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_hotpants_token failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_hotpants_token');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_hotpants_token failed but that is ok';
	NULL;
END;
$$;

--- about to process v_layer2_network_collection_expanded in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_layer2_network_collection_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_layer2_network_collection_expanded', 'v_layer2_network_collection_expanded');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_layer2_network_collection_expanded', tags := ARRAY['view_v_layer2_network_collection_expanded']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands.v_layer2_network_collection_expanded;
CREATE VIEW jazzhands.v_layer2_network_collection_expanded AS
 WITH RECURSIVE layer2_network_collection_recurse(level, root_layer2_network_collection_id, layer2_network_collection_id, array_path, rvs_array_path, cycle) AS (
         SELECT 0 AS level,
            layer2.layer2_network_collection_id AS root_layer2_network_collection_id,
            layer2.layer2_network_collection_id,
            ARRAY[layer2.layer2_network_collection_id] AS array_path,
            ARRAY[layer2.layer2_network_collection_id] AS rvs_array_path,
            false AS cycle
           FROM jazzhands.layer2_network_collection layer2
        UNION ALL
         SELECT x.level + 1 AS level,
            x.root_layer2_network_collection_id,
            layer2h.layer2_network_collection_id,
            x.array_path || layer2h.layer2_network_collection_id AS array_path,
            layer2h.layer2_network_collection_id || x.rvs_array_path AS rvs_array_path,
            layer2h.layer2_network_collection_id = ANY (x.array_path) AS cycle
           FROM layer2_network_collection_recurse x
             JOIN jazzhands.layer2_network_collection_hier layer2h ON x.layer2_network_collection_id = layer2h.child_layer2_network_collection_id
          WHERE NOT x.cycle
        )
 SELECT layer2_network_collection_recurse.level,
    layer2_network_collection_recurse.layer2_network_collection_id,
    layer2_network_collection_recurse.root_layer2_network_collection_id,
    array_to_string(layer2_network_collection_recurse.array_path, '/'::text) AS text_path,
    layer2_network_collection_recurse.array_path,
    layer2_network_collection_recurse.rvs_array_path
   FROM layer2_network_collection_recurse;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object IN ('v_layer2_network_collection_expanded','v_layer2_network_collection_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_layer2_network_collection_expanded failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('v_layer2_network_collection_expanded');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_layer2_network_collection_expanded  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_layer2_network_collection_expanded (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_layer2_network_collection_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_layer2_network_collection_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_layer2_network_collection_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_layer2_network_collection_expanded failed but that is ok';
	NULL;
END;
$$;

--- about to process v_layer3_network_collection_expanded in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_layer3_network_collection_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_layer3_network_collection_expanded', 'v_layer3_network_collection_expanded');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_layer3_network_collection_expanded', tags := ARRAY['view_v_layer3_network_collection_expanded']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands.v_layer3_network_collection_expanded;
CREATE VIEW jazzhands.v_layer3_network_collection_expanded AS
 WITH RECURSIVE layer3_network_collection_recurse(level, root_layer3_network_collection_id, layer3_network_collection_id, array_path, rvs_array_path, cycle) AS (
         SELECT 0 AS level,
            layer3.layer3_network_collection_id AS root_layer3_network_collection_id,
            layer3.layer3_network_collection_id,
            ARRAY[layer3.layer3_network_collection_id] AS array_path,
            ARRAY[layer3.layer3_network_collection_id] AS rvs_array_path,
            false AS cycle
           FROM jazzhands.layer3_network_collection layer3
        UNION ALL
         SELECT x.level + 1 AS level,
            x.root_layer3_network_collection_id,
            layer3h.layer3_network_collection_id,
            x.array_path || layer3h.layer3_network_collection_id AS array_path,
            layer3h.layer3_network_collection_id || x.rvs_array_path AS rvs_array_path,
            layer3h.layer3_network_collection_id = ANY (x.array_path) AS cycle
           FROM layer3_network_collection_recurse x
             JOIN jazzhands.layer3_network_collection_hier layer3h ON x.layer3_network_collection_id = layer3h.child_layer3_network_collection_id
          WHERE NOT x.cycle
        )
 SELECT layer3_network_collection_recurse.level,
    layer3_network_collection_recurse.layer3_network_collection_id,
    layer3_network_collection_recurse.root_layer3_network_collection_id,
    array_to_string(layer3_network_collection_recurse.array_path, '/'::text) AS text_path,
    layer3_network_collection_recurse.array_path,
    layer3_network_collection_recurse.rvs_array_path
   FROM layer3_network_collection_recurse;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object IN ('v_layer3_network_collection_expanded','v_layer3_network_collection_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_layer3_network_collection_expanded failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('v_layer3_network_collection_expanded');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_layer3_network_collection_expanded  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_layer3_network_collection_expanded (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_layer3_network_collection_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_layer3_network_collection_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_layer3_network_collection_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_layer3_network_collection_expanded failed but that is ok';
	NULL;
END;
$$;

--- about to process v_lv_hier in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_lv_hier
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_lv_hier', tags := ARRAY['view_v_lv_hier']);
DROP VIEW IF EXISTS jazzhands.v_lv_hier;
-- DONE DEALING WITH OLD TABLE v_lv_hier (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_lv_hier');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_lv_hier failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_lv_hier');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_lv_hier failed but that is ok';
	NULL;
END;
$$;

--- about to process v_netblock_collection_expanded in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_netblock_collection_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_netblock_collection_expanded', 'v_netblock_collection_expanded');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_netblock_collection_expanded', tags := ARRAY['view_v_netblock_collection_expanded']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands.v_netblock_collection_expanded;
CREATE VIEW jazzhands.v_netblock_collection_expanded AS
 WITH RECURSIVE netblock_coll_recurse(level, root_netblock_collection_id, netblock_collection_id, array_path, rvs_array_path, cycle) AS (
         SELECT 0 AS level,
            nc.netblock_collection_id AS root_netblock_collection_id,
            nc.netblock_collection_id,
            ARRAY[nc.netblock_collection_id] AS array_path,
            ARRAY[nc.netblock_collection_id] AS rvs_array_path,
            false AS cycle
           FROM jazzhands.netblock_collection nc
        UNION ALL
         SELECT x.level + 1 AS level,
            x.root_netblock_collection_id,
            nch.netblock_collection_id,
            x.array_path || nch.netblock_collection_id AS array_path,
            nch.netblock_collection_id || x.rvs_array_path AS rvs_array_path,
            nch.netblock_collection_id = ANY (x.array_path) AS cycle
           FROM netblock_coll_recurse x
             JOIN jazzhands.netblock_collection_hier nch ON x.netblock_collection_id = nch.child_netblock_collection_id
          WHERE NOT x.cycle
        )
 SELECT netblock_coll_recurse.level,
    netblock_coll_recurse.netblock_collection_id,
    netblock_coll_recurse.root_netblock_collection_id,
    array_to_string(netblock_coll_recurse.array_path, '/'::text) AS text_path,
    netblock_coll_recurse.array_path,
    netblock_coll_recurse.rvs_array_path
   FROM netblock_coll_recurse;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object IN ('v_netblock_collection_expanded','v_netblock_collection_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_netblock_collection_expanded failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('v_netblock_collection_expanded');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_netblock_collection_expanded  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_netblock_collection_expanded (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_netblock_collection_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_netblock_collection_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_netblock_collection_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_netblock_collection_expanded failed but that is ok';
	NULL;
END;
$$;

--- about to process v_person_company_hier in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_person_company_hier
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_person_company_hier', 'v_person_company_hier');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_person_company_hier', tags := ARRAY['view_v_person_company_hier']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands.v_person_company_hier;
CREATE VIEW jazzhands.v_person_company_hier AS
 WITH RECURSIVE pc_recurse(level, person_id, subordinate_person_id, intermediate_person_id, person_company_relation, array_path, rvs_array_path, cycle) AS (
         SELECT DISTINCT 0 AS level,
            pc.manager_person_id AS person_id,
            pc.person_id AS subordinate_person_id,
            pc.manager_person_id AS intermediate_person_id,
            pc.person_company_relation,
            ARRAY[pc.manager_person_id] AS array_path,
            ARRAY[pc.manager_person_id] AS rvs_array_path,
            false AS cycle
           FROM jazzhands.person_company pc
             JOIN jazzhands.val_person_status vps ON pc.person_company_status::text = vps.person_status::text
          WHERE vps.is_enabled = true
        UNION ALL
         SELECT x.level + 1 AS level,
            x.person_id,
            pc.person_id AS subordinate_person_id,
            pc.manager_person_id AS intermediate_person_id,
            pc.person_company_relation,
            x.array_path || pc.person_id AS array_path,
            pc.person_id || x.rvs_array_path AS rvs_array_path,
            pc.person_id = ANY (x.array_path) AS cycle
           FROM pc_recurse x
             JOIN jazzhands.person_company pc ON x.subordinate_person_id = pc.manager_person_id
             JOIN jazzhands.val_person_status vps ON pc.person_company_status::text = vps.person_status::text
          WHERE vps.is_enabled = true AND NOT x.cycle
        )
 SELECT pc_recurse.level,
    pc_recurse.person_id,
    pc_recurse.subordinate_person_id,
    pc_recurse.intermediate_person_id,
    pc_recurse.person_company_relation,
    pc_recurse.array_path,
    pc_recurse.rvs_array_path,
    pc_recurse.cycle
   FROM pc_recurse;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object IN ('v_person_company_hier','v_person_company_hier');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_person_company_hier failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('v_person_company_hier');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_person_company_hier  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_person_company_hier (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_person_company_hier');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_person_company_hier failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_person_company_hier');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_person_company_hier failed but that is ok';
	NULL;
END;
$$;

--- about to process v_account_collection_account_expanded_detail in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_account_collection_account_expanded_detail
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_account_collection_account_expanded_detail', tags := ARRAY['view_v_account_collection_account_expanded_detail']);
DROP VIEW IF EXISTS jazzhands.v_account_collection_account_expanded_detail;
-- DONE DEALING WITH OLD TABLE v_account_collection_account_expanded_detail (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_account_collection_account_expanded_detail');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_account_collection_account_expanded_detail failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_account_collection_account_expanded_detail');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_account_collection_account_expanded_detail failed but that is ok';
	NULL;
END;
$$;

--- about to process v_device_collection_device_root in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_collection_device_root
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_device_collection_device_root', tags := ARRAY['view_v_device_collection_device_root']);
DROP VIEW IF EXISTS jazzhands.v_device_collection_device_root;
-- DONE DEALING WITH OLD TABLE v_device_collection_device_root (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_device_root');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_collection_device_root failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_device_root');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_device_collection_device_root failed but that is ok';
	NULL;
END;
$$;

--- about to process v_device_collection_root in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_collection_root
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_device_collection_root', tags := ARRAY['view_v_device_collection_root']);
DROP VIEW IF EXISTS jazzhands.v_device_collection_root;
-- DONE DEALING WITH OLD TABLE v_device_collection_root (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_root');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_collection_root failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_root');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_device_collection_root failed but that is ok';
	NULL;
END;
$$;

--- about to process v_hotpants_device_collection in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_hotpants_device_collection
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_hotpants_device_collection', tags := ARRAY['view_v_hotpants_device_collection']);
DROP VIEW IF EXISTS jazzhands.v_hotpants_device_collection;
-- DONE DEALING WITH OLD TABLE v_hotpants_device_collection (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_hotpants_device_collection');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_hotpants_device_collection failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_hotpants_device_collection');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_hotpants_device_collection failed but that is ok';
	NULL;
END;
$$;

--- about to process v_hotpants_device_collection_attribute in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_hotpants_device_collection_attribute
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_hotpants_device_collection_attribute', tags := ARRAY['view_v_hotpants_device_collection_attribute']);
DROP VIEW IF EXISTS jazzhands.v_hotpants_device_collection_attribute;
-- DONE DEALING WITH OLD TABLE v_hotpants_device_collection_attribute (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_hotpants_device_collection_attribute');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_hotpants_device_collection_attribute failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_hotpants_device_collection_attribute');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_hotpants_device_collection_attribute failed but that is ok';
	NULL;
END;
$$;

--- about to process v_account_collection_property_expanded in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_account_collection_property_expanded
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_account_collection_property_expanded', tags := ARRAY['view_v_account_collection_property_expanded']);
DROP VIEW IF EXISTS jazzhands.v_account_collection_property_expanded;
-- DONE DEALING WITH OLD TABLE v_account_collection_property_expanded (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_account_collection_property_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_account_collection_property_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_account_collection_property_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_account_collection_property_expanded failed but that is ok';
	NULL;
END;
$$;

--- about to process v_dns in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_dns
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_dns', tags := ARRAY['view_v_dns']);
DROP VIEW IF EXISTS jazzhands.v_dns;
-- DONE DEALING WITH OLD TABLE v_dns (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_dns');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_dns failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_dns');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_dns failed but that is ok';
	NULL;
END;
$$;

--- about to process v_hotpants_client in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_hotpants_client
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_hotpants_client', tags := ARRAY['view_v_hotpants_client']);
DROP VIEW IF EXISTS jazzhands.v_hotpants_client;
-- DONE DEALING WITH OLD TABLE v_hotpants_client (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_hotpants_client');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_hotpants_client failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_hotpants_client');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_hotpants_client failed but that is ok';
	NULL;
END;
$$;

--- about to process v_unix_mclass_settings in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_unix_mclass_settings
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_unix_mclass_settings', tags := ARRAY['view_v_unix_mclass_settings']);
DROP VIEW IF EXISTS jazzhands.v_unix_mclass_settings;
-- DONE DEALING WITH OLD TABLE v_unix_mclass_settings (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_mclass_settings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_unix_mclass_settings failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_mclass_settings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_unix_mclass_settings failed but that is ok';
	NULL;
END;
$$;

--- about to process v_device_collection_account_collection_unix_group in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_collection_account_collection_unix_group
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_device_collection_account_collection_unix_group', tags := ARRAY['view_v_device_collection_account_collection_unix_group']);
DROP VIEW IF EXISTS jazzhands.v_device_collection_account_collection_unix_group;
-- DONE DEALING WITH OLD TABLE v_device_collection_account_collection_unix_group (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_collection_unix_group');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_collection_account_collection_unix_group failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_collection_unix_group');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_device_collection_account_collection_unix_group failed but that is ok';
	NULL;
END;
$$;

--- about to process v_dns_sorted in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_dns_sorted
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_dns_sorted', tags := ARRAY['view_v_dns_sorted']);
DROP VIEW IF EXISTS jazzhands.v_dns_sorted;
-- DONE DEALING WITH OLD TABLE v_dns_sorted (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_dns_sorted');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_dns_sorted failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_dns_sorted');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_dns_sorted failed but that is ok';
	NULL;
END;
$$;

--- about to process v_device_collection_account_property_expanded in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_collection_account_property_expanded
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_device_collection_account_property_expanded', tags := ARRAY['view_v_device_collection_account_property_expanded']);
DROP VIEW IF EXISTS jazzhands.v_device_collection_account_property_expanded;
-- DONE DEALING WITH OLD TABLE v_device_collection_account_property_expanded (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_property_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_collection_account_property_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_property_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_device_collection_account_property_expanded failed but that is ok';
	NULL;
END;
$$;

--- about to process v_device_collection_account_ssh_key in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_collection_account_ssh_key
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_device_collection_account_ssh_key', tags := ARRAY['view_v_device_collection_account_ssh_key']);
DROP VIEW IF EXISTS jazzhands.v_device_collection_account_ssh_key;
-- DONE DEALING WITH OLD TABLE v_device_collection_account_ssh_key (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_ssh_key');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_collection_account_ssh_key failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_ssh_key');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_device_collection_account_ssh_key failed but that is ok';
	NULL;
END;
$$;

--- about to process v_device_collection_account_collection_expanded in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_collection_account_collection_expanded
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_device_collection_account_collection_expanded', tags := ARRAY['view_v_device_collection_account_collection_expanded']);
DROP VIEW IF EXISTS jazzhands.v_device_collection_account_collection_expanded;
-- DONE DEALING WITH OLD TABLE v_device_collection_account_collection_expanded (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_collection_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_collection_account_collection_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_collection_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_device_collection_account_collection_expanded failed but that is ok';
	NULL;
END;
$$;

--- about to process v_device_collection_account_collection_unix_login in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_collection_account_collection_unix_login
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_device_collection_account_collection_unix_login', tags := ARRAY['view_v_device_collection_account_collection_unix_login']);
DROP VIEW IF EXISTS jazzhands.v_device_collection_account_collection_unix_login;
-- DONE DEALING WITH OLD TABLE v_device_collection_account_collection_unix_login (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_collection_unix_login');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_collection_account_collection_unix_login failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_collection_unix_login');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_device_collection_account_collection_unix_login failed but that is ok';
	NULL;
END;
$$;

--- about to process v_hotpants_account_attribute in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_hotpants_account_attribute
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_hotpants_account_attribute', tags := ARRAY['view_v_hotpants_account_attribute']);
DROP VIEW IF EXISTS jazzhands.v_hotpants_account_attribute;
-- DONE DEALING WITH OLD TABLE v_hotpants_account_attribute (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_hotpants_account_attribute');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_hotpants_account_attribute failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_hotpants_account_attribute');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_hotpants_account_attribute failed but that is ok';
	NULL;
END;
$$;

--- about to process v_unix_group_overrides in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_unix_group_overrides
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_unix_group_overrides', tags := ARRAY['view_v_unix_group_overrides']);
DROP VIEW IF EXISTS jazzhands.v_unix_group_overrides;
-- DONE DEALING WITH OLD TABLE v_unix_group_overrides (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_group_overrides');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_unix_group_overrides failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_group_overrides');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_unix_group_overrides failed but that is ok';
	NULL;
END;
$$;

--- about to process v_unix_account_overrides in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_unix_account_overrides
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_unix_account_overrides', tags := ARRAY['view_v_unix_account_overrides']);
DROP VIEW IF EXISTS jazzhands.v_unix_account_overrides;
-- DONE DEALING WITH OLD TABLE v_unix_account_overrides (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_account_overrides');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_unix_account_overrides failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_account_overrides');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_unix_account_overrides failed but that is ok';
	NULL;
END;
$$;

--- about to process v_device_collection_account_collection_cart in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_collection_account_collection_cart
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_device_collection_account_collection_cart', tags := ARRAY['view_v_device_collection_account_collection_cart']);
DROP VIEW IF EXISTS jazzhands.v_device_collection_account_collection_cart;
-- DONE DEALING WITH OLD TABLE v_device_collection_account_collection_cart (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_collection_cart');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_collection_account_collection_cart failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_collection_cart');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_device_collection_account_collection_cart failed but that is ok';
	NULL;
END;
$$;

--- about to process v_device_collection_account_cart in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_collection_account_cart
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_device_collection_account_cart', tags := ARRAY['view_v_device_collection_account_cart']);
DROP VIEW IF EXISTS jazzhands.v_device_collection_account_cart;
-- DONE DEALING WITH OLD TABLE v_device_collection_account_cart (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_cart');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_collection_account_cart failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_device_collection_account_cart');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_device_collection_account_cart failed but that is ok';
	NULL;
END;
$$;

--- about to process v_unix_passwd_mappings in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_unix_passwd_mappings
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_unix_passwd_mappings', tags := ARRAY['view_v_unix_passwd_mappings']);
DROP VIEW IF EXISTS jazzhands.v_unix_passwd_mappings;
-- DONE DEALING WITH OLD TABLE v_unix_passwd_mappings (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_passwd_mappings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_unix_passwd_mappings failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_passwd_mappings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_unix_passwd_mappings failed but that is ok';
	NULL;
END;
$$;

--- about to process v_unix_group_mappings in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_unix_group_mappings
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'v_unix_group_mappings', tags := ARRAY['view_v_unix_group_mappings']);
DROP VIEW IF EXISTS jazzhands.v_unix_group_mappings;
-- DONE DEALING WITH OLD TABLE v_unix_group_mappings (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_group_mappings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_unix_group_mappings failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('v_unix_group_mappings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped v_unix_group_mappings failed but that is ok';
	NULL;
END;
$$;

--- about to process val_physicalish_volume_type in set 1
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_physicalish_volume_type (jazzhands)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_physicalish_volume_type');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_audit', 'val_physicalish_volume_type');
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands.val_physicalish_volume_type;
CREATE VIEW jazzhands.val_physicalish_volume_type AS
 SELECT val_block_storage_device_type.block_storage_device_type AS physicalish_volume_type,
    val_block_storage_device_type.description,
    val_block_storage_device_type.data_ins_user,
    val_block_storage_device_type.data_ins_date,
    val_block_storage_device_type.data_upd_user,
    val_block_storage_device_type.data_upd_date
   FROM jazzhands.val_block_storage_device_type;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object IN ('val_physicalish_volume_type','val_physicalish_volume_type');
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
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_physicalish_volume_type');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_physicalish_volume_type  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE val_physicalish_volume_type (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_physicalish_volume_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_physicalish_volume_type failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_physicalish_volume_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_physicalish_volume_type failed but that is ok';
	NULL;
END;
$$;

-- Main loop processing views in jazzhands_legacy_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in layerx_network_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in logical_port_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in lv_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in net_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in netblock_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in netblock_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in network_strings
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in obfuscation_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in person_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in pgcrypto
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in physical_address_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in port_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in rack_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in schema_support
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in script_hooks
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in service_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in service_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in snapshot_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in time_util
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in token_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in versioning_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in x509_hash_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in x509_plperl_cert_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in audit
select clock_timestamp(), clock_timestamp() - now() AS len;
--- about to process physicalish_volume in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE physicalish_volume
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'physicalish_volume', 'physicalish_volume');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'audit', object := 'physicalish_volume', tags := ARRAY['view_physicalish_volume']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS audit.physicalish_volume;
CREATE VIEW audit.physicalish_volume AS
 SELECT block_storage_device.block_storage_device_id AS physicalish_volume_id,
    block_storage_device.block_storage_device_name AS physicalish_volume_name,
    block_storage_device.block_storage_device_type AS physicalish_volume_type,
    block_storage_device.device_id,
    block_storage_device.logical_volume_id,
    block_storage_device.component_id,
    block_storage_device.data_ins_user,
    block_storage_device.data_ins_date,
    block_storage_device.data_upd_user,
    block_storage_device.data_upd_date,
    block_storage_device."aud#action",
    block_storage_device."aud#timestamp",
    block_storage_device."aud#realtime",
    block_storage_device."aud#txid",
    block_storage_device."aud#user",
    block_storage_device."aud#seq"
   FROM jazzhands_audit.block_storage_device;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'audit' AND type = 'view' AND object IN ('physicalish_volume','physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of physicalish_volume failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'audit' AND object IN ('physicalish_volume');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for physicalish_volume  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE physicalish_volume (audit)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old physicalish_volume failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new physicalish_volume failed but that is ok';
	NULL;
END;
$$;

--- about to process account_auth_log in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE account_auth_log
SELECT schema_support.save_dependent_objects_for_replay(schema := 'audit', object := 'account_auth_log', tags := ARRAY['view_account_auth_log']);
DROP VIEW IF EXISTS audit.account_auth_log;
-- DONE DEALING WITH OLD TABLE account_auth_log (audit)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('account_auth_log');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old account_auth_log failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('account_auth_log');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped account_auth_log failed but that is ok';
	NULL;
END;
$$;

--- about to process val_physicalish_volume_type in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE val_physicalish_volume_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_physicalish_volume_type', 'val_physicalish_volume_type');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'audit', object := 'val_physicalish_volume_type', tags := ARRAY['view_val_physicalish_volume_type']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS audit.val_physicalish_volume_type;
CREATE VIEW audit.val_physicalish_volume_type AS
 SELECT val_block_storage_device_type.block_storage_device_type AS physicalish_volume_type,
    val_block_storage_device_type.description,
    val_block_storage_device_type.data_ins_user,
    val_block_storage_device_type.data_ins_date,
    val_block_storage_device_type.data_upd_user,
    val_block_storage_device_type.data_upd_date,
    val_block_storage_device_type."aud#action",
    val_block_storage_device_type."aud#timestamp",
    val_block_storage_device_type."aud#realtime",
    val_block_storage_device_type."aud#txid",
    val_block_storage_device_type."aud#user",
    val_block_storage_device_type."aud#seq"
   FROM jazzhands_audit.val_block_storage_device_type;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'audit' AND type = 'view' AND object IN ('val_physicalish_volume_type','val_physicalish_volume_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of val_physicalish_volume_type failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'audit' AND object IN ('val_physicalish_volume_type');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_physicalish_volume_type  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE val_physicalish_volume_type (audit)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('val_physicalish_volume_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_physicalish_volume_type failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('val_physicalish_volume_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_physicalish_volume_type failed but that is ok';
	NULL;
END;
$$;

--- about to process volume_group_physicalish_vol in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE volume_group_physicalish_vol
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'volume_group_physicalish_vol', 'volume_group_physicalish_vol');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'audit', object := 'volume_group_physicalish_vol', tags := ARRAY['view_volume_group_physicalish_vol']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS audit.volume_group_physicalish_vol;
CREATE VIEW audit.volume_group_physicalish_vol AS
 SELECT volume_group_block_storage_device.block_storage_device_id AS physicalish_volume_id,
    volume_group_block_storage_device.volume_group_id,
    volume_group_block_storage_device.device_id,
    volume_group_block_storage_device.volume_group_primary_position AS volume_group_primary_pos,
    volume_group_block_storage_device.volume_group_secondary_position AS volume_group_secondary_pos,
    volume_group_block_storage_device.volume_group_relation,
    volume_group_block_storage_device.data_ins_user,
    volume_group_block_storage_device.data_ins_date,
    volume_group_block_storage_device.data_upd_user,
    volume_group_block_storage_device.data_upd_date,
    volume_group_block_storage_device."aud#action",
    volume_group_block_storage_device."aud#timestamp",
    volume_group_block_storage_device."aud#realtime",
    volume_group_block_storage_device."aud#txid",
    volume_group_block_storage_device."aud#user",
    volume_group_block_storage_device."aud#seq"
   FROM jazzhands_audit.volume_group_block_storage_device;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'audit' AND type = 'view' AND object IN ('volume_group_physicalish_vol','volume_group_physicalish_vol');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of volume_group_physicalish_vol failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'audit' AND object IN ('volume_group_physicalish_vol');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for volume_group_physicalish_vol  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE volume_group_physicalish_vol (audit)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('volume_group_physicalish_vol');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old volume_group_physicalish_vol failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('volume_group_physicalish_vol');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new volume_group_physicalish_vol failed but that is ok';
	NULL;
END;
$$;

--
-- Process all procs in jazzhands_cache
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_cache']);
--
-- Process all procs in account_collection_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_collection_manip']);
--
-- Process all procs in account_password_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_password_manip']);
--
-- Process all procs in approval_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_approval_utils']);
--
-- Process all procs in auto_ac_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_auto_ac_manip']);
--
-- Process all procs in backend_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_backend_utils']);
--
-- Process all procs in company_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_company_manip']);
--
-- Process all procs in component_connection_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_connection_utils']);
--
-- Process all procs in component_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_manip']);
--
-- Process all procs in component_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_utils']);
--
-- Process all procs in device_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_manip']);
--
-- Process all procs in device_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_utils']);
--
-- Process all procs in dns_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_manip']);
--
-- Process all procs in dns_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_utils']);
--
-- Process all procs in jazzhands
--
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'device_management_controller_del');
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_management_controller_del');
CREATE OR REPLACE FUNCTION jazzhands.device_management_controller_del()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_c			jazzhands.component_management_controller.component_id%TYPE;
	_mc			jazzhands.component_management_controller.component_id%TYPE;
	_cmc		jazzhands.component_management_controller%ROWTYPE;
BEGIN
	SELECT	component_id
	INTO	_c
	FROM	device
	WHERE	device_id = OLD.device_id;

	SELECT	component_id
	INTO	_mc
	FROM	device
	WHERE	device_id = OLD.manager_device_id;

	DELETE FROM component_management_controller
	WHERE component_id IS NOT DISTINCT FROM  _c
	AND manager_component_id IS NOT DISTINCT FROM _mc
	RETURNING * INTO _cmc;

	OLD.device_management_control_type	= _cmc.component_management_controller_type;
	OLD.description					= _cmc.description;

	OLD.data_ins_user := _cmc.data_ins_user;
	OLD.data_ins_date := _cmc.data_ins_date;
	OLD.data_upd_user := _cmc.data_upd_user;
	OLD.data_upd_date := _cmc.data_upd_date;

	RETURN OLD;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('device_management_controller_del');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc device_management_controller_del failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'device_management_controller_ins');
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_management_controller_ins');
CREATE OR REPLACE FUNCTION jazzhands.device_management_controller_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_c		jazzhands.component_management_controller.component_id%TYPE;
	_mc		jazzhands.component_management_controller.component_id%TYPE;
	_cmc	jazzhands.component_management_controller%ROWTYPE;
BEGIN
	SELECT	component_id
	INTO	_c
	FROM	device
	WHERE	device_id IS NOT DISTINCT FROM NEW.device_id;

	IF _c IS NULL THEN
			RAISE EXCEPTION 'device_id may not be NULL or there is no component associated with the device.'
			USING ERRCODE = 'not_null_violation';
	END IF;

	SELECT	component_id
	INTO	_mc
	FROM	device
	WHERE	device_id IS NOT DISTINCT FROM NEW.manager_device_id;

	IF _mc IS NULL THEN
			RAISE EXCEPTION 'manager_device_id may not be NULL or there is no component associated with the device.'
			USING ERRCODE = 'not_null_violation';
	END IF;

	INSERT INTO component_management_controller (
		manager_component_id, component_id,
		component_management_controller_type, description
	) VALUES (
		_mc, _c,
		NEW.device_management_control_type, NEW.description
	) RETURNING * INTO _cmc;

	NEW.data_ins_user := _cmc.data_ins_user;
	NEW.data_ins_date := _cmc.data_ins_date;
	NEW.data_upd_user := _cmc.data_upd_user;
	NEW.data_upd_date := _cmc.data_upd_date;

	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('device_management_controller_ins');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc device_management_controller_ins failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'device_management_controller_upd');
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_management_controller_upd');
CREATE OR REPLACE FUNCTION jazzhands.device_management_controller_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	upd_query	TEXT[];
	_c			jazzhands.component_management_controller.component_id%TYPE;
	_oc			jazzhands.component_management_controller.component_id%TYPE;
	_omc		jazzhands.component_management_controller.component_id%TYPE;
	_cmc		jazzhands.component_management_controller%ROWTYPE;
BEGIN
	upd_query := NULL;
	IF OLD.device_id IS DISTINCT FROM NEW.device_id THEN
		SELECT	component_id
		INTO	_c
		FROM	device
		WHERE	device_id IS NOT DISTINCT FROM NEW.device_id;

		IF _c IS NULL THEN
				RAISE EXCEPTION 'device_id may not be NULL or there is no component associated with the device.'
				USING ERRCODE = 'not_null_violation';
		END IF;

		upd_query := array_append(upd_query,
			'component_id = ' || quote_nullable(_c));
	END IF;

	IF OLD.manager_device_id IS DISTINCT FROM NEW.manager_device_id THEN
		SELECT	component_id
		INTO	_c
		FROM	device
		WHERE	device_id IS NOT DISTINCT FROM NEW.manager_device_id;

		IF _c IS NULL THEN
				RAISE EXCEPTION 'manager_device_id may not be NULL or there is no component associated with the device.'
				USING ERRCODE = 'not_null_violation';
		END IF;

		upd_query := array_append(upd_query,
			'manager_component_id = ' || quote_nullable(_c));
	END IF;

	IF NEW.description IS DISTINCT FROM OLD.description THEN
		upd_query := array_append(upd_query,
		'description = ' || quote_nullable(NEW.description));
	END IF;

	IF NEW.device_management_control_type IS DISTINCT FROM OLD.device_management_control_type THEN
		upd_query := array_append(upd_query,
		'component_management_controller_type = ' || quote_nullable(NEW.device_management_control_type));
	END IF;

	IF upd_query IS NOT NULL THEN
		SELECT component_id INTO _cmc.component_id
		FROM device WHERE device_id = OLD.device_id;

		SELECT component_id INTO _cmc.manager_component_id
		FROM device WHERE device_id = OLD.manager_device_id;

		EXECUTE 'UPDATE component_management_controller SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE component_id = $1 AND manager_component_id = $2 RETURNING *'
			USING _cmc.component_id, _cmc.manager_component_id
			INTO _cmc;

		NEW.device_management_control_type	= _cmc.component_management_controller_type;
	  	NEW.description					= _cmc.description;

		NEW.data_ins_user := _cmc.data_ins_user;
		NEW.data_ins_date := _cmc.data_ins_date;
		NEW.data_upd_user := _cmc.data_upd_user;
		NEW.data_upd_date := _cmc.data_upd_date;
	END IF;

	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('device_management_controller_upd');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc device_management_controller_upd failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'dns_non_a_rec_validation');
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_non_a_rec_validation');
CREATE OR REPLACE FUNCTION jazzhands.dns_non_a_rec_validation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_ip		netblock.ip_address%type;
BEGIN
	IF NEW.dns_type NOT in ('A', 'AAAA', 'REVERSE_ZONE_BLOCK_PTR','DEFAULT_DNS_DOMAIN') AND
			( NEW.dns_value IS NULL AND NEW.dns_value_record_id IS NULL ) THEN
		RAISE EXCEPTION 'Attempt to set % record without a value',
			NEW.dns_type
			USING ERRCODE = 'not_null_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('dns_non_a_rec_validation');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc dns_non_a_rec_validation failed but that is ok';
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
	AND ip_universe_id IN (
			SELECT NEW.ip_universe_id
		UNION
			SELECT visible_ip_universe_id
			FROM ip_universe_visibility
			WHERE ip_universe_id = NEW.ip_universe_id
	)
	AND dns_class = NEW.dns_class
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

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'manip_all_svc_collection_members');
SELECT schema_support.save_grants_for_replay('jazzhands', 'manip_all_svc_collection_members');
CREATE OR REPLACE FUNCTION jazzhands.manip_all_svc_collection_members()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	IF TG_OP = 'INSERT' THEN
		INSERT INTO service_version_collection_service_version (
			service_version_collection_id, service_version_id
		) SELECT service_version_collection_id, NEW.service_version_id
		FROM service_version_collection
		WHERE service_version_collection_type = 'all-services'
		AND service_version_collection_name IN (SELECT service_name
			FROM service
			WHERE service_id = NEW.service_id
		);
		INSERT INTO service_version_collection_service_version (
			service_version_collection_id, service_version_id
		) SELECT service_version_collection_id, NEW.service_version_id
		FROM service_version_collection
		WHERE service_version_collection_type = 'current-services'
		AND service_version_collection_name IN (SELECT service_name
			FROM service
			WHERE service_id = NEW.service_id
		);
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM service_version_collection_service_version
		WHERE service_version_id = OLD.service_version_id
		AND service_version_collection_id IN (
			SELECT service_version_collection_id
			FROM service_version_collection
			WHERE service_version_collection_name IN (
				SELECT service_name
				FROM service
				WHERE service_id = OLD.service_id
			)
			AND service_version_collection_type IN (
				'all-services', 'current-services'
			)
		);
		RETURN OLD;
	END IF;
	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('manip_all_svc_collection_members');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc manip_all_svc_collection_members failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'service_environment_ins');
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_ins');
CREATE OR REPLACE FUNCTION jazzhands.service_environment_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_se	service_environment%ROWTYPE;
BEGIN
	IF NEW.service_environment_id IS NOT NULL THEN
		INSERT INTO service_environment (
			service_environment_id,
			service_environment_name,
			service_environment_type,
			production_state,
			description,
			external_id
		) VALUES (
			NEW.service_environment_id,
			NEW.service_environment_name,
			'default',
			NEW.production_state,
			NEW.description,
			NEW.external_id
		) RETURNING * INTO _se;
	ELSE
		INSERT INTO service_environment (
			service_environment_name,
			service_environment_type,
			production_state,
			description,
			external_id
		) VALUES (
			NEW.service_environment_name,
			'default',
			NEW.production_state,
			NEW.description,
			NEW.external_id
		) RETURNING * INTO _se;

	END IF;

	NEW.service_environment_id		:= _se.service_environment_id;
	NEW.service_environment_name	:= _se.service_environment_name;
	NEW.production_state			:= _se.production_state;
	NEW.description					:= _se.description;
	NEW.external_id					:= _se.external_id;
	NEW.data_ins_user				:= _se.data_ins_user;
	NEW.data_ins_date				:= _se.data_ins_date;
	NEW.data_upd_user				:= _se.data_upd_user;
	NEW.data_upd_date				:= _se.data_upd_date;

	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('service_environment_ins');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc service_environment_ins failed but that is ok';
	NULL;
END;
$$;

DROP TRIGGER IF EXISTS trigger_upd_v_hotpants_token ON jazzhands.v_hotpants_token;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands'::text, object := 'upd_v_hotpants_token (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands'::text]);
DROP FUNCTION IF EXISTS jazzhands.upd_v_hotpants_token (  );
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'validate_val_property');
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_val_property');
CREATE OR REPLACE FUNCTION jazzhands.validate_val_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN

	PERFORM property_utils.validate_val_property(NEW);

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

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('validate_val_property');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc validate_val_property failed but that is ok';
	NULL;
END;
$$;

DROP TRIGGER IF EXISTS trigger_verify_physicalish_volume ON jazzhands.physicalish_volume;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands'::text, object := 'verify_physicalish_volume (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands'::text]);
DROP FUNCTION IF EXISTS jazzhands.verify_physicalish_volume (  );
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands']);
-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.check_component_type_device_virtual_match()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	PERFORM *
	FROM device
	JOIN component USING (component_id)
	WHERE is_virtual_device != NEW.is_virtual_component;

	IF FOUND THEN
		RAISE EXCEPTION 'There are devices with a component of this type that do not match is_virtual_component'
			USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.check_device_component_type_virtual_match()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	IF NEW.component_id IS NOT NULL THEN
		PERFORM *
		FROM component c
		JOIN component_type ct USING (component_type_id)
		WHERE c.component_id = NEW.component_id
		AND NEW.is_virtual_device != ct.is_virtual_component;

		IF FOUND THEN
			RAISE EXCEPTION 'There are devices with a component of this type that do not match is_virtual_component'
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.check_fingerprint_hash_algorithm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
BEGIN
	--
	-- Give a release to deal with misspelling
	--
	IF TG_OP = 'INSERT' THEN
		IF NEW.x509_fingerprint_hash_algorighm IS NOT NULL AND NEW.cryptographic_hash_algorithm IS NOT NULL
		THEN
			RAISE EXCEPTION 'Should only set cryptographic_hash_algorithm'
				USING ERRCODE = 'invalid_parameter_value';
		ELSIF NEW.x509_fingerprint_hash_algorighm IS NULL THEN
			NEW.x509_fingerprint_hash_algorighm := NEW.cryptographic_hash_algorithm;
		ELSE
			NEW.cryptographic_hash_algorithm := NEW.x509_fingerprint_hash_algorighm;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.x509_fingerprint_hash_algorighm IS DISTINCT FROM NEW.x509_fingerprint_hash_algorighm AND
			OLD.x509_fingerprint_hash_algorighm IS DISTINCT FROM NEW.cryptographic_hash_algorithm
		THEN
			RAISE EXCEPTION 'Should only set cryptographic_hash_algorithm'
				USING ERRCODE = 'invalid_parameter_value';
		ELSIF OLD.x509_fingerprint_hash_algorighm IS DISTINCT FROM NEW.cryptographic_hash_algorithm THEN
			NEW.x509_fingerprint_hash_algorighm := NEW.cryptographic_hash_algorithm;
		ELSE
			NEW.cryptographic_hash_algorithm := NEW.x509_fingerprint_hash_algorighm;
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.set_x509_certificate_private_key_id()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	UPDATE x509_signed_certificate x SET private_key_id = pk.private_key_id
	FROM private_key pk WHERE x.public_key_hash_id = pk.public_key_hash_id
	AND x.private_key_id IS NULL AND x.x509_signed_certificate_id = NEW.x509_signed_certificate_id;

	RETURN NEW;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.sync_component_rack_location_id()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	IF pg_trigger_depth() >= 2 THEN
		RETURN NEW;
	END IF;
	IF OLD.component_id != NEW.component_id THEN
		UPDATE device d
		SET rack_location_id = NULL
		WHERE d.component_id = OLD.component_id
		AND d.rack_location_id IS NOT NULL;
	END IF;

	UPDATE device d
	SET rack_location_id = NEW.rack_location_id
	WHERE d.rack_location_id IS DISTINCT FROM NEW.rack_location_id
	AND d.component_id = NEW.component_id;

	RETURN NEW;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.sync_device_rack_location_id()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_id	INTEGER;
BEGIN
	IF pg_trigger_depth() >= 2 THEN
		RETURN NEW;
	END IF;
	IF TG_OP = 'INSERT' THEN
		IF NEW.component_id IS NOT NULL AND NEW.rack_location_id IS NOT NULL THEN
			UPDATE component c
			SET rack_location_id = NEW.rack_location_id
			WHERE c.rack_location_id IS DISTINCT FROM NEW.rack_location_id
			AND c.component_id = NEW.component_id;
		ELSIF NEW.rack_location_id IS NULL THEN
			SELECT rack_location_id
			INTO _id
			FROM component c
			WHERE c.component_id = NEW.component_id;
			NEW.rack_location_id := _id;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.component_id IS NULL THEN
			IF OLD.component_id IS NOT NULL THEN
				UPDATE component c
				SET rack_location_id = NULL
				WHERE c.rack_location_id  IS NOT NULL
				AND c.component_id = OLD.component_id;
			END IF;

			NEW.rack_location_id = NULL;
		ELSE
			UPDATE component
			SET rack_location_id = NEW.rack_location_id
			WHERE component_id = NEW.component_id
			AND rack_location_id IS DISTINCT FROM NEW.rack_location_id;
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.validate_filesystem()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	PERFORM property_utils.validate_filesystem(NEW);
	RETURN NEW;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.validate_filesystem_type()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	PERFORM	property_utils.validate_filesystem(f)
	FROM filesystem f
	WHERE f.filesystem_type = NEW.filesystem_type;
	RETURN NEW;
END;
$function$
;

--
-- Process all procs in jazzhands_legacy_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy_manip']);
--
-- Process all procs in layerx_network_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_layerx_network_manip']);
--
-- Process all procs in logical_port_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_logical_port_manip']);
--
-- Process all procs in lv_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_lv_manip']);
--
-- Process all procs in net_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_net_manip']);
--
-- Process all procs in netblock_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_manip']);
--
-- Process all procs in netblock_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_utils']);
--
-- Process all procs in network_strings
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_network_strings']);
--
-- Process all procs in obfuscation_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_obfuscation_utils']);
--
-- Process all procs in person_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_person_manip']);
--
-- Process all procs in pgcrypto
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_pgcrypto']);
--
-- Process all procs in physical_address_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_physical_address_utils']);
--
-- Process all procs in port_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_port_utils']);
--
-- Process all procs in rack_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_rack_utils']);
--
-- Process all procs in schema_support
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'schema_support'::text, object := 'migrate_grants ( text,text,text,text )'::text, tags := ARRAY['process_all_procs_in_schema_schema_support'::text]);
DROP FUNCTION IF EXISTS schema_support.migrate_grants ( text,text,text,text );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'schema_support'::text, object := 'reset_table_sequence ( character varying,character varying )'::text, tags := ARRAY['process_all_procs_in_schema_schema_support'::text]);
DROP FUNCTION IF EXISTS schema_support.reset_table_sequence ( character varying,character varying );
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('schema_support', 'trigger_ins_upd_generic_func');
SELECT schema_support.save_grants_for_replay('schema_support', 'trigger_ins_upd_generic_func');
CREATE OR REPLACE FUNCTION schema_support.trigger_ins_upd_generic_func()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'schema_support' AND type = 'function' AND object IN ('trigger_ins_upd_generic_func');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc trigger_ins_upd_generic_func failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_schema_support']);
--
-- Process all procs in script_hooks
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_script_hooks']);
--
-- Process all procs in service_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_service_manip']);
--
-- Process all procs in service_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_service_utils']);
--
-- Process all procs in snapshot_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_snapshot_manip']);
--
-- Process all procs in time_util
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_time_util']);
--
-- Process all procs in token_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_token_utils']);
--
-- Process all procs in versioning_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_versioning_utils']);
--
-- Process all procs in x509_hash_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_hash_manip']);
--
-- Process all procs in x509_plperl_cert_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_plperl_cert_utils']);
--
-- Process all procs in audit
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_audit']);
--
-- Recreate the saved views in the base schema
--
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', type := 'view');


-- BEGIN Misc that does not apply to above

-- There's probably a bug; these will get refreshed.
DELETE from jazzhands_cache.ct_jazzhands_legacy_device_support
WHERE device_id IN (
	SELECT device_id 
	FROM jazzhands_cache.v_jazzhands_legacy_device_support z
	WHERE (z) IN
	(
		SELECT (x) FROM
		(
			SELECT * FROM jazzhands_cache.v_jazzhands_legacy_device_support EXCEPT
			SELECT * FROM jazzhands_cache.ct_jazzhands_legacy_device_support
		) x
	)
);


-- END Misc that does not apply to above
--
-- BEGIN: process_ancillary_schema(jazzhands_legacy)
--
--- processing view physicalish_volume in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE physicalish_volume
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'physicalish_volume', 'physicalish_volume');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'physicalish_volume', tags := ARRAY['view_physicalish_volume']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.physicalish_volume;
CREATE VIEW jazzhands_legacy.physicalish_volume AS
 SELECT block_storage_device.block_storage_device_id AS physicalish_volume_id,
    block_storage_device.block_storage_device_name AS physicalish_volume_name,
    block_storage_device.block_storage_device_type AS physicalish_volume_type,
    block_storage_device.device_id,
    block_storage_device.logical_volume_id,
    block_storage_device.component_id,
    block_storage_device.data_ins_user,
    block_storage_device.data_ins_date,
    block_storage_device.data_upd_user,
    block_storage_device.data_upd_date
   FROM jazzhands.block_storage_device;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('physicalish_volume','physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of physicalish_volume failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('physicalish_volume');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for physicalish_volume  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE physicalish_volume (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old physicalish_volume failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new physicalish_volume failed but that is ok';
	NULL;
END;
$$;

--- processing view account_auth_log in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE account_auth_log
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'account_auth_log', tags := ARRAY['view_account_auth_log']);
DROP VIEW IF EXISTS jazzhands_legacy.account_auth_log;
-- DONE DEALING WITH OLD TABLE account_auth_log (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('account_auth_log');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old account_auth_log failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('account_auth_log');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped account_auth_log failed but that is ok';
	NULL;
END;
$$;

--- processing view public_key_hash_hash in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE public_key_hash_hash
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'public_key_hash_hash', 'public_key_hash_hash');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'public_key_hash_hash', tags := ARRAY['view_public_key_hash_hash']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.public_key_hash_hash;
CREATE VIEW jazzhands_legacy.public_key_hash_hash AS
 SELECT public_key_hash_hash.public_key_hash_id,
    public_key_hash_hash.cryptographic_hash_algorithm AS x509_fingerprint_hash_algorighm,
    public_key_hash_hash.calculated_hash,
    public_key_hash_hash.data_ins_user,
    public_key_hash_hash.data_ins_date,
    public_key_hash_hash.data_upd_user,
    public_key_hash_hash.data_upd_date
   FROM jazzhands.public_key_hash_hash;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('public_key_hash_hash','public_key_hash_hash');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of public_key_hash_hash failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('public_key_hash_hash');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for public_key_hash_hash  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE public_key_hash_hash (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('public_key_hash_hash');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old public_key_hash_hash failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('public_key_hash_hash');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new public_key_hash_hash failed but that is ok';
	NULL;
END;
$$;

--- processing view v_acct_coll_acct_expanded_detail in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_acct_coll_acct_expanded_detail
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_acct_coll_acct_expanded_detail', 'v_acct_coll_acct_expanded_detail');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded_detail', tags := ARRAY['view_v_acct_coll_acct_expanded_detail']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_acct_coll_acct_expanded_detail;
CREATE VIEW jazzhands_legacy.v_acct_coll_acct_expanded_detail AS
 WITH RECURSIVE var_recurse(account_collection_id, root_account_collection_id, account_id, acct_coll_level, dept_level, assign_method, array_path, cycle) AS (
         SELECT aca.account_collection_id,
            aca.account_collection_id,
            aca.account_id,
                CASE ac.account_collection_type
                    WHEN 'department'::text THEN 0
                    ELSE 1
                END AS "case",
                CASE ac.account_collection_type
                    WHEN 'department'::text THEN 1
                    ELSE 0
                END AS "case",
                CASE ac.account_collection_type
                    WHEN 'department'::text THEN 'DirectDepartmentAssignment'::text
                    ELSE 'DirectAccountCollectionAssignment'::text
                END AS "case",
            ARRAY[aca.account_collection_id] AS "array",
            false AS "?column?"
           FROM jazzhands.account_collection ac
             JOIN jazzhands.v_account_collection_account aca USING (account_collection_id)
        UNION ALL
         SELECT ach.account_collection_id,
            x.root_account_collection_id,
            x.account_id,
                CASE ac.account_collection_type
                    WHEN 'department'::text THEN x.dept_level
                    ELSE x.acct_coll_level + 1
                END AS "case",
                CASE ac.account_collection_type
                    WHEN 'department'::text THEN x.dept_level + 1
                    ELSE x.dept_level
                END AS dept_level,
                CASE
                    WHEN ac.account_collection_type::text = 'department'::text THEN 'AccountAssignedToChildDepartment'::text
                    WHEN x.dept_level > 1 AND x.acct_coll_level > 0 THEN 'ParentDepartmentAssignedToParentAccountCollection'::text
                    WHEN x.dept_level > 1 THEN 'ParentDepartmentAssignedToAccountCollection'::text
                    WHEN x.dept_level = 1 AND x.acct_coll_level > 0 THEN 'DepartmentAssignedToParentAccountCollection'::text
                    WHEN x.dept_level = 1 THEN 'DepartmentAssignedToAccountCollection'::text
                    ELSE 'AccountAssignedToParentAccountCollection'::text
                END AS assign_method,
            x.array_path || ach.account_collection_id AS array_path,
            ach.account_collection_id = ANY (x.array_path)
           FROM var_recurse x
             JOIN jazzhands.account_collection_hier ach ON x.account_collection_id = ach.child_account_collection_id
             JOIN jazzhands.account_collection ac ON ach.account_collection_id = ac.account_collection_id
          WHERE NOT x.cycle
        )
 SELECT var_recurse.account_collection_id,
    var_recurse.root_account_collection_id,
    var_recurse.account_id,
    var_recurse.acct_coll_level,
    var_recurse.dept_level,
    var_recurse.assign_method,
    array_to_string(var_recurse.array_path, '/'::text) AS text_path,
    var_recurse.array_path
   FROM var_recurse;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_acct_coll_acct_expanded_detail','v_acct_coll_acct_expanded_detail');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_acct_coll_acct_expanded_detail failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_acct_coll_acct_expanded_detail');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_acct_coll_acct_expanded_detail  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_acct_coll_acct_expanded_detail (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_acct_coll_acct_expanded_detail');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_acct_coll_acct_expanded_detail failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_acct_coll_acct_expanded_detail');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_acct_coll_acct_expanded_detail failed but that is ok';
	NULL;
END;
$$;

--- processing view v_acct_coll_expanded_detail in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_acct_coll_expanded_detail
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_acct_coll_expanded_detail', 'v_acct_coll_expanded_detail');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded_detail', tags := ARRAY['view_v_acct_coll_expanded_detail']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.v_acct_coll_expanded_detail;
CREATE VIEW jazzhands_legacy.v_acct_coll_expanded_detail AS
 WITH RECURSIVE var_recurse(root_account_collection_id, account_collection_id, account_collection_level, department_level, assignment_method, array_path, cycle) AS (
         SELECT ac.account_collection_id,
            ac.account_collection_id AS root_account_collection_id,
                CASE ac.account_collection_type
                    WHEN 'department'::text THEN 0
                    ELSE 1
                END AS account_collection_level,
                CASE ac.account_collection_type
                    WHEN 'department'::text THEN 1
                    ELSE 0
                END AS department_level,
                CASE ac.account_collection_type
                    WHEN 'department'::text THEN 'DirectDepartmentAssignment'::text
                    ELSE 'DirectAccountCollectionAssignment'::text
                END AS assignment_method,
            ARRAY[ac.account_collection_id] AS array_path,
            false AS "?column?"
           FROM jazzhands.account_collection ac
        UNION ALL
         SELECT x.root_account_collection_id,
            ach.account_collection_id,
                CASE ac.account_collection_type
                    WHEN 'department'::text THEN x.department_level
                    ELSE x.account_collection_level + 1
                END AS account_collection_level,
                CASE ac.account_collection_type
                    WHEN 'department'::text THEN x.department_level + 1
                    ELSE x.department_level
                END AS department_level,
                CASE
                    WHEN ac.account_collection_type::text = 'department'::text THEN 'AccountAssignedToChildDepartment'::text
                    WHEN x.department_level > 1 AND x.account_collection_level > 0 THEN 'ChildDepartmentAssignedToChildAccountCollection'::text
                    WHEN x.department_level > 1 THEN 'ChildDepartmentAssignedToAccountCollection'::text
                    WHEN x.department_level = 1 AND x.account_collection_level > 0 THEN 'DepartmentAssignedToChildAccountCollection'::text
                    WHEN x.department_level = 1 THEN 'DepartmentAssignedToAccountCollection'::text
                    ELSE 'AccountAssignedToChildAccountCollection'::text
                END AS assignment_method,
            x.array_path || ach.account_collection_id AS array_path,
            ach.account_collection_id = ANY (x.array_path)
           FROM var_recurse x
             JOIN jazzhands.account_collection_hier ach ON x.account_collection_id = ach.child_account_collection_id
             JOIN jazzhands.account_collection ac ON ach.account_collection_id = ac.account_collection_id
          WHERE NOT x.cycle
        )
 SELECT var_recurse.account_collection_id,
    var_recurse.root_account_collection_id,
    var_recurse.account_collection_level AS acct_coll_level,
    var_recurse.department_level AS dept_level,
    var_recurse.assignment_method AS assign_method,
    array_to_string(var_recurse.array_path, '/'::text) AS text_path,
    var_recurse.array_path
   FROM var_recurse;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_acct_coll_expanded_detail','v_acct_coll_expanded_detail');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_acct_coll_expanded_detail failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_acct_coll_expanded_detail');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_acct_coll_expanded_detail  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_acct_coll_expanded_detail (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_acct_coll_expanded_detail');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_acct_coll_expanded_detail failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_acct_coll_expanded_detail');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_acct_coll_expanded_detail failed but that is ok';
	NULL;
END;
$$;

--- processing view v_acct_coll_prop_expanded in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_acct_coll_prop_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_acct_coll_prop_expanded', 'v_acct_coll_prop_expanded');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_acct_coll_prop_expanded', tags := ARRAY['view_v_acct_coll_prop_expanded']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'val_property', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_acct_coll_prop_expanded;
CREATE VIEW jazzhands_legacy.v_acct_coll_prop_expanded AS
 SELECT v_acct_coll_expanded_detail.root_account_collection_id AS account_collection_id,
    v_property.property_id,
    v_property.property_name,
    v_property.property_type,
    v_property.property_value,
    v_property.property_value_timestamp,
    v_property.property_value_account_coll_id,
    v_property.property_value_nblk_coll_id,
    v_property.property_value_password_type,
    v_property.property_value_token_col_id,
    v_property.property_rank,
    val_property.is_multivalue,
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
   FROM jazzhands_legacy.v_acct_coll_expanded_detail
     JOIN jazzhands_legacy.account_collection ac USING (account_collection_id)
     JOIN jazzhands_legacy.v_property USING (account_collection_id)
     JOIN jazzhands_legacy.val_property USING (property_name, property_type);

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_acct_coll_prop_expanded','v_acct_coll_prop_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_acct_coll_prop_expanded failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_acct_coll_prop_expanded');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_acct_coll_prop_expanded  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_acct_coll_prop_expanded (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_acct_coll_prop_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_acct_coll_prop_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_acct_coll_prop_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_acct_coll_prop_expanded failed but that is ok';
	NULL;
END;
$$;

--- processing view v_application_role in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_application_role
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_application_role', 'v_application_role');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_application_role', tags := ARRAY['view_v_application_role']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.v_application_role;
CREATE VIEW jazzhands_legacy.v_application_role AS
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
          WHERE device_collection.device_collection_type::text = 'appgroup'::text AND NOT (device_collection.device_collection_id IN ( SELECT device_collection_hier.child_device_collection_id
                   FROM jazzhands.device_collection_hier))
        UNION ALL
         SELECT x.role_level + 1 AS role_level,
            dch.device_collection_id AS role_id,
            dch.device_collection_id AS parent_role_id,
            x.root_role_id,
            x.root_role_name,
            dc.device_collection_name AS role_name,
            (((x.role_path || '/'::text) || dc.device_collection_name::text))::character varying(255) AS role_path,
                CASE
                    WHEN lchk.device_collection_id IS NULL THEN 'Y'::text
                    ELSE 'N'::text
                END AS role_is_leaf,
            dch.device_collection_id || x.array_path AS array_path,
            dch.device_collection_id = ANY (x.array_path) AS cycle
           FROM var_recurse x
             JOIN jazzhands.device_collection_hier dch ON x.role_id = dch.device_collection_id
             JOIN jazzhands.device_collection dc ON dch.device_collection_id = dc.device_collection_id
             LEFT JOIN jazzhands.device_collection_hier lchk ON dch.device_collection_id = lchk.device_collection_id
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
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_application_role','v_application_role');
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
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_application_role');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_application_role  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_application_role (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_application_role');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_application_role failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_application_role');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_application_role failed but that is ok';
	NULL;
END;
$$;

--- processing view v_application_role_member in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_application_role_member
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_application_role_member', 'v_application_role_member');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_application_role_member', tags := ARRAY['view_v_application_role_member']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.v_application_role_member;
CREATE VIEW jazzhands_legacy.v_application_role_member AS
 SELECT device_collection_device.device_id,
    device_collection_device.device_collection_id AS role_id,
    device_collection_device.data_ins_user,
    device_collection_device.data_ins_date,
    device_collection_device.data_upd_user,
    device_collection_device.data_upd_date
   FROM jazzhands.device_collection_device
  WHERE (device_collection_device.device_collection_id IN ( SELECT device_collection.device_collection_id
           FROM jazzhands.device_collection
          WHERE device_collection.device_collection_type::text = 'appgroup'::text));

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_application_role_member','v_application_role_member');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_application_role_member failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_application_role_member');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_application_role_member  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_application_role_member (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_application_role_member');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_application_role_member failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_application_role_member');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_application_role_member failed but that is ok';
	NULL;
END;
$$;

--- processing view v_company_hier in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_company_hier
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_company_hier', 'v_company_hier');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_company_hier', tags := ARRAY['view_v_company_hier']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.v_company_hier;
CREATE VIEW jazzhands_legacy.v_company_hier AS
 WITH RECURSIVE var_recurse(level, root_company_id, company_id, array_path, cycle) AS (
         SELECT 0 AS level,
            c.company_id AS root_company_id,
            c.company_id,
            ARRAY[c.company_id] AS array_path,
            false AS cycle
           FROM jazzhands.company c
        UNION ALL
         SELECT x.level + 1 AS level,
            x.root_company_id,
            c.company_id,
            c.company_id || x.array_path AS array_path,
            c.company_id = ANY (x.array_path) AS cycle
           FROM var_recurse x
             JOIN jazzhands.company c ON c.parent_company_id = x.company_id
          WHERE NOT x.cycle
        )
 SELECT DISTINCT var_recurse.root_company_id,
    var_recurse.company_id
   FROM var_recurse;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_company_hier','v_company_hier');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_company_hier failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_company_hier');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_company_hier  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_company_hier (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_company_hier');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_company_hier failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_company_hier');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_company_hier failed but that is ok';
	NULL;
END;
$$;

--- processing view v_department_company_expanded in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_department_company_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_department_company_expanded', 'v_department_company_expanded');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_department_company_expanded', tags := ARRAY['view_v_department_company_expanded']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.v_department_company_expanded;
CREATE VIEW jazzhands_legacy.v_department_company_expanded AS
 WITH RECURSIVE var_recurse(level, root_company_id, company_id, account_collection_id, array_path, cycle) AS (
         SELECT 0 AS level,
            c.company_id AS root_company_id,
            c.company_id,
            d.account_collection_id,
            ARRAY[c.company_id] AS array_path,
            false AS "?column?"
           FROM jazzhands.company c
             JOIN jazzhands.department d USING (company_id)
        UNION ALL
         SELECT x.level + 1 AS level,
            x.company_id AS root_company_id,
            c.company_id,
            d.account_collection_id,
            c.company_id || x.array_path AS array_path,
            c.company_id = ANY (x.array_path) AS cycle
           FROM var_recurse x
             JOIN jazzhands.company c ON c.parent_company_id = x.company_id
             JOIN jazzhands.department d ON c.company_id = d.company_id
          WHERE NOT x.cycle
        )
 SELECT DISTINCT var_recurse.root_company_id AS company_id,
    var_recurse.account_collection_id
   FROM var_recurse;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_department_company_expanded','v_department_company_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_department_company_expanded failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_department_company_expanded');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_department_company_expanded  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_department_company_expanded (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_department_company_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_department_company_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_department_company_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_department_company_expanded failed but that is ok';
	NULL;
END;
$$;

--- processing view v_device_coll_device_expanded in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_coll_device_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_device_coll_device_expanded', 'v_device_coll_device_expanded');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_device_coll_device_expanded', tags := ARRAY['view_v_device_coll_device_expanded']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_device', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_coll_device_expanded;
CREATE VIEW jazzhands_legacy.v_device_coll_device_expanded AS
 WITH RECURSIVE var_recurse(root_device_collection_id, device_collection_id, parent_device_collection_id, device_collection_level, array_path, cycle) AS (
         SELECT device_collection.device_collection_id AS root_device_collection_id,
            device_collection.device_collection_id,
            device_collection.device_collection_id AS parent_device_collection_id,
            0 AS device_collection_level,
            ARRAY[device_collection.device_collection_id] AS "array",
            false AS "?column?"
           FROM jazzhands_legacy.device_collection
        UNION ALL
         SELECT x.root_device_collection_id,
            dch.child_device_collection_id AS device_collection_id,
            dch.device_collection_id AS parent_device_colletion_id,
            x.device_collection_level + 1 AS device_collection_level,
            dch.device_collection_id || x.array_path AS array_path,
            dch.device_collection_id = ANY (x.array_path)
           FROM var_recurse x
             JOIN jazzhands_legacy.device_collection_hier dch ON x.device_collection_id = dch.device_collection_id
          WHERE NOT x.cycle
        )
 SELECT DISTINCT var_recurse.root_device_collection_id AS device_collection_id,
    device_collection_device.device_id
   FROM var_recurse
     JOIN jazzhands_legacy.device_collection_device USING (device_collection_id);

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_device_coll_device_expanded','v_device_coll_device_expanded');
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
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_device_coll_device_expanded');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_device_coll_device_expanded  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_device_coll_device_expanded (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_coll_device_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_coll_device_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_coll_device_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_device_coll_device_expanded failed but that is ok';
	NULL;
END;
$$;

--- processing view v_dns_changes_pending in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_dns_changes_pending
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_dns_changes_pending', 'v_dns_changes_pending');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_dns_changes_pending', tags := ARRAY['view_v_dns_changes_pending']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.v_dns_changes_pending;
CREATE VIEW jazzhands_legacy.v_dns_changes_pending AS
 WITH chg AS NOT MATERIALIZED (
         SELECT dns_change_record.dns_change_record_id,
            dns_change_record.dns_domain_id,
                CASE
                    WHEN family(dns_change_record.ip_address) = 4 THEN set_masklen(dns_change_record.ip_address, 24)
                    ELSE set_masklen(dns_change_record.ip_address, 64)
                END AS ip_address,
            dns_utils.get_domain_from_cidr(dns_change_record.ip_address) AS cidrdns
           FROM jazzhands.dns_change_record
          WHERE dns_change_record.ip_address IS NOT NULL
        ), z AS NOT MATERIALIZED (
         SELECT x.dns_change_record_id,
            x.dns_domain_id,
            x.ip_universe_id,
            x.should_generate,
            x.last_generated,
            x.dns_domain_name,
            x.ip_address
           FROM ( SELECT chg.dns_change_record_id,
                    n.dns_domain_id,
                    du.ip_universe_id,
                    du.should_generate,
                    du.last_generated,
                    n.dns_domain_name,
                    chg.ip_address
                   FROM chg
                     JOIN jazzhands.dns_domain n ON chg.cidrdns = n.dns_domain_name::text
                     JOIN jazzhands.dns_domain_ip_universe du ON du.dns_domain_id = n.dns_domain_id
                UNION ALL
                 SELECT chg.dns_change_record_id,
                    d.dns_domain_id,
                    du.ip_universe_id,
                    du.should_generate,
                    du.last_generated,
                    d.dns_domain_name,
                    NULL::inet
                   FROM jazzhands.dns_change_record chg
                     JOIN jazzhands.dns_domain d USING (dns_domain_id)
                     JOIN jazzhands.dns_domain_ip_universe du USING (dns_domain_id)
                  WHERE chg.dns_domain_id IS NOT NULL AND chg.ip_universe_id IS NULL
                UNION ALL
                 SELECT chg.dns_change_record_id,
                    d.dns_domain_id,
                    chg.ip_universe_id,
                    du.should_generate,
                    du.last_generated,
                    d.dns_domain_name,
                    NULL::inet
                   FROM jazzhands.dns_change_record chg
                     JOIN jazzhands.dns_domain d USING (dns_domain_id)
                     JOIN jazzhands.dns_domain_ip_universe du USING (dns_domain_id, ip_universe_id)
                  WHERE chg.dns_domain_id IS NOT NULL AND chg.ip_universe_id IS NOT NULL
                UNION ALL
                 SELECT chg.dns_change_record_id,
                    d.dns_domain_id,
                    iv.visible_ip_universe_id,
                    du.should_generate,
                    du.last_generated,
                    d.dns_domain_name,
                    NULL::inet
                   FROM jazzhands.dns_change_record chg
                     JOIN jazzhands.ip_universe_visibility iv USING (ip_universe_id)
                     JOIN jazzhands.dns_domain d USING (dns_domain_id)
                     JOIN jazzhands.dns_domain_ip_universe du USING (dns_domain_id)
                  WHERE chg.dns_domain_id IS NOT NULL AND chg.ip_universe_id IS NOT NULL) x
        )
 SELECT z.dns_change_record_id,
    z.dns_domain_id,
    z.ip_universe_id,
        CASE
            WHEN z.should_generate IS NULL THEN NULL::text
            WHEN z.should_generate = true THEN 'Y'::text
            WHEN z.should_generate = false THEN 'N'::text
            ELSE NULL::text
        END AS should_generate,
    z.last_generated,
    z.dns_domain_name AS soa_name,
    z.ip_address
   FROM z;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_dns_changes_pending','v_dns_changes_pending');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_dns_changes_pending failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_dns_changes_pending');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_dns_changes_pending  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_dns_changes_pending (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dns_changes_pending');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_dns_changes_pending failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dns_changes_pending');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_dns_changes_pending failed but that is ok';
	NULL;
END;
$$;

--- processing view v_hotpants_token in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_hotpants_token
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_hotpants_token', 'v_hotpants_token');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_hotpants_token', tags := ARRAY['view_v_hotpants_token']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.v_hotpants_token;
CREATE VIEW jazzhands_legacy.v_hotpants_token AS
 SELECT t.token_id,
    t.token_type,
    t.token_status,
    t.token_serial,
    t.token_key,
    t.zero_time,
    t.time_modulo,
    t.token_password,
        CASE
            WHEN t.is_token_locked IS NULL THEN NULL::text
            WHEN t.is_token_locked = true THEN 'Y'::text
            WHEN t.is_token_locked = false THEN 'N'::text
            ELSE NULL::text
        END AS is_token_locked,
    t.token_unlock_time,
    t.bad_logins,
    ts.token_sequence,
    ts.last_updated,
    en.encryption_key_db_value,
    en.encryption_key_purpose,
    en.encryption_key_purpose_version,
    en.encryption_method
   FROM jazzhands.token t
     JOIN jazzhands.token_sequence ts USING (token_id)
     LEFT JOIN jazzhands.encryption_key en USING (encryption_key_id);

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_hotpants_token','v_hotpants_token');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_hotpants_token failed but that is ok';
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
-- considering NEW jazzhands_legacy.v_hotpants_token_upd
CREATE OR REPLACE FUNCTION jazzhands_legacy.v_hotpants_token_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	acct_realm_id	account_realm.account_realm_id%TYPE;
BEGIN
	IF OLD.token_sequence IS DISTINCT FROM NEW.token_sequence THEN
		PERFORM token_utils.set_sequence(
			p_token_id := NEW.token_id,
			p_token_sequence := NEW.token_sequence,
			p_reset_time := NEW.last_updated::timestamp
		);
	END IF;

	IF OLD.bad_logins IS DISTINCT FROM NEW.bad_logins THEN
		PERFORM token_utils.set_lock_status(
			p_token_id := NEW.token_id,
			p_lock_status := NEW.is_token_locked,
			p_unlock_time := NEW.token_unlock_time,
			p_bad_logins := NEW.bad_logins,
			p_last_updated :=NEW.last_updated::timestamp
		);
	END IF;
	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands_legacy.v_hotpants_token_upd() FROM public;
CREATE TRIGGER trigger_v_hotpants_token_upd INSTEAD OF UPDATE ON jazzhands_legacy.v_hotpants_token FOR EACH ROW EXECUTE FUNCTION jazzhands_legacy.v_hotpants_token_upd();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_hotpants_token');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_hotpants_token  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_hotpants_token (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_hotpants_token');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_hotpants_token failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_hotpants_token');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_hotpants_token failed but that is ok';
	NULL;
END;
$$;

--- processing view v_nblk_coll_netblock_expanded in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_nblk_coll_netblock_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_nblk_coll_netblock_expanded', 'v_nblk_coll_netblock_expanded');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_nblk_coll_netblock_expanded', tags := ARRAY['view_v_nblk_coll_netblock_expanded']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.v_nblk_coll_netblock_expanded;
CREATE VIEW jazzhands_legacy.v_nblk_coll_netblock_expanded AS
 WITH RECURSIVE var_recurse(level, root_collection_id, netblock_collection_id, child_netblock_collection_id, array_path, cycle) AS (
         SELECT 0 AS level,
            u.netblock_collection_id AS root_collection_id,
            u.netblock_collection_id,
            u.netblock_collection_id AS child_netblock_collection_id,
            ARRAY[u.netblock_collection_id] AS array_path,
            false AS cycle
           FROM jazzhands.netblock_collection u
        UNION ALL
         SELECT x.level + 1 AS level,
            x.netblock_collection_id AS root_netblock_collection_id,
            uch.child_netblock_collection_id AS netblock_collection_id,
            uch.child_netblock_collection_id,
            uch.child_netblock_collection_id || x.array_path AS array_path,
            uch.child_netblock_collection_id = ANY (x.array_path) AS cycle
           FROM var_recurse x
             JOIN jazzhands.netblock_collection_hier uch ON x.child_netblock_collection_id = uch.netblock_collection_id
          WHERE NOT x.cycle
        )
 SELECT DISTINCT var_recurse.root_collection_id AS netblock_collection_id,
    netblock_collection_netblock.netblock_id
   FROM var_recurse
     JOIN jazzhands.netblock_collection_netblock USING (netblock_collection_id);

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_nblk_coll_netblock_expanded','v_nblk_coll_netblock_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_nblk_coll_netblock_expanded failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_nblk_coll_netblock_expanded');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_nblk_coll_netblock_expanded  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_nblk_coll_netblock_expanded (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_nblk_coll_netblock_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_nblk_coll_netblock_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_nblk_coll_netblock_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_nblk_coll_netblock_expanded failed but that is ok';
	NULL;
END;
$$;

--- processing view val_physicalish_volume_type in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE val_physicalish_volume_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'val_physicalish_volume_type', 'val_physicalish_volume_type');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'val_physicalish_volume_type', tags := ARRAY['view_val_physicalish_volume_type']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.val_physicalish_volume_type;
CREATE VIEW jazzhands_legacy.val_physicalish_volume_type AS
 SELECT val_block_storage_device_type.block_storage_device_type AS physicalish_volume_type,
    val_block_storage_device_type.description,
    val_block_storage_device_type.data_ins_user,
    val_block_storage_device_type.data_ins_date,
    val_block_storage_device_type.data_upd_user,
    val_block_storage_device_type.data_upd_date
   FROM jazzhands.val_block_storage_device_type;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('val_physicalish_volume_type','val_physicalish_volume_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of val_physicalish_volume_type failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('val_physicalish_volume_type');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_physicalish_volume_type  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE val_physicalish_volume_type (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('val_physicalish_volume_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_physicalish_volume_type failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('val_physicalish_volume_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_physicalish_volume_type failed but that is ok';
	NULL;
END;
$$;

--- processing view val_x509_fingerprint_hash_algorithm in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE val_x509_fingerprint_hash_algorithm
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'val_x509_fingerprint_hash_algorithm', 'val_x509_fingerprint_hash_algorithm');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'val_x509_fingerprint_hash_algorithm', tags := ARRAY['view_val_x509_fingerprint_hash_algorithm']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.val_x509_fingerprint_hash_algorithm;
CREATE VIEW jazzhands_legacy.val_x509_fingerprint_hash_algorithm AS
 SELECT val_x509_fingerprint_hash_algorithm.cryptographic_hash_algorithm AS x509_fingerprint_hash_algorighm,
    val_x509_fingerprint_hash_algorithm.description,
    val_x509_fingerprint_hash_algorithm.data_ins_user,
    val_x509_fingerprint_hash_algorithm.data_ins_date,
    val_x509_fingerprint_hash_algorithm.data_upd_user,
    val_x509_fingerprint_hash_algorithm.data_upd_date
   FROM jazzhands.val_x509_fingerprint_hash_algorithm;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('val_x509_fingerprint_hash_algorithm','val_x509_fingerprint_hash_algorithm');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of val_x509_fingerprint_hash_algorithm failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('val_x509_fingerprint_hash_algorithm');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_x509_fingerprint_hash_algorithm  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE val_x509_fingerprint_hash_algorithm (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('val_x509_fingerprint_hash_algorithm');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_x509_fingerprint_hash_algorithm failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('val_x509_fingerprint_hash_algorithm');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_x509_fingerprint_hash_algorithm failed but that is ok';
	NULL;
END;
$$;

--- processing view volume_group_physicalish_vol in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE volume_group_physicalish_vol
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'volume_group_physicalish_vol', 'volume_group_physicalish_vol');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'volume_group_physicalish_vol', tags := ARRAY['view_volume_group_physicalish_vol']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.volume_group_physicalish_vol;
CREATE VIEW jazzhands_legacy.volume_group_physicalish_vol AS
 SELECT volume_group_block_storage_device.block_storage_device_id AS physicalish_volume_id,
    volume_group_block_storage_device.volume_group_id,
    volume_group_block_storage_device.device_id,
    volume_group_block_storage_device.volume_group_primary_position,
    volume_group_block_storage_device.volume_group_secondary_position,
    volume_group_block_storage_device.volume_group_relation,
    volume_group_block_storage_device.data_ins_user,
    volume_group_block_storage_device.data_ins_date,
    volume_group_block_storage_device.data_upd_user,
    volume_group_block_storage_device.data_upd_date
   FROM jazzhands.volume_group_block_storage_device;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('volume_group_physicalish_vol','volume_group_physicalish_vol');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of volume_group_physicalish_vol failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('volume_group_physicalish_vol');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for volume_group_physicalish_vol  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE volume_group_physicalish_vol (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('volume_group_physicalish_vol');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old volume_group_physicalish_vol failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('volume_group_physicalish_vol');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new volume_group_physicalish_vol failed but that is ok';
	NULL;
END;
$$;

--- processing view x509_signed_certificate_fingerprint in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE x509_signed_certificate_fingerprint
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'x509_signed_certificate_fingerprint', 'x509_signed_certificate_fingerprint');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'x509_signed_certificate_fingerprint', tags := ARRAY['view_x509_signed_certificate_fingerprint']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.x509_signed_certificate_fingerprint;
CREATE VIEW jazzhands_legacy.x509_signed_certificate_fingerprint AS
 SELECT x509_signed_certificate_fingerprint.x509_signed_certificate_id,
    x509_signed_certificate_fingerprint.cryptographic_hash_algorithm AS x509_fingerprint_hash_algorighm,
    x509_signed_certificate_fingerprint.fingerprint,
    x509_signed_certificate_fingerprint.description,
    x509_signed_certificate_fingerprint.data_ins_user,
    x509_signed_certificate_fingerprint.data_ins_date,
    x509_signed_certificate_fingerprint.data_upd_user,
    x509_signed_certificate_fingerprint.data_upd_date
   FROM jazzhands.x509_signed_certificate_fingerprint;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('x509_signed_certificate_fingerprint','x509_signed_certificate_fingerprint');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of x509_signed_certificate_fingerprint failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('x509_signed_certificate_fingerprint');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for x509_signed_certificate_fingerprint  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE x509_signed_certificate_fingerprint (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('x509_signed_certificate_fingerprint');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old x509_signed_certificate_fingerprint failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('x509_signed_certificate_fingerprint');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new x509_signed_certificate_fingerprint failed but that is ok';
	NULL;
END;
$$;

--- processing view device_management_controller in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE device_management_controller
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'device_management_controller', 'device_management_controller');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'device_management_controller', tags := ARRAY['view_device_management_controller']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.device_management_controller;
CREATE VIEW jazzhands_legacy.device_management_controller AS
 SELECT md.manager_device_id,
    d.device_id,
    c.component_management_controller_type AS device_mgmt_control_type,
    c.description,
    c.data_ins_user,
    c.data_ins_date,
    c.data_upd_user,
    c.data_upd_date
   FROM jazzhands.component_management_controller c
     JOIN ( SELECT device.device_id,
            device.component_id
           FROM jazzhands.device) d USING (component_id)
     JOIN ( SELECT device.device_id AS manager_device_id,
            device.component_id AS manager_component_id
           FROM jazzhands.device) md USING (manager_component_id);

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('device_management_controller','device_management_controller');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of device_management_controller failed but that is ok';
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
-- considering NEW jazzhands_legacy.device_management_controller_del
CREATE OR REPLACE FUNCTION jazzhands_legacy.device_management_controller_del()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_c			jazzhands.component_management_controller.component_id%TYPE;
	_mc			jazzhands.component_management_controller.component_id%TYPE;
	_cmc		jazzhands.component_management_controller%ROWTYPE;
BEGIN
	SELECT	component_id
	INTO	_c
	FROM	device
	WHERE	device_id = OLD.device_id;

	SELECT	component_id
	INTO	_mc
	FROM	device
	WHERE	device_id = OLD.manager_device_id;

	DELETE FROM component_management_controller
	WHERE component_id IS NOT DISTINCT FROM  _c
	AND manager_component_id IS NOT DISTINCT FROM _mc
	RETURNING * INTO _cmc;

	OLD.device_mgmt_control_type	= _cmc.component_management_controller_type;
	OLD.description					= _cmc.description;

	OLD.data_ins_user := _cmc.data_ins_user;
	OLD.data_ins_date := _cmc.data_ins_date;
	OLD.data_upd_user := _cmc.data_upd_user;
	OLD.data_upd_date := _cmc.data_upd_date;

	RETURN OLD;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands_legacy.device_management_controller_del() FROM public;
CREATE TRIGGER trigger_device_management_controller_del INSTEAD OF DELETE ON jazzhands_legacy.device_management_controller FOR EACH ROW EXECUTE FUNCTION jazzhands_legacy.device_management_controller_del();

-- considering NEW jazzhands_legacy.device_management_controller_ins
CREATE OR REPLACE FUNCTION jazzhands_legacy.device_management_controller_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_c		jazzhands.component_management_controller.component_id%TYPE;
	_mc		jazzhands.component_management_controller.component_id%TYPE;
	_cmc	jazzhands.component_management_controller%ROWTYPE;
BEGIN
	SELECT	component_id
	INTO	_c
	FROM	device
	WHERE	device_id IS NOT DISTINCT FROM NEW.device_id;

	IF _c IS NULL THEN
			RAISE EXCEPTION 'device_id may not be NULL or there is no component associated with the device.'
			USING ERRCODE = 'not_null_violation';
	END IF;

	SELECT	component_id
	INTO	_mc
	FROM	device
	WHERE	device_id IS NOT DISTINCT FROM NEW.manager_device_id;

	IF _mc IS NULL THEN
			RAISE EXCEPTION 'manager_device_id may not be NULL or there is no component associated with the device.'
			USING ERRCODE = 'not_null_violation';
	END IF;

	INSERT INTO component_management_controller (
		manager_component_id, component_id,
		component_management_controller_type, description
	) VALUES (
		_mc, _c,
		NEW.device_mgmt_control_type, NEW.description
	) RETURNING * INTO _cmc;

	NEW.data_ins_user := _cmc.data_ins_user;
	NEW.data_ins_date := _cmc.data_ins_date;
	NEW.data_upd_user := _cmc.data_upd_user;
	NEW.data_upd_date := _cmc.data_upd_date;

	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands_legacy.device_management_controller_ins() FROM public;
CREATE TRIGGER trigger_device_management_controller_ins INSTEAD OF INSERT ON jazzhands_legacy.device_management_controller FOR EACH ROW EXECUTE FUNCTION jazzhands_legacy.device_management_controller_ins();

-- considering NEW jazzhands_legacy.device_management_controller_upd
CREATE OR REPLACE FUNCTION jazzhands_legacy.device_management_controller_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	upd_query	TEXT[];
	_c			jazzhands.component_management_controller.component_id%TYPE;
	_oc			jazzhands.component_management_controller.component_id%TYPE;
	_omc		jazzhands.component_management_controller.component_id%TYPE;
	_cmc		jazzhands.component_management_controller%ROWTYPE;
BEGIN
	upd_query := NULL;
	IF OLD.device_id IS DISTINCT FROM NEW.device_id THEN
		SELECT	component_id
		INTO	_c
		FROM	device
		WHERE	device_id IS NOT DISTINCT FROM NEW.device_id;

		IF _c IS NULL THEN
				RAISE EXCEPTION 'device_id may not be NULL or there is no component associated with the device.'
				USING ERRCODE = 'not_null_violation';
		END IF;

		upd_query := array_append(upd_query,
			'component_id = ' || quote_nullable(_c));
	END IF;

	IF OLD.manager_device_id IS DISTINCT FROM NEW.manager_device_id THEN
		SELECT	component_id
		INTO	_c
		FROM	device
		WHERE	device_id IS NOT DISTINCT FROM NEW.manager_device_id;

		IF _c IS NULL THEN
				RAISE EXCEPTION 'manager_device_id may not be NULL or there is no component associated with the device.'
				USING ERRCODE = 'not_null_violation';
		END IF;

		upd_query := array_append(upd_query,
			'manager_component_id = ' || quote_nullable(_c));
	END IF;

	IF NEW.description IS DISTINCT FROM OLD.description THEN
		upd_query := array_append(upd_query,
		'description = ' || quote_nullable(NEW.description));
	END IF;

	IF NEW.device_mgmt_control_type IS DISTINCT FROM OLD.device_mgmt_control_type THEN
		upd_query := array_append(upd_query,
		'component_management_controller_type = ' || quote_nullable(NEW.device_mgmt_control_type));
	END IF;

	IF upd_query IS NOT NULL THEN
		SELECT component_id INTO _cmc.component_id
		FROM device WHERE device_id = OLD.device_id;

		SELECT component_id INTO _cmc.manager_component_id
		FROM device WHERE device_id = OLD.manager_device_id;

		EXECUTE 'UPDATE component_management_controller SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE component_id = $1 AND manager_component_id = $2 RETURNING *'
			USING _cmc.component_id, _cmc.manager_component_id
			INTO _cmc;

		NEW.device_mgmt_control_type	= _cmc.component_management_controller_type;
		NEW.description					= _cmc.description;

		NEW.data_ins_user := _cmc.data_ins_user;
		NEW.data_ins_date := _cmc.data_ins_date;
		NEW.data_upd_user := _cmc.data_upd_user;
		NEW.data_upd_date := _cmc.data_upd_date;
	END IF;

	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands_legacy.device_management_controller_upd() FROM public;
CREATE TRIGGER trigger_device_management_controller_upd INSTEAD OF UPDATE ON jazzhands_legacy.device_management_controller FOR EACH ROW EXECUTE FUNCTION jazzhands_legacy.device_management_controller_upd();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('device_management_controller');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for device_management_controller  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE device_management_controller (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('device_management_controller');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old device_management_controller failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('device_management_controller');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new device_management_controller failed but that is ok';
	NULL;
END;
$$;

--- processing view v_property in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_property
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_property', 'v_property');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_property', tags := ARRAY['view_v_property']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
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
    v_property.property_name_collection_id AS property_collection_id,
    v_property.service_environment_collection_id AS service_env_collection_id,
    v_property.site_code,
    v_property.x509_signed_certificate_id,
    v_property.property_name,
    v_property.property_type,
        CASE
            WHEN v_property.property_value_boolean = true THEN 'Y'::character varying
            WHEN v_property.property_value_boolean = false THEN 'N'::character varying
            ELSE v_property.property_value
        END::character varying(1024) AS property_value,
    v_property.property_value_timestamp,
    v_property.property_value_account_collection_id AS property_value_account_coll_id,
    v_property.property_value_device_collection_id AS property_value_device_coll_id,
    v_property.property_value_json,
    v_property.property_value_netblock_collection_id AS property_value_nblk_coll_id,
    v_property.property_value_password_type,
    NULL::integer AS property_value_sw_package_id,
    v_property.property_value_token_collection_id AS property_value_token_col_id,
    v_property.property_rank,
    v_property.start_date,
    v_property.finish_date,
        CASE
            WHEN v_property.is_enabled IS NULL THEN NULL::text
            WHEN v_property.is_enabled = true THEN 'Y'::text
            WHEN v_property.is_enabled = false THEN 'N'::text
            ELSE NULL::text
        END AS is_enabled,
    v_property.data_ins_user,
    v_property.data_ins_date,
    v_property.data_upd_user,
    v_property.data_upd_date
   FROM jazzhands.v_property;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_property','v_property');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_property failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_property');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_property  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_property (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_property');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_property failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_property');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_property failed but that is ok';
	NULL;
END;
$$;

--- processing view v_device_coll_hier_detail in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_coll_hier_detail
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_device_coll_hier_detail', 'v_device_coll_hier_detail');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', tags := ARRAY['view_v_device_coll_hier_detail']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_coll_hier_detail;
CREATE VIEW jazzhands_legacy.v_device_coll_hier_detail AS
 WITH RECURSIVE var_recurse(root_device_collection_id, device_collection_id, parent_device_collection_id, device_collection_level, array_path, cycle) AS (
         SELECT device_collection.device_collection_id AS root_device_collection_id,
            device_collection.device_collection_id,
            device_collection.device_collection_id AS parent_device_collection_id,
            0 AS device_collection_level,
            ARRAY[device_collection.device_collection_id] AS "array",
            false AS "?column?"
           FROM jazzhands_legacy.device_collection
        UNION ALL
         SELECT x.root_device_collection_id,
            dch.child_device_collection_id AS device_collection_id,
            dch.device_collection_id AS parent_device_collection_id,
            x.device_collection_level + 1 AS device_collection_level,
            dch.device_collection_id || x.array_path AS array_path,
            dch.device_collection_id = ANY (x.array_path)
           FROM var_recurse x
             JOIN jazzhands_legacy.device_collection_hier dch ON x.parent_device_collection_id = dch.child_device_collection_id
          WHERE NOT x.cycle
        )
 SELECT var_recurse.root_device_collection_id AS device_collection_id,
    var_recurse.parent_device_collection_id,
    var_recurse.device_collection_level
   FROM var_recurse;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_device_coll_hier_detail','v_device_coll_hier_detail');
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
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_device_coll_hier_detail');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_device_coll_hier_detail  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_device_coll_hier_detail (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_coll_hier_detail');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_coll_hier_detail failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_coll_hier_detail');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_device_coll_hier_detail failed but that is ok';
	NULL;
END;
$$;

--- processing view v_dev_col_root in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_dev_col_root
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_dev_col_root', 'v_dev_col_root');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_dev_col_root', tags := ARRAY['view_v_dev_col_root']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_dev_col_root;
CREATE VIEW jazzhands_legacy.v_dev_col_root AS
 WITH x AS (
         SELECT c.device_collection_id AS leaf_id,
            c.device_collection_name AS leaf_name,
            c.device_collection_type AS leaf_type,
            p.device_collection_id AS root_id,
            p.device_collection_name AS root_name,
            p.device_collection_type AS root_type,
            dch.device_collection_level
           FROM jazzhands_legacy.device_collection c
             JOIN jazzhands_legacy.v_device_coll_hier_detail dch ON dch.device_collection_id = c.device_collection_id
             JOIN jazzhands_legacy.device_collection p ON dch.parent_device_collection_id = p.device_collection_id AND p.device_collection_type::text = c.device_collection_type::text
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

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_dev_col_root','v_dev_col_root');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_dev_col_root failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_dev_col_root');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_dev_col_root  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_dev_col_root (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dev_col_root');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_dev_col_root failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dev_col_root');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_dev_col_root failed but that is ok';
	NULL;
END;
$$;

--- processing view v_device_col_acct_col_expanded in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_col_acct_col_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_device_col_acct_col_expanded', 'v_device_col_acct_col_expanded');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_device_col_acct_col_expanded', tags := ARRAY['view_v_device_col_acct_col_expanded']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_col_acct_col_expanded;
CREATE VIEW jazzhands_legacy.v_device_col_acct_col_expanded AS
 SELECT DISTINCT dchd.device_collection_id,
    dcu.account_collection_id,
    vuue.account_id
   FROM jazzhands_legacy.v_device_coll_hier_detail dchd
     JOIN jazzhands_legacy.v_property dcu ON dcu.device_collection_id = dchd.parent_device_collection_id
     JOIN jazzhands_legacy.v_acct_coll_acct_expanded vuue ON vuue.account_collection_id = dcu.account_collection_id
  WHERE dcu.property_name::text = 'UnixLogin'::text AND dcu.property_type::text = 'MclassUnixProp'::text;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_device_col_acct_col_expanded','v_device_col_acct_col_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_device_col_acct_col_expanded failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_device_col_acct_col_expanded');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_device_col_acct_col_expanded  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_device_col_acct_col_expanded (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_col_acct_col_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_col_acct_col_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_col_acct_col_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_device_col_acct_col_expanded failed but that is ok';
	NULL;
END;
$$;

--- processing view v_acct_coll_expanded in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_acct_coll_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_acct_coll_expanded', 'v_acct_coll_expanded');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', tags := ARRAY['view_v_acct_coll_expanded']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.v_acct_coll_expanded;
CREATE VIEW jazzhands_legacy.v_acct_coll_expanded AS
 WITH RECURSIVE acct_coll_recurse(level, root_account_collection_id, account_collection_id, array_path, rvs_array_path, cycle) AS (
         SELECT 0 AS level,
            ac.account_collection_id AS root_account_collection_id,
            ac.account_collection_id,
            ARRAY[ac.account_collection_id] AS array_path,
            ARRAY[ac.account_collection_id] AS rvs_array_path,
            false AS "?column?"
           FROM jazzhands.account_collection ac
        UNION ALL
         SELECT x.level + 1 AS level,
            x.root_account_collection_id,
            ach.account_collection_id,
            x.array_path || ach.account_collection_id AS array_path,
            ach.account_collection_id || x.rvs_array_path AS rvs_array_path,
            ach.account_collection_id = ANY (x.array_path) AS cycle
           FROM acct_coll_recurse x
             JOIN jazzhands.account_collection_hier ach ON x.account_collection_id = ach.child_account_collection_id
          WHERE NOT x.cycle
        )
 SELECT acct_coll_recurse.level,
    acct_coll_recurse.account_collection_id,
    acct_coll_recurse.root_account_collection_id,
    array_to_string(acct_coll_recurse.array_path, '/'::text) AS text_path,
    acct_coll_recurse.array_path,
    acct_coll_recurse.rvs_array_path
   FROM acct_coll_recurse;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_acct_coll_expanded','v_acct_coll_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_acct_coll_expanded failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_acct_coll_expanded');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_acct_coll_expanded  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_acct_coll_expanded (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_acct_coll_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_acct_coll_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_acct_coll_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_acct_coll_expanded failed but that is ok';
	NULL;
END;
$$;

--- processing view v_acct_coll_acct_expanded in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_acct_coll_acct_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_acct_coll_acct_expanded', 'v_acct_coll_acct_expanded');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded', tags := ARRAY['view_v_acct_coll_acct_expanded']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_acct_coll_acct_expanded;
CREATE VIEW jazzhands_legacy.v_acct_coll_acct_expanded AS
 SELECT DISTINCT ace.account_collection_id,
    aca.account_id
   FROM jazzhands_legacy.v_acct_coll_expanded ace
     JOIN jazzhands.v_account_collection_account aca ON aca.account_collection_id = ace.root_account_collection_id;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_acct_coll_acct_expanded','v_acct_coll_acct_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_acct_coll_acct_expanded failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_acct_coll_acct_expanded');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_acct_coll_acct_expanded  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_acct_coll_acct_expanded (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_acct_coll_acct_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_acct_coll_acct_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_acct_coll_acct_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_acct_coll_acct_expanded failed but that is ok';
	NULL;
END;
$$;

--- processing view v_device_collection_root in ancilary schema
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_collection_root (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_collection_root');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_audit', 'v_device_collection_root');
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_collection_root;
CREATE VIEW jazzhands_legacy.v_device_collection_root AS
 WITH x AS (
         SELECT c.device_collection_id AS leaf_id,
            c.device_collection_name AS leaf_name,
            c.device_collection_type AS leaf_type,
            p.device_collection_id AS root_id,
            p.device_collection_name AS root_name,
            p.device_collection_type AS root_type,
            dch.device_collection_level
           FROM jazzhands_legacy.device_collection c
             JOIN jazzhands_legacy.v_device_coll_hier_detail dch ON dch.device_collection_id = c.device_collection_id
             JOIN jazzhands_legacy.device_collection p ON dch.parent_device_collection_id = p.device_collection_id AND p.device_collection_type::text = c.device_collection_type::text
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

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_device_collection_root','v_device_collection_root');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_device_collection_root failed but that is ok';
	NULL;
END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_device_collection_root');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_device_collection_root  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_device_collection_root (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_collection_root');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_collection_root failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_collection_root');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_device_collection_root failed but that is ok';
	NULL;
END;
$$;

--- processing view v_dev_col_device_root in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_dev_col_device_root
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_dev_col_device_root', 'v_dev_col_device_root');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_dev_col_device_root', tags := ARRAY['view_v_dev_col_device_root']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_device', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_dev_col_device_root;
CREATE VIEW jazzhands_legacy.v_dev_col_device_root AS
 WITH x AS (
         SELECT dcd.device_id,
            c.device_collection_id AS leaf_id,
            c.device_collection_name AS leaf_name,
            c.device_collection_type AS leaf_type,
            p.device_collection_id AS root_id,
            p.device_collection_name AS root_name,
            p.device_collection_type AS root_type,
            dch.device_collection_level
           FROM jazzhands_legacy.v_device_coll_hier_detail dch
             JOIN jazzhands_legacy.device_collection_device dcd USING (device_collection_id)
             JOIN jazzhands_legacy.device_collection c ON dch.device_collection_id = c.device_collection_id
             JOIN jazzhands_legacy.device_collection p ON dch.parent_device_collection_id = p.device_collection_id
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

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_dev_col_device_root','v_dev_col_device_root');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_dev_col_device_root failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_dev_col_device_root');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_dev_col_device_root  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_dev_col_device_root (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dev_col_device_root');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_dev_col_device_root failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dev_col_device_root');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_dev_col_device_root failed but that is ok';
	NULL;
END;
$$;

--- processing view v_dev_col_user_prop_expanded in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_dev_col_user_prop_expanded
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_dev_col_user_prop_expanded', 'v_dev_col_user_prop_expanded');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_dev_col_user_prop_expanded', tags := ARRAY['view_v_dev_col_user_prop_expanded']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_realm', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'val_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'val_property_data_type', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_dev_col_user_prop_expanded;
CREATE VIEW jazzhands_legacy.v_dev_col_user_prop_expanded AS
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
    COALESCE(upo.property_value_password_type, upo.property_value) AS property_value,
        CASE
            WHEN upn.is_multivalue = 'N'::text THEN 0
            ELSE 1
        END AS is_multivalue,
        CASE
            WHEN pdt.property_data_type::text = 'boolean'::text THEN 1
            ELSE 0
        END AS is_boolean
   FROM jazzhands_legacy.v_acct_coll_acct_expanded_detail uued
     JOIN jazzhands_legacy.account_collection u USING (account_collection_id)
     JOIN jazzhands_legacy.v_property upo ON upo.account_collection_id = u.account_collection_id AND (upo.property_type::text = ANY (ARRAY['CCAForceCreation'::character varying, 'CCARight'::character varying, 'ConsoleACL'::character varying, 'RADIUS'::character varying, 'TokenMgmt'::character varying, 'UnixPasswdFileValue'::character varying, 'UserMgmt'::character varying, 'cca'::character varying, 'feed-attributes'::character varying, 'wwwgroup'::character varying, 'HOTPants'::character varying]::text[]))
     JOIN jazzhands_legacy.val_property upn ON upo.property_name::text = upn.property_name::text AND upo.property_type::text = upn.property_type::text
     JOIN jazzhands_legacy.val_property_data_type pdt ON upn.property_data_type::text = pdt.property_data_type::text
     JOIN jazzhands_legacy.account a ON uued.account_id = a.account_id
     JOIN jazzhands_legacy.account_realm ar ON a.account_realm_id = ar.account_realm_id
     LEFT JOIN jazzhands_legacy.v_device_coll_hier_detail dchd ON dchd.parent_device_collection_id = upo.device_collection_id
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
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_dev_col_user_prop_expanded','v_dev_col_user_prop_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_dev_col_user_prop_expanded failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_dev_col_user_prop_expanded');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_dev_col_user_prop_expanded  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_dev_col_user_prop_expanded (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dev_col_user_prop_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_dev_col_user_prop_expanded failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dev_col_user_prop_expanded');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_dev_col_user_prop_expanded failed but that is ok';
	NULL;
END;
$$;

--- processing view v_unix_account_overrides in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_unix_account_overrides
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_unix_account_overrides', 'v_unix_account_overrides');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_unix_account_overrides', tags := ARRAY['view_v_unix_account_overrides']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_device', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_prop_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'val_property', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_unix_account_overrides;
CREATE VIEW jazzhands_legacy.v_unix_account_overrides AS
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
                           FROM jazzhands_legacy.v_acct_coll_prop_expanded acpe
                             JOIN jazzhands_legacy.v_acct_coll_acct_expanded acae USING (account_collection_id)
                             JOIN jazzhands_legacy.v_property p USING (property_id)
                             JOIN ( SELECT v_device_coll_hier_detail.device_collection_id,
                                    v_device_coll_hier_detail.parent_device_collection_id,
                                    v_device_coll_hier_detail.device_collection_level
                                   FROM jazzhands_legacy.v_device_coll_hier_detail
                                UNION ALL
                                 SELECT p_1.host_device_collection_id AS device_collection_id,
                                    d.parent_device_collection_id,
                                    d.device_collection_level
                                   FROM ( SELECT hdc.device_collection_id AS host_device_collection_id,
    mdc.device_collection_id AS mclass_device_collection_id,
    hdcd.device_id
   FROM jazzhands_legacy.device_collection hdc
     JOIN jazzhands_legacy.device_collection_device hdcd USING (device_collection_id)
     JOIN jazzhands_legacy.device_collection_device mdcd USING (device_id)
     JOIN jazzhands_legacy.device_collection mdc ON mdcd.device_collection_id = mdc.device_collection_id
  WHERE hdc.device_collection_type::text = 'per-device'::text AND mdc.device_collection_type::text = 'mclass'::text) p_1
                                     JOIN jazzhands_legacy.v_device_coll_hier_detail d ON d.device_collection_id = p_1.mclass_device_collection_id) dchd ON dchd.parent_device_collection_id = p.device_collection_id
                          WHERE (p.property_type::text = ANY (ARRAY['UnixPasswdFileValue'::character varying, 'UnixGroupFileProperty'::character varying, 'MclassUnixProp'::character varying]::text[])) AND (p.property_name::text <> ALL (ARRAY['UnixLogin'::character varying, 'UnixGroup'::character varying, 'UnixGroupMemberOverride'::character varying]::text[]))) dc_acct_prop_list
                  WHERE dc_acct_prop_list.ord = 1) select_for_ordering) property_list
  GROUP BY property_list.device_collection_id, property_list.account_id;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_unix_account_overrides','v_unix_account_overrides');
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_unix_account_overrides');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_unix_account_overrides  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_unix_account_overrides (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_unix_account_overrides');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_unix_account_overrides failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_unix_account_overrides');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_unix_account_overrides failed but that is ok';
	NULL;
END;
$$;

--- processing view v_device_col_acct_col_unixgroup in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_col_acct_col_unixgroup
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_device_col_acct_col_unixgroup', 'v_device_col_acct_col_unixgroup');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_device_col_acct_col_unixgroup', tags := ARRAY['view_v_device_col_acct_col_unixgroup']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_col_acct_col_unixgroup;
CREATE VIEW jazzhands_legacy.v_device_col_acct_col_unixgroup AS
 SELECT DISTINCT dchd.device_collection_id,
    ace.account_collection_id
   FROM jazzhands_legacy.v_device_coll_hier_detail dchd
     JOIN jazzhands_legacy.v_property dcu ON dcu.device_collection_id = dchd.parent_device_collection_id
     JOIN jazzhands_legacy.v_acct_coll_expanded ace ON dcu.account_collection_id = ace.root_account_collection_id
  WHERE dcu.property_name::text = 'UnixGroup'::text AND dcu.property_type::text = 'MclassUnixProp'::text;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_device_col_acct_col_unixgroup','v_device_col_acct_col_unixgroup');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_device_col_acct_col_unixgroup failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_device_col_acct_col_unixgroup');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_device_col_acct_col_unixgroup  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_device_col_acct_col_unixgroup (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_col_acct_col_unixgroup');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_col_acct_col_unixgroup failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_col_acct_col_unixgroup');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_device_col_acct_col_unixgroup failed but that is ok';
	NULL;
END;
$$;

--- processing view v_device_col_acct_col_unixlogin in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_col_acct_col_unixlogin
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_device_col_acct_col_unixlogin', 'v_device_col_acct_col_unixlogin');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_device_col_acct_col_unixlogin', tags := ARRAY['view_v_device_col_acct_col_unixlogin']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_col_acct_col_unixlogin;
CREATE VIEW jazzhands_legacy.v_device_col_acct_col_unixlogin AS
 SELECT DISTINCT dchd.device_collection_id,
    dcu.account_collection_id,
    vuue.account_id
   FROM jazzhands_legacy.v_device_coll_hier_detail dchd
     JOIN jazzhands_legacy.v_property dcu ON dcu.device_collection_id = dchd.parent_device_collection_id
     JOIN jazzhands_legacy.v_acct_coll_acct_expanded vuue ON vuue.account_collection_id = dcu.account_collection_id
  WHERE dcu.property_name::text = 'UnixLogin'::text AND dcu.property_type::text = 'MclassUnixProp'::text;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_device_col_acct_col_unixlogin','v_device_col_acct_col_unixlogin');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_device_col_acct_col_unixlogin failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_device_col_acct_col_unixlogin');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_device_col_acct_col_unixlogin  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_device_col_acct_col_unixlogin (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_col_acct_col_unixlogin');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_col_acct_col_unixlogin failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_col_acct_col_unixlogin');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_device_col_acct_col_unixlogin failed but that is ok';
	NULL;
END;
$$;

--- processing view v_device_collection_account_ssh_key in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_collection_account_ssh_key
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_device_collection_account_ssh_key', 'v_device_collection_account_ssh_key');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_device_collection_account_ssh_key', tags := ARRAY['view_v_device_collection_account_ssh_key']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_ssh_key', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'ssh_key', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_collection_account_ssh_key;
CREATE VIEW jazzhands_legacy.v_device_collection_account_ssh_key AS
 SELECT allkeys.device_collection_id,
    allkeys.account_id,
    array_agg(allkeys.ssh_public_key) AS ssh_public_key
   FROM ( SELECT keylist.device_collection_id,
            keylist.account_id,
            keylist.ssh_public_key
           FROM ( SELECT dchd.device_collection_id,
                    ac.account_id,
                    ssh_key.ssh_public_key
                   FROM jazzhands_legacy.device_collection_ssh_key dcssh
                     JOIN jazzhands_legacy.ssh_key USING (ssh_key_id)
                     JOIN jazzhands_legacy.v_acct_coll_acct_expanded ac USING (account_collection_id)
                     JOIN jazzhands_legacy.account a USING (account_id)
                     JOIN jazzhands_legacy.v_device_coll_hier_detail dchd ON dchd.parent_device_collection_id = dcssh.device_collection_id
                UNION
                 SELECT NULL::integer AS device_collection_id,
                    ask.account_id,
                    skey.ssh_public_key
                   FROM jazzhands.account_ssh_key ask
                     JOIN jazzhands.ssh_key skey USING (ssh_key_id)) keylist
          ORDER BY keylist.account_id, (COALESCE(keylist.device_collection_id, 0)), keylist.ssh_public_key) allkeys
  GROUP BY allkeys.device_collection_id, allkeys.account_id;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_device_collection_account_ssh_key','v_device_collection_account_ssh_key');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_device_collection_account_ssh_key failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_device_collection_account_ssh_key');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_device_collection_account_ssh_key  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_device_collection_account_ssh_key (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_collection_account_ssh_key');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_collection_account_ssh_key failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_collection_account_ssh_key');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_device_collection_account_ssh_key failed but that is ok';
	NULL;
END;
$$;

--- processing view v_unix_group_overrides in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_unix_group_overrides
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_unix_group_overrides', 'v_unix_group_overrides');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_unix_group_overrides', tags := ARRAY['view_v_unix_group_overrides']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'unix_group', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_prop_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'val_property', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_unix_group_overrides;
CREATE VIEW jazzhands_legacy.v_unix_group_overrides AS
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
         SELECT v_device_coll_hier_detail.device_collection_id,
            v_device_coll_hier_detail.parent_device_collection_id,
            v_device_coll_hier_detail.device_collection_level
           FROM jazzhands_legacy.v_device_coll_hier_detail
        UNION
         SELECT p.host_device_collection_id AS device_collection_id,
            d.parent_device_collection_id,
            d.device_collection_level
           FROM perdevtomclass p
             JOIN jazzhands_legacy.v_device_coll_hier_detail d ON d.device_collection_id = p.mclass_device_collection_id
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
                            COALESCE(p.property_value, p.property_value_password_type) AS property_value,
                            row_number() OVER (PARTITION BY dchd.device_collection_id, acpe.account_collection_id, acpe.property_name ORDER BY dchd.device_collection_level, acpe.assign_rank, acpe.property_id) AS ord
                           FROM jazzhands_legacy.v_acct_coll_prop_expanded acpe
                             JOIN jazzhands_legacy.unix_group ug USING (account_collection_id)
                             JOIN jazzhands_legacy.v_property p USING (property_id)
                             JOIN dcmap dchd ON dchd.parent_device_collection_id = p.device_collection_id
                          WHERE (p.property_type::text = ANY (ARRAY['UnixPasswdFileValue'::character varying, 'UnixGroupFileProperty'::character varying, 'MclassUnixProp'::character varying]::text[])) AND (p.property_name::text <> ALL (ARRAY['UnixLogin'::character varying, 'UnixGroup'::character varying, 'UnixGroupMemberOverride'::character varying]::text[]))) dc_acct_prop_list
                  WHERE dc_acct_prop_list.ord = 1) select_for_ordering) property_list
  GROUP BY property_list.device_collection_id, property_list.account_collection_id;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_unix_group_overrides','v_unix_group_overrides');
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_unix_group_overrides');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_unix_group_overrides  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_unix_group_overrides (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_unix_group_overrides');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_unix_group_overrides failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_unix_group_overrides');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_unix_group_overrides failed but that is ok';
	NULL;
END;
$$;

--- processing view v_device_col_account_cart in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_col_account_cart
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_device_col_account_cart', 'v_device_col_account_cart');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_device_col_account_cart', tags := ARRAY['view_v_device_col_account_cart']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_unix_info', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_device', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_prop_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_col_acct_col_unixlogin', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_unix_account_overrides', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'val_property', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_col_account_cart;
CREATE VIEW jazzhands_legacy.v_device_col_account_cart AS
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
                   FROM jazzhands_legacy.v_device_col_acct_col_unixlogin
                     JOIN jazzhands_legacy.account USING (account_id)
                     JOIN jazzhands_legacy.account_unix_info USING (account_id)
                UNION ALL
                 SELECT v_unix_account_overrides.device_collection_id,
                    v_unix_account_overrides.account_id,
                    v_unix_account_overrides.setting
                   FROM jazzhands_legacy.v_unix_account_overrides
                     JOIN jazzhands_legacy.account USING (account_id)
                     JOIN jazzhands_legacy.account_unix_info USING (account_id)
                     JOIN jazzhands_legacy.v_device_col_acct_col_unixlogin USING (device_collection_id, account_id)) x) xx
  WHERE xx.rn = 1;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_device_col_account_cart','v_device_col_account_cart');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_device_col_account_cart failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_device_col_account_cart');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_device_col_account_cart  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_device_col_account_cart (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_col_account_cart');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_col_account_cart failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_col_account_cart');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_device_col_account_cart failed but that is ok';
	NULL;
END;
$$;

--- processing view v_device_col_account_col_cart in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_device_col_account_col_cart
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_device_col_account_col_cart', 'v_device_col_account_col_cart');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_device_col_account_col_cart', tags := ARRAY['view_v_device_col_account_col_cart']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'unix_group', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'unix_group', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_prop_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_col_acct_col_unixgroup', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_unix_group_overrides', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'val_property', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_col_account_col_cart;
CREATE VIEW jazzhands_legacy.v_device_col_account_col_cart AS
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
                   FROM jazzhands_legacy.v_device_col_acct_col_unixgroup
                     JOIN jazzhands_legacy.account_collection USING (account_collection_id)
                     JOIN jazzhands_legacy.unix_group USING (account_collection_id)
                UNION
                 SELECT v_unix_group_overrides.device_collection_id,
                    v_unix_group_overrides.account_collection_id,
                    v_unix_group_overrides.setting
                   FROM jazzhands_legacy.v_unix_group_overrides) x) xx
  WHERE xx.rn = 1;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_device_col_account_col_cart','v_device_col_account_col_cart');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_device_col_account_col_cart failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_device_col_account_col_cart');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_device_col_account_col_cart  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_device_col_account_col_cart (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_col_account_col_cart');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_device_col_account_col_cart failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_device_col_account_col_cart');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_device_col_account_col_cart failed but that is ok';
	NULL;
END;
$$;

--- processing view v_unix_mclass_settings in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_unix_mclass_settings
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_unix_mclass_settings', 'v_unix_mclass_settings');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_unix_mclass_settings', tags := ARRAY['view_v_unix_mclass_settings']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_unix_mclass_settings;
CREATE VIEW jazzhands_legacy.v_unix_mclass_settings AS
 SELECT property_list.device_collection_id,
    array_agg(property_list.setting ORDER BY property_list.rn) AS mclass_setting
   FROM ( SELECT select_for_ordering.device_collection_id,
            select_for_ordering.setting,
            row_number() OVER () AS rn
           FROM ( SELECT dc.device_collection_id,
                    unnest(ARRAY[dc.property_name, dc.property_value]) AS setting
                   FROM ( SELECT dcd.device_collection_id,
                            p.property_name,
                            COALESCE(p.property_value, p.property_value_password_type) AS property_value,
                            row_number() OVER (PARTITION BY dcd.device_collection_id, p.property_name ORDER BY dcd.device_collection_level, p.property_id) AS ord
                           FROM jazzhands_legacy.v_device_coll_hier_detail dcd
                             JOIN jazzhands_legacy.v_property p ON p.device_collection_id = dcd.parent_device_collection_id
                          WHERE p.property_type::text = 'MclassUnixProp'::text AND p.account_collection_id IS NULL) dc
                  WHERE dc.ord = 1) select_for_ordering) property_list
  GROUP BY property_list.device_collection_id;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_unix_mclass_settings','v_unix_mclass_settings');
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_unix_mclass_settings');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_unix_mclass_settings  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_unix_mclass_settings (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_unix_mclass_settings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_unix_mclass_settings failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_unix_mclass_settings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_unix_mclass_settings failed but that is ok';
	NULL;
END;
$$;

--- processing view v_unix_passwd_mappings in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_unix_passwd_mappings
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_unix_passwd_mappings', 'v_unix_passwd_mappings');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_unix_passwd_mappings', tags := ARRAY['view_v_unix_passwd_mappings']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_password', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_unix_info', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_unix_info', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_device', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_ssh_key', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'person', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'ssh_key', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'unix_group', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_prop_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_col_account_cart', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_col_acct_col_unixlogin', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_collection_account_ssh_key', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_unix_account_overrides', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_unix_mclass_settings', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'val_property', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_unix_passwd_mappings;
CREATE VIEW jazzhands_legacy.v_unix_passwd_mappings AS
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
                   FROM jazzhands_legacy.v_property p
                     JOIN jazzhands_legacy.v_device_coll_hier_detail dchd ON dchd.parent_device_collection_id = p.device_collection_id
                  WHERE p.property_name::text = 'UnixPwType'::text AND p.property_type::text = 'MclassUnixProp'::text) subq
             JOIN jazzhands_legacy.account_password ap USING (password_type)
             JOIN jazzhands_legacy.account_unix_info a USING (account_id)
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
                       FROM jazzhands.v_property
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
                    a_1.external_id,
                    a_1.data_ins_user,
                    a_1.data_ins_date,
                    a_1.data_upd_user,
                    a_1.data_upd_date,
                    aui.unix_uid,
                    aui.unix_group_acct_collection_id,
                    aui.shell,
                    aui.default_home
                   FROM jazzhands_legacy.account a_1
                     JOIN jazzhands_legacy.account_unix_info aui USING (account_id)
                  WHERE a_1.is_enabled = 'Y'::text) a
             JOIN jazzhands_legacy.v_device_col_account_cart o USING (account_id)
             JOIN jazzhands_legacy.device_collection dc USING (device_collection_id)
             JOIN jazzhands_legacy.person p USING (person_id)
             JOIN jazzhands_legacy.unix_group ug ON a.unix_group_acct_collection_id = ug.account_collection_id
             JOIN jazzhands_legacy.account_collection ugac ON ugac.account_collection_id = ug.account_collection_id
             LEFT JOIN ( SELECT p_1.device_collection_id,
                    acae.account_id,
                    array_agg(ac.account_collection_name) AS group_names
                   FROM jazzhands_legacy.v_property p_1
                     JOIN jazzhands_legacy.device_collection dc_1 USING (device_collection_id)
                     JOIN jazzhands_legacy.account_collection ac USING (account_collection_id)
                     JOIN jazzhands_legacy.account_collection pac ON pac.account_collection_id = p_1.property_value_account_coll_id
                     JOIN jazzhands_legacy.v_acct_coll_acct_expanded acae ON pac.account_collection_id = acae.account_collection_id
                  WHERE p_1.property_type::text = 'MclassUnixProp'::text AND p_1.property_name::text = 'UnixGroupMemberOverride'::text AND dc_1.device_collection_type::text <> 'mclass'::text
                  GROUP BY p_1.device_collection_id, acae.account_id) extra_groups USING (device_collection_id, account_id)
             LEFT JOIN jazzhands_legacy.v_device_collection_account_ssh_key ssh ON a.account_id = ssh.account_id AND (ssh.device_collection_id IS NULL OR ssh.device_collection_id = o.device_collection_id)
             LEFT JOIN jazzhands_legacy.v_unix_mclass_settings mcs ON mcs.device_collection_id = dc.device_collection_id
             LEFT JOIN passtype pwt ON o.device_collection_id = pwt.device_collection_id AND a.account_id = pwt.account_id) s
  ORDER BY s.device_collection_id, s.account_id;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_unix_passwd_mappings','v_unix_passwd_mappings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_unix_passwd_mappings failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_unix_passwd_mappings');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_unix_passwd_mappings  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_unix_passwd_mappings (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_unix_passwd_mappings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_unix_passwd_mappings failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_unix_passwd_mappings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_unix_passwd_mappings failed but that is ok';
	NULL;
END;
$$;

--- processing view v_unix_group_mappings in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_unix_group_mappings
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_unix_group_mappings', 'v_unix_group_mappings');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_unix_group_mappings', tags := ARRAY['view_v_unix_group_mappings']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_password', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_unix_info', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_unix_info', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_unix_info', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_device', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_ssh_key', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'person', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'ssh_key', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'unix_group', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'unix_group', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'unix_group', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_expanded_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_prop_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_prop_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_col_account_cart', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_col_account_col_cart', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_col_acct_col_unixgroup', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_col_acct_col_unixlogin', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_collection_account_ssh_key', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_unix_account_overrides', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_unix_group_overrides', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_unix_mclass_settings', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_unix_mclass_settings', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_unix_passwd_mappings', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'val_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'val_property', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_unix_group_mappings;
CREATE VIEW jazzhands_legacy.v_unix_group_mappings AS
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
   FROM jazzhands.device_collection dc
     JOIN ( SELECT dch.device_collection_id,
            vace.account_collection_id
           FROM jazzhands.v_property p
             JOIN jazzhands_legacy.v_device_coll_hier_detail dch ON p.device_collection_id = dch.parent_device_collection_id
             JOIN jazzhands_legacy.v_acct_coll_expanded vace ON vace.root_account_collection_id = p.account_collection_id
          WHERE p.property_name::text = 'UnixGroup'::text AND p.property_type::text = 'MclassUnixProp'::text
        UNION ALL
         SELECT dch.device_collection_id,
            uag.account_collection_id
           FROM jazzhands_legacy.v_property p
             JOIN jazzhands_legacy.v_device_coll_hier_detail dch ON p.device_collection_id = dch.parent_device_collection_id
             JOIN jazzhands_legacy.v_acct_coll_acct_expanded vace USING (account_collection_id)
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
                    a_2.external_id,
                    a_2.data_ins_user,
                    a_2.data_ins_date,
                    a_2.data_upd_user,
                    a_2.data_upd_date
                   FROM jazzhands.account a_2
                     JOIN jazzhands.account_unix_info USING (account_id)
                  WHERE a_2.is_enabled = true) a_1 ON vace.account_id = a_1.account_id
             JOIN jazzhands_legacy.account_unix_info aui ON a_1.account_id = aui.account_id
             JOIN jazzhands_legacy.unix_group ug ON ug.account_collection_id = aui.unix_group_acct_collection_id
             JOIN jazzhands_legacy.account_collection uag ON ug.account_collection_id = uag.account_collection_id
          WHERE p.property_name::text = 'UnixLogin'::text AND p.property_type::text = 'MclassUnixProp'::text) ugmap USING (device_collection_id)
     JOIN jazzhands_legacy.account_collection ac USING (account_collection_id)
     JOIN jazzhands_legacy.unix_group USING (account_collection_id)
     LEFT JOIN jazzhands_legacy.v_device_col_account_col_cart o USING (device_collection_id, account_collection_id)
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
            g.external_id,
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
                    a_1.external_id,
                    a_1.data_ins_user,
                    a_1.data_ins_date,
                    a_1.data_upd_user,
                    a_1.data_upd_date
                   FROM ( SELECT dc_1.device_collection_id,
                            ae.account_collection_id,
                            ae.account_id
                           FROM jazzhands_legacy.device_collection dc_1,
                            jazzhands_legacy.v_acct_coll_acct_expanded ae
                             JOIN jazzhands_legacy.unix_group unix_group_1 USING (account_collection_id)
                             JOIN jazzhands_legacy.account_collection inac USING (account_collection_id)
                          WHERE dc_1.device_collection_type::text = 'mclass'::text
                        UNION ALL
                         SELECT dcugm.device_collection_id,
                            dcugm.account_collection_id,
                            dcugm.account_id
                           FROM ( SELECT dch.device_collection_id,
                                    p.account_collection_id,
                                    aca.account_id
                                   FROM jazzhands_legacy.v_property p
                                     JOIN jazzhands_legacy.unix_group ug USING (account_collection_id)
                                     JOIN jazzhands_legacy.v_device_coll_hier_detail dch ON p.device_collection_id = dch.parent_device_collection_id
                                     JOIN jazzhands_legacy.v_acct_coll_acct_expanded aca ON p.property_value_account_coll_id = aca.account_collection_id
                                  WHERE p.property_name::text = 'UnixGroupMemberOverride'::text AND p.property_type::text = 'MclassUnixProp'::text) dcugm) actoa
                     JOIN jazzhands_legacy.account_unix_info ui USING (account_id)
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
                            a_2.external_id,
                            a_2.data_ins_user,
                            a_2.data_ins_date,
                            a_2.data_upd_user,
                            a_2.data_upd_date
                           FROM jazzhands_legacy.account a_2
                             JOIN jazzhands_legacy.account_unix_info USING (account_id)
                          WHERE a_2.is_enabled = 'Y'::text) a_1 USING (account_id)) g(account_id, device_collection_id, account_collection_id, unix_uid, unix_group_acct_collection_id, shell, default_home, data_ins_user, data_ins_date, data_upd_user, data_upd_date, login, person_id, company_id, is_enabled, account_realm_id, account_status, account_role, account_type, description, external_id, data_ins_user_1, data_ins_date_1, data_upd_user_1, data_upd_date_1)
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
                    a_1.external_id,
                    a_1.data_ins_user,
                    a_1.data_ins_date,
                    a_1.data_upd_user,
                    a_1.data_upd_date
                   FROM jazzhands_legacy.account a_1
                     JOIN jazzhands_legacy.account_unix_info USING (account_id)
                  WHERE a_1.is_enabled = 'Y'::text) accts USING (account_id)
             JOIN jazzhands_legacy.v_unix_passwd_mappings USING (device_collection_id, account_id)) a(account_id, device_collection_id, account_collection_id, unix_uid, unix_group_acct_collection_id, shell, default_home, data_ins_user, data_ins_date, data_upd_user, data_upd_date, login, person_id, company_id, is_enabled, account_realm_id, account_status, account_role, account_type, description, external_id, data_ins_user_1, data_ins_date_1, data_upd_user_1, data_upd_date_1) USING (device_collection_id, account_collection_id)
     LEFT JOIN jazzhands_legacy.v_unix_mclass_settings mcs ON mcs.device_collection_id = dc.device_collection_id
  GROUP BY dc.device_collection_id, ac.account_collection_id, ac.account_collection_name, unix_group.unix_gid, unix_group.group_password, o.setting, mcs.mclass_setting
  ORDER BY dc.device_collection_id, ac.account_collection_id;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_unix_group_mappings','v_unix_group_mappings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_unix_group_mappings failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_unix_group_mappings');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_unix_group_mappings  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_unix_group_mappings (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_unix_group_mappings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_unix_group_mappings failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_unix_group_mappings');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_unix_group_mappings failed but that is ok';
	NULL;
END;
$$;

--- processing view v_hotpants_account_attribute in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_hotpants_account_attribute
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_hotpants_account_attribute', 'v_hotpants_account_attribute');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_hotpants_account_attribute', tags := ARRAY['view_v_hotpants_account_attribute']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'account_realm', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_account_collection_account', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_acct_coll_acct_expanded_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_dev_col_user_prop_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'val_property', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'val_property_data_type', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_hotpants_account_attribute;
CREATE VIEW jazzhands_legacy.v_hotpants_account_attribute AS
 SELECT v_dev_col_user_prop_expanded.property_id,
    v_dev_col_user_prop_expanded.account_id,
    v_dev_col_user_prop_expanded.device_collection_id,
    v_dev_col_user_prop_expanded.login,
    v_dev_col_user_prop_expanded.property_name,
    v_dev_col_user_prop_expanded.property_type,
    v_dev_col_user_prop_expanded.property_value,
    v_dev_col_user_prop_expanded.property_rank,
    v_dev_col_user_prop_expanded.is_boolean
   FROM jazzhands_legacy.v_dev_col_user_prop_expanded
     JOIN jazzhands_legacy.device_collection USING (device_collection_id)
  WHERE v_dev_col_user_prop_expanded.is_enabled = 'Y'::text AND ((device_collection.device_collection_type::text = ANY (ARRAY['HOTPants-app'::character varying, 'HOTPants'::character varying]::text[])) OR (v_dev_col_user_prop_expanded.property_type::text = ANY (ARRAY['RADIUS'::character varying, 'HOTPants'::character varying]::text[])));

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_hotpants_account_attribute','v_hotpants_account_attribute');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_hotpants_account_attribute failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_hotpants_account_attribute');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_hotpants_account_attribute  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_hotpants_account_attribute (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_hotpants_account_attribute');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_hotpants_account_attribute failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_hotpants_account_attribute');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_hotpants_account_attribute failed but that is ok';
	NULL;
END;
$$;

--- processing view v_hotpants_client in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_hotpants_client
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_hotpants_client', 'v_hotpants_client');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_hotpants_client', tags := ARRAY['view_v_hotpants_client']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_device', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_device_expanded', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_hotpants_client;
CREATE VIEW jazzhands_legacy.v_hotpants_client AS
 SELECT dc.device_id,
    d.device_name,
    netblock.ip_address,
    p.property_value AS radius_secret
   FROM jazzhands.v_property p
     JOIN jazzhands_legacy.v_device_coll_device_expanded dc USING (device_collection_id)
     JOIN jazzhands.device d USING (device_id)
     JOIN jazzhands.layer3_interface_netblock ni USING (device_id)
     JOIN jazzhands.netblock USING (netblock_id)
  WHERE p.property_name::text = 'RadiusSharedSecret'::text AND p.property_type::text = 'HOTPants'::text;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_hotpants_client','v_hotpants_client');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_hotpants_client failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_hotpants_client');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_hotpants_client  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_hotpants_client (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_hotpants_client');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_hotpants_client failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_hotpants_client');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_hotpants_client failed but that is ok';
	NULL;
END;
$$;

--- processing view v_hotpants_dc_attribute in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_hotpants_dc_attribute
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_hotpants_dc_attribute', 'v_hotpants_dc_attribute');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_hotpants_dc_attribute', tags := ARRAY['view_v_hotpants_dc_attribute']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'v_property', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_hotpants_dc_attribute;
CREATE VIEW jazzhands_legacy.v_hotpants_dc_attribute AS
 SELECT v_property.property_id,
    v_property.device_collection_id,
    v_property.property_name,
    v_property.property_type,
    v_property.property_rank,
    v_property.property_value_password_type AS property_value
   FROM jazzhands.v_property
  WHERE v_property.property_name::text = 'PWType'::text AND v_property.property_type::text = 'HOTPants'::text AND v_property.account_collection_id IS NULL;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_hotpants_dc_attribute','v_hotpants_dc_attribute');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_hotpants_dc_attribute failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_hotpants_dc_attribute');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_hotpants_dc_attribute  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_hotpants_dc_attribute (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_hotpants_dc_attribute');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_hotpants_dc_attribute failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_hotpants_dc_attribute');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_hotpants_dc_attribute failed but that is ok';
	NULL;
END;
$$;

--- processing view v_hotpants_device_collection in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_hotpants_device_collection
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_hotpants_device_collection', 'v_hotpants_device_collection');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_hotpants_device_collection', tags := ARRAY['view_v_hotpants_device_collection']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_device', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'device_collection_hier', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'netblock', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_device_coll_hier_detail', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_hotpants_device_collection;
CREATE VIEW jazzhands_legacy.v_hotpants_device_collection AS
 SELECT rankbyhier.device_id,
    rankbyhier.device_name,
    rankbyhier.device_collection_id,
    rankbyhier.device_collection_name,
    rankbyhier.device_collection_type,
    host(rankbyhier.ip_address) AS ip_address
   FROM ( SELECT dcd.device_id,
            device.device_name,
            dc.device_collection_id,
            dc.device_collection_name,
            dc.device_collection_type,
            dcr.device_collection_level,
            nb.ip_address,
            rank() OVER (PARTITION BY dcd.device_id ORDER BY dcr.device_collection_level) AS rank
           FROM jazzhands_legacy.device_collection dc
             LEFT JOIN jazzhands_legacy.v_device_coll_hier_detail dcr ON dc.device_collection_id = dcr.parent_device_collection_id
             LEFT JOIN jazzhands_legacy.device_collection_device dcd ON dcd.device_collection_id = dcr.device_collection_id
             LEFT JOIN jazzhands_legacy.device USING (device_id)
             LEFT JOIN jazzhands.layer3_interface_netblock ni USING (device_id)
             LEFT JOIN jazzhands_legacy.netblock nb USING (netblock_id)
          WHERE dc.device_collection_type::text = ANY (ARRAY['HOTPants'::character varying, 'HOTPants-app'::character varying]::text[])) rankbyhier
  WHERE rankbyhier.device_collection_type::text = 'HOTPants-app'::text OR rankbyhier.rank = 1 AND rankbyhier.ip_address IS NOT NULL;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_hotpants_device_collection','v_hotpants_device_collection');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_hotpants_device_collection failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_hotpants_device_collection');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_hotpants_device_collection  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_hotpants_device_collection (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_hotpants_device_collection');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_hotpants_device_collection failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_hotpants_device_collection');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_hotpants_device_collection failed but that is ok';
	NULL;
END;
$$;

--- processing view v_lv_hier in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_lv_hier
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_lv_hier', 'v_lv_hier');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_lv_hier', tags := ARRAY['view_v_lv_hier']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'logical_volume', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', object := 'physicalish_volume', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'physicalish_volume', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'volume_group', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'volume_group_physicalish_vol', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_lv_hier;
CREATE VIEW jazzhands_legacy.v_lv_hier AS
 WITH RECURSIVE lv_hier(physicalish_volume_id, pv_logical_volume_id, volume_group_id, logical_volume_id, pv_path, vg_path, lv_path) AS (
         SELECT pv.physicalish_volume_id,
            pv.logical_volume_id,
            vg.volume_group_id,
            lv.logical_volume_id,
            ARRAY[pv.physicalish_volume_id] AS "array",
            ARRAY[vg.volume_group_id] AS "array",
            ARRAY[lv.logical_volume_id] AS "array"
           FROM jazzhands_legacy.physicalish_volume pv
             LEFT JOIN jazzhands_legacy.volume_group_physicalish_vol USING (physicalish_volume_id)
             FULL JOIN jazzhands_legacy.volume_group vg USING (volume_group_id)
             LEFT JOIN jazzhands_legacy.logical_volume lv USING (volume_group_id)
          WHERE lv.logical_volume_id IS NULL OR NOT (lv.logical_volume_id IN ( SELECT physicalish_volume.logical_volume_id
                   FROM jazzhands.physicalish_volume
                  WHERE physicalish_volume.logical_volume_id IS NOT NULL))
        UNION
         SELECT pv.physicalish_volume_id,
            pv.logical_volume_id,
            vg.volume_group_id,
            lv.logical_volume_id,
            array_prepend(pv.physicalish_volume_id, lh.pv_path) AS array_prepend,
            array_prepend(vg.volume_group_id, lh.vg_path) AS array_prepend,
            array_prepend(lv.logical_volume_id, lh.lv_path) AS array_prepend
           FROM jazzhands_legacy.physicalish_volume pv
             LEFT JOIN jazzhands_legacy.volume_group_physicalish_vol USING (physicalish_volume_id)
             FULL JOIN jazzhands_legacy.volume_group vg USING (volume_group_id)
             LEFT JOIN jazzhands_legacy.logical_volume lv USING (volume_group_id)
             JOIN lv_hier lh(physicalish_volume_id_1, pv_logical_volume_id, volume_group_id_1, logical_volume_id, pv_path, vg_path, lv_path) ON lv.logical_volume_id = lh.pv_logical_volume_id
        )
 SELECT DISTINCT lv_hier.physicalish_volume_id,
    lv_hier.volume_group_id,
    lv_hier.logical_volume_id,
    unnest(lv_hier.pv_path) AS child_pv_id,
    unnest(lv_hier.vg_path) AS child_vg_id,
    unnest(lv_hier.lv_path) AS child_lv_id,
    lv_hier.pv_path,
    lv_hier.vg_path,
    lv_hier.lv_path
   FROM lv_hier;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_lv_hier','v_lv_hier');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_lv_hier failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_lv_hier');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_lv_hier  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_lv_hier (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_lv_hier');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_lv_hier failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_lv_hier');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_lv_hier failed but that is ok';
	NULL;
END;
$$;

--- processing view v_dns_fwd in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_dns_fwd
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_dns_fwd', 'v_dns_fwd');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_dns_fwd', tags := ARRAY['view_v_dns_fwd']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.v_dns_fwd;
CREATE VIEW jazzhands_legacy.v_dns_fwd AS
 SELECT x.dns_record_id,
    x.network_range_id,
    x.dns_domain_id,
    x.dns_name,
    x.dns_ttl,
    x.dns_class,
    x.dns_type,
    x.dns_value,
    x.dns_priority,
    x.ip,
    x.netblock_id,
    x.ip_universe_id,
    x.ref_record_id,
    x.dns_srv_service,
    x.dns_srv_protocol,
    x.dns_srv_weight,
    x.dns_srv_port,
    x.is_enabled,
    x.should_generate_ptr,
    x.dns_value_record_id
   FROM ( SELECT u.dns_record_id,
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
                            ELSE concat(dv.dns_name, '.', dv.dns_domain_name, '.')
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
                        CASE
                            WHEN d.is_enabled THEN 'Y'::text
                            ELSE 'N'::text
                        END AS is_enabled,
                        CASE
                            WHEN d.should_generate_ptr THEN 'Y'::text
                            ELSE 'N'::text
                        END AS should_generate_ptr,
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
                            dom.dns_domain_name,
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
                    'Y'::text AS is_enabled,
                    'N'::text AS should_generate_ptr,
                    NULL::integer AS dns_value_record_id
                   FROM ( SELECT dr.network_range_id,
                            dr.dns_domain_id,
                            nbstart.ip_universe_id,
                            COALESCE(dr.dns_prefix, val_network_range_type.default_dns_prefix) AS dns_prefix,
                            nbstart.ip_address + generate_series(0::bigint, nbstop.ip_address - nbstart.ip_address) AS ip
                           FROM jazzhands.network_range dr
                             JOIN jazzhands.val_network_range_type USING (network_range_type)
                             JOIN jazzhands.netblock nbstart ON dr.start_netblock_id = nbstart.netblock_id
                             JOIN jazzhands.netblock nbstop ON dr.stop_netblock_id = nbstop.netblock_id
                          WHERE dr.dns_domain_id IS NOT NULL) range) u
          WHERE u.dns_type::text <> ALL (ARRAY['REVERSE_ZONE_BLOCK_PTR'::character varying, 'DEFAULT_DNS_DOMAIN'::character varying]::text[])
        UNION ALL
         SELECT NULL::integer AS dns_record_id,
            NULL::integer AS network_range_id,
            dns_domain.parent_dns_domain_id AS dns_domain_id,
            regexp_replace(dns_domain.dns_domain_name::text, ('\.'::text || pdom.parent_dns_domain_name::text) || '$'::text, ''::text) AS dns_name,
            dns_record.dns_ttl,
            dns_record.dns_class,
            dns_record.dns_type,
                CASE
                    WHEN dns_record.dns_value::text ~ '\.$'::text THEN dns_record.dns_value::text
                    ELSE concat(dns_record.dns_value, '.', dns_domain.dns_domain_name, '.')
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
                CASE
                    WHEN dns_record.is_enabled THEN 'Y'::text
                    ELSE 'N'::text
                END AS is_enabled,
            'N'::text AS should_generate_ptr,
            NULL::integer AS dns_value_record_id
           FROM jazzhands.dns_record
             JOIN jazzhands.dns_domain USING (dns_domain_id)
             JOIN ( SELECT dns_domain_1.dns_domain_id AS parent_dns_domain_id,
                    dns_domain_1.dns_domain_name AS parent_dns_domain_name
                   FROM jazzhands.dns_domain dns_domain_1) pdom USING (parent_dns_domain_id)
          WHERE dns_record.dns_class::text = 'IN'::text AND dns_record.dns_type::text = 'NS'::text AND dns_record.dns_name IS NULL AND dns_domain.parent_dns_domain_id IS NOT NULL) x;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_dns_fwd','v_dns_fwd');
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
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_dns_fwd');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_dns_fwd  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_dns_fwd (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dns_fwd');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_dns_fwd failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dns_fwd');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_dns_fwd failed but that is ok';
	NULL;
END;
$$;

--- processing view v_dns_rvs in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_dns_rvs
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_dns_rvs', 'v_dns_rvs');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_dns_rvs', tags := ARRAY['view_v_dns_rvs']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.v_dns_rvs;
CREATE VIEW jazzhands_legacy.v_dns_rvs AS
 SELECT x.dns_record_id,
    x.network_range_id,
    x.dns_domain_id,
    x.dns_name,
    x.dns_ttl,
    x.dns_class,
    x.dns_type,
    x.dns_value,
    x.dns_priority,
    x.ip,
    x.netblock_id,
    x.ip_universe_id,
    x.rdns_record_id,
    x.dns_srv_service,
    x.dns_srv_protocol,
    x.dns_srv_weight,
    x.dns_srv_srv_port,
    x.is_enabled,
    x.should_generate_ptr,
    x.dns_value_record_id
   FROM ( SELECT NULL::integer AS dns_record_id,
            combo.network_range_id,
            rootd.dns_domain_id,
                CASE
                    WHEN family(combo.ip) = 4 THEN regexp_replace(host(combo.ip), '^.*[.](\d+)$'::text, '\1'::text, 'i'::text)
                    ELSE regexp_replace(dns_utils.v6_inaddr(combo.ip), ('.'::text || replace(dd.dns_domain_name::text, '.ip6.arpa'::text, ''::text)) || '$'::text, ''::text, 'i'::text)
                END AS dns_name,
            combo.dns_ttl,
            'IN'::text AS dns_class,
            'PTR'::text AS dns_type,
                CASE
                    WHEN combo.dns_name IS NULL THEN concat(combo.dns_domain_name, '.')
                    ELSE concat(combo.dns_name, '.', combo.dns_domain_name, '.')
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
            'N'::text AS should_generate_ptr,
            NULL::integer AS dns_value_record_id
           FROM ( SELECT host(nb.ip_address)::inet AS ip,
                    NULL::integer AS network_range_id,
                    COALESCE(rdns.dns_name, dns.dns_name) AS dns_name,
                    dom.dns_domain_name,
                    dns.dns_ttl,
                    network(nb.ip_address) AS ip_base,
                    nb.ip_universe_id,
                        CASE
                            WHEN dns.is_enabled THEN 'Y'::text
                            ELSE 'N'::text
                        END AS is_enabled,
                    'N'::text AS should_generate_ptr,
                    nb.netblock_id
                   FROM jazzhands.netblock nb
                     JOIN jazzhands.dns_record dns ON nb.netblock_id = dns.netblock_id
                     JOIN jazzhands.dns_domain dom ON dns.dns_domain_id = dom.dns_domain_id
                     LEFT JOIN jazzhands.dns_record rdns ON rdns.dns_record_id = dns.reference_dns_record_id
                  WHERE dns.should_generate_ptr AND dns.dns_class::text = 'IN'::text AND (dns.dns_type::text = 'A'::text OR dns.dns_type::text = 'AAAA'::text) AND nb.is_single_address
                UNION ALL
                 SELECT host(range.ip)::inet AS ip,
                    range.network_range_id,
                    concat(COALESCE(range.dns_prefix, 'pool'::character varying), '-', replace(host(range.ip), '.'::text, '-'::text)) AS dns_name,
                    dom.dns_domain_name,
                    NULL::integer AS dns_ttl,
                    network(range.ip) AS ip_base,
                    range.ip_universe_id,
                    'Y'::text AS is_enabled,
                    'N'::text AS should_generate_ptr,
                    NULL::integer AS netblock_id
                   FROM ( SELECT dr.network_range_id,
                            nbstart.ip_universe_id,
                            dr.dns_domain_id,
                            COALESCE(dr.dns_prefix, val_network_range_type.default_dns_prefix) AS dns_prefix,
                            nbstart.ip_address + generate_series(0::bigint, nbstop.ip_address - nbstart.ip_address) AS ip
                           FROM jazzhands.network_range dr
                             JOIN jazzhands.val_network_range_type USING (network_range_type)
                             JOIN jazzhands.netblock nbstart ON dr.start_netblock_id = nbstart.netblock_id
                             JOIN jazzhands.netblock nbstop ON dr.stop_netblock_id = nbstop.netblock_id
                          WHERE dr.dns_domain_id IS NOT NULL) range
                     JOIN jazzhands.dns_domain dom ON range.dns_domain_id = dom.dns_domain_id) combo,
            jazzhands.netblock root
             JOIN jazzhands.dns_record rootd ON rootd.netblock_id = root.netblock_id AND rootd.dns_type::text = 'REVERSE_ZONE_BLOCK_PTR'::text
             JOIN jazzhands.dns_domain dd USING (dns_domain_id)
          WHERE family(root.ip_address) = family(combo.ip) AND set_masklen(combo.ip, masklen(root.ip_address)) <<= root.ip_address) x;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_dns_rvs','v_dns_rvs');
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
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_dns_rvs');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_dns_rvs  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_dns_rvs (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dns_rvs');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_dns_rvs failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dns_rvs');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_dns_rvs failed but that is ok';
	NULL;
END;
$$;

--- processing view v_dns in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_dns
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_dns', 'v_dns');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_dns', tags := ARRAY['view_v_dns']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'ip_universe_visibility', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_dns_fwd', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_dns_rvs', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_dns;
CREATE VIEW jazzhands_legacy.v_dns AS
 SELECT d.dns_record_id,
    d.network_range_id,
    d.dns_domain_id,
    d.dns_name,
    d.dns_ttl,
    d.dns_class,
    d.dns_type,
    d.dns_value,
    d.dns_priority,
    d.ip,
    d.netblock_id,
    d.real_ip_universe_id AS ip_universe_id,
    d.ref_record_id,
    d.dns_srv_service,
    d.dns_srv_protocol,
    d.dns_srv_weight,
    d.dns_srv_port,
    d.is_enabled,
    d.should_generate_ptr,
    d.dns_value_record_id
   FROM ( SELECT f.ip_universe_id AS real_ip_universe_id,
            f.dns_record_id,
            f.network_range_id,
            f.dns_domain_id,
            f.dns_name,
            f.dns_ttl,
            f.dns_class,
            f.dns_type,
            f.dns_value,
            f.dns_priority,
            f.ip,
            f.netblock_id,
            f.ip_universe_id,
            f.ref_record_id,
            f.dns_srv_service,
            f.dns_srv_protocol,
            f.dns_srv_weight,
            f.dns_srv_port,
            f.is_enabled,
            f.should_generate_ptr,
            f.dns_value_record_id
           FROM jazzhands_legacy.v_dns_fwd f
        UNION
         SELECT x.ip_universe_id AS real_ip_universe_id,
            f.dns_record_id,
            f.network_range_id,
            f.dns_domain_id,
            f.dns_name,
            f.dns_ttl,
            f.dns_class,
            f.dns_type,
            f.dns_value,
            f.dns_priority,
            f.ip,
            f.netblock_id,
            f.ip_universe_id,
            f.ref_record_id,
            f.dns_srv_service,
            f.dns_srv_protocol,
            f.dns_srv_weight,
            f.dns_srv_port,
            f.is_enabled,
            f.should_generate_ptr,
            f.dns_value_record_id
           FROM jazzhands_legacy.ip_universe_visibility x,
            jazzhands_legacy.v_dns_fwd f
          WHERE x.visible_ip_universe_id = f.ip_universe_id OR f.ip_universe_id IS NULL
        UNION
         SELECT f.ip_universe_id AS real_ip_universe_id,
            f.dns_record_id,
            f.network_range_id,
            f.dns_domain_id,
            f.dns_name,
            f.dns_ttl,
            f.dns_class,
            f.dns_type,
            f.dns_value,
            f.dns_priority,
            f.ip,
            f.netblock_id,
            f.ip_universe_id,
            f.rdns_record_id,
            f.dns_srv_service,
            f.dns_srv_protocol,
            f.dns_srv_weight,
            f.dns_srv_srv_port,
            f.is_enabled,
            f.should_generate_ptr,
            f.dns_value_record_id
           FROM jazzhands_legacy.v_dns_rvs f
        UNION
         SELECT x.ip_universe_id AS real_ip_universe_id,
            f.dns_record_id,
            f.network_range_id,
            f.dns_domain_id,
            f.dns_name,
            f.dns_ttl,
            f.dns_class,
            f.dns_type,
            f.dns_value,
            f.dns_priority,
            f.ip,
            f.netblock_id,
            f.ip_universe_id,
            f.rdns_record_id,
            f.dns_srv_service,
            f.dns_srv_protocol,
            f.dns_srv_weight,
            f.dns_srv_srv_port,
            f.is_enabled,
            f.should_generate_ptr,
            f.dns_value_record_id
           FROM jazzhands_legacy.ip_universe_visibility x,
            jazzhands_legacy.v_dns_rvs f
          WHERE x.visible_ip_universe_id = f.ip_universe_id OR f.ip_universe_id IS NULL) d;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_dns','v_dns');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_dns failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_dns');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_dns  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_dns (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dns');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_dns failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dns');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_dns failed but that is ok';
	NULL;
END;
$$;

--- processing view v_dns_sorted in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE v_dns_sorted
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'v_dns_sorted', 'v_dns_sorted');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'v_dns_sorted', tags := ARRAY['view_v_dns_sorted']);
-- restore any missing random views that may be cached that this one needs.
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'ip_universe_visibility', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_dns', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_dns_fwd', type := 'view');
SELECT schema_support.replay_object_recreates(schema := 'jazzhands_legacy', object := 'v_dns_rvs', type := 'view');
DROP VIEW IF EXISTS jazzhands_legacy.v_dns_sorted;
CREATE VIEW jazzhands_legacy.v_dns_sorted AS
 SELECT v_dns.dns_record_id,
    v_dns.network_range_id,
    v_dns.dns_value_record_id,
    v_dns.dns_name,
    v_dns.dns_ttl,
    v_dns.dns_class,
    v_dns.dns_type,
    v_dns.dns_value,
    v_dns.dns_priority,
    host(v_dns.ip) AS ip,
    v_dns.netblock_id,
    v_dns.ref_record_id,
    v_dns.dns_srv_service,
    v_dns.dns_srv_protocol,
    v_dns.dns_srv_weight,
    v_dns.dns_srv_port,
    v_dns.should_generate_ptr,
    v_dns.is_enabled,
    v_dns.dns_domain_id,
    COALESCE(v_dns.ref_record_id, v_dns.dns_value_record_id, v_dns.dns_record_id) AS anchor_record_id,
        CASE
            WHEN v_dns.ref_record_id IS NOT NULL THEN 2
            WHEN v_dns.dns_value_record_id IS NOT NULL THEN 3
            ELSE 1
        END AS anchor_rank
   FROM jazzhands_legacy.v_dns
  ORDER BY v_dns.dns_domain_id, (
        CASE
            WHEN v_dns.dns_name IS NULL THEN 0
            ELSE 1
        END), (
        CASE
            WHEN v_dns.dns_type::text = 'NS'::text THEN 0
            WHEN v_dns.dns_type::text = 'PTR'::text THEN 1
            WHEN v_dns.dns_type::text = 'A'::text THEN 2
            WHEN v_dns.dns_type::text = 'AAAA'::text THEN 3
            ELSE 4
        END), (
        CASE
            WHEN v_dns.dns_type::text = 'PTR'::text THEN lpad(v_dns.dns_name::text, 10, '0'::text)
            ELSE NULL::text
        END), (COALESCE(v_dns.ref_record_id, v_dns.dns_value_record_id, v_dns.dns_record_id)), (
        CASE
            WHEN v_dns.ref_record_id IS NOT NULL THEN 2
            WHEN v_dns.dns_value_record_id IS NOT NULL THEN 3
            ELSE 1
        END), v_dns.dns_type, (host(v_dns.ip)), v_dns.dns_value;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('v_dns_sorted','v_dns_sorted');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of v_dns_sorted failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('v_dns_sorted');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for v_dns_sorted  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE v_dns_sorted (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dns_sorted');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old v_dns_sorted failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('v_dns_sorted');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new v_dns_sorted failed but that is ok';
	NULL;
END;
$$;

DROP TRIGGER IF EXISTS trigger_account_auth_log_del ON jazzhands_legacy.account_auth_log;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy'::text, object := 'account_auth_log_del (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy'::text]);
DROP FUNCTION IF EXISTS jazzhands_legacy.account_auth_log_del (  );
DROP TRIGGER IF EXISTS trigger_account_auth_log_ins ON jazzhands_legacy.account_auth_log;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy'::text, object := 'account_auth_log_ins (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy'::text]);
DROP FUNCTION IF EXISTS jazzhands_legacy.account_auth_log_ins (  );
DROP TRIGGER IF EXISTS trigger_account_auth_log_upd ON jazzhands_legacy.account_auth_log;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy'::text, object := 'account_auth_log_upd (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy'::text]);
DROP FUNCTION IF EXISTS jazzhands_legacy.account_auth_log_upd (  );
DROP TRIGGER IF EXISTS trigger_v_hotpants_token_del ON jazzhands_legacy.v_hotpants_token;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy'::text, object := 'v_hotpants_token_del (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy'::text]);
DROP FUNCTION IF EXISTS jazzhands_legacy.v_hotpants_token_del (  );
DROP TRIGGER IF EXISTS trigger_v_hotpants_token_ins ON jazzhands_legacy.v_hotpants_token;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy'::text, object := 'v_hotpants_token_ins (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy'::text]);
DROP FUNCTION IF EXISTS jazzhands_legacy.v_hotpants_token_ins (  );
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy']);
-- DONE: process_ancillary_schema(jazzhands_legacy)
--
-- BEGIN: process_ancillary_schema(audit)
--
--- processing view physicalish_volume in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE physicalish_volume
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'physicalish_volume', 'physicalish_volume');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'audit', object := 'physicalish_volume', tags := ARRAY['view_physicalish_volume']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS audit.physicalish_volume;
CREATE VIEW audit.physicalish_volume AS
 SELECT block_storage_device.block_storage_device_id AS physicalish_volume_id,
    block_storage_device.block_storage_device_name AS physicalish_volume_name,
    block_storage_device.block_storage_device_type AS physicalish_volume_type,
    block_storage_device.device_id,
    block_storage_device.logical_volume_id,
    block_storage_device.component_id,
    block_storage_device.data_ins_user,
    block_storage_device.data_ins_date,
    block_storage_device.data_upd_user,
    block_storage_device.data_upd_date,
    block_storage_device."aud#action",
    block_storage_device."aud#timestamp",
    block_storage_device."aud#realtime",
    block_storage_device."aud#txid",
    block_storage_device."aud#user",
    block_storage_device."aud#seq"
   FROM jazzhands_audit.block_storage_device;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'audit' AND type = 'view' AND object IN ('physicalish_volume','physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of physicalish_volume failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'audit' AND object IN ('physicalish_volume');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for physicalish_volume  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE physicalish_volume (audit)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old physicalish_volume failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('physicalish_volume');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new physicalish_volume failed but that is ok';
	NULL;
END;
$$;

--- processing view volume_group_physicalish_vol in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE volume_group_physicalish_vol
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'volume_group_physicalish_vol', 'volume_group_physicalish_vol');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'audit', object := 'volume_group_physicalish_vol', tags := ARRAY['view_volume_group_physicalish_vol']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS audit.volume_group_physicalish_vol;
CREATE VIEW audit.volume_group_physicalish_vol AS
 SELECT volume_group_block_storage_device.block_storage_device_id AS physicalish_volume_id,
    volume_group_block_storage_device.volume_group_id,
    volume_group_block_storage_device.device_id,
    volume_group_block_storage_device.volume_group_primary_position AS volume_group_primary_pos,
    volume_group_block_storage_device.volume_group_secondary_position AS volume_group_secondary_pos,
    volume_group_block_storage_device.volume_group_relation,
    volume_group_block_storage_device.data_ins_user,
    volume_group_block_storage_device.data_ins_date,
    volume_group_block_storage_device.data_upd_user,
    volume_group_block_storage_device.data_upd_date,
    volume_group_block_storage_device."aud#action",
    volume_group_block_storage_device."aud#timestamp",
    volume_group_block_storage_device."aud#realtime",
    volume_group_block_storage_device."aud#txid",
    volume_group_block_storage_device."aud#user",
    volume_group_block_storage_device."aud#seq"
   FROM jazzhands_audit.volume_group_block_storage_device;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'audit' AND type = 'view' AND object IN ('volume_group_physicalish_vol','volume_group_physicalish_vol');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of volume_group_physicalish_vol failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'audit' AND object IN ('volume_group_physicalish_vol');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for volume_group_physicalish_vol  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE volume_group_physicalish_vol (audit)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('volume_group_physicalish_vol');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old volume_group_physicalish_vol failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('volume_group_physicalish_vol');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new volume_group_physicalish_vol failed but that is ok';
	NULL;
END;
$$;

--- processing view account_auth_log in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE account_auth_log
SELECT schema_support.save_dependent_objects_for_replay(schema := 'audit', object := 'account_auth_log', tags := ARRAY['view_account_auth_log']);
DROP VIEW IF EXISTS audit.account_auth_log;
-- DONE DEALING WITH OLD TABLE account_auth_log (audit)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('account_auth_log');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old account_auth_log failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('account_auth_log');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped account_auth_log failed but that is ok';
	NULL;
END;
$$;

--- processing view val_physicalish_volume_type in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE val_physicalish_volume_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_physicalish_volume_type', 'val_physicalish_volume_type');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'audit', object := 'val_physicalish_volume_type', tags := ARRAY['view_val_physicalish_volume_type']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS audit.val_physicalish_volume_type;
CREATE VIEW audit.val_physicalish_volume_type AS
 SELECT val_block_storage_device_type.block_storage_device_type AS physicalish_volume_type,
    val_block_storage_device_type.description,
    val_block_storage_device_type.data_ins_user,
    val_block_storage_device_type.data_ins_date,
    val_block_storage_device_type.data_upd_user,
    val_block_storage_device_type.data_upd_date,
    val_block_storage_device_type."aud#action",
    val_block_storage_device_type."aud#timestamp",
    val_block_storage_device_type."aud#realtime",
    val_block_storage_device_type."aud#txid",
    val_block_storage_device_type."aud#user",
    val_block_storage_device_type."aud#seq"
   FROM jazzhands_audit.val_block_storage_device_type;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'audit' AND type = 'view' AND object IN ('val_physicalish_volume_type','val_physicalish_volume_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of val_physicalish_volume_type failed but that is ok';
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
		DELETE FROM __recreate WHERE schema = 'audit' AND object IN ('val_physicalish_volume_type');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_physicalish_volume_type  failed but that is ok';
		NULL;
END;
$$;

-- DONE DEALING WITH TABLE val_physicalish_volume_type (audit)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('val_physicalish_volume_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_physicalish_volume_type failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('val_physicalish_volume_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_physicalish_volume_type failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_audit']);
-- DONE: process_ancillary_schema(audit)
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
--
-- Process post-schema property_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
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
	v_service_version_collection	service_version_collection%ROWTYPE;
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
				'Property name (%) or type (%) does not exist',
				NEW.property_name, NEW.property_type
				USING ERRCODE = 'foreign_key_violation';
			RETURN NULL;
	END;

	-- Check to see if the property itself is multivalue. That is, if only
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
			service_version_collection_id IS NOT DISTINCT FROM
				NEW.service_version_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code AND
			x509_signed_certificate_id IS NOT DISTINCT FROM
				NEW.x509_signed_certificate_id
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
			service_version_collection_id IS NOT DISTINCT FROM
				NEW.service_version_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code AND
			x509_signed_certificate_id IS NOT DISTINCT FROM
				NEW.x509_signed_certificate_id AND
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
			property_value_service_version_collection_id IS NOT DISTINCT FROM
				NEW.property_value_service_version_collection_id AND
			property_value_password_type IS NOT DISTINCT FROM
				NEW.property_value_password_type AND
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

	-- Check to see if the property type is multivalue. That is, if only
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
			service_version_collection_id IS NOT DISTINCT FROM
				NEW.service_version_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code AND
			x509_signed_certificate_id IS NOT DISTINCT FROM
				NEW.x509_signed_certificate_id
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
	IF NEW.Property_Value_service_version_collection_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'service_version_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be service_version_collection_id' USING
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
	-- values is set to something valid. Now, check the various options for
	-- PROPERTY_VALUE itself. If a new type is added to the val table, this
	-- trigger needs to be updated or it will be considered invalid. If a
	-- new PROPERTY_VALUE_* column is added, then it will pass through without
	-- trigger modification. This should be considered bad.
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
		ELSIF v_prop.Property_Data_Type = 'boolean' THEN
			RAISE 'Boolean values are set in Property_Value_Boolean' USING
				ERRCODE = 'invalid_parameter_value';
		ELSIF v_prop.Property_Data_Type != 'string' THEN
			RAISE 'Property_Value may not be set for this Property_Data_Type' USING
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
	IF NEW.service_version_collection_id IS NOT NULL THEN
		IF v_prop.service_version_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_service_version_collection
					FROM service_version_collection WHERE
					service_version_collection_Id = NEW.service_version_collection_id;
				IF v_service_version_collection.service_version_collection_Type != v_prop.service_version_collection_type
				THEN
					RAISE 'service_version_collection_id must be of type %',
					v_prop.service_version_collection_type
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
		IF v_prop.property_value_netblock_collection_type_restriction IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_netblock_collection
					FROM netblock_collection WHERE
					netblock_collection_Id = NEW.Property_Value_netblock_collection_Id;
				IF v_netblock_collection.netblock_collection_Type != v_prop.property_value_netblock_collection_type_restriction
				THEN
					RAISE 'Property_Value_netblock_collection_Id must be of type %',
					v_prop.property_value_netbloc_collection_type_restriction
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a service_version_collection_id, check to see if it must be a
	-- specific type and verify that if so
	IF NEW.property_value_service_version_collection_id IS NOT NULL THEN
		IF v_prop.property_value_service_version_collection_id IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_service_version_collection
					FROM service_version_collection WHERE
					service_version_collection_Id = NEW.property_value_service_version_collection_id;
				IF v_service_version_collection.service_version_collection_Type != v_prop.property_value_service_version_collection_type_restriction
				THEN
					RAISE 'Property_Value_service_version_collection_Id must be of type %',
					v_prop.property_value_service_version_collection_type_restriction
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
		IF NOT validate_json_schema(
				v_prop.property_value_json_schema,
				NEW.property_value_json) THEN
			RAISE EXCEPTION 'JSON provided must match the json schema'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	-- At this point, the RHS has been checked, so now we verify data
	-- set on the LHS

	-- There needs to be a stanza here for every "lhs". If a new column is
	-- added to the property table, a new stanza needs to be added here,
	-- otherwise it will not be validated. This should be considered bad.

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

	IF v_prop.Permit_DNS_Domain_Collection_Id = 'REQUIRED' THEN
			IF NEW.DNS_Domain_Collection_Id IS NULL THEN
				RAISE 'DNS_Domain_Collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;

	ELSIF v_prop.Permit_DNS_Domain_Collection_Id = 'PROHIBITED' THEN
			IF NEW.DNS_Domain_Collection_Id IS NOT NULL THEN
				RAISE 'DNS_Domain_Collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_service_environment_collection_id = 'REQUIRED' THEN
			IF NEW.service_environment_collection_id IS NULL THEN
				RAISE 'service_environment_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_service_environment_collection_id = 'PROHIBITED' THEN
			IF NEW.service_environment_collection_id IS NOT NULL THEN
				RAISE 'service_environment is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_service_version_collection_id = 'REQUIRED' THEN
			IF NEW.service_version_collection_id IS NULL THEN
				RAISE 'service_version_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_service_version_collection_id = 'PROHIBITED' THEN
			IF NEW.service_version_collection_id IS NOT NULL THEN
				RAISE 'service_version_parameter_value';
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
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('property_utils', 'validate_filesystem');
DROP FUNCTION IF EXISTS property_utils.validate_filesystem ( new jazzhands.filesystem );
CREATE OR REPLACE FUNCTION property_utils.validate_filesystem(new jazzhands.filesystem)
 RETURNS jazzhands.filesystem
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_vft	val_filesystem_type%ROWTYPE;
BEGIN
	SELECT * INTO _vft FROM val_filesystem_type
		WHERE filesystem_type = NEW.filesystem_type;

	IF NEW.mountpoint IS NOT NULL AND _vft.permit_mountpoint = 'PROHIBITED' THEN
		RAISE EXCEPTION 'mountpoint is not permitted'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	IF NEW.mountpoint IS NULL AND _vft.permit_mountpoint = 'REQURIED' THEN
		RAISE EXCEPTION 'mountpoint is required'
			USING ERRCODE = 'not_null_violation';
	END IF;

	IF NEW.filesystem_label IS NOT NULL AND _vft.permit_filesystem_label = 'PROHIBITED' THEN
		RAISE EXCEPTION 'filesystem_label is not permitted'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	IF NEW.filesystem_label IS NULL AND _vft.permit_mountpoint = 'REQURIED' THEN
		RAISE EXCEPTION 'mountpoint is required'
			USING ERRCODE = 'not_null_violation';
	END IF;

	IF NEW.filesystem_serial IS NOT NULL AND _vft.permit_filesystem_serial = 'PROHIBITED' THEN
		RAISE EXCEPTION 'filesystem_serial is not permitted'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	IF NEW.filesystem_serial IS NULL AND _vft.permit_mountpoint = 'REQURIED' THEN
		RAISE EXCEPTION 'mountpoint is required'
			USING ERRCODE = 'not_null_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_property_utils']);
-- Dropping obsoleted sequences....
DROP SEQUENCE IF EXISTS physicalish_volume_physicalish_volume_id_seq;


-- Dropping obsoleted jazzhands_audit sequences....
DROP SEQUENCE IF EXISTS jazzhands_audit.account_authentication_log_seq;
DROP SEQUENCE IF EXISTS jazzhands_audit.physicalish_volume_seq;
DROP SEQUENCE IF EXISTS jazzhands_audit.val_physicalish_volume_type_seq;
DROP SEQUENCE IF EXISTS jazzhands_audit.volume_group_physicalish_volume_seq;


-- Processing tables with no structural changes
-- Some of these may be redundant
-- triggers
DROP TRIGGER IF EXISTS trig_account_change_realm_aca_realm ON account;
CREATE TRIGGER trig_account_change_realm_aca_realm BEFORE UPDATE OF account_realm_id ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_change_realm_aca_realm();
DROP TRIGGER IF EXISTS trig_add_account_automated_reporting_ac ON account;
CREATE TRIGGER trig_add_account_automated_reporting_ac AFTER INSERT OR UPDATE OF login, account_status ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_automated_reporting_ac();
DROP TRIGGER IF EXISTS trig_add_automated_ac_on_account ON account;
CREATE TRIGGER trig_add_automated_ac_on_account AFTER INSERT OR UPDATE OF account_type, account_role, account_status ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.automated_ac_on_account();
DROP TRIGGER IF EXISTS trig_rm_account_automated_reporting_ac ON account;
CREATE TRIGGER trig_rm_account_automated_reporting_ac BEFORE DELETE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_automated_reporting_ac();
DROP TRIGGER IF EXISTS trig_rm_automated_ac_on_account ON account;
CREATE TRIGGER trig_rm_automated_ac_on_account BEFORE DELETE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.automated_ac_on_account();
DROP TRIGGER IF EXISTS trig_userlog_account ON account;
CREATE TRIGGER trig_userlog_account BEFORE INSERT OR UPDATE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_account_enforce_is_enabled ON account;
CREATE TRIGGER trigger_account_enforce_is_enabled BEFORE INSERT OR UPDATE OF account_status, is_enabled ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_enforce_is_enabled();
DROP TRIGGER IF EXISTS trigger_account_status_per_row_after_hooks ON account;
CREATE TRIGGER trigger_account_status_per_row_after_hooks AFTER UPDATE OF account_status ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_status_per_row_after_hooks();
DROP TRIGGER IF EXISTS trigger_account_validate_login ON account;
CREATE TRIGGER trigger_account_validate_login BEFORE INSERT OR UPDATE OF login ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_validate_login();
DROP TRIGGER IF EXISTS trigger_audit_account ON account;
CREATE TRIGGER trigger_audit_account AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account();
DROP TRIGGER IF EXISTS trigger_create_new_unix_account ON account;
CREATE TRIGGER trigger_create_new_unix_account AFTER INSERT ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.create_new_unix_account();
DROP TRIGGER IF EXISTS trigger_delete_peraccount_account_collection ON account;
CREATE TRIGGER trigger_delete_peraccount_account_collection BEFORE DELETE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.delete_peraccount_account_collection();
DROP TRIGGER IF EXISTS trigger_update_peraccount_account_collection ON account;
CREATE TRIGGER trigger_update_peraccount_account_collection AFTER INSERT OR UPDATE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.update_peraccount_account_collection();
DROP TRIGGER IF EXISTS trig_userlog_account_assigned_certificate ON account_assigned_certificate;
CREATE TRIGGER trig_userlog_account_assigned_certificate BEFORE INSERT OR UPDATE ON jazzhands.account_assigned_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_assigned_certificate ON account_assigned_certificate;
CREATE TRIGGER trigger_audit_account_assigned_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_assigned_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_assigned_certificate();
DROP TRIGGER IF EXISTS aaa_account_collection_base_handler ON account_collection;
CREATE TRIGGER aaa_account_collection_base_handler AFTER INSERT OR DELETE OR UPDATE OF account_collection_id ON jazzhands.account_collection FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.account_collection_base_handler();
DROP TRIGGER IF EXISTS trig_account_collection_realm ON account_collection;
CREATE TRIGGER trig_account_collection_realm AFTER UPDATE OF account_collection_type ON jazzhands.account_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_collection ON account_collection;
CREATE TRIGGER trig_userlog_account_collection BEFORE INSERT OR UPDATE ON jazzhands.account_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_collection ON account_collection;
CREATE TRIGGER trigger_audit_account_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_collection();
DROP TRIGGER IF EXISTS trigger_validate_account_collection_type_change ON account_collection;
CREATE TRIGGER trigger_validate_account_collection_type_change BEFORE UPDATE OF account_collection_type ON jazzhands.account_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_account_collection_type_change();
DROP TRIGGER IF EXISTS trig_account_collection_account_realm ON account_collection_account;
CREATE TRIGGER trig_account_collection_account_realm AFTER INSERT OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_account_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_collection_account ON account_collection_account;
CREATE TRIGGER trig_userlog_account_collection_account BEFORE INSERT OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_account_coll_member_relation_enforce ON account_collection_account;
CREATE CONSTRAINT TRIGGER trigger_account_coll_member_relation_enforce AFTER INSERT OR UPDATE ON jazzhands.account_collection_account DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.account_coll_member_relation_enforce();
DROP TRIGGER IF EXISTS trigger_account_collection_member_enforce ON account_collection_account;
CREATE CONSTRAINT TRIGGER trigger_account_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.account_collection_account DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_audit_account_collection_account ON account_collection_account;
CREATE TRIGGER trigger_audit_account_collection_account AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_collection_account();
DROP TRIGGER IF EXISTS trigger_pgnotify_account_collection_account_token_changes ON account_collection_account;
CREATE TRIGGER trigger_pgnotify_account_collection_account_token_changes AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE FUNCTION jazzhands.pgnotify_account_collection_account_token_changes();
DROP TRIGGER IF EXISTS aaa_account_collection_root_handler ON account_collection_hier;
CREATE TRIGGER aaa_account_collection_root_handler AFTER INSERT OR DELETE OR UPDATE OF account_collection_id, child_account_collection_id ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.account_collection_root_handler();
DROP TRIGGER IF EXISTS trig_account_collection_hier_realm ON account_collection_hier;
CREATE TRIGGER trig_account_collection_hier_realm AFTER INSERT OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_hier_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_collection_hier ON account_collection_hier;
CREATE TRIGGER trig_userlog_account_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_account_collection_hier_enforce ON account_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_account_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.account_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_hier_enforce();
DROP TRIGGER IF EXISTS trigger_audit_account_collection_hier ON account_collection_hier;
CREATE TRIGGER trigger_audit_account_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_account_collection_hier_loop ON account_collection_hier;
CREATE TRIGGER trigger_check_account_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.check_account_colllection_hier_loop();
DROP TRIGGER IF EXISTS trig_userlog_account_collection_type_relation ON account_collection_type_relation;
CREATE TRIGGER trig_userlog_account_collection_type_relation BEFORE INSERT OR UPDATE ON jazzhands.account_collection_type_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_collection_type_relation ON account_collection_type_relation;
CREATE TRIGGER trigger_audit_account_collection_type_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_type_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_collection_type_relation();
DROP TRIGGER IF EXISTS trig_userlog_account_password ON account_password;
CREATE TRIGGER trig_userlog_account_password BEFORE INSERT OR UPDATE ON jazzhands.account_password FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_password ON account_password;
CREATE TRIGGER trigger_audit_account_password AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_password FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_password();
DROP TRIGGER IF EXISTS trigger_pgnotify_account_password_changes ON account_password;
CREATE TRIGGER trigger_pgnotify_account_password_changes AFTER INSERT OR UPDATE ON jazzhands.account_password FOR EACH ROW EXECUTE FUNCTION jazzhands.pgnotify_account_password_changes();
DROP TRIGGER IF EXISTS trigger_pull_password_account_realm_from_account ON account_password;
CREATE TRIGGER trigger_pull_password_account_realm_from_account BEFORE INSERT OR UPDATE OF account_id ON jazzhands.account_password FOR EACH ROW EXECUTE FUNCTION jazzhands.pull_password_account_realm_from_account();
DROP TRIGGER IF EXISTS trigger_unrequire_password_change ON account_password;
CREATE TRIGGER trigger_unrequire_password_change BEFORE INSERT OR UPDATE OF password ON jazzhands.account_password FOR EACH ROW EXECUTE FUNCTION jazzhands.unrequire_password_change();
DROP TRIGGER IF EXISTS trig_userlog_account_realm ON account_realm;
CREATE TRIGGER trig_userlog_account_realm BEFORE INSERT OR UPDATE ON jazzhands.account_realm FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm ON account_realm;
CREATE TRIGGER trigger_audit_account_realm AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_realm_account_collection_type ON account_realm_account_collection_type;
CREATE TRIGGER trig_userlog_account_realm_account_collection_type BEFORE INSERT OR UPDATE ON jazzhands.account_realm_account_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm_account_collection_type ON account_realm_account_collection_type;
CREATE TRIGGER trigger_audit_account_realm_account_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_realm_account_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_account_realm_company ON account_realm_company;
CREATE TRIGGER trig_userlog_account_realm_company BEFORE INSERT OR UPDATE ON jazzhands.account_realm_company FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm_company ON account_realm_company;
CREATE TRIGGER trigger_audit_account_realm_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm_company FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_realm_company();
DROP TRIGGER IF EXISTS trig_userlog_account_realm_password_type ON account_realm_password_type;
CREATE TRIGGER trig_userlog_account_realm_password_type BEFORE INSERT OR UPDATE ON jazzhands.account_realm_password_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm_password_type ON account_realm_password_type;
CREATE TRIGGER trigger_audit_account_realm_password_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm_password_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_realm_password_type();
DROP TRIGGER IF EXISTS trig_userlog_account_ssh_key ON account_ssh_key;
CREATE TRIGGER trig_userlog_account_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.account_ssh_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_ssh_key ON account_ssh_key;
CREATE TRIGGER trigger_audit_account_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_ssh_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_account_token ON account_token;
CREATE TRIGGER trig_userlog_account_token BEFORE INSERT OR UPDATE ON jazzhands.account_token FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_token ON account_token;
CREATE TRIGGER trigger_audit_account_token AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_token FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_token();
DROP TRIGGER IF EXISTS trigger_pgnotify_account_token_change ON account_token;
CREATE TRIGGER trigger_pgnotify_account_token_change AFTER INSERT OR UPDATE ON jazzhands.account_token FOR EACH ROW EXECUTE FUNCTION jazzhands.pgnotify_account_token_change();
DROP TRIGGER IF EXISTS trig_userlog_account_unix_info ON account_unix_info;
CREATE TRIGGER trig_userlog_account_unix_info BEFORE INSERT OR UPDATE ON jazzhands.account_unix_info FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_unix_info ON account_unix_info;
CREATE TRIGGER trigger_audit_account_unix_info AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_unix_info FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_unix_info();
DROP TRIGGER IF EXISTS trig_userlog_appaal ON appaal;
CREATE TRIGGER trig_userlog_appaal BEFORE INSERT OR UPDATE ON jazzhands.appaal FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal ON appaal;
CREATE TRIGGER trigger_audit_appaal AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_appaal();
DROP TRIGGER IF EXISTS trig_userlog_appaal_instance ON appaal_instance;
CREATE TRIGGER trig_userlog_appaal_instance BEFORE INSERT OR UPDATE ON jazzhands.appaal_instance FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal_instance ON appaal_instance;
CREATE TRIGGER trigger_audit_appaal_instance AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal_instance FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_appaal_instance();
DROP TRIGGER IF EXISTS trig_userlog_appaal_instance_device_collection ON appaal_instance_device_collection;
CREATE TRIGGER trig_userlog_appaal_instance_device_collection BEFORE INSERT OR UPDATE ON jazzhands.appaal_instance_device_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal_instance_device_collection ON appaal_instance_device_collection;
CREATE TRIGGER trigger_audit_appaal_instance_device_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal_instance_device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_appaal_instance_device_collection();
DROP TRIGGER IF EXISTS trig_userlog_appaal_instance_property ON appaal_instance_property;
CREATE TRIGGER trig_userlog_appaal_instance_property BEFORE INSERT OR UPDATE ON jazzhands.appaal_instance_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal_instance_property ON appaal_instance_property;
CREATE TRIGGER trigger_audit_appaal_instance_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal_instance_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_appaal_instance_property();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance ON approval_instance;
CREATE TRIGGER trig_userlog_approval_instance BEFORE INSERT OR UPDATE ON jazzhands.approval_instance FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance ON approval_instance;
CREATE TRIGGER trigger_audit_approval_instance AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_instance();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_item ON approval_instance_item;
CREATE TRIGGER trig_userlog_approval_instance_item BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_approval_instance_item_approval_notify ON approval_instance_item;
CREATE TRIGGER trigger_approval_instance_item_approval_notify AFTER INSERT OR UPDATE OF is_approved ON jazzhands.approval_instance_item FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.approval_instance_item_approval_notify();
DROP TRIGGER IF EXISTS trigger_approval_instance_item_approved_immutable ON approval_instance_item;
CREATE TRIGGER trigger_approval_instance_item_approved_immutable BEFORE UPDATE OF is_approved ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE FUNCTION jazzhands.approval_instance_item_approved_immutable();
DROP TRIGGER IF EXISTS trigger_approval_instance_step_auto_complete ON approval_instance_item;
CREATE TRIGGER trigger_approval_instance_step_auto_complete AFTER INSERT OR UPDATE OF is_approved ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE FUNCTION jazzhands.approval_instance_step_auto_complete();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_item ON approval_instance_item;
CREATE TRIGGER trigger_audit_approval_instance_item AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_instance_item();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_link ON approval_instance_link;
CREATE TRIGGER trig_userlog_approval_instance_link BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_link FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_link ON approval_instance_link;
CREATE TRIGGER trigger_audit_approval_instance_link AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_link FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_instance_link();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_step ON approval_instance_step;
CREATE TRIGGER trig_userlog_approval_instance_step BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_approval_instance_step_completed_immutable ON approval_instance_step;
CREATE TRIGGER trigger_approval_instance_step_completed_immutable BEFORE UPDATE OF is_completed ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE FUNCTION jazzhands.approval_instance_step_completed_immutable();
DROP TRIGGER IF EXISTS trigger_approval_instance_step_resolve_instance ON approval_instance_step;
CREATE TRIGGER trigger_approval_instance_step_resolve_instance AFTER UPDATE OF is_completed ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE FUNCTION jazzhands.approval_instance_step_resolve_instance();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_step ON approval_instance_step;
CREATE TRIGGER trigger_audit_approval_instance_step AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_instance_step();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_step_notify ON approval_instance_step_notify;
CREATE TRIGGER trig_userlog_approval_instance_step_notify BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_step_notify FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_step_notify ON approval_instance_step_notify;
CREATE TRIGGER trigger_audit_approval_instance_step_notify AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_step_notify FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_instance_step_notify();
DROP TRIGGER IF EXISTS trigger_legacy_approval_instance_step_notify_account ON approval_instance_step_notify;
CREATE TRIGGER trigger_legacy_approval_instance_step_notify_account BEFORE INSERT OR UPDATE OF account_id ON jazzhands.approval_instance_step_notify FOR EACH ROW EXECUTE FUNCTION jazzhands.legacy_approval_instance_step_notify_account();
DROP TRIGGER IF EXISTS trig_userlog_approval_process ON approval_process;
CREATE TRIGGER trig_userlog_approval_process BEFORE INSERT OR UPDATE ON jazzhands.approval_process FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_process ON approval_process;
CREATE TRIGGER trigger_audit_approval_process AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_process FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_process();
DROP TRIGGER IF EXISTS trig_userlog_approval_process_chain ON approval_process_chain;
CREATE TRIGGER trig_userlog_approval_process_chain BEFORE INSERT OR UPDATE ON jazzhands.approval_process_chain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_process_chain ON approval_process_chain;
CREATE TRIGGER trigger_audit_approval_process_chain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_process_chain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_process_chain();
DROP TRIGGER IF EXISTS trig_userlog_asset ON asset;
CREATE TRIGGER trig_userlog_asset BEFORE INSERT OR UPDATE ON jazzhands.asset FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_asset ON asset;
CREATE TRIGGER trigger_audit_asset AFTER INSERT OR DELETE OR UPDATE ON jazzhands.asset FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_asset();
DROP TRIGGER IF EXISTS trigger_validate_asset_component_assignment ON asset;
CREATE CONSTRAINT TRIGGER trigger_validate_asset_component_assignment AFTER INSERT OR UPDATE OF component_id ON jazzhands.asset DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_asset_component_assignment();
DROP TRIGGER IF EXISTS trig_userlog_badge ON badge;
CREATE TRIGGER trig_userlog_badge BEFORE INSERT OR UPDATE ON jazzhands.badge FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_badge ON badge;
CREATE TRIGGER trigger_audit_badge AFTER INSERT OR DELETE OR UPDATE ON jazzhands.badge FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_badge();
DROP TRIGGER IF EXISTS trig_userlog_badge_type ON badge_type;
CREATE TRIGGER trig_userlog_badge_type BEFORE INSERT OR UPDATE ON jazzhands.badge_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_badge_type ON badge_type;
CREATE TRIGGER trigger_audit_badge_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.badge_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_badge_type();
DROP TRIGGER IF EXISTS trig_userlog_certificate_signing_request ON certificate_signing_request;
CREATE TRIGGER trig_userlog_certificate_signing_request BEFORE INSERT OR UPDATE ON jazzhands.certificate_signing_request FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_certificate_signing_request ON certificate_signing_request;
CREATE TRIGGER trigger_audit_certificate_signing_request AFTER INSERT OR DELETE OR UPDATE ON jazzhands.certificate_signing_request FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_certificate_signing_request();
DROP TRIGGER IF EXISTS trigger_csr_set_hashes ON certificate_signing_request;
CREATE TRIGGER trigger_csr_set_hashes BEFORE INSERT OR UPDATE OF certificate_signing_request, public_key_hash_id ON jazzhands.certificate_signing_request FOR EACH ROW EXECUTE FUNCTION jazzhands.set_csr_hashes();
DROP TRIGGER IF EXISTS trig_userlog_chassis_location ON chassis_location;
CREATE TRIGGER trig_userlog_chassis_location BEFORE INSERT OR UPDATE ON jazzhands.chassis_location FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_chassis_location ON chassis_location;
CREATE TRIGGER trigger_audit_chassis_location AFTER INSERT OR DELETE OR UPDATE ON jazzhands.chassis_location FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_chassis_location();
DROP TRIGGER IF EXISTS trig_userlog_circuit ON circuit;
CREATE TRIGGER trig_userlog_circuit BEFORE INSERT OR UPDATE ON jazzhands.circuit FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_circuit ON circuit;
CREATE TRIGGER trigger_audit_circuit AFTER INSERT OR DELETE OR UPDATE ON jazzhands.circuit FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_circuit();
DROP TRIGGER IF EXISTS trig_userlog_company ON company;
CREATE TRIGGER trig_userlog_company BEFORE INSERT OR UPDATE ON jazzhands.company FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company ON company;
CREATE TRIGGER trigger_audit_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_company();
DROP TRIGGER IF EXISTS trigger_company_insert_function_nudge ON company;
CREATE TRIGGER trigger_company_insert_function_nudge BEFORE INSERT ON jazzhands.company FOR EACH ROW EXECUTE FUNCTION jazzhands.company_insert_function_nudge();
DROP TRIGGER IF EXISTS trigger_delete_per_company_company_collection ON company;
CREATE TRIGGER trigger_delete_per_company_company_collection BEFORE DELETE ON jazzhands.company FOR EACH ROW EXECUTE FUNCTION jazzhands.delete_per_company_company_collection();
DROP TRIGGER IF EXISTS trigger_update_per_company_company_collection ON company;
CREATE TRIGGER trigger_update_per_company_company_collection AFTER INSERT OR UPDATE ON jazzhands.company FOR EACH ROW EXECUTE FUNCTION jazzhands.update_per_company_company_collection();
DROP TRIGGER IF EXISTS trig_userlog_company_collection ON company_collection;
CREATE TRIGGER trig_userlog_company_collection BEFORE INSERT OR UPDATE ON jazzhands.company_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_collection ON company_collection;
CREATE TRIGGER trigger_audit_company_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_company_collection();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_bytype_del ON company_collection;
CREATE TRIGGER trigger_manip_company_collection_bytype_del BEFORE DELETE ON jazzhands.company_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_company_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_bytype_insup ON company_collection;
CREATE TRIGGER trigger_manip_company_collection_bytype_insup AFTER INSERT OR UPDATE OF company_collection_type ON jazzhands.company_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_company_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_company_collection_type_change ON company_collection;
CREATE TRIGGER trigger_validate_company_collection_type_change BEFORE UPDATE OF company_collection_type ON jazzhands.company_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_company_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_company_collection_company ON company_collection_company;
CREATE TRIGGER trig_userlog_company_collection_company BEFORE INSERT OR UPDATE ON jazzhands.company_collection_company FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_collection_company ON company_collection_company;
CREATE TRIGGER trigger_audit_company_collection_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_collection_company FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_company_collection_company();
DROP TRIGGER IF EXISTS trigger_company_collection_member_enforce ON company_collection_company;
CREATE CONSTRAINT TRIGGER trigger_company_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.company_collection_company DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.company_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_company_collection_hier ON company_collection_hier;
CREATE TRIGGER trig_userlog_company_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.company_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_collection_hier ON company_collection_hier;
CREATE TRIGGER trigger_audit_company_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_company_collection_hier();
DROP TRIGGER IF EXISTS trigger_company_collection_hier_enforce ON company_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_company_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.company_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.company_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_company_type ON company_type;
CREATE TRIGGER trig_userlog_company_type BEFORE INSERT OR UPDATE ON jazzhands.company_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_type ON company_type;
CREATE TRIGGER trigger_audit_company_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_company_type();
DROP TRIGGER IF EXISTS aaa_tg_cache_component_parent_handler ON component;
CREATE TRIGGER aaa_tg_cache_component_parent_handler AFTER INSERT OR DELETE OR UPDATE OF parent_slot_id ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.cache_component_parent_handler();
DROP TRIGGER IF EXISTS aab_tg_cache_device_component_component_handler ON component;
CREATE TRIGGER aab_tg_cache_device_component_component_handler AFTER INSERT OR DELETE OR UPDATE OF parent_slot_id ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.cache_device_component_component_handler();
DROP TRIGGER IF EXISTS trig_userlog_component ON component;
CREATE TRIGGER trig_userlog_component BEFORE INSERT OR UPDATE ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component ON component;
CREATE TRIGGER trigger_audit_component AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component();
DROP TRIGGER IF EXISTS trigger_create_component_template_slots ON component;
CREATE TRIGGER trigger_create_component_template_slots AFTER INSERT OR UPDATE OF component_type_id ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands.create_component_slots_by_trigger();
DROP TRIGGER IF EXISTS trigger_sync_component_rack_location_id ON component;
CREATE TRIGGER trigger_sync_component_rack_location_id AFTER UPDATE OF rack_location_id ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands.sync_component_rack_location_id();
DROP TRIGGER IF EXISTS trigger_validate_component_parent_slot_id ON component;
CREATE CONSTRAINT TRIGGER trigger_validate_component_parent_slot_id AFTER INSERT OR UPDATE OF parent_slot_id, component_type_id ON jazzhands.component DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_component_parent_slot_id();
DROP TRIGGER IF EXISTS trigger_validate_component_rack_location ON component;
CREATE CONSTRAINT TRIGGER trigger_validate_component_rack_location AFTER INSERT OR UPDATE OF rack_location_id ON jazzhands.component DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_component_rack_location();
DROP TRIGGER IF EXISTS trigger_zzz_generate_slot_names ON component;
CREATE TRIGGER trigger_zzz_generate_slot_names AFTER INSERT OR UPDATE OF parent_slot_id ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands.set_slot_names_by_trigger();
DROP TRIGGER IF EXISTS trig_userlog_component_management_controller ON component_management_controller;
CREATE TRIGGER trig_userlog_component_management_controller BEFORE INSERT OR UPDATE ON jazzhands.component_management_controller FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_management_controller ON component_management_controller;
CREATE TRIGGER trigger_audit_component_management_controller AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_management_controller FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component_management_controller();
DROP TRIGGER IF EXISTS trig_userlog_component_property ON component_property;
CREATE TRIGGER trig_userlog_component_property BEFORE INSERT OR UPDATE ON jazzhands.component_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_property ON component_property;
CREATE TRIGGER trigger_audit_component_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component_property();
DROP TRIGGER IF EXISTS trigger_validate_component_property ON component_property;
CREATE CONSTRAINT TRIGGER trigger_validate_component_property AFTER INSERT OR UPDATE ON jazzhands.component_property DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_component_property();
DROP TRIGGER IF EXISTS trig_userlog_component_type ON component_type;
CREATE TRIGGER trig_userlog_component_type BEFORE INSERT OR UPDATE ON jazzhands.component_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_type ON component_type;
CREATE TRIGGER trigger_audit_component_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component_type();
DROP TRIGGER IF EXISTS trigger_check_component_type_device_virtual_match ON component_type;
CREATE CONSTRAINT TRIGGER trigger_check_component_type_device_virtual_match AFTER UPDATE OF is_virtual_component ON jazzhands.component_type NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_component_type_device_virtual_match();
DROP TRIGGER IF EXISTS trig_userlog_component_type_component_function ON component_type_component_function;
CREATE TRIGGER trig_userlog_component_type_component_function BEFORE INSERT OR UPDATE ON jazzhands.component_type_component_function FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_type_component_function ON component_type_component_function;
CREATE TRIGGER trigger_audit_component_type_component_function AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_type_component_function FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component_type_component_function();
DROP TRIGGER IF EXISTS trig_userlog_component_type_slot_template ON component_type_slot_template;
CREATE TRIGGER trig_userlog_component_type_slot_template BEFORE INSERT OR UPDATE ON jazzhands.component_type_slot_template FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_type_slot_template ON component_type_slot_template;
CREATE TRIGGER trigger_audit_component_type_slot_template AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_type_slot_template FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component_type_slot_template();
DROP TRIGGER IF EXISTS trig_userlog_contract ON contract;
CREATE TRIGGER trig_userlog_contract BEFORE INSERT OR UPDATE ON jazzhands.contract FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_contract ON contract;
CREATE TRIGGER trigger_audit_contract AFTER INSERT OR DELETE OR UPDATE ON jazzhands.contract FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_contract();
DROP TRIGGER IF EXISTS trig_userlog_contract_type ON contract_type;
CREATE TRIGGER trig_userlog_contract_type BEFORE INSERT OR UPDATE ON jazzhands.contract_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_contract_type ON contract_type;
CREATE TRIGGER trigger_audit_contract_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.contract_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_contract_type();
DROP TRIGGER IF EXISTS trig_userlog_department ON department;
CREATE TRIGGER trig_userlog_department BEFORE INSERT OR UPDATE ON jazzhands.department FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_department ON department;
CREATE TRIGGER trigger_audit_department AFTER INSERT OR DELETE OR UPDATE ON jazzhands.department FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_department();
DROP TRIGGER IF EXISTS tg_cache_device_component_device_handler ON device;
CREATE TRIGGER tg_cache_device_component_device_handler AFTER INSERT OR DELETE OR UPDATE OF component_id ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.cache_device_component_device_handler();
DROP TRIGGER IF EXISTS trig_userlog_device ON device;
CREATE TRIGGER trig_userlog_device BEFORE INSERT OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device ON device;
CREATE TRIGGER trigger_audit_device AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device();
DROP TRIGGER IF EXISTS trigger_check_device_component_type_virtual_match ON device;
CREATE CONSTRAINT TRIGGER trigger_check_device_component_type_virtual_match AFTER INSERT OR UPDATE OF is_virtual_device ON jazzhands.device NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_device_component_type_virtual_match();
DROP TRIGGER IF EXISTS trigger_create_device_component ON device;
CREATE TRIGGER trigger_create_device_component BEFORE INSERT OR UPDATE OF device_type_id ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.create_device_component_by_trigger();
DROP TRIGGER IF EXISTS trigger_del_jazzhands_legacy_support ON device;
CREATE TRIGGER trigger_del_jazzhands_legacy_support BEFORE DELETE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.del_jazzhands_legacy_support();
DROP TRIGGER IF EXISTS trigger_delete_per_device_device_collection ON device;
CREATE TRIGGER trigger_delete_per_device_device_collection BEFORE DELETE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.delete_per_device_device_collection();
DROP TRIGGER IF EXISTS trigger_device_one_location_validate ON device;
CREATE TRIGGER trigger_device_one_location_validate BEFORE INSERT OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.device_one_location_validate();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_device_del ON device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_device_del BEFORE DELETE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_device_del();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_device_ins ON device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_device_ins AFTER INSERT ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_device_ins();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_device_upd ON device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_device_upd AFTER UPDATE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_device_upd();
DROP TRIGGER IF EXISTS trigger_sync_device_rack_location_id ON device;
CREATE TRIGGER trigger_sync_device_rack_location_id BEFORE INSERT OR UPDATE OF rack_location_id, component_id ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.sync_device_rack_location_id();
DROP TRIGGER IF EXISTS trigger_update_per_device_device_collection ON device;
CREATE TRIGGER trigger_update_per_device_device_collection AFTER INSERT OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.update_per_device_device_collection();
DROP TRIGGER IF EXISTS trigger_validate_device_component_assignment ON device;
CREATE CONSTRAINT TRIGGER trigger_validate_device_component_assignment AFTER INSERT OR UPDATE OF device_type_id, component_id ON jazzhands.device DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_device_component_assignment();
DROP TRIGGER IF EXISTS aaa_device_collection_base_handler ON device_collection;
CREATE TRIGGER aaa_device_collection_base_handler AFTER INSERT OR DELETE OR UPDATE OF device_collection_id ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.device_collection_base_handler();
DROP TRIGGER IF EXISTS trig_userlog_device_collection ON device_collection;
CREATE TRIGGER trig_userlog_device_collection BEFORE INSERT OR UPDATE ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection ON device_collection;
CREATE TRIGGER trigger_audit_device_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_collection();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_bytype_del ON device_collection;
CREATE TRIGGER trigger_manip_device_collection_bytype_del BEFORE DELETE ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_device_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_bytype_insup ON device_collection;
CREATE TRIGGER trigger_manip_device_collection_bytype_insup AFTER INSERT OR UPDATE OF device_collection_type ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_device_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_device_collection_type_change ON device_collection;
CREATE TRIGGER trigger_validate_device_collection_type_change BEFORE UPDATE OF device_collection_type ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_device_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_assigned_certificate ON device_collection_assigned_certificate;
CREATE TRIGGER trig_userlog_device_collection_assigned_certificate BEFORE INSERT OR UPDATE ON jazzhands.device_collection_assigned_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_assigned_certificate ON device_collection_assigned_certificate;
CREATE TRIGGER trigger_audit_device_collection_assigned_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_assigned_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_collection_assigned_certificate();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_device ON device_collection_device;
CREATE TRIGGER trig_userlog_device_collection_device BEFORE INSERT OR UPDATE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_device ON device_collection_device;
CREATE TRIGGER trigger_audit_device_collection_device AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_collection_device();
DROP TRIGGER IF EXISTS trigger_device_collection_member_enforce ON device_collection_device;
CREATE CONSTRAINT TRIGGER trigger_device_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.device_collection_device DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.device_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_dcd_del ON device_collection_device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_dcd_del BEFORE DELETE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_dcd_del();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_dcd_ins ON device_collection_device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_dcd_ins AFTER INSERT ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_dcd_ins();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_dcd_upd ON device_collection_device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_dcd_upd AFTER UPDATE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_dcd_upd();
DROP TRIGGER IF EXISTS trigger_member_device_collection_after_hooks ON device_collection_device;
CREATE TRIGGER trigger_member_device_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_device FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.device_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_member_device_collection_after_row_hooks ON device_collection_device;
CREATE TRIGGER trigger_member_device_collection_after_row_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION jazzhands.device_collection_device_after_row_hooks();
DROP TRIGGER IF EXISTS aaa_device_collection_root_handler ON device_collection_hier;
CREATE TRIGGER aaa_device_collection_root_handler AFTER INSERT OR DELETE OR UPDATE OF device_collection_id, child_device_collection_id ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.device_collection_root_handler();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_hier ON device_collection_hier;
CREATE TRIGGER trig_userlog_device_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_hier ON device_collection_hier;
CREATE TRIGGER trigger_audit_device_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_device_collection_hier_loop ON device_collection_hier;
CREATE TRIGGER trigger_check_device_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.check_device_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_device_collection_hier_enforce ON device_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_device_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.device_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.device_collection_hier_enforce();
DROP TRIGGER IF EXISTS trigger_hier_device_collection_after_hooks ON device_collection_hier;
CREATE TRIGGER trigger_hier_device_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_hier FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.device_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_hier_device_collection_after_row_hooks ON device_collection_hier;
CREATE TRIGGER trigger_hier_device_collection_after_row_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.device_collection_hier_after_row_hooks();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_ssh_key ON device_collection_ssh_key;
CREATE TRIGGER trig_userlog_device_collection_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.device_collection_ssh_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_ssh_key ON device_collection_ssh_key;
CREATE TRIGGER trigger_audit_device_collection_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_ssh_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_collection_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_device_encapsulation_domain ON device_encapsulation_domain;
CREATE TRIGGER trig_userlog_device_encapsulation_domain BEFORE INSERT OR UPDATE ON jazzhands.device_encapsulation_domain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_encapsulation_domain ON device_encapsulation_domain;
CREATE TRIGGER trigger_audit_device_encapsulation_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_encapsulation_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_encapsulation_domain();
DROP TRIGGER IF EXISTS trig_userlog_device_layer2_network ON device_layer2_network;
CREATE TRIGGER trig_userlog_device_layer2_network BEFORE INSERT OR UPDATE ON jazzhands.device_layer2_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_layer2_network ON device_layer2_network;
CREATE TRIGGER trigger_audit_device_layer2_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_layer2_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_layer2_network();
DROP TRIGGER IF EXISTS trig_userlog_device_note ON device_note;
CREATE TRIGGER trig_userlog_device_note BEFORE INSERT OR UPDATE ON jazzhands.device_note FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_note ON device_note;
CREATE TRIGGER trigger_audit_device_note AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_note FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_note();
DROP TRIGGER IF EXISTS trig_userlog_device_ssh_key ON device_ssh_key;
CREATE TRIGGER trig_userlog_device_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.device_ssh_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_ssh_key ON device_ssh_key;
CREATE TRIGGER trigger_audit_device_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_ssh_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_device_ticket ON device_ticket;
CREATE TRIGGER trig_userlog_device_ticket BEFORE INSERT OR UPDATE ON jazzhands.device_ticket FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_ticket ON device_ticket;
CREATE TRIGGER trigger_audit_device_ticket AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_ticket FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_ticket();
DROP TRIGGER IF EXISTS trig_userlog_device_type ON device_type;
CREATE TRIGGER trig_userlog_device_type BEFORE INSERT OR UPDATE ON jazzhands.device_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_type ON device_type;
CREATE TRIGGER trigger_audit_device_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_type();
DROP TRIGGER IF EXISTS trigger_device_type_chassis_check ON device_type;
CREATE TRIGGER trigger_device_type_chassis_check BEFORE UPDATE OF is_chassis ON jazzhands.device_type FOR EACH ROW EXECUTE FUNCTION jazzhands.device_type_chassis_check();
DROP TRIGGER IF EXISTS trigger_device_type_model_to_name ON device_type;
CREATE TRIGGER trigger_device_type_model_to_name BEFORE INSERT OR UPDATE OF device_type_name, model ON jazzhands.device_type FOR EACH ROW EXECUTE FUNCTION jazzhands.device_type_model_to_name();
DROP TRIGGER IF EXISTS trig_userlog_device_type_module ON device_type_module;
CREATE TRIGGER trig_userlog_device_type_module BEFORE INSERT OR UPDATE ON jazzhands.device_type_module FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_type_module ON device_type_module;
CREATE TRIGGER trigger_audit_device_type_module AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_type_module FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_type_module();
DROP TRIGGER IF EXISTS trigger_device_type_module_chassis_check ON device_type_module;
CREATE TRIGGER trigger_device_type_module_chassis_check BEFORE INSERT OR UPDATE OF device_type_id ON jazzhands.device_type_module FOR EACH ROW EXECUTE FUNCTION jazzhands.device_type_module_chassis_check();
DROP TRIGGER IF EXISTS trigger_device_type_module_sanity_set ON device_type_module;
CREATE TRIGGER trigger_device_type_module_sanity_set BEFORE INSERT OR UPDATE ON jazzhands.device_type_module FOR EACH ROW EXECUTE FUNCTION jazzhands.device_type_module_sanity_set();
DROP TRIGGER IF EXISTS trig_userlog_device_type_module_device_type ON device_type_module_device_type;
CREATE TRIGGER trig_userlog_device_type_module_device_type BEFORE INSERT OR UPDATE ON jazzhands.device_type_module_device_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_type_module_device_type ON device_type_module_device_type;
CREATE TRIGGER trigger_audit_device_type_module_device_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_type_module_device_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_type_module_device_type();
DROP TRIGGER IF EXISTS trig_userlog_dns_change_record ON dns_change_record;
CREATE TRIGGER trig_userlog_dns_change_record BEFORE INSERT OR UPDATE ON jazzhands.dns_change_record FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_change_record ON dns_change_record;
CREATE TRIGGER trigger_audit_dns_change_record AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_change_record FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_change_record();
DROP TRIGGER IF EXISTS trigger_dns_change_record_pgnotify ON dns_change_record;
CREATE TRIGGER trigger_dns_change_record_pgnotify AFTER INSERT OR UPDATE ON jazzhands.dns_change_record FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.dns_change_record_pgnotify();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain ON dns_domain;
CREATE TRIGGER trig_userlog_dns_domain BEFORE INSERT OR UPDATE ON jazzhands.dns_domain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain ON dns_domain;
CREATE TRIGGER trigger_audit_dns_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_domain();
DROP TRIGGER IF EXISTS trigger_dns_domain_trigger_change ON dns_domain;
CREATE TRIGGER trigger_dns_domain_trigger_change AFTER INSERT OR UPDATE OF dns_domain_name ON jazzhands.dns_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_trigger_change();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_collection ON dns_domain_collection;
CREATE TRIGGER trig_userlog_dns_domain_collection BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_collection ON dns_domain_collection;
CREATE TRIGGER trigger_audit_dns_domain_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_domain_collection();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_bytype_del ON dns_domain_collection;
CREATE TRIGGER trigger_manip_dns_domain_collection_bytype_del BEFORE DELETE ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_dns_domain_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_bytype_insup ON dns_domain_collection;
CREATE TRIGGER trigger_manip_dns_domain_collection_bytype_insup AFTER INSERT OR UPDATE OF dns_domain_collection_type ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_dns_domain_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_dns_domain_collection_type_change ON dns_domain_collection;
CREATE TRIGGER trigger_validate_dns_domain_collection_type_change BEFORE UPDATE OF dns_domain_collection_type ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_dns_domain_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_collection_dns_domain ON dns_domain_collection_dns_domain;
CREATE TRIGGER trig_userlog_dns_domain_collection_dns_domain BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_collection_dns_domain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_collection_dns_domain ON dns_domain_collection_dns_domain;
CREATE TRIGGER trigger_audit_dns_domain_collection_dns_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_collection_dns_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_domain_collection_dns_domain();
DROP TRIGGER IF EXISTS trigger_dns_domain_collection_member_enforce ON dns_domain_collection_dns_domain;
CREATE CONSTRAINT TRIGGER trigger_dns_domain_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.dns_domain_collection_dns_domain DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_collection_hier ON dns_domain_collection_hier;
CREATE TRIGGER trig_userlog_dns_domain_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_collection_hier ON dns_domain_collection_hier;
CREATE TRIGGER trigger_audit_dns_domain_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_domain_collection_hier();
DROP TRIGGER IF EXISTS trigger_dns_domain_collection_hier_enforce ON dns_domain_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_dns_domain_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.dns_domain_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_ip_universe ON dns_domain_ip_universe;
CREATE TRIGGER trig_userlog_dns_domain_ip_universe BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_ip_universe ON dns_domain_ip_universe;
CREATE TRIGGER trigger_audit_dns_domain_ip_universe AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_domain_ip_universe();
DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_can_generate ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_can_generate AFTER INSERT OR UPDATE OF should_generate ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_ip_universe_can_generate();
DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_trigger_change ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_trigger_change AFTER INSERT OR UPDATE OF soa_class, soa_ttl, soa_serial, soa_refresh, soa_retry, soa_expire, soa_minimum, soa_mname, soa_rname, should_generate ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_ip_universe_trigger_change();
DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_trigger_del ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_trigger_del BEFORE DELETE ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_ip_universe_trigger_del();
DROP TRIGGER IF EXISTS trig_userlog_dns_record ON dns_record;
CREATE TRIGGER trig_userlog_dns_record BEFORE INSERT OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_record ON dns_record;
CREATE TRIGGER trigger_audit_dns_record AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_record();
DROP TRIGGER IF EXISTS trigger_check_ip_universe_dns_record ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_check_ip_universe_dns_record AFTER INSERT OR UPDATE OF dns_record_id, ip_universe_id ON jazzhands.dns_record DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_ip_universe_dns_record();
DROP TRIGGER IF EXISTS trigger_dns_a_rec_validation ON dns_record;
CREATE TRIGGER trigger_dns_a_rec_validation BEFORE INSERT OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_a_rec_validation();
DROP TRIGGER IF EXISTS trigger_dns_non_a_rec_validation ON dns_record;
CREATE TRIGGER trigger_dns_non_a_rec_validation BEFORE INSERT OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_non_a_rec_validation();
DROP TRIGGER IF EXISTS trigger_dns_rec_prevent_dups ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_dns_rec_prevent_dups AFTER INSERT OR UPDATE ON jazzhands.dns_record NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_rec_prevent_dups();
DROP TRIGGER IF EXISTS trigger_dns_record_check_name ON dns_record;
CREATE TRIGGER trigger_dns_record_check_name BEFORE INSERT OR UPDATE OF dns_name, should_generate_ptr ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_record_check_name();
DROP TRIGGER IF EXISTS trigger_dns_record_cname_checker ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_dns_record_cname_checker AFTER INSERT OR UPDATE OF dns_class, dns_type, dns_name, dns_domain_id, is_enabled ON jazzhands.dns_record NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_record_cname_checker();
DROP TRIGGER IF EXISTS trigger_dns_record_enabled_check ON dns_record;
CREATE TRIGGER trigger_dns_record_enabled_check BEFORE INSERT OR UPDATE OF is_enabled ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_record_enabled_check();
DROP TRIGGER IF EXISTS trigger_dns_record_update_nontime ON dns_record;
CREATE TRIGGER trigger_dns_record_update_nontime AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_record_update_nontime();
DROP TRIGGER IF EXISTS trig_userlog_dns_record_relation ON dns_record_relation;
CREATE TRIGGER trig_userlog_dns_record_relation BEFORE INSERT OR UPDATE ON jazzhands.dns_record_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_record_relation ON dns_record_relation;
CREATE TRIGGER trigger_audit_dns_record_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_record_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_record_relation();
DROP TRIGGER IF EXISTS trig_userlog_encapsulation_domain ON encapsulation_domain;
CREATE TRIGGER trig_userlog_encapsulation_domain BEFORE INSERT OR UPDATE ON jazzhands.encapsulation_domain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_encapsulation_domain ON encapsulation_domain;
CREATE TRIGGER trigger_audit_encapsulation_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.encapsulation_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_encapsulation_domain();
DROP TRIGGER IF EXISTS trig_userlog_encapsulation_range ON encapsulation_range;
CREATE TRIGGER trig_userlog_encapsulation_range BEFORE INSERT OR UPDATE ON jazzhands.encapsulation_range FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_encapsulation_range ON encapsulation_range;
CREATE TRIGGER trigger_audit_encapsulation_range AFTER INSERT OR DELETE OR UPDATE ON jazzhands.encapsulation_range FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_encapsulation_range();
DROP TRIGGER IF EXISTS trig_userlog_encryption_key ON encryption_key;
CREATE TRIGGER trig_userlog_encryption_key BEFORE INSERT OR UPDATE ON jazzhands.encryption_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_encryption_key ON encryption_key;
CREATE TRIGGER trigger_audit_encryption_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.encryption_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_encryption_key();
DROP TRIGGER IF EXISTS trig_userlog_inter_component_connection ON inter_component_connection;
CREATE TRIGGER trig_userlog_inter_component_connection BEFORE INSERT OR UPDATE ON jazzhands.inter_component_connection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_inter_component_connection ON inter_component_connection;
CREATE TRIGGER trigger_audit_inter_component_connection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.inter_component_connection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_inter_component_connection();
DROP TRIGGER IF EXISTS trigger_validate_inter_component_connection ON inter_component_connection;
CREATE CONSTRAINT TRIGGER trigger_validate_inter_component_connection AFTER INSERT OR UPDATE ON jazzhands.inter_component_connection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_inter_component_connection();
DROP TRIGGER IF EXISTS trig_userlog_ip_universe ON ip_universe;
CREATE TRIGGER trig_userlog_ip_universe BEFORE INSERT OR UPDATE ON jazzhands.ip_universe FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ip_universe ON ip_universe;
CREATE TRIGGER trigger_audit_ip_universe AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ip_universe FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_ip_universe();
DROP TRIGGER IF EXISTS trig_userlog_ip_universe_visibility ON ip_universe_visibility;
CREATE TRIGGER trig_userlog_ip_universe_visibility BEFORE INSERT OR UPDATE ON jazzhands.ip_universe_visibility FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ip_universe_visibility ON ip_universe_visibility;
CREATE TRIGGER trigger_audit_ip_universe_visibility AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ip_universe_visibility FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_ip_universe_visibility();
DROP TRIGGER IF EXISTS trig_userlog_kerberos_realm ON kerberos_realm;
CREATE TRIGGER trig_userlog_kerberos_realm BEFORE INSERT OR UPDATE ON jazzhands.kerberos_realm FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_kerberos_realm ON kerberos_realm;
CREATE TRIGGER trigger_audit_kerberos_realm AFTER INSERT OR DELETE OR UPDATE ON jazzhands.kerberos_realm FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_kerberos_realm();
DROP TRIGGER IF EXISTS trig_userlog_klogin ON klogin;
CREATE TRIGGER trig_userlog_klogin BEFORE INSERT OR UPDATE ON jazzhands.klogin FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_klogin ON klogin;
CREATE TRIGGER trigger_audit_klogin AFTER INSERT OR DELETE OR UPDATE ON jazzhands.klogin FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_klogin();
DROP TRIGGER IF EXISTS trig_userlog_klogin_mclass ON klogin_mclass;
CREATE TRIGGER trig_userlog_klogin_mclass BEFORE INSERT OR UPDATE ON jazzhands.klogin_mclass FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_klogin_mclass ON klogin_mclass;
CREATE TRIGGER trigger_audit_klogin_mclass AFTER INSERT OR DELETE OR UPDATE ON jazzhands.klogin_mclass FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_klogin_mclass();
DROP TRIGGER IF EXISTS trig_userlog_layer2_connection ON layer2_connection;
CREATE TRIGGER trig_userlog_layer2_connection BEFORE INSERT OR UPDATE ON jazzhands.layer2_connection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_connection ON layer2_connection;
CREATE TRIGGER trigger_audit_layer2_connection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_connection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_connection();
DROP TRIGGER IF EXISTS trig_userlog_layer2_connection_layer2_network ON layer2_connection_layer2_network;
CREATE TRIGGER trig_userlog_layer2_connection_layer2_network BEFORE INSERT OR UPDATE ON jazzhands.layer2_connection_layer2_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_connection_layer2_network ON layer2_connection_layer2_network;
CREATE TRIGGER trigger_audit_layer2_connection_layer2_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_connection_layer2_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_connection_layer2_network();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network ON layer2_network;
CREATE TRIGGER trig_userlog_layer2_network BEFORE INSERT OR UPDATE ON jazzhands.layer2_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network ON layer2_network;
CREATE TRIGGER trigger_audit_layer2_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_network();
DROP TRIGGER IF EXISTS layer2_net_collection_member_enforce_on_type_change ON layer2_network_collection;
CREATE CONSTRAINT TRIGGER layer2_net_collection_member_enforce_on_type_change AFTER UPDATE OF layer2_network_collection_type ON jazzhands.layer2_network_collection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer2_net_collection_member_enforce_on_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network_collection ON layer2_network_collection;
CREATE TRIGGER trig_userlog_layer2_network_collection BEFORE INSERT OR UPDATE ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network_collection ON layer2_network_collection;
CREATE TRIGGER trigger_audit_layer2_network_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_network_collection();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_bytype_del ON layer2_network_collection;
CREATE TRIGGER trigger_manip_layer2_network_collection_bytype_del BEFORE DELETE ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer2_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_bytype_insup ON layer2_network_collection;
CREATE TRIGGER trigger_manip_layer2_network_collection_bytype_insup AFTER INSERT OR UPDATE OF layer2_network_collection_type ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer2_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_layer2_network_collection_type_change ON layer2_network_collection;
CREATE TRIGGER trigger_validate_layer2_network_collection_type_change BEFORE UPDATE OF layer2_network_collection_type ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_layer2_network_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network_collection_hier ON layer2_network_collection_hier;
CREATE TRIGGER trig_userlog_layer2_network_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.layer2_network_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network_collection_hier ON layer2_network_collection_hier;
CREATE TRIGGER trigger_audit_layer2_network_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_network_collection_hier();
DROP TRIGGER IF EXISTS trigger_hier_layer2_network_collection_after_hooks ON layer2_network_collection_hier;
CREATE TRIGGER trigger_hier_layer2_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_hier FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.layer2_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_layer2_network_collection_hier_enforce ON layer2_network_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_layer2_network_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.layer2_network_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer2_network_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network_collection_layer2_network ON layer2_network_collection_layer2_network;
CREATE TRIGGER trig_userlog_layer2_network_collection_layer2_network BEFORE INSERT OR UPDATE ON jazzhands.layer2_network_collection_layer2_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network_collection_layer2_network ON layer2_network_collection_layer2_network;
CREATE TRIGGER trigger_audit_layer2_network_collection_layer2_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_layer2_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_network_collection_layer2_network();
DROP TRIGGER IF EXISTS trigger_layer2_network_collection_member_enforce ON layer2_network_collection_layer2_network;
CREATE CONSTRAINT TRIGGER trigger_layer2_network_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.layer2_network_collection_layer2_network DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer2_network_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_member_layer2_network_collection_after_hooks ON layer2_network_collection_layer2_network;
CREATE TRIGGER trigger_member_layer2_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_layer2_network FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.layer2_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trig_userlog_layer3_acl_chain ON layer3_acl_chain;
CREATE TRIGGER trig_userlog_layer3_acl_chain BEFORE INSERT OR UPDATE ON jazzhands.layer3_acl_chain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_acl_chain ON layer3_acl_chain;
CREATE TRIGGER trigger_audit_layer3_acl_chain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_acl_chain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_acl_chain();
DROP TRIGGER IF EXISTS trig_userlog_layer3_acl_chain_layer3_interface ON layer3_acl_chain_layer3_interface;
CREATE TRIGGER trig_userlog_layer3_acl_chain_layer3_interface BEFORE INSERT OR UPDATE ON jazzhands.layer3_acl_chain_layer3_interface FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_acl_chain_layer3_interface ON layer3_acl_chain_layer3_interface;
CREATE TRIGGER trigger_audit_layer3_acl_chain_layer3_interface AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_acl_chain_layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_acl_chain_layer3_interface();
DROP TRIGGER IF EXISTS trig_userlog_layer3_acl_group ON layer3_acl_group;
CREATE TRIGGER trig_userlog_layer3_acl_group BEFORE INSERT OR UPDATE ON jazzhands.layer3_acl_group FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_acl_group ON layer3_acl_group;
CREATE TRIGGER trigger_audit_layer3_acl_group AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_acl_group FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_acl_group();
DROP TRIGGER IF EXISTS trig_userlog_layer3_acl_rule ON layer3_acl_rule;
CREATE TRIGGER trig_userlog_layer3_acl_rule BEFORE INSERT OR UPDATE ON jazzhands.layer3_acl_rule FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_acl_rule ON layer3_acl_rule;
CREATE TRIGGER trigger_audit_layer3_acl_rule AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_acl_rule FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_acl_rule();
DROP TRIGGER IF EXISTS trig_userlog_layer3_interface ON layer3_interface;
CREATE TRIGGER trig_userlog_layer3_interface BEFORE INSERT OR UPDATE ON jazzhands.layer3_interface FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_interface ON layer3_interface;
CREATE TRIGGER trigger_audit_layer3_interface AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_interface();
DROP TRIGGER IF EXISTS trigger_net_int_device_id_upd ON layer3_interface;
CREATE TRIGGER trigger_net_int_device_id_upd AFTER UPDATE OF device_id ON jazzhands.layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.net_int_device_id_upd();
DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins_before ON layer3_interface;
CREATE TRIGGER trigger_net_int_nb_device_id_ins_before BEFORE UPDATE OF device_id ON jazzhands.layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.net_int_nb_device_id_ins_before();
DROP TRIGGER IF EXISTS trig_userlog_layer3_interface_netblock ON layer3_interface_netblock;
CREATE TRIGGER trig_userlog_layer3_interface_netblock BEFORE INSERT OR UPDATE ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_interface_netblock ON layer3_interface_netblock;
CREATE TRIGGER trigger_audit_layer3_interface_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_interface_netblock();
DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins ON layer3_interface_netblock;
CREATE TRIGGER trigger_net_int_nb_device_id_ins BEFORE INSERT OR UPDATE OF layer3_interface_id ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.net_int_nb_device_id_ins();
DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins_after ON layer3_interface_netblock;
CREATE TRIGGER trigger_net_int_nb_device_id_ins_after AFTER INSERT OR UPDATE OF layer3_interface_id ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.net_int_nb_device_id_ins_after();
DROP TRIGGER IF EXISTS trigger_net_int_nb_single_address ON layer3_interface_netblock;
CREATE TRIGGER trigger_net_int_nb_single_address BEFORE INSERT OR UPDATE OF netblock_id ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.net_int_nb_single_address();
DROP TRIGGER IF EXISTS trig_userlog_layer3_interface_purpose ON layer3_interface_purpose;
CREATE TRIGGER trig_userlog_layer3_interface_purpose BEFORE INSERT OR UPDATE ON jazzhands.layer3_interface_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_interface_purpose ON layer3_interface_purpose;
CREATE TRIGGER trigger_audit_layer3_interface_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_interface_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_interface_purpose();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network ON layer3_network;
CREATE TRIGGER trig_userlog_layer3_network BEFORE INSERT OR UPDATE ON jazzhands.layer3_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network ON layer3_network;
CREATE TRIGGER trigger_audit_layer3_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_network();
DROP TRIGGER IF EXISTS trigger_layer3_network_validate_netblock ON layer3_network;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_validate_netblock AFTER INSERT OR UPDATE OF netblock_id ON jazzhands.layer3_network NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer3_network_validate_netblock();
DROP TRIGGER IF EXISTS layer3_net_collection_member_enforce_on_type_change ON layer3_network_collection;
CREATE CONSTRAINT TRIGGER layer3_net_collection_member_enforce_on_type_change AFTER UPDATE OF layer3_network_collection_type ON jazzhands.layer3_network_collection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer3_net_collection_member_enforce_on_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network_collection ON layer3_network_collection;
CREATE TRIGGER trig_userlog_layer3_network_collection BEFORE INSERT OR UPDATE ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network_collection ON layer3_network_collection;
CREATE TRIGGER trigger_audit_layer3_network_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_network_collection();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_bytype_del ON layer3_network_collection;
CREATE TRIGGER trigger_manip_layer3_network_collection_bytype_del BEFORE DELETE ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer3_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_bytype_insup ON layer3_network_collection;
CREATE TRIGGER trigger_manip_layer3_network_collection_bytype_insup AFTER INSERT OR UPDATE OF layer3_network_collection_type ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer3_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_layer3_network_collection_type_change ON layer3_network_collection;
CREATE TRIGGER trigger_validate_layer3_network_collection_type_change BEFORE UPDATE OF layer3_network_collection_type ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_layer3_network_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network_collection_hier ON layer3_network_collection_hier;
CREATE TRIGGER trig_userlog_layer3_network_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.layer3_network_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network_collection_hier ON layer3_network_collection_hier;
CREATE TRIGGER trigger_audit_layer3_network_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_network_collection_hier();
DROP TRIGGER IF EXISTS trigger_hier_layer3_network_collection_after_hooks ON layer3_network_collection_hier;
CREATE TRIGGER trigger_hier_layer3_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_hier FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.layer3_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_layer3_network_collection_hier_enforce ON layer3_network_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.layer3_network_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer3_network_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network_collection_layer3_network ON layer3_network_collection_layer3_network;
CREATE TRIGGER trig_userlog_layer3_network_collection_layer3_network BEFORE INSERT OR UPDATE ON jazzhands.layer3_network_collection_layer3_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network_collection_layer3_network ON layer3_network_collection_layer3_network;
CREATE TRIGGER trigger_audit_layer3_network_collection_layer3_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_layer3_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_network_collection_layer3_network();
DROP TRIGGER IF EXISTS trigger_layer3_network_collection_member_enforce ON layer3_network_collection_layer3_network;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.layer3_network_collection_layer3_network DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer3_network_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_member_layer3_network_collection_after_hooks ON layer3_network_collection_layer3_network;
CREATE TRIGGER trigger_member_layer3_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_layer3_network FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.layer3_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trig_userlog_logical_port ON logical_port;
CREATE TRIGGER trig_userlog_logical_port BEFORE INSERT OR UPDATE ON jazzhands.logical_port FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_port ON logical_port;
CREATE TRIGGER trigger_audit_logical_port AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_port FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_logical_port();
DROP TRIGGER IF EXISTS trig_userlog_logical_port_slot ON logical_port_slot;
CREATE TRIGGER trig_userlog_logical_port_slot BEFORE INSERT OR UPDATE ON jazzhands.logical_port_slot FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_port_slot ON logical_port_slot;
CREATE TRIGGER trigger_audit_logical_port_slot AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_port_slot FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_logical_port_slot();
DROP TRIGGER IF EXISTS trig_userlog_logical_volume_property ON logical_volume_property;
CREATE TRIGGER trig_userlog_logical_volume_property BEFORE INSERT OR UPDATE ON jazzhands.logical_volume_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_volume_property ON logical_volume_property;
CREATE TRIGGER trigger_audit_logical_volume_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_volume_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_logical_volume_property();
DROP TRIGGER IF EXISTS trig_userlog_logical_volume_purpose ON logical_volume_purpose;
CREATE TRIGGER trig_userlog_logical_volume_purpose BEFORE INSERT OR UPDATE ON jazzhands.logical_volume_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_volume_purpose ON logical_volume_purpose;
CREATE TRIGGER trigger_audit_logical_volume_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_volume_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_logical_volume_purpose();
DROP TRIGGER IF EXISTS trig_userlog_mlag_peering ON mlag_peering;
CREATE TRIGGER trig_userlog_mlag_peering BEFORE INSERT OR UPDATE ON jazzhands.mlag_peering FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_mlag_peering ON mlag_peering;
CREATE TRIGGER trigger_audit_mlag_peering AFTER INSERT OR DELETE OR UPDATE ON jazzhands.mlag_peering FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_mlag_peering();
DROP TRIGGER IF EXISTS aaa_ta_manipulate_netblock_parentage ON netblock;
CREATE CONSTRAINT TRIGGER aaa_ta_manipulate_netblock_parentage AFTER INSERT OR DELETE ON jazzhands.netblock NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.manipulate_netblock_parentage_after();
DROP TRIGGER IF EXISTS tb_a_validate_netblock ON netblock;
CREATE TRIGGER tb_a_validate_netblock BEFORE INSERT OR UPDATE OF netblock_id, ip_address, netblock_type, is_single_address, can_subnet, parent_netblock_id, ip_universe_id ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_netblock();
DROP TRIGGER IF EXISTS tb_manipulate_netblock_parentage ON netblock;
CREATE TRIGGER tb_manipulate_netblock_parentage BEFORE INSERT OR UPDATE OF ip_address, netblock_type, ip_universe_id, netblock_id, can_subnet, is_single_address ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.manipulate_netblock_parentage_before();
DROP TRIGGER IF EXISTS trig_userlog_netblock ON netblock;
CREATE TRIGGER trig_userlog_netblock BEFORE INSERT OR UPDATE ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock ON netblock;
CREATE TRIGGER trigger_audit_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_netblock();
DROP TRIGGER IF EXISTS trigger_cache_netblock_hier_truncate ON netblock;
CREATE TRIGGER trigger_cache_netblock_hier_truncate AFTER TRUNCATE ON jazzhands.netblock FOR EACH STATEMENT EXECUTE FUNCTION jazzhands_cache.cache_netblock_hier_truncate_handler();
DROP TRIGGER IF EXISTS trigger_check_ip_universe_netblock ON netblock;
CREATE CONSTRAINT TRIGGER trigger_check_ip_universe_netblock AFTER UPDATE OF netblock_id, ip_universe_id ON jazzhands.netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_ip_universe_netblock();
DROP TRIGGER IF EXISTS trigger_nb_dns_a_rec_validation ON netblock;
CREATE TRIGGER trigger_nb_dns_a_rec_validation BEFORE UPDATE OF ip_address, is_single_address ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.nb_dns_a_rec_validation();
DROP TRIGGER IF EXISTS trigger_netblock_single_address_ni ON netblock;
CREATE TRIGGER trigger_netblock_single_address_ni BEFORE UPDATE OF is_single_address, netblock_type ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.netblock_single_address_ni();
DROP TRIGGER IF EXISTS trigger_netblock_validate_layer3_network_netblock ON netblock;
CREATE CONSTRAINT TRIGGER trigger_netblock_validate_layer3_network_netblock AFTER UPDATE OF can_subnet, is_single_address ON jazzhands.netblock NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.netblock_validate_layer3_network_netblock();
DROP TRIGGER IF EXISTS trigger_validate_netblock_parentage ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_parentage AFTER INSERT OR UPDATE OF netblock_id, ip_address, netblock_type, is_single_address, can_subnet, parent_netblock_id, ip_universe_id ON jazzhands.netblock DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_netblock_parentage();
DROP TRIGGER IF EXISTS trigger_validate_netblock_to_range_changes ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_to_range_changes AFTER UPDATE OF ip_address, is_single_address, can_subnet, netblock_type ON jazzhands.netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_netblock_to_range_changes();
DROP TRIGGER IF EXISTS zaa_ta_cache_netblock_hier_handler ON netblock;
CREATE TRIGGER zaa_ta_cache_netblock_hier_handler AFTER INSERT OR DELETE OR UPDATE OF ip_address, parent_netblock_id ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.cache_netblock_hier_handler();
DROP TRIGGER IF EXISTS aaa_netblock_collection_base_handler ON netblock_collection;
CREATE TRIGGER aaa_netblock_collection_base_handler AFTER INSERT OR DELETE OR UPDATE OF netblock_collection_id ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.netblock_collection_base_handler();
DROP TRIGGER IF EXISTS trig_userlog_netblock_collection ON netblock_collection;
CREATE TRIGGER trig_userlog_netblock_collection BEFORE INSERT OR UPDATE ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock_collection ON netblock_collection;
CREATE TRIGGER trigger_audit_netblock_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_netblock_collection();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_bytype_del ON netblock_collection;
CREATE TRIGGER trigger_manip_netblock_collection_bytype_del BEFORE DELETE ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_netblock_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_bytype_insup ON netblock_collection;
CREATE TRIGGER trigger_manip_netblock_collection_bytype_insup AFTER INSERT OR UPDATE OF netblock_collection_type ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_netblock_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_netblock_collection_type_change ON netblock_collection;
CREATE TRIGGER trigger_validate_netblock_collection_type_change BEFORE UPDATE OF netblock_collection_type ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_netblock_collection_type_change();
DROP TRIGGER IF EXISTS aaa_netblock_collection_root_handler ON netblock_collection_hier;
CREATE TRIGGER aaa_netblock_collection_root_handler AFTER INSERT OR DELETE OR UPDATE OF netblock_collection_id, child_netblock_collection_id ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.netblock_collection_root_handler();
DROP TRIGGER IF EXISTS trig_userlog_netblock_collection_hier ON netblock_collection_hier;
CREATE TRIGGER trig_userlog_netblock_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock_collection_hier ON netblock_collection_hier;
CREATE TRIGGER trigger_audit_netblock_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_netblock_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_netblock_collection_hier_loop ON netblock_collection_hier;
CREATE TRIGGER trigger_check_netblock_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.check_netblock_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_netblock_collection_hier_enforce ON netblock_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_netblock_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.netblock_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.netblock_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_netblock_collection_netblock ON netblock_collection_netblock;
CREATE TRIGGER trig_userlog_netblock_collection_netblock BEFORE INSERT OR UPDATE ON jazzhands.netblock_collection_netblock FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock_collection_netblock ON netblock_collection_netblock;
CREATE TRIGGER trigger_audit_netblock_collection_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock_collection_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_netblock_collection_netblock();
DROP TRIGGER IF EXISTS trigger_netblock_collection_member_enforce ON netblock_collection_netblock;
CREATE CONSTRAINT TRIGGER trigger_netblock_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.netblock_collection_netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.netblock_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_network_range ON network_range;
CREATE TRIGGER trig_userlog_network_range BEFORE INSERT OR UPDATE ON jazzhands.network_range FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_network_range ON network_range;
CREATE TRIGGER trigger_audit_network_range AFTER INSERT OR DELETE OR UPDATE ON jazzhands.network_range FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_network_range();
DROP TRIGGER IF EXISTS trigger_validate_network_range_dns ON network_range;
CREATE CONSTRAINT TRIGGER trigger_validate_network_range_dns AFTER INSERT OR UPDATE OF dns_domain_id ON jazzhands.network_range DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_network_range_dns();
DROP TRIGGER IF EXISTS trigger_validate_network_range_ips ON network_range;
CREATE CONSTRAINT TRIGGER trigger_validate_network_range_ips AFTER INSERT OR UPDATE OF start_netblock_id, stop_netblock_id, parent_netblock_id, network_range_type ON jazzhands.network_range DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_network_range_ips();
DROP TRIGGER IF EXISTS trig_userlog_network_service ON network_service;
CREATE TRIGGER trig_userlog_network_service BEFORE INSERT OR UPDATE ON jazzhands.network_service FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_network_service ON network_service;
CREATE TRIGGER trigger_audit_network_service AFTER INSERT OR DELETE OR UPDATE ON jazzhands.network_service FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_network_service();
DROP TRIGGER IF EXISTS trig_userlog_operating_system ON operating_system;
CREATE TRIGGER trig_userlog_operating_system BEFORE INSERT OR UPDATE ON jazzhands.operating_system FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_operating_system ON operating_system;
CREATE TRIGGER trigger_audit_operating_system AFTER INSERT OR DELETE OR UPDATE ON jazzhands.operating_system FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_operating_system();
DROP TRIGGER IF EXISTS trig_userlog_operating_system_snapshot ON operating_system_snapshot;
CREATE TRIGGER trig_userlog_operating_system_snapshot BEFORE INSERT OR UPDATE ON jazzhands.operating_system_snapshot FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_operating_system_snapshot ON operating_system_snapshot;
CREATE TRIGGER trigger_audit_operating_system_snapshot AFTER INSERT OR DELETE OR UPDATE ON jazzhands.operating_system_snapshot FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_operating_system_snapshot();
DROP TRIGGER IF EXISTS trig_userlog_person ON person;
CREATE TRIGGER trig_userlog_person BEFORE INSERT OR UPDATE ON jazzhands.person FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person ON person;
CREATE TRIGGER trigger_audit_person AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person();
DROP TRIGGER IF EXISTS trig_userlog_person_account_realm_company ON person_account_realm_company;
CREATE TRIGGER trig_userlog_person_account_realm_company BEFORE INSERT OR UPDATE ON jazzhands.person_account_realm_company FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_account_realm_company ON person_account_realm_company;
CREATE TRIGGER trigger_audit_person_account_realm_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_account_realm_company FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_account_realm_company();
DROP TRIGGER IF EXISTS trig_userlog_person_authentication_question ON person_authentication_question;
CREATE TRIGGER trig_userlog_person_authentication_question BEFORE INSERT OR UPDATE ON jazzhands.person_authentication_question FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_authentication_question ON person_authentication_question;
CREATE TRIGGER trigger_audit_person_authentication_question AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_authentication_question FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_authentication_question();
DROP TRIGGER IF EXISTS trig_userlog_person_company ON person_company;
CREATE TRIGGER trig_userlog_person_company BEFORE INSERT OR UPDATE ON jazzhands.person_company FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_company ON person_company;
CREATE TRIGGER trigger_audit_person_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_company FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_company();
DROP TRIGGER IF EXISTS trigger_propagate_person_status_to_account ON person_company;
CREATE TRIGGER trigger_propagate_person_status_to_account AFTER UPDATE ON jazzhands.person_company FOR EACH ROW EXECUTE FUNCTION jazzhands.propagate_person_status_to_account();
DROP TRIGGER IF EXISTS trigger_z_automated_ac_on_person_company ON person_company;
CREATE TRIGGER trigger_z_automated_ac_on_person_company AFTER UPDATE OF is_management, is_exempt, is_full_time, person_id, company_id, manager_person_id ON jazzhands.person_company FOR EACH ROW EXECUTE FUNCTION jazzhands.automated_ac_on_person_company();
DROP TRIGGER IF EXISTS trig_userlog_person_company_attribute ON person_company_attribute;
CREATE TRIGGER trig_userlog_person_company_attribute BEFORE INSERT OR UPDATE ON jazzhands.person_company_attribute FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_company_attribute ON person_company_attribute;
CREATE TRIGGER trigger_audit_person_company_attribute AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_company_attribute FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_company_attribute();
DROP TRIGGER IF EXISTS trigger_validate_person_company_attribute ON person_company_attribute;
CREATE TRIGGER trigger_validate_person_company_attribute BEFORE INSERT OR UPDATE ON jazzhands.person_company_attribute FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_person_company_attribute();
DROP TRIGGER IF EXISTS trig_userlog_person_company_badge ON person_company_badge;
CREATE TRIGGER trig_userlog_person_company_badge BEFORE INSERT OR UPDATE ON jazzhands.person_company_badge FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_company_badge ON person_company_badge;
CREATE TRIGGER trigger_audit_person_company_badge AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_company_badge FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_company_badge();
DROP TRIGGER IF EXISTS trig_userlog_person_contact ON person_contact;
CREATE TRIGGER trig_userlog_person_contact BEFORE INSERT OR UPDATE ON jazzhands.person_contact FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_contact ON person_contact;
CREATE TRIGGER trigger_audit_person_contact AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_contact FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_contact();
DROP TRIGGER IF EXISTS trig_userlog_person_image ON person_image;
CREATE TRIGGER trig_userlog_person_image BEFORE INSERT OR UPDATE ON jazzhands.person_image FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_image ON person_image;
CREATE TRIGGER trigger_audit_person_image AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_image FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_image();
DROP TRIGGER IF EXISTS trigger_fix_person_image_oid_ownership ON person_image;
CREATE TRIGGER trigger_fix_person_image_oid_ownership BEFORE INSERT ON jazzhands.person_image FOR EACH ROW EXECUTE FUNCTION jazzhands.fix_person_image_oid_ownership();
DROP TRIGGER IF EXISTS trig_userlog_person_image_usage ON person_image_usage;
CREATE TRIGGER trig_userlog_person_image_usage BEFORE INSERT OR UPDATE ON jazzhands.person_image_usage FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_image_usage ON person_image_usage;
CREATE TRIGGER trigger_audit_person_image_usage AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_image_usage FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_image_usage();
DROP TRIGGER IF EXISTS trigger_check_person_image_usage_mv ON person_image_usage;
CREATE TRIGGER trigger_check_person_image_usage_mv AFTER INSERT OR UPDATE ON jazzhands.person_image_usage FOR EACH ROW EXECUTE FUNCTION jazzhands.check_person_image_usage_mv();
DROP TRIGGER IF EXISTS trig_automated_realm_site_ac_pl ON person_location;
CREATE TRIGGER trig_automated_realm_site_ac_pl AFTER INSERT OR DELETE OR UPDATE OF site_code, person_id ON jazzhands.person_location FOR EACH ROW EXECUTE FUNCTION jazzhands.automated_realm_site_ac_pl();
DROP TRIGGER IF EXISTS trig_userlog_person_location ON person_location;
CREATE TRIGGER trig_userlog_person_location BEFORE INSERT OR UPDATE ON jazzhands.person_location FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_location ON person_location;
CREATE TRIGGER trigger_audit_person_location AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_location FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_location();
DROP TRIGGER IF EXISTS trig_userlog_person_note ON person_note;
CREATE TRIGGER trig_userlog_person_note BEFORE INSERT OR UPDATE ON jazzhands.person_note FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_note ON person_note;
CREATE TRIGGER trigger_audit_person_note AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_note FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_note();
DROP TRIGGER IF EXISTS trig_userlog_person_parking_pass ON person_parking_pass;
CREATE TRIGGER trig_userlog_person_parking_pass BEFORE INSERT OR UPDATE ON jazzhands.person_parking_pass FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_parking_pass ON person_parking_pass;
CREATE TRIGGER trigger_audit_person_parking_pass AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_parking_pass FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_parking_pass();
DROP TRIGGER IF EXISTS trig_userlog_person_vehicle ON person_vehicle;
CREATE TRIGGER trig_userlog_person_vehicle BEFORE INSERT OR UPDATE ON jazzhands.person_vehicle FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_vehicle ON person_vehicle;
CREATE TRIGGER trigger_audit_person_vehicle AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_vehicle FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_vehicle();
DROP TRIGGER IF EXISTS trig_userlog_physical_address ON physical_address;
CREATE TRIGGER trig_userlog_physical_address BEFORE INSERT OR UPDATE ON jazzhands.physical_address FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_physical_address ON physical_address;
CREATE TRIGGER trigger_audit_physical_address AFTER INSERT OR DELETE OR UPDATE ON jazzhands.physical_address FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_physical_address();
DROP TRIGGER IF EXISTS trig_userlog_physical_connection ON physical_connection;
CREATE TRIGGER trig_userlog_physical_connection BEFORE INSERT OR UPDATE ON jazzhands.physical_connection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_physical_connection ON physical_connection;
CREATE TRIGGER trigger_audit_physical_connection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.physical_connection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_physical_connection();
DROP TRIGGER IF EXISTS trigger_verify_physical_connection ON physical_connection;
CREATE TRIGGER trigger_verify_physical_connection AFTER INSERT OR UPDATE ON jazzhands.physical_connection FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.verify_physical_connection();
DROP TRIGGER IF EXISTS trig_userlog_port_range ON port_range;
CREATE TRIGGER trig_userlog_port_range BEFORE INSERT OR UPDATE ON jazzhands.port_range FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_port_range ON port_range;
CREATE TRIGGER trigger_audit_port_range AFTER INSERT OR DELETE OR UPDATE ON jazzhands.port_range FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_port_range();
DROP TRIGGER IF EXISTS trigger_port_range_manage_singleton ON port_range;
CREATE TRIGGER trigger_port_range_manage_singleton BEFORE INSERT ON jazzhands.port_range FOR EACH ROW EXECUTE FUNCTION jazzhands.port_range_manage_singleton();
DROP TRIGGER IF EXISTS trigger_port_range_sanity_check ON port_range;
CREATE CONSTRAINT TRIGGER trigger_port_range_sanity_check AFTER INSERT OR UPDATE OF port_start, port_end, is_singleton ON jazzhands.port_range NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.port_range_sanity_check();
DROP TRIGGER IF EXISTS trig_userlog_private_key ON private_key;
CREATE TRIGGER trig_userlog_private_key BEFORE INSERT OR UPDATE ON jazzhands.private_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_private_key ON private_key;
CREATE TRIGGER trigger_audit_private_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.private_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_private_key();
DROP TRIGGER IF EXISTS trigger_private_key_delete_dangling_hashes ON private_key;
CREATE TRIGGER trigger_private_key_delete_dangling_hashes AFTER DELETE OR UPDATE OF public_key_hash_id ON jazzhands.private_key FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.delete_dangling_public_key_hashes();
DROP TRIGGER IF EXISTS trig_userlog_property ON property;
CREATE TRIGGER trig_userlog_property BEFORE INSERT OR UPDATE ON jazzhands.property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property ON property;
CREATE TRIGGER trigger_audit_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_property();
DROP TRIGGER IF EXISTS trigger_validate_property ON property;
CREATE CONSTRAINT TRIGGER trigger_validate_property AFTER INSERT OR UPDATE ON jazzhands.property NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_property();
DROP TRIGGER IF EXISTS trig_userlog_property_name_collection ON property_name_collection;
CREATE TRIGGER trig_userlog_property_name_collection BEFORE INSERT OR UPDATE ON jazzhands.property_name_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property_name_collection ON property_name_collection;
CREATE TRIGGER trigger_audit_property_name_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_property_name_collection();
DROP TRIGGER IF EXISTS trigger_validate_property_name_collection_type_change ON property_name_collection;
CREATE TRIGGER trigger_validate_property_name_collection_type_change BEFORE UPDATE OF property_name_collection_type ON jazzhands.property_name_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_property_name_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_property_name_collection_hier ON property_name_collection_hier;
CREATE TRIGGER trig_userlog_property_name_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.property_name_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property_name_collection_hier ON property_name_collection_hier;
CREATE TRIGGER trigger_audit_property_name_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_property_name_collection_hier();
DROP TRIGGER IF EXISTS trigger_hier_property_name_collection_after_hooks ON property_name_collection_hier;
CREATE TRIGGER trigger_hier_property_name_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_hier FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.property_name_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_property_name_collection_hier_enforce ON property_name_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_property_name_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.property_name_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.property_name_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_property_name_collection_property_name ON property_name_collection_property_name;
CREATE TRIGGER trig_userlog_property_name_collection_property_name BEFORE INSERT OR UPDATE ON jazzhands.property_name_collection_property_name FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property_name_collection_property_name ON property_name_collection_property_name;
CREATE TRIGGER trigger_audit_property_name_collection_property_name AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_property_name FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_property_name_collection_property_name();
DROP TRIGGER IF EXISTS trigger_member_property_name_collection_after_hooks ON property_name_collection_property_name;
CREATE TRIGGER trigger_member_property_name_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_property_name FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.property_name_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_property_name_collection_member_enforce ON property_name_collection_property_name;
CREATE CONSTRAINT TRIGGER trigger_property_name_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.property_name_collection_property_name DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.property_name_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_protocol ON protocol;
CREATE TRIGGER trig_userlog_protocol BEFORE INSERT OR UPDATE ON jazzhands.protocol FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_protocol ON protocol;
CREATE TRIGGER trigger_audit_protocol AFTER INSERT OR DELETE OR UPDATE ON jazzhands.protocol FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_protocol();
DROP TRIGGER IF EXISTS trig_userlog_pseudo_klogin ON pseudo_klogin;
CREATE TRIGGER trig_userlog_pseudo_klogin BEFORE INSERT OR UPDATE ON jazzhands.pseudo_klogin FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_pseudo_klogin ON pseudo_klogin;
CREATE TRIGGER trigger_audit_pseudo_klogin AFTER INSERT OR DELETE OR UPDATE ON jazzhands.pseudo_klogin FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_pseudo_klogin();
DROP TRIGGER IF EXISTS trig_userlog_public_key_hash ON public_key_hash;
CREATE TRIGGER trig_userlog_public_key_hash BEFORE INSERT OR UPDATE ON jazzhands.public_key_hash FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_public_key_hash ON public_key_hash;
CREATE TRIGGER trigger_audit_public_key_hash AFTER INSERT OR DELETE OR UPDATE ON jazzhands.public_key_hash FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_public_key_hash();
DROP TRIGGER IF EXISTS trig_userlog_rack ON rack;
CREATE TRIGGER trig_userlog_rack BEFORE INSERT OR UPDATE ON jazzhands.rack FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_rack ON rack;
CREATE TRIGGER trigger_audit_rack AFTER INSERT OR DELETE OR UPDATE ON jazzhands.rack FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_rack();
DROP TRIGGER IF EXISTS trig_userlog_rack_location ON rack_location;
CREATE TRIGGER trig_userlog_rack_location BEFORE INSERT OR UPDATE ON jazzhands.rack_location FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_rack_location ON rack_location;
CREATE TRIGGER trigger_audit_rack_location AFTER INSERT OR DELETE OR UPDATE ON jazzhands.rack_location FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_rack_location();
DROP TRIGGER IF EXISTS trig_userlog_service ON service;
CREATE TRIGGER trig_userlog_service BEFORE INSERT OR UPDATE ON jazzhands.service FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service ON service;
CREATE TRIGGER trigger_audit_service AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service();
DROP TRIGGER IF EXISTS trigger_check_service_namespace ON service;
CREATE CONSTRAINT TRIGGER trigger_check_service_namespace AFTER INSERT OR UPDATE OF service_name, service_type ON jazzhands.service NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_service_namespace();
DROP TRIGGER IF EXISTS trigger_create_all_services_collection ON service;
CREATE TRIGGER trigger_create_all_services_collection AFTER INSERT OR UPDATE OF service_name ON jazzhands.service FOR EACH ROW EXECUTE FUNCTION jazzhands.create_all_services_collection();
DROP TRIGGER IF EXISTS trigger_create_all_services_collection_del ON service;
CREATE TRIGGER trigger_create_all_services_collection_del BEFORE DELETE ON jazzhands.service FOR EACH ROW EXECUTE FUNCTION jazzhands.create_all_services_collection();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint ON service_endpoint;
CREATE TRIGGER trig_userlog_service_endpoint BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint ON service_endpoint;
CREATE TRIGGER trigger_audit_service_endpoint AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint();
DROP TRIGGER IF EXISTS trigger_service_endpoint_direct_check ON service_endpoint;
CREATE CONSTRAINT TRIGGER trigger_service_endpoint_direct_check AFTER INSERT OR UPDATE OF dns_record_id, port_range_id ON jazzhands.service_endpoint NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_endpoint_direct_check();
DROP TRIGGER IF EXISTS trigger_validate_service_endpoint_fksets ON service_endpoint;
CREATE CONSTRAINT TRIGGER trigger_validate_service_endpoint_fksets AFTER INSERT OR UPDATE OF dns_record_id, port_range_id ON jazzhands.service_endpoint NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_service_endpoint_fksets();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_health_check ON service_endpoint_health_check;
CREATE TRIGGER trig_userlog_service_endpoint_health_check BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_health_check FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_health_check ON service_endpoint_health_check;
CREATE TRIGGER trigger_audit_service_endpoint_health_check AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_health_check FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_health_check();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_provider ON service_endpoint_provider;
CREATE TRIGGER trig_userlog_service_endpoint_provider BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_provider FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_provider ON service_endpoint_provider;
CREATE TRIGGER trigger_audit_service_endpoint_provider AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_provider FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_provider();
DROP TRIGGER IF EXISTS trigger_service_endpoint_provider_direct_check ON service_endpoint_provider;
CREATE CONSTRAINT TRIGGER trigger_service_endpoint_provider_direct_check AFTER INSERT OR UPDATE OF service_endpoint_provider_type, dns_record_id ON jazzhands.service_endpoint_provider NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_endpoint_provider_direct_check();
DROP TRIGGER IF EXISTS trigger_service_endpoint_provider_dns_netblock_check ON service_endpoint_provider;
CREATE CONSTRAINT TRIGGER trigger_service_endpoint_provider_dns_netblock_check AFTER INSERT OR UPDATE OF dns_record_id, netblock_id ON jazzhands.service_endpoint_provider NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_endpoint_provider_dns_netblock_check();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_provider_collection ON service_endpoint_provider_collection;
CREATE TRIGGER trig_userlog_service_endpoint_provider_collection BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_provider_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_provider_collection ON service_endpoint_provider_collection;
CREATE TRIGGER trigger_audit_service_endpoint_provider_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_provider_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_provider_collection();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_provider_collection_service_endpo ON service_endpoint_provider_collection_service_endpoint_provider;
CREATE TRIGGER trig_userlog_service_endpoint_provider_collection_service_endpo BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_provider_collection_service_endpoint_provider FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_provider_collection_service_endp ON service_endpoint_provider_collection_service_endpoint_provider;
CREATE TRIGGER trigger_audit_service_endpoint_provider_collection_service_endp AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_provider_collection_service_endpoint_provider FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_provider_collection_service_endp();
DROP TRIGGER IF EXISTS trigger_svc_ep_coll_sep_direct_check ON service_endpoint_provider_collection_service_endpoint_provider;
CREATE CONSTRAINT TRIGGER trigger_svc_ep_coll_sep_direct_check AFTER INSERT OR UPDATE OF service_endpoint_provider_collection_id, service_endpoint_provider_id ON jazzhands.service_endpoint_provider_collection_service_endpoint_provider NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.svc_ep_coll_sep_direct_check();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_provider_service_instance ON service_endpoint_provider_service_instance;
CREATE TRIGGER trig_userlog_service_endpoint_provider_service_instance BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_provider_service_instance FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_provider_service_instance ON service_endpoint_provider_service_instance;
CREATE TRIGGER trigger_audit_service_endpoint_provider_service_instance AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_provider_service_instance FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_provider_service_instance();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_provider_shared_netblock_layer3_i ON service_endpoint_provider_shared_netblock_layer3_interface;
CREATE TRIGGER trig_userlog_service_endpoint_provider_shared_netblock_layer3_i BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_provider_shared_netblock_layer3_interface FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_provider_shared_netblock_layer3_ ON service_endpoint_provider_shared_netblock_layer3_interface;
CREATE TRIGGER trigger_audit_service_endpoint_provider_shared_netblock_layer3_ AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_provider_shared_netblock_layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_provider_shared_netblock_layer3_();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_service_endpoint_provider_collect ON service_endpoint_service_endpoint_provider_collection;
CREATE TRIGGER trig_userlog_service_endpoint_service_endpoint_provider_collect BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_service_endpoint_provider_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_service_endpoint_provider_collec ON service_endpoint_service_endpoint_provider_collection;
CREATE TRIGGER trigger_audit_service_endpoint_service_endpoint_provider_collec AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_service_endpoint_provider_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_service_endpoint_provider_collec();
DROP TRIGGER IF EXISTS trigger_svc_end_prov_svc_end_col_direct_check ON service_endpoint_service_endpoint_provider_collection;
CREATE CONSTRAINT TRIGGER trigger_svc_end_prov_svc_end_col_direct_check AFTER INSERT OR UPDATE OF service_endpoint_provider_collection_id, service_endpoint_relation_type, service_endpoint_relation_key ON jazzhands.service_endpoint_service_endpoint_provider_collection NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.svc_end_prov_svc_end_col_direct_check();
DROP TRIGGER IF EXISTS trigger_svc_ep_svc_epp_coll_direct ON service_endpoint_service_endpoint_provider_collection;
CREATE CONSTRAINT TRIGGER trigger_svc_ep_svc_epp_coll_direct AFTER INSERT OR UPDATE OF service_endpoint_relation_type, service_endpoint_relation_key ON jazzhands.service_endpoint_service_endpoint_provider_collection NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.svc_ep_svc_epp_coll_direct();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_service_sla ON service_endpoint_service_sla;
CREATE TRIGGER trig_userlog_service_endpoint_service_sla BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_service_sla FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_service_sla ON service_endpoint_service_sla;
CREATE TRIGGER trigger_audit_service_endpoint_service_sla AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_service_sla FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_service_sla();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_service_sla_service_feature ON service_endpoint_service_sla_service_feature;
CREATE TRIGGER trig_userlog_service_endpoint_service_sla_service_feature BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_service_sla_service_feature FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_service_sla_service_feature ON service_endpoint_service_sla_service_feature;
CREATE TRIGGER trigger_audit_service_endpoint_service_sla_service_feature AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_service_sla_service_feature FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_service_sla_service_feature();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_x509_certificate ON service_endpoint_x509_certificate;
CREATE TRIGGER trig_userlog_service_endpoint_x509_certificate BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_x509_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_x509_certificate ON service_endpoint_x509_certificate;
CREATE TRIGGER trigger_audit_service_endpoint_x509_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_x509_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_x509_certificate();
DROP TRIGGER IF EXISTS trig_userlog_service_environment ON service_environment;
CREATE TRIGGER trig_userlog_service_environment BEFORE INSERT OR UPDATE ON jazzhands.service_environment FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment ON service_environment;
CREATE TRIGGER trigger_audit_service_environment AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_environment();
DROP TRIGGER IF EXISTS trigger_delete_per_service_environment_service_environment_coll ON service_environment;
CREATE TRIGGER trigger_delete_per_service_environment_service_environment_coll BEFORE DELETE ON jazzhands.service_environment FOR EACH ROW EXECUTE FUNCTION jazzhands.delete_per_service_environment_service_environment_collection();
DROP TRIGGER IF EXISTS trigger_update_per_service_environment_service_environment_coll ON service_environment;
CREATE TRIGGER trigger_update_per_service_environment_service_environment_coll AFTER INSERT OR UPDATE ON jazzhands.service_environment FOR EACH ROW EXECUTE FUNCTION jazzhands.update_per_service_environment_service_environment_collection();
DROP TRIGGER IF EXISTS trig_userlog_service_environment_collection ON service_environment_collection;
CREATE TRIGGER trig_userlog_service_environment_collection BEFORE INSERT OR UPDATE ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment_collection ON service_environment_collection;
CREATE TRIGGER trigger_audit_service_environment_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_environment_collection();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_bytype_del ON service_environment_collection;
CREATE TRIGGER trigger_manip_service_environment_collection_bytype_del BEFORE DELETE ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_service_environment_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_bytype_insup ON service_environment_collection;
CREATE TRIGGER trigger_manip_service_environment_collection_bytype_insup AFTER INSERT OR UPDATE OF service_environment_collection_type ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_service_environment_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_service_environment_collection_type_change ON service_environment_collection;
CREATE TRIGGER trigger_validate_service_environment_collection_type_change BEFORE UPDATE OF service_environment_collection_type ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_service_environment_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_service_environment_collection_hier ON service_environment_collection_hier;
CREATE TRIGGER trig_userlog_service_environment_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.service_environment_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment_collection_hier ON service_environment_collection_hier;
CREATE TRIGGER trigger_audit_service_environment_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_environment_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_svcenv_collection_hier_loop ON service_environment_collection_hier;
CREATE TRIGGER trigger_check_svcenv_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.service_environment_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.check_svcenv_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_service_environment_collection_hier_enforce ON service_environment_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_service_environment_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.service_environment_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_environment_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_service_environment_collection_service_environment ON service_environment_collection_service_environment;
CREATE TRIGGER trig_userlog_service_environment_collection_service_environment BEFORE INSERT OR UPDATE ON jazzhands.service_environment_collection_service_environment FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment_collection_service_environmen ON service_environment_collection_service_environment;
CREATE TRIGGER trigger_audit_service_environment_collection_service_environmen AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment_collection_service_environment FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_environment_collection_service_environmen();
DROP TRIGGER IF EXISTS trigger_service_environment_collection_member_enforce ON service_environment_collection_service_environment;
CREATE CONSTRAINT TRIGGER trigger_service_environment_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.service_environment_collection_service_environment DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_environment_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_service_instance ON service_instance;
CREATE TRIGGER trig_userlog_service_instance BEFORE INSERT OR UPDATE ON jazzhands.service_instance FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_instance ON service_instance;
CREATE TRIGGER trigger_audit_service_instance AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_instance FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_instance();
DROP TRIGGER IF EXISTS trig_userlog_service_instance_provided_feature ON service_instance_provided_feature;
CREATE TRIGGER trig_userlog_service_instance_provided_feature BEFORE INSERT OR UPDATE ON jazzhands.service_instance_provided_feature FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_instance_provided_feature ON service_instance_provided_feature;
CREATE TRIGGER trigger_audit_service_instance_provided_feature AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_instance_provided_feature FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_instance_provided_feature();
DROP TRIGGER IF EXISTS trigger_service_instance_feature_check ON service_instance_provided_feature;
CREATE CONSTRAINT TRIGGER trigger_service_instance_feature_check AFTER INSERT ON jazzhands.service_instance_provided_feature NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_instance_feature_check();
DROP TRIGGER IF EXISTS trigger_service_instance_service_feature_rename ON service_instance_provided_feature;
CREATE CONSTRAINT TRIGGER trigger_service_instance_service_feature_rename AFTER UPDATE OF service_feature, service_instance_id ON jazzhands.service_instance_provided_feature NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_instance_service_feature_rename();
DROP TRIGGER IF EXISTS trig_userlog_service_layer3_acl ON service_layer3_acl;
CREATE TRIGGER trig_userlog_service_layer3_acl BEFORE INSERT OR UPDATE ON jazzhands.service_layer3_acl FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_layer3_acl ON service_layer3_acl;
CREATE TRIGGER trigger_audit_service_layer3_acl AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_layer3_acl FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_layer3_acl();
DROP TRIGGER IF EXISTS trig_userlog_service_relationship ON service_relationship;
CREATE TRIGGER trig_userlog_service_relationship BEFORE INSERT OR UPDATE ON jazzhands.service_relationship FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_relationship ON service_relationship;
CREATE TRIGGER trigger_audit_service_relationship AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_relationship FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_relationship();
DROP TRIGGER IF EXISTS trigger_check_service_relationship_rhs ON service_relationship;
CREATE CONSTRAINT TRIGGER trigger_check_service_relationship_rhs AFTER INSERT OR UPDATE OF related_service_version_id, service_version_restriction_service_id, service_version_restriction ON jazzhands.service_relationship NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_service_relationship_rhs();
DROP TRIGGER IF EXISTS trig_userlog_service_relationship_service_feature ON service_relationship_service_feature;
CREATE TRIGGER trig_userlog_service_relationship_service_feature BEFORE INSERT OR UPDATE ON jazzhands.service_relationship_service_feature FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_relationship_service_feature ON service_relationship_service_feature;
CREATE TRIGGER trigger_audit_service_relationship_service_feature AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_relationship_service_feature FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_relationship_service_feature();
DROP TRIGGER IF EXISTS trigger_service_relationship_feature_check ON service_relationship_service_feature;
CREATE CONSTRAINT TRIGGER trigger_service_relationship_feature_check AFTER INSERT OR UPDATE OF service_feature ON jazzhands.service_relationship_service_feature NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_relationship_feature_check();
DROP TRIGGER IF EXISTS trig_userlog_service_sla ON service_sla;
CREATE TRIGGER trig_userlog_service_sla BEFORE INSERT OR UPDATE ON jazzhands.service_sla FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_sla ON service_sla;
CREATE TRIGGER trigger_audit_service_sla AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_sla FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_sla();
DROP TRIGGER IF EXISTS trig_userlog_service_software_repository ON service_software_repository;
CREATE TRIGGER trig_userlog_service_software_repository BEFORE INSERT OR UPDATE ON jazzhands.service_software_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_software_repository ON service_software_repository;
CREATE TRIGGER trigger_audit_service_software_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_software_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_software_repository();
DROP TRIGGER IF EXISTS trig_userlog_service_source_repository ON service_source_repository;
CREATE TRIGGER trig_userlog_service_source_repository BEFORE INSERT OR UPDATE ON jazzhands.service_source_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_source_repository ON service_source_repository;
CREATE TRIGGER trigger_audit_service_source_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_source_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_source_repository();
DROP TRIGGER IF EXISTS trigger_service_source_repository_sanity ON service_source_repository;
CREATE CONSTRAINT TRIGGER trigger_service_source_repository_sanity AFTER INSERT OR UPDATE OF is_primary ON jazzhands.service_source_repository NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_source_repository_sanity();
DROP TRIGGER IF EXISTS trigger_service_source_repository_service_match_check ON service_source_repository;
CREATE CONSTRAINT TRIGGER trigger_service_source_repository_service_match_check AFTER UPDATE OF service_id, service_source_repository_id ON jazzhands.service_source_repository NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_source_repository_service_match_check();
DROP TRIGGER IF EXISTS trig_userlog_service_version ON service_version;
CREATE TRIGGER trig_userlog_service_version BEFORE INSERT OR UPDATE ON jazzhands.service_version FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version ON service_version;
CREATE TRIGGER trigger_audit_service_version AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version();
DROP TRIGGER IF EXISTS trigger_manip_all_svc_collection_members ON service_version;
CREATE TRIGGER trigger_manip_all_svc_collection_members AFTER INSERT ON jazzhands.service_version FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_all_svc_collection_members();
DROP TRIGGER IF EXISTS trigger_manip_all_svc_collection_members_del ON service_version;
CREATE TRIGGER trigger_manip_all_svc_collection_members_del BEFORE DELETE ON jazzhands.service_version FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_all_svc_collection_members();
DROP TRIGGER IF EXISTS trigger_propagate_service_type_to_version ON service_version;
CREATE TRIGGER trigger_propagate_service_type_to_version BEFORE INSERT ON jazzhands.service_version FOR EACH ROW EXECUTE FUNCTION jazzhands.propagate_service_type_to_version();
DROP TRIGGER IF EXISTS trig_userlog_service_version_artifact ON service_version_artifact;
CREATE TRIGGER trig_userlog_service_version_artifact BEFORE INSERT OR UPDATE ON jazzhands.service_version_artifact FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_artifact ON service_version_artifact;
CREATE TRIGGER trigger_audit_service_version_artifact AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_artifact FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_artifact();
DROP TRIGGER IF EXISTS trig_userlog_service_version_collection ON service_version_collection;
CREATE TRIGGER trig_userlog_service_version_collection BEFORE INSERT OR UPDATE ON jazzhands.service_version_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_collection ON service_version_collection;
CREATE TRIGGER trigger_audit_service_version_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_collection();
DROP TRIGGER IF EXISTS trig_userlog_service_version_collection_hier ON service_version_collection_hier;
CREATE TRIGGER trig_userlog_service_version_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.service_version_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_collection_hier ON service_version_collection_hier;
CREATE TRIGGER trigger_audit_service_version_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_collection_hier();
DROP TRIGGER IF EXISTS trig_userlog_service_version_collection_permitted_feature ON service_version_collection_permitted_feature;
CREATE TRIGGER trig_userlog_service_version_collection_permitted_feature BEFORE INSERT OR UPDATE ON jazzhands.service_version_collection_permitted_feature FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_collection_permitted_feature ON service_version_collection_permitted_feature;
CREATE TRIGGER trigger_audit_service_version_collection_permitted_feature AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_collection_permitted_feature FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_collection_permitted_feature();
DROP TRIGGER IF EXISTS trigger_service_version_feature_permitted_rename ON service_version_collection_permitted_feature;
CREATE CONSTRAINT TRIGGER trigger_service_version_feature_permitted_rename AFTER UPDATE OF service_feature ON jazzhands.service_version_collection_permitted_feature NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_version_feature_permitted_rename();
DROP TRIGGER IF EXISTS trig_userlog_service_version_collection_service_version ON service_version_collection_service_version;
CREATE TRIGGER trig_userlog_service_version_collection_service_version BEFORE INSERT OR UPDATE ON jazzhands.service_version_collection_service_version FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_collection_service_version ON service_version_collection_service_version;
CREATE TRIGGER trigger_audit_service_version_collection_service_version AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_collection_service_version FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_collection_service_version();
DROP TRIGGER IF EXISTS trig_userlog_service_version_software_artifact_repository ON service_version_software_artifact_repository;
CREATE TRIGGER trig_userlog_service_version_software_artifact_repository BEFORE INSERT OR UPDATE ON jazzhands.service_version_software_artifact_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_software_artifact_repository ON service_version_software_artifact_repository;
CREATE TRIGGER trigger_audit_service_version_software_artifact_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_software_artifact_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_software_artifact_repository();
DROP TRIGGER IF EXISTS trig_userlog_service_version_source_repository ON service_version_source_repository;
CREATE TRIGGER trig_userlog_service_version_source_repository BEFORE INSERT OR UPDATE ON jazzhands.service_version_source_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_source_repository ON service_version_source_repository;
CREATE TRIGGER trigger_audit_service_version_source_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_source_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_source_repository();
DROP TRIGGER IF EXISTS trigger_service_version_source_repository_service_match_check ON service_version_source_repository;
CREATE CONSTRAINT TRIGGER trigger_service_version_source_repository_service_match_check AFTER INSERT OR UPDATE OF service_version_id, service_source_repository_id ON jazzhands.service_version_source_repository NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_version_source_repository_service_match_check();
DROP TRIGGER IF EXISTS trig_userlog_shared_netblock ON shared_netblock;
CREATE TRIGGER trig_userlog_shared_netblock BEFORE INSERT OR UPDATE ON jazzhands.shared_netblock FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_shared_netblock ON shared_netblock;
CREATE TRIGGER trigger_audit_shared_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.shared_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_shared_netblock();
DROP TRIGGER IF EXISTS trig_userlog_shared_netblock_layer3_interface ON shared_netblock_layer3_interface;
CREATE TRIGGER trig_userlog_shared_netblock_layer3_interface BEFORE INSERT OR UPDATE ON jazzhands.shared_netblock_layer3_interface FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_shared_netblock_layer3_interface ON shared_netblock_layer3_interface;
CREATE TRIGGER trigger_audit_shared_netblock_layer3_interface AFTER INSERT OR DELETE OR UPDATE ON jazzhands.shared_netblock_layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_shared_netblock_layer3_interface();
DROP TRIGGER IF EXISTS trig_userlog_site ON site;
CREATE TRIGGER trig_userlog_site BEFORE INSERT OR UPDATE ON jazzhands.site FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_site ON site;
CREATE TRIGGER trigger_audit_site AFTER INSERT OR DELETE OR UPDATE ON jazzhands.site FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_site();
DROP TRIGGER IF EXISTS trigger_del_site_netblock_collections ON site;
CREATE TRIGGER trigger_del_site_netblock_collections BEFORE DELETE ON jazzhands.site FOR EACH ROW EXECUTE FUNCTION jazzhands.del_site_netblock_collections();
DROP TRIGGER IF EXISTS trigger_ins_site_netblock_collections ON site;
CREATE TRIGGER trigger_ins_site_netblock_collections AFTER INSERT ON jazzhands.site FOR EACH ROW EXECUTE FUNCTION jazzhands.ins_site_netblock_collections();
DROP TRIGGER IF EXISTS trigger_upd_site_netblock_collections ON site;
CREATE TRIGGER trigger_upd_site_netblock_collections AFTER UPDATE ON jazzhands.site FOR EACH ROW EXECUTE FUNCTION jazzhands.upd_site_netblock_collections();
DROP TRIGGER IF EXISTS trig_userlog_slot ON slot;
CREATE TRIGGER trig_userlog_slot BEFORE INSERT OR UPDATE ON jazzhands.slot FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot ON slot;
CREATE TRIGGER trigger_audit_slot AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_slot();
DROP TRIGGER IF EXISTS trig_userlog_slot_type ON slot_type;
CREATE TRIGGER trig_userlog_slot_type BEFORE INSERT OR UPDATE ON jazzhands.slot_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot_type ON slot_type;
CREATE TRIGGER trigger_audit_slot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_slot_type();
DROP TRIGGER IF EXISTS trig_userlog_slot_type_permitted_component_slot_type ON slot_type_permitted_component_slot_type;
CREATE TRIGGER trig_userlog_slot_type_permitted_component_slot_type BEFORE INSERT OR UPDATE ON jazzhands.slot_type_permitted_component_slot_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot_type_permitted_component_slot_type ON slot_type_permitted_component_slot_type;
CREATE TRIGGER trigger_audit_slot_type_permitted_component_slot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot_type_permitted_component_slot_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_slot_type_permitted_component_slot_type();
DROP TRIGGER IF EXISTS trig_userlog_slot_type_permitted_remote_slot_type ON slot_type_permitted_remote_slot_type;
CREATE TRIGGER trig_userlog_slot_type_permitted_remote_slot_type BEFORE INSERT OR UPDATE ON jazzhands.slot_type_permitted_remote_slot_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot_type_permitted_remote_slot_type ON slot_type_permitted_remote_slot_type;
CREATE TRIGGER trigger_audit_slot_type_permitted_remote_slot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot_type_permitted_remote_slot_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_slot_type_permitted_remote_slot_type();
DROP TRIGGER IF EXISTS trig_userlog_software_artifact_name ON software_artifact_name;
CREATE TRIGGER trig_userlog_software_artifact_name BEFORE INSERT OR UPDATE ON jazzhands.software_artifact_name FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_software_artifact_name ON software_artifact_name;
CREATE TRIGGER trigger_audit_software_artifact_name AFTER INSERT OR DELETE OR UPDATE ON jazzhands.software_artifact_name FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_software_artifact_name();
DROP TRIGGER IF EXISTS trig_userlog_software_artifact_provider ON software_artifact_provider;
CREATE TRIGGER trig_userlog_software_artifact_provider BEFORE INSERT OR UPDATE ON jazzhands.software_artifact_provider FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_software_artifact_provider ON software_artifact_provider;
CREATE TRIGGER trigger_audit_software_artifact_provider AFTER INSERT OR DELETE OR UPDATE ON jazzhands.software_artifact_provider FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_software_artifact_provider();
DROP TRIGGER IF EXISTS trig_userlog_software_artifact_repository ON software_artifact_repository;
CREATE TRIGGER trig_userlog_software_artifact_repository BEFORE INSERT OR UPDATE ON jazzhands.software_artifact_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_software_artifact_repository ON software_artifact_repository;
CREATE TRIGGER trigger_audit_software_artifact_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.software_artifact_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_software_artifact_repository();
DROP TRIGGER IF EXISTS trig_userlog_software_artifact_repository_relation ON software_artifact_repository_relation;
CREATE TRIGGER trig_userlog_software_artifact_repository_relation BEFORE INSERT OR UPDATE ON jazzhands.software_artifact_repository_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_software_artifact_repository_relation ON software_artifact_repository_relation;
CREATE TRIGGER trigger_audit_software_artifact_repository_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.software_artifact_repository_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_software_artifact_repository_relation();
DROP TRIGGER IF EXISTS trig_userlog_software_artifact_repository_uri ON software_artifact_repository_uri;
CREATE TRIGGER trig_userlog_software_artifact_repository_uri BEFORE INSERT OR UPDATE ON jazzhands.software_artifact_repository_uri FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_software_artifact_repository_uri ON software_artifact_repository_uri;
CREATE TRIGGER trigger_audit_software_artifact_repository_uri AFTER INSERT OR DELETE OR UPDATE ON jazzhands.software_artifact_repository_uri FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_software_artifact_repository_uri();
DROP TRIGGER IF EXISTS trigger_software_artifact_repository_uri_endpoint_enforce ON software_artifact_repository_uri;
CREATE CONSTRAINT TRIGGER trigger_software_artifact_repository_uri_endpoint_enforce AFTER INSERT OR UPDATE OF software_artifact_repository_uri, service_endpoint_id ON jazzhands.software_artifact_repository_uri NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.software_artifact_repository_uri_endpoint_enforce();
DROP TRIGGER IF EXISTS trig_userlog_source_repository ON source_repository;
CREATE TRIGGER trig_userlog_source_repository BEFORE INSERT OR UPDATE ON jazzhands.source_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_source_repository ON source_repository;
CREATE TRIGGER trigger_audit_source_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.source_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_source_repository();
DROP TRIGGER IF EXISTS trig_userlog_source_repository_commit ON source_repository_commit;
CREATE TRIGGER trig_userlog_source_repository_commit BEFORE INSERT OR UPDATE ON jazzhands.source_repository_commit FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_source_repository_commit ON source_repository_commit;
CREATE TRIGGER trigger_audit_source_repository_commit AFTER INSERT OR DELETE OR UPDATE ON jazzhands.source_repository_commit FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_source_repository_commit();
DROP TRIGGER IF EXISTS trig_userlog_source_repository_project ON source_repository_project;
CREATE TRIGGER trig_userlog_source_repository_project BEFORE INSERT OR UPDATE ON jazzhands.source_repository_project FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_source_repository_project ON source_repository_project;
CREATE TRIGGER trigger_audit_source_repository_project AFTER INSERT OR DELETE OR UPDATE ON jazzhands.source_repository_project FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_source_repository_project();
DROP TRIGGER IF EXISTS trig_userlog_source_repository_provider ON source_repository_provider;
CREATE TRIGGER trig_userlog_source_repository_provider BEFORE INSERT OR UPDATE ON jazzhands.source_repository_provider FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_source_repository_provider ON source_repository_provider;
CREATE TRIGGER trigger_audit_source_repository_provider AFTER INSERT OR DELETE OR UPDATE ON jazzhands.source_repository_provider FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_source_repository_provider();
DROP TRIGGER IF EXISTS trig_userlog_source_repository_provider_uri_template ON source_repository_provider_uri_template;
CREATE TRIGGER trig_userlog_source_repository_provider_uri_template BEFORE INSERT OR UPDATE ON jazzhands.source_repository_provider_uri_template FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_source_repository_provider_uri_template ON source_repository_provider_uri_template;
CREATE TRIGGER trigger_audit_source_repository_provider_uri_template AFTER INSERT OR DELETE OR UPDATE ON jazzhands.source_repository_provider_uri_template FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_source_repository_provider_uri_template();
DROP TRIGGER IF EXISTS trigger_source_repository_provider_uri_template_endpoint_enforc ON source_repository_provider_uri_template;
CREATE CONSTRAINT TRIGGER trigger_source_repository_provider_uri_template_endpoint_enforc AFTER INSERT OR UPDATE OF source_repository_uri, service_endpoint_id ON jazzhands.source_repository_provider_uri_template NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.source_repository_provider_uri_template_endpoint_enforce();
DROP TRIGGER IF EXISTS trig_userlog_ssh_key ON ssh_key;
CREATE TRIGGER trig_userlog_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.ssh_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ssh_key ON ssh_key;
CREATE TRIGGER trigger_audit_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ssh_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_static_route ON static_route;
CREATE TRIGGER trig_userlog_static_route BEFORE INSERT OR UPDATE ON jazzhands.static_route FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_static_route ON static_route;
CREATE TRIGGER trigger_audit_static_route AFTER INSERT OR DELETE OR UPDATE ON jazzhands.static_route FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_static_route();
DROP TRIGGER IF EXISTS trig_userlog_static_route_template ON static_route_template;
CREATE TRIGGER trig_userlog_static_route_template BEFORE INSERT OR UPDATE ON jazzhands.static_route_template FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_static_route_template ON static_route_template;
CREATE TRIGGER trigger_audit_static_route_template AFTER INSERT OR DELETE OR UPDATE ON jazzhands.static_route_template FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_static_route_template();
DROP TRIGGER IF EXISTS trig_userlog_sudo_account_collection_device_collection ON sudo_account_collection_device_collection;
CREATE TRIGGER trig_userlog_sudo_account_collection_device_collection BEFORE INSERT OR UPDATE ON jazzhands.sudo_account_collection_device_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_sudo_account_collection_device_collection ON sudo_account_collection_device_collection;
CREATE TRIGGER trigger_audit_sudo_account_collection_device_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.sudo_account_collection_device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_sudo_account_collection_device_collection();
DROP TRIGGER IF EXISTS trig_userlog_sudo_alias ON sudo_alias;
CREATE TRIGGER trig_userlog_sudo_alias BEFORE INSERT OR UPDATE ON jazzhands.sudo_alias FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_sudo_alias ON sudo_alias;
CREATE TRIGGER trigger_audit_sudo_alias AFTER INSERT OR DELETE OR UPDATE ON jazzhands.sudo_alias FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_sudo_alias();
DROP TRIGGER IF EXISTS trig_userlog_ticketing_system ON ticketing_system;
CREATE TRIGGER trig_userlog_ticketing_system BEFORE INSERT OR UPDATE ON jazzhands.ticketing_system FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ticketing_system ON ticketing_system;
CREATE TRIGGER trigger_audit_ticketing_system AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ticketing_system FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_ticketing_system();
DROP TRIGGER IF EXISTS trig_userlog_token ON token;
CREATE TRIGGER trig_userlog_token BEFORE INSERT OR UPDATE ON jazzhands.token FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token ON token;
CREATE TRIGGER trigger_audit_token AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_token();
DROP TRIGGER IF EXISTS trigger_pgnotify_token_change ON token;
CREATE TRIGGER trigger_pgnotify_token_change AFTER INSERT OR UPDATE ON jazzhands.token FOR EACH ROW EXECUTE FUNCTION jazzhands.pgnotify_token_change();
DROP TRIGGER IF EXISTS trig_userlog_token_collection ON token_collection;
CREATE TRIGGER trig_userlog_token_collection BEFORE INSERT OR UPDATE ON jazzhands.token_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token_collection ON token_collection;
CREATE TRIGGER trigger_audit_token_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_token_collection();
DROP TRIGGER IF EXISTS trig_userlog_token_collection_hier ON token_collection_hier;
CREATE TRIGGER trig_userlog_token_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.token_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token_collection_hier ON token_collection_hier;
CREATE TRIGGER trigger_audit_token_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_token_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_token_collection_hier_loop ON token_collection_hier;
CREATE TRIGGER trigger_check_token_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.token_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.check_token_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_token_collection_hier_enforce ON token_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_token_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.token_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.token_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_token_collection_token ON token_collection_token;
CREATE TRIGGER trig_userlog_token_collection_token BEFORE INSERT OR UPDATE ON jazzhands.token_collection_token FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token_collection_token ON token_collection_token;
CREATE TRIGGER trigger_audit_token_collection_token AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token_collection_token FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_token_collection_token();
DROP TRIGGER IF EXISTS trigger_token_collection_member_enforce ON token_collection_token;
CREATE CONSTRAINT TRIGGER trigger_token_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.token_collection_token DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.token_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_unix_group ON unix_group;
CREATE TRIGGER trig_userlog_unix_group BEFORE INSERT OR UPDATE ON jazzhands.unix_group FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_unix_group ON unix_group;
CREATE TRIGGER trigger_audit_unix_group AFTER INSERT OR DELETE OR UPDATE ON jazzhands.unix_group FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_unix_group();
DROP TRIGGER IF EXISTS trig_userlog_val_account_collection_relation ON val_account_collection_relation;
CREATE TRIGGER trig_userlog_val_account_collection_relation BEFORE INSERT OR UPDATE ON jazzhands.val_account_collection_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_acct_coll_preserve_direct ON val_account_collection_relation;
CREATE CONSTRAINT TRIGGER trigger_acct_coll_preserve_direct AFTER DELETE OR UPDATE ON jazzhands.val_account_collection_relation DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.acct_coll_preserve_direct();
DROP TRIGGER IF EXISTS trigger_audit_val_account_collection_relation ON val_account_collection_relation;
CREATE TRIGGER trigger_audit_val_account_collection_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_collection_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_account_collection_relation();
DROP TRIGGER IF EXISTS trig_account_collection_type_realm ON val_account_collection_type;
CREATE TRIGGER trig_account_collection_type_realm AFTER UPDATE OF account_realm_id ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_type_realm();
DROP TRIGGER IF EXISTS trig_userlog_val_account_collection_type ON val_account_collection_type;
CREATE TRIGGER trig_userlog_val_account_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_acct_coll_insert_direct ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_insert_direct AFTER INSERT ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.acct_coll_insert_direct();
DROP TRIGGER IF EXISTS trigger_acct_coll_remove_direct ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_remove_direct BEFORE DELETE ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.acct_coll_remove_direct();
DROP TRIGGER IF EXISTS trigger_acct_coll_update_direct_before ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_update_direct_before AFTER UPDATE OF account_collection_type ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.acct_coll_update_direct_before();
DROP TRIGGER IF EXISTS trigger_audit_val_account_collection_type ON val_account_collection_type;
CREATE TRIGGER trigger_audit_val_account_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_account_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_account_role ON val_account_role;
CREATE TRIGGER trig_userlog_val_account_role BEFORE INSERT OR UPDATE ON jazzhands.val_account_role FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_account_role ON val_account_role;
CREATE TRIGGER trigger_audit_val_account_role AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_role FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_account_role();
DROP TRIGGER IF EXISTS trig_userlog_val_account_type ON val_account_type;
CREATE TRIGGER trig_userlog_val_account_type BEFORE INSERT OR UPDATE ON jazzhands.val_account_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_account_type ON val_account_type;
CREATE TRIGGER trigger_audit_val_account_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_account_type();
DROP TRIGGER IF EXISTS trig_userlog_val_appaal_group_name ON val_appaal_group_name;
CREATE TRIGGER trig_userlog_val_appaal_group_name BEFORE INSERT OR UPDATE ON jazzhands.val_appaal_group_name FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_appaal_group_name ON val_appaal_group_name;
CREATE TRIGGER trigger_audit_val_appaal_group_name AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_appaal_group_name FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_appaal_group_name();
DROP TRIGGER IF EXISTS trig_userlog_val_application_key ON val_application_key;
CREATE TRIGGER trig_userlog_val_application_key BEFORE INSERT OR UPDATE ON jazzhands.val_application_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_application_key ON val_application_key;
CREATE TRIGGER trigger_audit_val_application_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_application_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_application_key();
DROP TRIGGER IF EXISTS trig_userlog_val_application_key_values ON val_application_key_values;
CREATE TRIGGER trig_userlog_val_application_key_values BEFORE INSERT OR UPDATE ON jazzhands.val_application_key_values FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_application_key_values ON val_application_key_values;
CREATE TRIGGER trigger_audit_val_application_key_values AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_application_key_values FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_application_key_values();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_chain_response_period ON val_approval_chain_response_period;
CREATE TRIGGER trig_userlog_val_approval_chain_response_period BEFORE INSERT OR UPDATE ON jazzhands.val_approval_chain_response_period FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_chain_response_period ON val_approval_chain_response_period;
CREATE TRIGGER trigger_audit_val_approval_chain_response_period AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_chain_response_period FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_approval_chain_response_period();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_expiration_action ON val_approval_expiration_action;
CREATE TRIGGER trig_userlog_val_approval_expiration_action BEFORE INSERT OR UPDATE ON jazzhands.val_approval_expiration_action FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_expiration_action ON val_approval_expiration_action;
CREATE TRIGGER trigger_audit_val_approval_expiration_action AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_expiration_action FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_approval_expiration_action();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_notifty_type ON val_approval_notifty_type;
CREATE TRIGGER trig_userlog_val_approval_notifty_type BEFORE INSERT OR UPDATE ON jazzhands.val_approval_notifty_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_notifty_type ON val_approval_notifty_type;
CREATE TRIGGER trigger_audit_val_approval_notifty_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_notifty_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_approval_notifty_type();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_process_type ON val_approval_process_type;
CREATE TRIGGER trig_userlog_val_approval_process_type BEFORE INSERT OR UPDATE ON jazzhands.val_approval_process_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_process_type ON val_approval_process_type;
CREATE TRIGGER trigger_audit_val_approval_process_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_process_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_approval_process_type();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_type ON val_approval_type;
CREATE TRIGGER trig_userlog_val_approval_type BEFORE INSERT OR UPDATE ON jazzhands.val_approval_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_type ON val_approval_type;
CREATE TRIGGER trigger_audit_val_approval_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_approval_type();
DROP TRIGGER IF EXISTS trig_userlog_val_attestation_frequency ON val_attestation_frequency;
CREATE TRIGGER trig_userlog_val_attestation_frequency BEFORE INSERT OR UPDATE ON jazzhands.val_attestation_frequency FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_attestation_frequency ON val_attestation_frequency;
CREATE TRIGGER trigger_audit_val_attestation_frequency AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_attestation_frequency FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_attestation_frequency();
DROP TRIGGER IF EXISTS trig_userlog_val_authentication_question ON val_authentication_question;
CREATE TRIGGER trig_userlog_val_authentication_question BEFORE INSERT OR UPDATE ON jazzhands.val_authentication_question FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_authentication_question ON val_authentication_question;
CREATE TRIGGER trigger_audit_val_authentication_question AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_authentication_question FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_authentication_question();
DROP TRIGGER IF EXISTS trig_userlog_val_authentication_resource ON val_authentication_resource;
CREATE TRIGGER trig_userlog_val_authentication_resource BEFORE INSERT OR UPDATE ON jazzhands.val_authentication_resource FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_authentication_resource ON val_authentication_resource;
CREATE TRIGGER trigger_audit_val_authentication_resource AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_authentication_resource FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_authentication_resource();
DROP TRIGGER IF EXISTS trig_userlog_val_badge_status ON val_badge_status;
CREATE TRIGGER trig_userlog_val_badge_status BEFORE INSERT OR UPDATE ON jazzhands.val_badge_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_badge_status ON val_badge_status;
CREATE TRIGGER trigger_audit_val_badge_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_badge_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_badge_status();
DROP TRIGGER IF EXISTS trig_userlog_val_cable_type ON val_cable_type;
CREATE TRIGGER trig_userlog_val_cable_type BEFORE INSERT OR UPDATE ON jazzhands.val_cable_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_cable_type ON val_cable_type;
CREATE TRIGGER trigger_audit_val_cable_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_cable_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_cable_type();
DROP TRIGGER IF EXISTS trig_userlog_val_checksum_algorithm ON val_checksum_algorithm;
CREATE TRIGGER trig_userlog_val_checksum_algorithm BEFORE INSERT OR UPDATE ON jazzhands.val_checksum_algorithm FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_checksum_algorithm ON val_checksum_algorithm;
CREATE TRIGGER trigger_audit_val_checksum_algorithm AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_checksum_algorithm FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_checksum_algorithm();
DROP TRIGGER IF EXISTS trig_userlog_val_company_collection_type ON val_company_collection_type;
CREATE TRIGGER trig_userlog_val_company_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_company_collection_type ON val_company_collection_type;
CREATE TRIGGER trigger_audit_val_company_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_company_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_type_bytype_del ON val_company_collection_type;
CREATE TRIGGER trigger_manip_company_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_company_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_type_bytype_insup ON val_company_collection_type;
CREATE TRIGGER trigger_manip_company_collection_type_bytype_insup AFTER INSERT OR UPDATE OF company_collection_type ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_company_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_company_type ON val_company_type;
CREATE TRIGGER trig_userlog_val_company_type BEFORE INSERT OR UPDATE ON jazzhands.val_company_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_company_type ON val_company_type;
CREATE TRIGGER trigger_audit_val_company_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_company_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_company_type();
DROP TRIGGER IF EXISTS trig_userlog_val_company_type_purpose ON val_company_type_purpose;
CREATE TRIGGER trig_userlog_val_company_type_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_company_type_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_company_type_purpose ON val_company_type_purpose;
CREATE TRIGGER trigger_audit_val_company_type_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_company_type_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_company_type_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_component_function ON val_component_function;
CREATE TRIGGER trig_userlog_val_component_function BEFORE INSERT OR UPDATE ON jazzhands.val_component_function FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_function ON val_component_function;
CREATE TRIGGER trigger_audit_val_component_function AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_function FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_component_function();
DROP TRIGGER IF EXISTS trig_userlog_val_component_management_controller_type ON val_component_management_controller_type;
CREATE TRIGGER trig_userlog_val_component_management_controller_type BEFORE INSERT OR UPDATE ON jazzhands.val_component_management_controller_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_management_controller_type ON val_component_management_controller_type;
CREATE TRIGGER trigger_audit_val_component_management_controller_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_management_controller_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_component_management_controller_type();
DROP TRIGGER IF EXISTS trig_userlog_val_component_property ON val_component_property;
CREATE TRIGGER trig_userlog_val_component_property BEFORE INSERT OR UPDATE ON jazzhands.val_component_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_property ON val_component_property;
CREATE TRIGGER trigger_audit_val_component_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_component_property();
DROP TRIGGER IF EXISTS trig_userlog_val_component_property_type ON val_component_property_type;
CREATE TRIGGER trig_userlog_val_component_property_type BEFORE INSERT OR UPDATE ON jazzhands.val_component_property_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_property_type ON val_component_property_type;
CREATE TRIGGER trigger_audit_val_component_property_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_property_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_component_property_type();
DROP TRIGGER IF EXISTS trig_userlog_val_component_property_value ON val_component_property_value;
CREATE TRIGGER trig_userlog_val_component_property_value BEFORE INSERT OR UPDATE ON jazzhands.val_component_property_value FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_property_value ON val_component_property_value;
CREATE TRIGGER trigger_audit_val_component_property_value AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_property_value FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_component_property_value();
DROP TRIGGER IF EXISTS trig_userlog_val_contract_type ON val_contract_type;
CREATE TRIGGER trig_userlog_val_contract_type BEFORE INSERT OR UPDATE ON jazzhands.val_contract_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_contract_type ON val_contract_type;
CREATE TRIGGER trigger_audit_val_contract_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_contract_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_contract_type();
DROP TRIGGER IF EXISTS trig_userlog_val_country_code ON val_country_code;
CREATE TRIGGER trig_userlog_val_country_code BEFORE INSERT OR UPDATE ON jazzhands.val_country_code FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_country_code ON val_country_code;
CREATE TRIGGER trigger_audit_val_country_code AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_country_code FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_country_code();
DROP TRIGGER IF EXISTS trig_userlog_val_device_collection_type ON val_device_collection_type;
CREATE TRIGGER trig_userlog_val_device_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_device_collection_type ON val_device_collection_type;
CREATE TRIGGER trigger_audit_val_device_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_device_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_type_bytype_del ON val_device_collection_type;
CREATE TRIGGER trigger_manip_device_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_device_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_type_bytype_insup ON val_device_collection_type;
CREATE TRIGGER trigger_manip_device_collection_type_bytype_insup AFTER INSERT OR UPDATE OF device_collection_type ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_device_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_device_status ON val_device_status;
CREATE TRIGGER trig_userlog_val_device_status BEFORE INSERT OR UPDATE ON jazzhands.val_device_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_device_status ON val_device_status;
CREATE TRIGGER trigger_audit_val_device_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_device_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_device_status();
DROP TRIGGER IF EXISTS trig_userlog_val_diet ON val_diet;
CREATE TRIGGER trig_userlog_val_diet BEFORE INSERT OR UPDATE ON jazzhands.val_diet FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_diet ON val_diet;
CREATE TRIGGER trigger_audit_val_diet AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_diet FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_diet();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_class ON val_dns_class;
CREATE TRIGGER trig_userlog_val_dns_class BEFORE INSERT OR UPDATE ON jazzhands.val_dns_class FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_class ON val_dns_class;
CREATE TRIGGER trigger_audit_val_dns_class AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_class FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_class();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_domain_collection_type ON val_dns_domain_collection_type;
CREATE TRIGGER trig_userlog_val_dns_domain_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_domain_collection_type ON val_dns_domain_collection_type;
CREATE TRIGGER trigger_audit_val_dns_domain_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_domain_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_type_bytype_del ON val_dns_domain_collection_type;
CREATE TRIGGER trigger_manip_dns_domain_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_dns_domain_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_type_bytype_insup ON val_dns_domain_collection_type;
CREATE TRIGGER trigger_manip_dns_domain_collection_type_bytype_insup AFTER INSERT OR UPDATE OF dns_domain_collection_type ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_dns_domain_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_domain_type ON val_dns_domain_type;
CREATE TRIGGER trig_userlog_val_dns_domain_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_domain_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_domain_type ON val_dns_domain_type;
CREATE TRIGGER trigger_audit_val_dns_domain_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_domain_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_domain_type();
DROP TRIGGER IF EXISTS trigger_dns_domain_type_should_generate ON val_dns_domain_type;
CREATE TRIGGER trigger_dns_domain_type_should_generate AFTER UPDATE OF can_generate ON jazzhands.val_dns_domain_type FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_type_should_generate();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_record_relation_type ON val_dns_record_relation_type;
CREATE TRIGGER trig_userlog_val_dns_record_relation_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_record_relation_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_record_relation_type ON val_dns_record_relation_type;
CREATE TRIGGER trigger_audit_val_dns_record_relation_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_record_relation_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_record_relation_type();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_srv_service ON val_dns_srv_service;
CREATE TRIGGER trig_userlog_val_dns_srv_service BEFORE INSERT OR UPDATE ON jazzhands.val_dns_srv_service FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_srv_service ON val_dns_srv_service;
CREATE TRIGGER trigger_audit_val_dns_srv_service AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_srv_service FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_srv_service();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_type ON val_dns_type;
CREATE TRIGGER trig_userlog_val_dns_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_type ON val_dns_type;
CREATE TRIGGER trigger_audit_val_dns_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_type();
DROP TRIGGER IF EXISTS trig_userlog_val_encapsulation_mode ON val_encapsulation_mode;
CREATE TRIGGER trig_userlog_val_encapsulation_mode BEFORE INSERT OR UPDATE ON jazzhands.val_encapsulation_mode FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_encapsulation_mode ON val_encapsulation_mode;
CREATE TRIGGER trigger_audit_val_encapsulation_mode AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_encapsulation_mode FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_encapsulation_mode();
DROP TRIGGER IF EXISTS trig_userlog_val_encapsulation_type ON val_encapsulation_type;
CREATE TRIGGER trig_userlog_val_encapsulation_type BEFORE INSERT OR UPDATE ON jazzhands.val_encapsulation_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_encapsulation_type ON val_encapsulation_type;
CREATE TRIGGER trigger_audit_val_encapsulation_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_encapsulation_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_encapsulation_type();
DROP TRIGGER IF EXISTS trig_userlog_val_encryption_key_purpose ON val_encryption_key_purpose;
CREATE TRIGGER trig_userlog_val_encryption_key_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_encryption_key_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_encryption_key_purpose ON val_encryption_key_purpose;
CREATE TRIGGER trigger_audit_val_encryption_key_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_encryption_key_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_encryption_key_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_gender ON val_gender;
CREATE TRIGGER trig_userlog_val_gender BEFORE INSERT OR UPDATE ON jazzhands.val_gender FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_gender ON val_gender;
CREATE TRIGGER trigger_audit_val_gender AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_gender FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_gender();
DROP TRIGGER IF EXISTS trig_userlog_val_image_type ON val_image_type;
CREATE TRIGGER trig_userlog_val_image_type BEFORE INSERT OR UPDATE ON jazzhands.val_image_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_image_type ON val_image_type;
CREATE TRIGGER trigger_audit_val_image_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_image_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_image_type();
DROP TRIGGER IF EXISTS trig_userlog_val_ip_namespace ON val_ip_namespace;
CREATE TRIGGER trig_userlog_val_ip_namespace BEFORE INSERT OR UPDATE ON jazzhands.val_ip_namespace FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_ip_namespace ON val_ip_namespace;
CREATE TRIGGER trigger_audit_val_ip_namespace AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_ip_namespace FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_ip_namespace();
DROP TRIGGER IF EXISTS trig_userlog_val_iso_currency_code ON val_iso_currency_code;
CREATE TRIGGER trig_userlog_val_iso_currency_code BEFORE INSERT OR UPDATE ON jazzhands.val_iso_currency_code FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_iso_currency_code ON val_iso_currency_code;
CREATE TRIGGER trigger_audit_val_iso_currency_code AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_iso_currency_code FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_iso_currency_code();
DROP TRIGGER IF EXISTS trig_userlog_val_key_usage_reason_for_assignment ON val_key_usage_reason_for_assignment;
CREATE TRIGGER trig_userlog_val_key_usage_reason_for_assignment BEFORE INSERT OR UPDATE ON jazzhands.val_key_usage_reason_for_assignment FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_key_usage_reason_for_assignment ON val_key_usage_reason_for_assignment;
CREATE TRIGGER trigger_audit_val_key_usage_reason_for_assignment AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_key_usage_reason_for_assignment FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_key_usage_reason_for_assignment();
DROP TRIGGER IF EXISTS trig_userlog_val_layer2_network_collection_type ON val_layer2_network_collection_type;
CREATE TRIGGER trig_userlog_val_layer2_network_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer2_network_collection_type ON val_layer2_network_collection_type;
CREATE TRIGGER trigger_audit_val_layer2_network_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_layer2_network_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_type_bytype_del ON val_layer2_network_collection_type;
CREATE TRIGGER trigger_manip_layer2_network_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer2_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_type_bytype_insup ON val_layer2_network_collection_type;
CREATE TRIGGER trigger_manip_layer2_network_collection_type_bytype_insup AFTER INSERT OR UPDATE OF layer2_network_collection_type ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer2_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_acl_group_type ON val_layer3_acl_group_type;
CREATE TRIGGER trig_userlog_val_layer3_acl_group_type BEFORE INSERT OR UPDATE ON jazzhands.val_layer3_acl_group_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_acl_group_type ON val_layer3_acl_group_type;
CREATE TRIGGER trigger_audit_val_layer3_acl_group_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer3_acl_group_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_layer3_acl_group_type();
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_interface_purpose ON val_layer3_interface_purpose;
CREATE TRIGGER trig_userlog_val_layer3_interface_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_layer3_interface_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_interface_purpose ON val_layer3_interface_purpose;
CREATE TRIGGER trigger_audit_val_layer3_interface_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer3_interface_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_layer3_interface_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_interface_type ON val_layer3_interface_type;
CREATE TRIGGER trig_userlog_val_layer3_interface_type BEFORE INSERT OR UPDATE ON jazzhands.val_layer3_interface_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_interface_type ON val_layer3_interface_type;
CREATE TRIGGER trigger_audit_val_layer3_interface_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer3_interface_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_layer3_interface_type();
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_network_collection_type ON val_layer3_network_collection_type;
CREATE TRIGGER trig_userlog_val_layer3_network_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_network_collection_type ON val_layer3_network_collection_type;
CREATE TRIGGER trigger_audit_val_layer3_network_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_layer3_network_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_type_bytype_del ON val_layer3_network_collection_type;
CREATE TRIGGER trigger_manip_layer3_network_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer3_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_type_bytype_insup ON val_layer3_network_collection_type;
CREATE TRIGGER trigger_manip_layer3_network_collection_type_bytype_insup AFTER INSERT OR UPDATE OF layer3_network_collection_type ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer3_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_port_type ON val_logical_port_type;
CREATE TRIGGER trig_userlog_val_logical_port_type BEFORE INSERT OR UPDATE ON jazzhands.val_logical_port_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_port_type ON val_logical_port_type;
CREATE TRIGGER trigger_audit_val_logical_port_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_port_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_logical_port_type();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_volume_property ON val_logical_volume_property;
CREATE TRIGGER trig_userlog_val_logical_volume_property BEFORE INSERT OR UPDATE ON jazzhands.val_logical_volume_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_volume_property ON val_logical_volume_property;
CREATE TRIGGER trigger_audit_val_logical_volume_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_volume_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_logical_volume_property();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_volume_purpose ON val_logical_volume_purpose;
CREATE TRIGGER trig_userlog_val_logical_volume_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_logical_volume_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_volume_purpose ON val_logical_volume_purpose;
CREATE TRIGGER trigger_audit_val_logical_volume_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_volume_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_logical_volume_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_volume_type ON val_logical_volume_type;
CREATE TRIGGER trig_userlog_val_logical_volume_type BEFORE INSERT OR UPDATE ON jazzhands.val_logical_volume_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_volume_type ON val_logical_volume_type;
CREATE TRIGGER trigger_audit_val_logical_volume_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_volume_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_logical_volume_type();
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_collection_type ON val_netblock_collection_type;
CREATE TRIGGER trig_userlog_val_netblock_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_collection_type ON val_netblock_collection_type;
CREATE TRIGGER trigger_audit_val_netblock_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_netblock_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_type_bytype_del ON val_netblock_collection_type;
CREATE TRIGGER trigger_manip_netblock_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_netblock_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_type_bytype_insup ON val_netblock_collection_type;
CREATE TRIGGER trigger_manip_netblock_collection_type_bytype_insup AFTER INSERT OR UPDATE OF netblock_collection_type ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_netblock_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_status ON val_netblock_status;
CREATE TRIGGER trig_userlog_val_netblock_status BEFORE INSERT OR UPDATE ON jazzhands.val_netblock_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_status ON val_netblock_status;
CREATE TRIGGER trigger_audit_val_netblock_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_netblock_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_netblock_status();
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_type ON val_netblock_type;
CREATE TRIGGER trig_userlog_val_netblock_type BEFORE INSERT OR UPDATE ON jazzhands.val_netblock_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_type ON val_netblock_type;
CREATE TRIGGER trigger_audit_val_netblock_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_netblock_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_netblock_type();
DROP TRIGGER IF EXISTS trig_userlog_val_network_range_type ON val_network_range_type;
CREATE TRIGGER trig_userlog_val_network_range_type BEFORE INSERT OR UPDATE ON jazzhands.val_network_range_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_network_range_type ON val_network_range_type;
CREATE TRIGGER trigger_audit_val_network_range_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_network_range_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_network_range_type();
DROP TRIGGER IF EXISTS trigger_validate_net_range_toggle_nonoverlap ON val_network_range_type;
CREATE CONSTRAINT TRIGGER trigger_validate_net_range_toggle_nonoverlap AFTER UPDATE OF can_overlap, require_cidr_boundary ON jazzhands.val_network_range_type DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_net_range_toggle_nonoverlap();
DROP TRIGGER IF EXISTS trigger_validate_val_network_range_type ON val_network_range_type;
CREATE CONSTRAINT TRIGGER trigger_validate_val_network_range_type AFTER UPDATE OF dns_domain_required, netblock_type ON jazzhands.val_network_range_type DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_val_network_range_type();
DROP TRIGGER IF EXISTS trig_userlog_val_network_service_type ON val_network_service_type;
CREATE TRIGGER trig_userlog_val_network_service_type BEFORE INSERT OR UPDATE ON jazzhands.val_network_service_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_network_service_type ON val_network_service_type;
CREATE TRIGGER trigger_audit_val_network_service_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_network_service_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_network_service_type();
DROP TRIGGER IF EXISTS trig_userlog_val_operating_system_family ON val_operating_system_family;
CREATE TRIGGER trig_userlog_val_operating_system_family BEFORE INSERT OR UPDATE ON jazzhands.val_operating_system_family FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_operating_system_family ON val_operating_system_family;
CREATE TRIGGER trigger_audit_val_operating_system_family AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_operating_system_family FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_operating_system_family();
DROP TRIGGER IF EXISTS trig_userlog_val_operating_system_snapshot_type ON val_operating_system_snapshot_type;
CREATE TRIGGER trig_userlog_val_operating_system_snapshot_type BEFORE INSERT OR UPDATE ON jazzhands.val_operating_system_snapshot_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_operating_system_snapshot_type ON val_operating_system_snapshot_type;
CREATE TRIGGER trigger_audit_val_operating_system_snapshot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_operating_system_snapshot_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_operating_system_snapshot_type();
DROP TRIGGER IF EXISTS trig_userlog_val_ownership_status ON val_ownership_status;
CREATE TRIGGER trig_userlog_val_ownership_status BEFORE INSERT OR UPDATE ON jazzhands.val_ownership_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_ownership_status ON val_ownership_status;
CREATE TRIGGER trigger_audit_val_ownership_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_ownership_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_ownership_status();
DROP TRIGGER IF EXISTS trig_userlog_val_password_type ON val_password_type;
CREATE TRIGGER trig_userlog_val_password_type BEFORE INSERT OR UPDATE ON jazzhands.val_password_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_password_type ON val_password_type;
CREATE TRIGGER trigger_audit_val_password_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_password_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_password_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_attribute_data_type ON val_person_company_attribute_data_type;
CREATE TRIGGER trig_userlog_val_person_company_attribute_data_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_attribute_data_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_attribute_data_type ON val_person_company_attribute_data_type;
CREATE TRIGGER trigger_audit_val_person_company_attribute_data_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_attribute_data_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_company_attribute_data_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_attribute_name ON val_person_company_attribute_name;
CREATE TRIGGER trig_userlog_val_person_company_attribute_name BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_attribute_name FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_attribute_name ON val_person_company_attribute_name;
CREATE TRIGGER trigger_audit_val_person_company_attribute_name AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_attribute_name FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_company_attribute_name();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_attribute_value ON val_person_company_attribute_value;
CREATE TRIGGER trig_userlog_val_person_company_attribute_value BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_attribute_value ON val_person_company_attribute_value;
CREATE TRIGGER trigger_audit_val_person_company_attribute_value AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_company_attribute_value();
DROP TRIGGER IF EXISTS trigger_person_company_attribute_change_after_row_hooks ON val_person_company_attribute_value;
CREATE TRIGGER trigger_person_company_attribute_change_after_row_hooks AFTER INSERT OR UPDATE ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE FUNCTION jazzhands.person_company_attribute_change_after_row_hooks();
DROP TRIGGER IF EXISTS trigger_validate_pers_comp_attr_value ON val_person_company_attribute_value;
CREATE TRIGGER trigger_validate_pers_comp_attr_value BEFORE DELETE OR UPDATE OF person_company_attribute_name, person_company_attribute_value ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_pers_comp_attr_value();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_relation ON val_person_company_relation;
CREATE TRIGGER trig_userlog_val_person_company_relation BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_relation ON val_person_company_relation;
CREATE TRIGGER trigger_audit_val_person_company_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_company_relation();
DROP TRIGGER IF EXISTS trig_userlog_val_person_contact_location_type ON val_person_contact_location_type;
CREATE TRIGGER trig_userlog_val_person_contact_location_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_contact_location_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_contact_location_type ON val_person_contact_location_type;
CREATE TRIGGER trigger_audit_val_person_contact_location_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_contact_location_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_contact_location_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_contact_technology ON val_person_contact_technology;
CREATE TRIGGER trig_userlog_val_person_contact_technology BEFORE INSERT OR UPDATE ON jazzhands.val_person_contact_technology FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_contact_technology ON val_person_contact_technology;
CREATE TRIGGER trigger_audit_val_person_contact_technology AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_contact_technology FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_contact_technology();
DROP TRIGGER IF EXISTS trig_userlog_val_person_contact_type ON val_person_contact_type;
CREATE TRIGGER trig_userlog_val_person_contact_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_contact_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_contact_type ON val_person_contact_type;
CREATE TRIGGER trigger_audit_val_person_contact_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_contact_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_contact_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_image_usage ON val_person_image_usage;
CREATE TRIGGER trig_userlog_val_person_image_usage BEFORE INSERT OR UPDATE ON jazzhands.val_person_image_usage FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_image_usage ON val_person_image_usage;
CREATE TRIGGER trigger_audit_val_person_image_usage AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_image_usage FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_image_usage();
DROP TRIGGER IF EXISTS trig_userlog_val_person_location_type ON val_person_location_type;
CREATE TRIGGER trig_userlog_val_person_location_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_location_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_location_type ON val_person_location_type;
CREATE TRIGGER trigger_audit_val_person_location_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_location_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_location_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_status ON val_person_status;
CREATE TRIGGER trig_userlog_val_person_status BEFORE INSERT OR UPDATE ON jazzhands.val_person_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_status ON val_person_status;
CREATE TRIGGER trigger_audit_val_person_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_status();
DROP TRIGGER IF EXISTS trig_userlog_val_physical_address_type ON val_physical_address_type;
CREATE TRIGGER trig_userlog_val_physical_address_type BEFORE INSERT OR UPDATE ON jazzhands.val_physical_address_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_physical_address_type ON val_physical_address_type;
CREATE TRIGGER trigger_audit_val_physical_address_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_physical_address_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_physical_address_type();
DROP TRIGGER IF EXISTS trig_userlog_val_port_range_type ON val_port_range_type;
CREATE TRIGGER trig_userlog_val_port_range_type BEFORE INSERT OR UPDATE ON jazzhands.val_port_range_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_port_range_type ON val_port_range_type;
CREATE TRIGGER trigger_audit_val_port_range_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_port_range_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_port_range_type();
DROP TRIGGER IF EXISTS trigger_val_port_range_sanity_check ON val_port_range_type;
CREATE CONSTRAINT TRIGGER trigger_val_port_range_sanity_check AFTER UPDATE OF range_permitted ON jazzhands.val_port_range_type NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.val_port_range_sanity_check();
DROP TRIGGER IF EXISTS trig_userlog_val_private_key_encryption_type ON val_private_key_encryption_type;
CREATE TRIGGER trig_userlog_val_private_key_encryption_type BEFORE INSERT OR UPDATE ON jazzhands.val_private_key_encryption_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_private_key_encryption_type ON val_private_key_encryption_type;
CREATE TRIGGER trigger_audit_val_private_key_encryption_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_private_key_encryption_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_private_key_encryption_type();
DROP TRIGGER IF EXISTS trig_userlog_val_processor_architecture ON val_processor_architecture;
CREATE TRIGGER trig_userlog_val_processor_architecture BEFORE INSERT OR UPDATE ON jazzhands.val_processor_architecture FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_processor_architecture ON val_processor_architecture;
CREATE TRIGGER trigger_audit_val_processor_architecture AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_processor_architecture FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_processor_architecture();
DROP TRIGGER IF EXISTS trig_userlog_val_production_state ON val_production_state;
CREATE TRIGGER trig_userlog_val_production_state BEFORE INSERT OR UPDATE ON jazzhands.val_production_state FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_production_state ON val_production_state;
CREATE TRIGGER trigger_audit_val_production_state AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_production_state FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_production_state();
DROP TRIGGER IF EXISTS trig_userlog_val_property ON val_property;
CREATE TRIGGER trig_userlog_val_property BEFORE INSERT OR UPDATE ON jazzhands.val_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property ON val_property;
CREATE TRIGGER trigger_audit_val_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_property();
DROP TRIGGER IF EXISTS trigger_validate_val_property ON val_property;
CREATE TRIGGER trigger_validate_val_property BEFORE INSERT OR UPDATE OF property_data_type, property_value_json_schema, permit_company_id ON jazzhands.val_property FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_val_property();
DROP TRIGGER IF EXISTS trigger_validate_val_property_after ON val_property;
CREATE CONSTRAINT TRIGGER trigger_validate_val_property_after AFTER UPDATE ON jazzhands.val_property DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_val_property_after();
DROP TRIGGER IF EXISTS trig_userlog_val_property_data_type ON val_property_data_type;
CREATE TRIGGER trig_userlog_val_property_data_type BEFORE INSERT OR UPDATE ON jazzhands.val_property_data_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_data_type ON val_property_data_type;
CREATE TRIGGER trigger_audit_val_property_data_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_data_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_property_data_type();
DROP TRIGGER IF EXISTS trig_userlog_val_property_name_collection_type ON val_property_name_collection_type;
CREATE TRIGGER trig_userlog_val_property_name_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_property_name_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_name_collection_type ON val_property_name_collection_type;
CREATE TRIGGER trigger_audit_val_property_name_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_name_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_property_name_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_property_type ON val_property_type;
CREATE TRIGGER trig_userlog_val_property_type BEFORE INSERT OR UPDATE ON jazzhands.val_property_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_type ON val_property_type;
CREATE TRIGGER trigger_audit_val_property_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_property_type();
DROP TRIGGER IF EXISTS trig_userlog_val_property_value ON val_property_value;
CREATE TRIGGER trig_userlog_val_property_value BEFORE INSERT OR UPDATE ON jazzhands.val_property_value FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_value ON val_property_value;
CREATE TRIGGER trigger_audit_val_property_value AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_value FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_property_value();
DROP TRIGGER IF EXISTS trigger_val_property_value_del_check ON val_property_value;
CREATE CONSTRAINT TRIGGER trigger_val_property_value_del_check AFTER DELETE ON jazzhands.val_property_value DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.val_property_value_del_check();
DROP TRIGGER IF EXISTS trig_userlog_val_rack_type ON val_rack_type;
CREATE TRIGGER trig_userlog_val_rack_type BEFORE INSERT OR UPDATE ON jazzhands.val_rack_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_rack_type ON val_rack_type;
CREATE TRIGGER trigger_audit_val_rack_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_rack_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_rack_type();
DROP TRIGGER IF EXISTS trig_userlog_val_raid_type ON val_raid_type;
CREATE TRIGGER trig_userlog_val_raid_type BEFORE INSERT OR UPDATE ON jazzhands.val_raid_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_raid_type ON val_raid_type;
CREATE TRIGGER trigger_audit_val_raid_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_raid_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_raid_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_affinity ON val_service_affinity;
CREATE TRIGGER trig_userlog_val_service_affinity BEFORE INSERT OR UPDATE ON jazzhands.val_service_affinity FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_affinity ON val_service_affinity;
CREATE TRIGGER trigger_audit_val_service_affinity AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_affinity FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_affinity();
DROP TRIGGER IF EXISTS trig_userlog_val_service_endpoint_provider_collection_type ON val_service_endpoint_provider_collection_type;
CREATE TRIGGER trig_userlog_val_service_endpoint_provider_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_endpoint_provider_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_endpoint_provider_collection_type ON val_service_endpoint_provider_collection_type;
CREATE TRIGGER trigger_audit_val_service_endpoint_provider_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_endpoint_provider_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_endpoint_provider_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_endpoint_provider_type ON val_service_endpoint_provider_type;
CREATE TRIGGER trig_userlog_val_service_endpoint_provider_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_endpoint_provider_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_endpoint_provider_type ON val_service_endpoint_provider_type;
CREATE TRIGGER trigger_audit_val_service_endpoint_provider_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_endpoint_provider_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_endpoint_provider_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_environment_collection_type ON val_service_environment_collection_type;
CREATE TRIGGER trig_userlog_val_service_environment_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_environment_collection_type ON val_service_environment_collection_type;
CREATE TRIGGER trigger_audit_val_service_environment_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_environment_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_type_bytype_del ON val_service_environment_collection_type;
CREATE TRIGGER trigger_manip_service_environment_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_service_environment_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_type_bytype_insup ON val_service_environment_collection_type;
CREATE TRIGGER trigger_manip_service_environment_collection_type_bytype_insup AFTER INSERT OR UPDATE OF service_environment_collection_type ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_service_environment_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_service_environment_type ON val_service_environment_type;
CREATE TRIGGER trig_userlog_val_service_environment_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_environment_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_environment_type ON val_service_environment_type;
CREATE TRIGGER trigger_audit_val_service_environment_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_environment_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_environment_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_feature ON val_service_feature;
CREATE TRIGGER trig_userlog_val_service_feature BEFORE INSERT OR UPDATE ON jazzhands.val_service_feature FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_feature ON val_service_feature;
CREATE TRIGGER trigger_audit_val_service_feature AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_feature FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_feature();
DROP TRIGGER IF EXISTS trig_userlog_val_service_namespace ON val_service_namespace;
CREATE TRIGGER trig_userlog_val_service_namespace BEFORE INSERT OR UPDATE ON jazzhands.val_service_namespace FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_namespace ON val_service_namespace;
CREATE TRIGGER trigger_audit_val_service_namespace AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_namespace FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_namespace();
DROP TRIGGER IF EXISTS trig_userlog_val_service_relationship_type ON val_service_relationship_type;
CREATE TRIGGER trig_userlog_val_service_relationship_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_relationship_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_relationship_type ON val_service_relationship_type;
CREATE TRIGGER trigger_audit_val_service_relationship_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_relationship_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_relationship_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_source_control_purpose ON val_service_source_control_purpose;
CREATE TRIGGER trig_userlog_val_service_source_control_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_service_source_control_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_source_control_purpose ON val_service_source_control_purpose;
CREATE TRIGGER trigger_audit_val_service_source_control_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_source_control_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_source_control_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_service_type ON val_service_type;
CREATE TRIGGER trig_userlog_val_service_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_type ON val_service_type;
CREATE TRIGGER trigger_audit_val_service_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_type();
DROP TRIGGER IF EXISTS trigger_check_service_type_namespace ON val_service_type;
CREATE CONSTRAINT TRIGGER trigger_check_service_type_namespace AFTER UPDATE OF service_namespace ON jazzhands.val_service_type NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_service_type_namespace();
DROP TRIGGER IF EXISTS trigger_check_service_type_relation_regexp_change ON val_service_type;
CREATE CONSTRAINT TRIGGER trigger_check_service_type_relation_regexp_change AFTER UPDATE OF service_version_restriction_regular_expression ON jazzhands.val_service_type NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_service_type_relation_regexp_change();
DROP TRIGGER IF EXISTS trig_userlog_val_service_version_collection_type ON val_service_version_collection_type;
CREATE TRIGGER trig_userlog_val_service_version_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_version_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_version_collection_type ON val_service_version_collection_type;
CREATE TRIGGER trigger_audit_val_service_version_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_version_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_version_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_shared_netblock_protocol ON val_shared_netblock_protocol;
CREATE TRIGGER trig_userlog_val_shared_netblock_protocol BEFORE INSERT OR UPDATE ON jazzhands.val_shared_netblock_protocol FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_shared_netblock_protocol ON val_shared_netblock_protocol;
CREATE TRIGGER trigger_audit_val_shared_netblock_protocol AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_shared_netblock_protocol FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_shared_netblock_protocol();
DROP TRIGGER IF EXISTS trig_userlog_val_slot_function ON val_slot_function;
CREATE TRIGGER trig_userlog_val_slot_function BEFORE INSERT OR UPDATE ON jazzhands.val_slot_function FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_slot_function ON val_slot_function;
CREATE TRIGGER trigger_audit_val_slot_function AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_slot_function FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_slot_function();
DROP TRIGGER IF EXISTS trig_userlog_val_slot_physical_interface ON val_slot_physical_interface;
CREATE TRIGGER trig_userlog_val_slot_physical_interface BEFORE INSERT OR UPDATE ON jazzhands.val_slot_physical_interface FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_slot_physical_interface ON val_slot_physical_interface;
CREATE TRIGGER trigger_audit_val_slot_physical_interface AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_slot_physical_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_slot_physical_interface();
DROP TRIGGER IF EXISTS trig_userlog_val_software_artifact_relationship ON val_software_artifact_relationship;
CREATE TRIGGER trig_userlog_val_software_artifact_relationship BEFORE INSERT OR UPDATE ON jazzhands.val_software_artifact_relationship FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_software_artifact_relationship ON val_software_artifact_relationship;
CREATE TRIGGER trigger_audit_val_software_artifact_relationship AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_software_artifact_relationship FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_software_artifact_relationship();
DROP TRIGGER IF EXISTS trig_userlog_val_software_artifact_repository_uri_type ON val_software_artifact_repository_uri_type;
CREATE TRIGGER trig_userlog_val_software_artifact_repository_uri_type BEFORE INSERT OR UPDATE ON jazzhands.val_software_artifact_repository_uri_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_software_artifact_repository_uri_type ON val_software_artifact_repository_uri_type;
CREATE TRIGGER trigger_audit_val_software_artifact_repository_uri_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_software_artifact_repository_uri_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_software_artifact_repository_uri_type();
DROP TRIGGER IF EXISTS trig_userlog_val_software_artifact_type ON val_software_artifact_type;
CREATE TRIGGER trig_userlog_val_software_artifact_type BEFORE INSERT OR UPDATE ON jazzhands.val_software_artifact_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_software_artifact_type ON val_software_artifact_type;
CREATE TRIGGER trigger_audit_val_software_artifact_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_software_artifact_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_software_artifact_type();
DROP TRIGGER IF EXISTS trig_userlog_val_source_repository_method ON val_source_repository_method;
CREATE TRIGGER trig_userlog_val_source_repository_method BEFORE INSERT OR UPDATE ON jazzhands.val_source_repository_method FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_source_repository_method ON val_source_repository_method;
CREATE TRIGGER trigger_audit_val_source_repository_method AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_source_repository_method FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_source_repository_method();
DROP TRIGGER IF EXISTS trig_userlog_val_source_repository_protocol ON val_source_repository_protocol;
CREATE TRIGGER trig_userlog_val_source_repository_protocol BEFORE INSERT OR UPDATE ON jazzhands.val_source_repository_protocol FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_source_repository_protocol ON val_source_repository_protocol;
CREATE TRIGGER trigger_audit_val_source_repository_protocol AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_source_repository_protocol FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_source_repository_protocol();
DROP TRIGGER IF EXISTS trig_userlog_val_source_repository_uri_purpose ON val_source_repository_uri_purpose;
CREATE TRIGGER trig_userlog_val_source_repository_uri_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_source_repository_uri_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_source_repository_uri_purpose ON val_source_repository_uri_purpose;
CREATE TRIGGER trigger_audit_val_source_repository_uri_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_source_repository_uri_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_source_repository_uri_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_ssh_key_type ON val_ssh_key_type;
CREATE TRIGGER trig_userlog_val_ssh_key_type BEFORE INSERT OR UPDATE ON jazzhands.val_ssh_key_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_ssh_key_type ON val_ssh_key_type;
CREATE TRIGGER trigger_audit_val_ssh_key_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_ssh_key_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_ssh_key_type();
DROP TRIGGER IF EXISTS trig_userlog_val_token_collection_type ON val_token_collection_type;
CREATE TRIGGER trig_userlog_val_token_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_token_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_token_collection_type ON val_token_collection_type;
CREATE TRIGGER trigger_audit_val_token_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_token_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_token_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_token_status ON val_token_status;
CREATE TRIGGER trig_userlog_val_token_status BEFORE INSERT OR UPDATE ON jazzhands.val_token_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_token_status ON val_token_status;
CREATE TRIGGER trigger_audit_val_token_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_token_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_token_status();
DROP TRIGGER IF EXISTS trig_userlog_val_token_type ON val_token_type;
CREATE TRIGGER trig_userlog_val_token_type BEFORE INSERT OR UPDATE ON jazzhands.val_token_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_token_type ON val_token_type;
CREATE TRIGGER trigger_audit_val_token_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_token_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_token_type();
DROP TRIGGER IF EXISTS trig_userlog_val_volume_group_purpose ON val_volume_group_purpose;
CREATE TRIGGER trig_userlog_val_volume_group_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_volume_group_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_volume_group_purpose ON val_volume_group_purpose;
CREATE TRIGGER trigger_audit_val_volume_group_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_volume_group_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_volume_group_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_volume_group_relation ON val_volume_group_relation;
CREATE TRIGGER trig_userlog_val_volume_group_relation BEFORE INSERT OR UPDATE ON jazzhands.val_volume_group_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_volume_group_relation ON val_volume_group_relation;
CREATE TRIGGER trigger_audit_val_volume_group_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_volume_group_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_volume_group_relation();
DROP TRIGGER IF EXISTS trig_userlog_val_volume_group_type ON val_volume_group_type;
CREATE TRIGGER trig_userlog_val_volume_group_type BEFORE INSERT OR UPDATE ON jazzhands.val_volume_group_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_volume_group_type ON val_volume_group_type;
CREATE TRIGGER trigger_audit_val_volume_group_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_volume_group_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_volume_group_type();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_certificate_file_format ON val_x509_certificate_file_format;
CREATE TRIGGER trig_userlog_val_x509_certificate_file_format BEFORE INSERT OR UPDATE ON jazzhands.val_x509_certificate_file_format FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_certificate_file_format ON val_x509_certificate_file_format;
CREATE TRIGGER trigger_audit_val_x509_certificate_file_format AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_certificate_file_format FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_certificate_file_format();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_certificate_type ON val_x509_certificate_type;
CREATE TRIGGER trig_userlog_val_x509_certificate_type BEFORE INSERT OR UPDATE ON jazzhands.val_x509_certificate_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_certificate_type ON val_x509_certificate_type;
CREATE TRIGGER trigger_audit_val_x509_certificate_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_certificate_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_certificate_type();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_key_usage ON val_x509_key_usage;
CREATE TRIGGER trig_userlog_val_x509_key_usage BEFORE INSERT OR UPDATE ON jazzhands.val_x509_key_usage FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_key_usage ON val_x509_key_usage;
CREATE TRIGGER trigger_audit_val_x509_key_usage AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_key_usage FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_key_usage();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_key_usage_category ON val_x509_key_usage_category;
CREATE TRIGGER trig_userlog_val_x509_key_usage_category BEFORE INSERT OR UPDATE ON jazzhands.val_x509_key_usage_category FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_key_usage_category ON val_x509_key_usage_category;
CREATE TRIGGER trigger_audit_val_x509_key_usage_category AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_key_usage_category FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_key_usage_category();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_revocation_reason ON val_x509_revocation_reason;
CREATE TRIGGER trig_userlog_val_x509_revocation_reason BEFORE INSERT OR UPDATE ON jazzhands.val_x509_revocation_reason FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_revocation_reason ON val_x509_revocation_reason;
CREATE TRIGGER trigger_audit_val_x509_revocation_reason AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_revocation_reason FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_revocation_reason();
DROP TRIGGER IF EXISTS trig_userlog_volume_group_purpose ON volume_group_purpose;
CREATE TRIGGER trig_userlog_volume_group_purpose BEFORE INSERT OR UPDATE ON jazzhands.volume_group_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_volume_group_purpose ON volume_group_purpose;
CREATE TRIGGER trigger_audit_volume_group_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.volume_group_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_volume_group_purpose();
DROP TRIGGER IF EXISTS trig_userlog_x509_key_usage_attribute ON x509_key_usage_attribute;
CREATE TRIGGER trig_userlog_x509_key_usage_attribute BEFORE INSERT OR UPDATE ON jazzhands.x509_key_usage_attribute FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_key_usage_attribute ON x509_key_usage_attribute;
CREATE TRIGGER trigger_audit_x509_key_usage_attribute AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_key_usage_attribute FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_x509_key_usage_attribute();
DROP TRIGGER IF EXISTS trig_userlog_x509_key_usage_categorization ON x509_key_usage_categorization;
CREATE TRIGGER trig_userlog_x509_key_usage_categorization BEFORE INSERT OR UPDATE ON jazzhands.x509_key_usage_categorization FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_key_usage_categorization ON x509_key_usage_categorization;
CREATE TRIGGER trigger_audit_x509_key_usage_categorization AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_key_usage_categorization FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_x509_key_usage_categorization();
DROP TRIGGER IF EXISTS trig_userlog_x509_key_usage_default ON x509_key_usage_default;
CREATE TRIGGER trig_userlog_x509_key_usage_default BEFORE INSERT OR UPDATE ON jazzhands.x509_key_usage_default FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_key_usage_default ON x509_key_usage_default;
CREATE TRIGGER trigger_audit_x509_key_usage_default AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_key_usage_default FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_x509_key_usage_default();
DROP TRIGGER IF EXISTS trig_userlog_x509_signed_certificate ON x509_signed_certificate;
CREATE TRIGGER trig_userlog_x509_signed_certificate BEFORE INSERT OR UPDATE ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_signed_certificate ON x509_signed_certificate;
CREATE TRIGGER trigger_audit_x509_signed_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_x509_signed_certificate();
DROP TRIGGER IF EXISTS trigger_x509_signed_delete_dangling_hashes ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_delete_dangling_hashes AFTER DELETE OR UPDATE OF public_key_hash_id ON jazzhands.x509_signed_certificate FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.delete_dangling_public_key_hashes();
DROP TRIGGER IF EXISTS trigger_x509_signed_set_fingerprints ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_set_fingerprints AFTER INSERT OR UPDATE OF public_key ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.set_x509_certificate_fingerprints();
DROP TRIGGER IF EXISTS trigger_x509_signed_set_private_key_id ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_set_private_key_id AFTER INSERT OR UPDATE OF public_key, public_key_hash_id ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.set_x509_certificate_private_key_id();
DROP TRIGGER IF EXISTS trigger_x509_signed_set_ski_and_hashes ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_set_ski_and_hashes BEFORE INSERT OR UPDATE OF public_key, public_key_hash_id, subject_key_identifier ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.set_x509_certificate_ski_and_hashes();

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
SAVEPOINT beforecache;
SELECT schema_support.synchronize_cache_tables();

--
-- END: Running final cache table sync
SAVEPOINT beforereset;
SELECT schema_support.reset_all_schema_table_sequences('jazzhands');
SELECT schema_support.reset_all_schema_table_sequences('jazzhands_audit');
SAVEPOINT beforegrant;


-- BEGIN final checks

UPDATE val_property
SET device_collection_type = 'JazzHandsLegacySupport-AutoMgmtProtocol',
	property_value_device_collection_type_restriction = NULL
WHERE property_name = 'AutoMgmtProtocol'
AND property_type = 'JazzHandsLegacySupport';

SELECT property_utils.validate_val_property(v)
FROM val_property v;

/* remove me
SELECT schema_support.rebuild_audit_indexes(
	aud_schema := 'jazzhands_audit',
	tbl_schema := 'jazzhands',
	table_name := 'layer3_interface'
);

*/

DO $X$
DECLARE
	_r	RECORD;
	tag	TEXT;
BEGIN
	tag := random()::text;
	FOR _r IN SELECT relname::text
		FROM	pg_class c
			JOIN pg_namespace n on c.relnamespace = n.oid
		WHERE	nspname = 'jazzhands_audit'
		AND	relkind = 'r'
		AND	c.oid NOT IN (
			SELECT attrelid
			FROM pg_attribute
			WHERE attname = 'aud#actor'
		)
	LOOP
		RAISE NOTICE 'Rebuilding %', _r.relname;
		PERFORM schema_support.save_dependent_objects_for_replay(
			schema := 'jazzhands_audit',
			object := _r.relname,
			tags := ARRAY[tag]
		);
		PERFORM schema_support.save_grants_for_replay(
			schema := 'jazzhands_audit',
			object := _r.relname,
			tags := ARRAY[tag]
		);

		PERFORM schema_support.rebuild_audit_table(
			aud_schema := 'jazzhands_audit',
			tbl_schema := 'jazzhands',
			table_name := _r.relname
		);

		PERFORM schema_support.replay_object_recreates(tags := ARRAY[tag]);
		PERFORM schema_support.replay_saved_grants(tags := ARRAY[tag]);
	END LOOP;
END;
$X$;

DROP TRIGGER IF EXISTS trigger_audit_token_sequence ON token_sequence;

SELECT schema_support.set_schema_version(
        version := '0.96',
        schema := 'jazzhands'
);


-- END final checks
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT insert,update,delete on all tables in schema jazzhands_legacy to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
GRANT select on all tables in schema jazzhands_audit to ro_role;
GRANT select on all sequences in schema jazzhands_audit to ro_role;
GRANT select on all tables in schema jazzhands_audit to ro_role;
GRANT select on all sequences in schema jazzhands_audit to ro_role;
-- schema_support changes.  schema_owners needs to be documented somewhere
GRANT execute on all functions in schema schema_support to schema_owners;
REVOKE execute on all functions in schema schema_support from public;

SELECT schema_support.end_maintenance();
SAVEPOINT maintend;
select clock_timestamp(), now(), clock_timestamp() - now() AS len;
