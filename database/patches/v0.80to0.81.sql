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

	--scan-tables
	--suffix=v80
	--col-default=should_generate_dns:'Y'
	--first
	property
	--first
	v_property
	--first
	network_interface_netblock
	--first
	v_network_interface_trans
	--first
	v_hotpants_device_collection
	--post
	post
	--reinsert-dir=i
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();
--
-- Process middle (non-trigger) schema jazzhands
--
-- New function
CREATE OR REPLACE FUNCTION jazzhands._validate_json_schema_type(type text, data jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  IF type = 'integer' THEN
    IF jsonb_typeof(data) != 'number' THEN
      RETURN false;
    END IF;
    IF trunc(data::text::numeric) != data::text::numeric THEN
      RETURN false;
    END IF;
  ELSE
    IF type != jsonb_typeof(data) THEN
      RETURN false;
    END IF;
  END IF;
  RETURN true;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_json_schema(schema jsonb, data jsonb, root_schema jsonb DEFAULT NULL::jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  prop text;
  item jsonb;
  path text[];
  types text[];
  pattern text;
  props text[];
BEGIN
  IF root_schema IS NULL THEN
    root_schema = schema;
  END IF;

  IF schema ? 'type' THEN
    IF jsonb_typeof(schema->'type') = 'array' THEN
      types = ARRAY(SELECT jsonb_array_elements_text(schema->'type'));
    ELSE
      types = ARRAY[schema->>'type'];
    END IF;
    IF (SELECT NOT bool_or(_validate_json_schema_type(type, data)) FROM unnest(types) type) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'properties' THEN
    FOR prop IN SELECT jsonb_object_keys(schema->'properties') LOOP
      IF data ? prop AND NOT validate_json_schema(schema->'properties'->prop, data->prop, root_schema) THEN
        RETURN false;
      END IF;
    END LOOP;
  END IF;

  IF schema ? 'required' AND jsonb_typeof(data) = 'object' THEN
    IF NOT ARRAY(SELECT jsonb_object_keys(data)) @>
           ARRAY(SELECT jsonb_array_elements_text(schema->'required')) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'items' AND jsonb_typeof(data) = 'array' THEN
    IF jsonb_typeof(schema->'items') = 'object' THEN
      FOR item IN SELECT jsonb_array_elements(data) LOOP
        IF NOT validate_json_schema(schema->'items', item, root_schema) THEN
          RETURN false;
        END IF;
      END LOOP;
    ELSE
      IF NOT (
        SELECT bool_and(i > jsonb_array_length(schema->'items') OR validate_json_schema(schema->'items'->(i::int - 1), elem, root_schema))
        FROM jsonb_array_elements(data) WITH ORDINALITY AS t(elem, i)
      ) THEN
        RETURN false;
      END IF;
    END IF;
  END IF;

  IF jsonb_typeof(schema->'additionalItems') = 'boolean' and NOT (schema->'additionalItems')::text::boolean AND jsonb_typeof(schema->'items') = 'array' THEN
    IF jsonb_array_length(data) > jsonb_array_length(schema->'items') THEN
      RETURN false;
    END IF;
  END IF;

  IF jsonb_typeof(schema->'additionalItems') = 'object' THEN
    IF NOT (
        SELECT bool_and(validate_json_schema(schema->'additionalItems', elem, root_schema))
        FROM jsonb_array_elements(data) WITH ORDINALITY AS t(elem, i)
        WHERE i > jsonb_array_length(schema->'items')
      ) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minimum' AND jsonb_typeof(data) = 'number' THEN
    IF data::text::numeric < (schema->>'minimum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maximum' AND jsonb_typeof(data) = 'number' THEN
    IF data::text::numeric > (schema->>'maximum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF COALESCE((schema->'exclusiveMinimum')::text::bool, FALSE) THEN
    IF data::text::numeric = (schema->>'minimum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF COALESCE((schema->'exclusiveMaximum')::text::bool, FALSE) THEN
    IF data::text::numeric = (schema->>'maximum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'anyOf' THEN
    IF NOT (SELECT bool_or(validate_json_schema(sub_schema, data, root_schema)) FROM jsonb_array_elements(schema->'anyOf') sub_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'allOf' THEN
    IF NOT (SELECT bool_and(validate_json_schema(sub_schema, data, root_schema)) FROM jsonb_array_elements(schema->'allOf') sub_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'oneOf' THEN
    IF 1 != (SELECT COUNT(*) FROM jsonb_array_elements(schema->'oneOf') sub_schema WHERE validate_json_schema(sub_schema, data, root_schema)) THEN
      RETURN false;
    END IF;
  END IF;

  IF COALESCE((schema->'uniqueItems')::text::boolean, false) THEN
    IF (SELECT COUNT(*) FROM jsonb_array_elements(data)) != (SELECT count(DISTINCT val) FROM jsonb_array_elements(data) val) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'additionalProperties' AND jsonb_typeof(data) = 'object' THEN
    props := ARRAY(
      SELECT key
      FROM jsonb_object_keys(data) key
      WHERE key NOT IN (SELECT jsonb_object_keys(schema->'properties'))
        AND NOT EXISTS (SELECT * FROM jsonb_object_keys(schema->'patternProperties') pat WHERE key ~ pat)
    );
    IF jsonb_typeof(schema->'additionalProperties') = 'boolean' THEN
      IF NOT (schema->'additionalProperties')::text::boolean AND jsonb_typeof(data) = 'object' AND NOT props <@ ARRAY(SELECT jsonb_object_keys(schema->'properties')) THEN
        RETURN false;
      END IF;
    ELSEIF NOT (
      SELECT bool_and(validate_json_schema(schema->'additionalProperties', data->key, root_schema))
      FROM unnest(props) key
    ) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? '$ref' THEN
    path := ARRAY(
      SELECT regexp_replace(regexp_replace(path_part, '~1', '/'), '~0', '~')
      FROM UNNEST(regexp_split_to_array(schema->>'$ref', '/')) path_part
    );
    -- ASSERT path[1] = '#', 'only refs anchored at the root are supported';
    IF NOT validate_json_schema(root_schema #> path[2:array_length(path, 1)], data, root_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'enum' THEN
    IF NOT EXISTS (SELECT * FROM jsonb_array_elements(schema->'enum') val WHERE val = data) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minLength' AND jsonb_typeof(data) = 'string' THEN
    IF char_length(data #>> '{}') < (schema->>'minLength')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maxLength' AND jsonb_typeof(data) = 'string' THEN
    IF char_length(data #>> '{}') > (schema->>'maxLength')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'not' THEN
    IF validate_json_schema(schema->'not', data, root_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maxProperties' AND jsonb_typeof(data) = 'object' THEN
    IF (SELECT count(*) FROM jsonb_object_keys(data)) > (schema->>'maxProperties')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minProperties' AND jsonb_typeof(data) = 'object' THEN
    IF (SELECT count(*) FROM jsonb_object_keys(data)) < (schema->>'minProperties')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maxItems' AND jsonb_typeof(data) = 'array' THEN
    IF (SELECT count(*) FROM jsonb_array_elements(data)) > (schema->>'maxItems')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minItems' AND jsonb_typeof(data) = 'array' THEN
    IF (SELECT count(*) FROM jsonb_array_elements(data)) < (schema->>'minItems')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'dependencies' THEN
    FOR prop IN SELECT jsonb_object_keys(schema->'dependencies') LOOP
      IF data ? prop THEN
        IF jsonb_typeof(schema->'dependencies'->prop) = 'array' THEN
          IF NOT (SELECT bool_and(data ? dep) FROM jsonb_array_elements_text(schema->'dependencies'->prop) dep) THEN
            RETURN false;
          END IF;
        ELSE
          IF NOT validate_json_schema(schema->'dependencies'->prop, data, root_schema) THEN
            RETURN false;
          END IF;
        END IF;
      END IF;
    END LOOP;
  END IF;

  IF schema ? 'pattern' AND jsonb_typeof(data) = 'string' THEN
    IF (data #>> '{}') !~ (schema->>'pattern') THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'patternProperties' AND jsonb_typeof(data) = 'object' THEN
    FOR prop IN SELECT jsonb_object_keys(data) LOOP
      FOR pattern IN SELECT jsonb_object_keys(schema->'patternProperties') LOOP
        RAISE NOTICE 'prop %s, pattern %, schema %', prop, pattern, schema->'patternProperties'->pattern;
        IF prop ~ pattern AND NOT validate_json_schema(schema->'patternProperties'->pattern, data->prop, root_schema) THEN
          RETURN false;
        END IF;
      END LOOP;
    END LOOP;
  END IF;

  IF schema ? 'multipleOf' AND jsonb_typeof(data) = 'number' THEN
    IF data::text::numeric % (schema->>'multipleOf')::numeric != 0 THEN
      RETURN false;
    END IF;
  END IF;

  RETURN true;
END;
$function$
;

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
-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'destroy_report_account_collections');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.destroy_report_account_collections ( account_id integer, account_realm_id integer, numrpt integer, numrlup integer );
CREATE OR REPLACE FUNCTION auto_ac_manip.destroy_report_account_collections(account_id integer, account_realm_id integer DEFAULT NULL::integer, numrpt integer DEFAULT NULL::integer, numrlup integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_account	account%ROWTYPE;
	_directac	account_collection.account_collection_id%TYPE;
	_rollupac	account_collection.account_collection_id%TYPE;
BEGIN
	IF account_realm_id IS NULL THEN
		EXECUTE '
			SELECT account_realm_id
			FROM	account
			WHERE	account_id = $1
		' INTO account_realm_id USING account_id;
	END IF;

	IF numrpt IS NULL THEN
		numrpt := auto_ac_manip.get_num_direct_reports(account_id, account_realm_id);
	END IF;
	IF numrpt = 0 THEN
		PERFORM auto_ac_manip.purge_report_account_collection(
			account_id := account_id,
			account_realm_id := account_realm_id,
			ac_type := 'AutomatedDirectsAC');
		RETURN;
	END IF;

	IF numrlup IS NULL THEN
		numrlup := auto_ac_manip.get_num_reports_with_reports(account_id, account_realm_id);
	END IF;
	IF numrlup = 0 THEN
		PERFORM auto_ac_manip.purge_report_account_collection(
			account_id := account_id,
			account_realm_id := account_realm_id,
			ac_type := 'AutomatedRollupsAC');
		RETURN;
	END IF;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'find_or_create_automated_ac');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.find_or_create_automated_ac ( account_id integer, ac_type character varying, account_realm_id integer, login character varying );
CREATE OR REPLACE FUNCTION auto_ac_manip.find_or_create_automated_ac(account_id integer, ac_type character varying, account_realm_id integer DEFAULT NULL::integer, login character varying DEFAULT NULL::character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_acname		text;
	_acid		account_collection.account_collection_id%TYPE;
BEGIN
	IF login is NULL THEN
		EXECUTE 'SELECT account_realm_id,login
			FROM account where account_id = $1'
			INTO account_realm_id,login USING account_id;
	END IF;

	IF ac_type = 'AutomatedDirectsAC' THEN
		_acname := concat(login, '-employee-directs');
	ELSIF ac_type = 'AutomatedRollupsAC' THEN
		_acname := concat(login, '-employee-rollup');
	ELSE
		RAISE EXCEPTION 'Do not know how to name Automated AC type %', ac_type;
	END IF;

	--
	-- Check to see if a -direct account collection exists already.  If not,
	-- create it.  There is a bit of a problem here if the name is not unique
	-- or otherwise messed up.  This will just raise errors.
	--
	EXECUTE 'SELECT ac.account_collection_id
			FROM account_collection ac
				INNER JOIN property p
					ON p.property_value_account_coll_id = ac.account_collection_id
		   WHERE ac.account_collection_name = $1
		    AND	ac.account_collection_type = $2
			AND	p.property_name = $3
			AND p.property_type = $4
			AND p.account_id = $5
			AND p.account_realm_id = $6
		' INTO _acid USING _acname, 'automated',
				ac_type, 'auto_acct_coll', account_id,
				account_realm_id;

	-- Assume the person is always in their own account collection, or if tehy
	-- are not someone took them out for a good reason.  (Thus, they are only
	-- added on creation).
	IF _acid IS NULL THEN
		EXECUTE 'INSERT INTO account_collection (
					account_collection_name, account_collection_type
				) VALUES ( $1, $2) RETURNING *
			' INTO _acid USING _acname, 'automated';

		IF ac_type = 'AutomatedDirectsAC' THEN
			EXECUTE 'INSERT INTO account_collection_account (
						account_collection_id, account_id
					) VALUES (  $1, $2 )
				' USING _acid, account_id;
		END IF;

		EXECUTE '
			INSERT INTO property (
				account_id,
				account_realm_id,
				property_name,
				property_type,
				property_value_account_coll_id
			)  VALUES ( $1, $2, $3, $4, $5)'
			USING account_id, account_realm_id,
				ac_type, 'auto_acct_coll', _acid;
	END IF;

	RETURN _acid;
END;
$function$
;

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
			AND		is_enabled = ''Y''
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
					manager_person_id, is_enabled
			FROM	account a
				INNER JOIN person_company USING (person_id, company_id)
			WHERE	account_role = $3
			AND		account_type = ''person''
			AND		person_company_relation = ''employee''
			AND		account_realm_id = $2
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
			WHERE reports.is_enabled = ''Y''
		), rank AS (
			SELECT *,
				rank() OVER (partition by account_id ORDER BY property_name desc)
					as rank
			FROM agg
		) SELECT count(*) from rank
		WHERE	manager_account_id =  $1
		AND	account_realm_id = $2
		AND	rank = 1;
	' INTO _numrlup USING account_id, account_realm_id, 'primary',
				'AutomatedDirectsAC','AutomatedRollupsAC','auto_acct_coll';

	RETURN _numrlup;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'make_personal_acs_right');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.make_personal_acs_right ( account_id integer );
CREATE OR REPLACE FUNCTION auto_ac_manip.make_personal_acs_right(account_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	EXECUTE '
	WITH ac AS (
		SELECT DISTINCT ac.*
		FROM	account_collection ac
				INNER JOIN property p USING (account_collection_id)
		WHERE	property_type = ''auto_acct_coll''
		AND		property_name in (''non_exempt'', ''exempt'',
					''management'', ''non_management'', ''full_time'',
					''non_full_time'', ''male'', ''female'', ''unspecified_gender'',
					''account_type'', ''person_company_relation'')
	), acct AS (
		    SELECT  a.account_id, a.account_type, a.account_role, parc.*,
			    pc.is_management, pc.is_full_time, pc.is_exempt,
			    p.gender, pc.person_company_relation
		     FROM   account a
			    INNER JOIN person_account_realm_company parc
				    USING (person_id, company_id, account_realm_id)
			    INNER JOIN person_company pc USING (person_id,company_id)
			    INNER JOIN person p USING (person_id)
			WHERE a.is_enabled = ''Y''
			AND a.account_role = ''primary''
		),
	list AS (
		SELECT  p.account_collection_id, a.account_id, a.account_type,
			a.account_role,
			a.person_id, a.company_id,
			ac.account_collection_name, ac.account_collection_type,
			p.property_name, p.property_type, p.property_value, p.property_id
		FROM    property p
			INNER JOIN ac USING (account_collection_id)
		    INNER JOIN acct a
				ON a.account_realm_id = p.account_realm_id
		WHERE   (p.company_id is NULL or a.company_id = p.company_id)
		    AND     property_type = ''auto_acct_coll''
			AND	( a.account_type = ''person''
				AND a.person_company_relation = ''employee''
				AND (
			(
				property_name =
					CASE WHEN a.is_exempt = ''N''
					THEN ''non_exempt''
					ELSE ''exempt'' END
				OR
				property_name =
					CASE WHEN a.is_management = ''N''
					THEN ''non_management''
					ELSE ''management'' END
				OR
				property_name =
					CASE WHEN a.is_full_time = ''N''
					THEN ''non_full_time''
					ELSE ''full_time'' END
				OR
				property_name =
					CASE WHEN a.gender = ''M'' THEN ''male''
					WHEN a.gender = ''F'' THEN ''female''
					ELSE ''unspecified_gender'' END
			) )
			OR (
			    property_name = ''account_type''
			    AND property_value = a.account_type
			    )
			OR (
			    property_name = ''person_company_relation''
			    AND property_value = a.person_company_relation
			    )
			)
	), ins AS (
			INSERT INTO account_collection_account
				(account_collection_id, account_id)
			SELECT	account_collection_id, account_id
			FROM	 list
			WHERE	 (account_collection_id, account_id) NOT IN
					(SELECT account_collection_id, account_id FROM
						account_collection_account
					JOIN ac USING (account_collection_id) )
			AND account_id = $1
		RETURNING *
	), del AS (
		DELETE
		FROM	 account_collection_account
		WHERE	 (account_collection_id, account_id) NOT IN
				 (SELECT account_collection_id, account_id FROM
					list JOIN ac USING (account_collection_id))
		AND		(account_collection_id, account_id) IN
				(SELECT account_collection_id,account_id from ac)
		AND account_id = $1 RETURNING *
	), combo AS (
		SELECT * from ins UNION select * FROM del
	) SELECT count(*)
		FROM combo
		JOIN account_collection USING (account_collection_id);
	' INTO _tally USING account_id;
	RETURN _tally;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'make_site_acs_right');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.make_site_acs_right ( account_id integer );
CREATE OR REPLACE FUNCTION auto_ac_manip.make_site_acs_right(account_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	EXECUTE '
	WITH ac AS (
		SELECT DISTINCT ac.*
		FROM	account_collection ac
				INNER JOIN property p USING (account_collection_id)
		WHERE	property_type = ''auto_acct_coll''
		AND		property_name in (''site'')
	), acct AS (
		    SELECT  a.account_id, a.account_type, a.account_role, parc.*,
			    pc.is_management, pc.is_full_time, pc.is_exempt,
			    p.gender, pc.person_company_relation
		     FROM   account a
			    INNER JOIN person_account_realm_company parc
				    USING (person_id, company_id, account_realm_id)
			    INNER JOIN person_company pc USING (person_id,company_id)
			    INNER JOIN person p USING (person_id)
			WHERE a.is_enabled = ''Y''
			AND a.account_role = ''primary''
	), list AS (
		SELECT  p.account_collection_id, a.account_id, a.account_type,
			a.account_role,
			a.person_id, a.company_id,
			ac.account_collection_name, ac.account_collection_type,
			p.property_name, p.property_type, p.property_value, p.property_id
		FROM    property p
			INNER JOIN ac USING (account_collection_id)
		    INNER JOIN acct a
				ON a.account_realm_id = p.account_realm_id
			INNER JOIN person_location pl on a.person_id = pl.person_id
		WHERE   (p.company_id is NULL or a.company_id = p.company_id)
		AND		a.person_company_relation = ''employee''
		AND		property_type = ''auto_acct_coll''
		AND		p.site_code = pl.site_code
		AND		property_name = ''site''
	), ins AS (
			INSERT INTO account_collection_account
				(account_collection_id, account_id)
			SELECT	account_collection_id, account_id
			FROM	 list
			WHERE	 (account_collection_id, account_id) NOT IN
					(SELECT account_collection_id, account_id FROM
						account_collection_account
					JOIN ac USING (account_collection_id) )
			AND account_id = $1
		RETURNING *
	), del AS (
		DELETE
		FROM	 account_collection_account
		WHERE	 (account_collection_id, account_id) NOT IN
				 (SELECT account_collection_id, account_id FROM
					list JOIN ac USING (account_collection_id))
		AND		(account_collection_id, account_id) IN
				(SELECT account_collection_id,account_id from ac)
		AND account_id = $1 RETURNING *
	), combo AS (
		SELECT * from ins UNION select * FROM del
	) SELECT count(*)
		FROM combo
		JOIN account_collection USING (account_collection_id);
	' INTO _tally USING account_id;
	RETURN _tally;
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
				FROM account
				WHERE account_id = $1
				AND is_enabled = ''Y''
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

-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'purge_report_account_collection');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.purge_report_account_collection ( account_id integer, account_realm_id integer, ac_type character varying );
CREATE OR REPLACE FUNCTION auto_ac_manip.purge_report_account_collection(account_id integer, account_realm_id integer, ac_type character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	EXECUTE '
		DELETE FROM account_collection_account
		WHERE account_collection_ID IN (
			SELECT	property_value_account_coll_id
			FROM	property
			WHERE	property_name = $3
			AND		property_type = $4
			AND		account_id = $1
			AND		account_realm_id = $2
		)' USING account_id, account_realm_id, ac_type, 'auto_acct_coll';

	EXECUTE '
		WITH p AS (
			SELECT	property_value_account_coll_id AS account_collection_id
			FROM	property
			WHERE	property_name = $3
			AND		property_type = $4
			AND		account_id = $1
			AND		account_realm_id = $2
		)
		DELETE FROM account_collection_hier
		WHERE account_collection_id IN ( select account_collection_id from p)
		OR child_account_collection_id IN
			( select account_collection_id from p)
		' USING account_id, account_realm_id, ac_type, 'auto_acct_coll';

	EXECUTE '
		WITH list AS (
			SELECT	property_value_account_coll_id as account_collection_id,
					property_id
			FROM	property
			WHERE	property_name = $3
			AND		property_type = $4
			AND		account_id = $1
			AND		account_realm_id = $2
		), props AS (
			DELETE FROM property WHERE property_id IN
				(select property_id FROM list ) RETURNING *
		) DELETE FROM account_collection WHERE account_collection_id IN
				(select property_value_account_coll_id FROM props )
		' USING account_id, account_realm_id, ac_type, 'auto_acct_coll';

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'rename_automated_report_acs');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.rename_automated_report_acs ( account_id integer, old_login character varying, new_login character varying, account_realm_id integer );
CREATE OR REPLACE FUNCTION auto_ac_manip.rename_automated_report_acs(account_id integer, old_login character varying, new_login character varying, account_realm_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	EXECUTE '
		UPDATE account_collection
		  SET	account_collection_name =
				replace(account_collection_name, $6, $7)
		WHERE	account_collection_id IN (
				SELECT property_value_account_coll_id
				FROM	property
				WHERE	property_name IN ($3, $4)
				AND		property_type = $5
				AND		account_id = $1
				AND		account_realm_id = $2
		)' USING	account_id, account_realm_id,
				'AutomatedDirectsAC','AutomatedRollupsAC','auto_acct_coll',
				old_login, new_login;
END;
$function$
;

--
-- Process middle (non-trigger) schema company_manip
--
--
-- Process middle (non-trigger) schema token_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('token_utils', 'set_lock_status');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS token_utils.set_lock_status ( p_token_id integer, p_lock_status character, p_unlock_time timestamp with time zone, p_bad_logins integer, p_last_updated timestamp with time zone );
CREATE OR REPLACE FUNCTION token_utils.set_lock_status(p_token_id integer, p_lock_status character, p_unlock_time timestamp with time zone, p_bad_logins integer, p_last_updated timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_cur		token%ROWTYPE;
BEGIN

	IF p_token_id IS NULL THEN
		RAISE EXCEPTION 'Invalid token %', p_token_id
			USING ERRCODE = invalid_parameter_value;
	END IF;

	EXECUTE '
		SELECT *
		FROM token
		WHERE token_id = $1
	' INTO _cur USING p_token_id;

	--
	-- This used to be <= but if two clients were doing things in the
	-- same second, it became dueling syncs.  This may result in a change
	-- getting undone.  Solution may be to make last_updated more garanular
	-- as some libraries in here are no more granular than second (HOTPants
	-- or dbsyncer in jazzhands)
	IF _cur.last_updated < p_last_updated THEN
		UPDATE token SET
		is_token_locked = p_lock_status,
			token_unlock_time = p_unlock_time,
			bad_logins = p_bad_logins,
			last_updated = p_last_updated
		WHERE
			Token_ID = p_token_id;
	END IF;
END;
$function$
;

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
SELECT schema_support.save_grants_for_replay('device_utils', 'retire_devices');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.retire_devices ( device_id_list integer[] );
CREATE OR REPLACE FUNCTION device_utils.retire_devices(device_id_list integer[])
 RETURNS TABLE(device_id integer, success boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
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
			UNION
			SELECT
				rack_location_id
			FROM
				component
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
	RETURN;
END;
$function$
;

--
-- Process middle (non-trigger) schema netblock_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'calculate_intermediate_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.calculate_intermediate_netblocks ( ip_block_1 inet, ip_block_2 inet, netblock_type text, ip_universe_id integer );
CREATE OR REPLACE FUNCTION netblock_utils.calculate_intermediate_netblocks(ip_block_1 inet DEFAULT NULL::inet, ip_block_2 inet DEFAULT NULL::inet, netblock_type text DEFAULT 'default'::text, ip_universe_id integer DEFAULT 0)
 RETURNS TABLE(ip_addr inet)
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	current_nb		inet;
	new_nb			inet;
	min_addr		inet;
	max_addr		inet;
BEGIN
	IF ip_block_1 IS NULL OR ip_block_2 IS NULL THEN
		RAISE EXCEPTION 'Must specify both ip_block_1 and ip_block_2';
	END IF;

	IF family(ip_block_1) != family(ip_block_2) THEN
		RAISE EXCEPTION 'families of ip_block_1 and ip_block_2 must match';
	END IF;

	-- Make sure these are network blocks
	ip_block_1 := network(ip_block_1);
	ip_block_2 := network(ip_block_2);

	-- If the blocks are subsets of each other, then error

	IF ip_block_1 <<= ip_block_2 OR ip_block_2 <<= ip_block_1 THEN
		RAISE EXCEPTION 'netblocks intersect each other';
	END IF;

	-- Order the blocks correctly

	IF ip_block_1 > ip_block_2 THEN
		new_nb := ip_block_1;
		ip_block_1 := ip_block_2;
		ip_block_2 := new_nb;
	END IF;

	current_nb := ip_block_1;
	max_addr := broadcast(ip_block_1);

	-- Loop through bumping the netmask up and seeing if the destination block is in the new block
	LOOP
		new_nb := network(set_masklen(current_nb, masklen(current_nb) - 1));

		-- If the block is in our new larger netblock, then exit this loop
		IF (new_nb >>= ip_block_2) THEN
			current_nb := broadcast(current_nb) + 1;
			EXIT;
		END IF;
	
		-- If the max address of the new netblock is larger than the last one, then it's empty
		IF set_masklen(broadcast(new_nb), 32) > set_masklen(max_addr, 32) THEN
			ip_addr := set_masklen(max_addr + 1, masklen(current_nb));
			-- Validate that this isn't an empty can_subnet='Y' block already
			-- If it is, split it in half and return both halves
			PERFORM * FROM netblock n WHERE
				n.ip_address = ip_addr AND
				n.ip_universe_id =
					calculate_intermediate_netblocks.ip_universe_id AND
				n.netblock_type =
					calculate_intermediate_netblocks.netblock_type;
			IF FOUND AND masklen(ip_addr) < 32 THEN
				ip_addr := set_masklen(ip_addr, masklen(ip_addr) + 1);
				RETURN NEXT;
				ip_addr := broadcast(ip_addr) + 1;
				RETURN NEXT;
			ELSE
				RETURN NEXT;
			END IF;
			max_addr := broadcast(new_nb);
		END IF;
		current_nb := new_nb;
	END LOOP;

	-- Now loop through there to find the unused blocks at the front

	LOOP
		IF host(current_nb) = host(ip_block_2) THEN
			RETURN;
		END IF;
		current_nb := set_masklen(current_nb, masklen(current_nb) + 1);
		IF NOT (current_nb >>= ip_block_2) THEN
			ip_addr := current_nb;
			-- Validate that this isn't an empty can_subnet='Y' block already
			-- If it is, split it in half and return both halves
			PERFORM * FROM netblock n WHERE
				n.ip_address = ip_addr AND
				n.ip_universe_id =
					calculate_intermediate_netblocks.ip_universe_id AND
				n.netblock_type =
					calculate_intermediate_netblocks.netblock_type;
			IF FOUND AND masklen(ip_addr) < 32 THEN
				ip_addr := set_masklen(ip_addr, masklen(ip_addr) + 1);
				RETURN NEXT;
				ip_addr := broadcast(ip_addr) + 1;
				RETURN NEXT;
			ELSE
				RETURN NEXT;
			END IF;
			current_nb := broadcast(current_nb) + 1;
			CONTINUE;
		END IF;
	END LOOP;
	RETURN;
END;
$function$
;

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
-- Process middle (non-trigger) schema rack_utils
--
--
-- Process middle (non-trigger) schema schema_support
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

	FOREACH i IN ARRAY idx
	LOOP
		EXECUTE 'ALTER INDEX '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(i)
			|| ' RENAME TO '
			|| quote_ident('_' || i);
	END LOOP;

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
	-- get columns
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.build_audit_table_other_indexes(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
	AND 	con.contype IS NULL

	LOOP
		_r.def := regexp_replace(_r.def, ' ON ', ' ON ' || sch || '.');
		EXECUTE _r.def;
	END LOOP;

END;
$function$
;

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

-- New function
CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer3_network(layer3_network_id integer, purge_network_interfaces boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
	PERFORM * FROM layerx_network_manip.delete_layer3_networks(
		layer3_network_id_list := ARRAY[ layer3_network_id ],
		purge_network_interfaces := purge_network_interfaces
	);
END $function$
;

-- New function
CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer3_networks(layer3_network_id_list integer[], purge_network_interfaces boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	netblock_id_list			integer[];
	network_interface_id_list	integer[];
BEGIN
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

-- Creating new sequences....
CREATE SEQUENCE contract_contract_id_seq;


--------------------------------------------------------------------
-- DEALING WITH TABLE property
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'property', 'property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_compcoll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_l2_netcollid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_l3_netcoll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_net_range_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_os_snapshot;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_pv_devcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_svc_env_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_x509_crt_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acct_col;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acctid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acctrealmid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_compid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_devcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_dns_dom_collect;
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

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS pk_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif30property";
DROP INDEX IF EXISTS "jazzhands"."xif31property";
DROP INDEX IF EXISTS "jazzhands"."xif32property";
DROP INDEX IF EXISTS "jazzhands"."xif33property";
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
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'property');
---- BEGIN audit.property TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'property', 'property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.property DROP CONSTRAINT IF EXISTS property_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_property_pk_property";
DROP INDEX IF EXISTS "audit"."property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.property TEARDOWN


ALTER TABLE property RENAME TO property_v80;
ALTER TABLE audit.property RENAME TO property_v80;

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
	x509_signed_certificate_id	integer  NULL,
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	property_value	varchar(1024)  NULL,
	property_value_timestamp	timestamp without time zone  NULL,
	property_value_company_id	integer  NULL,
	property_value_account_coll_id	integer  NULL,
	property_value_device_coll_id	integer  NULL,
	property_value_json	jsonb  NULL,
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
	x509_signed_certificate_id,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	property_value_json,		-- new column (property_value_json)
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
	x509_signed_certificate_id,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	NULL,		-- new column (property_value_json)
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
FROM property_v80;

INSERT INTO audit.property (
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_collection_id,
	company_id,
	device_collection_id,
	dns_domain_collection_id,
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
	x509_signed_certificate_id,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	property_value_json,		-- new column (property_value_json)
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
	"aud#realtime",
	"aud#txid",
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
	x509_signed_certificate_id,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	NULL,		-- new column (property_value_json)
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
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.property_v80;

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
COMMENT ON COLUMN property.netblock_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.operating_system_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.operating_system_snapshot_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.person_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.property_collection_id IS 'LHS settable based on val_property.  NOTE, this is actually collections of property_name,property_type';
COMMENT ON COLUMN property.service_env_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.site_code IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.x509_signed_certificate_id IS 'Uniquely identifies Certificate';
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
CREATE INDEX xif33property ON property USING btree (x509_signed_certificate_id);
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
-- consider FK property and network_range
ALTER TABLE property
	ADD CONSTRAINT fk_prop_net_range_id
	FOREIGN KEY (network_range_id) REFERENCES network_range(network_range_id);
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
-- consider FK property and x509_signed_certificate
ALTER TABLE property
	ADD CONSTRAINT fk_prop_x509_crt_id
	FOREIGN KEY (x509_signed_certificate_id) REFERENCES x509_signed_certificate(x509_signed_certificate_id);
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

-- TRIGGERS
-- consider NEW jazzhands.validate_property
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
			property_value_json IS NOT DISTINCT FROM
				NEW.property_value_json AND
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
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'property');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'property');
ALTER SEQUENCE property_property_id_seq
	 OWNED BY property.property_id;
DROP TABLE IF EXISTS property_v80;
DROP TABLE IF EXISTS audit.property_v80;
-- DONE DEALING WITH TABLE property
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_property
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_property', 'v_property');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_property');
DROP VIEW IF EXISTS jazzhands.v_property;
CREATE VIEW jazzhands.v_property AS
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
    property.property_value_company_id,
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
   FROM property
  WHERE property.is_enabled = 'Y'::bpchar AND (property.start_date IS NULL AND property.finish_date IS NULL OR property.start_date IS NULL AND now() <= property.finish_date OR property.start_date <= now() AND property.finish_date IS NULL OR property.start_date <= now() AND now() <= property.finish_date);

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_property';
-- DONE DEALING WITH TABLE v_property
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE network_interface_netblock
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'network_interface_netblock', 'network_interface_netblock');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.network_interface_netblock DROP CONSTRAINT IF EXISTS fk_netint_nb_nblk_id;
ALTER TABLE jazzhands.network_interface_netblock DROP CONSTRAINT IF EXISTS fk_netint_nb_netint_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'network_interface_netblock');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.network_interface_netblock DROP CONSTRAINT IF EXISTS ak_netint_nblk_nblk_id;
ALTER TABLE jazzhands.network_interface_netblock DROP CONSTRAINT IF EXISTS ak_network_interface_nblk_ni_r;
ALTER TABLE jazzhands.network_interface_netblock DROP CONSTRAINT IF EXISTS pk_network_interface_netblock;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_netint_nb_nblk_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_network_interface_netblock ON jazzhands.network_interface_netblock;
DROP TRIGGER IF EXISTS trigger_audit_network_interface_netblock ON jazzhands.network_interface_netblock;
DROP TRIGGER IF EXISTS trigger_network_interface_drop_tt_netint_nb ON jazzhands.network_interface_netblock;
DROP TRIGGER IF EXISTS trigger_network_interface_netblock_to_ni ON jazzhands.network_interface_netblock;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'network_interface_netblock');
---- BEGIN audit.network_interface_netblock TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'network_interface_netblock', 'network_interface_netblock');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'network_interface_netblock');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.network_interface_netblock DROP CONSTRAINT IF EXISTS network_interface_netblock_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_network_interface_netblock_ak_netint_nblk_nblk_id";
DROP INDEX IF EXISTS "audit"."aud_network_interface_netblock_ak_network_interface_nblk_ni_r";
DROP INDEX IF EXISTS "audit"."aud_network_interface_netblock_pk_network_interface_netblock";
DROP INDEX IF EXISTS "audit"."network_interface_netblock_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.network_interface_netblock TEARDOWN


ALTER TABLE network_interface_netblock RENAME TO network_interface_netblock_v80;
ALTER TABLE audit.network_interface_netblock RENAME TO network_interface_netblock_v80;

CREATE TABLE network_interface_netblock
(
	netblock_id	integer NOT NULL,
	network_interface_id	integer NOT NULL,
	device_id	integer NOT NULL,
	network_interface_rank	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'network_interface_netblock', false);
ALTER TABLE network_interface_netblock
	ALTER network_interface_rank
	SET DEFAULT 0;


-- BEGIN Manually written insert function

ALTER TABLE network_interface_netblock
	ALTER network_interface_rank
	SET DEFAULT 0;
INSERT INTO network_interface_netblock (
	netblock_id,
	network_interface_id,
	device_id,		-- new column (device_id)
	network_interface_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	netblock_id,
	network_interface_id,
	device_id,		-- new column (device_id)
	network_interface_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM network_interface_netblock_v80
	join (select device_id, network_interface_id FROM network_interface) ni
		USING (network_interface_id);

--
-- note -- this will miss historical device_ids but that's work.
--
INSERT INTO audit.network_interface_netblock (
	netblock_id,
	network_interface_id,
	device_id,		-- new column (device_id)
	network_interface_rank,
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
	nbn.netblock_id,
	network_interface_id,
	device_id,		-- new column (device_id)
	network_interface_rank,
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
FROM audit.network_interface_netblock_v80 nbn
	LEFT
	join (select device_id, network_interface_id FROM network_interface) ni
		USING (network_interface_id);



-- END Manually written insert function
ALTER TABLE network_interface_netblock
	ALTER network_interface_rank
	SET DEFAULT 0;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE network_interface_netblock ADD CONSTRAINT ak_netint_nblk_nblk_id UNIQUE (netblock_id);
ALTER TABLE network_interface_netblock ADD CONSTRAINT ak_network_interface_nblk_ni_r UNIQUE (network_interface_id, network_interface_rank);
ALTER TABLE network_interface_netblock ADD CONSTRAINT pk_network_interface_netblock PRIMARY KEY (netblock_id, network_interface_id, device_id);

-- Table/Column Comments
COMMENT ON COLUMN network_interface_netblock.network_interface_rank IS 'specifies the order of priority for the ip address.  generally only the highest priority matters (or highest priority v4 and v6) and is the "primary" if the underlying device supports it.';
-- INDEXES
CREATE INDEX xif3network_interface_netblock ON network_interface_netblock USING btree (network_interface_id, device_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK network_interface_netblock and network_interface
ALTER TABLE network_interface_netblock
	ADD CONSTRAINT fk_netint_nb_nblk_id
	FOREIGN KEY (network_interface_id, device_id) REFERENCES network_interface(network_interface_id, device_id);
-- consider FK network_interface_netblock and netblock
ALTER TABLE network_interface_netblock
	ADD CONSTRAINT fk_netint_nb_netint_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id) DEFERRABLE;

-- TRIGGERS
-- consider NEW jazzhands.net_int_nb_device_id_ins
CREATE OR REPLACE FUNCTION jazzhands.net_int_nb_device_id_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.device_id IS NULL OR TG_OP = 'UPDATE' THEN
		SELECT device_id
		INTO	NEW.device_id
		FROM	network_interface
		WHERE	network_interface_id = NEW.network_interface_id;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_net_int_nb_device_id_ins BEFORE INSERT OR UPDATE OF network_interface_id ON network_interface_netblock FOR EACH ROW EXECUTE PROCEDURE net_int_nb_device_id_ins();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.net_int_nb_single_address
CREATE OR REPLACE FUNCTION jazzhands.net_int_nb_single_address()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF NEW.netblock_id IS NOT NULL THEN
		select count(*)
		INTO _tally
		FROM netblock
		WHERE netblock_id = NEW.netblock_id
		AND is_single_address = 'Y'
		AND netblock_type = 'default';

		IF _tally = 0 THEN
			RAISE EXCEPTION 'network interfaces must refer to single ip addresses of type default (%,%)', NEW.network_interface_id, NEW.netblock_id
				USING errcode = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_net_int_nb_single_address BEFORE INSERT OR UPDATE OF netblock_id ON network_interface_netblock FOR EACH ROW EXECUTE PROCEDURE net_int_nb_single_address();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'network_interface_netblock');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'network_interface_netblock');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'network_interface_netblock');
DROP TABLE IF EXISTS network_interface_netblock_v80;
DROP TABLE IF EXISTS audit.network_interface_netblock_v80;
-- DONE DEALING WITH TABLE network_interface_netblock
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_network_interface_trans
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_network_interface_trans', 'v_network_interface_trans');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_network_interface_trans');
DROP VIEW IF EXISTS jazzhands.v_network_interface_trans;
CREATE VIEW jazzhands.v_network_interface_trans AS
 SELECT base.network_interface_id,
    base.device_id,
    base.network_interface_name,
    base.description,
    base.parent_network_interface_id,
    base.parent_relation_type,
    base.netblock_id,
    base.physical_port_id,
    base.slot_id,
    base.logical_port_id,
    base.network_interface_type,
    base.is_interface_up,
    base.mac_addr,
    base.should_monitor,
    base.provides_nat,
    base.should_manage,
    base.provides_dhcp,
    base.data_ins_user,
    base.data_ins_date,
    base.data_upd_user,
    base.data_upd_date
   FROM ( SELECT ni.network_interface_id,
            ni.device_id,
            ni.network_interface_name,
            ni.description,
            ni.parent_network_interface_id,
            ni.parent_relation_type,
            nin.netblock_id,
            ni.physical_port_id,
            ni.slot_id,
            ni.logical_port_id,
            ni.network_interface_type,
            ni.is_interface_up,
            ni.mac_addr,
            ni.should_monitor,
            ni.provides_nat,
            ni.should_manage,
            ni.provides_dhcp,
            ni.data_ins_user,
            ni.data_ins_date,
            ni.data_upd_user,
            ni.data_upd_date,
            rank() OVER (PARTITION BY ni.network_interface_id ORDER BY nin.network_interface_rank) AS rnk
           FROM network_interface ni
             JOIN network_interface_netblock nin USING (network_interface_id)) base
  WHERE base.rnk = 1;

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_network_interface_trans';
-- DONE DEALING WITH TABLE v_network_interface_trans
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_hotpants_device_collection
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_hotpants_device_collection', 'v_hotpants_device_collection');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_hotpants_device_collection');
DROP VIEW IF EXISTS jazzhands.v_hotpants_device_collection;
CREATE VIEW jazzhands.v_hotpants_device_collection AS
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
           FROM device_collection dc
             LEFT JOIN v_device_coll_hier_detail dcr ON dc.device_collection_id = dcr.parent_device_collection_id
             LEFT JOIN device_collection_device dcd ON dcd.device_collection_id = dcr.device_collection_id
             LEFT JOIN device USING (device_id)
             LEFT JOIN network_interface_netblock ni USING (device_id)
             LEFT JOIN netblock nb USING (netblock_id)
          WHERE dc.device_collection_type::text = ANY (ARRAY['HOTPants'::character varying, 'HOTPants-app'::character varying]::text[])) rankbyhier
  WHERE rankbyhier.device_collection_type::text = 'HOTPants-app'::text OR rankbyhier.rank = 1 AND rankbyhier.ip_address IS NOT NULL;

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_hotpants_device_collection';
-- DONE DEALING WITH TABLE v_hotpants_device_collection
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


ALTER TABLE val_property RENAME TO val_property_v80;
ALTER TABLE audit.val_property RENAME TO val_property_v80;

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
	network_range_type,
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	property_value_json_schema,		-- new column (property_value_json_schema)
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
	NULL,		-- new column (property_value_json_schema)
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
FROM val_property_v80;

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
	property_value_json_schema,		-- new column (property_value_json_schema)
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
	NULL,		-- new column (property_value_json_schema)
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
FROM audit.val_property_v80;

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
-- consider NEW jazzhands.validate_val_property
CREATE OR REPLACE FUNCTION jazzhands.validate_val_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
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
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_validate_val_property BEFORE INSERT OR UPDATE OF property_data_type, property_value_json_schema ON val_property FOR EACH ROW EXECUTE PROCEDURE validate_val_property();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_property');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'val_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_property');
DROP TABLE IF EXISTS val_property_v80;
DROP TABLE IF EXISTS audit.val_property_v80;
-- DONE DEALING WITH TABLE val_property
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE account_coll_type_relation
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_coll_type_relation', 'account_coll_type_relation');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.account_coll_type_relation DROP CONSTRAINT IF EXISTS fk_acct_coll_rel_type_rel;
ALTER TABLE jazzhands.account_coll_type_relation DROP CONSTRAINT IF EXISTS fk_acct_coll_rel_type_type;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'account_coll_type_relation');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.account_coll_type_relation DROP CONSTRAINT IF EXISTS pk_account_coll_type_relation;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifacct_coll_rel_type_rel";
DROP INDEX IF EXISTS "jazzhands"."xifacct_coll_rel_type_type";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_account_coll_type_relation ON jazzhands.account_coll_type_relation;
DROP TRIGGER IF EXISTS trigger_audit_account_coll_type_relation ON jazzhands.account_coll_type_relation;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'account_coll_type_relation');
---- BEGIN audit.account_coll_type_relation TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'account_coll_type_relation', 'account_coll_type_relation');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'account_coll_type_relation');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.account_coll_type_relation DROP CONSTRAINT IF EXISTS account_coll_type_relation_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."account_coll_type_relation_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."aud_account_coll_type_relation_pk_account_coll_type_relation";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.account_coll_type_relation TEARDOWN


ALTER TABLE account_coll_type_relation RENAME TO account_coll_type_relation_v80;
ALTER TABLE audit.account_coll_type_relation RENAME TO account_coll_type_relation_v80;

CREATE TABLE account_coll_type_relation
(
	account_collection_relation	varchar(50) NOT NULL,
	account_collection_type	varchar(50) NOT NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'account_coll_type_relation', false);
INSERT INTO account_coll_type_relation (
	account_collection_relation,
	account_collection_type,
	max_num_members,
	max_num_collections,		-- new column (max_num_collections)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	account_collection_relation,
	account_collection_type,
	max_num_members,
	NULL,		-- new column (max_num_collections)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM account_coll_type_relation_v80;

INSERT INTO audit.account_coll_type_relation (
	account_collection_relation,
	account_collection_type,
	max_num_members,
	max_num_collections,		-- new column (max_num_collections)
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
	account_collection_relation,
	account_collection_type,
	max_num_members,
	NULL,		-- new column (max_num_collections)
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
FROM audit.account_coll_type_relation_v80;


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
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'account_coll_type_relation');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'account_coll_type_relation');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'account_coll_type_relation');
DROP TABLE IF EXISTS account_coll_type_relation_v80;
DROP TABLE IF EXISTS audit.account_coll_type_relation_v80;
-- DONE DEALING WITH TABLE account_coll_type_relation
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE contract
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'contract', 'contract');

-- FOREIGN KEYS FROM
ALTER TABLE asset DROP CONSTRAINT IF EXISTS fk_asset_contract_id;
ALTER TABLE contract_type DROP CONSTRAINT IF EXISTS fk_contract_contract_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.contract DROP CONSTRAINT IF EXISTS fk_contract_company_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'contract');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.contract DROP CONSTRAINT IF EXISTS pk_contract;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifcontract_company_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_contract ON jazzhands.contract;
DROP TRIGGER IF EXISTS trigger_audit_contract ON jazzhands.contract;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'contract');
---- BEGIN audit.contract TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'contract', 'contract');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'contract');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.contract DROP CONSTRAINT IF EXISTS contract_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_contract_pk_contract";
DROP INDEX IF EXISTS "audit"."contract_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.contract TEARDOWN


ALTER TABLE contract RENAME TO contract_v80;
ALTER TABLE audit.contract RENAME TO contract_v80;

CREATE TABLE contract
(
	contract_id	integer NOT NULL,
	company_id	integer NOT NULL,
	contract_name	varchar(255) NOT NULL,
	vendor_contract_name	varchar(255)  NULL,
	description	varchar(255)  NULL,
	contract_termination_date	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'contract', false);
ALTER TABLE contract
	ALTER contract_id
	SET DEFAULT nextval('contract_contract_id_seq'::regclass);
INSERT INTO contract (
	contract_id,
	company_id,
	contract_name,
	vendor_contract_name,
	description,
	contract_termination_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	contract_id,
	company_id,
	contract_name,
	vendor_contract_name,
	description,
	contract_termination_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM contract_v80;

INSERT INTO audit.contract (
	contract_id,
	company_id,
	contract_name,
	vendor_contract_name,
	description,
	contract_termination_date,
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
	contract_id,
	company_id,
	contract_name,
	vendor_contract_name,
	description,
	contract_termination_date,
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
FROM audit.contract_v80;

ALTER TABLE contract
	ALTER contract_id
	SET DEFAULT nextval('contract_contract_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE contract ADD CONSTRAINT pk_contract PRIMARY KEY (contract_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifcontract_company_id ON contract USING btree (company_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between contract and asset
ALTER TABLE asset
	ADD CONSTRAINT fk_asset_contract_id
	FOREIGN KEY (contract_id) REFERENCES contract(contract_id);
-- consider FK between contract and contract_type
ALTER TABLE contract_type
	ADD CONSTRAINT fk_contract_contract_id
	FOREIGN KEY (contract_id) REFERENCES contract(contract_id);

-- FOREIGN KEYS TO
-- consider FK contract and company
ALTER TABLE contract
	ADD CONSTRAINT fk_contract_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'contract');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'contract');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'contract');
ALTER SEQUENCE contract_contract_id_seq
	 OWNED BY contract.contract_id;
DROP TABLE IF EXISTS contract_v80;
DROP TABLE IF EXISTS audit.contract_v80;
-- DONE DEALING WITH TABLE contract
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE ip_universe
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'ip_universe', 'ip_universe');

-- FOREIGN KEYS FROM
ALTER TABLE dns_record DROP CONSTRAINT IF EXISTS fk_dns_rec_ip_universe;
ALTER TABLE dns_change_record DROP CONSTRAINT IF EXISTS fk_dnschgrec_ip_universe;
ALTER TABLE dns_domain_ip_universe DROP CONSTRAINT IF EXISTS fk_dnsdom_ipu_ipu;
ALTER TABLE ip_universe_visibility DROP CONSTRAINT IF EXISTS fk_ip_universe_vis_ip_univ;
ALTER TABLE ip_universe_visibility DROP CONSTRAINT IF EXISTS fk_ip_universe_vis_ip_univ_vis;
ALTER TABLE netblock DROP CONSTRAINT IF EXISTS fk_nblk_ip_universe_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.ip_universe DROP CONSTRAINT IF EXISTS r_815;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'ip_universe');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.ip_universe DROP CONSTRAINT IF EXISTS ak_ip_universe_name;
ALTER TABLE jazzhands.ip_universe DROP CONSTRAINT IF EXISTS pk_ip_universe;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1ip_universe";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_ip_universe ON jazzhands.ip_universe;
DROP TRIGGER IF EXISTS trigger_audit_ip_universe ON jazzhands.ip_universe;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'ip_universe');
---- BEGIN audit.ip_universe TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'ip_universe', 'ip_universe');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'ip_universe');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.ip_universe DROP CONSTRAINT IF EXISTS ip_universe_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_ip_universe_ak_ip_universe_name";
DROP INDEX IF EXISTS "audit"."aud_ip_universe_pk_ip_universe";
DROP INDEX IF EXISTS "audit"."ip_universe_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.ip_universe TEARDOWN


ALTER TABLE ip_universe RENAME TO ip_universe_v80;
ALTER TABLE audit.ip_universe RENAME TO ip_universe_v80;

CREATE TABLE ip_universe
(
	ip_universe_id	integer NOT NULL,
	ip_universe_name	varchar(50) NOT NULL,
	ip_namespace	varchar(50) NOT NULL,
	should_generate_dns	character(1) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'ip_universe', false);
ALTER TABLE ip_universe
	ALTER ip_universe_id
	SET DEFAULT nextval('ip_universe_ip_universe_id_seq'::regclass);
INSERT INTO ip_universe (
	ip_universe_id,
	ip_universe_name,
	ip_namespace,
	should_generate_dns,		-- new column (should_generate_dns)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	ip_universe_id,
	ip_universe_name,
	ip_namespace,
	'Y',		-- new column (should_generate_dns)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM ip_universe_v80;

INSERT INTO audit.ip_universe (
	ip_universe_id,
	ip_universe_name,
	ip_namespace,
	should_generate_dns,		-- new column (should_generate_dns)
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
	ip_universe_id,
	ip_universe_name,
	ip_namespace,
	'Y',		-- new column (should_generate_dns)
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
FROM audit.ip_universe_v80;

ALTER TABLE ip_universe
	ALTER ip_universe_id
	SET DEFAULT nextval('ip_universe_ip_universe_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE ip_universe ADD CONSTRAINT ak_ip_universe_name UNIQUE (ip_universe_name);
ALTER TABLE ip_universe ADD CONSTRAINT pk_ip_universe PRIMARY KEY (ip_universe_id);

-- Table/Column Comments
COMMENT ON COLUMN ip_universe.ip_namespace IS 'defeines the namespace for a given ip universe -- all universes in this namespace are considered unique for netblock validations';
COMMENT ON COLUMN ip_universe.should_generate_dns IS 'Indicates if any zones should generated rooted in this universe.   Primarily used to turn off DNS generation for universes that exist as shims between two networks (such as the internet can see, inside can not, for inbound NAT''d addresses).';
-- INDEXES
CREATE INDEX xif1ip_universe ON ip_universe USING btree (ip_namespace);

-- CHECK CONSTRAINTS
ALTER TABLE ip_universe ADD CONSTRAINT check_yes_no_722228305
	CHECK (should_generate_dns = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between ip_universe and dns_record
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dns_rec_ip_universe
	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);
-- consider FK between ip_universe and dns_change_record
ALTER TABLE dns_change_record
	ADD CONSTRAINT fk_dnschgrec_ip_universe
	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);
-- consider FK between ip_universe and dns_domain_ip_universe
ALTER TABLE dns_domain_ip_universe
	ADD CONSTRAINT fk_dnsdom_ipu_ipu
	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);
-- consider FK between ip_universe and ip_universe_visibility
ALTER TABLE ip_universe_visibility
	ADD CONSTRAINT fk_ip_universe_vis_ip_univ
	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);
-- consider FK between ip_universe and ip_universe_visibility
ALTER TABLE ip_universe_visibility
	ADD CONSTRAINT fk_ip_universe_vis_ip_univ_vis
	FOREIGN KEY (visible_ip_universe_id) REFERENCES ip_universe(ip_universe_id);
-- consider FK between ip_universe and netblock
ALTER TABLE netblock
	ADD CONSTRAINT fk_nblk_ip_universe_id
	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);

-- FOREIGN KEYS TO
-- consider FK ip_universe and val_ip_namespace
ALTER TABLE ip_universe
	ADD CONSTRAINT r_815
	FOREIGN KEY (ip_namespace) REFERENCES val_ip_namespace(ip_namespace);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'ip_universe');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'ip_universe');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'ip_universe');
ALTER SEQUENCE ip_universe_ip_universe_id_seq
	 OWNED BY ip_universe.ip_universe_id;
DROP TABLE IF EXISTS ip_universe_v80;
DROP TABLE IF EXISTS audit.ip_universe_v80;
-- DONE DEALING WITH TABLE ip_universe
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
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_netblk_v4id;
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
DROP INDEX IF EXISTS "jazzhands"."idx_netint_provides_dhcp";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_providesnat";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_shouldmange";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_shouldmonitor";
DROP INDEX IF EXISTS "jazzhands"."xif_net_int_lgl_port_id";
DROP INDEX IF EXISTS "jazzhands"."xif_net_int_phys_port_id";
DROP INDEX IF EXISTS "jazzhands"."xif_netint_netdev_id";
DROP INDEX IF EXISTS "jazzhands"."xif_netint_parentnetint";
DROP INDEX IF EXISTS "jazzhands"."xif_netint_prim_v4id";
DROP INDEX IF EXISTS "jazzhands"."xif_netint_slot_id";
DROP INDEX IF EXISTS "jazzhands"."xif_netint_typeid";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS check_any_yes_no_1926994056;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_is_interface_up_network_;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_netint_parent_r_1604677531;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_provides_dhcp_network_;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_provides_nat_network_;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_should_manage_network_;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_network_interface ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_audit_network_interface ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_net_int_nb_single_address ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_net_int_netblock_to_nbn_compat_after ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_net_int_netblock_to_nbn_compat_before ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_net_int_netblock_to_nbn_compat_before_del ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_net_int_physical_id_to_slot_id_enforce ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_network_interface_drop_tt_netint_ni ON jazzhands.network_interface;
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
DROP INDEX IF EXISTS "audit"."network_interface_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.network_interface TEARDOWN


ALTER TABLE network_interface RENAME TO network_interface_v80;
ALTER TABLE audit.network_interface RENAME TO network_interface_v80;

CREATE TABLE network_interface
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
	should_monitor	varchar(255) NOT NULL,
	provides_nat	character(1) NOT NULL,
	should_manage	character(1) NOT NULL,
	provides_dhcp	character(1) NOT NULL,
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
	ALTER provides_nat
	SET DEFAULT 'N'::bpchar;
ALTER TABLE network_interface
	ALTER should_manage
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE network_interface
	ALTER provides_dhcp
	SET DEFAULT 'N'::bpchar;
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
	provides_nat,
	should_manage,
	provides_dhcp,
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
	provides_nat,
	should_manage,
	provides_dhcp,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM network_interface_v80;

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
	provides_nat,
	should_manage,
	provides_dhcp,
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
	provides_nat,
	should_manage,
	provides_dhcp,
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
FROM audit.network_interface_v80;

ALTER TABLE network_interface
	ALTER network_interface_id
	SET DEFAULT nextval('network_interface_network_interface_id_seq'::regclass);
ALTER TABLE network_interface
	ALTER is_interface_up
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE network_interface
	ALTER provides_nat
	SET DEFAULT 'N'::bpchar;
ALTER TABLE network_interface
	ALTER should_manage
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE network_interface
	ALTER provides_dhcp
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE network_interface ADD CONSTRAINT ak_net_int_devid_netintid UNIQUE (network_interface_id, device_id);
ALTER TABLE network_interface ADD CONSTRAINT fk_netint_devid_name UNIQUE (device_id, network_interface_name);
ALTER TABLE network_interface ADD CONSTRAINT pk_network_interface_id PRIMARY KEY (network_interface_id);

-- Table/Column Comments
COMMENT ON COLUMN network_interface.physical_port_id IS 'historical column to be dropped in the next release after tools use slot_id.  matches slot_id by trigger.';
COMMENT ON COLUMN network_interface.slot_id IS 'to be dropped after transition to logical_ports are complete.';
-- INDEXES
CREATE INDEX idx_netint_isifaceup ON network_interface USING btree (is_interface_up);
CREATE INDEX idx_netint_provides_dhcp ON network_interface USING btree (provides_dhcp);
CREATE INDEX idx_netint_providesnat ON network_interface USING btree (provides_nat);
CREATE INDEX idx_netint_shouldmange ON network_interface USING btree (should_manage);
CREATE INDEX idx_netint_shouldmonitor ON network_interface USING btree (should_monitor);
CREATE INDEX xif_net_int_lgl_port_id ON network_interface USING btree (logical_port_id);
CREATE INDEX xif_net_int_phys_port_id ON network_interface USING btree (physical_port_id);
CREATE INDEX xif_netint_netdev_id ON network_interface USING btree (device_id);
CREATE INDEX xif_netint_parentnetint ON network_interface USING btree (parent_network_interface_id);
CREATE INDEX xif_netint_slot_id ON network_interface USING btree (slot_id);
CREATE INDEX xif_netint_typeid ON network_interface USING btree (network_interface_type);

-- CHECK CONSTRAINTS
ALTER TABLE network_interface ADD CONSTRAINT check_any_yes_no_1926994056
	CHECK ((should_monitor)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying, 'ANY'::character varying])::text[]));
ALTER TABLE network_interface ADD CONSTRAINT ckc_is_interface_up_network_
	CHECK ((is_interface_up = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_interface_up)::text = upper((is_interface_up)::text)));
ALTER TABLE network_interface ADD CONSTRAINT ckc_netint_parent_r_1604677531
	CHECK ((parent_relation_type)::text = ANY ((ARRAY['NONE'::character varying, 'SUBINTERFACE'::character varying, 'SECONDARY'::character varying])::text[]));
ALTER TABLE network_interface ADD CONSTRAINT ckc_provides_dhcp_network_
	CHECK ((provides_dhcp = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((provides_dhcp)::text = upper((provides_dhcp)::text)));
ALTER TABLE network_interface ADD CONSTRAINT ckc_provides_nat_network_
	CHECK ((provides_nat = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((provides_nat)::text = upper((provides_nat)::text)));
ALTER TABLE network_interface ADD CONSTRAINT ckc_should_manage_network_
	CHECK ((should_manage = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_manage)::text = upper((should_manage)::text)));

-- FOREIGN KEYS FROM
-- consider FK between network_interface and network_interface_netblock
ALTER TABLE network_interface_netblock
	ADD CONSTRAINT fk_netint_nb_nblk_id
	FOREIGN KEY (network_interface_id, device_id) REFERENCES network_interface(network_interface_id, device_id);
-- consider FK between network_interface and network_interface_purpose
ALTER TABLE network_interface_purpose
	ADD CONSTRAINT fk_netint_purp_dev_ni_id
	FOREIGN KEY (network_interface_id, device_id) REFERENCES network_interface(network_interface_id, device_id);
-- consider FK between network_interface and network_service
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);
-- consider FK between network_interface and shared_netblock_network_int
ALTER TABLE shared_netblock_network_int
	ADD CONSTRAINT fk_shrdnet_netint_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);
-- consider FK between network_interface and static_route_template
ALTER TABLE static_route_template
	ADD CONSTRAINT fk_static_rt_net_interface
	FOREIGN KEY (network_interface_dst_id) REFERENCES network_interface(network_interface_id);
-- consider FK between network_interface and static_route
ALTER TABLE static_route
	ADD CONSTRAINT fk_statrt_netintdst_id
	FOREIGN KEY (network_interface_dst_id) REFERENCES network_interface(network_interface_id);

-- FOREIGN KEYS TO
-- consider FK network_interface and logical_port
ALTER TABLE network_interface
	ADD CONSTRAINT fk_net_int_lgl_port_id
	FOREIGN KEY (logical_port_id) REFERENCES logical_port(logical_port_id);
-- consider FK network_interface and slot
ALTER TABLE network_interface
	ADD CONSTRAINT fk_net_int_phys_port_id
	FOREIGN KEY (physical_port_id) REFERENCES slot(slot_id);
-- consider FK network_interface and device
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK network_interface and val_network_interface_type
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_netinttyp_id
	FOREIGN KEY (network_interface_type) REFERENCES val_network_interface_type(network_interface_type);
-- consider FK network_interface and network_interface
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_ref_parentnetint
	FOREIGN KEY (parent_network_interface_id) REFERENCES network_interface(network_interface_id);
-- consider FK network_interface and slot
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_slot_id
	FOREIGN KEY (slot_id) REFERENCES slot(slot_id);

-- TRIGGERS
-- consider NEW jazzhands.net_int_device_id_upd
CREATE OR REPLACE FUNCTION jazzhands.net_int_device_id_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	UPDATE network_interface_netblock
	SET device_id = NEW.device_id
	WHERE	network_interface_id = NEW.network_interface_id;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_net_int_device_id_upd AFTER UPDATE OF device_id ON network_interface FOR EACH ROW EXECUTE PROCEDURE net_int_device_id_upd();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.net_int_physical_id_to_slot_id_enforce
CREATE OR REPLACE FUNCTION jazzhands.net_int_physical_id_to_slot_id_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
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
DROP TABLE IF EXISTS network_interface_v80;
DROP TABLE IF EXISTS audit.network_interface_v80;
-- DONE DEALING WITH TABLE network_interface
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_network_interface_trans
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_network_interface_trans', 'v_network_interface_trans');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_network_interface_trans');
DROP VIEW IF EXISTS jazzhands.v_network_interface_trans;
CREATE VIEW jazzhands.v_network_interface_trans AS
 SELECT base.network_interface_id,
    base.device_id,
    base.network_interface_name,
    base.description,
    base.parent_network_interface_id,
    base.parent_relation_type,
    base.netblock_id,
    base.physical_port_id,
    base.slot_id,
    base.logical_port_id,
    base.network_interface_type,
    base.is_interface_up,
    base.mac_addr,
    base.should_monitor,
    base.provides_nat,
    base.should_manage,
    base.provides_dhcp,
    base.data_ins_user,
    base.data_ins_date,
    base.data_upd_user,
    base.data_upd_date
   FROM ( SELECT ni.network_interface_id,
            ni.device_id,
            ni.network_interface_name,
            ni.description,
            ni.parent_network_interface_id,
            ni.parent_relation_type,
            nin.netblock_id,
            ni.physical_port_id,
            ni.slot_id,
            ni.logical_port_id,
            ni.network_interface_type,
            ni.is_interface_up,
            ni.mac_addr,
            ni.should_monitor,
            ni.provides_nat,
            ni.should_manage,
            ni.provides_dhcp,
            ni.data_ins_user,
            ni.data_ins_date,
            ni.data_upd_user,
            ni.data_upd_date,
            rank() OVER (PARTITION BY ni.network_interface_id ORDER BY nin.network_interface_rank) AS rnk
           FROM network_interface ni
             JOIN network_interface_netblock nin USING (network_interface_id)) base
  WHERE base.rnk = 1;

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_network_interface_trans';
-- DONE DEALING WITH TABLE v_network_interface_trans
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_property
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_property', 'v_property');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_property');
DROP VIEW IF EXISTS jazzhands.v_property;
CREATE VIEW jazzhands.v_property AS
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
    property.property_value_company_id,
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
   FROM property
  WHERE property.is_enabled = 'Y'::bpchar AND (property.start_date IS NULL AND property.finish_date IS NULL OR property.start_date IS NULL AND now() <= property.finish_date OR property.start_date <= now() AND property.finish_date IS NULL OR property.start_date <= now() AND now() <= property.finish_date);

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_property';
-- DONE DEALING WITH TABLE v_property
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_hotpants_device_collection
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_hotpants_device_collection', 'v_hotpants_device_collection');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_hotpants_device_collection');
DROP VIEW IF EXISTS jazzhands.v_hotpants_device_collection;
CREATE VIEW jazzhands.v_hotpants_device_collection AS
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
           FROM device_collection dc
             LEFT JOIN v_device_coll_hier_detail dcr ON dc.device_collection_id = dcr.parent_device_collection_id
             LEFT JOIN device_collection_device dcd ON dcd.device_collection_id = dcr.device_collection_id
             LEFT JOIN device USING (device_id)
             LEFT JOIN network_interface_netblock ni USING (device_id)
             LEFT JOIN netblock nb USING (netblock_id)
          WHERE dc.device_collection_type::text = ANY (ARRAY['HOTPants'::character varying, 'HOTPants-app'::character varying]::text[])) rankbyhier
  WHERE rankbyhier.device_collection_type::text = 'HOTPants-app'::text OR rankbyhier.rank = 1 AND rankbyhier.ip_address IS NOT NULL;

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_hotpants_device_collection';
-- DONE DEALING WITH TABLE v_hotpants_device_collection
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_hotpants_client
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_hotpants_client', 'v_hotpants_client');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_hotpants_client');
DROP VIEW IF EXISTS jazzhands.v_hotpants_client;
CREATE VIEW jazzhands.v_hotpants_client AS
 SELECT dc.device_id,
    d.device_name,
    netblock.ip_address,
    p.property_value AS radius_secret
   FROM v_property p
     JOIN v_device_coll_device_expanded dc USING (device_collection_id)
     JOIN device d USING (device_id)
     JOIN network_interface_netblock ni USING (device_id)
     JOIN netblock USING (netblock_id)
  WHERE p.property_name::text = 'RadiusSharedSecret'::text AND p.property_type::text = 'HOTPants'::text;

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_hotpants_client';
-- DONE DEALING WITH TABLE v_hotpants_client
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_layer3_network_expanded
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_layer3_network_expanded');
DROP VIEW IF EXISTS jazzhands.v_layer3_network_expanded;
CREATE VIEW jazzhands.v_layer3_network_expanded AS
 SELECT l3.layer3_network_id,
    l3.description AS layer3_network_description,
    n.netblock_id,
    n.ip_address,
    n.netblock_type,
    n.ip_universe_id,
    l3.default_gateway_netblock_id,
    dg.ip_address AS default_gateway_ip_address,
    dg.netblock_type AS default_gateway_netblock_type,
    dg.ip_universe_id AS default_gateway_ip_universe_id,
    l2.layer2_network_id,
    l2.encapsulation_name,
    l2.encapsulation_domain,
    l2.encapsulation_type,
    l2.encapsulation_tag,
    l2.description AS layer2_network_description
   FROM layer3_network l3
     JOIN netblock n USING (netblock_id)
     LEFT JOIN netblock dg ON l3.default_gateway_netblock_id = dg.netblock_id
     LEFT JOIN layer2_network l2 USING (layer2_network_id);

-- DONE DEALING WITH TABLE v_layer3_network_expanded
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_account_manager_hier
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_account_manager_hier');
DROP VIEW IF EXISTS jazzhands.v_account_manager_hier;
CREATE VIEW jazzhands.v_account_manager_hier AS
 WITH RECURSIVE phier(level, person_id, company_id, intermediate_manager_person_id, manager_person_id) AS (
         SELECT 0 AS level,
            person_company.person_id,
            person_company.company_id,
            person_company.manager_person_id AS intermediate_manager_person_id,
            person_company.manager_person_id,
            ARRAY[person_company.person_id] AS array_path,
            false AS cycle
           FROM person_company
        UNION
         SELECT x.level + 1 AS level,
            x.person_id,
            x.company_id,
            m_1.manager_person_id AS intermediate_manager_person_id,
            m_1.manager_person_id,
            x.array_path || m_1.manager_person_id AS array_path,
            m_1.manager_person_id = ANY (x.array_path) AS cycle
           FROM person_company m_1
             JOIN phier x ON x.intermediate_manager_person_id = m_1.person_id
          WHERE NOT x.cycle AND m_1.manager_person_id IS NOT NULL
        )
 SELECT h.level,
    a.account_id,
    a.person_id,
    a.company_id,
    a.login,
    concat(p.first_name, ' ', p.last_name, ' (', a.login, ')') AS human_readable,
    a.account_realm_id,
    m.manager_account_id,
    m.manager_login,
    h.manager_person_id,
    m.manager_company_id,
    m.manager_human_readable,
    h.array_path
   FROM account a
     JOIN phier h USING (person_id, company_id)
     JOIN v_person p USING (person_id)
     LEFT JOIN ( SELECT a_1.person_id AS manager_person_id,
            a_1.account_id AS manager_account_id,
            concat(p_1.first_name, ' ', p_1.last_name, ' (', a_1.login, ')') AS manager_human_readable,
            p_1.first_name AS manager_first_name,
            p_1.last_name AS manager_last_name,
            a_1.account_role,
            a_1.company_id AS manager_company_id,
            a_1.account_realm_id,
            a_1.login AS manager_login
           FROM account a_1
             JOIN v_person p_1 USING (person_id)
          WHERE a_1.account_role::text = 'primary'::text AND a_1.account_type::text = 'person'::text) m USING (manager_person_id, account_realm_id, account_role)
  WHERE a.account_role::text = 'primary'::text AND a.account_type::text = 'person'::text;

-- DONE DEALING WITH TABLE v_account_manager_hier
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
--
-- Process drops in jazzhands
--
DROP TRIGGER IF EXISTS trigger_account_status_after_hooks ON jazzhands.account;
DROP FUNCTION IF EXISTS jazzhands.account_status_after_hooks (  );
DROP TRIGGER IF EXISTS trigger_net_int_netblock_to_nbn_compat_after ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_net_int_netblock_to_nbn_compat_before_del ON jazzhands.network_interface;
DROP FUNCTION IF EXISTS jazzhands.net_int_netblock_to_nbn_compat_after (  );
DROP TRIGGER IF EXISTS trigger_net_int_netblock_to_nbn_compat_before ON jazzhands.network_interface;
DROP FUNCTION IF EXISTS jazzhands.net_int_netblock_to_nbn_compat_before (  );
DROP TRIGGER IF EXISTS trigger_network_interface_drop_tt_netint_nb ON jazzhands.network_interface_netblock;
DROP TRIGGER IF EXISTS trigger_network_interface_drop_tt_netint_ni ON jazzhands.network_interface;
DROP FUNCTION IF EXISTS jazzhands.network_interface_drop_tt (  );
DROP TRIGGER IF EXISTS trigger_network_interface_netblock_to_ni ON jazzhands.network_interface_netblock;
DROP FUNCTION IF EXISTS jazzhands.network_interface_netblock_to_ni (  );
-- New function
CREATE OR REPLACE FUNCTION jazzhands._validate_json_schema_type(type text, data jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  IF type = 'integer' THEN
    IF jsonb_typeof(data) != 'number' THEN
      RETURN false;
    END IF;
    IF trunc(data::text::numeric) != data::text::numeric THEN
      RETURN false;
    END IF;
  ELSE
    IF type != jsonb_typeof(data) THEN
      RETURN false;
    END IF;
  END IF;
  RETURN true;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_json_schema(schema jsonb, data jsonb, root_schema jsonb DEFAULT NULL::jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  prop text;
  item jsonb;
  path text[];
  types text[];
  pattern text;
  props text[];
BEGIN
  IF root_schema IS NULL THEN
    root_schema = schema;
  END IF;

  IF schema ? 'type' THEN
    IF jsonb_typeof(schema->'type') = 'array' THEN
      types = ARRAY(SELECT jsonb_array_elements_text(schema->'type'));
    ELSE
      types = ARRAY[schema->>'type'];
    END IF;
    IF (SELECT NOT bool_or(_validate_json_schema_type(type, data)) FROM unnest(types) type) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'properties' THEN
    FOR prop IN SELECT jsonb_object_keys(schema->'properties') LOOP
      IF data ? prop AND NOT validate_json_schema(schema->'properties'->prop, data->prop, root_schema) THEN
        RETURN false;
      END IF;
    END LOOP;
  END IF;

  IF schema ? 'required' AND jsonb_typeof(data) = 'object' THEN
    IF NOT ARRAY(SELECT jsonb_object_keys(data)) @>
           ARRAY(SELECT jsonb_array_elements_text(schema->'required')) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'items' AND jsonb_typeof(data) = 'array' THEN
    IF jsonb_typeof(schema->'items') = 'object' THEN
      FOR item IN SELECT jsonb_array_elements(data) LOOP
        IF NOT validate_json_schema(schema->'items', item, root_schema) THEN
          RETURN false;
        END IF;
      END LOOP;
    ELSE
      IF NOT (
        SELECT bool_and(i > jsonb_array_length(schema->'items') OR validate_json_schema(schema->'items'->(i::int - 1), elem, root_schema))
        FROM jsonb_array_elements(data) WITH ORDINALITY AS t(elem, i)
      ) THEN
        RETURN false;
      END IF;
    END IF;
  END IF;

  IF jsonb_typeof(schema->'additionalItems') = 'boolean' and NOT (schema->'additionalItems')::text::boolean AND jsonb_typeof(schema->'items') = 'array' THEN
    IF jsonb_array_length(data) > jsonb_array_length(schema->'items') THEN
      RETURN false;
    END IF;
  END IF;

  IF jsonb_typeof(schema->'additionalItems') = 'object' THEN
    IF NOT (
        SELECT bool_and(validate_json_schema(schema->'additionalItems', elem, root_schema))
        FROM jsonb_array_elements(data) WITH ORDINALITY AS t(elem, i)
        WHERE i > jsonb_array_length(schema->'items')
      ) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minimum' AND jsonb_typeof(data) = 'number' THEN
    IF data::text::numeric < (schema->>'minimum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maximum' AND jsonb_typeof(data) = 'number' THEN
    IF data::text::numeric > (schema->>'maximum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF COALESCE((schema->'exclusiveMinimum')::text::bool, FALSE) THEN
    IF data::text::numeric = (schema->>'minimum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF COALESCE((schema->'exclusiveMaximum')::text::bool, FALSE) THEN
    IF data::text::numeric = (schema->>'maximum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'anyOf' THEN
    IF NOT (SELECT bool_or(validate_json_schema(sub_schema, data, root_schema)) FROM jsonb_array_elements(schema->'anyOf') sub_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'allOf' THEN
    IF NOT (SELECT bool_and(validate_json_schema(sub_schema, data, root_schema)) FROM jsonb_array_elements(schema->'allOf') sub_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'oneOf' THEN
    IF 1 != (SELECT COUNT(*) FROM jsonb_array_elements(schema->'oneOf') sub_schema WHERE validate_json_schema(sub_schema, data, root_schema)) THEN
      RETURN false;
    END IF;
  END IF;

  IF COALESCE((schema->'uniqueItems')::text::boolean, false) THEN
    IF (SELECT COUNT(*) FROM jsonb_array_elements(data)) != (SELECT count(DISTINCT val) FROM jsonb_array_elements(data) val) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'additionalProperties' AND jsonb_typeof(data) = 'object' THEN
    props := ARRAY(
      SELECT key
      FROM jsonb_object_keys(data) key
      WHERE key NOT IN (SELECT jsonb_object_keys(schema->'properties'))
        AND NOT EXISTS (SELECT * FROM jsonb_object_keys(schema->'patternProperties') pat WHERE key ~ pat)
    );
    IF jsonb_typeof(schema->'additionalProperties') = 'boolean' THEN
      IF NOT (schema->'additionalProperties')::text::boolean AND jsonb_typeof(data) = 'object' AND NOT props <@ ARRAY(SELECT jsonb_object_keys(schema->'properties')) THEN
        RETURN false;
      END IF;
    ELSEIF NOT (
      SELECT bool_and(validate_json_schema(schema->'additionalProperties', data->key, root_schema))
      FROM unnest(props) key
    ) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? '$ref' THEN
    path := ARRAY(
      SELECT regexp_replace(regexp_replace(path_part, '~1', '/'), '~0', '~')
      FROM UNNEST(regexp_split_to_array(schema->>'$ref', '/')) path_part
    );
    -- ASSERT path[1] = '#', 'only refs anchored at the root are supported';
    IF NOT validate_json_schema(root_schema #> path[2:array_length(path, 1)], data, root_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'enum' THEN
    IF NOT EXISTS (SELECT * FROM jsonb_array_elements(schema->'enum') val WHERE val = data) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minLength' AND jsonb_typeof(data) = 'string' THEN
    IF char_length(data #>> '{}') < (schema->>'minLength')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maxLength' AND jsonb_typeof(data) = 'string' THEN
    IF char_length(data #>> '{}') > (schema->>'maxLength')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'not' THEN
    IF validate_json_schema(schema->'not', data, root_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maxProperties' AND jsonb_typeof(data) = 'object' THEN
    IF (SELECT count(*) FROM jsonb_object_keys(data)) > (schema->>'maxProperties')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minProperties' AND jsonb_typeof(data) = 'object' THEN
    IF (SELECT count(*) FROM jsonb_object_keys(data)) < (schema->>'minProperties')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maxItems' AND jsonb_typeof(data) = 'array' THEN
    IF (SELECT count(*) FROM jsonb_array_elements(data)) > (schema->>'maxItems')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minItems' AND jsonb_typeof(data) = 'array' THEN
    IF (SELECT count(*) FROM jsonb_array_elements(data)) < (schema->>'minItems')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'dependencies' THEN
    FOR prop IN SELECT jsonb_object_keys(schema->'dependencies') LOOP
      IF data ? prop THEN
        IF jsonb_typeof(schema->'dependencies'->prop) = 'array' THEN
          IF NOT (SELECT bool_and(data ? dep) FROM jsonb_array_elements_text(schema->'dependencies'->prop) dep) THEN
            RETURN false;
          END IF;
        ELSE
          IF NOT validate_json_schema(schema->'dependencies'->prop, data, root_schema) THEN
            RETURN false;
          END IF;
        END IF;
      END IF;
    END LOOP;
  END IF;

  IF schema ? 'pattern' AND jsonb_typeof(data) = 'string' THEN
    IF (data #>> '{}') !~ (schema->>'pattern') THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'patternProperties' AND jsonb_typeof(data) = 'object' THEN
    FOR prop IN SELECT jsonb_object_keys(data) LOOP
      FOR pattern IN SELECT jsonb_object_keys(schema->'patternProperties') LOOP
        RAISE NOTICE 'prop %s, pattern %, schema %', prop, pattern, schema->'patternProperties'->pattern;
        IF prop ~ pattern AND NOT validate_json_schema(schema->'patternProperties'->pattern, data->prop, root_schema) THEN
          RETURN false;
        END IF;
      END LOOP;
    END LOOP;
  END IF;

  IF schema ? 'multipleOf' AND jsonb_typeof(data) = 'number' THEN
    IF data::text::numeric % (schema->>'multipleOf')::numeric != 0 THEN
      RETURN false;
    END IF;
  END IF;

  RETURN true;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_automated_reporting_ac');
CREATE OR REPLACE FUNCTION jazzhands.account_automated_reporting_ac()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_numrpt	INTEGER;
	_r		RECORD;
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.account_role != 'primary' THEN
			RETURN OLD;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.account_role != 'primary' AND OLD.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	END IF;

	-- XXX check account realm to see if we should be inserting for this
	-- XXX account realm

	IF TG_OP = 'INSERT' THEN
		PERFORM auto_ac_manip.make_all_auto_acs_right(
			account_id := NEW.account_id,
			account_realm_id := NEW.account_realm_id,
			login := NEW.login
		);
	ELSIF TG_OP = 'UPDATE' THEN
		PERFORM auto_ac_manip.rename_automated_report_acs(
			NEW.account_id, OLD.login, NEW.login, NEW.account_realm_id);
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM account_collection_account WHERE account_id
			= OLD.account_id
		AND account_collection_id IN ( select account_collection_id
			FROM account_collection where account_collection_type
			= 'automated'
		);
		-- PERFORM auto_ac_manip.destroy_report_account_collections(
		--	account_id := OLD.account_id,
		--	account_realm_id := OLD.account_realm_id
		-- );
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
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_coll_member_relation_enforce');
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

	IF act.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		SELECT count(*)
		  INTO tally
		  FROM account_collection_account
		  		JOIN account_collection USING (account_collection_id)
		  WHERE account_collection_type = act.account_collection_type
		  AND account_collection_relation = NEW.account_collection_relation
		  AND account_id = NEW.account_id;

		IF tally > act.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'account % is in too many collections of type %/%',
				NEW.account_id,
				act.account_collection_type,
				act.account_collection_relation
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_ip_universe_trigger_change');
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_ip_universe_trigger_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF NEW.should_generate = 'Y' THEN
		insert into DNS_CHANGE_RECORD
			(dns_domain_id) VALUES (NEW.dns_domain_id);
    ELSE
		DELETE FROM DNS_CHANGE_RECORD
		WHERE dns_domain_id = NEW.dns_domain_id
		AND ip_universe_id = NEW.ip_universe_id;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_nouniverse_ins');
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_nouniverse_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_d	dns_domain.dns_domain_id%TYPE;
BEGIN
	IF NEW.dns_domain_id IS NULL THEN
		INSERT INTO dns_domain (
			dns_domain_name, dns_domain_type, parent_dns_domain_id
		) VALUES (
			NEW.soa_name, NEW.dns_domain_type, NEW.parent_dns_domain_id
		) RETURNING dns_domain_id INTO _d;
	ELSE
		INSERT INTO dns_domain (
			dns_domain_id, dns_domain_name, dns_domain_type,
			parent_dns_domain_id
		) VALUES (
			NEW.dns_domain_id, NEW.soa_name, NEW.dns_domain_type,
			NEW.parent_dns_domain_id
		) RETURNING dns_domain_id INTO _d;
	END IF;

	NEW.dns_domain_id := _d;

	INSERT INTO dns_domain_ip_universe (
		dns_domain_id, ip_universe_id,
		soa_class, soa_ttl, soa_serial, soa_refresh,
		soa_retry,
		soa_expire, soa_minimum, soa_mname, soa_rname,
		should_generate, last_generated
	) VALUES (
		_d, 0,
		NEW.soa_class, NEW.soa_ttl, NEW.soa_serial, NEW.soa_refresh,
		NEW.soa_retry,
		NEW.soa_expire, NEW.soa_minimum, NEW.soa_mname, NEW.soa_rname,
		NEW.should_generate, NEW.last_generated
	);
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_nouniverse_upd');
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_nouniverse_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	upd_query	TEXT[];
BEGIN
	IF OLD.dns_domain_id IS DISTINCT FROM NEW.dns_domain_id THEN
		RAISE EXCEPTION 'dns_domain_id can not be updated';
	END IF;

	upd_query := NULL;
	IF OLD.soa_name IS DISTINCT FROM NEW.soa_name THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.soa_name));
	END IF;
	IF OLD.parent_dns_domain_id IS DISTINCT FROM NEW.parent_dns_domain_id THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.parent_dns_domain_id));
	END IF;
	IF OLD.dns_domain_type IS DISTINCT FROM NEW.dns_domain_type THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.dns_domain_type));
	END IF;
	IF upd_query IS NOT NULL THEN
		EXECUTE 'UPDATE dns_domain SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE dns_domain_id = $1'
		USING
			NEW.dns_domain_id;
	END IF;

	upd_query := NULL;
	IF OLD.soa_class IS DISTINCT FROM NEW.soa_class THEN
		upd_query := array_append( upd_query,
			'soa_class = ' || quote_nullable(NEW.soa_class));
	END IF;

	IF OLD.soa_ttl IS DISTINCT FROM NEW.soa_ttl THEN
		upd_query := array_append( upd_query,
			'soa_ttl = ' || quote_nullable(NEW.soa_ttl));
	END IF;

	IF OLD.soa_serial IS DISTINCT FROM NEW.soa_serial THEN
		upd_query := array_append( upd_query,
			'soa_serial = ' || quote_nullable(NEW.soa_serial));
	END IF;

	IF OLD.soa_refresh IS DISTINCT FROM NEW.soa_refresh THEN
		upd_query := array_append( upd_query,
			'soa_refresh = ' || quote_nullable(NEW.soa_refresh));
	END IF;

	IF OLD.soa_retry IS DISTINCT FROM NEW.soa_retry THEN
		upd_query := array_append( upd_query,
			'soa_retry = ' || quote_nullable(NEW.soa_retry));
	END IF;

	IF OLD.soa_expire IS DISTINCT FROM NEW.soa_expire THEN
		upd_query := array_append( upd_query,
			'soa_expire = ' || quote_nullable(NEW.soa_expire));
	END IF;

	IF OLD.soa_minimum IS DISTINCT FROM NEW.soa_minimum THEN
		upd_query := array_append( upd_query,
			'soa_minimum = ' || quote_nullable(NEW.soa_minimum));
	END IF;

	IF OLD.soa_mname IS DISTINCT FROM NEW.soa_mname THEN
		upd_query := array_append( upd_query,
			'soa_mname = ' || quote_nullable(NEW.soa_mname));
	END IF;

	IF OLD.soa_rname IS DISTINCT FROM NEW.soa_rname THEN
		upd_query := array_append( upd_query,
			'soa_rname = ' || quote_nullable(NEW.soa_rname));
	END IF;

	IF OLD.should_generate IS DISTINCT FROM NEW.should_generate THEN
		upd_query := array_append( upd_query,
			'should_generate = ' || quote_nullable(NEW.should_generate));
	END IF;

	IF OLD.last_generated IS DISTINCT FROM NEW.last_generated THEN
		upd_query := array_append( upd_query,
			'last_generated = ' || quote_nullable(NEW.last_generated));
	END IF;


	IF upd_query IS NOT NULL THEN
		EXECUTE 'UPDATE dns_domain_ip_universe SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE ip_universe_id = 0 AND dns_domain_id = $1'
		USING
			NEW.dns_domain_id;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_trigger_change');
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_trigger_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	PERFORM *
	FROM dns_domain_ip_universe
	WHERE dns_domain_id = NEW.dns_domain_id
	AND SHOULD_GENERATE = 'Y';
	IF FOUND THEN
		INSERT INTO dns_change_record
			(dns_domain_id) VALUES (NEW.dns_domain_id);
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'ins_x509_certificate');
CREATE OR REPLACE FUNCTION jazzhands.ins_x509_certificate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	key	private_key.private_key_id%TYPE;
	csr	certificate_signing_request.certificate_signing_request_id%TYPE;
	crt	x509_signed_certificate.x509_signed_certificate_id%TYPE;
BEGIN
	IF NEW.private_key IS NOT NULL THEN
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
		) RETURNING private_key_id INTO key;
		NEW.x509_cert_id := key;
	ELSE
		IF NEW.subject_key_identifier IS NOT NULL THEN
			SELECT private_key_id
			INTO key
			FROM private_key
			WHERE subject_key_identifier = NEW.subject_key_identifier;

			SELECT private_key
			INTO NEW.private_key
			FROM private_key
			WHERE private_key_id = key;
		END IF;
	END IF;

	IF NEW.certificate_sign_req IS NOT NULL THEN
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
		) RETURNING certificate_signing_request_id INTO csr;
		IF NEW.x509_cert_id IS NULL THEN
			NEW.x509_cert_id := csr;
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
			WHERE certificate_signing_request_id  = csr;
		END IF;
	END IF;

	IF NEW.public_key IS NOT NULL THEN
		INSERT INTO x509_signed_certificate (
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
			NEW.is_active,
			NEW.is_certificate_authority,
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
			key,
			csr
		) RETURNING x509_signed_certificate_id INTO crt;
		NEW.x509_cert_id := crt;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock_single_address_ni');
CREATE OR REPLACE FUNCTION jazzhands.netblock_single_address_ni()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF (NEW.is_single_address = 'N' AND OLD.is_single_address = 'Y') OR
		(NEW.netblock_type != 'default' AND OLD.netblock_type = 'default')
			THEN
		select count(*)
		INTO _tally
		FROM network_interface_netblock
		WHERE netblock_id = NEW.netblock_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'network interfaces must refer to single ip addresses of type default address (%,%)', NEW.ip_address, NEW.netblock_id
				USING errcode = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock');
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	nbtype				RECORD;
	v_netblock_id		netblock.netblock_id%TYPE;
	parent_netblock		RECORD;
	tmp_nb				RECORD;
	universes			integer[];
	netmask_bits		integer;
	tally				integer;
BEGIN
	IF NEW.ip_address IS NULL THEN
		RAISE EXCEPTION 'Column ip_address may not be null'
			USING ERRCODE = 'not_null_violation';
	END IF;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	IF NEW.is_single_address = 'Y' THEN
		IF nbtype.db_forced_hierarchy = 'Y' THEN
			RAISE DEBUG 'Calculating netmask for new netblock';

			v_netblock_id := netblock_utils.find_best_parent_id(
				NEW.ip_address,
				NULL,
				NEW.netblock_type,
				NEW.ip_universe_id,
				NEW.is_single_address,
				NEW.netblock_id
				);

			IF v_netblock_id IS NULL THEN
				RAISE EXCEPTION 'A single address (%) must be the child of a parent netblock, which must have can_subnet=N', NEW.ip_address
					USING ERRCODE = 'JH105';
			END IF;

			SELECT masklen(ip_address) INTO netmask_bits FROM
				netblock WHERE netblock_id = v_netblock_id;

			NEW.ip_address := set_masklen(NEW.ip_address, netmask_bits);
		END IF;
	END IF;

	/* Done with handling of netmasks */

	IF NEW.can_subnet = 'Y' AND NEW.is_single_address = 'Y' THEN
		RAISE EXCEPTION 'Single addresses may not be subnettable'
			USING ERRCODE = 'JH106';
	END IF;

	IF NEW.is_single_address = 'N' AND (NEW.ip_address != cidr(NEW.ip_address))
			THEN
		RAISE EXCEPTION
			'Non-network bits must be zero if is_single_address is N for %',
			NEW.ip_address
			USING ERRCODE = 'JH103';
	END IF;

	/*
	 * This used to only happen for not-rfc1918 space, but that sort of
	 * uniqueness enforcement is done through ip universes now.
	 */
	SELECT * FROM netblock INTO tmp_nb
	WHERE
		ip_address = NEW.ip_address AND
		ip_universe_id = NEW.ip_universe_id AND
		netblock_type = NEW.netblock_type AND
		is_single_address = NEW.is_single_address
	LIMIT 1;

	IF (TG_OP = 'INSERT' AND FOUND) THEN
		RAISE EXCEPTION E'Unique Constraint Violated on IP Address: %\nFailing row is %\nConflicts with: %',
			NEW.ip_address, row_to_json(NEW), row_to_json(tmp_nb)
			USING ERRCODE= 'unique_violation';
	END IF;
	IF (TG_OP = 'UPDATE') THEN
		IF (NEW.ip_address != OLD.ip_address AND FOUND) THEN
			RAISE EXCEPTION E'Unique Constraint Violated on IP Address: %\nFailing row is %\nConflicts with: %',
				NEW.ip_address, row_to_json(NEW), row_to_json(tmp_nb)
				USING ERRCODE= 'unique_violation';
		END IF;
	END IF;

	/*
	 * for networks, check for uniqueness across ip universe and ip visibility
	 */
	IF NEW.is_single_address = 'N' THEN
		WITH x AS (
				SELECT	ip_universe_id
				FROM	ip_universe
				WHERE	ip_namespace IN (
							SELECT ip_namespace FROM ip_universe
							WHERE ip_universe_id = NEW.ip_universe_id
						)
				AND		ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	visible_ip_universe_id
				FROM	ip_universe_visibility
				WHERE	ip_universe_id = NEW.ip_universe_id
				AND		ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	ip_universe_id
				FROM	ip_universe_visibility
				WHERE	visible_ip_universe_id = NEW.ip_universe_id
				AND		visible_ip_universe_id != NEW.ip_universe_id
		) SELECT count(*) INTO tally
		FROM netblock
		WHERE ip_address = NEW.ip_address AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id IN (select ip_universe_id FROM x) AND
			is_single_address = 'N' AND
			netblock_id != NEW.netblock_id
		;

		IF tally >  0 THEN
			RAISE EXCEPTION
				'IP Universe Constraint Violated on IP Address: % Universe: %',
				NEW.ip_address, NEW.ip_universe_id
				USING ERRCODE= 'unique_violation';
		END IF;

		IF NEW.can_subnet = 'N' THEN
			WITH x AS (
				SELECT	ip_universe_id
				FROM	ip_universe
				WHERE	ip_namespace IN (
							SELECT ip_namespace FROM ip_universe
							WHERE ip_universe_id = NEW.ip_universe_id
						)
				AND		ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	visible_ip_universe_id
				FROM	ip_universe_visibility
				WHERE	ip_universe_id = NEW.ip_universe_id
				AND		visible_ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	ip_universe_id
				FROM	ip_universe_visibility
				WHERE	visible_ip_universe_id = NEW.ip_universe_id
				AND		ip_universe_id != NEW.ip_universe_id
			) SELECT count(*) INTO tally
			FROM netblock
			WHERE
				ip_universe_id IN (select ip_universe_id FROM x) AND
				(
					ip_address <<= NEW.ip_address OR
					ip_address >>= NEW.ip_address
				) AND
				netblock_type = NEW.netblock_type AND
				is_single_address = 'N' AND
				can_subnet = 'N' AND
				netblock_id != NEW.netblock_id
			;

			IF tally >  0 THEN
				RAISE EXCEPTION
					'Can Subnet = N IP Universe Constraint Violated on IP Address: % Universe: %',
					NEW.ip_address, NEW.ip_universe_id
					USING ERRCODE= 'unique_violation';
			END IF;
		END IF;
	END IF;

	/*
	 * Parent validation is performed in the deferred after trigger
	 */

	 RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock_parentage');
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_parentage()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	nbrec			record;
	realnew			record;
	nbtype			record;
	parent_nbid		netblock.netblock_id%type;
	parent_rec		record;
	ipaddr			inet;
	parent_ipaddr	inet;
	single_count	integer;
	nonsingle_count	integer;
	pip	    		netblock.ip_address%type;
BEGIN

	RAISE DEBUG 'Validating % of netblock %', TG_OP, NEW.netblock_id;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	/*
	 * It's possible that due to delayed triggers that what is stored in
	 * NEW is not current, so fetch the current values
	 */

	SELECT * INTO realnew FROM netblock WHERE netblock_id =
		NEW.netblock_id;
	IF NOT FOUND THEN
		/*
		 * If the netblock isn't there, it was subsequently deleted, so
		 * our parentage doesn't need to be checked
		 */
		RETURN NULL;
	END IF;


	/*
	 * If the parent changed above (or somewhere else between update and
	 * now), just bail, because another trigger will have been fired that
	 * we can do the full check with.
	 */
	IF NEW.parent_netblock_id != realnew.parent_netblock_id AND
		realnew.parent_netblock_id IS NOT NULL
	THEN
		RAISE DEBUG '... skipping for now';
		RETURN NULL;
	END IF;

	/*
	 * Validate that parent and all children are of the same netblock_type and
	 * in the same ip_universe.  We care about this even if the
	 * netblock type is not a validated type.
	 */

	RAISE DEBUG 'Verifying child ip_universe and type match';
	PERFORM netblock_id FROM netblock WHERE
		parent_netblock_id = realnew.netblock_id AND
		netblock_type != realnew.netblock_type AND
		ip_universe_id != realnew.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 'JH109';
	END IF;

	RAISE DEBUG '... OK';

	/*
	 * validate that this netblock is attached to its correct parent
	 */
	IF realnew.parent_netblock_id IS NULL THEN
		IF nbtype.is_validated_hierarchy='N' THEN
			RETURN NULL;
		END IF;
		RAISE DEBUG 'Checking hierarchical netblock_id % with NULL parent',
			NEW.netblock_id;

		IF realnew.is_single_address = 'Y' THEN
			RAISE 'A single address (%) must be the child of a parent netblock, which must have can_subnet=N',
				realnew.ip_address
				USING ERRCODE = 'JH105';
		END IF;

		/*
		 * Validate that a netblock has a parent, unless
		 * it is the root of a hierarchy
		 */
		parent_nbid := netblock_utils.find_best_parent_id(
			realnew.ip_address,
			NULL,
			realnew.netblock_type,
			realnew.ip_universe_id,
			realnew.is_single_address,
			realnew.netblock_id
		);

		IF parent_nbid IS NOT NULL THEN
			SELECT * INTO nbrec FROM netblock WHERE netblock_id =
				parent_nbid;

			RAISE EXCEPTION 'Netblock % (%) has NULL parent; should be % (%)',
				realnew.netblock_id, realnew.ip_address,
				parent_nbid, nbrec.ip_address USING ERRCODE = 'JH102';
		END IF;

		/*
		 * Validate that none of the other top-level netblocks should
		 * belong to this netblock
		 */
		PERFORM netblock_id FROM netblock WHERE
			parent_netblock_id IS NULL AND
			netblock_id != NEW.netblock_id AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id = NEW.ip_universe_id AND
			ip_address <<= NEW.ip_address;
		IF FOUND THEN
			RAISE EXCEPTION 'Other top-level netblocks should belong to this parent'
				USING ERRCODE = 'JH108';
		END IF;
	ELSE
	 	/*
		 * Reject a block that is self-referential
		 */
	 	IF realnew.parent_netblock_id = realnew.netblock_id THEN
			RAISE EXCEPTION 'Netblock may not have itself as a parent'
				USING ERRCODE = 'JH101';
		END IF;

		SELECT * INTO nbrec FROM netblock WHERE netblock_id =
			realnew.parent_netblock_id;

		/*
		 * This shouldn't happen, but may because of deferred constraints
		 */
		IF NOT FOUND THEN
			RAISE EXCEPTION 'Parent netblock % does not exist',
			realnew.parent_netblock_id
			USING ERRCODE = 'foreign_key_violation';
		END IF;

		IF nbrec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'A parent netblock (% for %) may not be a single address',
			nbrec.netblock_id, realnew.ip_address
			USING ERRCODE = 'JH10A';
		END IF;

		IF nbrec.ip_universe_id != realnew.ip_universe_id OR
				nbrec.netblock_type != realnew.netblock_type THEN
			RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 'JH109';
		END IF;

		IF nbtype.is_validated_hierarchy='N' THEN
			RETURN NULL;
		ELSE
			parent_nbid := netblock_utils.find_best_parent_id(
				realnew.ip_address,
				NULL,
				realnew.netblock_type,
				realnew.ip_universe_id,
				realnew.is_single_address,
				realnew.netblock_id
				);

			SELECT * FROM netblock INTO parent_rec WHERE netblock_id =
				parent_nbid;

			IF realnew.can_subnet = 'N' THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					is_single_address = 'N';
				IF FOUND THEN
					RAISE EXCEPTION E'A non-subnettable netblock may not have child network netblocks\nParent: %\nChild: %\n',
						row_to_json(parent_rec, true),
						row_to_json(realnew, true)
					USING ERRCODE = 'JH10B';
				END IF;
			END IF;
			IF realnew.is_single_address = 'Y' THEN
				SELECT * INTO nbrec FROM netblock
					WHERE netblock_id = realnew.parent_netblock_id;
				IF (nbrec.can_subnet = 'Y') THEN
					RAISE 'Parent netblock % for single-address % must have can_subnet=N',
						nbrec.netblock_id,
						realnew.ip_address
						USING ERRCODE = 'JH10D';
				END IF;
				IF (masklen(realnew.ip_address) !=
						masklen(nbrec.ip_address)) THEN
					RAISE 'Parent netblock % does not have the same netmask as single-address child % (% vs %)',
						parent_nbid, realnew.netblock_id,
						masklen(nbrec.ip_address),
						masklen(realnew.ip_address)
						USING ERRCODE = 'JH105';
				END IF;
			END IF;
			IF (parent_nbid IS NULL OR realnew.parent_netblock_id != parent_nbid) THEN
				SELECT ip_address INTO parent_ipaddr FROM netblock
				WHERE
					netblock_id = parent_nbid;
				SELECT ip_address INTO ipaddr FROM netblock WHERE
					netblock_id = realnew.parent_netblock_id;

				RAISE EXCEPTION
					'Parent netblock % (%) for netblock % (%) is not the correct parent (should be % (%))',
					realnew.parent_netblock_id, ipaddr,
					realnew.netblock_id, realnew.ip_address,
					parent_nbid, parent_ipaddr
					USING ERRCODE = 'JH102';
			END IF;
			/*
			 * Validate that all children are is_single_address='Y' or
			 * all children are is_single_address='N'
			 */
			SELECT count(*) INTO single_count FROM netblock WHERE
				is_single_address='Y' and parent_netblock_id =
				realnew.parent_netblock_id;
			SELECT count(*) INTO nonsingle_count FROM netblock WHERE
				is_single_address='N' and parent_netblock_id =
				realnew.parent_netblock_id;

			IF (single_count > 0 and nonsingle_count > 0) THEN
				SELECT * INTO nbrec FROM netblock WHERE netblock_id =
					realnew.parent_netblock_id;
				RAISE EXCEPTION 'Netblock % (%) may not have direct children for both single and multiple addresses simultaneously',
					nbrec.netblock_id, nbrec.ip_address
					USING ERRCODE = 'JH107';
			END IF;
			/*
			 *  If we're updating and we changed our ip_address (including
			 *  netmask bits), then check that our children still belong to
			 *  us
			 */
			 IF (TG_OP = 'UPDATE' AND NEW.ip_address != OLD.ip_address) THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					((is_single_address = 'Y' AND NEW.ip_address !=
						ip_address::cidr) OR
					(is_single_address = 'N' AND realnew.netblock_id !=
						netblock_utils.find_best_parent_id(netblock_id)));
				IF FOUND THEN
					RAISE EXCEPTION 'Update for netblock % (%) causes parent to have children that do not belong to it',
						realnew.netblock_id, realnew.ip_address
						USING ERRCODE = 'JH10E';
				END IF;
			END IF;

			/*
			 * Validate that none of the children of the parent netblock are
			 * children of this netblock (e.g. if inserting into the middle
			 * of the hierarchy)
			 */
			IF (realnew.is_single_address = 'N') THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.parent_netblock_id AND
					netblock_id != realnew.netblock_id AND
					ip_address <<= realnew.ip_address;
				IF FOUND THEN
					RAISE EXCEPTION 'Other netblocks have children that should belong to parent % (%)',
						realnew.parent_netblock_id, realnew.ip_address
						USING ERRCODE = 'JH108';
				END IF;
			END IF;
		END IF;
	END IF;

	RETURN NULL;
END;
$function$
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
			property_value_json IS NOT DISTINCT FROM
				NEW.property_value_json AND
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
CREATE OR REPLACE FUNCTION jazzhands.account_status_per_row_after_hooks()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	BEGIN
		PERFORM local_hooks.account_status_per_row_after_hooks(account_record => NEW);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
	RETURN NULL;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.net_int_device_id_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	UPDATE network_interface_netblock
	SET device_id = NEW.device_id
	WHERE	network_interface_id = NEW.network_interface_id;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.net_int_nb_device_id_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.device_id IS NULL OR TG_OP = 'UPDATE' THEN
		SELECT device_id
		INTO	NEW.device_id
		FROM	network_interface
		WHERE	network_interface_id = NEW.network_interface_id;
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_val_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
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
-- Process drops in auto_ac_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'destroy_report_account_collections');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.destroy_report_account_collections ( account_id integer, account_realm_id integer, numrpt integer, numrlup integer );
CREATE OR REPLACE FUNCTION auto_ac_manip.destroy_report_account_collections(account_id integer, account_realm_id integer DEFAULT NULL::integer, numrpt integer DEFAULT NULL::integer, numrlup integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_account	account%ROWTYPE;
	_directac	account_collection.account_collection_id%TYPE;
	_rollupac	account_collection.account_collection_id%TYPE;
BEGIN
	IF account_realm_id IS NULL THEN
		EXECUTE '
			SELECT account_realm_id
			FROM	account
			WHERE	account_id = $1
		' INTO account_realm_id USING account_id;
	END IF;

	IF numrpt IS NULL THEN
		numrpt := auto_ac_manip.get_num_direct_reports(account_id, account_realm_id);
	END IF;
	IF numrpt = 0 THEN
		PERFORM auto_ac_manip.purge_report_account_collection(
			account_id := account_id,
			account_realm_id := account_realm_id,
			ac_type := 'AutomatedDirectsAC');
		RETURN;
	END IF;

	IF numrlup IS NULL THEN
		numrlup := auto_ac_manip.get_num_reports_with_reports(account_id, account_realm_id);
	END IF;
	IF numrlup = 0 THEN
		PERFORM auto_ac_manip.purge_report_account_collection(
			account_id := account_id,
			account_realm_id := account_realm_id,
			ac_type := 'AutomatedRollupsAC');
		RETURN;
	END IF;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'find_or_create_automated_ac');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.find_or_create_automated_ac ( account_id integer, ac_type character varying, account_realm_id integer, login character varying );
CREATE OR REPLACE FUNCTION auto_ac_manip.find_or_create_automated_ac(account_id integer, ac_type character varying, account_realm_id integer DEFAULT NULL::integer, login character varying DEFAULT NULL::character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_acname		text;
	_acid		account_collection.account_collection_id%TYPE;
BEGIN
	IF login is NULL THEN
		EXECUTE 'SELECT account_realm_id,login
			FROM account where account_id = $1'
			INTO account_realm_id,login USING account_id;
	END IF;

	IF ac_type = 'AutomatedDirectsAC' THEN
		_acname := concat(login, '-employee-directs');
	ELSIF ac_type = 'AutomatedRollupsAC' THEN
		_acname := concat(login, '-employee-rollup');
	ELSE
		RAISE EXCEPTION 'Do not know how to name Automated AC type %', ac_type;
	END IF;

	--
	-- Check to see if a -direct account collection exists already.  If not,
	-- create it.  There is a bit of a problem here if the name is not unique
	-- or otherwise messed up.  This will just raise errors.
	--
	EXECUTE 'SELECT ac.account_collection_id
			FROM account_collection ac
				INNER JOIN property p
					ON p.property_value_account_coll_id = ac.account_collection_id
		   WHERE ac.account_collection_name = $1
		    AND	ac.account_collection_type = $2
			AND	p.property_name = $3
			AND p.property_type = $4
			AND p.account_id = $5
			AND p.account_realm_id = $6
		' INTO _acid USING _acname, 'automated',
				ac_type, 'auto_acct_coll', account_id,
				account_realm_id;

	-- Assume the person is always in their own account collection, or if tehy
	-- are not someone took them out for a good reason.  (Thus, they are only
	-- added on creation).
	IF _acid IS NULL THEN
		EXECUTE 'INSERT INTO account_collection (
					account_collection_name, account_collection_type
				) VALUES ( $1, $2) RETURNING *
			' INTO _acid USING _acname, 'automated';

		IF ac_type = 'AutomatedDirectsAC' THEN
			EXECUTE 'INSERT INTO account_collection_account (
						account_collection_id, account_id
					) VALUES (  $1, $2 )
				' USING _acid, account_id;
		END IF;

		EXECUTE '
			INSERT INTO property (
				account_id,
				account_realm_id,
				property_name,
				property_type,
				property_value_account_coll_id
			)  VALUES ( $1, $2, $3, $4, $5)'
			USING account_id, account_realm_id,
				ac_type, 'auto_acct_coll', _acid;
	END IF;

	RETURN _acid;
END;
$function$
;

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
			AND		is_enabled = ''Y''
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
					manager_person_id, is_enabled
			FROM	account a
				INNER JOIN person_company USING (person_id, company_id)
			WHERE	account_role = $3
			AND		account_type = ''person''
			AND		person_company_relation = ''employee''
			AND		account_realm_id = $2
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
			WHERE reports.is_enabled = ''Y''
		), rank AS (
			SELECT *,
				rank() OVER (partition by account_id ORDER BY property_name desc)
					as rank
			FROM agg
		) SELECT count(*) from rank
		WHERE	manager_account_id =  $1
		AND	account_realm_id = $2
		AND	rank = 1;
	' INTO _numrlup USING account_id, account_realm_id, 'primary',
				'AutomatedDirectsAC','AutomatedRollupsAC','auto_acct_coll';

	RETURN _numrlup;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'make_personal_acs_right');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.make_personal_acs_right ( account_id integer );
CREATE OR REPLACE FUNCTION auto_ac_manip.make_personal_acs_right(account_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	EXECUTE '
	WITH ac AS (
		SELECT DISTINCT ac.*
		FROM	account_collection ac
				INNER JOIN property p USING (account_collection_id)
		WHERE	property_type = ''auto_acct_coll''
		AND		property_name in (''non_exempt'', ''exempt'',
					''management'', ''non_management'', ''full_time'',
					''non_full_time'', ''male'', ''female'', ''unspecified_gender'',
					''account_type'', ''person_company_relation'')
	), acct AS (
		    SELECT  a.account_id, a.account_type, a.account_role, parc.*,
			    pc.is_management, pc.is_full_time, pc.is_exempt,
			    p.gender, pc.person_company_relation
		     FROM   account a
			    INNER JOIN person_account_realm_company parc
				    USING (person_id, company_id, account_realm_id)
			    INNER JOIN person_company pc USING (person_id,company_id)
			    INNER JOIN person p USING (person_id)
			WHERE a.is_enabled = ''Y''
			AND a.account_role = ''primary''
		),
	list AS (
		SELECT  p.account_collection_id, a.account_id, a.account_type,
			a.account_role,
			a.person_id, a.company_id,
			ac.account_collection_name, ac.account_collection_type,
			p.property_name, p.property_type, p.property_value, p.property_id
		FROM    property p
			INNER JOIN ac USING (account_collection_id)
		    INNER JOIN acct a
				ON a.account_realm_id = p.account_realm_id
		WHERE   (p.company_id is NULL or a.company_id = p.company_id)
		    AND     property_type = ''auto_acct_coll''
			AND	( a.account_type = ''person''
				AND a.person_company_relation = ''employee''
				AND (
			(
				property_name =
					CASE WHEN a.is_exempt = ''N''
					THEN ''non_exempt''
					ELSE ''exempt'' END
				OR
				property_name =
					CASE WHEN a.is_management = ''N''
					THEN ''non_management''
					ELSE ''management'' END
				OR
				property_name =
					CASE WHEN a.is_full_time = ''N''
					THEN ''non_full_time''
					ELSE ''full_time'' END
				OR
				property_name =
					CASE WHEN a.gender = ''M'' THEN ''male''
					WHEN a.gender = ''F'' THEN ''female''
					ELSE ''unspecified_gender'' END
			) )
			OR (
			    property_name = ''account_type''
			    AND property_value = a.account_type
			    )
			OR (
			    property_name = ''person_company_relation''
			    AND property_value = a.person_company_relation
			    )
			)
	), ins AS (
			INSERT INTO account_collection_account
				(account_collection_id, account_id)
			SELECT	account_collection_id, account_id
			FROM	 list
			WHERE	 (account_collection_id, account_id) NOT IN
					(SELECT account_collection_id, account_id FROM
						account_collection_account
					JOIN ac USING (account_collection_id) )
			AND account_id = $1
		RETURNING *
	), del AS (
		DELETE
		FROM	 account_collection_account
		WHERE	 (account_collection_id, account_id) NOT IN
				 (SELECT account_collection_id, account_id FROM
					list JOIN ac USING (account_collection_id))
		AND		(account_collection_id, account_id) IN
				(SELECT account_collection_id,account_id from ac)
		AND account_id = $1 RETURNING *
	), combo AS (
		SELECT * from ins UNION select * FROM del
	) SELECT count(*)
		FROM combo
		JOIN account_collection USING (account_collection_id);
	' INTO _tally USING account_id;
	RETURN _tally;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'make_site_acs_right');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.make_site_acs_right ( account_id integer );
CREATE OR REPLACE FUNCTION auto_ac_manip.make_site_acs_right(account_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	EXECUTE '
	WITH ac AS (
		SELECT DISTINCT ac.*
		FROM	account_collection ac
				INNER JOIN property p USING (account_collection_id)
		WHERE	property_type = ''auto_acct_coll''
		AND		property_name in (''site'')
	), acct AS (
		    SELECT  a.account_id, a.account_type, a.account_role, parc.*,
			    pc.is_management, pc.is_full_time, pc.is_exempt,
			    p.gender, pc.person_company_relation
		     FROM   account a
			    INNER JOIN person_account_realm_company parc
				    USING (person_id, company_id, account_realm_id)
			    INNER JOIN person_company pc USING (person_id,company_id)
			    INNER JOIN person p USING (person_id)
			WHERE a.is_enabled = ''Y''
			AND a.account_role = ''primary''
	), list AS (
		SELECT  p.account_collection_id, a.account_id, a.account_type,
			a.account_role,
			a.person_id, a.company_id,
			ac.account_collection_name, ac.account_collection_type,
			p.property_name, p.property_type, p.property_value, p.property_id
		FROM    property p
			INNER JOIN ac USING (account_collection_id)
		    INNER JOIN acct a
				ON a.account_realm_id = p.account_realm_id
			INNER JOIN person_location pl on a.person_id = pl.person_id
		WHERE   (p.company_id is NULL or a.company_id = p.company_id)
		AND		a.person_company_relation = ''employee''
		AND		property_type = ''auto_acct_coll''
		AND		p.site_code = pl.site_code
		AND		property_name = ''site''
	), ins AS (
			INSERT INTO account_collection_account
				(account_collection_id, account_id)
			SELECT	account_collection_id, account_id
			FROM	 list
			WHERE	 (account_collection_id, account_id) NOT IN
					(SELECT account_collection_id, account_id FROM
						account_collection_account
					JOIN ac USING (account_collection_id) )
			AND account_id = $1
		RETURNING *
	), del AS (
		DELETE
		FROM	 account_collection_account
		WHERE	 (account_collection_id, account_id) NOT IN
				 (SELECT account_collection_id, account_id FROM
					list JOIN ac USING (account_collection_id))
		AND		(account_collection_id, account_id) IN
				(SELECT account_collection_id,account_id from ac)
		AND account_id = $1 RETURNING *
	), combo AS (
		SELECT * from ins UNION select * FROM del
	) SELECT count(*)
		FROM combo
		JOIN account_collection USING (account_collection_id);
	' INTO _tally USING account_id;
	RETURN _tally;
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
				FROM account
				WHERE account_id = $1
				AND is_enabled = ''Y''
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

-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'purge_report_account_collection');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.purge_report_account_collection ( account_id integer, account_realm_id integer, ac_type character varying );
CREATE OR REPLACE FUNCTION auto_ac_manip.purge_report_account_collection(account_id integer, account_realm_id integer, ac_type character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	EXECUTE '
		DELETE FROM account_collection_account
		WHERE account_collection_ID IN (
			SELECT	property_value_account_coll_id
			FROM	property
			WHERE	property_name = $3
			AND		property_type = $4
			AND		account_id = $1
			AND		account_realm_id = $2
		)' USING account_id, account_realm_id, ac_type, 'auto_acct_coll';

	EXECUTE '
		WITH p AS (
			SELECT	property_value_account_coll_id AS account_collection_id
			FROM	property
			WHERE	property_name = $3
			AND		property_type = $4
			AND		account_id = $1
			AND		account_realm_id = $2
		)
		DELETE FROM account_collection_hier
		WHERE account_collection_id IN ( select account_collection_id from p)
		OR child_account_collection_id IN
			( select account_collection_id from p)
		' USING account_id, account_realm_id, ac_type, 'auto_acct_coll';

	EXECUTE '
		WITH list AS (
			SELECT	property_value_account_coll_id as account_collection_id,
					property_id
			FROM	property
			WHERE	property_name = $3
			AND		property_type = $4
			AND		account_id = $1
			AND		account_realm_id = $2
		), props AS (
			DELETE FROM property WHERE property_id IN
				(select property_id FROM list ) RETURNING *
		) DELETE FROM account_collection WHERE account_collection_id IN
				(select property_value_account_coll_id FROM props )
		' USING account_id, account_realm_id, ac_type, 'auto_acct_coll';

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'rename_automated_report_acs');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.rename_automated_report_acs ( account_id integer, old_login character varying, new_login character varying, account_realm_id integer );
CREATE OR REPLACE FUNCTION auto_ac_manip.rename_automated_report_acs(account_id integer, old_login character varying, new_login character varying, account_realm_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	EXECUTE '
		UPDATE account_collection
		  SET	account_collection_name =
				replace(account_collection_name, $6, $7)
		WHERE	account_collection_id IN (
				SELECT property_value_account_coll_id
				FROM	property
				WHERE	property_name IN ($3, $4)
				AND		property_type = $5
				AND		account_id = $1
				AND		account_realm_id = $2
		)' USING	account_id, account_realm_id,
				'AutomatedDirectsAC','AutomatedRollupsAC','auto_acct_coll',
				old_login, new_login;
END;
$function$
;

--
-- Process drops in company_manip
--
--
-- Process drops in token_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('token_utils', 'set_lock_status');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS token_utils.set_lock_status ( p_token_id integer, p_lock_status character, p_unlock_time timestamp with time zone, p_bad_logins integer, p_last_updated timestamp with time zone );
CREATE OR REPLACE FUNCTION token_utils.set_lock_status(p_token_id integer, p_lock_status character, p_unlock_time timestamp with time zone, p_bad_logins integer, p_last_updated timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_cur		token%ROWTYPE;
BEGIN

	IF p_token_id IS NULL THEN
		RAISE EXCEPTION 'Invalid token %', p_token_id
			USING ERRCODE = invalid_parameter_value;
	END IF;

	EXECUTE '
		SELECT *
		FROM token
		WHERE token_id = $1
	' INTO _cur USING p_token_id;

	--
	-- This used to be <= but if two clients were doing things in the
	-- same second, it became dueling syncs.  This may result in a change
	-- getting undone.  Solution may be to make last_updated more garanular
	-- as some libraries in here are no more granular than second (HOTPants
	-- or dbsyncer in jazzhands)
	IF _cur.last_updated < p_last_updated THEN
		UPDATE token SET
		is_token_locked = p_lock_status,
			token_unlock_time = p_unlock_time,
			bad_logins = p_bad_logins,
			last_updated = p_last_updated
		WHERE
			Token_ID = p_token_id;
	END IF;
END;
$function$
;

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
SELECT schema_support.save_grants_for_replay('device_utils', 'retire_devices');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.retire_devices ( device_id_list integer[] );
CREATE OR REPLACE FUNCTION device_utils.retire_devices(device_id_list integer[])
 RETURNS TABLE(device_id integer, success boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
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
			UNION
			SELECT
				rack_location_id
			FROM
				component
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
	RETURN;
END;
$function$
;

--
-- Process drops in netblock_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'calculate_intermediate_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.calculate_intermediate_netblocks ( ip_block_1 inet, ip_block_2 inet, netblock_type text, ip_universe_id integer );
CREATE OR REPLACE FUNCTION netblock_utils.calculate_intermediate_netblocks(ip_block_1 inet DEFAULT NULL::inet, ip_block_2 inet DEFAULT NULL::inet, netblock_type text DEFAULT 'default'::text, ip_universe_id integer DEFAULT 0)
 RETURNS TABLE(ip_addr inet)
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	current_nb		inet;
	new_nb			inet;
	min_addr		inet;
	max_addr		inet;
BEGIN
	IF ip_block_1 IS NULL OR ip_block_2 IS NULL THEN
		RAISE EXCEPTION 'Must specify both ip_block_1 and ip_block_2';
	END IF;

	IF family(ip_block_1) != family(ip_block_2) THEN
		RAISE EXCEPTION 'families of ip_block_1 and ip_block_2 must match';
	END IF;

	-- Make sure these are network blocks
	ip_block_1 := network(ip_block_1);
	ip_block_2 := network(ip_block_2);

	-- If the blocks are subsets of each other, then error

	IF ip_block_1 <<= ip_block_2 OR ip_block_2 <<= ip_block_1 THEN
		RAISE EXCEPTION 'netblocks intersect each other';
	END IF;

	-- Order the blocks correctly

	IF ip_block_1 > ip_block_2 THEN
		new_nb := ip_block_1;
		ip_block_1 := ip_block_2;
		ip_block_2 := new_nb;
	END IF;

	current_nb := ip_block_1;
	max_addr := broadcast(ip_block_1);

	-- Loop through bumping the netmask up and seeing if the destination block is in the new block
	LOOP
		new_nb := network(set_masklen(current_nb, masklen(current_nb) - 1));

		-- If the block is in our new larger netblock, then exit this loop
		IF (new_nb >>= ip_block_2) THEN
			current_nb := broadcast(current_nb) + 1;
			EXIT;
		END IF;
	
		-- If the max address of the new netblock is larger than the last one, then it's empty
		IF set_masklen(broadcast(new_nb), 32) > set_masklen(max_addr, 32) THEN
			ip_addr := set_masklen(max_addr + 1, masklen(current_nb));
			-- Validate that this isn't an empty can_subnet='Y' block already
			-- If it is, split it in half and return both halves
			PERFORM * FROM netblock n WHERE
				n.ip_address = ip_addr AND
				n.ip_universe_id =
					calculate_intermediate_netblocks.ip_universe_id AND
				n.netblock_type =
					calculate_intermediate_netblocks.netblock_type;
			IF FOUND AND masklen(ip_addr) < 32 THEN
				ip_addr := set_masklen(ip_addr, masklen(ip_addr) + 1);
				RETURN NEXT;
				ip_addr := broadcast(ip_addr) + 1;
				RETURN NEXT;
			ELSE
				RETURN NEXT;
			END IF;
			max_addr := broadcast(new_nb);
		END IF;
		current_nb := new_nb;
	END LOOP;

	-- Now loop through there to find the unused blocks at the front

	LOOP
		IF host(current_nb) = host(ip_block_2) THEN
			RETURN;
		END IF;
		current_nb := set_masklen(current_nb, masklen(current_nb) + 1);
		IF NOT (current_nb >>= ip_block_2) THEN
			ip_addr := current_nb;
			-- Validate that this isn't an empty can_subnet='Y' block already
			-- If it is, split it in half and return both halves
			PERFORM * FROM netblock n WHERE
				n.ip_address = ip_addr AND
				n.ip_universe_id =
					calculate_intermediate_netblocks.ip_universe_id AND
				n.netblock_type =
					calculate_intermediate_netblocks.netblock_type;
			IF FOUND AND masklen(ip_addr) < 32 THEN
				ip_addr := set_masklen(ip_addr, masklen(ip_addr) + 1);
				RETURN NEXT;
				ip_addr := broadcast(ip_addr) + 1;
				RETURN NEXT;
			ELSE
				RETURN NEXT;
			END IF;
			current_nb := broadcast(current_nb) + 1;
			CONTINUE;
		END IF;
	END LOOP;
	RETURN;
END;
$function$
;

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
-- Process drops in rack_utils
--
--
-- Process drops in schema_support
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

	FOREACH i IN ARRAY idx
	LOOP
		EXECUTE 'ALTER INDEX '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(i)
			|| ' RENAME TO '
			|| quote_ident('_' || i);
	END LOOP;

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
	-- get columns
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

-- New function
CREATE OR REPLACE FUNCTION schema_support.build_audit_table_other_indexes(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
	AND 	con.contype IS NULL

	LOOP
		_r.def := regexp_replace(_r.def, ' ON ', ' ON ' || sch || '.');
		EXECUTE _r.def;
	END LOOP;

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

-- New function
CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer3_network(layer3_network_id integer, purge_network_interfaces boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
	PERFORM * FROM layerx_network_manip.delete_layer3_networks(
		layer3_network_id_list := ARRAY[ layer3_network_id ],
		purge_network_interfaces := purge_network_interfaces
	);
END $function$
;

-- New function
CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer3_networks(layer3_network_id_list integer[], purge_network_interfaces boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	netblock_id_list			integer[];
	network_interface_id_list	integer[];
BEGIN
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

-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- index
DROP INDEX IF EXISTS "jazzhands"."idx_dev_is_virtual_dev";
CREATE INDEX idx_dev_is_virtual_dev ON device USING btree (is_virtual_device);
DROP INDEX IF EXISTS "jazzhands"."idx_dev_name";
CREATE INDEX idx_dev_name ON device USING btree (device_name);
DROP INDEX IF EXISTS "jazzhands"."idx_dev_parent_device_id";
CREATE INDEX idx_dev_parent_device_id ON device USING btree (parent_device_id);
DROP INDEX IF EXISTS "jazzhands"."idx_dev_phys_label";
CREATE INDEX idx_dev_phys_label ON device USING btree (physical_label);
-- triggers
DROP TRIGGER IF EXISTS trigger_account_status_after_hooks ON account;
DROP TRIGGER IF EXISTS trigger_account_status_per_row_after_hooks ON account;
CREATE TRIGGER trigger_account_status_per_row_after_hooks AFTER UPDATE OF account_status ON account FOR EACH ROW EXECUTE PROCEDURE account_status_per_row_after_hooks();
DROP TRIGGER IF EXISTS trigger_z_automated_ac_on_person_company ON person_company;
CREATE TRIGGER trigger_z_automated_ac_on_person_company AFTER UPDATE OF manager_person_id, person_company_status, person_company_relation ON person_company FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_person_company();


-- BEGIN Misc that does not apply to above

select schema_support.rebuild_audit_tables( 'audit'::text, 'jazzhands'::text);



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