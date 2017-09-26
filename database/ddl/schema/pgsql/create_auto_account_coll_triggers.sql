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


	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE'  THEN
		PERFORM auto_ac_manip.make_site_acs_right(NEW.account_id);
		PERFORM auto_ac_manip.make_personal_acs_right(NEW.account_id);

		-- update the person's manager to match
		WITH RECURSIVE map AS (
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
					account_realm_id := NEW.account_realm_id,
					login := manager_login)
				FROM map
				WHERE root_account_id = NEW.account_id
			) SELECT count(*) INTO _tally FROM x;
	END IF;

	IF TG_OP = 'UPDATE'  THEN
		PERFORM auto_ac_manip.make_site_acs_right(OLD.account_id);
		PERFORM auto_ac_manip.make_personal_acs_right(OLD.account_id);
	END IF;

	-- when deleting, do nothing rather than calling the above, same as
	-- update; pointless because account is getting deleted anyway.

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
	AFTER INSERT
	OR UPDATE OF account_type, account_role, account_status
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
RAISE NOTICE '1';
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
RAISE NOTICE '2';
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
RAISE NOTICE '2a';
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
RAISE NOTICE '3: %', OLD;
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_company USING (person_id,company_id)
		WHERE	account_role = 'primary'
		AND		person_id = OLD.person_id
		AND		company_id = OLD.company_id;
	END IF;
	IF ( TG_OP = 'UPDATE' AND  (
			OLD.person_id IS DISTINCT FROM NEW.person_id OR
			OLD.company_id IS DISTINCT FROM NEW.company_id )
		) THEN
RAISE NOTICE '4: %', NEW;
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_company USING (person_id,company_id)
		WHERE	account_role = 'primary'
		AND		person_id = NEW.person_id
		AND		company_id = NEW.company_id;
	END IF;

RAISE NOTICE '5';
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
DROP TRIGGER IF EXISTS trigger_z_automated_ac_on_person_company 
	ON person_company;
CREATE TRIGGER trigger_z_automated_ac_on_person_company
	AFTER UPDATE OF is_management, is_exempt, is_full_time, person_id,company_id,
		manager_person_id
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
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_location USING (person_id)
		WHERE	account_role = 'primary'
		AND		person_id = NEW.person_id;
	END IF;

	IF TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_location USING (person_id)
		WHERE	account_role = 'primary'
		AND		person_id = OLD.person_id;
	END IF;
	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;

END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------------
--
-- If someone moves location, update the site if something appropriate exists
--
--
CREATE OR REPLACE FUNCTION automated_realm_site_ac_pl()
RETURNS TRIGGER AS $_$
DECLARE
	_tally	INTEGER;
BEGIN
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		PERFORM	auto_ac_manip.make_site_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_location USING (person_id)
		WHERE	account_role = 'primary'
		AND		person_id = NEW.person_id;
	END IF;

	IF TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN
		PERFORM	auto_ac_manip.make_site_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_location USING (person_id)
		WHERE	account_role = 'primary'
		AND		person_id = OLD.person_id;
	END IF;

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
