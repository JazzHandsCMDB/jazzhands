INSERT INTO val_property_type
	(property_type, description)
VALUES
	('HOTPants', 'properties that define HOTPants behavior')
;

insert into val_property (property_name, property_type,
        permit_device_collection_id, property_data_type, description
) values (
        'RadiusSharedSecret', 'HOTPants',
        'REQUIRED', 'string', 'RADIUS share secret consumed by HOTPants'
);

insert into val_token_status (token_status)
values
	('disabled'),
	('enabled'),
	('lost'),
	('destored'),
	('stolen');

insert into val_token_type (token_type, description, token_digit_count)
values
	('soft_seq', 'sequence based soft token', 6),
	('soft_time', 'time-based soft token', 6);

insert into val_encryption_key_purpose (
	encryption_key_purpose, encryption_key_purpose_version, description
) values (
	'tokenkey', 1, 'Passwords for Token Keys'
);

