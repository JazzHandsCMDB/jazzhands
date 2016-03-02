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

grant select on all tables in schema account_collection_manip to iud_role;
grant usage on schema account_collection_manip to iud_role;
revoke all on schema account_collection_manip from public;
revoke all on  all functions in schema account_collection_manip from public;
grant execute on all functions in schema account_collection_manip to iud_role;

