--
-- Copyright (c) 2018 Todd Kover
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

	--suffix=v82
	--pre
	pre
	--post
	post
	--scan-tables
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();


-- BEGIN Misc that does not apply to above
alter table netblock_collection_netblock disable trigger
		trig_userlog_netblock_collection_netblock;
alter table netblock_collection_netblock disable trigger
		trigger_audit_netblock_collection_netblock;

WITH pt AS (
	INSERT INTO val_property_type (
		property_type, description
	) VALUES (
		'automated', 'properties that are automatically managed by jazzhands'
	) RETURNING *
), pv AS (
	INSERT INTO val_property (
		property_type, property_name, permit_netblock_collection_id,
		permit_site_code, property_data_type
	) SELECT property_type, 'per-site-netblock_collection', 'REQUIRED',
		'REQUIRED', 'none'
	FROM pt RETURNING *
), nct AS (
	INSERT INTO val_netblock_collection_type (
		netblock_collection_type, description, can_have_hierarchy
	) VALUES (
		'per-site', 'automated collection named after sites', 'N'
	) RETURNING *
), nc AS (
	INSERT INTO netblock_collection (
		netblock_collection_name, netblock_collection_type
	) SELECT site_code, netblock_collection_type
	FROM site, nct
	ORDER by site_code
	RETURNING *
), p AS ( 
	INSERT INTO property (
		property_name, property_type, site_code, 
		netblock_collection_id
	) SELECT
		property_name, property_type, netblock_collection_name, 
		netblock_collection_id
	FROM nc, pv
	RETURNING *
), ncn AS (
	INSERT INTO netblock_collection_netblock (
		netblock_collection_id, netblock_id,
		data_ins_user, data_ins_date, data_upd_user, data_upd_date
	) SELECT netblock_collection_id, netblock_id,
		sn.data_ins_user, sn.data_ins_date, sn.data_upd_user, sn.data_upd_date
	FROM nc join site_netblock sn ON nc.netblock_collection_name = sn.site_code
	RETURNING *
) SELECT count(*) from ncn;

alter table netblock_collection_netblock enable trigger
		trig_userlog_netblock_collection_netblock;
alter table netblock_collection_netblock enable trigger
		trigger_audit_netblock_collection_netblock;

INSERT INTO audit.netblock_collection_netblock (
	netblock_collection_id, netblock_id, 
	data_ins_user, data_ins_date, data_upd_user, data_upd_date,
	"aud#action", "aud#timestamp", "aud#realtime", "aud#txid", "aud#user",
	"aud#seq"
) SELECT
	netblock_collection_id, netblock_id, 
	sn.data_ins_user, sn.data_ins_date, sn.data_upd_user, sn.data_upd_date,
	"aud#action", "aud#timestamp", "aud#realtime", "aud#txid", "aud#user",
	"aud#seq"
FROM audit.site_netblock sn
	JOIN property p USING (site_code)
	WHERE property_name = 'per-site'
	AND property_type = 'automated'
;

alter table audit.netblock_collection_netblock
	drop constraint netblock_collection_netblock_pkey;

--
-- redo the sequences.  This is pretty awesome.
--
WITH x AS (
	SELECT "aud#seq", row_number() OVER
		(ORDER BY
			coalesce("aud#realtime", "aud#timestamp"), "aud#seq") as rnk
	FROM audit.netblock_collection_netblock
) UPDATE audit.netblock_collection_netblock a
SET "aud#seq" = x.rnk
FROM x 
where x."aud#seq" = a."aud#seq";


alter table audit.netblock_collection_netblock
	add constraint
	netblock_collection_netblock_pkey
	primary key ("aud#seq");



-- END Misc that does not apply to above
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'component_connection_utils';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS component_connection_utils;
		CREATE SCHEMA component_connection_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA component_connection_utils IS 'part of jazzhands';
	END IF;
END;
			$$;DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'property_utils';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS property_utils;
		CREATE SCHEMA property_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA property_utils IS 'part of jazzhands';
	END IF;
END;
			$$;--
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
				INNER JOIN v_property p
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
			INNER JOIN v_property p
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
				INNER JOIN v_property p USING (account_collection_id)
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
		FROM    (SELECT p.property_id, 
					p.account_collection_id,
					cc.company_id, 
					p.account_realm_id, p.property_name, p.property_type,
					p.property_value
					FROM v_property p
						LEFT JOIN (
								SELECT company_collection_id, company_id
								FROM	company_collection
										JOIN company_collection_company
										USING (company_collection_id)
						) cc USING (company_collection_id)
				) p
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
				INNER JOIN v_property p USING (account_collection_id)
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
		FROM    v_property p
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
			INNER JOIN v_property p
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

-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'retire_racks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.retire_racks ( rack_id_list integer[] );
CREATE OR REPLACE FUNCTION device_utils.retire_racks(rack_id_list integer[])
 RETURNS TABLE(rack_id integer, success boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	rid					ALIAS FOR rack_id;
	device_id_list		integer[];
	component_id_list	integer[];
	enc_domain_list		text[];
	empty_enc_domain_list		text[];
BEGIN
	BEGIN
		PERFORM local_hooks.rack_retire_early(rack_id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	--
	-- Get the list of devices which either are directly attached to
	-- a rack_location in this rack, or which are attached to a component
	-- which is attached to this rack.  Do this once, since it's an
	-- expensive query
	--
	device_id_list := ARRAY(
		SELECT
			device_id
		FROM
			device d JOIN
			rack_location rl USING (rack_location_id)
		WHERE
			rl.rack_id = ANY(rack_id_list)
		UNION
		SELECT
			device_id
		FROM
			rack_location rl JOIN
			component pc USING (rack_location_id) JOIN
			v_component_hier ch USING (component_id) JOIN
			device d ON (d.component_id = ch.child_component_id)
		WHERE
			rl.rack_id = ANY(rack_id_list)
	);

	--
	-- For components, just get a list of those directly attached to the rack
	-- and remove them.  We probably don't need to save this list, but just
	-- in case, we do
	--
	WITH x AS (
		UPDATE
			component AS c
		SET
			rack_location_id = NULL
		FROM
			rack_location rl
		WHERE
			rl.rack_location_id = c.rack_location_id AND
			rl.rack_id = ANY(rack_id_list)
		RETURNING
			c.component_id AS component_id
	) SELECT ARRAY(SELECT component_id FROM x) INTO component_id_list;

	--
	-- Get a list of all of the encapsulation_domains that are
	-- used by devices in these racks and stash them for later
	--
	enc_domain_list := ARRAY(
		SELECT DISTINCT
			encapsulation_domain
		FROM
			device_encapsulation_domain
		WHERE
			device_id = ANY(device_id_list)
	);

	PERFORM device_utils.retire_devices(device_id_list := device_id_list);

	--
	-- Check the encapsulation domains and for any that have no devices
	-- in them any more, clean up the layer2_networks for them
	--

	empty_enc_domain_list := ARRAY(
		SELECT
			encapsulation_domain
		FROM
			unnest(enc_domain_list) AS x(encapsulation_domain)
		WHERE
			encapsulation_domain NOT IN (
				SELECT encapsulation_domain FROM device_encapsulation_domain
			)
	);

	IF FOUND THEN
		PERFORM layerx_network_manip.delete_layer2_networks(
			layer2_network_id_list := ARRAY(
				SELECT
					layer2_network_id
				FROM
					layer2_network
				WHERE
					encapsulation_domain = ANY(empty_enc_domain_list)
			)
		);
		DELETE FROM encapsulation_domain WHERE
			encapsulation_domain = ANY(empty_enc_domain_list);
	END IF;

	BEGIN
		PERFORM local_hooks.racK_retire_late(rack_id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	FOREACH rid IN ARRAY rack_id_list LOOP
		BEGIN
			DELETE FROM rack_location rl WHERE rl.rack_id = rid;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
		BEGIN
			DELETE FROM rack r WHERE r.rack_id = rid;
			success := true;
			RETURN NEXT;
		EXCEPTION WHEN foreign_key_violation THEN
			UPDATE rack r SET
				room = NULL,
				sub_room = NULL,
				rack_row = NULL,
				rack_name = 'none',
				description = 'retired'
			WHERE	r.rack_id = rid;
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
	family_bits		integer;
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

	IF ip_block_1 <<= ip_block_2 AND ip_block_2 <<= ip_block_1 THEN
		RAISE EXCEPTION 'netblocks % and % intersect each other',
			ip_block_1,
			ip_block_2;
	END IF;

	-- Order the blocks correctly

	IF ip_block_1 > ip_block_2 THEN
		new_nb := ip_block_1;
		ip_block_1 := ip_block_2;
		ip_block_2 := new_nb;
	END IF;

	current_nb := ip_block_1;
	max_addr := broadcast(ip_block_1);

	family_bits := CASE WHEN family(ip_block_1) = 4 THEN 32 ELSE 128 END;

	-- Loop through bumping the netmask up and seeing if the destination block is in the new block
	LOOP
		new_nb := network(set_masklen(current_nb, masklen(current_nb) - 1));

		-- If the block is in our new larger netblock, then exit this loop
		IF (new_nb >>= ip_block_2) THEN
			current_nb := broadcast(current_nb) + 1;
			EXIT;
		END IF;
	
		-- If the max address of the new netblock is larger than the last one, then it's empty
		IF set_masklen(broadcast(new_nb), family_bits) > 
			set_masklen(max_addr, family_bits)
		THEN
			ip_addr := set_masklen(max_addr + 1, masklen(current_nb));
			-- Validate that this isn't an empty can_subnet='Y' block already
			-- If it is, split it in half and return both halves
			PERFORM * FROM netblock n WHERE
				n.ip_address = ip_addr AND
				n.ip_universe_id =
					calculate_intermediate_netblocks.ip_universe_id AND
				n.netblock_type =
					calculate_intermediate_netblocks.netblock_type;
			IF FOUND AND masklen(ip_addr) < family_bits THEN
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
		IF host(current_nb) = host(ip_block_2) OR
			masklen(current_nb) >= family_bits
		THEN
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
			IF FOUND AND masklen(ip_addr) < family_bits THEN
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

-- New function
CREATE OR REPLACE FUNCTION netblock_utils.find_best_ip_universe(ip_address inet, ip_namespace character varying DEFAULT 'default'::character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	u_id	ip_universe.ip_universe_id%TYPE;
	ip	inet;
	nsp	text;
BEGIN
	ip := ip_address;
	nsp := ip_namespace;

	SELECT	nb.ip_universe_id
	INTO	u_id
	FROM	netblock nb
		JOIN ip_universe u USING (ip_universe_id)
	WHERE	is_single_address = 'N'
	AND	nb.ip_address >>= ip
	AND	u.ip_namespace = 'default'
	ORDER BY masklen(nb.ip_address) desc
	LIMIT 1;

	IF u_id IS NOT NULL THEN
		RETURN u_id;
	END IF;
	RETURN 0;

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
-- Changed function
SELECT schema_support.save_grants_for_replay('approval_utils', 'approve');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS approval_utils.approve ( approval_instance_item_id integer, approved character, approving_account_id integer, new_value text );
CREATE OR REPLACE FUNCTION approval_utils.approve(approval_instance_item_id integer, approved character, approving_account_id integer, new_value text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO approval_utils, jazzhands
AS $function$
DECLARE
	_r		RECORD;
	_aii	approval_instance_item%ROWTYPE;	
	_new	approval_instance_item.approval_instance_item_id%TYPE;	
	_chid	approval_process_chain.approval_process_chain_id%TYPE;
	_tally	INTEGER;
BEGIN
	EXECUTE '
		SELECT 	aii.approval_instance_item_id,
			ais.approval_instance_step_id,
			ais.approval_instance_id,
			ais.approver_account_id,
			ais.approval_type,
			aii.is_approved,
			ais.is_completed,
			aic.accept_app_process_chain_id,
			aic.reject_app_process_chain_id
   	     FROM    approval_instance ai
   		     INNER JOIN approval_instance_step ais
   			 USING (approval_instance_id)
   		     INNER JOIN approval_instance_item aii
   			 USING (approval_instance_step_id)
   		     INNER JOIN approval_instance_link ail
   			 USING (approval_instance_link_id)
			INNER JOIN approval_process_chain aic
				USING (approval_process_chain_id)
		WHERE approval_instance_item_id = $1
	' USING approval_instance_item_id INTO 	_r;

	--
	-- Ensure that only the person or their management chain can approve
	-- others; this may want to be a property on val_approval_type rather
	-- than hard coded on account...
	IF (_r.approval_type = 'account' AND _r.approver_account_id != approving_account_id ) THEN
		EXECUTE '
			SELECT count(*)
			FROM	v_account_manager_hier
			WHERE account_id = $1
			AND manager_account_id = $2
		' INTO _tally USING _r.approver_account_id, approving_account_id;

		IF _tally = 0 THEN
			EXECUTE '
				SELECT	count(*)
				FROM	property
						INNER JOIN v_acct_coll_acct_expanded e
						USING (account_collection_id)
				WHERE	property_type = ''Defaults''
				AND		property_name = ''_can_approve_all''
				AND		e.account_id = $1
			' INTO _tally USING approving_account_id;

			IF _tally = 0 THEN
				RAISE EXCEPTION 'Only a person and their management chain may approve others';
			END IF;
		END IF;

	END IF;

	IF _r.approval_instance_item_id IS NULL THEN
		RAISE EXCEPTION 'Unknown approval_instance_item_id %',
			approval_instance_item_id;
	END IF;

	IF _r.is_approved IS NOT NULL THEN
		RAISE EXCEPTION 'Approval is already completed.';
	END IF;

	IF approved = 'N' THEN
		IF _r.reject_app_process_chain_id IS NOT NULL THEN
			_chid := _r.reject_app_process_chain_id;	
		END IF;
	ELSIF approved = 'Y' THEN
		IF _r.accept_app_process_chain_id IS NOT NULL THEN
			_chid := _r.accept_app_process_chain_id;
		END IF;
	ELSE
		RAISE EXCEPTION 'Approved must be Y or N';
	END IF;

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

	--
	-- This needs to happen after the next steps are created
	-- or the entire process gets marked as done on the second to last
	-- update instead of the list.

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
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_trigger');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_trigger ( aud_schema character varying, tbl_schema character varying, table_name character varying );
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

--
-- Process middle (non-trigger) schema layerx_network_manip
--
--
-- Process middle (non-trigger) schema property_utils
--
-- New function
CREATE OR REPLACE FUNCTION property_utils.validate_property(new property)
 RETURNS property
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

--
-- Process middle (non-trigger) schema component_connection_utils
--
-- New function
CREATE OR REPLACE FUNCTION component_connection_utils.create_inter_component_connection(INOUT device_id integer, INOUT slot_name character varying, INOUT remote_slot_name character varying, INOUT remote_device_id integer DEFAULT NULL::integer, remote_host_id character varying DEFAULT NULL::character varying, remote_device_name character varying DEFAULT NULL::character varying, force boolean DEFAULT false, OUT inter_component_connection_id integer, OUT slot_id integer, OUT slot_index integer, OUT mac_address macaddr, OUT slot_type_id integer, OUT slot_type text, OUT slot_function text, OUT remote_slot_id integer, OUT remote_slot_index integer, OUT remote_mac_address macaddr, OUT remote_slot_type_id integer, OUT remote_slot_type text, OUT remote_slot_function text, OUT changed boolean)
 RETURNS SETOF record
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	remote_dev_rec		RECORD;
	slot_rec			RECORD;
	remote_slot_rec		RECORD;
	_device_id			ALIAS FOR device_id;
	_slot_name			ALIAS FOR slot_name;
	_remote_slot_name	ALIAS FOR remote_slot_name;
	_remote_device_id	ALIAS FOR remote_device_id;
	_remote_host_id		ALIAS FOR remote_host_id;
	_remote_device_name	ALIAS FOR remote_device_name;
BEGIN
	--
	-- Validate what's passed
	--
	IF remote_device_id IS NULL AND remote_host_id IS NULL AND
		remote_device_name IS NULL
	THEN
		RAISE 'Must pass remote_device_id, remote_host_id, or remote_device_name to create_inter_component_connection()' 
			USING ERRCODE = 'null_value_not_allowed';
	END IF;

	--
	-- For selecting a device, prefer passed device_id
	--
	IF remote_device_id IS NOT NULL THEN
		SELECT
			d.device_id,
			d.device_name,
			d.host_id
		INTO remote_dev_rec
		FROM
			device d
		WHERE
			d.device_id = remote_device_id;

		IF NOT FOUND THEN
			RETURN;
		END IF;
	ELSIF remote_device_name IS NOT NULL THEN
		BEGIN
			SELECT
				d.device_id,
				d.device_name,
				d.host_id
			INTO STRICT remote_dev_rec
			FROM
				device d
			WHERE
				device_name = remote_device_name AND
				device_status != 'removed';
		EXCEPTION
			WHEN NO_DATA_FOUND THEN RETURN;
			WHEN TOO_MANY_ROWS THEN
				RAISE EXCEPTION 'Multiple devices have device_name %',
					remote_device_name;
		END;
	ELSIF remote_host_id IS NOT NULL THEN
		BEGIN
			SELECT
				d.device_id,
				d.device_name,
				d.host_id
			INTO STRICT remote_dev_rec
			FROM
				device d
			WHERE
				host_id = remote_host_id AND
				device_status != 'removed';
		EXCEPTION
			WHEN NO_DATA_FOUND THEN RETURN;
			WHEN TOO_MANY_ROWS THEN
				RAISE EXCEPTION 'Multiple devices have host_id %',
					remote_host_id;
		END;
	END IF;

	RAISE DEBUG 'Remote device is %', row_to_json(remote_dev_rec, true);
	--
	-- Now look to make sure both slots exist and whether there is a current
	-- connection for the remote side
	--

	SELECT
		*
	INTO
		slot_rec
	FROM
		jazzhands.v_device_slot_connections dsc
	WHERE
		dsc.device_id = _device_id AND
		dsc.slot_name = _slot_name AND
		dsc.slot_function = 'network';

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Network slot % does not exist on device %',
			_slot_name,
			_device_id;
	END IF;

	RAISE DEBUG 'Local slot is %', row_to_json(slot_rec, true);
	
	SELECT
		*
	INTO
		remote_slot_rec
	FROM
		jazzhands.v_device_slot_connections dsc
	WHERE
		dsc.device_id = remote_dev_rec.device_id AND
		dsc.slot_name = _remote_slot_name AND
		dsc.slot_function = 'network';

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Network slot % does not exist on device %',
			_slot_name,
			_device_id;
	END IF;

	RAISE DEBUG 'Remote slot is %', row_to_json(remote_slot_rec, true);
	
	--
	-- See if these are already connected
	--
	IF slot_rec.inter_component_connection_id = 
		remote_slot_rec.inter_component_connection_id
	THEN
		inter_component_connection_id := slot_rec.inter_component_connection_id;
		slot_id := slot_rec.slot_id;
		slot_name := slot_rec.slot_name;
		slot_index := slot_rec.slot_index;
		mac_address := slot_rec.mac_address;
		slot_type_id := slot_rec.slot_type_id;
		slot_type := slot_rec.slot_type;
		slot_function := slot_rec.slot_function;
		remote_device_id := slot_rec.remote_device_id;
		remote_slot_id := slot_rec.remote_slot_id;
		remote_slot_name := slot_rec.remote_slot_name;
		remote_slot_index := slot_rec.remote_slot_index;
		remote_mac_address := slot_rec.remote_mac_address;
		remote_slot_type_id := slot_rec.remote_slot_type_id;
		remote_slot_type := slot_rec.remote_slot_type;
		remote_slot_function := slot_rec.remote_slot_function;
		changed := false;
		RETURN NEXT;
		RETURN;
	END IF;

	--
	-- See if we can create a new connection
	--
	IF remote_slot_rec.inter_component_connection_id IS NOT NULL THEN
		IF
			force OR
			remote_host_id = remote_dev_rec.host_id
		THEN
			DELETE FROM
				inter_component_connection icc
			WHERE
				icc.inter_component_connection_id = 
					remote_slot_rec.inter_component_connection_id;
		ELSE
			RAISE EXCEPTION 'Slot % for device % is already connected to slot % on device %',
				remote_slot_rec.slot_name,
				remote_slot_rec.device_id,
				remote_slot_rec.remote_slot_name,
				remote_slot_rec.remote_device_id;
			RETURN;
		END IF;
	END IF;

	IF slot_rec.inter_component_connection_id IS NOT NULL THEN
		DELETE FROM
			inter_component_connection icc
		WHERE
			icc.inter_component_connection_id = 
				slot_rec.inter_component_connection_id;
	END IF;

	INSERT INTO inter_component_connection (
		slot1_id,
		slot2_id
	) VALUES (
		slot_rec.slot_id,
		remote_slot_rec.slot_id
	);

	SELECT
		* INTO slot_rec
	FROM
		jazzhands.v_device_slot_connections dsc
	WHERE
		dsc.slot_id = slot_rec.slot_id;
		
	inter_component_connection_id := slot_rec.inter_component_connection_id;
	slot_id := slot_rec.slot_id;
	slot_name := slot_rec.slot_name;
	slot_index := slot_rec.slot_index;
	mac_address := slot_rec.mac_address;
	slot_type_id := slot_rec.slot_type_id;
	slot_type := slot_rec.slot_type;
	slot_function := slot_rec.slot_function;
	remote_device_id := slot_rec.remote_device_id;
	remote_slot_id := slot_rec.remote_slot_id;
	remote_slot_name := slot_rec.remote_slot_name;
	remote_slot_index := slot_rec.remote_slot_index;
	remote_mac_address := slot_rec.remote_mac_address;
	remote_slot_type_id := slot_rec.remote_slot_type_id;
	remote_slot_type := slot_rec.remote_slot_type;
	remote_slot_function := slot_rec.remote_slot_function;
	changed := true;
	RETURN NEXT;
	RETURN;
END;
$function$
;

-- Creating new sequences....


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
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS fk_dns_rec_ip_universe;
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
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS ak_dns_record_dnsrec_domainid;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS pk_dns_record;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_dns_record_lower_dns_name";
DROP INDEX IF EXISTS "jazzhands"."idx_dnsrec_dnsclass";
DROP INDEX IF EXISTS "jazzhands"."idx_dnsrec_dnssrvservice";
DROP INDEX IF EXISTS "jazzhands"."idx_dnsrec_dnstype";
DROP INDEX IF EXISTS "jazzhands"."ix_dnsid_domid";
DROP INDEX IF EXISTS "jazzhands"."ix_dnsid_netblock_id";
DROP INDEX IF EXISTS "jazzhands"."xif8dns_record";
DROP INDEX IF EXISTS "jazzhands"."xif9dns_record";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS ckc_dns_srv_protocol_dns_reco;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS ckc_is_enabled_dns_reco;
ALTER TABLE jazzhands.dns_record DROP CONSTRAINT IF EXISTS ckc_should_generate_p_dns_reco;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_dns_record ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_audit_dns_record ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_check_ip_universe_dns_record ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_a_rec_validation ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_non_a_rec_validation ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_rec_prevent_dups ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_record_check_name ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_record_cname_checker ON jazzhands.dns_record;
DROP TRIGGER IF EXISTS trigger_dns_record_enabled_check ON jazzhands.dns_record;
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
DROP INDEX IF EXISTS "audit"."aud_dns_record_ak_dns_record_dnsrec_domainid";
DROP INDEX IF EXISTS "audit"."aud_dns_record_pk_dns_record";
DROP INDEX IF EXISTS "audit"."dns_record_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."dns_record_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."dns_record_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.dns_record TEARDOWN


ALTER TABLE dns_record RENAME TO dns_record_v82;
ALTER TABLE audit.dns_record RENAME TO dns_record_v82;

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
	ip_universe_id,
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
	ip_universe_id,
	reference_dns_record_id,
	dns_value_record_id,
	should_generate_ptr,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM dns_record_v82;

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
	ip_universe_id,
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
	ip_universe_id,
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
FROM audit.dns_record_v82;

ALTER TABLE dns_record
	ALTER dns_record_id
	SET DEFAULT nextval('dns_record_dns_record_id_seq'::regclass);
ALTER TABLE dns_record
	ALTER dns_class
	SET DEFAULT 'IN'::character varying;
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
			db.dns_srv_weight, db.dns_srv_port, db.ip_universe_id,
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
		AND db.ip_universe_id IS NOT DISTINCT FROM NEW.ip_universe_id
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
		IF NEW.DNS_NAME ~ '[^-a-zA-Z0-9\._\*]+' THEN
			RAISE EXCEPTION 'Invalid DNS NAME %',
				NEW.DNS_NAME
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

		-- PTRs on wildcard records break thing and make no sense.
		IF NEW.DNS_NAME ~ '\*' AND NEW.SHOULD_GENERATE_PTR = 'Y' THEN
			RAISE EXCEPTION 'Wildcard DNS Record % can not have auto-set PTR',
				NEW.DNS_NAME
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_dns_record_check_name BEFORE INSERT OR UPDATE OF dns_name, should_generate_ptr ON dns_record FOR EACH ROW EXECUTE PROCEDURE dns_record_check_name();

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
	--- XXX - need to seriously think about ip_universes here.
	_tally := 0;
	IF TG_OP = 'INSERT' OR NEW.DNS_TYPE != OLD.DNS_TYPE THEN
		IF NEW.DNS_TYPE = 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
			SELECT	COUNT(*)
				  INTO	_tally
				  FROM	v_dns x
				 WHERE
						NEW.dns_domain_id = x.dns_domain_id
				 AND	NEW.ip_universe_id IS NOT DISTINCT FROM x.ip_universe_id
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
				  FROM	v_dns x
				 WHERE
						NEW.dns_domain_id = x.dns_domain_id
				 AND	NEW.ip_universe_id IS NOT DISTINCT FROM x.ip_universe_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		-- this clause is basically the same as above except = 'CNAME'
		ELSIF NEW.DNS_TYPE != 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	v_dns x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	NEW.ip_universe_id IS NOT DISTINCT FROM x.ip_universe_id
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
				  FROM	v_dns x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	NEW.ip_universe_id IS NOT DISTINCT FROM x.ip_universe_id
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

	--
	-- deal with records pointing to this one.  only values are done because
	-- references are forced by ak to be in the same zone.
	IF TG_OP = 'INSERT' THEN
		INSERT INTO dns_change_record (dns_domain_id)
			SELECT DISTINCT dns_domain_id
			FROM dns_record
			WHERE dns_value_record_id = NEW.dns_record_id
			AND dns_domain_id != NEW.dns_domain_id;
	ELSIF TG_OP = 'UPDATE' THEN
		INSERT INTO dns_change_record (dns_domain_id)
			SELECT DISTINCT dns_domain_id
			FROM dns_record
			WHERE dns_value_record_id = NEW.dns_record_id
			AND dns_domain_id NOT IN (OLD.dns_domain_id, NEW.dns_domain_id);
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
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'dns_record');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'dns_record');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'dns_record');
ALTER SEQUENCE dns_record_dns_record_id_seq
	 OWNED BY dns_record.dns_record_id;
DROP TABLE IF EXISTS dns_record_v82;
DROP TABLE IF EXISTS audit.dns_record_v82;
-- DONE DEALING WITH TABLE dns_record
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE netblock
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock', 'netblock');

-- FOREIGN KEYS FROM
ALTER TABLE dns_record DROP CONSTRAINT IF EXISTS fk_dnsid_nblk_id;
ALTER TABLE layer3_network DROP CONSTRAINT IF EXISTS fk_l3_net_def_gate_nbid;
ALTER TABLE layer3_network DROP CONSTRAINT IF EXISTS fk_l3net_rndv_pt_nblk_id;
ALTER TABLE layer3_network DROP CONSTRAINT IF EXISTS fk_layer3_network_netblock_id;
ALTER TABLE netblock_collection_netblock DROP CONSTRAINT IF EXISTS fk_nblk_col_nblk_nblkid;
ALTER TABLE network_range DROP CONSTRAINT IF EXISTS fk_net_range_start_netblock;
ALTER TABLE network_range DROP CONSTRAINT IF EXISTS fk_net_range_stop_netblock;
ALTER TABLE static_route_template DROP CONSTRAINT IF EXISTS fk_netblock_st_rt_dst_net;
ALTER TABLE static_route_template DROP CONSTRAINT IF EXISTS fk_netblock_st_rt_src_net;
ALTER TABLE network_interface_netblock DROP CONSTRAINT IF EXISTS fk_netint_nb_netint_id;
ALTER TABLE network_range DROP CONSTRAINT IF EXISTS fk_netrng_prngnblkid;
ALTER TABLE shared_netblock DROP CONSTRAINT IF EXISTS fk_shared_net_netblock_id;
ALTER TABLE site_netblock DROP CONSTRAINT IF EXISTS fk_site_netblock_ref_netblock;
ALTER TABLE static_route DROP CONSTRAINT IF EXISTS fk_statrt_nblk_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS fk_nblk_ip_universe_id;
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS fk_netblk_netblk_parid;
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS fk_netblock_nblk_typ;
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS fk_netblock_v_netblock_stat;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'netblock');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS ak_netblock_params;
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS pk_netblock;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_netblk_netblkstatus";
DROP INDEX IF EXISTS "jazzhands"."idx_netblock_host_ip_address";
DROP INDEX IF EXISTS "jazzhands"."ix_netblk_ip_address";
DROP INDEX IF EXISTS "jazzhands"."ix_netblk_ip_address_parent";
DROP INDEX IF EXISTS "jazzhands"."netblock_case_idx";
DROP INDEX IF EXISTS "jazzhands"."xif6netblock";
DROP INDEX IF EXISTS "jazzhands"."xif7netblock";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS check_yes_no_172122967;
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS ckc_is_single_address_netblock;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS aaa_ta_manipulate_netblock_parentage ON jazzhands.netblock;
DROP TRIGGER IF EXISTS tb_a_validate_netblock ON jazzhands.netblock;
DROP TRIGGER IF EXISTS tb_manipulate_netblock_parentage ON jazzhands.netblock;
DROP TRIGGER IF EXISTS trig_userlog_netblock ON jazzhands.netblock;
DROP TRIGGER IF EXISTS trigger_audit_netblock ON jazzhands.netblock;
DROP TRIGGER IF EXISTS trigger_check_ip_universe_netblock ON jazzhands.netblock;
DROP TRIGGER IF EXISTS trigger_nb_dns_a_rec_validation ON jazzhands.netblock;
DROP TRIGGER IF EXISTS trigger_netblock_single_address_ni ON jazzhands.netblock;
DROP TRIGGER IF EXISTS trigger_validate_netblock_parentage ON jazzhands.netblock;
DROP TRIGGER IF EXISTS trigger_validate_netblock_to_range_changes ON jazzhands.netblock;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'netblock');
---- BEGIN audit.netblock TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'netblock', 'netblock');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'netblock');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.netblock DROP CONSTRAINT IF EXISTS netblock_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_netblock_ak_netblock_params";
DROP INDEX IF EXISTS "audit"."aud_netblock_pk_netblock";
DROP INDEX IF EXISTS "audit"."netblock_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."netblock_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."netblock_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.netblock TEARDOWN


ALTER TABLE netblock RENAME TO netblock_v82;
ALTER TABLE audit.netblock RENAME TO netblock_v82;

CREATE TABLE netblock
(
	netblock_id	integer NOT NULL,
	ip_address	inet NOT NULL,
	netblock_type	varchar(50) NOT NULL,
	is_single_address	character(1) NOT NULL,
	can_subnet	character(1) NOT NULL,
	parent_netblock_id	integer  NULL,
	netblock_status	varchar(50) NOT NULL,
	ip_universe_id	integer NOT NULL,
	description	varchar(255)  NULL,
	external_id	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'netblock', false);
ALTER TABLE netblock
	ALTER netblock_id
	SET DEFAULT nextval('netblock_netblock_id_seq'::regclass);
ALTER TABLE netblock
	ALTER netblock_type
	SET DEFAULT 'default'::character varying;
INSERT INTO netblock (
	netblock_id,
	ip_address,
	netblock_type,
	is_single_address,
	can_subnet,
	parent_netblock_id,
	netblock_status,
	ip_universe_id,
	description,
	external_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	netblock_id,
	ip_address,
	netblock_type,
	is_single_address,
	can_subnet,
	parent_netblock_id,
	netblock_status,
	ip_universe_id,
	description,
	external_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM netblock_v82;

INSERT INTO audit.netblock (
	netblock_id,
	ip_address,
	netblock_type,
	is_single_address,
	can_subnet,
	parent_netblock_id,
	netblock_status,
	ip_universe_id,
	description,
	external_id,
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
	netblock_id,
	ip_address,
	netblock_type,
	is_single_address,
	can_subnet,
	parent_netblock_id,
	netblock_status,
	ip_universe_id,
	description,
	external_id,
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
FROM audit.netblock_v82;

ALTER TABLE netblock
	ALTER netblock_id
	SET DEFAULT nextval('netblock_netblock_id_seq'::regclass);
ALTER TABLE netblock
	ALTER netblock_type
	SET DEFAULT 'default'::character varying;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE netblock ADD CONSTRAINT ak_netblock_params UNIQUE (ip_address, netblock_type, ip_universe_id, is_single_address);
ALTER TABLE netblock ADD CONSTRAINT pk_netblock PRIMARY KEY (netblock_id);

-- Table/Column Comments
COMMENT ON COLUMN netblock.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX idx_netblk_netblkstatus ON netblock USING btree (netblock_status);
CREATE INDEX idx_netblock_host_ip_address ON netblock USING btree (host(ip_address));
CREATE INDEX ix_netblk_ip_address ON netblock USING btree (ip_address);
CREATE INDEX ix_netblk_ip_address_parent ON netblock USING btree (parent_netblock_id);
CREATE INDEX netblock_case_idx ON netblock USING btree ((
CASE
    WHEN family(ip_address) = 4 THEN ip_address - '0.0.0.0'::inet
    ELSE NULL::bigint
END));
CREATE INDEX xif6netblock ON netblock USING btree (ip_universe_id);
CREATE INDEX xif7netblock ON netblock USING btree (netblock_type);

-- CHECK CONSTRAINTS
ALTER TABLE netblock ADD CONSTRAINT check_yes_no_172122967
	CHECK (can_subnet = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE netblock ADD CONSTRAINT ckc_is_single_address_netblock
	CHECK ((is_single_address IS NULL) OR ((is_single_address = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_single_address)::text = upper((is_single_address)::text))));

-- FOREIGN KEYS FROM
-- consider FK between netblock and dns_record
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsid_nblk_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and layer3_network
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3_net_def_gate_nbid
	FOREIGN KEY (default_gateway_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and layer3_network
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3net_rndv_pt_nblk_id
	FOREIGN KEY (rendezvous_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and layer3_network
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_layer3_network_netblock_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and netblock_collection_netblock
ALTER TABLE netblock_collection_netblock
	ADD CONSTRAINT fk_nblk_col_nblk_nblkid
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and network_range
ALTER TABLE network_range
	ADD CONSTRAINT fk_net_range_start_netblock
	FOREIGN KEY (start_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and network_range
ALTER TABLE network_range
	ADD CONSTRAINT fk_net_range_stop_netblock
	FOREIGN KEY (stop_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and static_route_template
ALTER TABLE static_route_template
	ADD CONSTRAINT fk_netblock_st_rt_dst_net
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and static_route_template
ALTER TABLE static_route_template
	ADD CONSTRAINT fk_netblock_st_rt_src_net
	FOREIGN KEY (netblock_src_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and network_interface_netblock
ALTER TABLE network_interface_netblock
	ADD CONSTRAINT fk_netint_nb_netint_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id) DEFERRABLE;
-- consider FK between netblock and network_range
ALTER TABLE network_range
	ADD CONSTRAINT fk_netrng_prngnblkid
	FOREIGN KEY (parent_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and shared_netblock
ALTER TABLE shared_netblock
	ADD CONSTRAINT fk_shared_net_netblock_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and static_route
ALTER TABLE static_route
	ADD CONSTRAINT fk_statrt_nblk_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);

-- FOREIGN KEYS TO
-- consider FK netblock and ip_universe
ALTER TABLE netblock
	ADD CONSTRAINT fk_nblk_ip_universe_id
	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);
-- consider FK netblock and netblock
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblk_netblk_parid
	FOREIGN KEY (parent_netblock_id) REFERENCES netblock(netblock_id) DEFERRABLE INITIALLY DEFERRED;
-- consider FK netblock and val_netblock_type
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblock_nblk_typ
	FOREIGN KEY (netblock_type) REFERENCES val_netblock_type(netblock_type);
-- consider FK netblock and val_netblock_status
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblock_v_netblock_stat
	FOREIGN KEY (netblock_status) REFERENCES val_netblock_status(netblock_status);

-- TRIGGERS
-- consider NEW jazzhands.manipulate_netblock_parentage_after
CREATE OR REPLACE FUNCTION jazzhands.manipulate_netblock_parentage_after()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$

DECLARE
	nbtype				record;
	v_netblock_type		val_netblock_type.netblock_type%TYPE;
	v_row_count			integer;
	v_trigger			record;
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

	RAISE DEBUG 'Setting parent for all child netblocks of parent netblock % that belong to %',
		NEW.parent_netblock_id,
		NEW.netblock_id;

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
		RETURN NULL;
	END IF;
END;
$function$
;
CREATE CONSTRAINT TRIGGER aaa_ta_manipulate_netblock_parentage AFTER INSERT OR DELETE ON netblock NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE manipulate_netblock_parentage_after();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.validate_netblock
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

	/*
	 * These are trigger enforced later and are basically what anyone
	 * using this means.
	 */
	IF NEW.can_subnet = 'Y' and NEW.is_single_address iS NULL THEN
		NEW.is_single_address = 'N';
	ELSIF NEW.can_subnet IS NULL and NEW.is_single_address = 'Y' THEN
		NEW.can_subnet = 'N';
	END IF;

	/*
	 * If the universe is not set, we used to assume 0/default, but now
	 * its the same namespace.  In the interest of speed, we assume a
	 * default namespace of 0, which is kind of like before, and 
	 * assume that if there's no match, 0 should be returned, which
	 * is also like before, which basically is just all the defaults.
	 * The assumption is that if multiple namespaces are used, then
	 * the caller is smart about figuring this out
	 */
	IF NEW.ip_universe_id IS NULL THEN
		NEW.ip_universe_id := netblock_utils.find_best_ip_universe(
				ip_address := NEW.ip_address
			);
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
CREATE TRIGGER tb_a_validate_netblock BEFORE INSERT OR UPDATE OF netblock_id, ip_address, netblock_type, is_single_address, can_subnet, parent_netblock_id, ip_universe_id ON netblock FOR EACH ROW EXECUTE PROCEDURE validate_netblock();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.manipulate_netblock_parentage_before
CREATE OR REPLACE FUNCTION jazzhands.manipulate_netblock_parentage_before()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$

DECLARE
	nbtype				record;
	v_netblock_type		val_netblock_type.netblock_type%TYPE;
BEGIN
	/*
	 * Get the parameters for the given netblock type to see if we need
	 * to do anything
	 */

	RAISE DEBUG 'Performing % on netblock %', TG_OP, NEW.netblock_id;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
		RETURN NEW;
	END IF;

	/*
	 * Find the correct parent netblock
	 */

	RAISE DEBUG 'Setting forced hierarchical netblock %', NEW.netblock_id;
	NEW.parent_netblock_id := netblock_utils.find_best_parent_id(
		NEW.ip_address,
		NULL,
		NEW.netblock_type,
		NEW.ip_universe_id,
		NEW.is_single_address,
		NEW.netblock_id
		);

	RAISE DEBUG 'Setting parent for netblock % (%, type %, universe %, single-address %) to %',
		NEW.netblock_id, NEW.ip_address, NEW.netblock_type,
		NEW.ip_universe_id, NEW.is_single_address,
		NEW.parent_netblock_id;

	/*
	 * If we are an end-node, then we're done
	 */

	IF NEW.is_single_address = 'Y' THEN
		RETURN NEW;
	END IF;

	/*
	 * If we're updating and we're a container netblock, find
	 * all of the children of our new parent that should be ours and take
	 * them.  They will already be guaranteed to be of the correct
	 * netblock_type and ip_universe_id.  We can't do this for inserts
	 * because the row doesn't exist causing foreign key problems, so
	 * that needs to be done in an after trigger.
	 */
	IF TG_OP = 'UPDATE' THEN
		RAISE DEBUG 'Setting parent for all child netblocks of parent netblock % that belong to %',
			NEW.parent_netblock_id,
			NEW.netblock_id;
		UPDATE
			netblock
		SET
			parent_netblock_id = NEW.netblock_id
		WHERE
			parent_netblock_id = NEW.parent_netblock_id AND
			ip_address <<= NEW.ip_address AND
			netblock_id != NEW.netblock_id;

		RAISE DEBUG 'Setting parent for all child netblocks of netblock % that no longer belong to it to %',
			NEW.parent_netblock_id,
			NEW.netblock_id;
		RAISE DEBUG 'Setting parent % to %',
			OLD.netblock_id,
			OLD.parent_netblock_id;
		UPDATE
			netblock
		SET
			parent_netblock_id = OLD.parent_netblock_id
		WHERE
			parent_netblock_id = NEW.netblock_id AND
			(ip_universe_id != NEW.ip_universe_id OR
			 netblock_type != NEW.netblock_type OR
			 NOT(ip_address <<= NEW.ip_address));
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE TRIGGER tb_manipulate_netblock_parentage BEFORE INSERT OR UPDATE OF ip_address, netblock_type, ip_universe_id, netblock_id, can_subnet, is_single_address ON netblock FOR EACH ROW EXECUTE PROCEDURE manipulate_netblock_parentage_before();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.check_ip_universe_netblock
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
CREATE CONSTRAINT TRIGGER trigger_check_ip_universe_netblock AFTER UPDATE OF netblock_id, ip_universe_id ON netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE check_ip_universe_netblock();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.nb_dns_a_rec_validation
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
CREATE TRIGGER trigger_nb_dns_a_rec_validation BEFORE UPDATE OF ip_address, is_single_address ON netblock FOR EACH ROW EXECUTE PROCEDURE nb_dns_a_rec_validation();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.netblock_single_address_ni
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
CREATE TRIGGER trigger_netblock_single_address_ni BEFORE UPDATE OF is_single_address, netblock_type ON netblock FOR EACH ROW EXECUTE PROCEDURE netblock_single_address_ni();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.validate_netblock_parentage
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
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_parentage AFTER INSERT OR UPDATE OF netblock_id, ip_address, netblock_type, is_single_address, can_subnet, parent_netblock_id, ip_universe_id ON netblock DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE PROCEDURE validate_netblock_parentage();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.validate_netblock_to_range_changes
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
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_to_range_changes AFTER UPDATE OF ip_address, is_single_address, can_subnet, netblock_type ON netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE validate_netblock_to_range_changes();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'netblock');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'netblock');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'netblock');
ALTER SEQUENCE netblock_netblock_id_seq
	 OWNED BY netblock.netblock_id;
DROP TABLE IF EXISTS netblock_v82;
DROP TABLE IF EXISTS audit.netblock_v82;
-- DONE DEALING WITH TABLE netblock
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE site_netblock
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'site_netblock', 'site_netblock');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.site_netblock DROP CONSTRAINT IF EXISTS fk_site_netblock_ref_netblock;
ALTER TABLE jazzhands.site_netblock DROP CONSTRAINT IF EXISTS fk_site_netblock_ref_site;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'site_netblock');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.site_netblock DROP CONSTRAINT IF EXISTS pk_site_netblock;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_site_netblock ON jazzhands.site_netblock;
DROP TRIGGER IF EXISTS trigger_audit_site_netblock ON jazzhands.site_netblock;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'site_netblock');
---- BEGIN audit.site_netblock TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'site_netblock', 'site_netblock');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'site_netblock');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.site_netblock DROP CONSTRAINT IF EXISTS site_netblock_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_site_netblock_pk_site_netblock";
DROP INDEX IF EXISTS "audit"."site_netblock_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."site_netblock_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."site_netblock_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.site_netblock TEARDOWN


ALTER TABLE site_netblock RENAME TO site_netblock_v82;
ALTER TABLE audit.site_netblock RENAME TO site_netblock_v82;

DROP VIEW IF EXISTS jazzhands.site_netblock;
CREATE VIEW jazzhands.site_netblock AS
 SELECT p.site_code,
    ncn.netblock_id,
    ncn.data_ins_user,
    ncn.data_ins_date,
    ncn.data_upd_user,
    ncn.data_upd_date
   FROM property p
     JOIN netblock_collection nc USING (netblock_collection_id)
     JOIN netblock_collection_netblock ncn USING (netblock_collection_id)
  WHERE p.property_name::text = 'per-site'::text AND p.property_type::text = 'automated'::text;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE type = 'view' AND object = 'site_netblock';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of site_netblock failed but that is ok';
				NULL;
			END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();
DROP TABLE IF EXISTS site_netblock_v82;
DROP TABLE IF EXISTS audit.site_netblock_v82;
-- DONE DEALING WITH TABLE site_netblock
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE site_netblock
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'site_netblock');
DROP VIEW IF EXISTS jazzhands.site_netblock;
CREATE VIEW jazzhands.site_netblock AS
 SELECT p.site_code,
    ncn.netblock_id,
    ncn.data_ins_user,
    ncn.data_ins_date,
    ncn.data_upd_user,
    ncn.data_upd_date
   FROM property p
     JOIN netblock_collection nc USING (netblock_collection_id)
     JOIN netblock_collection_netblock ncn USING (netblock_collection_id)
  WHERE p.property_name::text = 'per-site'::text AND p.property_type::text = 'automated'::text;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE type = 'view' AND object = 'site_netblock';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of site_netblock failed but that is ok';
				NULL;
			END;
$$;

-- DONE DEALING WITH TABLE site_netblock
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_network_range_expanded
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_network_range_expanded');
DROP VIEW IF EXISTS jazzhands.v_network_range_expanded;
CREATE VIEW jazzhands.v_network_range_expanded AS
 SELECT nr.network_range_id,
    nr.network_range_type,
    nr.description,
    nr.parent_netblock_id,
    p.ip_address,
    p.netblock_type,
    p.ip_universe_id,
    nr.start_netblock_id,
    start.ip_address AS start_ip_address,
    start.netblock_type AS start_netblock_type,
    start.ip_universe_id AS start_ip_universe_id,
    nr.stop_netblock_id,
    stop.ip_address AS stop_ip_address,
    stop.netblock_type AS stop_netblock_type,
    stop.ip_universe_id AS stop_ip_universe_id,
    nr.dns_prefix,
    nr.dns_domain_id,
    dd.soa_name
   FROM network_range nr
     JOIN netblock p ON nr.parent_netblock_id = p.netblock_id
     JOIN netblock start ON nr.start_netblock_id = start.netblock_id
     JOIN netblock stop ON nr.stop_netblock_id = stop.netblock_id
     LEFT JOIN dns_domain dd USING (dns_domain_id);

DO $$

			BEGIN
				DELETE FROM __recreate WHERE type = 'view' AND object = 'v_network_range_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_network_range_expanded failed but that is ok';
				NULL;
			END;
$$;

-- DONE DEALING WITH TABLE v_network_range_expanded
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_slot_connections
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_device_slot_connections');
DROP VIEW IF EXISTS jazzhands.v_device_slot_connections;
CREATE VIEW jazzhands.v_device_slot_connections AS
 WITH ds AS (
         SELECT s.slot_id,
            ds.device_id,
            s.slot_name,
            s.slot_index,
            s.mac_address,
            st.slot_type_id,
            st.slot_type,
            st.slot_function
           FROM slot s
             JOIN slot_type st USING (slot_type_id)
             LEFT JOIN v_device_slots ds USING (slot_id)
          WHERE (st.slot_type_id IN ( SELECT slot_type_prmt_rem_slot_type.slot_type_id
                   FROM slot_type_prmt_rem_slot_type
                UNION
                 SELECT slot_type_prmt_rem_slot_type.remote_slot_type_id
                   FROM slot_type_prmt_rem_slot_type))
        )
 SELECT icc.inter_component_connection_id,
    s1.device_id,
    s1.slot_id,
    s1.slot_name,
    s1.slot_index,
    s1.mac_address,
    s1.slot_type_id,
    s1.slot_type,
    s1.slot_function,
    s2.device_id AS remote_device_id,
    s2.slot_id AS remote_slot_id,
    s2.slot_name AS remote_slot_name,
    s2.slot_index AS remote_slot_index,
    s2.mac_address AS remote_mac_address,
    s2.slot_type_id AS remote_slot_type_id,
    s2.slot_type AS remote_slot_type,
    s2.slot_function AS remote_slot_function
   FROM ds s1
     JOIN inter_component_connection icc ON s1.slot_id = icc.slot1_id
     JOIN ds s2 ON s2.slot_id = icc.slot2_id
UNION
 SELECT icc.inter_component_connection_id,
    s2.device_id,
    s2.slot_id,
    s2.slot_name,
    s2.slot_index,
    s2.mac_address,
    s2.slot_type_id,
    s2.slot_type,
    s2.slot_function,
    s1.device_id AS remote_device_id,
    s1.slot_id AS remote_slot_id,
    s1.slot_name AS remote_slot_name,
    s1.slot_index AS remote_slot_index,
    s1.mac_address AS remote_mac_address,
    s1.slot_type_id AS remote_slot_type_id,
    s1.slot_type AS remote_slot_type,
    s1.slot_function AS remote_slot_function
   FROM ds s1
     JOIN inter_component_connection icc ON s1.slot_id = icc.slot1_id
     JOIN ds s2 ON s2.slot_id = icc.slot2_id
UNION
 SELECT NULL::integer AS inter_component_connection_id,
    s1.device_id,
    s1.slot_id,
    s1.slot_name,
    s1.slot_index,
    s1.mac_address,
    s1.slot_type_id,
    s1.slot_type,
    s1.slot_function,
    NULL::integer AS remote_device_id,
    NULL::integer AS remote_slot_id,
    NULL::text AS remote_slot_name,
    NULL::integer AS remote_slot_index,
    NULL::macaddr AS remote_mac_address,
    NULL::integer AS remote_slot_type_id,
    NULL::text AS remote_slot_type,
    NULL::text AS remote_slot_function
   FROM ds s1
  WHERE NOT (s1.slot_id IN ( SELECT inter_component_connection.slot1_id
           FROM inter_component_connection
        UNION
         SELECT inter_component_connection.slot2_id
           FROM inter_component_connection));

DO $$

			BEGIN
				DELETE FROM __recreate WHERE type = 'view' AND object = 'v_device_slot_connections';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_slot_connections failed but that is ok';
				NULL;
			END;
$$;

-- DONE DEALING WITH TABLE v_device_slot_connections
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
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_ip_universe_trigger_change');
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

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record_check_name');
CREATE OR REPLACE FUNCTION jazzhands.dns_record_check_name()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.DNS_NAME IS NOT NULL THEN
		-- rfc rfc952
		IF NEW.DNS_NAME ~ '[^-a-zA-Z0-9\._\*]+' THEN
			RAISE EXCEPTION 'Invalid DNS NAME %',
				NEW.DNS_NAME
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

		-- PTRs on wildcard records break thing and make no sense.
		IF NEW.DNS_NAME ~ '\*' AND NEW.SHOULD_GENERATE_PTR = 'Y' THEN
			RAISE EXCEPTION 'Wildcard DNS Record % can not have auto-set PTR',
				NEW.DNS_NAME
				USING ERRCODE = 'integrity_constraint_violation';
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
	--- XXX - need to seriously think about ip_universes here.
	_tally := 0;
	IF TG_OP = 'INSERT' OR NEW.DNS_TYPE != OLD.DNS_TYPE THEN
		IF NEW.DNS_TYPE = 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
			SELECT	COUNT(*)
				  INTO	_tally
				  FROM	v_dns x
				 WHERE
						NEW.dns_domain_id = x.dns_domain_id
				 AND	NEW.ip_universe_id IS NOT DISTINCT FROM x.ip_universe_id
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
				  FROM	v_dns x
				 WHERE
						NEW.dns_domain_id = x.dns_domain_id
				 AND	NEW.ip_universe_id IS NOT DISTINCT FROM x.ip_universe_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		-- this clause is basically the same as above except = 'CNAME'
		ELSIF NEW.DNS_TYPE != 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	v_dns x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	NEW.ip_universe_id IS NOT DISTINCT FROM x.ip_universe_id
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
				  FROM	v_dns x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	NEW.ip_universe_id IS NOT DISTINCT FROM x.ip_universe_id
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
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_network_interface_trans_ins');
CREATE OR REPLACE FUNCTION jazzhands.v_network_interface_trans_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_ni	network_interface%ROWTYPE;
BEGIN
	INSERT INTO network_interface (
                device_id,
		network_interface_name, description,
		parent_network_interface_id,
                parent_relation_type, physical_port_id,
		slot_id, logical_port_id,
		network_interface_type, is_interface_up,
		mac_addr, should_monitor, provides_nat,
                should_manage, provides_dhcp
	) VALUES (
                NEW.device_id,
                NEW.network_interface_name, NEW.description,
                NEW.parent_network_interface_id,
                NEW.parent_relation_type, NEW.physical_port_id,
                NEW.slot_id, NEW.logical_port_id,
                NEW.network_interface_type, NEW.is_interface_up,
                NEW.mac_addr, NEW.should_monitor, NEW.provides_nat,
                NEW.should_manage, NEW.provides_dhcp
	) RETURNING * INTO _ni;

	IF NEW.netblock_id IS NOT NULL THEN
		INSERT INTO network_interface_netblock (
			network_interface_id, netblock_id
		) VALUES (
			_ni.network_interface_id, NEW.netblock_id
		);
	END IF;

	NEW.network_interface_id := _ni.network_interface_id;
	NEW.device_id := _ni.device_id;
	NEW.network_interface_name := _ni.network_interface_name;
	NEW.description := _ni.description;
	NEW.parent_network_interface_id := _ni.parent_network_interface_id;
	NEW.parent_relation_type := _ni.parent_relation_type;
	NEW.physical_port_id := _ni.physical_port_id;
	NEW.slot_id := _ni.slot_id;
	NEW.logical_port_id := _ni.logical_port_id;
	NEW.network_interface_type := _ni.network_interface_type;
	NEW.is_interface_up := _ni.is_interface_up;
	NEW.mac_addr := _ni.mac_addr;
	NEW.should_monitor := _ni.should_monitor;
	NEW.provides_nat := _ni.provides_nat;
	NEW.should_manage := _ni.should_manage;
	NEW.provides_dhcp :=_ni.provides_dhcp;
	NEW.data_ins_user :=_ni.data_ins_user;
	NEW.data_ins_date := _ni.data_ins_date;
	NEW.data_upd_user := _ni.data_upd_user;
	NEW.data_upd_date := _ni.data_upd_date;


	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_network_interface_trans_upd');
CREATE OR REPLACE FUNCTION jazzhands.v_network_interface_trans_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	upd_query		TEXT[];
	_ni				network_interface%ROWTYPE;
BEGIN
	IF OLD.network_interface_id IS DISTINCT FROM NEW.network_interface_id THEN
		RAISE EXCEPTION 'May not update network_interface_id'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF OLD.netblock_id IS DISTINCT FROM NEW.netblock_id THEN
		IF OLD.netblock_id IS NULL THEN
			INSERT INTO network_interface_netblock (
				network_interface_id, netblock_id
			) VALUES (
				NEW.network_interface_id, NEW.netblock_id
			);
		ELSIF NEW.netblock_id IS NULL THEN
			DELETE FROM network_interface_netblock
			WHERE network_interface_id = OLD.network_interface_id
			AND netblock_id = OLD.netblock_id;

			WITH x AS (
				SELECT *,
				rank() OVER (PARTITION BY
					network_interface_id ORDER BY
					network_interface_rank) AS rnk
				FROM network_interface_netblock
				WHERE network_interface_id = NEW.network_interface_id
			) SELECT netblock_id
			INTO NEW.netblock_id
				FROM x
				WHERE x.rnk = 1;
		ELSE
			UPDATE network_interface_netblock
			SET netblock_id = NEW.netblock_id
			WHERE netblock_id = OLD.netblock_id
			AND network_interface_id = NEW.network_interface_id;
		END IF;
	END IF;

	upd_query := NULL;
		IF NEW.device_id IS DISTINCT FROM OLD.device_id THEN
			upd_query := array_append(upd_query,
				'device_id = ' || quote_nullable(NEW.device_id));
		END IF;
		IF NEW.network_interface_name IS DISTINCT FROM OLD.network_interface_name THEN
			upd_query := array_append(upd_query,
				'network_interface_name = ' || quote_nullable(NEW.network_interface_name));
		END IF;
		IF NEW.description IS DISTINCT FROM OLD.description THEN
			upd_query := array_append(upd_query,
				'description = ' || quote_nullable(NEW.description));
		END IF;
		IF NEW.parent_network_interface_id IS DISTINCT FROM OLD.parent_network_interface_id THEN
			upd_query := array_append(upd_query,
				'parent_network_interface_id = ' || quote_nullable(NEW.parent_network_interface_id));
		END IF;
		IF NEW.parent_relation_type IS DISTINCT FROM OLD.parent_relation_type THEN
			upd_query := array_append(upd_query,
				'parent_relation_type = ' || quote_nullable(NEW.parent_relation_type));
		END IF;
		IF NEW.physical_port_id IS DISTINCT FROM OLD.physical_port_id THEN
			upd_query := array_append(upd_query,
				'physical_port_id = ' || quote_nullable(NEW.physical_port_id));
		END IF;
		IF NEW.slot_id IS DISTINCT FROM OLD.slot_id THEN
			upd_query := array_append(upd_query,
				'slot_id = ' || quote_nullable(NEW.slot_id));
		END IF;
		IF NEW.logical_port_id IS DISTINCT FROM OLD.logical_port_id THEN
			upd_query := array_append(upd_query,
				'logical_port_id = ' || quote_nullable(NEW.logical_port_id));
		END IF;
		IF NEW.network_interface_type IS DISTINCT FROM OLD.network_interface_type THEN
			upd_query := array_append(upd_query,
				'network_interface_type = ' || quote_nullable(NEW.network_interface_type));
		END IF;
		IF NEW.is_interface_up IS DISTINCT FROM OLD.is_interface_up THEN
			upd_query := array_append(upd_query,
				'is_interface_up = ' || quote_nullable(NEW.is_interface_Up));
		END IF;
		IF NEW.mac_addr IS DISTINCT FROM OLD.mac_addr THEN
			upd_query := array_append(upd_query,
				'mac_addr = ' || quote_nullable(NEW.mac_addr));
		END IF;
		IF NEW.should_monitor IS DISTINCT FROM OLD.should_monitor THEN
			upd_query := array_append(upd_query,
				'should_monitor = ' || quote_nullable(NEW.should_monitor));
		END IF;
		IF NEW.provides_nat IS DISTINCT FROM OLD.provides_nat THEN
			upd_query := array_append(upd_query,
				'provides_nat = ' || quote_nullable(NEW.provides_nat));
		END IF;
		IF NEW.should_manage IS DISTINCT FROM OLD.should_manage THEN
			upd_query := array_append(upd_query,
				'should_manage = ' || quote_nullable(NEW.should_manage));
		END IF;
		IF NEW.provides_dhcp IS DISTINCT FROM OLD.provides_dhcp THEN
			upd_query := array_append(upd_query,
				'provides_dhcp = ' || quote_nullable(NEW.provides_dhcp));
		END IF;

		IF upd_query IS NOT NULL THEN
			EXECUTE 'UPDATE network_interface SET ' ||
				array_to_string(upd_query, ', ') ||
				' WHERE network_interface_id = $1 RETURNING *'
			USING OLD.network_interface_id
			INTO _ni;

			NEW.device_id := _ni.device_id;
			NEW.network_interface_name := _ni.network_interface_name;
			NEW.description := _ni.description;
			NEW.parent_network_interface_id := _ni.parent_network_interface_id;
			NEW.parent_relation_type := _ni.parent_relation_type;
			NEW.physical_port_id := _ni.physical_port_id;
			NEW.slot_id := _ni.slot_id;
			NEW.logical_port_id := _ni.logical_port_id;
			NEW.network_interface_type := _ni.network_interface_type;
			NEW.is_interface_up := _ni.is_interface_up;
			NEW.mac_addr := _ni.mac_addr;
			NEW.should_monitor := _ni.should_monitor;
			NEW.provides_nat := _ni.provides_nat;
			NEW.should_manage := _ni.should_manage;
			NEW.provides_dhcp := _ni.provides_dhcp;
			NEW.data_ins_user := _ni.data_ins_user;
			NEW.data_ins_date := _ni.data_ins_date;
			NEW.data_upd_user := _ni.data_upd_user;
			NEW.data_upd_date := _ni.data_upd_date;
		END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_person_company_del');
CREATE OR REPLACE FUNCTION jazzhands.v_person_company_del()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	DELETE FROM person_company_attr
	WHERE person_id = OLD.person_id
	AND company_id = OLD.company_id
	AND person_company_attr_name IN (
		'employee_id', 'payroll_id', 'external_hr_id',
		'badge_system_id', 'supervisor_person_id'
	);

	DELETE FROM person_company
	WHERE person_id = OLD.person_id
	AND company_id = OLD.company_id;

	RETURN OLD;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_person_company_upd');
CREATE OR REPLACE FUNCTION jazzhands.v_person_company_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
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

	IF NEW.employee_id IS NOT NULL THEN
		UPDATE person_company_attr
		SET	attribute_value = NEW.employee_id
		WHERE person_company_attr_name = 'employee_id'
		AND person_id = NEW.person_id
		AND company_id = NEW.company_id;
	END IF;

	IF NEW.payroll_id IS NOT NULL THEN
		UPDATE person_company_attr
		SET	attribute_value = NEW.payroll_id
		WHERE person_company_attr_name = 'payroll_id'
		AND person_id = NEW.person_id
		AND company_id = NEW.company_id;
	END IF;

	IF NEW.external_hr_id IS NOT NULL THEN
		UPDATE person_company_attr
		SET	attribute_value = NEW.external_hr_id
		WHERE person_company_attr_name = 'external_hr_id'
		AND person_id = NEW.person_id
		AND company_id = NEW.company_id;
	END IF;

	IF NEW.badge_system_id IS NOT NULL THEN
		UPDATE person_company_attr
		SET	attribute_value = NEW.badge_system_id
		WHERE person_company_attr_name = 'badge_system_id'
		AND person_id = NEW.person_id
		AND company_id = NEW.company_id;
	END IF;

	IF NEW.supervisor_person_id IS NOT NULL THEN
		UPDATE person_company_attr
		SET	attribute_value_person_id = NEW.supervisor_person_id
		WHERE person_company_attr_name = 'supervisor_id'
		AND person_id = NEW.person_id
		AND company_id = NEW.company_id;
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

	/*
	 * These are trigger enforced later and are basically what anyone
	 * using this means.
	 */
	IF NEW.can_subnet = 'Y' and NEW.is_single_address iS NULL THEN
		NEW.is_single_address = 'N';
	ELSIF NEW.can_subnet IS NULL and NEW.is_single_address = 'Y' THEN
		NEW.can_subnet = 'N';
	END IF;

	/*
	 * If the universe is not set, we used to assume 0/default, but now
	 * its the same namespace.  In the interest of speed, we assume a
	 * default namespace of 0, which is kind of like before, and 
	 * assume that if there's no match, 0 should be returned, which
	 * is also like before, which basically is just all the defaults.
	 * The assumption is that if multiple namespaces are used, then
	 * the caller is smart about figuring this out
	 */
	IF NEW.ip_universe_id IS NULL THEN
		NEW.ip_universe_id := netblock_utils.find_best_ip_universe(
				ip_address := NEW.ip_address
			);
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
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_property');
CREATE OR REPLACE FUNCTION jazzhands.validate_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	RETURN property_utils.validate_property(NEW);
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.del_site_netblock_collections()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_hate	INTEGER;
BEGIN
	WITH p AS (
		DELETE FROM property
		WHERE property_type = 'automated'
		AND property_name = 'per-site-netblock_collection'
		AND site_code = OLD.site_code
		RETURNING *
	),  nc AS (
		DELETE FROM netblock_collection
		WHERE netblock_collection_id IN (
			SELECT netblock_collection_id from p
		)
		RETURNING *
	) SELECT count(*) INTO _hate FROM nc;

	RETURN OLD;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.ins_site_netblock_collections()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_hate	INTEGER;
BEGIN

	WITH nc AS (
		INSERT INTO netblock_collection (
			netblock_collection_name, netblock_collection_type
		) VALUES (
			NEW.site_code, 'per-site'
		) RETURNING *
	), p AS (
		INSERT INTO property (
			property_name, property_type, site_code,
			netblock_collection_id
		) SELECT
			'per-site-netblock_collection', 'automated', NEW.site_code,
			netblock_collection_id
			FROM nc
		RETURNING *
	) SELECT count(*) INTO _hate FROM p;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.site_netblock_del()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
BEGIN
	DELETE FROM netblock_collection_netblock
	WHERE netblock_collection_id IN (
		SELECT netblock_collection_id
			FROM property
			WHERE property_type = 'automated'
			AND property_name = 'per-site-netblock_collection'
			AND site_code = OLD.site_code
		)
	AND netblock_id = OLD.netblock_id;

	RETURN OLD;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.site_netblock_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	WITH i AS (
		INSERT INTO netblock_collection_netblock
			(netblock_collection_id, netblock_id)
		SELECT netblock_collection_id, NEW.netblock_id
			FROM property
			WHERE property_type = 'automated'
			AND property_name = 'per-site-netblock_collection'
			AND site_code = NEW.site_code
		RETURNING *
	) SELECT count(*) INTO _tally FROM i;

	IF _tally != 1 THEN
		RAISE 'Inserted % rows, not 1.', _tally;
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.site_netblock_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	upd_query	TEXT[];
BEGIN
	upd_query := NULL;
	IF OLD.site_code != NEW.site_code THEN
		upd_query := array_append(upd_query,
			'netblock_collection_id = ' ||
				( SELECT netblock_collection_id
					FROM property
					WHERE property_type = 'automated'
					AND property_name = 'per-site-netblock_collection'
					AND site_code = NEW.site_code
				)
		);
	END IF;

	IF OLD.netblock_id != NEW.netblock_id THEN
		upd_query := array_append(upd_query,
			'netblock_id = ' || NEW.netblock_id
		);
	END IF;

	IF upd_query IS NOT NULL THEN
		EXECUTE 'UPDATE netblock_collection_netblock SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE netblock_id = $1 
				AND netblock_collection_id IN 
				( SELECT netblock_collection_id
					FROM property
					WHERE property_type = $3
					AND property_name = $4
					AND site_code = $2
				)
			RETURNING *'
			USING OLD.netblock_id, OLD.site_code,
				'automated', 'per-site-netblock_collection';
	END IF;
	RETURN NEW;

END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.upd_site_netblock_collections()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	--
	-- The property site_code is not adjusted here because that's a fk
	-- that anything renaming the site code would need to deal with
	-- if renaming a property and that is just too confusing.
	--
	UPDATE netblock_collection
		SET netblock_collection_name = NEW.site_code
		WHERE netblock_collection_name = OLD.site_code
		AND netblock_collection_type = 'per-site';

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_val_property_after()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
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
-- Process drops in auto_ac_manip
--
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
				INNER JOIN v_property p
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
			INNER JOIN v_property p
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
				INNER JOIN v_property p USING (account_collection_id)
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
		FROM    (SELECT p.property_id, 
					p.account_collection_id,
					cc.company_id, 
					p.account_realm_id, p.property_name, p.property_type,
					p.property_value
					FROM v_property p
						LEFT JOIN (
								SELECT company_collection_id, company_id
								FROM	company_collection
										JOIN company_collection_company
										USING (company_collection_id)
						) cc USING (company_collection_id)
				) p
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
				INNER JOIN v_property p USING (account_collection_id)
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
		FROM    v_property p
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
			INNER JOIN v_property p
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

-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'retire_racks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.retire_racks ( rack_id_list integer[] );
CREATE OR REPLACE FUNCTION device_utils.retire_racks(rack_id_list integer[])
 RETURNS TABLE(rack_id integer, success boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	rid					ALIAS FOR rack_id;
	device_id_list		integer[];
	component_id_list	integer[];
	enc_domain_list		text[];
	empty_enc_domain_list		text[];
BEGIN
	BEGIN
		PERFORM local_hooks.rack_retire_early(rack_id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	--
	-- Get the list of devices which either are directly attached to
	-- a rack_location in this rack, or which are attached to a component
	-- which is attached to this rack.  Do this once, since it's an
	-- expensive query
	--
	device_id_list := ARRAY(
		SELECT
			device_id
		FROM
			device d JOIN
			rack_location rl USING (rack_location_id)
		WHERE
			rl.rack_id = ANY(rack_id_list)
		UNION
		SELECT
			device_id
		FROM
			rack_location rl JOIN
			component pc USING (rack_location_id) JOIN
			v_component_hier ch USING (component_id) JOIN
			device d ON (d.component_id = ch.child_component_id)
		WHERE
			rl.rack_id = ANY(rack_id_list)
	);

	--
	-- For components, just get a list of those directly attached to the rack
	-- and remove them.  We probably don't need to save this list, but just
	-- in case, we do
	--
	WITH x AS (
		UPDATE
			component AS c
		SET
			rack_location_id = NULL
		FROM
			rack_location rl
		WHERE
			rl.rack_location_id = c.rack_location_id AND
			rl.rack_id = ANY(rack_id_list)
		RETURNING
			c.component_id AS component_id
	) SELECT ARRAY(SELECT component_id FROM x) INTO component_id_list;

	--
	-- Get a list of all of the encapsulation_domains that are
	-- used by devices in these racks and stash them for later
	--
	enc_domain_list := ARRAY(
		SELECT DISTINCT
			encapsulation_domain
		FROM
			device_encapsulation_domain
		WHERE
			device_id = ANY(device_id_list)
	);

	PERFORM device_utils.retire_devices(device_id_list := device_id_list);

	--
	-- Check the encapsulation domains and for any that have no devices
	-- in them any more, clean up the layer2_networks for them
	--

	empty_enc_domain_list := ARRAY(
		SELECT
			encapsulation_domain
		FROM
			unnest(enc_domain_list) AS x(encapsulation_domain)
		WHERE
			encapsulation_domain NOT IN (
				SELECT encapsulation_domain FROM device_encapsulation_domain
			)
	);

	IF FOUND THEN
		PERFORM layerx_network_manip.delete_layer2_networks(
			layer2_network_id_list := ARRAY(
				SELECT
					layer2_network_id
				FROM
					layer2_network
				WHERE
					encapsulation_domain = ANY(empty_enc_domain_list)
			)
		);
		DELETE FROM encapsulation_domain WHERE
			encapsulation_domain = ANY(empty_enc_domain_list);
	END IF;

	BEGIN
		PERFORM local_hooks.racK_retire_late(rack_id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	FOREACH rid IN ARRAY rack_id_list LOOP
		BEGIN
			DELETE FROM rack_location rl WHERE rl.rack_id = rid;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
		BEGIN
			DELETE FROM rack r WHERE r.rack_id = rid;
			success := true;
			RETURN NEXT;
		EXCEPTION WHEN foreign_key_violation THEN
			UPDATE rack r SET
				room = NULL,
				sub_room = NULL,
				rack_row = NULL,
				rack_name = 'none',
				description = 'retired'
			WHERE	r.rack_id = rid;
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
	family_bits		integer;
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

	IF ip_block_1 <<= ip_block_2 AND ip_block_2 <<= ip_block_1 THEN
		RAISE EXCEPTION 'netblocks % and % intersect each other',
			ip_block_1,
			ip_block_2;
	END IF;

	-- Order the blocks correctly

	IF ip_block_1 > ip_block_2 THEN
		new_nb := ip_block_1;
		ip_block_1 := ip_block_2;
		ip_block_2 := new_nb;
	END IF;

	current_nb := ip_block_1;
	max_addr := broadcast(ip_block_1);

	family_bits := CASE WHEN family(ip_block_1) = 4 THEN 32 ELSE 128 END;

	-- Loop through bumping the netmask up and seeing if the destination block is in the new block
	LOOP
		new_nb := network(set_masklen(current_nb, masklen(current_nb) - 1));

		-- If the block is in our new larger netblock, then exit this loop
		IF (new_nb >>= ip_block_2) THEN
			current_nb := broadcast(current_nb) + 1;
			EXIT;
		END IF;
	
		-- If the max address of the new netblock is larger than the last one, then it's empty
		IF set_masklen(broadcast(new_nb), family_bits) > 
			set_masklen(max_addr, family_bits)
		THEN
			ip_addr := set_masklen(max_addr + 1, masklen(current_nb));
			-- Validate that this isn't an empty can_subnet='Y' block already
			-- If it is, split it in half and return both halves
			PERFORM * FROM netblock n WHERE
				n.ip_address = ip_addr AND
				n.ip_universe_id =
					calculate_intermediate_netblocks.ip_universe_id AND
				n.netblock_type =
					calculate_intermediate_netblocks.netblock_type;
			IF FOUND AND masklen(ip_addr) < family_bits THEN
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
		IF host(current_nb) = host(ip_block_2) OR
			masklen(current_nb) >= family_bits
		THEN
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
			IF FOUND AND masklen(ip_addr) < family_bits THEN
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

-- New function
CREATE OR REPLACE FUNCTION netblock_utils.find_best_ip_universe(ip_address inet, ip_namespace character varying DEFAULT 'default'::character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	u_id	ip_universe.ip_universe_id%TYPE;
	ip	inet;
	nsp	text;
BEGIN
	ip := ip_address;
	nsp := ip_namespace;

	SELECT	nb.ip_universe_id
	INTO	u_id
	FROM	netblock nb
		JOIN ip_universe u USING (ip_universe_id)
	WHERE	is_single_address = 'N'
	AND	nb.ip_address >>= ip
	AND	u.ip_namespace = 'default'
	ORDER BY masklen(nb.ip_address) desc
	LIMIT 1;

	IF u_id IS NOT NULL THEN
		RETURN u_id;
	END IF;
	RETURN 0;

END;
$function$
;

--
-- Process drops in property_utils
--
-- New function
CREATE OR REPLACE FUNCTION property_utils.validate_property(new property)
 RETURNS property
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
-- Changed function
SELECT schema_support.save_grants_for_replay('approval_utils', 'approve');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS approval_utils.approve ( approval_instance_item_id integer, approved character, approving_account_id integer, new_value text );
CREATE OR REPLACE FUNCTION approval_utils.approve(approval_instance_item_id integer, approved character, approving_account_id integer, new_value text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO approval_utils, jazzhands
AS $function$
DECLARE
	_r		RECORD;
	_aii	approval_instance_item%ROWTYPE;	
	_new	approval_instance_item.approval_instance_item_id%TYPE;	
	_chid	approval_process_chain.approval_process_chain_id%TYPE;
	_tally	INTEGER;
BEGIN
	EXECUTE '
		SELECT 	aii.approval_instance_item_id,
			ais.approval_instance_step_id,
			ais.approval_instance_id,
			ais.approver_account_id,
			ais.approval_type,
			aii.is_approved,
			ais.is_completed,
			aic.accept_app_process_chain_id,
			aic.reject_app_process_chain_id
   	     FROM    approval_instance ai
   		     INNER JOIN approval_instance_step ais
   			 USING (approval_instance_id)
   		     INNER JOIN approval_instance_item aii
   			 USING (approval_instance_step_id)
   		     INNER JOIN approval_instance_link ail
   			 USING (approval_instance_link_id)
			INNER JOIN approval_process_chain aic
				USING (approval_process_chain_id)
		WHERE approval_instance_item_id = $1
	' USING approval_instance_item_id INTO 	_r;

	--
	-- Ensure that only the person or their management chain can approve
	-- others; this may want to be a property on val_approval_type rather
	-- than hard coded on account...
	IF (_r.approval_type = 'account' AND _r.approver_account_id != approving_account_id ) THEN
		EXECUTE '
			SELECT count(*)
			FROM	v_account_manager_hier
			WHERE account_id = $1
			AND manager_account_id = $2
		' INTO _tally USING _r.approver_account_id, approving_account_id;

		IF _tally = 0 THEN
			EXECUTE '
				SELECT	count(*)
				FROM	property
						INNER JOIN v_acct_coll_acct_expanded e
						USING (account_collection_id)
				WHERE	property_type = ''Defaults''
				AND		property_name = ''_can_approve_all''
				AND		e.account_id = $1
			' INTO _tally USING approving_account_id;

			IF _tally = 0 THEN
				RAISE EXCEPTION 'Only a person and their management chain may approve others';
			END IF;
		END IF;

	END IF;

	IF _r.approval_instance_item_id IS NULL THEN
		RAISE EXCEPTION 'Unknown approval_instance_item_id %',
			approval_instance_item_id;
	END IF;

	IF _r.is_approved IS NOT NULL THEN
		RAISE EXCEPTION 'Approval is already completed.';
	END IF;

	IF approved = 'N' THEN
		IF _r.reject_app_process_chain_id IS NOT NULL THEN
			_chid := _r.reject_app_process_chain_id;	
		END IF;
	ELSIF approved = 'Y' THEN
		IF _r.accept_app_process_chain_id IS NOT NULL THEN
			_chid := _r.accept_app_process_chain_id;
		END IF;
	ELSE
		RAISE EXCEPTION 'Approved must be Y or N';
	END IF;

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

	--
	-- This needs to happen after the next steps are created
	-- or the entire process gets marked as done on the second to last
	-- update instead of the list.

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
-- Process drops in layerx_network_manip
--
--
-- Process drops in schema_support
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_trigger');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_trigger ( aud_schema character varying, tbl_schema character varying, table_name character varying );
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

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'trigger_ins_upd_generic_func');
CREATE OR REPLACE FUNCTION schema_support.trigger_ins_upd_generic_func()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

--
-- Process drops in component_connection_utils
--
-- New function
CREATE OR REPLACE FUNCTION component_connection_utils.create_inter_component_connection(INOUT device_id integer, INOUT slot_name character varying, INOUT remote_slot_name character varying, INOUT remote_device_id integer DEFAULT NULL::integer, remote_host_id character varying DEFAULT NULL::character varying, remote_device_name character varying DEFAULT NULL::character varying, force boolean DEFAULT false, OUT inter_component_connection_id integer, OUT slot_id integer, OUT slot_index integer, OUT mac_address macaddr, OUT slot_type_id integer, OUT slot_type text, OUT slot_function text, OUT remote_slot_id integer, OUT remote_slot_index integer, OUT remote_mac_address macaddr, OUT remote_slot_type_id integer, OUT remote_slot_type text, OUT remote_slot_function text, OUT changed boolean)
 RETURNS SETOF record
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	remote_dev_rec		RECORD;
	slot_rec			RECORD;
	remote_slot_rec		RECORD;
	_device_id			ALIAS FOR device_id;
	_slot_name			ALIAS FOR slot_name;
	_remote_slot_name	ALIAS FOR remote_slot_name;
	_remote_device_id	ALIAS FOR remote_device_id;
	_remote_host_id		ALIAS FOR remote_host_id;
	_remote_device_name	ALIAS FOR remote_device_name;
BEGIN
	--
	-- Validate what's passed
	--
	IF remote_device_id IS NULL AND remote_host_id IS NULL AND
		remote_device_name IS NULL
	THEN
		RAISE 'Must pass remote_device_id, remote_host_id, or remote_device_name to create_inter_component_connection()' 
			USING ERRCODE = 'null_value_not_allowed';
	END IF;

	--
	-- For selecting a device, prefer passed device_id
	--
	IF remote_device_id IS NOT NULL THEN
		SELECT
			d.device_id,
			d.device_name,
			d.host_id
		INTO remote_dev_rec
		FROM
			device d
		WHERE
			d.device_id = remote_device_id;

		IF NOT FOUND THEN
			RETURN;
		END IF;
	ELSIF remote_device_name IS NOT NULL THEN
		BEGIN
			SELECT
				d.device_id,
				d.device_name,
				d.host_id
			INTO STRICT remote_dev_rec
			FROM
				device d
			WHERE
				device_name = remote_device_name AND
				device_status != 'removed';
		EXCEPTION
			WHEN NO_DATA_FOUND THEN RETURN;
			WHEN TOO_MANY_ROWS THEN
				RAISE EXCEPTION 'Multiple devices have device_name %',
					remote_device_name;
		END;
	ELSIF remote_host_id IS NOT NULL THEN
		BEGIN
			SELECT
				d.device_id,
				d.device_name,
				d.host_id
			INTO STRICT remote_dev_rec
			FROM
				device d
			WHERE
				host_id = remote_host_id AND
				device_status != 'removed';
		EXCEPTION
			WHEN NO_DATA_FOUND THEN RETURN;
			WHEN TOO_MANY_ROWS THEN
				RAISE EXCEPTION 'Multiple devices have host_id %',
					remote_host_id;
		END;
	END IF;

	RAISE DEBUG 'Remote device is %', row_to_json(remote_dev_rec, true);
	--
	-- Now look to make sure both slots exist and whether there is a current
	-- connection for the remote side
	--

	SELECT
		*
	INTO
		slot_rec
	FROM
		jazzhands.v_device_slot_connections dsc
	WHERE
		dsc.device_id = _device_id AND
		dsc.slot_name = _slot_name AND
		dsc.slot_function = 'network';

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Network slot % does not exist on device %',
			_slot_name,
			_device_id;
	END IF;

	RAISE DEBUG 'Local slot is %', row_to_json(slot_rec, true);
	
	SELECT
		*
	INTO
		remote_slot_rec
	FROM
		jazzhands.v_device_slot_connections dsc
	WHERE
		dsc.device_id = remote_dev_rec.device_id AND
		dsc.slot_name = _remote_slot_name AND
		dsc.slot_function = 'network';

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Network slot % does not exist on device %',
			_slot_name,
			_device_id;
	END IF;

	RAISE DEBUG 'Remote slot is %', row_to_json(remote_slot_rec, true);
	
	--
	-- See if these are already connected
	--
	IF slot_rec.inter_component_connection_id = 
		remote_slot_rec.inter_component_connection_id
	THEN
		inter_component_connection_id := slot_rec.inter_component_connection_id;
		slot_id := slot_rec.slot_id;
		slot_name := slot_rec.slot_name;
		slot_index := slot_rec.slot_index;
		mac_address := slot_rec.mac_address;
		slot_type_id := slot_rec.slot_type_id;
		slot_type := slot_rec.slot_type;
		slot_function := slot_rec.slot_function;
		remote_device_id := slot_rec.remote_device_id;
		remote_slot_id := slot_rec.remote_slot_id;
		remote_slot_name := slot_rec.remote_slot_name;
		remote_slot_index := slot_rec.remote_slot_index;
		remote_mac_address := slot_rec.remote_mac_address;
		remote_slot_type_id := slot_rec.remote_slot_type_id;
		remote_slot_type := slot_rec.remote_slot_type;
		remote_slot_function := slot_rec.remote_slot_function;
		changed := false;
		RETURN NEXT;
		RETURN;
	END IF;

	--
	-- See if we can create a new connection
	--
	IF remote_slot_rec.inter_component_connection_id IS NOT NULL THEN
		IF
			force OR
			remote_host_id = remote_dev_rec.host_id
		THEN
			DELETE FROM
				inter_component_connection icc
			WHERE
				icc.inter_component_connection_id = 
					remote_slot_rec.inter_component_connection_id;
		ELSE
			RAISE EXCEPTION 'Slot % for device % is already connected to slot % on device %',
				remote_slot_rec.slot_name,
				remote_slot_rec.device_id,
				remote_slot_rec.remote_slot_name,
				remote_slot_rec.remote_device_id;
			RETURN;
		END IF;
	END IF;

	IF slot_rec.inter_component_connection_id IS NOT NULL THEN
		DELETE FROM
			inter_component_connection icc
		WHERE
			icc.inter_component_connection_id = 
				slot_rec.inter_component_connection_id;
	END IF;

	INSERT INTO inter_component_connection (
		slot1_id,
		slot2_id
	) VALUES (
		slot_rec.slot_id,
		remote_slot_rec.slot_id
	);

	SELECT
		* INTO slot_rec
	FROM
		jazzhands.v_device_slot_connections dsc
	WHERE
		dsc.slot_id = slot_rec.slot_id;
		
	inter_component_connection_id := slot_rec.inter_component_connection_id;
	slot_id := slot_rec.slot_id;
	slot_name := slot_rec.slot_name;
	slot_index := slot_rec.slot_index;
	mac_address := slot_rec.mac_address;
	slot_type_id := slot_rec.slot_type_id;
	slot_type := slot_rec.slot_type;
	slot_function := slot_rec.slot_function;
	remote_device_id := slot_rec.remote_device_id;
	remote_slot_id := slot_rec.remote_slot_id;
	remote_slot_name := slot_rec.remote_slot_name;
	remote_slot_index := slot_rec.remote_slot_index;
	remote_mac_address := slot_rec.remote_mac_address;
	remote_slot_type_id := slot_rec.remote_slot_type_id;
	remote_slot_type := slot_rec.remote_slot_type;
	remote_slot_function := slot_rec.remote_slot_function;
	changed := true;
	RETURN NEXT;
	RETURN;
END;
$function$
;

-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....
DROP SEQUENCE IF EXISTS audit.site_netblock_seq;


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- index
-- triggers
DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_trigger_change ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_trigger_change AFTER INSERT OR UPDATE OF soa_class, soa_ttl, soa_serial, soa_refresh, soa_retry, soa_expire, soa_minimum, soa_mname, soa_rname, should_generate ON dns_domain_ip_universe FOR EACH ROW EXECUTE PROCEDURE dns_domain_ip_universe_trigger_change();
DROP TRIGGER IF EXISTS trigger_del_site_netblock_collections ON site;
CREATE TRIGGER trigger_del_site_netblock_collections BEFORE DELETE ON site FOR EACH ROW EXECUTE PROCEDURE del_site_netblock_collections();
DROP TRIGGER IF EXISTS trigger_ins_site_netblock_collections ON site;
CREATE TRIGGER trigger_ins_site_netblock_collections AFTER INSERT ON site FOR EACH ROW EXECUTE PROCEDURE ins_site_netblock_collections();
DROP TRIGGER IF EXISTS trigger_upd_site_netblock_collections ON site;
CREATE TRIGGER trigger_upd_site_netblock_collections AFTER UPDATE ON site FOR EACH ROW EXECUTE PROCEDURE upd_site_netblock_collections();
DROP TRIGGER IF EXISTS trigger_validate_val_property_after ON val_property;
CREATE CONSTRAINT TRIGGER trigger_validate_val_property_after AFTER UPDATE ON val_property DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE validate_val_property_after();


-- BEGIN Misc that does not apply to above

SELECT schema_support.rebuild_audit_triggers( 'audit'::text, 'jazzhands'::text);

DROP FUNCTION IF EXISTS perform_audit_site_netblock();

DELETE FROM __regrants where schema = 'audit' and object = 'site_netblock';

CREATE TRIGGER trigger_site_netblock_del INSTEAD OF DELETE ON site_netblock FOR EACH ROW EXECUTE PROCEDURE site_netblock_del();
CREATE TRIGGER trigger_site_netblock_ins INSTEAD OF INSERT ON site_netblock FOR EACH ROW EXECUTE PROCEDURE site_netblock_ins();
CREATE TRIGGER trigger_site_netblock_upd INSTEAD OF UPDATE ON site_netblock FOR EACH ROW EXECUTE PROCEDURE site_netblock_upd();

DROP TRIGGER IF EXISTS trigger_audit_token_sequence ON token_sequence;

-- --
-- -- postgresql 10 seems to default to bigints for sequences.  As such,
-- -- try to change them all; pg_sequences is also added in 10, so use the
-- -- lack of that existing as a reason not to bother.
-- --
-- DO $$
-- DECLARE
-- 	_r	RECORD;
-- 	s	TEXT;
-- BEGIN
-- 	FOR _r IN SELECT schemaname,sequencename,data_type
-- 		FROM pg_sequences
-- 		WHERE schemaname IN ('jazzhands', 'audit')
-- 	LOOP
-- 		s := 'ALTER SEQUENCE ' ||
-- 			quote_ident(_r.schemaname) || '.' ||
-- 			quote_ident(_r.sequencename) ||
-- 			' AS bigint';
-- 		RAISE NOTICE '%', s;
-- 		EXECUTE s;
-- 
-- 	END LOOP;
-- EXCEPTION WHEN SQLSTATE '42P01' THEN
-- 	RAISE NOTICE 'Skipping sequence type change to due postgres version';
-- END
-- $$;
-- 
-- 


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
