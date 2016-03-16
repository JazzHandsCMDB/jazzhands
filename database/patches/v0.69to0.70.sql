/*
Invoked:

	--suffix=v69
	--scan-tables
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();
CREATE SCHEMA account_collection_manip AUTHORIZATION jazzhands;
CREATE SCHEMA script_hooks AUTHORIZATION jazzhands;
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
SELECT schema_support.save_grants_for_replay('person_manip', 'change_company');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.change_company ( final_company_id integer, _person_id integer, initial_company_id integer, _account_realm_id integer );
CREATE OR REPLACE FUNCTION person_manip.change_company(final_company_id integer, _person_id integer, initial_company_id integer, _account_realm_id integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands, pg_temp
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
	set constraints fk_pers_comp_attr_person_comp_ DEFERRED;

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
	set constraints fk_pers_comp_attr_person_comp_ IMMEDIATE;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION person_manip.guess_person_id(first_name text, last_name text, login text, company_id integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands, pg_temp
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

--
-- Process middle (non-trigger) schema auto_ac_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'get_num_direct_reports');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.get_num_direct_reports ( account_id integer, account_realm_id integer );
CREATE OR REPLACE FUNCTION auto_ac_manip.get_num_direct_reports(account_id integer, account_realm_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_numrpt	INTEGER;
BEGIN
	-- get number of direct reports
	EXECUTE '
		WITH peeps AS (
			SELECT	account_realm_id, account_id, login, person_id, 
					manager_person_id
			FROM	account a
				INNER JOIN person_company USING (person_id, company_id)
			WHERE	account_role = $3
			AND		account_type = ''person''
			AND		person_company_relation = ''employee''
			AND		a.is_enabled = ''Y''
		) SELECT count(*)
		FROM peeps reports
			INNER JOIN peeps managers on  
				managers.person_id = reports.manager_person_id
			AND	managers.account_realm_id = reports.account_realm_id
		WHERE	managers.account_id = $1
		AND		managers.account_realm_id = $2
	' INTO _numrpt USING account_id, account_realm_id, 'primary';

	RETURN _numrpt;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'get_num_reports_with_reports');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.get_num_reports_with_reports ( account_id integer, account_realm_id integer );
CREATE OR REPLACE FUNCTION auto_ac_manip.get_num_reports_with_reports(account_id integer, account_realm_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_numrlup	INTEGER;
BEGIN
	EXECUTE '
		WITH peeps AS (
			SELECT	account_realm_id, account_id, login, person_id, 
					manager_person_id
			FROM	account a
				INNER JOIN person_company USING (person_id, company_id)
			WHERE	account_role = $3
			AND		account_type = ''person''
			AND		person_company_relation = ''employee''
			AND		account_realm_id = $2
			AND		a.is_enabled = ''Y''
		), agg AS ( SELECT reports.*, managers.account_id as manager_account_id,
				managers.login as manager_login, p.property_name,
				p.property_value_account_coll_id as account_collection_id
			FROM peeps reports
			INNER JOIN peeps managers
				ON managers.person_id = reports.manager_person_id
				AND	managers.account_realm_id = reports.account_realm_id
			INNER JOIN property p 
				ON p.account_id = reports.account_id
				AND p.account_realm_id = reports.account_realm_id
				AND p.property_name IN ($4,$5)
				AND p.property_type = $6
		), rank AS (
			SELECT *,
				rank() OVER (partition by account_id ORDER BY property_name desc)
					as rank
			FROM agg
		) SELECT count(*) from rank
		WHERE	manager_account_id =  $1
		AND 	account_realm_id = $2
		AND	rank = 1;
	' INTO _numrlup USING account_id, account_realm_id, 'primary',
				'AutomatedDirectsAC','AutomatedRollupsAC','auto_acct_coll';

	RETURN _numrlup;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'populate_direct_report_ac');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.populate_direct_report_ac ( account_id integer, account_realm_id integer, login character varying );
CREATE OR REPLACE FUNCTION auto_ac_manip.populate_direct_report_ac(account_id integer, account_realm_id integer DEFAULT NULL::integer, login character varying DEFAULT NULL::character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_directac	account_collection.account_collection_id%TYPE;
BEGIN
	_directac := auto_ac_manip.find_or_create_automated_ac(
		account_id := account_id,
		account_realm_id := account_realm_id,
		ac_type := 'AutomatedDirectsAC'
	);

	--
	-- Make membership right
	--
	EXECUTE '
		WITH peeps AS (
			SELECT	account_realm_id, account_id, login, person_id, 
					manager_person_id
			FROM	account a
				INNER JOIN person_company USING (person_id, company_id)
			WHERE	account_role = $2
			AND		account_type = ''person''
			AND		person_company_relation = ''employee''
			AND		a.is_enabled = ''Y''
		), arethere AS (
			SELECT account_collection_id, account_id FROM
				account_collection_account
				WHERE account_collection_id = $3
		), shouldbethere AS (
			SELECT $3 as account_collection_id, reports.account_id
			FROM peeps reports
				INNER JOIN peeps managers on  
					managers.person_id = reports.manager_person_id
				AND	managers.account_realm_id = reports.account_realm_id
			WHERE	managers.account_id =  $1
			UNION SELECT $3, $1
		), ins AS (
			INSERT INTO account_collection_account 
				(account_collection_id, account_id)
			SELECT account_collection_id, account_id 
			FROM shouldbethere
			WHERE (account_collection_id, account_id)
				NOT IN (select account_collection_id, account_id FROM arethere)
			RETURNING *
		), del AS (
			DELETE FROM account_collection_account
			WHERE (account_collection_id, account_id)
			IN (
				SELECT account_collection_id, account_id 
				FROM arethere
			) AND (account_collection_id, account_id) NOT IN (
				SELECT account_collection_id, account_id 
				FROM shouldbethere
			) RETURNING *
		) SELECT * from ins UNION SELECT * from del
		'USING account_id, 'primary', _directac;

	RETURN _directac;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'populate_rollup_report_ac');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.populate_rollup_report_ac ( account_id integer, account_realm_id integer, login character varying );
CREATE OR REPLACE FUNCTION auto_ac_manip.populate_rollup_report_ac(account_id integer, account_realm_id integer DEFAULT NULL::integer, login character varying DEFAULT NULL::character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_rollupac	account_collection.account_collection_id%TYPE;
BEGIN
	_rollupac := auto_ac_manip.find_or_create_automated_ac(
		account_id := account_id,
		account_realm_id := account_realm_id,
		ac_type := 'AutomatedRollupsAC'
	);

	EXECUTE '
		WITH peeps AS (
			SELECT	account_realm_id, account_id, login, person_id, 
					manager_person_id
			FROM	account a
				INNER JOIN person_company USING (person_id, company_id)
			WHERE	account_role = $2
			AND		account_type = ''person''
			AND		person_company_relation = ''employee''
			AND		a.is_enabled = ''Y''
		), agg AS ( SELECT reports.*, managers.account_id as manager_account_id,
				managers.login as manager_login, p.property_name,
				p.property_value_account_coll_id as account_collection_id
			FROM peeps reports
			INNER JOIN peeps managers
				ON managers.person_id = reports.manager_person_id
				AND	managers.account_realm_id = reports.account_realm_id
			INNER JOIN property p 
				ON p.account_id = reports.account_id
				AND p.account_realm_id = reports.account_realm_id
				AND p.property_name IN ($3,$4)
				AND p.property_type = $5
		), rank AS (
			SELECT *,
				rank() OVER (partition by account_id ORDER BY property_name desc)
					as rank
			FROM agg
		), shouldbethere AS (
			SELECT $6 as account_collection_id,
					account_collection_id as child_account_collection_id
			FROM rank
	 		WHERE	manager_account_id =  $1
			AND	rank = 1
		), arethere AS (
			SELECT account_collection_id, child_account_collection_id FROM
				account_collection_hier
			WHERE account_collection_id = $6
		), ins AS (
			INSERT INTO account_collection_hier 
				(account_collection_id, child_account_collection_id)
			SELECT account_collection_id, child_account_collection_id
			FROM shouldbethere
			WHERE (account_collection_id, child_account_collection_id)
				NOT IN (SELECT * from arethere)
			RETURNING *
		), del AS (
			DELETE FROM account_collection_hier
			WHERE (account_collection_id, child_account_collection_id)
				IN (SELECT * from arethere)
			AND (account_collection_id, child_account_collection_id)
				NOT IN (SELECT * FROM shouldbethere)
			RETURNING *
		) select * from ins UNION select * from del;

	' USING account_id, 'primary',
				'AutomatedDirectsAC','AutomatedRollupsAC','auto_acct_coll',
				_rollupac;

	RETURN _rollupac;
END;
$function$
;

--
-- Process middle (non-trigger) schema company_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('company_manip', 'add_auto_collections');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS company_manip.add_auto_collections ( _company_id integer, _account_realm_id integer, _company_type text );
CREATE OR REPLACE FUNCTION company_manip.add_auto_collections(_company_id integer, _account_realm_id integer, _company_type text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_ar		account_realm.account_realm_name%TYPE;
	_csn	company.company_short_name%TYPE;
	_r		RECORD;
	_v		text[];
	i		text;
	acname	account_collection.account_collection_name%TYPE;
	acid	account_collection.account_collection_id%TYPE;
	propv	text;
	tally	integer;
BEGIN
	PERFORM *
	FROM	account_realm_company
	WHERE	company_id = _company_id
	AND		account_realm_id = _account_realm_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Company and Account Realm are not associated together'
			USING ERRCODE = 'not_null_violation';
	END IF;

	PERFORM *
	FROM	company_type
	WHERE	company_id = _company_id
	AND		company_type = _company_type;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Company % is not of type %', _company_id, _company_type
			USING ERRCODE = 'not_null_violation';
	END IF;
	
	tally := 0;
	FOR _r IN SELECT	property_name, property_type, permit_company_id
				FROM    property_collection_property pcp
				INNER JOIN property_collection pc
					USING (property_collection_id)
				INNER JOIN val_property vp USING (property_name,property_type)
				WHERE pc.property_collection_type = 'auto_ac_assignment'
				AND pc.property_collection_name = _company_type
				AND property_name != 'site'
	LOOP
		IF _r.property_name = 'account_type' THEN
			SELECT array_agg( account_type)
			INTO _v
			FROM val_account_type
			WHERE account_type != 'blacklist';
		ELSE
			_v := ARRAY[NULL]::text[];
		END IF;

	SELECT	account_realm_name
	INTO	_ar
	FROM	account_realm
	WHERE	account_realm_id = _account_realm_id;

	SELECT	company_short_name
	INTO	_csn
	FROM	company
	WHERE	company_id = _company_id;

		FOREACH i IN ARRAY _v
		LOOP
			IF i IS NULL THEN
				acname := concat(_ar, '_', _csn, '_', _r.property_name);
				propv := NULL;
			ELSE
				acname := concat(_ar, '_', _csn, '_', i);
				propv := i;
			END IF;

			INSERT INTO account_collection (
				account_collection_name, account_collection_type
			) VALUES (
				acname, 'automated'
			) RETURNING account_collection_id INTO acid;

			INSERT INTO property (
				property_name, property_type, account_realm_id,
				account_collection_id,
				company_id, property_value
			) VALUES (
				_r.property_name, _r.property_type, _account_realm_id,
				acid,
				_company_id, propv
			);
			tally := tally + 1;
		END LOOP;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('company_manip', 'add_company');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS company_manip.add_company ( _company_name text, _company_types text[], _parent_company_id integer, _account_realm_id integer, _company_short_name text, _description text );
CREATE OR REPLACE FUNCTION company_manip.add_company(_company_name text, _company_types text[] DEFAULT NULL::text[], _parent_company_id integer DEFAULT NULL::integer, _account_realm_id integer DEFAULT NULL::integer, _company_short_name text DEFAULT NULL::text, _description text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_cmpid	company.company_id%type;
	_short	text;
	_isfam	char(1);
BEGIN
	IF _company_types @> ARRAY['corporate family'] THEN
		_isfam := 'Y';
	ELSE
		_isfam := 'N';
	END IF;
	IF _company_short_name IS NULL and _isfam = 'Y' THEN
		_short := lower(regexp_replace(
				regexp_replace(
					regexp_replace(_company_name, 
						E'\\s+(ltd|sarl|limited|pt[ye]|GmbH|ag|ab|inc)', 
						'', 'gi'),
					E'[,\\.\\$#@]', '', 'mg'),
				E'\\s+', '_', 'gi'));
	ELSE
		_short := _company_short_name;
	END IF;

	INSERT INTO company (
		company_name, company_short_name,
		parent_company_id, description
	) VALUES (
		_company_name, _short,
		_parent_company_id, _description
	) RETURNING company_id INTO _cmpid;

	IF _account_realm_id IS NOT NULL THEN
		INSERT INTO account_realm_company (
			account_realm_id, company_id
		) VALUES (
			_account_realm_id, _cmpid
		);
	END IF;

	IF _company_types IS NOT NULL THEN
		PERFORM company_manip.add_company_types(_cmpid, _account_realm_id, _company_types);
	END IF;

	RETURN _cmpid;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION company_manip.remove_company(_company_id integer, raise_exception boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF raise_exception THEN
		DELETE FROM company_type
		WHERE company_id = _company_id;

		DELETE FROM account_realm_company
		WHERE company_id = _company_id;

		DELETE FROM account_realm_company
		WHERE company_id = _company_id;

		DELETE FROM company
		WHERE company_id = _company_id;
	ELSE
		BEGIN
			DELETE FROM company_type
			WHERE company_id = _company_id;

			DELETE FROM account_realm_company
			WHERE company_id = _company_id;

			DELETE FROM account_realm_company
			WHERE company_id = _company_id;

			DELETE FROM company
			WHERE company_id = _company_id;
		EXCEPTION WHEN foreign_key_violation THEN
			RETURN false;
		END;
	END IF;
	RETURN true;
END;
$function$
;

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
-- Process middle (non-trigger) schema schema_support
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_dependant_objects_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_dependant_objects_for_replay ( schema character varying, object character varying, dropit boolean, doobjectdeps boolean );
CREATE OR REPLACE FUNCTION schema_support.save_dependant_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
	PERFORM schema_support.save_dependent_objects_for_replay(
		schema, object, dropit, doobjectdeps);
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
				WHEN 'v' THEN 'view'
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

-- New function
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
		IF _r.relkind = 'v' THEN
			RAISE NOTICE '2 dealing with  %.%', _r.nspname, _r.relname;
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

--
-- Process middle (non-trigger) schema approval_utils
--
--
-- Process middle (non-trigger) schema account_collection_manip
--
-- New function
CREATE OR REPLACE FUNCTION account_collection_manip.id_tag()
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
BEGIN
	RETURN('<-- $Id$ -->');
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION account_collection_manip.manip_membership(account_collection_name character varying, account_collection_type character varying, account_id integer, is_member boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally	INTEGER;
	acid	account_collection.account_collection_id%TYPE;
BEGIN
	IF is_member IS NULL THEN
		is_member := false;
	END IF;

	EXECUTE '
		SELECT	account_collection_id
		FROM	account_collection
		WHERE	account_collection_name = $1
		AND		account_collection_type = $2
	' INTO acid USING account_collection_name, account_collection_type;

	IF acid IS NULL THEN
		RAISE EXCEPTION 'Unknown account collection %:%',
			account_collection_type, account_collection_name
			USING ERRCODE = 'invalid_parameter_value';
	END IF;


	IF is_member THEN
		EXECUTE '
			SELECT count(*)
			FROM account_collection_account
			WHERE account_collection_id = $1
			AND account_id = $2
		' INTO tally USING acid, account_id;

		IF tally = 0 THEN
			EXECUTE 'INSERT INTO account_collection_account (
				account_collection_id, account_id
				) VALUES (
					$1, $2
				)
			' USING acid, account_id;
		END IF;
		RETURN true;
	ELSE
		EXECUTE '
			DELETE FROM account_collection_account
			WHERE account_collection_id = $1
			AND account_id = $2
		' USING acid, account_id;
		return false;
	END IF;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION account_collection_manip.manip_membership(account_collection_name character varying, account_collection_type character varying, account_id integer, is_member character)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	forced boolean;
BEGIN
	IF is_member IS NULL OR is_member = 'N' THEN
		forced = false;
	ELSE
		forced = true;
	END IF;
	RETURN account_collection_manip.manip_membership(
		account_collection_name, account_collection_type, account_id,
		forced);
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION account_collection_manip.manip_membership(account_collection_name character varying, account_collection_type character varying, account_id integer, is_member integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	forced boolean;
BEGIN
	IF is_member IS NULL OR is_member = 0 THEN
		forced = false;
	ELSE
		forced = true;
	END IF;
	RETURN account_collection_manip.manip_membership(
		account_collection_name, account_collection_type, account_id,
		forced);
END;
$function$
;

--
-- Process middle (non-trigger) schema script_hooks
--
-- New function
CREATE OR REPLACE FUNCTION script_hooks.id_tag()
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
BEGIN
	RETURN('<-- $Id$ -->');
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION script_hooks.mkpasswdfiles_post()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	BEGIN
		PERFORM local_hooks.mkpasswdfiles_post();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION script_hooks.mkpasswdfiles_pre()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	BEGIN
		PERFORM local_hooks.mkpasswdfiles_pre();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION script_hooks.zonegen_post()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	BEGIN
		PERFORM local_hooks.zonegen_post();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION script_hooks.zonegen_pre()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	BEGIN
		PERFORM local_hooks.zonegen_pre();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
END;
$function$
;

-- Creating new sequences....


--------------------------------------------------------------------
-- DEALING WITH TABLE val_account_collection_type [1291452]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_account_collection_type', 'val_account_collection_type');

-- FOREIGN KEYS FROM
ALTER TABLE account_realm_acct_coll_type DROP CONSTRAINT IF EXISTS fk_acct_realm_acct_coll_typ;
ALTER TABLE account_collection DROP CONSTRAINT IF EXISTS fk_acctcol_usrcoltyp;
ALTER TABLE val_property_type DROP CONSTRAINT IF EXISTS fk_prop_typ_pv_uctyp_rst;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_val_prop_acct_coll_type;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_valprop_pv_actyp_rst;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_account_collection_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_account_collection_type DROP CONSTRAINT IF EXISTS pk_val_account_collection_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_account_collection_type DROP CONSTRAINT IF EXISTS check_yes_no_1816418084;
ALTER TABLE jazzhands.val_account_collection_type DROP CONSTRAINT IF EXISTS check_yes_no_act_chh;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_account_collection_type ON jazzhands.val_account_collection_type;
DROP TRIGGER IF EXISTS trigger_audit_val_account_collection_type ON jazzhands.val_account_collection_type;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_account_collection_type');
---- BEGIN audit.val_account_collection_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_account_collection_type', 'val_account_collection_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_account_collection_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_account_collection_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_account_collection_type');
---- DONE audit.val_account_collection_type TEARDOWN


ALTER TABLE val_account_collection_type RENAME TO val_account_collection_type_v69;
ALTER TABLE audit.val_account_collection_type RENAME TO val_account_collection_type_v69;

CREATE TABLE val_account_collection_type
(
	account_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	is_infrastructure_type	character(1) NOT NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	account_realm_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_account_collection_type', false);
ALTER TABLE val_account_collection_type
	ALTER is_infrastructure_type
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_account_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
INSERT INTO val_account_collection_type (
	account_collection_type,
	description,
	is_infrastructure_type,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	account_realm_id,		-- new column (account_realm_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	account_collection_type,
	description,
	is_infrastructure_type,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	NULL,		-- new column (account_realm_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_account_collection_type_v69;

INSERT INTO audit.val_account_collection_type (
	account_collection_type,
	description,
	is_infrastructure_type,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	account_realm_id,		-- new column (account_realm_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	account_collection_type,
	description,
	is_infrastructure_type,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	NULL,		-- new column (account_realm_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_account_collection_type_v69;

ALTER TABLE val_account_collection_type
	ALTER is_infrastructure_type
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_account_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_account_collection_type ADD CONSTRAINT pk_val_account_collection_type PRIMARY KEY (account_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_account_collection_type.max_num_members IS 'Maximum INTEGER of members in a given collection of this type
';
COMMENT ON COLUMN val_account_collection_type.max_num_collections IS 'Maximum INTEGER of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_account_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
COMMENT ON COLUMN val_account_collection_type.account_realm_id IS 'If set, all accounts in this collection must be of this realm, and all child account collections of this one must have the realm set to be the same.';
-- INDEXES
CREATE INDEX xif1val_account_collection_typ ON val_account_collection_type USING btree (account_realm_id);

-- CHECK CONSTRAINTS
ALTER TABLE val_account_collection_type ADD CONSTRAINT check_yes_no_1816418084
	CHECK (is_infrastructure_type = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_account_collection_type ADD CONSTRAINT check_yes_no_act_chh
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_account_collection_type and account_realm_acct_coll_type
ALTER TABLE account_realm_acct_coll_type
	ADD CONSTRAINT fk_acct_realm_acct_coll_typ
	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_account_collection_type and account_collection
ALTER TABLE account_collection
	ADD CONSTRAINT fk_acctcol_usrcoltyp
	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_account_collection_type and val_property_type
ALTER TABLE val_property_type
	ADD CONSTRAINT fk_prop_typ_pv_uctyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_account_collection_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_acct_coll_type
	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_account_collection_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_pv_actyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);

-- FOREIGN KEYS TO
-- consider FK val_account_collection_type and account_realm
ALTER TABLE val_account_collection_type
	ADD CONSTRAINT r_785
	FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id);

-- TRIGGERS
-- consider NEW oid 1365001
CREATE OR REPLACE FUNCTION jazzhands.account_collection_type_realm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF NEW.account_realm_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_account
			JOIN account_collection USING (account_collection_id)
			JOIN account a USING (account_id)
	WHERE	account_collection_type = NEW.account_collection_type
	AND		a.account_realm_id != NEW.account_realm_id;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Unable to set account_realm restriction because there are accounts assigned that do not match it'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	-- This is probably useless.
	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_hier h
			JOIN account_collection pac USING (account_collection_id)
			JOIN val_account_collection_type pat USING (account_collection_type)
			JOIN account_collection cac ON
				h.child_account_collection_id = cac.account_collection_id
			JOIN val_account_collection_type cat ON
				cac.account_collection_type = cat.account_collection_type
	WHERE	(
				pac.account_collection_type = NEW.account_collection_type
			OR
				cac.account_collection_type = NEW.account_collection_type
			)
	AND		(
				pat.account_realm_id IS DISTINCT FROM NEW.account_realm_id
			OR
				cat.account_realm_id IS DISTINCT FROM NEW.account_realm_id
			)
	;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Unable to set account_realm restriction because there are account collections in the hierarchy that do not match'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trig_account_collection_type_realm AFTER UPDATE OF account_realm_id ON val_account_collection_type FOR EACH ROW EXECUTE PROCEDURE account_collection_type_realm();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_account_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_account_collection_type');
DROP TABLE IF EXISTS val_account_collection_type_v69;
DROP TABLE IF EXISTS audit.val_account_collection_type_v69;
-- DONE DEALING WITH TABLE val_account_collection_type [1354547]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE device [1289975]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device', 'device');

-- FOREIGN KEYS FROM
ALTER TABLE chassis_location DROP CONSTRAINT IF EXISTS fk_chass_loc_chass_devid;
ALTER TABLE device_encapsulation_domain DROP CONSTRAINT IF EXISTS fk_dev_encap_domain_devid;
ALTER TABLE device_management_controller DROP CONSTRAINT IF EXISTS fk_dev_mgmt_ctlr_dev_id;
ALTER TABLE device_ssh_key DROP CONSTRAINT IF EXISTS fk_dev_ssh_key_ssh_key_id;
ALTER TABLE device_ticket DROP CONSTRAINT IF EXISTS fk_dev_tkt_dev_id;
ALTER TABLE device_type DROP CONSTRAINT IF EXISTS fk_dev_typ_tmplt_dev_typ_id;
ALTER TABLE device_collection_device DROP CONSTRAINT IF EXISTS fk_devcolldev_dev_id;
ALTER TABLE device_layer2_network DROP CONSTRAINT IF EXISTS fk_device_l2_net_devid;
ALTER TABLE device_note DROP CONSTRAINT IF EXISTS fk_device_note_device;
ALTER TABLE device_management_controller DROP CONSTRAINT IF EXISTS fk_dvc_mgmt_ctrl_mgr_dev_id;
ALTER TABLE logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_device_id;
ALTER TABLE mlag_peering DROP CONSTRAINT IF EXISTS fk_mlag_peering_devid1;
ALTER TABLE mlag_peering DROP CONSTRAINT IF EXISTS fk_mlag_peering_devid2;
ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS fk_netint_device_id;
ALTER TABLE network_interface_purpose DROP CONSTRAINT IF EXISTS fk_netint_purpose_device_id;
ALTER TABLE network_service DROP CONSTRAINT IF EXISTS fk_netsvc_device_id;
ALTER TABLE physicalish_volume DROP CONSTRAINT IF EXISTS fk_physvol_device_id;
ALTER TABLE snmp_commstr DROP CONSTRAINT IF EXISTS fk_snmpstr_device_id;
ALTER TABLE static_route DROP CONSTRAINT IF EXISTS fk_statrt_devsrc_id;
ALTER TABLE volume_group DROP CONSTRAINT IF EXISTS fk_volgrp_devid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_chasloc_chass_devid;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_chass_loc_id_mod_enfc;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_devtp_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_os_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_rack_location_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_ref_mgmt_proto;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_asset_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_comp_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_dev_v_svcenv;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_dev_val_status;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_fk_voe;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_id_dnsrecord;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_ref_parent_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_ref_voesymbtrk;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_site_code;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'device');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ak_device_chassis_location_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ak_device_rack_location_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS pk_device;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_dev_islclymgd";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_ismonitored";
DROP INDEX IF EXISTS "jazzhands"."idx_device_type_location";
DROP INDEX IF EXISTS "jazzhands"."xif_dev_chass_loc_id_mod_enfc";
DROP INDEX IF EXISTS "jazzhands"."xif_dev_os_id";
DROP INDEX IF EXISTS "jazzhands"."xif_device_asset_id";
DROP INDEX IF EXISTS "jazzhands"."xif_device_comp_id";
DROP INDEX IF EXISTS "jazzhands"."xif_device_dev_v_svcenv";
DROP INDEX IF EXISTS "jazzhands"."xif_device_dev_val_status";
DROP INDEX IF EXISTS "jazzhands"."xif_device_fk_voe";
DROP INDEX IF EXISTS "jazzhands"."xif_device_id_dnsrecord";
DROP INDEX IF EXISTS "jazzhands"."xif_device_site_code";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_locally_manage_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_monitored_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_virtual_device_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_should_fetch_conf_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS dev_osid_notnull;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069051;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069052;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069057;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069059;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069060;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_device ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_audit_device ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_create_device_component ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_delete_per_device_device_collection ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_device_one_location_validate ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_update_per_device_device_collection ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_validate_device_component_assignment ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_verify_device_voe ON jazzhands.device;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'device');
---- BEGIN audit.device TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'device', 'device');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'device');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."device_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'device');
---- DONE audit.device TEARDOWN


ALTER TABLE device RENAME TO device_v69;
ALTER TABLE audit.device RENAME TO device_v69;

CREATE TABLE device
(
	device_id	integer NOT NULL,
	component_id	integer  NULL,
	device_type_id	integer NOT NULL,
	asset_id	integer  NULL,
	device_name	varchar(255)  NULL,
	site_code	varchar(50)  NULL,
	identifying_dns_record_id	integer  NULL,
	host_id	varchar(255)  NULL,
	physical_label	varchar(255)  NULL,
	rack_location_id	integer  NULL,
	chassis_location_id	integer  NULL,
	parent_device_id	integer  NULL,
	description	varchar(255)  NULL,
	device_status	varchar(50) NOT NULL,
	operating_system_id	integer NOT NULL,
	service_environment_id	integer NOT NULL,
	voe_id	integer  NULL,
	auto_mgmt_protocol	varchar(50)  NULL,
	voe_symbolic_track_id	integer  NULL,
	is_locally_managed	character(1) NOT NULL,
	is_monitored	character(1) NOT NULL,
	is_virtual_device	character(1) NOT NULL,
	should_fetch_config	character(1) NOT NULL,
	date_in_service	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device', false);
ALTER TABLE device
	ALTER device_id
	SET DEFAULT nextval('device_device_id_seq'::regclass);
ALTER TABLE device
	ALTER operating_system_id
	SET DEFAULT 0;
ALTER TABLE device
	ALTER is_locally_managed
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE device
	ALTER is_virtual_device
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device
	ALTER should_fetch_config
	SET DEFAULT 'Y'::bpchar;
INSERT INTO device (
	device_id,
	component_id,
	device_type_id,
	asset_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	host_id,
	physical_label,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	device_status,
	operating_system_id,
	service_environment_id,
	voe_id,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	device_id,
	component_id,
	device_type_id,
	asset_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	host_id,
	physical_label,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	device_status,
	operating_system_id,
	service_environment_id,
	voe_id,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_v69;

INSERT INTO audit.device (
	device_id,
	component_id,
	device_type_id,
	asset_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	host_id,
	physical_label,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	device_status,
	operating_system_id,
	service_environment_id,
	voe_id,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
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
	component_id,
	device_type_id,
	asset_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	host_id,
	physical_label,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	device_status,
	operating_system_id,
	service_environment_id,
	voe_id,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_v69;

ALTER TABLE device
	ALTER device_id
	SET DEFAULT nextval('device_device_id_seq'::regclass);
ALTER TABLE device
	ALTER operating_system_id
	SET DEFAULT 0;
ALTER TABLE device
	ALTER is_locally_managed
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE device
	ALTER is_virtual_device
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device
	ALTER should_fetch_config
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device ADD CONSTRAINT ak_device_chassis_location_id UNIQUE (chassis_location_id);
-- ALTER TABLE device ADD CONSTRAINT ak_device_rack_location_id UNIQUE (rack_location_id);
ALTER TABLE device ADD CONSTRAINT pk_device PRIMARY KEY (device_id);

-- Table/Column Comments
COMMENT ON COLUMN device.asset_id IS 'COLUMN IS DEPRECATED AND WILL REMOVED >= 0.70.  Get to it via asset.component_id.';
-- INDEXES
CREATE INDEX idx_dev_islclymgd ON device USING btree (is_locally_managed);
CREATE INDEX idx_dev_ismonitored ON device USING btree (is_monitored);
CREATE INDEX idx_device_type_location ON device USING btree (device_type_id);
CREATE INDEX xif_dev_chass_loc_id_mod_enfc ON device USING btree (chassis_location_id, parent_device_id, device_type_id);
CREATE INDEX xif_dev_os_id ON device USING btree (operating_system_id);
CREATE INDEX xif_device_asset_id ON device USING btree (asset_id);
CREATE INDEX xif_device_comp_id ON device USING btree (component_id);
CREATE INDEX xif_device_dev_v_svcenv ON device USING btree (service_environment_id);
CREATE INDEX xif_device_dev_val_status ON device USING btree (device_status);
CREATE INDEX xif_device_fk_voe ON device USING btree (voe_id);
CREATE INDEX xif_device_id_dnsrecord ON device USING btree (identifying_dns_record_id);
CREATE INDEX xif_device_site_code ON device USING btree (site_code);

-- CHECK CONSTRAINTS
ALTER TABLE device ADD CONSTRAINT ckc_is_locally_manage_device
	CHECK ((is_locally_managed = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_locally_managed)::text = upper((is_locally_managed)::text)));
ALTER TABLE device ADD CONSTRAINT ckc_is_monitored_device
	CHECK ((is_monitored = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_monitored)::text = upper((is_monitored)::text)));
ALTER TABLE device ADD CONSTRAINT ckc_is_virtual_device_device
	CHECK ((is_virtual_device = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_virtual_device)::text = upper((is_virtual_device)::text)));
ALTER TABLE device ADD CONSTRAINT ckc_should_fetch_conf_device
	CHECK ((should_fetch_config = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_fetch_config)::text = upper((should_fetch_config)::text)));
ALTER TABLE device ADD CONSTRAINT dev_osid_notnull
	CHECK (operating_system_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069051
	CHECK (device_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069052
	CHECK (device_type_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069057
	CHECK (is_monitored IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069059
	CHECK (is_virtual_device IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069060
	CHECK (should_fetch_config IS NOT NULL);

-- FOREIGN KEYS FROM
-- consider FK device and chassis_location
ALTER TABLE chassis_location
	ADD CONSTRAINT fk_chass_loc_chass_devid
	FOREIGN KEY (chassis_device_id) REFERENCES device(device_id) DEFERRABLE;
-- consider FK device and device_encapsulation_domain
ALTER TABLE device_encapsulation_domain
	ADD CONSTRAINT fk_dev_encap_domain_devid
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_management_controller
ALTER TABLE device_management_controller
	ADD CONSTRAINT fk_dev_mgmt_ctlr_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_ssh_key
ALTER TABLE device_ssh_key
	ADD CONSTRAINT fk_dev_ssh_key_ssh_key_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_ticket
ALTER TABLE device_ticket
	ADD CONSTRAINT fk_dev_tkt_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_type
ALTER TABLE device_type
	ADD CONSTRAINT fk_dev_typ_tmplt_dev_typ_id
	FOREIGN KEY (template_device_id) REFERENCES device(device_id);
-- consider FK device and device_collection_device
ALTER TABLE device_collection_device
	ADD CONSTRAINT fk_devcolldev_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_layer2_network
ALTER TABLE device_layer2_network
	ADD CONSTRAINT fk_device_l2_net_devid
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_note
ALTER TABLE device_note
	ADD CONSTRAINT fk_device_note_device
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_management_controller
ALTER TABLE device_management_controller
	ADD CONSTRAINT fk_dvc_mgmt_ctrl_mgr_dev_id
	FOREIGN KEY (manager_device_id) REFERENCES device(device_id);
-- consider FK device and logical_volume
ALTER TABLE logical_volume
	ADD CONSTRAINT fk_logvol_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id) DEFERRABLE;
-- consider FK device and mlag_peering
ALTER TABLE mlag_peering
	ADD CONSTRAINT fk_mlag_peering_devid1
	FOREIGN KEY (device1_id) REFERENCES device(device_id);
-- consider FK device and mlag_peering
ALTER TABLE mlag_peering
	ADD CONSTRAINT fk_mlag_peering_devid2
	FOREIGN KEY (device2_id) REFERENCES device(device_id);
-- consider FK device and network_interface
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and network_interface_purpose
ALTER TABLE network_interface_purpose
	ADD CONSTRAINT fk_netint_purpose_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and network_service
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and physicalish_volume
ALTER TABLE physicalish_volume
	ADD CONSTRAINT fk_physvol_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id) DEFERRABLE;
-- consider FK device and snmp_commstr
ALTER TABLE snmp_commstr
	ADD CONSTRAINT fk_snmpstr_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and static_route
ALTER TABLE static_route
	ADD CONSTRAINT fk_statrt_devsrc_id
	FOREIGN KEY (device_src_id) REFERENCES device(device_id);
-- consider FK device and volume_group
ALTER TABLE volume_group
	ADD CONSTRAINT fk_volgrp_devid
	FOREIGN KEY (device_id) REFERENCES device(device_id) DEFERRABLE;

-- FOREIGN KEYS TO
-- consider FK device and chassis_location
ALTER TABLE device
	ADD CONSTRAINT fk_chasloc_chass_devid
	FOREIGN KEY (chassis_location_id) REFERENCES chassis_location(chassis_location_id) DEFERRABLE;
-- consider FK device and chassis_location
ALTER TABLE device
	ADD CONSTRAINT fk_dev_chass_loc_id_mod_enfc
	FOREIGN KEY (chassis_location_id, parent_device_id, device_type_id) REFERENCES chassis_location(chassis_location_id, chassis_device_id, module_device_type_id) DEFERRABLE;
-- consider FK device and device_type
ALTER TABLE device
	ADD CONSTRAINT fk_dev_devtp_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
-- consider FK device and operating_system
ALTER TABLE device
	ADD CONSTRAINT fk_dev_os_id
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
-- consider FK device and rack_location
ALTER TABLE device
	ADD CONSTRAINT fk_dev_rack_location_id
	FOREIGN KEY (rack_location_id) REFERENCES rack_location(rack_location_id);
-- consider FK device and val_device_auto_mgmt_protocol
ALTER TABLE device
	ADD CONSTRAINT fk_dev_ref_mgmt_proto
	FOREIGN KEY (auto_mgmt_protocol) REFERENCES val_device_auto_mgmt_protocol(auto_mgmt_protocol);
-- consider FK device and asset
ALTER TABLE device
	ADD CONSTRAINT fk_device_asset_id
	FOREIGN KEY (asset_id) REFERENCES asset(asset_id);
-- consider FK device and component
ALTER TABLE device
	ADD CONSTRAINT fk_device_comp_id
	FOREIGN KEY (component_id) REFERENCES component(component_id);
-- consider FK device and service_environment
ALTER TABLE device
	ADD CONSTRAINT fk_device_dev_v_svcenv
	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);
-- consider FK device and val_device_status
ALTER TABLE device
	ADD CONSTRAINT fk_device_dev_val_status
	FOREIGN KEY (device_status) REFERENCES val_device_status(device_status);
-- consider FK device and voe
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_voe
	FOREIGN KEY (voe_id) REFERENCES voe(voe_id);
-- consider FK device and dns_record
ALTER TABLE device
	ADD CONSTRAINT fk_device_id_dnsrecord
	FOREIGN KEY (identifying_dns_record_id) REFERENCES dns_record(dns_record_id) DEFERRABLE;
-- consider FK device and device
ALTER TABLE device
	ADD CONSTRAINT fk_device_ref_parent_device
	FOREIGN KEY (parent_device_id) REFERENCES device(device_id);
-- consider FK device and voe_symbolic_track
ALTER TABLE device
	ADD CONSTRAINT fk_device_ref_voesymbtrk
	FOREIGN KEY (voe_symbolic_track_id) REFERENCES voe_symbolic_track(voe_symbolic_track_id);
-- consider FK device and site
ALTER TABLE device
	ADD CONSTRAINT fk_device_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);

-- TRIGGERS
-- consider NEW oid 1364559
CREATE OR REPLACE FUNCTION jazzhands.create_device_component_by_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	devtype		RECORD;
	ctid		integer;
	cid			integer;
	scarr       integer[];
	dcarr       integer[];
	server_ver	integer;
BEGIN

	SELECT
		dt.device_type_id,
		dt.component_type_id,
		dt.template_device_id,
		d.component_id
	INTO
		devtype
	FROM
		device_type dt LEFT JOIN
		device d ON (dt.template_device_id = d.device_id)
	WHERE
		dt.device_type_id = NEW.device_type_id;

	IF NEW.component_id IS NOT NULL THEN
		IF devtype.component_type_id IS NOT NULL THEN
			SELECT
				component_type_id INTO ctid
			FROM
				component c
			WHERE
				c.component_id = NEW.component_id;

			IF ctid != devtype.component_type_id THEN
				UPDATE
					component
				SET
					component_type_id = devtype.component_type_id
				WHERE
					component_id = NEW.component_id;
			END IF;
		END IF;
			
		RETURN NEW;
	END IF;

	--
	-- If template_device_id doesn't exist, then create an instance of
	-- the component_id if it exists 
	--
	IF devtype.component_id IS NULL THEN
		--
		-- If the component_id doesn't exist, then we're done
		--
		IF devtype.component_type_id IS NULL THEN
			RETURN NEW;
		END IF;
		--
		-- Insert a component of the given type and tie it to the device
		--
		INSERT INTO component (component_type_id)
			VALUES (devtype.component_type_id)
			RETURNING component_id INTO cid;

		NEW.component_id := cid;
		RETURN NEW;
	ELSE
		SELECT setting INTO server_ver FROM pg_catalog.pg_settings
			WHERE name = 'server_version_num';

		IF (server_ver < 90400) THEN
			--
			-- This is pretty nasty; welcome to SQL
			--
			--
			-- This returns data into a temporary table (ugh) that's used as a
			-- key/value store to map each template component to the 
			-- newly-created one
			--
			CREATE TEMPORARY TABLE trig_comp_ins AS
			WITH comp_ins AS (
				INSERT INTO component (
					component_type_id
				) SELECT
					c.component_type_id
				FROM
					device_type dt JOIN 
					v_device_components dc ON
						(dc.device_id = dt.template_device_id) JOIN
					component c USING (component_id)
				WHERE
					device_type_id = NEW.device_type_id
				ORDER BY
					level, c.component_type_id
				RETURNING component_id
			)
			SELECT 
				src_comp.component_id as src_component_id,
				dst_comp.component_id as dst_component_id,
				src_comp.level as level
			FROM
				(SELECT
					c.component_id,
					level,
					row_number() OVER (ORDER BY level, c.component_type_id)
						AS rownum
				 FROM
					device_type dt JOIN 
					v_device_components dc ON
						(dc.device_id = dt.template_device_id) JOIN
					component c USING (component_id)
				 WHERE
					device_type_id = NEW.device_type_id
				) src_comp,
				(SELECT
					component_id,
					row_number() OVER () AS rownum
				 FROM
					comp_ins
				) dst_comp
			WHERE
				src_comp.rownum = dst_comp.rownum;

			/* 
				 Now take the mapping of components that were inserted above,
				 and tie the new components to the appropriate slot on the
				 parent.
				 The logic below is:
					- Take the template component, and locate its parent slot
					- Find the correct slot on the corresponding new parent 
					  component by locating one with the same slot_name and
					  slot_type_id on the mapped parent component_id
					- Update the parent_slot_id of the component with the
					  mapped component_id to this slot_id 
				 
				 This works even if the top-level component is attached to some
				 other device, since there will not be a mapping for those in
				 the table to locate.
			*/
					  
			UPDATE
				component dc
			SET
				parent_slot_id = ds.slot_id
			FROM
				trig_comp_ins tt,
				trig_comp_ins ptt,
				component sc,
				slot ss,
				slot ds
			WHERE
				tt.src_component_id = sc.component_id AND
				tt.dst_component_id = dc.component_id AND
				ss.slot_id = sc.parent_slot_id AND
				ss.component_id = ptt.src_component_id AND
				ds.component_id = ptt.dst_component_id AND
				ss.slot_type_id = ds.slot_type_id AND
				ss.slot_name = ds.slot_name;

			SELECT dst_component_id INTO cid FROM trig_comp_ins WHERE
				level = 1;

			NEW.component_id := cid;

			DROP TABLE trig_comp_ins;

			RETURN NEW;
		ELSE
			WITH dev_comps AS (
				SELECT
					c.component_id,
					c.component_type_id,
					level,
					row_number() OVER (ORDER BY level, c.component_type_id) AS
						rownum
				FROM
					device_type dt JOIN 
					v_device_components dc ON
						(dc.device_id = dt.template_device_id) JOIN
					component c USING (component_id)
				WHERE
					device_type_id = NEW.device_type_id
			),
			comp_ins AS (
				INSERT INTO component (
					component_type_id
				) SELECT
					component_type_id
				FROM
					dev_comps
				ORDER BY
					rownum
				RETURNING component_id, component_type_id
			),
			comp_ins_arr AS (
				SELECT
					array_agg(component_id) AS dst_arr
				FROM
					comp_ins
			),
			dev_comps_arr AS (
				SELECT
					array_agg(component_id) as src_arr
				FROM
					dev_comps
			)
			SELECT src_arr, dst_arr INTO scarr, dcarr FROM
				dev_comps_arr, comp_ins_arr;

			UPDATE
				component dc
			SET
				parent_slot_id = ds.slot_id
			FROM
				unnest(scarr, dcarr) AS 
					tt(src_component_id, dst_component_id),
				unnest(scarr, dcarr) AS 
					ptt(src_component_id, dst_component_id),
				component sc,
				slot ss,
				slot ds
			WHERE
				tt.src_component_id = sc.component_id AND
				tt.dst_component_id = dc.component_id AND
				ss.slot_id = sc.parent_slot_id AND
				ss.component_id = ptt.src_component_id AND
				ds.component_id = ptt.dst_component_id AND
				ss.slot_type_id = ds.slot_type_id AND
				ss.slot_name = ds.slot_name;

			SELECT 
				component_id INTO NEW.component_id
			FROM 
				component c
			WHERE
				component_id = ANY(dcarr) AND
				parent_slot_id IS NULL;

			RETURN NEW;
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_create_device_component BEFORE INSERT OR UPDATE OF device_type_id ON device FOR EACH ROW EXECUTE PROCEDURE create_device_component_by_trigger();

-- XXX - may need to include trigger function
-- consider NEW oid 1364582
CREATE OR REPLACE FUNCTION jazzhands.delete_per_device_device_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;
CREATE TRIGGER trigger_delete_per_device_device_collection BEFORE DELETE ON device FOR EACH ROW EXECUTE PROCEDURE delete_per_device_device_collection();

-- XXX - may need to include trigger function
-- consider NEW oid 1364606
CREATE OR REPLACE FUNCTION jazzhands.device_one_location_validate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;
CREATE TRIGGER trigger_device_one_location_validate BEFORE INSERT OR UPDATE ON device FOR EACH ROW EXECUTE PROCEDURE device_one_location_validate();

-- XXX - may need to include trigger function
-- consider NEW oid 1364591
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
CREATE TRIGGER trigger_update_per_device_device_collection AFTER INSERT OR UPDATE ON device FOR EACH ROW EXECUTE PROCEDURE update_per_device_device_collection();

-- XXX - may need to include trigger function
-- consider NEW oid 1364492
CREATE OR REPLACE FUNCTION jazzhands.validate_device_component_assignment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dtid		device_type.device_type_id%TYPE;
	dt_ctid		component.component_type_id%TYPE;
	ctid		component.component_type_id%TYPE;
BEGIN
	-- If no component_id is set, then we're done

	IF NEW.component_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT
		device_type_id, component_type_id 
	INTO
		dtid, dt_ctid
	FROM
		device_type
	WHERE
		device_type_id = NEW.device_type_id;
	
	IF NOT FOUND OR dt_ctid IS NULL THEN
		RAISE EXCEPTION 'No component_type_id set for device type'
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	SELECT
		component_type_id INTO ctid
	FROM
		component
	WHERE
		component_id = NEW.component_id;
	
	IF NOT FOUND OR ctid IS DISTINCT FROM dt_ctid THEN
		RAISE EXCEPTION 'Component type of component_id % does not match component_type for device_type_id % (%)',
			ctid, dtid, dt_ctid
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_validate_device_component_assignment AFTER INSERT OR UPDATE OF device_type_id, component_id ON device DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE validate_device_component_assignment();

-- XXX - may need to include trigger function
-- consider NEW oid 1364598
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
CREATE TRIGGER trigger_verify_device_voe BEFORE INSERT OR UPDATE ON device FOR EACH ROW EXECUTE PROCEDURE verify_device_voe();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device');
ALTER SEQUENCE device_device_id_seq
	 OWNED BY device.device_id;
DROP TABLE IF EXISTS device_v69;
DROP TABLE IF EXISTS audit.device_v69;
-- DONE DEALING WITH TABLE device [1352326]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE property [1291004]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'property', 'property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_compcoll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_l2_netcollid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_l3_netcoll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_os_snapshot;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_pv_devcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_svc_env_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acct_col;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acctid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acctrealmid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_compid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_devcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_dns_dom_collect;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_dnsdomid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_nblk_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_nmtyp;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_osid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_person_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_prop_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pv_nblkcol_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_acct_colid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_compid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_pwdtyp;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_swpkgid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_tokcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_site_code;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_val_prsnid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS r_784;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS pk_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif30property";
DROP INDEX IF EXISTS "jazzhands"."xif31property";
DROP INDEX IF EXISTS "jazzhands"."xif32property";
DROP INDEX IF EXISTS "jazzhands"."xif_prop_compcoll_id";
DROP INDEX IF EXISTS "jazzhands"."xif_prop_os_snapshot";
DROP INDEX IF EXISTS "jazzhands"."xif_prop_pv_devcolid";
DROP INDEX IF EXISTS "jazzhands"."xif_prop_svc_env_coll_id";
DROP INDEX IF EXISTS "jazzhands"."xif_property_acctrealmid";
DROP INDEX IF EXISTS "jazzhands"."xif_property_dns_dom_collect";
DROP INDEX IF EXISTS "jazzhands"."xif_property_nblk_coll_id";
DROP INDEX IF EXISTS "jazzhands"."xif_property_person_id";
DROP INDEX IF EXISTS "jazzhands"."xif_property_prop_coll_id";
DROP INDEX IF EXISTS "jazzhands"."xif_property_pv_nblkcol_id";
DROP INDEX IF EXISTS "jazzhands"."xif_property_val_prsnid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_account_id";
DROP INDEX IF EXISTS "jazzhands"."xifprop_acctcol_id";
DROP INDEX IF EXISTS "jazzhands"."xifprop_compid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_devcolid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_dnsdomid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_nmtyp";
DROP INDEX IF EXISTS "jazzhands"."xifprop_osid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_acct_colid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_compid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_pwdtyp";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_swpkgid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_tokcolid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_site_code";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS ckc_prop_isenbld;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_property ON jazzhands.property;
DROP TRIGGER IF EXISTS trigger_audit_property ON jazzhands.property;
DROP TRIGGER IF EXISTS trigger_validate_property ON jazzhands.property;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'property');
---- BEGIN audit.property TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'property', 'property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'property');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'property');
---- DONE audit.property TEARDOWN


ALTER TABLE property RENAME TO property_v69;
ALTER TABLE audit.property RENAME TO property_v69;

CREATE TABLE property
(
	property_id	integer NOT NULL,
	account_collection_id	integer  NULL,
	account_id	integer  NULL,
	account_realm_id	integer  NULL,
	company_collection_id	integer  NULL,
	company_id	integer  NULL,
	device_collection_id	integer  NULL,
	dns_domain_collection_id	integer  NULL,
	dns_domain_id	integer  NULL,
	layer2_network_collection_id	integer  NULL,
	layer3_network_collection_id	integer  NULL,
	netblock_collection_id	integer  NULL,
	network_range_id	integer  NULL,
	operating_system_id	integer  NULL,
	operating_system_snapshot_id	integer  NULL,
	person_id	integer  NULL,
	property_collection_id	integer  NULL,
	service_env_collection_id	integer  NULL,
	site_code	varchar(50)  NULL,
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	property_value	varchar(1024)  NULL,
	property_value_timestamp	timestamp without time zone  NULL,
	property_value_company_id	integer  NULL,
	property_value_account_coll_id	integer  NULL,
	property_value_device_coll_id	integer  NULL,
	property_value_nblk_coll_id	integer  NULL,
	property_value_password_type	varchar(50)  NULL,
	property_value_person_id	integer  NULL,
	property_value_sw_package_id	integer  NULL,
	property_value_token_col_id	integer  NULL,
	property_rank	integer  NULL,
	start_date	timestamp without time zone  NULL,
	finish_date	timestamp without time zone  NULL,
	is_enabled	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'property', false);
ALTER TABLE property
	ALTER property_id
	SET DEFAULT nextval('property_property_id_seq'::regclass);
ALTER TABLE property
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;
INSERT INTO property (
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_collection_id,
	company_id,
	device_collection_id,
	dns_domain_collection_id,
	dns_domain_id,
	layer2_network_collection_id,
	layer3_network_collection_id,
	netblock_collection_id,
	network_range_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_collection_id,
	company_id,
	device_collection_id,
	dns_domain_collection_id,
	dns_domain_id,
	layer2_network_collection_id,
	layer3_network_collection_id,
	netblock_collection_id,
	network_range_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM property_v69;

INSERT INTO audit.property (
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_collection_id,
	company_id,
	device_collection_id,
	dns_domain_collection_id,
	dns_domain_id,
	layer2_network_collection_id,
	layer3_network_collection_id,
	netblock_collection_id,
	network_range_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_collection_id,
	company_id,
	device_collection_id,
	dns_domain_collection_id,
	dns_domain_id,
	layer2_network_collection_id,
	layer3_network_collection_id,
	netblock_collection_id,
	network_range_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.property_v69;

ALTER TABLE property
	ALTER property_id
	SET DEFAULT nextval('property_property_id_seq'::regclass);
ALTER TABLE property
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE property ADD CONSTRAINT pk_property PRIMARY KEY (property_id);

-- Table/Column Comments
COMMENT ON TABLE property IS 'generic mechanism to create arbitrary associations between lhs database objects and assign them to zero or one other database objects/strings/lists/etc.  They are trigger enforced based on characteristics in val_property and val_property_value where foreign key enforcement does not work.';
COMMENT ON COLUMN property.property_id IS 'primary key for table to uniquely identify rows.';
COMMENT ON COLUMN property.account_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.account_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.account_realm_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.company_id IS 'LHS settable based on val_property.  THIS COLUMN IS DEPRECATED AND WILL BE REMOVED >= 0.66';
COMMENT ON COLUMN property.device_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.dns_domain_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.dns_domain_id IS 'LHS settable based on val_property.   THIS COLUMN IS BEING DEPRECATED IN FAVOR OF DNS_DOMAIN_COLLECTION_ID IN >= 0.66';
COMMENT ON COLUMN property.netblock_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.operating_system_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.operating_system_snapshot_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.person_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.property_collection_id IS 'LHS settable based on val_property.  NOTE, this is actually collections of property_name,property_type';
COMMENT ON COLUMN property.service_env_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.site_code IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.property_name IS 'textual name of a property';
COMMENT ON COLUMN property.property_type IS 'textual type of a department';
COMMENT ON COLUMN property.property_value IS 'RHS - general purpose column for value of property not defined by other types.  This may be enforced by fk (trigger) if val_property.property_data_type is list (fk is to val_property_value).   permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_timestamp IS 'RHS - value is a timestamp , permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_company_id IS 'RHS - fk to company_id,  permitted based on val_property.property_data_type.  THIS COLUMN IS DEPRECATED AND WILL BE REMOVED >= 0.66';
COMMENT ON COLUMN property.property_value_account_coll_id IS 'RHS, fk to account_collection,    permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_device_coll_id IS 'RHS - fk to device_collection.    permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_nblk_coll_id IS 'RHS - fk to network_collection.    permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_password_type IS 'RHS - fk to val_password_type.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_person_id IS 'RHS - fk to person.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_sw_package_id IS 'RHS - fk to sw_package.  possibly will be deprecated.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_token_col_id IS 'RHS - fk to token_collection_id.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_rank IS 'for multivalues, specifies the order.  If set, this basically becomes part of the "ak" for the lhs.';
COMMENT ON COLUMN property.start_date IS 'date/time that the assignment takes effect or NULL.  .  The view v_property filters this out.';
COMMENT ON COLUMN property.finish_date IS 'date/time that the assignment ceases taking effect or NULL.  .  The view v_property filters this out.';
COMMENT ON COLUMN property.is_enabled IS 'indiciates if the property is temporarily disabled or not.  The view v_property filters this out.';
-- INDEXES
CREATE INDEX xif30property ON property USING btree (layer2_network_collection_id);
CREATE INDEX xif31property ON property USING btree (layer3_network_collection_id);
CREATE INDEX xif32property ON property USING btree (network_range_id);
CREATE INDEX xif_prop_compcoll_id ON property USING btree (company_collection_id);
CREATE INDEX xif_prop_os_snapshot ON property USING btree (operating_system_snapshot_id);
CREATE INDEX xif_prop_pv_devcolid ON property USING btree (property_value_device_coll_id);
CREATE INDEX xif_prop_svc_env_coll_id ON property USING btree (service_env_collection_id);
CREATE INDEX xif_property_acctrealmid ON property USING btree (account_realm_id);
CREATE INDEX xif_property_dns_dom_collect ON property USING btree (dns_domain_collection_id);
CREATE INDEX xif_property_nblk_coll_id ON property USING btree (netblock_collection_id);
CREATE INDEX xif_property_person_id ON property USING btree (person_id);
CREATE INDEX xif_property_prop_coll_id ON property USING btree (property_collection_id);
CREATE INDEX xif_property_pv_nblkcol_id ON property USING btree (property_value_nblk_coll_id);
CREATE INDEX xif_property_val_prsnid ON property USING btree (property_value_person_id);
CREATE INDEX xifprop_account_id ON property USING btree (account_id);
CREATE INDEX xifprop_acctcol_id ON property USING btree (account_collection_id);
CREATE INDEX xifprop_compid ON property USING btree (company_id);
CREATE INDEX xifprop_devcolid ON property USING btree (device_collection_id);
CREATE INDEX xifprop_dnsdomid ON property USING btree (dns_domain_id);
CREATE INDEX xifprop_nmtyp ON property USING btree (property_name, property_type);
CREATE INDEX xifprop_osid ON property USING btree (operating_system_id);
CREATE INDEX xifprop_pval_acct_colid ON property USING btree (property_value_account_coll_id);
CREATE INDEX xifprop_pval_compid ON property USING btree (property_value_company_id);
CREATE INDEX xifprop_pval_pwdtyp ON property USING btree (property_value_password_type);
CREATE INDEX xifprop_pval_swpkgid ON property USING btree (property_value_sw_package_id);
CREATE INDEX xifprop_pval_tokcolid ON property USING btree (property_value_token_col_id);
CREATE INDEX xifprop_site_code ON property USING btree (site_code);

-- CHECK CONSTRAINTS
ALTER TABLE property ADD CONSTRAINT ckc_prop_isenbld
	CHECK (is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK property and company_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_compcoll_id
	FOREIGN KEY (company_collection_id) REFERENCES company_collection(company_collection_id);
-- consider FK property and layer2_network_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l2_netcollid
	FOREIGN KEY (layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id);
-- consider FK property and layer3_network_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l3_netcoll_id
	FOREIGN KEY (layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id);
-- consider FK property and operating_system_snapshot
ALTER TABLE property
	ADD CONSTRAINT fk_prop_os_snapshot
	FOREIGN KEY (operating_system_snapshot_id) REFERENCES operating_system_snapshot(operating_system_snapshot_id);
-- consider FK property and device_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_pv_devcolid
	FOREIGN KEY (property_value_device_coll_id) REFERENCES device_collection(device_collection_id);
-- consider FK property and service_environment_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_svc_env_coll_id
	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);
-- consider FK property and account_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_acct_col
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK property and account
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctid
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK property and account_realm
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctrealmid
	FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id);
-- consider FK property and company
ALTER TABLE property
	ADD CONSTRAINT fk_property_compid
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK property and device_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_devcolid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
-- consider FK property and dns_domain_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_dns_dom_collect
	FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);
-- consider FK property and dns_domain
ALTER TABLE property
	ADD CONSTRAINT fk_property_dnsdomid
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK property and netblock_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_nblk_coll_id
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK property and val_property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK property and operating_system
ALTER TABLE property
	ADD CONSTRAINT fk_property_osid
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
-- consider FK property and person
ALTER TABLE property
	ADD CONSTRAINT fk_property_person_id
	FOREIGN KEY (person_id) REFERENCES person(person_id);
-- consider FK property and property_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_prop_coll_id
	FOREIGN KEY (property_collection_id) REFERENCES property_collection(property_collection_id);
-- consider FK property and netblock_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pv_nblkcol_id
	FOREIGN KEY (property_value_nblk_coll_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK property and account_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_acct_colid
	FOREIGN KEY (property_value_account_coll_id) REFERENCES account_collection(account_collection_id);
-- consider FK property and company
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_compid
	FOREIGN KEY (property_value_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK property and val_password_type
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_pwdtyp
	FOREIGN KEY (property_value_password_type) REFERENCES val_password_type(password_type);
-- consider FK property and sw_package
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_swpkgid
	FOREIGN KEY (property_value_sw_package_id) REFERENCES sw_package(sw_package_id);
-- consider FK property and token_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_tokcolid
	FOREIGN KEY (property_value_token_col_id) REFERENCES token_collection(token_collection_id);
-- consider FK property and site
ALTER TABLE property
	ADD CONSTRAINT fk_property_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);
-- consider FK property and person
ALTER TABLE property
	ADD CONSTRAINT fk_property_val_prsnid
	FOREIGN KEY (property_value_person_id) REFERENCES person(person_id);
-- consider FK property and network_range
ALTER TABLE property
	ADD CONSTRAINT r_784
	FOREIGN KEY (network_range_id) REFERENCES network_range(network_range_id);

-- TRIGGERS
-- consider NEW oid 1364902
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
CREATE TRIGGER trigger_validate_property BEFORE INSERT OR UPDATE ON property FOR EACH ROW EXECUTE PROCEDURE validate_property();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'property');
ALTER SEQUENCE property_property_id_seq
	 OWNED BY property.property_id;
DROP TABLE IF EXISTS property_v69;
DROP TABLE IF EXISTS audit.property_v69;
-- DONE DEALING WITH TABLE property [1353605]
--------------------------------------------------------------------
--
-- Process trigger procs in jazzhands
--
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_collection_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.account_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	act	val_account_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	act
	FROM	val_account_collection_type
	WHERE	account_collection_type =
		(select account_collection_type from account_collection
			where account_collection_id = NEW.account_collection_id);

	IF act.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Account Collections of type % may not be hierarcical',
			act.account_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_collection_member_enforce');
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

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_enforce_is_enabled');
CREATE OR REPLACE FUNCTION jazzhands.account_enforce_is_enabled()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	correctval	char(1);
BEGIN
	SELECT is_enabled INTO correctval
	FROM val_person_status
	WHERE person_status = NEW.account_status;

	IF TG_OP = 'INSERT' THEN
		IF NEW.is_enabled is NULL THEN
			NEW.is_enabled = correctval;
		ELSIF NEW.is_enabled != correctval THEN
			RAISE EXCEPTION 'May not set IS_ENABLED to an invalid value (%) for given account_status: %', NEW.is_enabled, NEW.account_status
				USING errcode = 'integrity_constraint_violation';
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.account_status != OLD.account_status THEN
			IF NEW.is_enabled != correctval THEN
				NEW.is_enabled := correctval;
			END IF;
		ELSIF NEW.is_enabled != correctval THEN
			RAISE EXCEPTION 'May not update IS_ENABLED to an invalid value (%->%) for given account_status: %', OLD.account_status, NEW.account_status, NEW.is_enabled
			USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_validate_login');
CREATE OR REPLACE FUNCTION jazzhands.account_validate_login()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	regexp		text;
	correctval	char(1);
BEGIN
	SELECT property_value
	INTO   regexp
	FROM	property
	WHERE	account_realm_id = NEW.account_realm_id
	AND		property_name = 'login_restriction'
	AND		property_type = 'Defaults';

	IF FOUND THEN
		-- ~ '[^-/@a-z0-9_]+' THEN
		IF NEW.login  ~ regexp THEN
			RAISE EXCEPTION 'May not set login to an invalid value (%)', NEW.login
				USING errcode = 'integrity_constraint_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'automated_ac_on_person_company');
CREATE OR REPLACE FUNCTION jazzhands.automated_ac_on_person_company()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_r		RECORD;
BEGIN
	IF ( TG_OP = 'INSERT' OR TG_OP = 'UPDATE' ) THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_company USING (person_id,company_id)
		WHERE	account_role = 'primary'
		AND		person_id = NEW.person_id
		AND		company_id = NEW.company_id;

		IF ( TG_OP = 'INSERT' OR ( TG_OP = 'UPDATE' AND 
				NEW.manager_person_id != OLD.manager_person_id ) 
		) THEN
			-- update the person's manager to match
			WITH RECURSIVE map As (
				SELECT account_id as root_account_id,
					account_id, login, manager_account_id, manager_login
				FROM v_account_manager_map
				UNION
				SELECT map.root_account_id, m.account_id, m.login,
					m.manager_account_id, m.manager_login 
					from v_account_manager_map m
						join map on m.account_id = map.manager_account_id
			), x AS ( SELECT auto_ac_manip.make_auto_report_acs_right(
						account_id := manager_account_id,
						account_realm_id := account_realm_id,
						login := manager_login)
					FROM map m
							join v_corp_family_account a ON
								a.account_id = m.root_account_id
					WHERE a.person_id = NEW.person_id
					AND a.company_id = NEW.company_id
			) SELECT count(*) into _tally from x;
			IF TG_OP = 'UPDATE' THEN
				PERFORM auto_ac_manip.make_auto_report_acs_right(
							account_id := account_id)
				FROM    v_corp_family_account
				WHERE   account_role = 'primary'
				AND     is_enabled = 'Y'
				AND     person_id = OLD.manager_person_id;
			END IF;
		END IF;
	END IF;

	IF ( TG_OP = 'DELETE' OR TG_OP = 'UPDATE' ) THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_company USING (person_id,company_id)
		WHERE	account_role = 'primary'
		AND		person_id = OLD.person_id
		AND		company_id = OLD.company_id;
	END IF;
	IF ( TG_OP = 'UPDATE' ) THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_company USING (person_id,company_id)
		WHERE	account_role = 'primary'
		AND		person_id = NEW.person_id
		AND		company_id = NEW.company_id;
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'check_account_colllection_hier_loop');
CREATE OR REPLACE FUNCTION jazzhands.check_account_colllection_hier_loop()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.account_collection_id = NEW.child_account_collection_id THEN
		RAISE EXCEPTION 'Account Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'check_device_colllection_hier_loop');
CREATE OR REPLACE FUNCTION jazzhands.check_device_colllection_hier_loop()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.device_collection_id = NEW.parent_device_collection_id THEN
		RAISE EXCEPTION 'device Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'check_netblock_colllection_hier_loop');
CREATE OR REPLACE FUNCTION jazzhands.check_netblock_colllection_hier_loop()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.netblock_collection_id = NEW.child_netblock_collection_id THEN
		RAISE EXCEPTION 'Netblock Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'check_svcenv_colllection_hier_loop');
CREATE OR REPLACE FUNCTION jazzhands.check_svcenv_colllection_hier_loop()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.service_env_collection_id = 
		NEW.child_service_env_coll_id THEN
			RAISE EXCEPTION 'svcenv Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'check_token_colllection_hier_loop');
CREATE OR REPLACE FUNCTION jazzhands.check_token_colllection_hier_loop()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.token_collection_id = NEW.child_token_collection_id THEN
		RAISE EXCEPTION 'token Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'company_collection_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.company_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dct	val_company_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_company_collection_type
	WHERE	company_collection_type =
		(select company_collection_type from company_collection
			where company_collection_id = NEW.company_collection_id);

	IF dct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Company Collections of type % may not be hierarcical',
			dct.company_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'company_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.company_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dct	val_company_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_company_collection_type
	WHERE	company_collection_type =
		(select company_collection_type from company_collection
			where company_collection_id = NEW.company_collection_id);

	IF dct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from company_collection_company
		  where company_collection_id = NEW.company_collection_id;
		IF tally > dct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF dct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from company_collection_company
		  		inner join company_collection using (company_collection_id)
		  where company_id = NEW.company_id
		  and	company_collection_type = dct.company_collection_type;
		IF tally > dct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Company may not be a member of more than % collections of type %',
				dct.MAX_NUM_COLLECTIONS, dct.company_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'create_new_unix_account');
CREATE OR REPLACE FUNCTION jazzhands.create_new_unix_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	unix_id 		INTEGER;
	_account_collection_id 	INTEGER;
	_arid			INTEGER;
BEGIN
	--
	-- This should be a property that shows which account collections
	-- get unix accounts created by default, but the mapping of unix-groups
	-- to account collection across realms needs to be resolved
	--
	SELECT  account_realm_id
	INTO    _arid
	FROM    property
	WHERE   property_name = '_root_account_realm_id'
	AND     property_type = 'Defaults';

	IF _arid IS NOT NULL AND NEW.account_realm_id = _arid THEN
		IF NEW.person_id != 0 THEN
			PERFORM person_manip.setup_unix_account(
				in_account_id := NEW.account_id,
				in_account_type := NEW.account_type
			);
		END IF;
	END IF;
	RETURN NEW;	
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'del_v_corp_family_account');
CREATE OR REPLACE FUNCTION jazzhands.del_v_corp_family_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	acct_realm_id	account_realm.account_realm_id%TYPE;
BEGIN
	SELECT	account_realm_id
	INTO	acct_realm_id
	FROM	property
	WHERE	property_name = '_root_account_realm_id'
	AND	property_type = 'Defaults';

	IF acct_realm_id != OLD.account_realm_id THEN
		RAISE EXCEPTION 'Invalid account_realm_id'
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	DELETE FROM account where account_id = OLD.account_id;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_collection_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dct	val_dns_domain_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_dns_domain_collection_type
	WHERE	dns_domain_collection_type =
		(select dns_domain_collection_type from dns_domain_collection
			where dns_domain_collection_id = NEW.dns_domain_collection_id);

	IF dct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'DNS Domain Collections of type % may not be hierarcical',
			dct.dns_domain_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dct	val_dns_domain_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_dns_domain_collection_type
	WHERE	dns_domain_collection_type =
		(select dns_domain_collection_type from dns_domain_collection
			where dns_domain_collection_id = NEW.dns_domain_collection_id);

	IF dct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from dns_domain_collection_dns_dom
		  where dns_domain_collection_id = NEW.dns_domain_collection_id;
		IF tally > dct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF dct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from dns_domain_collection_dns_dom
		  		inner join dns_domain_collection using (dns_domain_collection_id)
		  where dns_domain_id = NEW.dns_domain_id
		  and	dns_domain_collection_type = dct.dns_domain_collection_type;
		IF tally > dct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'DNS Domain may not be a member of more than % collections of type %',
				dct.MAX_NUM_COLLECTIONS, dct.dns_domain_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'fix_person_image_oid_ownership');
CREATE OR REPLACE FUNCTION jazzhands.fix_person_image_oid_ownership()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
   b	integer;
   str	varchar;
BEGIN
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

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'ins_v_corp_family_account');
CREATE OR REPLACE FUNCTION jazzhands.ins_v_corp_family_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	acct_realm_id	account_realm.account_realm_id%TYPE;
BEGIN
	SELECT	account_realm_id
	INTO	acct_realm_id
	FROM	property
	WHERE	property_name = '_root_account_realm_id'
	AND	property_type = 'Defaults';

	IF acct_realm_id != NEW.account_realm_id THEN
		RAISE EXCEPTION 'Invalid account_realm_id'
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	INSERT INTO account VALUES (NEW.*);

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'layer2_network_collection_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.layer2_network_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	act	val_layer2_network_coll_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type =
		(select layer2_network_collection_type from layer2_network_collection
			where layer2_network_collection_id = NEW.layer2_network_collection_id);

	IF act.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Layer2 Network Collections of type % may not be hierarcical',
			act.layer2_network_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'layer2_network_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.layer2_network_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	act	val_layer2_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type =
		(select layer2_network_collection_type from layer2_network_collection
			where layer2_network_collection_id = NEW.layer2_network_collection_id);

	IF act.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l2_network_coll_l2_network
		  where layer2_network_collection_id = NEW.layer2_network_collection_id;
		IF tally > act.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF act.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l2_network_coll_l2_network
		  		inner join layer2_network_collection using (layer2_network_collection_id)
		  where layer2_network_id = NEW.layer2_network_id
		  and	layer2_network_collection_type = act.layer2_network_collection_type;
		IF tally > act.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Layer2 network may not be a member of more than % collections of type %',
				act.MAX_NUM_COLLECTIONS, act.layer2_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'layer3_network_collection_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.layer3_network_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	act	val_layer3_network_coll_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type =
		(select layer3_network_collection_type from layer3_network_collection
			where layer3_network_collection_id = NEW.layer3_network_collection_id);

	IF act.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Layer3 Network Collections of type % may not be hierarcical',
			act.layer3_network_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'layer3_network_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.layer3_network_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	act	val_layer3_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type =
		(select layer3_network_collection_type from layer3_network_collection
			where layer3_network_collection_id = NEW.layer3_network_collection_id);

	IF act.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l3_network_coll_l3_network
		  where layer3_network_collection_id = NEW.layer3_network_collection_id;
		IF tally > act.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF act.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l3_network_coll_l3_network
		  		inner join layer3_network_collection using (layer3_network_collection_id)
		  where layer3_network_id = NEW.layer3_network_id
		  and	layer3_network_collection_type = act.layer3_network_collection_type;
		IF tally > act.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Layer3 Network may not be a member of more than % collections of type %',
				act.MAX_NUM_COLLECTIONS, act.layer3_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock_collection_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.netblock_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	nct	val_netblock_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	nct
	FROM	val_netblock_collection_type
	WHERE	netblock_collection_type =
		(select netblock_collection_type from netblock_collection
			where netblock_collection_id = NEW.netblock_collection_id);

	IF nct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Netblock Collections of type % may not be hierarcical',
			nct.netblock_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.netblock_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
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
			RAISE EXCEPTION 'Netblock may not be a member of more than % collections of type %',
				nct.MAX_NUM_COLLECTIONS, nct.netblock_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'property_collection_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.property_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	pct	val_property_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	pct
	FROM	val_property_collection_type
	WHERE	property_collection_type =
		(select property_collection_type from property_collection
			where property_collection_id = NEW.property_collection_id);

	IF pct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Property Collections of type % may not be hierarcical',
			pct.property_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'property_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.property_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	pct	val_property_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	pct
	FROM	val_property_collection_type
	WHERE	property_collection_type =
		(select property_collection_type from property_collection
			where property_collection_id = NEW.property_collection_id);

	IF pct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from property_collection_property
		  where property_collection_id = NEW.property_collection_id;
		IF tally > pct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF pct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from property_collection_property
		  		inner join property_collection using (property_collection_id)
		  where	
				property_name = NEW.property_name
		  and	property_type = NEW.property_type
		  and	property_collection_type = pct.property_collection_type;
		IF tally > pct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Property may not be a member of more than % collections of type %',
				pct.MAX_NUM_COLLECTIONS, pct.property_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_coll_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.service_environment_coll_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	svcenvt	val_service_env_coll_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	svcenvt
	FROM	val_service_env_coll_type
	WHERE	service_env_collection_type =
		(select service_env_collection_type 
			from service_environment_collection
			where service_env_collection_id = 
				NEW.service_env_collection_id);

	IF svcenvt.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Service Environment Collections of type % may not be hierarcical',
			svcenvt.service_env_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.service_environment_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	svcenvt	val_service_env_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	svcenvt
	FROM	val_service_env_coll_type
	WHERE	service_env_collection_type =
		(select service_env_collection_type 
			from service_environment_collection
			where service_env_collection_id = 
				NEW.service_env_collection_id);

	IF svcenvt.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from svc_environment_coll_svc_env
		  where service_env_collection_id = NEW.service_env_collection_id;
		IF tally > svcenvt.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF svcenvt.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from svc_environment_coll_svc_env
		  		inner join service_environment_collection 
					USING (service_env_collection_id)
		  where service_environment_id = NEW.service_environment_id
		  and	service_env_collection_type = 
					svcenvt.service_env_collection_type;
		IF tally > svcenvt.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Service Environment may not be a member of more than % collections of type %',
				svcenvt.MAX_NUM_COLLECTIONS, svcenvt.service_env_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'token_collection_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.token_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tct	val_token_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	tct
	FROM	val_token_collection_type
	WHERE	token_collection_type =
		(select token_collection_type from token_collection
			where token_collection_id = NEW.token_collection_id);

	IF tct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Token Collections of type % may not be hierarcical',
			tct.token_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'token_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.token_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tct	val_token_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	tct
	FROM	val_token_collection_type
	WHERE	token_collection_type =
		(select token_collection_type from token_collection
			where token_collection_id = NEW.token_collection_id);

	IF tct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from token_collection_token
		  where token_collection_id = NEW.token_collection_id;
		IF tally > tct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF tct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from token_collection_token
		  		inner join token_collection using (token_collection_id)
		  where token_id = NEW.token_id
		  and	token_collection_type = tct.token_collection_type;
		IF tally > tct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Token may not be a member of more than % collections of type %',
				tct.MAX_NUM_COLLECTIONS, tct.token_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'upd_v_corp_family_account');
CREATE OR REPLACE FUNCTION jazzhands.upd_v_corp_family_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	acct_realm_id	account_realm.account_realm_id%TYPE;
	setstr		TEXT;
	_r		RECORD;
	val		TEXT;
BEGIN
	SELECT	account_realm_id
	INTO	acct_realm_id
	FROM	property
	WHERE	property_name = '_root_account_realm_id'
	AND	property_type = 'Defaults';

	IF acct_realm_id != OLD.account_realm_id OR
			acct_realm_id != NEW.account_realm_id THEN
		RAISE EXCEPTION 'Invalid account_realm_id'
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	setstr = '';
	FOR _r IN SELECT * FROM json_each_text( row_to_json(NEW) )
	LOOP
		IF _r.key NOT SIMILAR TO 'data_(ins|upd)_(user|date)' THEN
			EXECUTE 'SELECT ' || _r.key ||' FROM account
				WHERE account_id = ' || OLD.account_id
				INTO val;
			IF ( _r.value IS NULL  AND val IS NOT NULL) OR
				( _r.value IS NOT NULL AND val IS NULL) OR
				(_r.value::text NOT SIMILAR TO val::text) THEN
				-- RAISE NOTICE 'Changing %: "%" to "%"', _r.key, val, _r.value;
				IF char_length(setstr) > 0 THEN
					setstr = setstr || ',
					';
				END IF;
				IF _r.value IS NOT  NULL THEN
					setstr = setstr || _r.key || ' = ' ||  
						quote_nullable(_r.value) || ' ' ;
				ELSE
					setstr = setstr || _r.key || ' = ' ||  
						' NULL ' ;
				END IF;
			END IF;
		END IF;
	END LOOP;


	IF char_length(setstr) > 0 THEN
		setstr = 'UPDATE account SET ' || setstr || '
			WHERE	account_id = ' || OLD.account_id;
		-- RAISE NOTICE 'executing %', setstr;
		EXECUTE setstr;
	END IF;
	RETURN NEW;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'upd_v_hotpants_token');
CREATE OR REPLACE FUNCTION jazzhands.upd_v_hotpants_token()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
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

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'update_peraccount_account_collection');
CREATE OR REPLACE FUNCTION jazzhands.update_peraccount_account_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	def_acct_rlm	account_realm.account_realm_id%TYPE;
	acid			account_collection.account_collection_id%TYPE;
DECLARE
	newname	TEXT;
BEGIN
	newname = concat(NEW.login, '_', NEW.account_id);
	if TG_OP = 'INSERT' THEN
		insert into account_collection
			(account_collection_name, account_collection_type)
		values
			(newname, 'per-account')
		RETURNING account_collection_id INTO acid;
		insert into account_collection_account
			(account_collection_id, account_id)
		VALUES
			(acid, NEW.account_id);
	END IF;

	IF TG_OP = 'UPDATE' AND OLD.login != NEW.login THEN
		UPDATE	account_collection
		    set	account_collection_name = newname
		  where	account_collection_type = 'per-account'
		    and	account_collection_id = (
				SELECT	account_collection_id
		  		FROM	account_collection ac
						INNER JOIN account_collection_account aca
							USING (account_collection_id)
		 		WHERE	aca.account_id = OLD.account_Id
		   		AND	ac.account_collection_type = 'per-account'
			);
	END IF;
	return NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_status_enabled_migration_enforce');
CREATE OR REPLACE FUNCTION jazzhands.val_person_status_enabled_migration_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF ( NEW.is_disabled IS NOT NULL AND NEW.is_enabled IS NOT NULL ) THEN
			RAISE EXCEPTION 'May not set both IS_ENABLED and IS_DISABLED.  Set IS_ENABLED only.'
				USING errcode = 'integrity_constraint_violation';
		END IF;

		IF NEW.is_enabled IS NOT NULL THEN
			IF NEW.is_enabled = 'Y' THEN
				NEW.is_disabled := 'N';
			ELSE
				NEW.is_disabled := 'Y';
			END IF;
		ELSIF NEW.is_disabled IS NOT NULL THEN
			IF NEW.is_disabled = 'Y' THEN
				NEW.is_enabled := 'N';
			ELSE
				NEW.is_enabled := 'Y';
			END IF;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF ( OLD.is_disabled != NEW.is_disabled AND
				OLD.is_enabled != NEW.is_enabled ) THEN
			RAISE EXCEPTION 'May not update both IS_ENABLED and IS_DISABLED.  Update IS_ENABLED only.'
				USING errcode = 'integrity_constraint_violation';
		END IF;

		IF OLD.is_enabled != NEW.is_enabled THEN
			IF NEW.is_enabled = 'Y' THEN
				NEW.is_disabled := 'N';
			ELSE
				NEW.is_disabled := 'Y';
			END IF;
		ELSIF OLD.is_disabled != NEW.is_disabled THEN
			IF NEW.is_disabled = 'Y' THEN
				NEW.is_enabled := 'N';
			ELSE
				NEW.is_enabled := 'Y';
			END IF;
		END IF;
	END IF;

	IF NEW.is_enabled = NEW.is_disabled THEN
		RAISE NOTICE 'is_enabled=is_disabled.  This should never happen'
			USING  errcode = 'integrity_constraint_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_account_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_account_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.account_collection_type != NEW.account_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.account_collection_type = OLD.account_collection_type
		AND	p.account_collection_id = NEW.account_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'account_collection % of type % is used by % restricted properties.',
				NEW.account_collection_id, NEW.account_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_company_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_company_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.company_collection_type != NEW.company_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.company_collection_type = OLD.company_collection_type
		AND	p.company_collection_id = NEW.company_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'company_collection % of type % is used by % restricted properties.',
				NEW.company_collection_id, NEW.company_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_device_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_device_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.device_collection_type != NEW.device_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.device_collection_type = OLD.device_collection_type
		AND	p.device_collection_id = NEW.device_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'device_collection % of type % is used by % restricted properties.',
				NEW.device_collection_id, NEW.device_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;	
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_dns_domain_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_dns_domain_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.dns_domain_collection_type != NEW.dns_domain_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.dns_domain_collection_type = OLD.dns_domain_collection_type
		AND	p.dns_domain_collection_id = NEW.dns_domain_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'dns_domain_collection % of type % is used by % restricted properties.',
				NEW.dns_domain_collection_id, NEW.dns_domain_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;	
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_layer2_network_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_layer2_network_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.layer2_network_collection_type != NEW.layer2_network_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.layer2_network_collection_type = OLD.layer2_network_collection_type
		AND	p.layer2_network_collection_id = NEW.layer2_network_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'layer2_network_collection % of type % is used by % restricted properties.',
				NEW.layer2_network_collection_id, NEW.layer2_network_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;	
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_layer3_network_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_layer3_network_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.layer3_network_collection_type != NEW.layer3_network_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.layer3_network_collection_type = OLD.layer3_network_collection_type
		AND	p.layer3_network_collection_id = NEW.layer3_network_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'layer3_network_collection % of type % is used by % restricted properties.',
				NEW.layer3_network_collection_id, NEW.layer3_network_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;	
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.netblock_collection_type != NEW.netblock_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.netblock_collection_type = OLD.netblock_collection_type
		AND	p.netblock_collection_id = NEW.netblock_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'netblock_collection % of type % is used by % restricted properties.',
				NEW.netblock_collection_id, NEW.netblock_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;	
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_network_range');
CREATE OR REPLACE FUNCTION jazzhands.validate_network_range()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	v_nrt	val_network_range_type%ROWTYPE;
BEGIN
	SELECT	*
	INTO	v_nrt
	FROM	val_network_range_type
	WHERE	network_range_type = NEW.network_range_type;

	IF NEW.dns_domain_id IS NULL AND v_nrt.dns_domain_required = 'REQUIRED' THEN
		RAISE EXCEPTION 'For type %, dns_domain_id is required.',
			NEW.network_range_type
			USING ERRCODE = 'not_null_violation';
	ELSIF NEW.dns_domain_id IS NOT NULL AND
			v_nrt.dns_domain_required = 'PROHIBITED' THEN
		RAISE EXCEPTION 'For type %, dns_domain_id is prohibited.',
			NEW.network_range_type
			USING ERRCODE = 'not_null_violation';
	END IF;
	RETURN NEW;
END; $function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_property_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_property_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.property_collection_type != NEW.property_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.property_collection_type = OLD.property_collection_type
		AND	p.property_collection_id = NEW.property_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'property_collection % of type % is used by % restricted properties.',
				NEW.property_collection_id, NEW.property_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_service_env_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_service_env_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.service_env_collection_type != NEW.service_env_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.service_env_collection_type = OLD.service_env_collection_type
		AND	p.service_env_collection_id = NEW.service_env_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'service_env_collection % of type % is used by % restricted properties.',
				NEW.service_env_collection_id, NEW.service_env_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;	
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_val_network_range_type');
CREATE OR REPLACE FUNCTION jazzhands.validate_val_network_range_type()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.dns_domain_required = 'REQUIRED' THEN
		PERFORM
		FROM	network_range
		WHERE	network_range_type = NEW.network_range_type
		AND		dns_domain_id IS NULL;

		IF FOUND THEN
			RAISE EXCEPTION 'dns_domain_id is not set on some ranges'
				USING ERRCODE = 'not_null_violation';
		END IF;
	ELSIF NEW.dns_domain_required = 'PROHIBITED' THEN
		PERFORM
		FROM	network_range
		WHERE	network_range_type = NEW.network_range_type
		AND		dns_domain_id IS NOT NULL;

		IF FOUND THEN
			RAISE EXCEPTION 'dns_domain_id is set on some ranges'
				USING ERRCODE = 'not_null_violation';
		END IF;
	END IF;
	RETURN NEW;
END; $function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.account_change_realm_aca_realm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_account
			JOIN account_collection USING (account_collection_id)
			JOIN val_account_collection_type vt USING (account_collection_type)
	WHERE	vt.account_realm_id IS NOT NULL
	AND		vt.account_realm_id != NEW.account_realm_id;
	
	IF _tally > 0 THEN
		RAISE EXCEPTION 'New account realm is part of % account collections with a type restriction',
			_tally
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
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

-- New function
CREATE OR REPLACE FUNCTION jazzhands.account_collection_hier_realm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_pat	val_account_collection_type%ROWTYPE;
	_cat	val_account_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	_pat
	FROM	val_account_collection_type
		JOIN account_collection USING (account_collection_type)
	WHERE
		account_collection_id = NEW.account_collection_id;
	SELECT *
	INTO	_cat
	FROM	val_account_collection_type
		JOIN account_collection USING (account_collection_type)
	WHERE
		account_collection_id = NEW.child_account_collection_id;

	-- no restrictions, so do not care
	IF _pat.account_realm_id IS DISTINCT FROM _cat.account_realm_id THEN
		RAISE EXCEPTION 'account realm restrictions on parent %/child % do not match" ',
			NEW.account_collection_id, NEW.child_account_collection_id
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.account_collection_realm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_at		val_account_collection_type%ROWTYPE;
	_tally	integer;
BEGIN
	SELECT * INTO _at FROM val_account_collection_type
	WHERE account_collection_type = NEW.account_collection_type;

	IF _at.account_realm_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_account
			JOIN account a USING (account_id)
	WHERE	account_collection_id = NEW.account_collection_id
	AND		a.account_realm_id != _at.account_realm_id;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Unable to set account_realm restriction because there are accounts assigned that do not match it'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_hier h
			JOIN account_collection pac USING (account_collection_id)
			JOIN val_account_collection_type pat USING (account_collection_type)
			JOIN account_collection cac ON
				h.child_account_collection_id = cac.account_collection_id
			JOIN val_account_collection_type cat ON
				cac.account_collection_type = cat.account_collection_type
	WHERE	(
				pac.account_collection_id = NEW.account_collection_id
			OR		cac.account_collection_id = NEW.account_collection_id
			)
	AND		pat.account_realm_id IS DISTINCT FROM cat.account_realm_id
	;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Unable to set account_realm restriction because there are account collections in the hierarchy that do not match'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.account_collection_type_realm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF NEW.account_realm_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_account
			JOIN account_collection USING (account_collection_id)
			JOIN account a USING (account_id)
	WHERE	account_collection_type = NEW.account_collection_type
	AND		a.account_realm_id != NEW.account_realm_id;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Unable to set account_realm restriction because there are accounts assigned that do not match it'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	-- This is probably useless.
	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_hier h
			JOIN account_collection pac USING (account_collection_id)
			JOIN val_account_collection_type pat USING (account_collection_type)
			JOIN account_collection cac ON
				h.child_account_collection_id = cac.account_collection_id
			JOIN val_account_collection_type cat ON
				cac.account_collection_type = cat.account_collection_type
	WHERE	(
				pac.account_collection_type = NEW.account_collection_type
			OR
				cac.account_collection_type = NEW.account_collection_type
			)
	AND		(
				pat.account_realm_id IS DISTINCT FROM NEW.account_realm_id
			OR
				cat.account_realm_id IS DISTINCT FROM NEW.account_realm_id
			)
	;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Unable to set account_realm restriction because there are account collections in the hierarchy that do not match'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

--
-- Process trigger procs in net_manip
--
--
-- Process trigger procs in network_strings
--
--
-- Process trigger procs in time_util
--
--
-- Process trigger procs in dns_utils
--
--
-- Process trigger procs in person_manip
--
--
-- Process trigger procs in auto_ac_manip
--
--
-- Process trigger procs in company_manip
--
--
-- Process trigger procs in token_utils
--
--
-- Process trigger procs in port_support
--
--
-- Process trigger procs in port_utils
--
--
-- Process trigger procs in device_utils
--
--
-- Process trigger procs in netblock_utils
--
--
-- Process trigger procs in netblock_manip
--
--
-- Process trigger procs in physical_address_utils
--
--
-- Process trigger procs in component_utils
--
--
-- Process trigger procs in snapshot_manip
--
--
-- Process trigger procs in lv_manip
--
--
-- Process trigger procs in approval_utils
--
--
-- Process trigger procs in account_collection_manip
--
--
-- Process trigger procs in schema_support
--
--
-- Process trigger procs in script_hooks
--
-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
ALTER TABLE person_company_attr DROP CONSTRAINT IF EXISTS fk_pers_comp_attr_person_comp_;
ALTER TABLE person_company_attr
	ADD CONSTRAINT fk_pers_comp_attr_person_comp_
	FOREIGN KEY (company_id, person_id) REFERENCES person_company(company_id, person_id) DEFERRABLE;

-- index
-- triggers
CREATE TRIGGER trig_account_change_realm_aca_realm BEFORE UPDATE OF account_realm_id ON account FOR EACH ROW EXECUTE PROCEDURE account_change_realm_aca_realm();
CREATE TRIGGER trig_account_collection_realm AFTER UPDATE OF account_collection_type ON account_collection FOR EACH ROW EXECUTE PROCEDURE account_collection_realm();
CREATE TRIGGER trig_account_collection_account_realm AFTER INSERT OR UPDATE ON account_collection_account FOR EACH ROW EXECUTE PROCEDURE account_collection_account_realm();
CREATE TRIGGER trig_account_collection_hier_realm AFTER INSERT OR UPDATE ON account_collection_hier FOR EACH ROW EXECUTE PROCEDURE account_collection_hier_realm();

alter sequence audit.network_interface_netblock_seq restart;
insert into network_interface_netblock
        (network_interface_id, netblock_id)
select network_interface_id, netblock_id
from network_interface where
        (network_interface_id, netblock_id) NOT IN
                (SELECT network_interface_id, netblock_id
                from network_interface_netblock
                )
and netblock_id is not NULL;

CREATE TRIGGER trigger_net_int_netblock_to_nbn_compat_after AFTER INSERT OR DELETE OR UPDATE OF network_interface_id, netblock_id ON network_interface FOR EACH ROW EXECUTE PROCEDURE net_int_netblock_to_nbn_compat_after();
CREATE TRIGGER trigger_net_int_netblock_to_nbn_compat_before BEFORE DELETE ON network_interface FOR EACH ROW EXECUTE PROCEDURE net_int_netblock_to_nbn_compat_before();
CREATE TRIGGER trigger_network_interface_drop_tt_netint_ni AFTER INSERT OR DELETE OR UPDATE ON network_interface FOR EACH STATEMENT EXECUTE PROCEDURE network_interface_drop_tt();
CREATE TRIGGER trigger_network_interface_drop_tt_netint_nb AFTER INSERT OR DELETE OR UPDATE ON network_interface_netblock FOR EACH STATEMENT EXECUTE PROCEDURE network_interface_drop_tt();
CREATE TRIGGER trigger_network_interface_netblock_to_ni AFTER INSERT OR DELETE OR UPDATE ON network_interface_netblock FOR EACH ROW EXECUTE PROCEDURE network_interface_netblock_to_ni();

--- misc
-- backwards compatibility
insert into val_property (
        property_name, property_type, is_multivalue, property_data_type,
        description,
        permit_account_realm_id
) values (
        'login_restriction', 'Defaults', 'N', 'string',
        'per-account realm validation of login names',
        'REQUIRED'
);
INSERT INTO property (
	property_type, property_name, property_value, account_realm_id
) SELECT 'Defaults', 'login_restriction', '[^-/@a-z0-9_]+', account_realm_id
FROM account_realm;

COMMENT ON SCHEMA account_collection_manip IS 'part of jazzhands';
COMMENT ON SCHEMA script_hooks IS 'part of jazzhands';




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
