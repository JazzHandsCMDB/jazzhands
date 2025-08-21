-- Copyright (c) 2023-2025 Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

\set ON_ERROR_STOP


DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'authorization_utils';
        IF _tal = 0 THEN
			DROP SCHEMA IF EXISTS authorization_utils;
			CREATE SCHEMA authorization_utils AUTHORIZATION jazzhands;
			COMMENT ON SCHEMA authorization_utils IS 'part of jazzhands';

			REVOKE ALL on ALL FUNCTIONS IN SCHEMA authorization_utils FROM public;
			REVOKE ALL on SCHEMA authorization_utils FROM public;
			GRANT USAGE ON SCHEMA authorization_utils TO ro_role;
			GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA authorization_utils TO ro_role;
        END IF;
END;
$$;

---
--- given a json blob sort of like:
---
--- {
--- 	"property_role":	"property_type:property_name"
--- 	"login":			"login",		// pick one or the other
--- 	"account_id":		id
--- 	"device_name":		"name"
--- 	"device_id":		id				// optional, one or the other
--- 	"account_realm_id": id				// has default, one or the other
--- 	"account_realm_name": id
---		"property_value": text				// if set, must be this value
---		"service_name": "Vv" // if set, limits lhs to a purpose of this service name
---		"service_collection_purpose": "Vv" // default to current
---		"service_namespace": "Vv" // if not set, uses "default"
---		"auth_use_value": boolean				// indicates that the perm is assigned on rhs not lhs
--- }
---
--- retruns true or falsA
---
--- raises an exception when things that should exist aren't.  (possibly should
--- become a flag)
CREATE OR REPLACE FUNCTION authorization_utils.check_property_account_authorization(
	parameters	JSONB
) RETURNS boolean
AS $$
DECLARE
	_tally	INTEGER;
	_arid	account_realm.account_realm_id%type;
	_aid	account_realm.account_realm_id%type;
	_q		TEXT;
	_iq		TEXT[];
	_r		RECORD;
	_authz_col	TEXT;
BEGIN
	IF parameters?'login' AND parameters?'account_id' THEN
		RAISE EXCEPTION 'Must specify either login or account_id, not both.'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	IF NOT parameters?'login' AND NOT parameters?'account_id' THEN
		RAISE EXCEPTION 'Must specify one of login or account_id, not both.'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	IF parameters?'device_id' OR parameters?'device_name' THEN
		RAISE EXCEPTION 'Device support not implemented yet, but should be.'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	IF NOT parameters?'property_role' THEN
		RAISE EXCEPTION 'Must specify property role'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	--
	-- determines if the account collection with the user to check is on the
	-- lhs (false) or rhs (true)
	--
	IF (NOT parameters?'auth_use_value' OR NOT (parameters->>'auth_use_value')::boolean )
	THEN
		_authz_col := 'account_collection_id';
	ELSE
		_authz_col := 'property_value_account_collection_id';

	END IF;

	IF parameters?'account_realm_id' AND parameters?'account_realm_name' THEN
		RAISE EXCEPTION
			'Must specify either account_realm_id or account_realm_name'
			USING ERRCODE = 'invalid_parameter_value';
	ELSIF parameters?'account_realm_id' THEN
		_arid := parameters->>'account_realm_id';
	ELSIF parameters?'account_realm_name' THEN
		SELECT	account_realm_id
		INTO	_arid
		WHERE	account_realm_name IS NOT DISTINCT FROM
			parameters->>'account_realm_name';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'account_realm % not found',
				parameters->>'account_realm_name'
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	ELSE
		SELECT	account_realm_id
		INTO	_arid
		FROM	property
		WHERE	property_type = 'Defaults'
		AND		property_name = '_root_account_realm_id';
	END IF;

	IF parameters?'account_id' AND parameters?'login' THEN
		RAISE EXCEPTION
			'Must specify either account_id or login'
			USING ERRCODE = 'invalid_parameter_value';
	ELSIF parameters?'account_id' THEN
		_aid := parameters->>'account_id';
	ELSIF parameters?'login' THEN
		SELECT	account_id
		INTO	_aid
		FROM	account
		WHERE	login IS NOT DISTINCT FROM parameters->>'login'
		AND		account_realm_id = _arid;
	ELSE
		RAISE EXCEPTION 'must specify a user to check for'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	-- now getting into the weirder things.
	IF NOT parameters?'service_name' THEN
		IF parameters?'service_collection_purpose' THEN
			RAISE EXCEPTION 'must set service_name if using service_collection_purpose'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF parameters?'service_namespace' THEN
			RAISE EXCEPTION 'must set service_name if using service_namespace'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSE
		_iq := array_append(_iq, format($str$ (
			service_version_collection_id IN (
				SELECT root_service_version_collection_id
				FROM	jazzhands_cache.ct_service_version_collection_hier_recurse
						JOIN service_version_collection_purpose
							USING (service_version_collection_id)
						JOIN service USING (service_id)
						JOIN val_service_type USING (service_type)
						JOIN val_service_namespace USING (service_namespace)
				WHERE	service_name = '%s'
				AND		service_namespace = '%s'
				AND		service_version_collection_purpose = '%s'

			) ) $str$,
			parameters->>'service_name',
			COALESCE(parameters->>'service_namespace', 'default'),
			COALESCE(parameters->>'service_collection_purpose', 'current')
		));
	END IF;


	--
	-- The basic version of this looks for a given account_id (which may be
	-- set by login or account_id) and an account_realm (which has a default)
	-- and sees if it is part of the an account collection on the lhs of ra
	-- property with propety_role set to property_type:proeprty_name .
	--
	-- It is possible to extend the rhs of property by adding values to _iq
	-- (above) that futher restricted by various bits in the incoming json.
	--
	-- These will likely be fleshed out over time.

	_q := format($str$SELECT count(*) FROM (
		SELECT
			p.%s,
			property_type,
			property_name,
			property_value
		FROM (
			SELECT
				r.root_account_collection_id AS %s,
				aca.account_id
			FROM
				jazzhands_cache.ct_account_collection_hier_recurse r
				JOIN jazzhands.account_collection_account aca
					USING (account_collection_id)
		) ia
		JOIN jazzhands.account a USING (account_id)
		JOIN property p USING (%s)
		WHERE
			property_type = split_part($1, ':', 1)
			AND property_name = split_part($1, ':', 2)
			AND a.account_id = $2
			AND a.account_realm_Id = $3
			AND ($4 IS NULL OR p.property_value = $4 )
		%s
		); $str$,
			_authz_col,
			_authz_col,
			_authz_col,
			CASE WHEN _iq IS NULL THEN ''
			ELSE concat(' AND ', array_to_string(_iq, ' AND '))
			END -- CASE
	);

	EXECUTE _q INTO _tally USING
		parameters->>'property_role',
		_aid,
		_arid,
		parameters->>'property_value';

	tIF _tally > 0 THEN
		RETURN true;
	END IF;

	RETURN false;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

--
-- Check if an fqdn is in a dns_domain_collection.  returns true/false;
--
-- If raise_exception, on unknown domain will raise foreign_key_violation
-- exception, otherwise returns false
--
CREATE OR REPLACE FUNCTION authorization_utils.check_dns_name_role(
	property_role	TEXT,
	fqdn			TEXT,
	raise_exception	BOOLEAN DEFAULT false
) RETURNS boolean AS $$
DECLARE
	_j		JSONB;
	_did	INTEGER;
BEGIN
	SELECT dns_utils.find_dns_domain_from_fqdn(fqdn) INTO _j;

	IF _j IS NULL THEN
		IF raise_exception THEN
			RAISE EXCEPTION '% maps to an unknown dns domain', fqdn
				USING ERRCODE = 'foreign_key_violation';
		ELSE
			RETURN false;
		END IF;
	END IF;

	PERFORM *
	FROM jazzhands.property
		JOIN jazzhands.dns_domain_collection USING (dns_domain_collection_id)
		JOIN jazzhands.dns_domain_collection_dns_domain USING (dns_domain_collection_id)
	WHERE dns_domain_id = CAST(_j->>'dns_domain_id' AS integer)
		AND property_type = split_part(property_role, ':', 1)
		AND property_name = split_part(property_role, ':', 2);

	IF FOUND THEN
		RETURN true;
	END IF;

	RETURN false;
END;
$$ SET search_path = jazzhands
LANGUAGE plpgsql SECURITY DEFINER;


--
-- Checks to see if an IP is associated with a device either via direct
-- assignment on an interface or via shared_network.
--
-- If raise_exception, on unknown device_name will raise foreign_key_violation
-- exception, otherwise returns false
--
CREATE OR REPLACE FUNCTION authorization_utils.check_device_ip_address(
	ip_address	INET,
	device_id		device.device_id%TYPE		DEFAULT NULL,
	device_name		device.device_name%TYPE		DEFAULT NULL,
	raise_exception	boolean						DEFAULT false
) RETURNS boolean AS $$
DECLARE
	_in_ip		ALIAS FOR ip_address;
	_in_dname	ALIAS FOR device_name;
	_did		device.device_id%TYPE;
BEGIN
	IF device_id IS NOT NULL AND device_name IS NOT NULL THEN
		RAISE EXCEPTION 'Must specify only either device_id or device-name'
			USING ERRCODE = 'invalid_parameter_value';
	ELSIF device_id IS NOT NULL THEN
		_did := device_Id;
	ELSIF device_name IS NOT NULL THEN
		SELECT	d.device_id
		INTO	_did
		FROM	device d
		WHERE	d.device_name IS NOT DISTINCT FROM _in_dname;

		IF NOT FOUND THEN
			IF raise_exception THEN
				RAISE EXCEPTION 'Unknown device %', _in_dname
					USING ERRCODE = 'foreign_key_violation';
			ELSE
				RETURN false;
			END IF;
		END IF;
	ELSE
		RAISE EXCEPTION 'Must specify either a device id or name'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	PERFORM * FROM (
		SELECT n.ip_address, lin.device_id
		FROM
			jazzhands.netblock n
			JOIN jazzhands.layer3_interface_netblock lin USING (netblock_id)
		UNION
		SELECT n.ip_address, l3i.device_id
		FROM jazzhands.netblock n
			JOIN jazzhands.shared_netblock USING (netblock_id)
			JOIN jazzhands.shared_netblock_layer3_interface
				USING (shared_netblock_id)
			JOIN jazzhands.layer3_interface l3i USING (layer3_interface_Id)
	) alltheips
	WHERE host(alltheips.ip_address) = host(_in_ip)
	AND alltheips.device_Id = _did;

	IF FOUND THEN
		RETURN true;
	END IF;

	RETURN false;
END;
$$ SET search_path = jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON SCHEMA authorization_utils FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA authorization_utils FROM public;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA authorization_utils TO ro_role;
