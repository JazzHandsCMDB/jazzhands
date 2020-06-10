
WITH apt AS (
	INSERT INTO val_authorization_policy_type (
		authorization_policy_type
	) VALUES ( 
		'database-object-grants'
	) RETURNING *
) INSERT INTO authorization_policy_type_permitted_permission (
        authorization_policy_type,permission
) SELECT authorization_policy_type,
        unnest(ARRAY['select','insert','update','delete'])
FROM apt;

INSERT INTO val_authorization_policy_collection_type (
	authorization_policy_collection_type
) VALUES (
	'database-grants'
);

WITH ap AS (
	INSERT INTO authorization_policy (
    	authorization_policy_name, authorization_policy_type,
    	authorization_policy_scope
	) VALUES 
		('jazzhands-device-collection_device-rw', 'database-object-grants',
    		'device_collection_device'
		),
		('jazzhands-device-collection-rw', 'database-object-grants',
    		'device_collection'
		),
		('jazzhands-device-rw', 'database-object-grants',
    		'device'
		)
		RETURNING *
), app AS (
	INSERT INTO authorization_policy_permission (
		authorization_policy_id, permission
	) SELECT authorization_policy_id,
		unnest(ARRAY['insert','update','delete'])
	FROM ap
	RETURNING *
), apc AS (
	INSERT INTO authorization_policy_collection (
		authorization_policy_collection_name, 
		authorization_policy_collection_type
	) VALUES (
		'jazzhands-device-rw', 'database-grants'
	) RETURNING *
) INSERT INTO authorization_policy_collection_authorization_policy (
	authorization_policy_collection_id, authorization_policy_id
) SELECT authorization_policy_collection_id, authorization_policy_id
FROM apc, ap
;

WITH ap AS (
	INSERT INTO authorization_policy (
    	authorization_policy_name, authorization_policy_type,
    	authorization_policy_scope
	) VALUES 
		('update-serial-number', 'database-object-grants',
    		'jazzhands.asset(serial_number)'
		)
		RETURNING *
), app AS (
	INSERT INTO authorization_policy_permission (
		authorization_policy_id, permission
	) SELECT authorization_policy_id,
		unnest(ARRAY['update'])
	FROM ap
	RETURNING *
), apc AS (
	INSERT INTO authorization_policy_collection (
		authorization_policy_collection_name, 
		authorization_policy_collection_type
	) VALUES (
		'asset-mgmt', 'database-grants'
	) RETURNING *
) INSERT INTO authorization_policy_collection_authorization_policy (
	authorization_policy_collection_id, authorization_policy_id
) SELECT authorization_policy_collection_id, authorization_policy_id
FROM apc, ap
;

INSERT INTO val_property_type (
	property_type,
	description
) VALUES (
	'database-grants',
	'nuff said'
);

INSERT INTO val_property (
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


CREATE VIEW v_database_grants AS
SELECT ac.authorization_policy_collection_name, 
	ap.authorization_policy_id,
	ap.authorization_policy_name,
	ap.authorization_policy_type,
	ap.authorization_policy_scope,
	ap.description,
	perm.permission
FROM authorization_policy_collection ac
JOIN authorization_policy_collection_authorization_policy
	USING (authorization_policy_collection_id)
JOIN authorization_policy ap USING (authorization_policy_id)
JOIN authorization_policy_permission perm USING (authorization_policy_id)
WHERE authorization_policy_collection_type = 'database-grants'
;

-- SELECT * FROM authz_property;
SELECT * FROM v_database_grants;
