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


Given PRN is 279174.  PRN for sequence 47812854 is 543263
Given PRN is 279174.  PRN for sequence 47812855 is 404021


