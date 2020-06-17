/*
 * insert things into the base tables for vault
 */

INSERT INTO val_policy_type
	(policy_type, policy_schema)
VALUES
	('vault-ttls', '{}'),
	('vault-usages', '{}'),
	('vault-disabled-approles', '{}')
RETURNING *
;

INSERT INTO policy 
	(policy_name, policy_type, policy_definition)
VALUES 
	('initial-vault-ttl-default', 'vault-ttls', 
		'{"secret_ttl": 2592000, "token_ttl": 172800, "token_max_ttl": 345600}'),
	('unlimited-usages', 'vault-usages', 
		'{"secret_max_uses": null, "token_max_uses": null }'),
	('disabled-approle', 'vault-disabled-approles', '{"disabled": true}')
;

WITH apt AS (
	INSERT INTO val_authorization_policy_type (
		authorization_policy_type
	) VALUES 
		( 'vault-policy-path' ),
		( 'vault-metadata-path' )
	RETURNING *
) INSERT INTO authorization_policy_type_permitted_permission (
	authorization_policy_type,permission
) SELECT authorization_policy_type, 
	unnest(ARRAY['create','read','update','delete'])
FROM apt;


INSERT INTO val_authorization_policy_collection_type (
	authorization_policy_collection_type
) VALUES
	('vault-policy')
;

INSERT INTO authorization_policy_collection (
	authorization_policy_collection_name, authorization_policy_collection_type
) VALUES (
	'nbde-escrow-production-creator', 'vault-policy'
);

INSERT INTO authorization_policy_collection_policy (
	authorization_policy_collection_id, policy_id
) SELECT authorization_policy_collection_id, policy_id
FROM authorization_policy_collection, policy
WHERE authorization_policy_collection_name = 'nbde-escrow-production-creator'
AND authorization_policy_collection_type = 'vault-policy'
AND (
	policy_name = 'initial-vault-ttl-default' AND policy_type = 'vault-ttls'
OR	 policy_name = 'unlimited-usages' AND policy_type = 'vault-usages'
OR	 policy_name = 'vault-disabled-approles' AND policy_type = 'disabled-approle'
);

WITH pt AS (
		INSERT INTO authorization_policy (
			authorization_policy_name, authorization_policy_type,
			authorization_policy_scope
		) VALUES (
			pgcrypto.gen_random_uuid(), 'vault-policy-path',
			'global/kv/data/services/nbde-escrow/environments/production/hosts/*'
		)
		RETURNING *
	), perm AS (
		INSERT INTO authorization_policy_permission (
			authorization_policy_id, permission
		) SELECT authorization_policy_id, 'create'
		FROM pt
	) INSERT INTO authorization_policy_collection_authorization_policy (
		authorization_policy_collection_id, authorization_policy_id
	) SELECT authorization_policy_collection_id, authorization_policy_id
	FROM pt, authorization_policy_collection
	WHERE authorization_policy_collection_name = 'nbde-escrow-production-creator'
	AND authorization_policy_collection_type = 'vault-policy' 
	;

	WITH pt AS (
		INSERT INTO authorization_policy (
			authorization_policy_name, authorization_policy_type,
			authorization_policy_scope
		) VALUES  (
			pgcrypto.gen_random_uuid(), 'vault-policy-path',
			unnest(ARRAY[
				'global/kv/data/services/nbde-escrow/environments/production/krb5-principal',
				'global/kv/data/services/nbde-escrow/environments/production/tls-certificate'
			])
		) RETURNING *
	), perm AS (
		INSERT INTO authorization_policy_permission (
			authorization_policy_id, permission
		) SELECT authorization_policy_id, 'create'
		FROM pt
	) INSERT INTO authorization_policy_collection_authorization_policy (
		authorization_policy_collection_id, authorization_policy_id
	) SELECT authorization_policy_collection_id, authorization_policy_id
	FROM pt, authorization_policy_collection
	WHERE authorization_policy_collection_name = 'nbde-escrow-production-creator'
	AND authorization_policy_collection_type = 'vault-policy' 
	;

	WITH pt AS (
		INSERT INTO authorization_policy (
			authorization_policy_name, authorization_policy_type,
			authorization_policy_scope
		) VALUES  (
			pgcrypto.gen_random_uuid(), 'vault-policy-path',
			unnest(ARRAY[
				'global/kv/data/services/nbde-escrow/environments/production/hosts/+/+/+/latest-checksum',
				'global/kv/data/services/nbde-escrow/environments/production/hosts/+/_tmp_luks-test-device/'
			])
		) RETURNING *
	), perm AS (
		INSERT INTO authorization_policy_permission (
			authorization_policy_id, permission
		) SELECT authorization_policy_id, 
			unnest(ARRAY['read','create','update'])
		FROM pt
	) INSERT INTO authorization_policy_collection_authorization_policy (
		authorization_policy_collection_id, authorization_policy_id
	) SELECT authorization_policy_collection_id, authorization_policy_id
	FROM pt, authorization_policy_collection
	WHERE authorization_policy_collection_name = 'nbde-escrow-production-creator'
	AND authorization_policy_collection_type = 'vault-policy' 
	;

	WITH pt AS (
		INSERT INTO authorization_policy (
			authorization_policy_name, authorization_policy_type,
			authorization_policy_scope
		) VALUES  (
			pgcrypto.gen_random_uuid(), 'vault-policy-path',
			'global/kv/metadata/services/nbde-escrow/environments/production/hosts/+/_tmp_luks-test-device/'
		) RETURNING *
	), perm AS (
		INSERT INTO authorization_policy_permission (
			authorization_policy_id, permission
		) SELECT authorization_policy_id, 
			unnest(ARRAY['list','delete'])
		FROM pt
	) INSERT INTO authorization_policy_collection_authorization_policy (
		authorization_policy_collection_id, authorization_policy_id
	) SELECT authorization_policy_collection_id, authorization_policy_id
	FROM pt, authorization_policy_collection
	WHERE authorization_policy_collection_name = 'nbde-escrow-production-creator'
	AND authorization_policy_collection_type = 'vault-policy' 
	;

	WITH pt AS (
		INSERT INTO authorization_policy (
			authorization_policy_name, authorization_policy_type,
			authorization_policy_scope
		) VALUES  (
			pgcrypto.gen_random_uuid(), 'vault-policy-path',
			unnest(ARRAY[
				'global/kv/data/services/nbde-escrow/environments/production/hosts/01.code-test.local/*',
				'global/kv/metadata/services/nbde-escrow/environments/production/hosts/01.code-test.local/*'
			])
		) RETURNING *
	), perm AS (
		INSERT INTO authorization_policy_permission (
			authorization_policy_id, permission
		) SELECT authorization_policy_id, 
			unnest(ARRAY['read','create','update'])
		FROM pt
	) INSERT INTO authorization_policy_collection_authorization_policy (
		authorization_policy_collection_id, authorization_policy_id
	) SELECT authorization_policy_collection_id, authorization_policy_id
	FROM pt, authorization_policy_collection
	WHERE authorization_policy_collection_name = 'nbde-escrow-production-creator'
	AND authorization_policy_collection_type = 'vault-policy' 
;


INSERT INTO authorization_property (
	property_name, property_type, 
	device_collection_id, authorization_policy_collection_id,
	unix_group_account_collection_id
)
SELECT 'mclass-authorization-map', 'authorization-mappings',
        device_collection_id, authorization_policy_collection_id,
		account_collection_id
FROM authorization_policy_collection, jazzhands.device_collection,
	jazzhands.account_collection
WHERE authorization_policy_collection_name = 'nbde-escrow-production-creator'
AND authorization_policy_collection_type = 'vault-policy'
AND  device_collection_name = 'stab'
AND device_collection_type = 'mclass'
AND account_collection_name = 'www-data'
AND account_collection_type = 'unix-group'
;
