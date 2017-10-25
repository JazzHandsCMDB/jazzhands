/*
 * Copyright (c) 2015-2017 Todd Kover
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

/*
 * These routines support the management of account collections for people that
 * report to and rollup to a given person.
 *
 * They were written with multiple account_realms in mind, although the triggers
 * only support all this for the default realm as defined by properties, so
 * a multiple realm context is untested.
 *
 * Many of the routines accept optional arguments for various fields.  This is
 * to speed up calling functions so the same queries do not need to be run
 * multiple times.  There is probably room for additional cleverness around
 * all this.  If those values are not specified, then they get looked up.
 *
 * This handles both contractors and employees.  It should probably be
 * tweaked to just handle employees.
 */

/*
 * $Id$
 */

-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'auto_ac_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS auto_ac_manip;
		CREATE SCHEMA auto_ac_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA auto_ac_manip IS 'part of jazzhands';
	END IF;
END;
$$;

\set ON_ERROR_STOP


--------------------------------------------------------------------------------
-- returns the Id tag for CM
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id$ -->');
END;
$$ LANGUAGE plpgsql;
-- end of procedure id_tag

--------------------------------------------------------------------------------
--
-- renames a person's magic account collection when login name changes
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.rename_automated_report_acs(
	account_id			account.account_id%TYPE,
	old_login			account.login%TYPE,
	new_login			account.login%TYPE,
	account_realm_id	account.account_realm_id%TYPE
) RETURNS VOID AS $_$
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
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- returns the number of direct reports to a person
--
-- does *NOT* include terminated employees.
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.get_num_direct_reports(
	account_id	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE
) RETURNS INTEGER AS $_$
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
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- returns the number of direct reports that have reports
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.get_num_reports_with_reports(
	account_id	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE
) RETURNS INTEGER AS $_$
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
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;


--------------------------------------------------------------------------------
--
-- returns the automated ac for a given account for a given purpose, creates
-- if necessary.
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.find_or_create_automated_ac(
	account_id	account.account_id%TYPE,
	ac_type		property.property_name%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL
)  RETURNS account_collection.account_collection_id%TYPE AS $_$
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
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- Creates the account collection and associated property if it exists,
-- makes sure the membership is what it should be (excluding the account,
-- itself, which may be a mistake -- the assumption is it was removed for a
-- good reason.
--
-- Returns the account_collection_id
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.populate_direct_report_ac(
	account_id	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL
)  RETURNS account_collection.account_collection_id%TYPE AS $_$
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
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- Creates the account collection and associated property if it exists,
-- makes sure the membership is what it should be .  This does NOT manipulate
-- the -direct account collection at all
--
-- Returns the account_collection_id
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.populate_rollup_report_ac(
	account_id	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL
)  RETURNS account_collection.account_collection_id%TYPE AS $_$
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
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;


--------------------------------------------------------------------------------
--
-- makes sure that the -direct and -rollup account collections exist for
-- someone that should.  Does not destroy
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.create_report_account_collections(
	account_id	account.account_id%TYPE,
	account_realm_id	account.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL,
	numrpt				integer DEFAULT NULL,
	numrlup				integer DEFAULT NULL
)  RETURNS VOID AS $_$
DECLARE
	_account	account%ROWTYPE;
	_directac	account_collection.account_collection_id%TYPE;
	_rollupac	account_collection.account_collection_id%TYPE;
BEGIN
	IF ( login is NULL or account_realm_id IS NULL ) THEN
		EXECUTE '
		SELECT account_realm_id, login
		FROM	account
		WHERE	account_id = $1
		' INTO account_realm_id, login USING account_id;
	END IF;
	IF numrpt IS NULL THEN
		numrpt := auto_ac_manip.get_num_direct_reports(account_id, account_realm_id);
	END IF;

	IF numrpt = 0 THEN
		RETURN;
	END IF;

	_directac := auto_ac_manip.populate_direct_report_ac(account_id, account_realm_id, login);

	IF numrlup IS NULL THEN
		numrlup := auto_ac_manip.get_num_reports_with_reports(account_id, account_realm_id);
	END IF;

	IF numrlup = 0 THEN
		RETURN;
	END IF;

	_rollupac := auto_ac_manip.populate_rollup_report_ac(account_id, account_realm_id, login);

	-- add directs to rollup
	EXECUTE 'INSERT INTO account_collection_hier (
			account_collection_id, child_account_collection_id
		) VALUES (
			$1, $2
		)' USING _rollupac, _directac;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

CREATE OR REPLACE FUNCTION auto_ac_manip.purge_report_account_collection(
	account_id	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE,
	ac_type		property.property_name%TYPE
) RETURNS VOID AS $_$
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
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- makes sure that the -direct and -rollup account collections do exist for
-- someone if they should not.  Removes if necessary, and also removes them
-- from other account collections.  Arguably should also remove other
-- properties associated but I opted out of that for now.
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.destroy_report_account_collections(
	account_id	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	numrpt				integer DEFAULT NULL,
	numrlup				integer DEFAULT NULL
)  RETURNS VOID AS $_$
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
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- one routine that just goes and fixes all the -direct and -rollup auto
-- account collections to be right.  Note that this just calls other routines
-- and relies on them to decide if things should be purged or not.
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.make_auto_report_acs_right(
	account_id			account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL
)  RETURNS VOID AS $_$
DECLARE
	_numrpt	INTEGER;
	_numrlup INTEGER;
BEGIN
	IF account_realm_id IS NULL OR login IS NULL THEN
		EXECUTE '
			SELECT account_realm_id, login
			FROM	account
			WHERE	account_id = $1
		' INTO account_realm_id, login USING account_id;
	END IF;
	_numrpt := auto_ac_manip.get_num_direct_reports(account_id, account_realm_id);
	_numrlup := auto_ac_manip.get_num_reports_with_reports(account_id, account_realm_id);
	PERFORM auto_ac_manip.destroy_report_account_collections(account_id, account_realm_id, _numrpt, _numrlup);
	PERFORM auto_ac_manip.create_report_account_collections(account_id, account_realm_id, login, _numrpt, _numrlup);
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;



--------------------------------------------------------------------------------
--
-- fix all the fields that come from person_company.  This would be
-- called from a trigger.
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.make_personal_acs_right(
	account_id	account.account_id%TYPE
) RETURNS integer AS $_$
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
		FROM    (SELECT p.property_id, 
					p.account_collection_id,
					cc.company_id, 
					p.account_realm_id, p.property_name, p.property_type,
					p.property_value
					FROM property p
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
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- fix the person's site code based on their location.  This is largely meant
-- to be called by the person_location trigger.
-- called from a trigger.
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.make_site_acs_right(
	account_id	account.account_id%TYPE
) RETURNS integer AS $_$
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
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;


--------------------------------------------------------------------------------
--
-- one routine that just fixes all auto acs
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.make_all_auto_acs_right(
	account_id			account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL
)  RETURNS VOID AS $_$
BEGIN
	PERFORM auto_ac_manip.make_auto_report_acs_right(account_id, account_realm_id, login);
	PERFORM auto_ac_manip.make_site_acs_right(account_id);
	PERFORM auto_ac_manip.make_personal_acs_right(account_id);
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;



grant usage on schema auto_ac_manip to iud_role;
revoke all on schema auto_ac_manip from public;
revoke all on  all functions in schema auto_ac_manip from public;
grant execute on all functions in schema auto_ac_manip to iud_role;
