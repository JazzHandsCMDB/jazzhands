
WITH apt AS (
	INSERT INTO val_authorization_policy_type (
		authorization_policy_type
	) VALUES ( 
		'stab-access'
	) RETURNING *
) INSERT INTO authorization_policy_type_permitted_permission (
        authorization_policy_type,permission
) SELECT authorization_policy_type,
        unnest(ARRAY['read','write'])
FROM apt;

INSERT INTO val_authorization_policy_collection_type (
	authorization_policy_collection_type
) VALUES (
	'stab-policies'
);

WITH ap AS (
	INSERT INTO authorization_policy (
    	authorization_policy_name, authorization_policy_type,
    	authorization_policy_scope
	) VALUES 
		('stab-device-rw', 'stab-access',
    		'/device'
		),
		('stab-netblock-rw', 'stab-access',
    		'/netblock/*.pl'
		),
		('stab-dns-rw', 'stab-access',
    		'/dns'
		)
		RETURNING *
), app AS (
	INSERT INTO authorization_policy_permission (
		authorization_policy_id, permission
	) SELECT authorization_policy_id,
		unnest(ARRAY['read','write'])
	FROM ap
	RETURNING *
), apc AS (
	INSERT INTO authorization_policy_collection (
		authorization_policy_collection_name, 
		authorization_policy_collection_type
	) VALUES (
		'stab-techs', 'stab-policies'
	) RETURNING *
) INSERT INTO authorization_policy_collection_authorization_policy (
	authorization_policy_collection_id, authorization_policy_id
) SELECT authorization_policy_collection_id, authorization_policy_id
FROM apc, ap
;

INSERT INTO authorization_property (
	property_name, property_type, 
	device_collection_id,
	authorization_policy_collection_id
)
SELECT 'mclass-authorization-map', 'authorization-mappings',
	device_collection_id,
	authorization_policy_collection_id
FROM jazzhands.device_collection, authorization_policy_collection
WHERE authorization_policy_collection_name = 'stab-techs'
AND authorization_policy_collection_type = 'stab-policies'
AND device_collection_name = 'stab'
AND device_collection_type = 'mclass'
;

CREATE OR REPLACE VIEW v_stab_permissions AS
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
WHERE authorization_policy_collection_type = 'stab-policies'
;

CREATE OR REPLACE VIEW v_stab_permissions_to_device AS
SELECT 	device_name,
	ac.authorization_policy_collection_name, 
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
JOIN authorization_property azp USING (authorization_policy_collection_id)
JOIN device_collection_device USING (device_collection_id)
JOIN device d USING (device_id)
WHERE authorization_policy_collection_type = 'stab-policies'
AND property_name = 'mclass-authorization-map'
AND property_type = 'authorization-mappings'
;

-- SELECT * FROM authz_property;
SELECT * FROM v_stab_permissions_to_device;
