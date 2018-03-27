/*
 * Copyright (c) 2016 Todd Kover
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
 * $Id$
 */

-- Scripts to streamline addition/removal of people from account collections
-- This is primarily used by triggers

-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'account_collection_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS account_collection_manip;
		CREATE SCHEMA account_collection_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA account_collection_manip IS 'part of jazzhands';
	END IF;
END;
$$;


-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION account_collection_manip.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id$ -->');
END;
$$ LANGUAGE plpgsql;
-- end of procedure id_tag
-------------------------------------------------------------------

--
-- adds a user to an account collection if they are not already there
--
CREATE OR REPLACE FUNCTION account_collection_manip.manip_membership(
	account_collection_name	account_collection.account_collection_name%TYPE,
	account_collection_type	account_collection.account_collection_type%TYPE,
	account_id				account.account_id%TYPE,
	is_member				boolean
) RETURNS boolean AS
$$
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
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION account_collection_manip.manip_membership(
	account_collection_name	account_collection.account_collection_name%TYPE,
	account_collection_type	account_collection.account_collection_type%TYPE,
	account_id				account.account_id%TYPE,
	is_member				integer
) RETURNS boolean AS
$$
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
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION account_collection_manip.manip_membership(
	account_collection_name	account_collection.account_collection_name%TYPE,
	account_collection_type	account_collection.account_collection_type%TYPE,
	account_id				account.account_id%TYPE,
	is_member				char(1)
) RETURNS boolean AS
$$
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
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------------------
--
-- Used to purge accounts from account from account collections when the
-- members have been terminated for more than an interval.
--
-- The default is a year, but its possible to pass in an interval or set up
-- a system wide default.
--
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION account_collection_manip.cleanup_account_collection_account (
	lifespan	INTERVAL DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
	rv	INTEGER;
BEGIN
	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_collection_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		lifespan := '1 year'::interval;
	END IF;

	--
	-- It is possible that this will fail if there are surprise foreign
	-- keys to the accounts.
	--
	EXECUTE '
		WITH x AS (
			SELECT account_collection_id, account_id
			FROM    account a
				JOIN account_collection_account aca USING (account_id)
				JOIN account_collection ac USING (account_collection_id)
				JOIN person_company pc USING (person_id, company_id)
			WHERE   pc.termination_date IS NOT NULL
			AND     pc.termination_date < now() - $1::interval
			AND     account_collection_type != $2
			AND
				(account_collection_id, account_id)  NOT IN
					( SELECT unix_group_acct_collection_id, account_id from
						account_unix_info)
			) DELETE FROM account_collection_account aca
			WHERE (account_collection_id, account_id) IN
				(SELECT account_collection_id, account_id FROM x)
		' USING lifespan, 'per-account';
	GET DIAGNOSTICS rv = ROW_COUNT;
	RETURN rv;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------------------
--
-- generic routine to cleanup account collections assigned to department
-- maintains them.
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION account_collection_manip.purge_inactive_department_properties(
	property_type	property.property_type%TYPE,
	property_name	property.property_name%TYPE DEFAULT NULL,
	lifespan	INTERVAL DEFAULT NULL,
	raise_exception	boolean DEFAULT true
) RETURNS INTEGER AS $$
DECLARE
	_r	RECORD;
	rv	INTEGER;
	i	INTEGER;
	_pn	TEXT;
	_pt TEXT;
BEGIN
	_pn := property_name;
	_pt := property_type;
	rv := 0;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_collection_purge_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;
	IF lifespan IS NULL THEN
		lifespan := '1 year'::interval;
	END IF;

	--
	-- delete login assignment to linux machines for departments that are
	-- disabled and not in use
	--
	FOR _r IN SELECT	p.property_id
			FROM	account_collection ac
				JOIN department d USING (account_collection_id)
				JOIN property p USING (account_collection_id)
			WHERE 	d.is_active = 'N'
			AND ((_pn IS NOT NULL AND _pn = p.property_name) OR _pn IS NULL )
			AND	p.property_type = _pt
			AND	account_collection_id NOT IN (
					SELECT child_account_collection_id
					FROM account_collection_hier
				)
			AND	account_collection_id NOT IN (
					SELECT account_collection_id
					FROM account_collection_account
				)
	LOOP
		BEGIN
			DELETE FROM property
			WHERE property_id = _r.property_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;


	--
	-- delete unix group overrides to linux machines for departments that are
	-- disabled and not in use
	--
	FOR _r IN SELECT	p.property_id
			FROM	account_collection ac
				JOIN department d USING (account_collection_id)
				JOIN property p ON p.property_value_account_coll_id =
					ac.account_collection_id
			WHERE 	d.is_active = 'N'
			AND ((_pn IS NOT NULL AND _pn = p.property_name) OR _pn IS NULL )
			AND	p.property_type = _pt
			AND	p.property_value_account_coll_id NOT IN (
					SELECT child_account_collection_id
					FROM account_collection_hier
				)
			AND	p.property_value_account_coll_id NOT IN (
					SELECT account_collection_id
					FROM account_collection_account
				)
	LOOP
		BEGIN
			DELETE FROM property
			WHERE property_id = _r.property_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	RETURN rv;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;;

--------------------------------------------------------------------------------
--
-- Used to purge inactive departments from various places where the database
-- maintains them
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION account_collection_manip.purge_inactive_departments(
	lifespan	INTERVAL DEFAULT NULL,
	raise_exception	boolean DEFAULT true
) RETURNS INTEGER AS $$
DECLARE
	_r	RECORD;
	rv	INTEGER;
	i	INTEGER;
BEGIN
	rv := 0;
	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_collection_purge_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;
	IF lifespan IS NULL THEN
		lifespan := '1 year'::interval;
	END IF;

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'UnixLogin',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'MclassUnixProp',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'StabRole',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'Defaults',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'API',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'DeviceInventory',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'PhoneDirectoryAttributes',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	--
	-- remove child account collection membership
	--
	FOR _r IN SELECT	ac.*
			FROM	account_collection ac
				JOIN department d USING (account_collection_id)
			WHERE	d.is_active = 'N'
			AND	account_collection_id IN (
				SELECT child_account_collection_id FROM account_collection_hier
			)
	LOOP
		BEGIN
			DELETE FROM account_collection_hier
				WHERE child_account_collection_id = _r.account_collection_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	RETURN rv;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------------------
--
-- Used to purge account collections that are empty from children account
-- collections if they have no properties assigned.  Since container-only
-- account collections should have properties attached, if it fails to
-- delete, it means its attached elsewhere.  properties are skipped because
-- they are obvious.
--
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION account_collection_manip.purge_inactive_account_collections(
	lifespan	INTERVAL DEFAULT NULL,
	raise_exception	boolean DEFAULT true
) RETURNS INTEGER AS $$
DECLARE
	_r	RECORD;
	i	INTEGER;
	rv	INTEGER;
BEGIN
	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_collection_purge_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;
	IF lifespan IS NULL THEN
		lifespan := '1 year'::interval;
	END IF;

	--
	-- remove unused account collections
	--
	rv := 0;
	FOR _r IN
		SELECT ac.*
		FROM	account_collection ac
			JOIN val_account_collection_type act USING (account_collection_type)
		WHERE	now() -
			coalesce(ac.data_upd_date,ac.data_ins_date) > lifespan::interval
		AND	act.is_infrastructure_type = 'N'
		AND	account_collection_id NOT IN
			(SELECT child_account_collection_id FROM account_collection_hier)
		AND	account_collection_id NOT IN
			(SELECT account_collection_id FROM account_collection_hier)
		AND	account_collection_id NOT IN
			(SELECT account_collection_id FROM account_collection_account)
		AND	account_collection_id NOT IN
			(SELECT account_collection_id FROM property
				WHERE account_collection_id IS NOT NULL)
		AND	account_collection_id NOT IN
			(SELECT property_value_account_coll_id FROM property
				WHERE property_value_account_coll_id IS NOT NULL)
	LOOP
		BEGIN
			DELETE FROM account_collection
				WHERE account_collection_id = _r.account_collection_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	RETURN rv;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

grant select on all tables in schema account_collection_manip to iud_role;
grant usage on schema account_collection_manip to iud_role;
revoke all on schema account_collection_manip from public;
revoke all on  all functions in schema account_collection_manip from public;
grant execute on all functions in schema account_collection_manip to iud_role;

