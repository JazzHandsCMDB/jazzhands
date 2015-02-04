/*
 * Copyright (c) 2015 Todd Kover
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

/*************************************************************************

This is how they used to work; this logic needs to be folded into 
"add a comany" logic

Here is how these work:

automated_ac()
	on account, used for RealmName_Type, most practically RealmName_person
	that is, omniscientcompany_person

automated_ac_on_person_company()
	on person_company, used for RealmName_ShortName_thing, that is:

		OmniscientRealm_omniscientcompany_full_time
		OmniscientRealm_omniscientcompany_management
		OmniscientRealm_omniscientcompany_exempt

		Y means they're in, N means they're not

automated_ac_on_person()
	on person, manipulates gender related class of the form
		RealmName_ShortName_thing that is

		OmniscientRealm_omniscientcompany_male
		OmniscientRealm_omniscientcompany_female

		also need to incorporate unknown

automated_realm_site_ac_pl()
	on person_location.  RealmName_SITE, i.e.  Omniscient_IAD1

	associates  a person's primary account in the realm with s site code

*************************************************************************/

--
-- Changes to account trigger addition/removal from various things.  This is
-- actually redundant with the second two triggers on person_company and
-- person, which deal with updates.  This covers the case of accounts coming
-- into existance after the rows in person/person_company
--
-- This currently does not move an account out of a "site" class when someone 
-- moves around, which should probably be revisited.
--
CREATE OR REPLACE FUNCTION automated_ac_on_account() 
RETURNS TRIGGER AS $_$
DECLARE
	_tally	INTEGER;
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


	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__automated_ac__'
	   AND  relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __automated_ac__ (account_collection_id integer, account_id integer, direction text);
	END IF;


	--
	-- based on the old and new values, check for account collections that
	-- may need to be changed based on data.  Note that this may end up being
	-- a no-op.
	-- 
	IF TG_OP = 'INSERT' or TG_OP = 'UPDATE' THEN
		WITH acct AS (
			    SELECT  a.account_id, a.account_type, a.account_role, parc.*,
				    pc.is_management, pc.is_full_time, pc.is_exempt,
				    p.gender
			     FROM   account a
				    INNER JOIN person_account_realm_company parc
					    USING (person_id, company_id, account_realm_id)
				    INNER JOIN person_company pc USING (person_id,company_id)
				    INNER JOIN person p USING (person_id)
			),
		list AS (
			SELECT  p.account_collection_id, a.account_id, a.account_type,
				a.account_role,
				a.person_id, a.company_id
			FROM    property p
			    INNER JOIN acct a
				ON a.account_realm_id = p.account_realm_id
			WHERE   (p.company_id is NULL or a.company_id = p.company_id)
			    AND     property_type = 'auto_acct_coll'
			    AND     (
				    property_name =
					CASE WHEN a.is_exempt = 'N'
					    THEN 'non_exempt'
					    ELSE 'exempt' END
				OR
				    property_name =
					CASE WHEN a.is_management = 'N'
					    THEN 'non_management'
					    ELSE 'management' END
				OR
				    property_name =
					CASE WHEN a.is_full_time = 'N'
					    THEN 'non_full_time'
					    ELSE 'full_time' END
				OR
				    property_name =
					CASE WHEN a.gender = 'M' THEN 'male'
					    WHEN a.gender = 'F' THEN 'female'
					    ELSE 'unspecified_gender' END
				OR (
				    property_name = 'account_type'
				    AND property_value = a.account_type
				    )
				)
		) 
		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		) select account_collection_id, account_id, 'add'
		FROM list 
		WHERE account_id = NEW.account_id
		AND NEW.account_role = 'primary'
		;
	END IF;
	IF TG_OP = 'UPDATE' or TG_OP = 'DELETE' THEN
		WITH acct AS (
			    SELECT  a.account_id, a.account_type, a.account_role, parc.*,
				    pc.is_management, pc.is_full_time, pc.is_exempt,
				    p.gender
			     FROM   account a
				    INNER JOIN person_account_realm_company parc
					    USING (person_id, company_id, account_realm_id)
				    INNER JOIN person_company pc USING (person_id,company_id)
				    INNER JOIN person p USING (person_id)
			),
		list AS (
			SELECT  p.account_collection_id, a.account_id, a.account_type,
				a.account_role,
				a.person_id, a.company_id
			FROM    property p
			    INNER JOIN acct a
				ON a.account_realm_id = p.account_realm_id
			WHERE   (p.company_id is NULL or a.company_id = p.company_id)
			    AND     property_type = 'auto_acct_coll'
				AND (
					( account_role != 'primary' AND
						property_name in ('non_exempt', 'exempt',
						'management', 'non_management', 'full_time',
						'non_full_time', 'male', 'female', 'unspecified_gender')
				) OR (
					account_role != 'primary'
				    AND property_name = 'account_type'
				    AND property_value = a.account_type
				    )
				)
		) 
		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		) select account_collection_id, account_id, 'remove'
		FROM list 
		WHERE account_id = OLD.account_id
		;
	END IF;

/*
	FOR _r IN SELECT * from __automated_ac__
	LOOP
		RAISE NOTICE '%', _r;
	END LOOP;
*/

	--
	-- Remove rows from the temporary table that are in "remove" but not in
	-- "add".
	--
	DELETE FROM account_collection_account
	WHERE (account_collection_id, account_id) IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
		)
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'add'
	)
	;
	--
	-- Add rows from the temporary table that are in 'add" but not "remove"
	-- "add".
	--
	INSERT INTO account_collection_account (
		account_collection_id, account_id)
	SELECT account_collection_id, account_id 
	FROM __automated_ac__
	WHERE direction = 'add'
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
	)
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM account_collection_account)
	;

	DROP TABLE IF EXISTS __automated_ac__;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trig_add_automated_ac_on_account ON account;
CREATE TRIGGER trig_add_automated_ac_on_account 
	AFTER INSERT OR UPDATE OF account_type, account_role
	ON account 
	FOR EACH ROW 
	EXECUTE PROCEDURE automated_ac_on_account();

DROP TRIGGER IF EXISTS trig_rm_automated_ac_on_account ON account;
CREATE TRIGGER trig_rm_automated_ac_on_account 
	BEFORE DELETE 
	ON account 
	FOR EACH ROW 
	EXECUTE PROCEDURE automated_ac_on_account();

--------------------------------------------------------------------------

--
-- Using a temporary table, add/remove users based on account collections
-- as defined in properties.
--
CREATE OR REPLACE FUNCTION automated_ac_on_person_company() 
RETURNS TRIGGER AS $_$
DECLARE
	_tally	INTEGER;
	_r		RECORD;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__automated_ac__'
	   AND  relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __automated_ac__ (account_collection_id integer, account_id integer, direction text);
	END IF;


	RAISE NOTICE 'Here!';

	--
	-- based on the old and new values, check for account collections that
	-- may need to be changed based on data.  Note that this may end up being
	-- a no-op.
	-- 
	IF TG_OP = 'INSERT' or TG_OP = 'UPDATE' THEN
		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		)
		SELECT	p.account_collection_id, a.account_id, 'add'
		FROM    property p
			INNER JOIN account_realm_company arc USING (account_realm_id)
			INNER JOIN account a 
				ON a.account_realm_id = arc.account_realm_id
				AND a.company_id = arc.company_id
		WHERE	arc.company_id = NEW.company_id
		AND     (p.company_id is NULL or arc.company_id = p.company_id)
			AND	a.person_id = NEW.person_id
			AND     property_type = 'auto_acct_coll'
			AND     (
				    property_name =
				    CASE WHEN NEW.is_exempt = 'N'
					THEN 'non_exempt'
					ELSE 'exempt' END
				OR
				    property_name =
				    CASE WHEN NEW.is_management = 'N'
					THEN 'non_management'
					ELSE 'management' END
				OR
				    property_name =
				    CASE WHEN NEW.is_full_time = 'N'
					THEN 'non_full_time'
					ELSE 'full_time' END
				);
	END IF;
	IF TG_OP = 'UPDATE' or TG_OP = 'DELETE' THEN
		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		)
		SELECT	p.account_collection_id, a.account_id, 'remove'
		FROM    property p
			INNER JOIN account_realm_company arc USING (account_realm_id)
			INNER JOIN account a 
				ON a.account_realm_id = arc.account_realm_id
				AND a.company_id = arc.company_id
		WHERE	arc.company_id = OLD.company_id
		AND     (p.company_id is NULL or arc.company_id = p.company_id)
			AND	a.person_id = OLD.person_id
			AND     property_type = 'auto_acct_coll'
			AND     (
				    property_name =
				    CASE WHEN OLD.is_exempt = 'N'
					THEN 'non_exempt'
					ELSE 'exempt' END
				OR
				    property_name =
				    CASE WHEN OLD.is_management = 'N'
					THEN 'non_management'
					ELSE 'management' END
				OR
				    property_name =
				    CASE WHEN OLD.is_full_time = 'N'
					THEN 'non_full_time'
					ELSE 'full_time' END
				);
	END IF;

	FOR _r IN SELECT * from __automated_ac__
	LOOP
		RAISE NOTICE '%', _r;
	END LOOP;

	--
	-- Remove rows from the temporary table that are in "remove" but not in
	-- "add".
	--
	DELETE FROM account_collection_account
	WHERE (account_collection_id, account_id) IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
		)
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'add'
	);

	--
	-- Add rows from the temporary table that are in 'add" but not "remove"
	-- "add".
	--
	INSERT INTO account_collection_account (
		account_collection_id, account_id)
	SELECT account_collection_id, account_id 
	FROM __automated_ac__
	WHERE direction = 'add'
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
	);

	DROP TABLE IF EXISTS __automated_ac__;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trigger_automated_ac_on_person_company ON person_company;
CREATE TRIGGER trigger_automated_ac_on_person_company 
	AFTER UPDATE OF is_management, is_exempt, is_full_time, person_id,company_id
	ON person_company 
	FOR EACH ROW EXECUTE PROCEDURE 
	automated_ac_on_person_company();

--------------------------------------------------------------------------

--
-- fires on changes to person that are relevant.  This does not fire on
-- insert or delete because accounts do not exist in either of those cases.
--
CREATE OR REPLACE FUNCTION automated_ac_on_person() 
RETURNS TRIGGER AS $_$
DECLARE
	_tally	INTEGER;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__automated_ac__'
	   AND  relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __automated_ac__ (account_collection_id integer, account_id integer, direction text);
	END IF;


	--
	-- based on the old and new values, check for account collections that
	-- may need to be changed based on data.  Note that this may end up being
	-- a no-op.
	-- 
	IF TG_OP = 'UPDATE' THEN
		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		)
		SELECT	p.account_collection_id, a.account_id, 'add'
		FROM    property p
			INNER JOIN account_realm_company arc USING (account_realm_id)
			INNER JOIN account a 
				ON a.account_realm_id = arc.account_realm_id
				AND a.company_id = arc.company_id
		WHERE	arc.company_id = NEW.company_id
		AND     (p.company_id is NULL or arc.company_id = p.company_id)
			AND	a.person_id = NEW.person_id
			AND     property_type = 'auto_acct_coll'
			AND     (
				    property_name =
				    	CASE WHEN NEW.gender = 'M' THEN 'male'
				    		WHEN NEW.gender = 'F' THEN 'female'
							ELSE 'unspecified_gender' END
					);

		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		)
		SELECT	p.account_collection_id, a.account_id, 'remove'
		FROM    property p
			INNER JOIN account_realm_company arc USING (account_realm_id)
			INNER JOIN account a 
				ON a.account_realm_id = arc.account_realm_id
				AND a.company_id = arc.company_id
		WHERE	arc.company_id = OLD.company_id
		AND     (p.company_id is NULL or arc.company_id = p.company_id)
			AND	a.person_id = OLD.person_id
			AND     property_type = 'auto_acct_coll'
			AND     (
				    property_name =
				    	CASE WHEN OLD.gender = 'M' THEN 'male'
				    	WHEN OLD.gender = 'F' THEN 'female'
						ELSE 'unspecified_gender' END
				);
	END IF;

	--
	-- Remove rows from the temporary table that are in "remove" but not in
	-- "add".
	--
	DELETE FROM account_collection_account
	WHERE (account_collection_id, account_id) IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
		)
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'add'
	);

	--
	-- Add rows from the temporary table that are in 'add" but not "remove"
	-- "add".
	--
	INSERT INTO account_collection_account (
		account_collection_id, account_id)
	SELECT account_collection_id, account_id 
	FROM __automated_ac__
	WHERE direction = 'add'
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
	);

	DROP TABLE IF EXISTS __automated_ac__;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;

END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trigger_automated_ac_on_person ON person;
CREATE TRIGGER trigger_automated_ac_on_person 
	AFTER UPDATE OF gender ON person 
	FOR EACH ROW 
	EXECUTE PROCEDURE automated_ac_on_person();

--------------------------------------------------------------------------

--
-- If someone moves location, update the site if something appropriate exists
--
CREATE OR REPLACE FUNCTION automated_realm_site_ac_pl() 
RETURNS TRIGGER AS $_$
DECLARE
	_tally	INTEGER;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__automated_ac__'
	   AND  relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __automated_ac__ (account_collection_id integer, account_id integer, direction text);
	END IF;

	--
	-- based on the old and new values, check for account collections that
	-- may need to be changed based on data.  Note that this may end up being
	-- a no-op.
	-- 
	IF TG_OP = 'INSERT' or TG_OP = 'UPDATE' THEN
		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		)
		SELECT	p.account_collection_id, a.account_id, 'add'
		FROM    property p
			INNER JOIN account_realm_company arc USING (account_realm_id)
			INNER JOIN account a 
				ON a.account_realm_id = arc.account_realm_id
				AND a.company_id = arc.company_id
		WHERE   (p.company_id is NULL or arc.company_id = p.company_id)
			AND	a.person_id = NEW.person_id
			AND		p.site_code = NEW.site_code
			AND     property_type = 'auto_acct_coll'
			AND     property_name = 'site'
		;
	END IF;
	IF TG_OP = 'UPDATE' or TG_OP = 'DELETE' THEN
		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		)
		SELECT	p.account_collection_id, a.account_id, 'remove'
		FROM    property p
			INNER JOIN account_realm_company arc USING (account_realm_id)
			INNER JOIN account a 
				ON a.account_realm_id = arc.account_realm_id
				AND a.company_id = arc.company_id
		WHERE   (p.company_id is NULL or arc.company_id = p.company_id)
			AND	a.person_id = OLD.person_id
			AND		p.site_code = OLD.site_code
			AND     property_type = 'auto_acct_coll'
			AND     property_name = 'site'
		;
	END IF;
	--
	-- Remove rows from the temporary table that are in "remove" but not in
	-- "add".
	--
	DELETE FROM account_collection_account
	WHERE (account_collection_id, account_id) IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
		)
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'add'
	);

	--
	-- Add rows from the temporary table that are in 'add" but not "remove"
	-- "add".
	--
	INSERT INTO account_collection_account (
		account_collection_id, account_id)
	SELECT account_collection_id, account_id 
	FROM __automated_ac__
	WHERE direction = 'add'
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
	);

	DROP TABLE IF EXISTS __automated_ac__;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;

END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trig_automated_realm_site_ac_pl ON person_location;
CREATE TRIGGER trig_automated_realm_site_ac_pl 
	AFTER DELETE OR INSERT OR UPDATE OF site_code, person_id
	ON person_location 
	FOR EACH ROW 
	EXECUTE PROCEDURE automated_realm_site_ac_pl();
