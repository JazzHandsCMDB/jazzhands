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
		REVOKE ALL ON schema company_manip from public;
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
	company_id			company.company_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE,
	company_type		TEXT
) RETURNS void AS
$$
DECLARE
	_ar		account_realm.account_realm_name%TYPE;
	_csn	company.company_short_name%TYPE;
	_r		RECORD;
	_v		text[];
	i		text;
	_cc		company_collection.company_collection_id%TYPE;
	acname	account_collection.account_collection_name%TYPE;
	acid	account_collection.account_collection_id%TYPE;
	propv	text;
	tally	integer;
BEGIN

	PERFORM *
	FROM	account_realm_company arc
	WHERE	arc.company_id = add_auto_collections.company_id
	AND		arc.account_realm_id = add_auto_collections.account_realm_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Company and Account Realm are not associated together'
			USING ERRCODE = 'not_null_violation';
	END IF;

	PERFORM *
	FROM	company_type ct
	WHERE	ct.company_id = add_auto_collections.company_id
	AND		ct.company_type = add_auto_collections.company_type;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Company % is not of type %', company_id, company_type
			USING ERRCODE = 'not_null_violation';
	END IF;

	SELECT	company_collection_id
	INTO	_cc
	FROM	company_collection cc
			INNER JOIN company_collection_company ccc USING (company_collection_id)
	WHERE	cc.company_collection_type = 'per-company'
	AND		ccc.company_id = add_auto_collections.company_id;

	tally := 0;
	FOR _r IN SELECT	property_name, property_type,
						permit_company_collection_id
				FROM    property_name_collection_property_name pcp
				INNER JOIN property_name_collection pc
					USING (property_name_collection_id)
				INNER JOIN val_property vp USING (property_name,property_type)
				WHERE pc.property_name_collection_type = 'auto_ac_assignment'
				AND pc.property_name_collection_name = company_type
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
	FROM	account_realm ar
	WHERE	ar.account_realm_id = add_auto_collections.account_realm_id;

	SELECT	company_short_name
	INTO	_csn
	FROM	company c
	WHERE	c.company_id = add_auto_collections.company_id;

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
				company_collection_id, property_value
			) VALUES (
				_r.property_name, _r.property_type, account_realm_id,
				acid,
				_cc, propv
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
	company_id			company.company_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE,
	site_code			site.site_code%TYPE
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
	FROM	account_realm_company arc
	WHERE	arc.company_id = add_auto_collections_site.company_id
	AND		arc.account_realm_id = add_auto_collections_site.account_realm_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Company and Account Realm are not associated together'
			USING ERRCODE = 'not_null_violation';
	END IF;

	acname := concat(_ar, '_', site_code);

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
		'site', 'auto_acct_coll', add_auto_collections_site.account_realm_id,
		acid,
		add_auto_collections_site.site_code
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
	company_id			company.company_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	company_types		TEXT[]								DEFAULT NULL
) RETURNS integer AS
$$
DECLARE
	x		text;
	count	integer;
BEGIN
	count := 0;
	FOREACH x IN ARRAY company_types
	LOOP
		INSERT INTO company_type (company_id, company_type)
			VALUES (company_id, x);
		IF account_realm_id IS NOT NULL THEN
			PERFORM company_manip.add_auto_collections(
				company_id := company_id,
				account_realm_id := account_realm_id,
				company_type := x);
		END IF;
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
	company_name		TEXT,
	company_types		TEXT[]								DEFAULT NULL,
	parent_company_id	company.company_id%type			DEFAULT NULL,
	account_realm_id	account_realm.account_realm_id%type DEFAULT NULL,
	company_short_name	TEXT								DEFAULT NULL,
	description			TEXT								DEFAULT NULL

) RETURNS integer AS
$$
DECLARE
	_cmpid	company.company_id%type;
	_short	text;
	_isfam	boolean;
	_perm	text;
BEGIN
	IF company_types @> ARRAY['corporate family'] THEN
		_isfam := true;
	ELSE
		_isfam := false;
	END IF;
	IF company_short_name IS NULL and _isfam = true THEN
		_short := lower(regexp_replace(
				regexp_replace(
					regexp_replace(company_name,
						E'\\s+(ltd|sarl|limited|pt[ye]|GmbH|ag|ab|inc)',
						'', 'gi'),
					E'[,\\.\\$#@]', '', 'mg'),
				E'\\s+', '_', 'gi'));
	ELSE
		_short := company_short_name;
	END IF;

	BEGIN
		_perm := current_setting('jazzhands.permit_company_insert');
	EXCEPTION WHEN undefined_object THEN
		_perm := '';
	END;

	SET jazzhands.permit_company_insert = 'permit';

	INSERT INTO company (
		company_name, company_short_name,
		parent_company_id, description
	) VALUES (
		company_name, _short,
		parent_company_id, description
	) RETURNING company_id INTO _cmpid;

	SET jazzhands.permit_company_insert = _perm;

	IF account_realm_id IS NOT NULL THEN
		INSERT INTO account_realm_company (
			account_realm_id, company_id
		) VALUES (
			account_realm_id, _cmpid
		);
	END IF;

	IF company_types IS NOT NULL THEN
		PERFORM company_manip.add_company_types(
			company_id			:= _cmpid,
			account_realm_id	:= account_realm_id,
			company_types		:= company_types
		);
	END IF;

	RETURN _cmpid;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

--
-- purge the company from the database.  essentailly undoes add_company
-- and will fail if fk's have grown to it nd raise_exception is set to true
--
CREATE OR REPLACE FUNCTION company_manip.remove_company(
	company_id			company.company_id%type,
	raise_exception		boolean DEFAULT true
) RETURNS boolean AS
$$
BEGIN
	IF raise_exception THEN
		DELETE FROM company_type ct
		WHERE ct.company_id = remove_company.company_id;

		DELETE FROM account_realm_company arc
		WHERE arc.company_id = remove_company.company_id;

		DELETE FROM account_realm_company arc
		WHERE arc.company_id = remove_company.company_id;

		DELETE FROM company c
		WHERE c.company_id = remove_company.company_id;
	ELSE
		BEGIN
			DELETE FROM company_type ct
			WHERE ct.company_id = remove_company.company_id;

			DELETE FROM account_realm_company arc
			WHERE arc.company_id = remove_company.company_id;

			DELETE FROM account_realm_company arc
			WHERE arc.company_id = remove_company.company_id;

			DELETE FROM company c
			WHERE c.company_id = remove_company.company_id;
		EXCEPTION WHEN foreign_key_violation THEN
			RETURN false;
		END;
	END IF;
	RETURN true;
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
	company_id		company.company_id%type,
	site_code		site.site_code%type,
	physical_address_id	physical_address.physical_address_id%type,
	account_realm_id	account_realm.account_realm_id%type DEFAULT NULL,
	site_status		site.site_status%type DEFAULT 'ACTIVE',
	description		text DEFAULT NULL
) RETURNS void AS
$$
DECLARE
BEGIN
	INSERT INTO site (site_code, colo_company_id,
		physical_address_id, site_status,
		description
	) VALUES (
		add_location.site_code, add_location.company_id,
		add_location.physical_address_id, add_location.site_status,
		add_location.description
	);

	IF add_location.account_realm_id IS NOT NULL THEN
		PERFORM company_manip.add_auto_collections_site(
			company_id 	:= add_location.company_id,
			account_realm_id := add_location.account_realm_id,
			site_code := add_location.site_code
		);
	END IF;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

------------------------------------------------------------------------------
------------------------------------------------------------------------------
--
-- These all exist for backwards compatibility.  Note that their existance
-- breaks positional arguments.
--
------------------------------------------------------------------------------
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION company_manip.add_auto_collections(
	_company_id			company.company_id%type,
	_account_realm_id	account_realm.account_realm_id%type,
	_company_type			TEXT,
	will_soon_be_dropped	boolean DEFAULT true
) RETURNS void AS
$$
BEGIN
	PERFORM company_manip.add_auto_collections(
		company_id := _company_id,
		account_realm_id := _account_realm_id,
		company_type := _company_type
	);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY INVOKER;


------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION company_manip.add_auto_collections_site(
        _company_id             company.company_id%type,
        _account_realm_id       account_realm.account_realm_id%type,
        _site_code              site.site_code%type,
	will_soon_be_dropped	boolean DEFAULT true
) RETURNS void AS
$$
BEGIN
	PERFORM company_manip.add_auto_collections_site(
		company_id := _company_id,
		account_realm_id := _account_realm_id,
		site_code := _site_code
	);

END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY INVOKER;

------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION company_manip.add_company_types(
        _company_id             company.company_id%type,
        _account_realm_id       account_realm.account_realm_id%type,
        _company_types 			TEXT[],
		will_soon_be_dropped	BOOLEAN DEFAULT true
) RETURNS integer AS
$$
BEGIN
	RETURN company_manip.add_company_types(
		company_id			:= _company_id,
		account_realm_id	:= _account_realm_id,
		company_types		:= _company_types
	);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY INVOKER;

CREATE OR REPLACE FUNCTION company_manip.add_company(
	_company_name		TEXT,
	_company_types		TEXT[]							DEFAULT NULL,
	_parent_company_id	company.company_id%type			DEFAULT NULL,
	_account_realm_id	account_realm.account_realm_id%type DEFAULT NULL,
	_company_short_name	TEXT							DEFAULT NULL,
	_description			TEXT						DEFAULT NULL,
	will_soon_be_dropped	boolean DEFAULT true
) RETURNS integer AS
$$
BEGIN
	RETURN company_manip.add_company(
		company_name		:= _company_name,
		company_types		:= _company_types,
		parent_company_id	:= _parent_company_id,
		account_realm_id	:= _account_realm_id,
		company_short_name	:= _company_short_name,
		description			:= _description
	);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY INVOKER;

------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION company_manip.remove_company(
        _company_id     company.company_id%type,
        raise_exception			BOOLEAN DEFAULT true,
		will_soon_be_dropped	BOOLEAN DEFAULT true
) RETURNS boolean AS
$$
BEGIN
	RETURN company_manip.remove_company(
        company_id		:= _company_id,
        raise_exception := raise_exception
	);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY INVOKER;

--
-- backwards compatible version that needs to be dropped
--
CREATE OR REPLACE FUNCTION company_manip.add_location(
        _company_id             company.company_id%type,
        _site_code              site.site_code%type,
        _physical_address_id    physical_address.physical_address_id%type,
        _account_realm_id       account_realm.account_realm_id%type DEFAULT NULL,
        _site_status            site.site_status%type DEFAULT 'ACTIVE',
        _description            text DEFAULT NULL,
	will_soon_be_dropped	boolean DEFAULT true
) RETURNS void AS
$$
BEGIN
	PERFORM company_manip.add_location(
		company_id := _company_id,
		site_code := _site_code,
		physical_address_id := _physical_address_id,
		account_realm_id := _account_realm_id,
		site_status := _site_status,
		description := _description
	);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY INVOKER;

------------------------------------------------------------------------------
------------------------------------------------------------------------------
--
-- End of backwards compatibility
--
------------------------------------------------------------------------------
------------------------------------------------------------------------------

REVOKE ALL ON schema company_manip from public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA company_manip from public;

GRANT USAGE ON SCHEMA company_manip to iud_role;
GRANT SELECT ON ALL TABLES IN SCHEMA company_manip to iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA company_manip to iud_role;

