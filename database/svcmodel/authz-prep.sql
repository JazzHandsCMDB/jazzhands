--
-- this should be the authz schema owner (and there will be a bunch more
-- other grants
--
\set ON_ERROR_STOP 
GRANT REFERENCES on maestro.application TO jazzhands; 

DROP SCHEMA IF EXISTS authorization_policy CASCADE;
DROP SCHEMA IF EXISTS vault_policy CASCADE;
DROP SCHEMA IF EXISTS authz_test CASCADE;

DO $$
BEGIN
	REVOKE ALL ON ALL TABLES IN SCHEMA jazzhands FROM authorization_policy;
	REVOKE ALL ON ALL TABLES IN SCHEMA maestro FROM authorization_policy;

	REVOKE ALL ON ALL TABLES IN SCHEMA jazzhands FROM authorization_policy;
	REVOKE ALL ON ALL TABLES IN SCHEMA jazzhands FROM vault_policy;
	REVOKE ALL ON ALL TABLES IN SCHEMA maestro FROM vault_policy;

	REVOKE ALL ON ALL TABLES IN SCHEMA jazzhands FROM authz_test;
	REVOKE ALL ON ALL TABLES IN SCHEMA maestro FROM authz_test;
EXCEPTION WHEN invalid_schema_name OR undefined_object THEN NULL;

END;
$$;

DO $$
BEGIN
	REVOKE USAGE ON SCHEMA authorization_policy FROM vault_policy;
EXCEPTION WHEN invalid_schema_name OR undefined_object THEN NULL;
END;
$$;

DO $$
BEGIN
	REVOKE USAGE ON SCHEMA authorization_policy FROM authz_test;
EXCEPTION WHEN invalid_schema_name OR undefined_object THEN NULL;
END;
$$;

DO $$
BEGIN
	REVOKE USAGE on schema jazzhands FROM authorization_policy;
	REVOKE USAGE on schema jazzhands FROM vault_policy;
	REVOKE USAGE on schema jazzhands FROM authz_test;

	REVOKE ALL ON ALL TABLES IN SCHEMA maestro FROM authorization_policy;
	REVOKE USAGE ON schema maestro FROM authorization_policy;

	REVOKE USAGE ON schema jazzhands FROM authorization_policy;

	REVOKE pgcrypto_roles FROM authorization_policy;
	REVOKE pgcrypto_roles FROM vault_policy;
EXCEPTION WHEN invalid_schema_name OR undefined_object THEN NULL;
END;
$$;

DROP USER IF EXISTS authorization_policy;
DROP USER IF EXISTS vault_policy;
DROP USER IF EXISTS authz_test;

--

CREATE USER authorization_policy IN GROUP schema_owners;
CREATE USER vault_policy IN GROUP schema_owners;
CREATE USER authz_test IN GROUP schema_owners;

ALTER USER authorization_policy SET search_path=authorization_policy;
ALTER USER vault_policy SET search_path=vault_policy;
ALTER USER authz_test SET search_path=vault_policy;

CREATE SCHEMA authorization_policy AUTHORIZATION authorization_policy;
CREATE SCHEMA vault_policy AUTHORIZATION vault_policy;
CREATE SCHEMA authz_test AUTHORIZATION  authz_test;

ALTER USER authorization_policy SET search_path=authorization_policy;
ALTER USER vault_policy SET search_path=vault_policy;
ALTER USER authz_test SET search_path=authz_test;

GRANT pgcrypto_roles TO authorization_policy;
GRANT pgcrypto_roles TO vault_policy;

GRANT USAGE ON schema jazzhands TO authorization_policy;
GRANT USAGE ON schema jazzhands TO vault_policy;
GRANT REFERENCES,SELECT,INSERT ON jazzhands.val_property TO authorization_policy;
GRANT REFERENCES,SELECT,INSERT ON jazzhands.property TO authorization_policy;
GRANT REFERENCES,SELECT,INSERT ON jazzhands.account_collection TO authorization_policy;
GRANT REFERENCES,SELECT,INSERT ON jazzhands.device_collection TO authorization_policy;
GRANT REFERENCES,SELECT,INSERT ON jazzhands.unix_group TO authorization_policy;
GRANT REFERENCES,SELECT,INSERT ON jazzhands.account TO authorization_policy;

GRANT USAGE ON schema maestro TO authorization_policy;
GRANT REFERENCES,SELECT ON maestro.application TO authorization_policy;

GRANT REFERENCES,SELECT on jazzhands.device_collection TO vault_policy;
GRANT REFERENCES,SELECT on jazzhands.account_collection TO vault_policy;
GRANT REFERENCES,SELECT on jazzhands.account TO vault_policy;

GRANT USAGE ON SCHEMA authorization_policy TO vault_policy;
GRANT USAGE ON SCHEMA authorization_policy TO authz_test;

GRANT USAGE ON schema jazzhands TO authz_test;
GRANT SELECT ON jazzhands.device_collection TO authz_test;
GRANT SELECT ON jazzhands.device_collection_device TO authz_test;
GRANT SELECT ON jazzhands.device TO authz_test;

-- === === === === === === === === === === === === === === === === === ===

DELETE FROM jazzhands.val_property WHERE
	property_type IN ('authorization-mappings', 'database-grants');

DELETE FROM jazzhands.val_property_type WHERE
	property_type IN ('authorization-mappings', 'database-grants');

INSERT INTO jazzhands.val_property_type (
	property_type,
	description
) VALUES (
	'authorization-mappings',
	'prototype authorization mappings for authz schema'
);

INSERT INTO jazzhands.val_property (
	property_name,
	property_type,
	permit_device_collection_id,
	device_collection_type,
	is_multivalue,
	property_data_type
) VALUES (
	'mclass-authorization-map',
	'authorization-mappings',
	'REQUIRED',
	'mclass',
	'Y',
	'none'
);

INSERT INTO jazzhands.val_property (
	property_name,
	property_type,
	is_multivalue,
	property_data_type
) VALUES (
	'application-authorization-map',
	'authorization-mappings',
	'Y',
	'none'
);

INSERT INTO jazzhands.val_property (
	property_name,
	property_type,
	is_multivalue,
	property_data_type
) VALUES (
	'application-kubernetes-map',
	'authorization-mappings',
	'Y',
	'none'
);

-- === === === === === === === === === === === === === === === === === ===

INSERT INTO jazzhands.val_property_type (
	property_type,
	description
) VALUES (
	'database-grants',
	'nuff said'
);

INSERT INTO jazzhands.val_property (
	property_name,
	property_type,
	property_data_type,
	is_multivalue
) VALUES (
	'object-grants',
	'database-grants',
	'string',
	'Y'
);

-- === === === === === === === === === === === === === === === === === ===
