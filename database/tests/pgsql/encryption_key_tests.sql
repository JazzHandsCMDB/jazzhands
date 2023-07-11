-- Copyright (c) 2023 Todd Kover
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
--

\set ON_ERROR_STOP

\ir ../../ddl/schema/pgsql/create_encryption_key_triggers.sql

\t on

savepoint pretest;
DROP FUNCTION IF EXISTS encryption_key_regression_test();
CREATE FUNCTION encryption_key_regression_test() RETURNS BOOLEAN AS $$
DECLARE
	_key1	encryption_key;
	_key2	encryption_key;
BEGIN
	INSERT INTO val_encryption_method (
		encryption_method, cipher, key_size, cipher_chain_mode,
		cipher_padding, passphrase_cryptographic_hash_algorithm
	) VALUES (
		'jhsecure', 'none', 0, 'none',
		'none', 'none'
	);

	INSERT INTO val_encryption_key_purpose (
		encryption_key_purpose, encryption_key_purpose_version,
		permit_encryption_key_db_value
	) VALUES (
		'jhpurpose', 1, 'PROHIBITED'
	);

	BEGIN
		INSERT INTO encryption_key (
			encryption_key_purpose, encryption_key_purpose_version,
			encryption_method, encryption_key_db_value
		) VALUES (
			'jhpurpose', 1, 'jhsecure', 'dbpart'
		) RETURNING * INTO _key1;
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '... PHOHIBITED works.';
	END;

	INSERT INTO encryption_key (
		encryption_key_purpose, encryption_key_purpose_version,
		encryption_method
	) VALUES (
		'jhpurpose', 1, 'jhsecure'
	) RETURNING * INTO _key1;

	RAISE NOTICE 'Checking if changing encryption_key_db_value to REQUIRED fails';
	BEGIN
		UPDATE val_encryption_key_purpose
		SET permit_encryption_key_db_value = 'REQUIRED'
		WHERE encryption_key_purpose = 'jhpurpose'
		AND encryption_key_purpose_version = 1;

		RAISE EXCEPTION '... it suceeeded, ugh';
	EXCEPTION WHEN not_null_violation THEN
                RAISE NOTICE '... failed correctly: (%: %)', SQLSTATE, SQLERRM;
	END;

	RAISE NOTICE 'Checking if changing encryption_key_db_value to ALLOWED works';
	BEGIN
		UPDATE val_encryption_key_purpose
		SET permit_encryption_key_db_value = 'ALLOWED'
		WHERE encryption_key_purpose = 'jhpurpose'
		AND encryption_key_purpose_version = 1;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... it did : (%: %)', SQLSTATE, SQLERRM;
	END;

	RAISE NOTICE 'Checking if changing encryption_key_db_value to REQUIRED works';
	BEGIN
		UPDATE val_encryption_key_purpose
		SET permit_encryption_key_db_value = 'ALLOWED'
		WHERE encryption_key_purpose = 'jhpurpose'
		AND encryption_key_purpose_version = 1;

		UPDATE encryption_key SET encryption_key_db_value = 'dbvalue'
			WHERE encryption_key_id = _key1.encryption_key_id;

		UPDATE val_encryption_key_purpose
		SET permit_encryption_key_db_value = 'REQUIRED'
		WHERE encryption_key_purpose = 'jhpurpose'
		AND encryption_key_purpose_version = 1;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... it did : (%: %)', SQLSTATE, SQLERRM;
	END;

	RAISE NOTICE 'Checking if startingw ith encryption_key_db_value to REQUIRED works';
	BEGIN
		INSERT INTO val_encryption_key_purpose (
			encryption_key_purpose, encryption_key_purpose_version,
			permit_encryption_key_db_value
		) VALUES (
			'jhpurpose', 2, 'REQURIED'
		);

		INSERT INTO encryption_key (
			encryption_key_purpose, encryption_key_purpose_version,
			encryption_method, encryption_key_db_value
		) VALUES (
			'jhpurpose', 2, 'jhsecure', 'dbpart'
		) RETURNING * INTO _key2;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... it did : (%: %)', SQLSTATE, SQLERRM;
	END;

	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT encryption_key_regression_test();
DROP FUNCTION encryption_key_regression_test();

ROLLBACK TO pretest;
\t off
