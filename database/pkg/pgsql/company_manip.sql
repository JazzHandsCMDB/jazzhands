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

/*
 * $Id$
 */

\set ON_ERROR_STOP

-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'company_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS company_manip;
		CREATE SCHEMA company_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA company_manip IS 'part of jazzhands';
	END IF;
END;
$$;

------------------------------------------------------------------------------

--
-- account realm is here because its possible for companies to be part of
-- multiple account realms.
--

--
-- sets up the automated account collections.  This assumes some carnal
-- knowledge of some of the types.
--
-- This is typically only called from add_company.
--
-- note that there is no 'remove_auto_collections'
--
CREATE OR REPLACE FUNCTION company_manip.add_auto_collections(
	_company_id		company.company_id%type,
	_account_realm_id	account_realm.account_realm_id%type,
	_company_type	text
) RETURNS void AS
$$
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
				WHERE property_collection_type = 'auto_ac_assignment'
				AND property_collection_name = _company_type
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
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

--
-- add site based automated account collections for the given realm to be
-- automanaged by trigger.
--
-- NOTE:  There is no remove_auto_collections_site.
--
CREATE OR REPLACE FUNCTION company_manip.add_auto_collections_site(
	_company_id		company.company_id%type,
	_account_realm_id	account_realm.account_realm_id%type,
	_site_code		site.site_code%type
) RETURNS void AS
$$
DECLARE
	_ar		account_realm.account_realm_name%TYPE;
	_csn	company.company_short_name%TYPE;
	acname	account_collection.account_collection_name%TYPE;
	acid	account_collection.account_collection_id%TYPE;
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

	acname := concat(_ar, '_', _site_code);

	INSERT INTO account_collection (
		account_collection_name, account_collection_type
	) VALUES (
		acname, 'automated'
	) RETURNING account_collection_id INTO acid;

	INSERT INTO property (
		property_name, property_type, account_realm_id,
		account_collection_id,
		site_code
	) VALUES (
		'site', 'auto_acct_coll', _account_realm_id,
		acid,
		_site_code
	);
	tally := tally + 1;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;



------------------------------------------------------------------------------

--
-- addds company types to company, and sets up any automated classes
-- associated via company_manip.add_auto_collections.
--
-- note that there is no 'remove_company_types'
--
CREATE OR REPLACE FUNCTION company_manip.add_company_types(
	_company_id		company.company_id%type,
	_account_realm_id	account_realm.account_realm_id%type DEFAULT NULL,
	_company_types	text[] default NULL
) RETURNS integer AS
$$
DECLARE
	x		text;
	count	integer;
BEGIN
	count := 0;
	FOREACH x IN ARRAY _company_types
	LOOP
		INSERT INTO company_type (company_id, company_type)
			VALUES (_company_id, x);
		PERFORM company_manip.add_auto_collections(_company_id, _account_realm_id, x);
		count := count + 1;
	END LOOP;
	return count;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

------------------------------------------------------------------------------

--
-- primary interface to add things to the company table.  It does other
-- necessary manipulations based on company types.
--
-- shortname is inferred if not set
--
-- NOTE: There is no remove_company.
--
CREATE OR REPLACE FUNCTION company_manip.add_company(
	_company_name		text,
	_company_types		text[] default NULL,
	_parent_company_id	company.company_id%type DEFAULT NULL,
	_account_realm_id	account_realm.account_realm_id%type DEFAULT NULL,
	_company_short_name	text DEFAULT NULL,
	_description		text DEFAULT NULL

) RETURNS integer AS
$$
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
	END IF;

	INSERT INTO company (
		company_name, company_short_name, is_corporate_family,
		parent_company_id, description
	) VALUES (
		_company_name, _short, _isfam,
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
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

------------------------------------------------------------------------------
--
-- Adds a location to a company with the given site code and address.  It will
-- take are of any automated account collections that are needed.
--
-- NOTE: There is no remove_location.
--
CREATE OR REPLACE FUNCTION company_manip.add_location(
	_company_id		company.company_id%type,
	_site_code		site.site_code%type,
	_physical_address_id	physical_address.physical_address_id%type,
	_account_realm_id	account_realm.account_realm_id%type DEFAULT NULL,
	_site_status		site.site_status%type DEFAULT 'ACTIVE',
	_description		text DEFAULT NULL
) RETURNS void AS
$$
DECLARE
BEGIN
	INSERT INTO site (site_code, colo_company_id,
		physical_address_id, site_status, description
	) VALUES (
		_site_code, _company_id,
		_physical_address_id, _site_status, _description
	);

	if _account_realm_id IS NOT NULL THEN
		PERFORM company_manip.add_auto_collections_site(
			_company_id,
			_account_realm_id,
			_site_code
		);
	END IF;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;
