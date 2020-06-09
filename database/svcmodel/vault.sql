\set ON_ERROR_STOP

-- XXX - need to deal with service, device collection integration

CREATE OR REPLACE VIEW vault_policy AS
SELECT
	authorization_policy_collection_id as vault_policy_id,
	authorization_policy_collection_name as vault_policy_name,
	min(policy_definition->>'secret_ttl') 
		FILTER (WHERE policy_type = 'vault-ttls') AS secret_ttl,
	min(policy_definition->>'token_ttl') 
		FILTER (WHERE policy_type = 'vault-ttls') AS token_ttl,
	min(policy_definition->>'token_max_ttl') 
		FILTER (WHERE policy_type = 'vault-ttls') AS token_max_ttl,
	min(policy_definition->>'secret_max') 
		FILTER (WHERE policy_type = 'vault-usages') AS secret_max,
	min(policy_definition->>'token_max') 
		FILTER (WHERE policy_type = 'vault-usages') AS token_max,
	coalesce(
		bool_or( (policy_definition->>'disabled')::boolean ) 
		FILTER (WHERE policy_type = 'disabled-approle') 
	, false) AS approle_disabled
FROM	authorization_policy_collection
	lEFT JOIN (
		SELECT authorization_policy_collection_id, p.*
		FROM authorization_policy_collection_policy
			JOIN policy p USING (policy_id)
	) pols USING (authorization_policy_collection_id)
WHERE authorization_policy_collection_type = 'vault-policy'
GROUP BY authorization_policy_collection_id,
	authorization_policy_collection_name
;

CREATE OR REPLACE VIEW vault_policy_path AS
SELECT
	authorization_policy_id	AS vault_policy_path_id,
	authorization_policy_collection_id AS vault_policy_id,
	authorization_policy_scope AS vault_policy_path,
	CASE WHEN COUNT(*) FILTER (WHERE permission = 'create') > 0 THEN
		true ELSE false END AS create,
	CASE WHEN COUNT(*) FILTER (WHERE permission = 'list') > 0 THEN
		true ELSE false END AS list,
	CASE WHEN COUNT(*) FILTER (WHERE permission = 'read') > 0 THEN
		true ELSE false END AS read,
	CASE WHEN COUNT(*) FILTER (WHERE permission = 'update') > 0 THEN
		true ELSE false END AS update,
	CASE WHEN COUNT(*) FILTER (WHERE permission = 'delete') > 0 THEN
		true ELSE false END AS delete
FROM authorization_policy
	JOIN authorization_policy_collection_authorization_policy
		USING (authorization_policy_id)
	JOIN authorization_policy_permission USING (authorization_policy_id)
WHERE authorization_policy_type IN ('vault-policy-path','vault-metadata-path')
GROUP BY authorization_policy_id,
	authorization_policy_collection_id,
	authorization_policy_name
;

CREATE OR REPLACE VIEW vault_mclass AS
SELECT authorization_policy_collection_id AS vault_policy_id,
	device_collection_name AS mclass,
	'notyet' as user,
	'notyet' as group
FROM authorization_policy_collection ac
JOIN authz_property azp USING (authorization_policy_collection_id)
JOIN device_collection USING (device_collection_id)
-- WHERE authorization_policy_type IN ('vault-policy-path','vault-metadata-path')
WHERE authorization_policy_collection_type IN ('vault-policy')
AND property_name = 'mclass-authorization-map'
AND property_type = 'authorization-mappings'
;

\set ECHO queries

SELECT * FROM vault_policy ORDER BY 1;
SELECT * FROM vault_policy_path ORDER BY 1;

SELECT * FROM vault_mclass;

-- XXX need to incrporate user and group for mclass

\set ECHO none
