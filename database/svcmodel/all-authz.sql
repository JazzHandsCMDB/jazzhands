
\set ON_ERROR_STOP
\pset pager off

\c :DBNAME authorization_policy

begin;
SET search_path=authorization_policy ;
\ir authz-schema.sql
\ir vault-data.sql 
commit;

\c :DBNAME postgres
GRANT SELECT,INSERT ON authorization_policy.authorization_policy_collection
        TO vault_policy;
GRANT USAGE ON SEQUENCE authorization_policy.authorization_policy_collecti_authorization_policy_collecti_seq TO vault_policy;
GRANT SELECT,INSERT ON 
	authorization_policy.authorization_policy_collection_policy
	TO vault_policy;
GRANT SELECT,INSERT ON authorization_policy.policy
	TO vault_policy;
GRANT SELECT,INSERT ON 
	authorization_policy.authorization_policy
	TO vault_policy;
GRANT USAGE ON SEQUENCE authorization_policy.authorization_policy_authorization_policy_id_seq TO vault_policy;
GRANT SELECT,INSERT ON 
	authorization_policy.authorization_policy_permission
	TO vault_policy;
GRANT SELECT,INSERT ON 
	authorization_policy.authorization_policy_collection_authorization_policy
	TO vault_policy;
GRANT SELECT ON
	authorization_policy.authorization_property
	tO vault_policy;

--
GRANT SELECT,INSERT ON 
	authorization_policy.val_authorization_policy_type
	TO authz_test;
GRANT SELECT,INSERT ON 
	authorization_policy.authorization_policy_type_permitted_permission
	TO authz_test;
GRANT SELECT,INSERT ON 
	authorization_policy.val_authorization_policy_collection_type
	TO authz_test;
GRANT SELECT,INSERT ON 
	authorization_policy.authorization_policy_collection_authorization_policy
	TO authz_test;
GRANT SELECT,INSERT ON 
	authorization_policy.authorization_policy
	TO authz_test;
GRANT SELECT,INSERT ON 
	authorization_policy.authorization_property
	TO authz_test;
GRANT SELECT,INSERT ON 
	authorization_policy.authorization_policy_permission
	TO authz_test;
GRANT SELECT,INSERT ON 
	authorization_policy.authorization_policy_collection
	TO authz_test;
GRANT USAGE ON SEQUENCE
	authorization_policy.authorization_policy_collecti_authorization_policy_collecti_seq
	TO authz_test;
GRANT USAGE ON SEQUENCE
	authorization_policy.authorization_policy_authorization_policy_id_seq
	TO authz_test;
GRANT USAGE ON SEQUENCE
	authorization_policy.authorization_property_authorization_property_id_seq
	TO authz_test;
GRANT SELECT,INSERT ON 
	authorization_policy.policy
	TO authz_test;

--

\c :DBNAME vault_policy

begin;
SET search_path=vault_policy;
\ir vault.sql
\ir vault-data2.sql

GRANT SELECT ON ALL TABLES IN schema vault_policy TO app_vault_extract;
GRANT SELECT,INSERT ON ALL TABLES IN schema vault_policy TO app_vault_change;
commit;

\c :DBNAME authz_test

begin;
SET search_path=authz_test,authorization_policy;
\ir dbgrants-data.sql
\ir stab.sql
commit;
