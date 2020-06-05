
INSERT INTO val_authorization_policy_collection_type (
    authorization_policy_collection_type
) VALUES
    ('database-grants')
;

INSERT INTO authorization_policy_collection (
    authorization_policy_collection_name, authorization_policy_collection_type
) VALUES (
    'select', 'database-grants'
);

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

WITH p AS (
	INSERT INTO property (
		property_name,
		property_type,
		property_value
	) VALUES (
		'object-grants',
		'database-grants',
		'device_collection_device'
	) RETURNING *
) INSERT INTO authz_property_base
	(property_id,  authorization_policy_collection_id)
SELECT property_id, authorization_policy_collection_id
FROM p, authorization_policy_collection
WHERE authorization_policy_collection_name = 'select'
AND authorization_policy_collection_type = 'database-grants'
RETURNING *;

SELECT * FROM authz_property;
