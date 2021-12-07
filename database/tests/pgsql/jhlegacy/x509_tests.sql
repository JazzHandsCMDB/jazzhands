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

-- \ir ../../ddl/schema/pgsql/create_x509_triggers.sql

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION x509_regression() RETURNS BOOLEAN AS $$
DECLARE
	crt			x509_signed_certificate%ROWTYPE;
	key			private_key%ROWTYPE;
	key2		private_key%ROWTYPE;
	csr			certificate_signing_request%ROWTYPE;
	pkhid		public_key_hash.public_key_hash_id%TYPE;
BEGIN
	RAISE NOTICE 'x509_regression: Cleanup Records from Previous Tests';

	RAISE NOTICE '++ x509_regression: Inserting testing data';

	INSERT INTO public_key_hash ( description ) VALUES ('JHTEST')
		RETURNING public_key_hash_id INTO pkhid;

	INSERT INTO private_key (
		private_key_encryption_type, public_key_hash_id, private_key
	) VALUES (
		'rsa', pkhid, '-- KEY --'
	) RETURNING * INTO key;

	INSERT INTO certificate_signing_request (
		friendly_name, subject, certificate_signing_request,
		public_key_hash_id, private_key_id
	) VALUES (
		'foo', 'bar', '--- CSR ---',
		pkhid, key.private_key_id
	) RETURNING * INTO csr;

	INSERT INTO x509_signed_certificate (
		x509_certificate_type, subject, friendly_name, subject_key_identifier,
		public_key, private_key_id, public_key_hash_id,
		certificate_signing_request_id, valid_from, valid_to
	) VALUES (
		'default', 'foo', 'bar', '11:22:33:44',
		'-- CRT--', key.private_key_id, pkhid,
		csr.certificate_signing_request_id, '-infinity', 'infinity'
	) RETURNING * INTO crt;


	WITH p AS (
		INSERT INTO public_key_hash ( description ) VALUES ('JHTEST')
			RETURNING *
	) INSERT INTO private_key (
		private_key_encryption_type, public_key_hash_id, private_key
	) SELECT 'rsa', public_key_hash_id, '-- KEY2 --'
	FROM p RETURNING * INTO key2;

	RAISE NOTICE '++ x509_regression: Inserting testing data';

	RAISE NOTICE 'Checking if inserting a mismatched csr AND private_key public_key_hash_id fails...';
	BEGIN
		INSERT INTO x509_signed_certificate (
			x509_certificate_type, subject, friendly_name,
			subject_key_identifier, public_key_hash_id,
			public_key, private_key_id, certificate_signing_request_id,
			valid_from, valid_to
		) VALUES (
			'default', 'foo', 'bar',
			'11:22:33:55', key2.public_key_hash_id,
			'-- CRT--', key.private_key_id, csr.certificate_signing_request_id,
			'-infinity', 'infinity'
		) RETURNING * INTO crt;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if inserting a mismatched private_key  public_key_hash_id fails...';
	BEGIN
		INSERT INTO x509_signed_certificate (
			x509_certificate_type, subject, friendly_name,
			subject_key_identifier, public_key_hash_id,
			public_key, private_key_id,
			valid_from, valid_to
		) VALUES (
			'default', 'foo', 'bar',
			'11:22:33:55', key2.public_key_hash_id,
			'-- CRT--', key.private_key_id,
			'-infinity', 'infinity'
		) RETURNING * INTO crt;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if inserting a mismatched csr public_key_hash_id fails...';
	BEGIN
		INSERT INTO x509_signed_certificate (
			x509_certificate_type, subject, friendly_name,
			subject_key_identifier, public_key_hash_id,
			public_key, certificate_signing_request_id,
			valid_from, valid_to
		) VALUES (
			'default', 'foo', 'bar',
			'11:22:33:55', key2.public_key_hash_id,
			'-- CRT--', csr.certificate_signing_request_id,
			'-infinity', 'infinity'
		) RETURNING * INTO crt;
		RAISE EXCEPTION '... IT DID NOT. (%)', jsonb_pretty(to_jsonb(crt));
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if updating a bum public_key_hash in x509_signed_cert fails...';
	BEGIN
		UPDATE x509_signed_certificate
		SET public_key_hash_id = key2.public_key_hash_id
		WHERE private_key_id = key.private_key_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if updating a bum public_key_hash in private_key fails...';
	BEGIN
		UPDATE private_key
		SET public_key_hash_id = key2.public_key_hash_id
		WHERE private_key_id = key.private_key_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if updating a bum public_key_hash in certificate_signing_request fails...';
	BEGIN
		UPDATE certificate_signing_request
		SET public_key_hash_id = key2.public_key_hash_id
		WHERE certificate_signing_request_id = csr.certificate_signing_request_id;
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

	RAISE NOTICE 'Checking if inserting both an external id AND private key fails...';
	BEGIN
		INSERT INTO private_key (
			private_key_encryption_type, public_key_hash_id,
			private_key, external_id
		) VALUES (
			'rsa', key2.public_key_hash_id,
			'--KEY--', '/foo/bar/baz'
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did - %', SQLERRM;
	END;

	RAISE NOTICE 'Checking if inserting neither an external id AND private key fails...';
	BEGIN
		INSERT INTO private_key (
			private_key_encryption_type, public_key_hash_id
		) VALUES (
			'rsa', key2.public_key_hash_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did - %', SQLERRM;
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
