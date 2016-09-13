-- Copyright (c) 2016 Todd Kover
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

-- $Id$


\set ON_ERROR_STOP

\t on
SAVEPOINT x509_tests;

-- 
-- Trigger tests
--
CREATE OR REPLACE FUNCTION x509_regression() RETURNS BOOLEAN AS $$
DECLARE
	crt			x509_signed_certificate%ROWTYPE;
	key			private_key%ROWTYPE;
	key2		private_key%ROWTYPE;
	csr			certificate_signing_request%ROWTYPE;
BEGIN
	RAISE NOTICE 'x509_regression: Cleanup Records from Previous Tests';

	RAISE NOTICE '++ x509_regression: Inserting testing data';

	INSERT INTO private_key (
		private_key_encryption_type, subject_key_identifier, private_key
	) VALUES (
		'rsa', '11:22:33:44', '-- KEY --'
	) RETURNING * INTO key;

	INSERT INTO certificate_signing_request (
		friendly_name, subject, certificate_signing_request, private_key_id
	) VALUES (
		'foo', 'bar', '--- CSR ---', key.private_key_id
	) RETURNING * INTO csr;

	INSERT INTO x509_signed_certificate (
		x509_certificate_type, subject, friendly_name, subject_key_identifier,
		public_key, private_key_id, certificate_signing_request_id,
		valid_from, valid_to
	) VALUES (
		'default', 'foo', 'bar', '11:22:33:44',
		'-- CRT--', key.private_key_id, csr.certificate_signing_request_id,
		'-infinity', 'infinity'
	) RETURNING * INTO crt;

	INSERT INTO private_key (
		private_key_encryption_type, subject_key_identifier, private_key
	) VALUES (
		'rsa', 'aa:bb:cc:dd', '-- KEY2 --'
	) RETURNING * INTO key2;

	RAISE NOTICE '++ x509_regression: Inserting testing data';

	RAISE NOTICE 'Checking if inserting a bum SKI fails...';
	BEGIN
		INSERT INTO x509_signed_certificate (
			x509_certificate_type, subject, friendly_name, subject_key_identifier,
			public_key, private_key_id, certificate_signing_request_id,
			valid_from, valid_to
		) VALUES (
			'default', 'foo', 'bar', '11:22:33:55',
			'-- CRT--', key.private_key_id, csr.certificate_signing_request_id,
			'-infinity', 'infinity'
		) RETURNING * INTO crt;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if updating a bum SKI in x509_signed_cert fails...';
	BEGIN
		UPDATE x509_signed_certificate
		SET subject_key_identifier = '11:22:33:55'
		WHERE private_key_id = key.private_key_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if updating a bum SKI in private_key fails...';
	BEGIN
		UPDATE private_key
		SET subject_key_identifier = '11:22:33:55'
		WHERE private_key_id = key.private_key_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if updating a only private key in x509_signed_cert fails...';
	BEGIN
		UPDATE x509_signed_certificate
		SET private_key_id = key2.private_key_id
		WHERE x509_signed_certificate_id = crt.x509_signed_certificate_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT x509_regression();
-- set search_path=jazzhands;
DROP FUNCTION x509_regression();

ROLLBACK TO x509_tests;

\t off
