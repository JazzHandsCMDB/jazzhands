-- Copyright (c) 2021 Todd Kover
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

-- search path jazzhands - if this is being fixed up
-- \ir ../../../ddl/schema/pgsql/create_x509_triggers.sql
-- this is typically set outside but left here
-- set search_path=jazzhands_legacy;
-- \ir ../../../ddl/legacy.sql

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION deprecated_x509_regression() RETURNS BOOLEAN AS $$
DECLARE
	x509ca		x509_certificate%ROWTYPE;
	x509		x509_certificate%ROWTYPE;
	crt			x509_signed_certificate%ROWTYPE;
	key			private_key%ROWTYPE;
	key2		private_key%ROWTYPE;
	csr			certificate_signing_request%ROWTYPE;
	pkhidca		public_key_hash.public_key_hash_id%TYPE;
	pkhid		public_key_hash.public_key_hash_id%TYPE;
	pkhid2		public_key_hash.public_key_hash_id%TYPE;
	_d			RECORD;
	_r			RECORD;
BEGIN
	RAISE NOTICE 'deprecated_x509_regression: Cleanup Records from Previous Tests';

	RAISE NOTICE '++ deprecated_x509_regression: Inserting testing data';

	INSERT INTO public_key_hash ( description ) VALUES ('testca')
		RETURNING public_key_hash_id INTO pkhidca;
	INSERT INTO public_key_hash ( description ) VALUES ('test')
		RETURNING public_key_hash_id INTO pkhid;
	INSERT INTO public_key_hash ( description ) VALUES ('test')
		RETURNING public_key_hash_id INTO pkhid2;

	INSERT INTO x509_certificate (
		friendly_name, is_certificate_authority,
		signing_cert_id, x509_ca_cert_serial_number,
		public_key, private_key, certificate_sign_req, subject,
		subject_key_identifier, public_key_hash_id,
		valid_from, valid_to
	) VALUES (
		'myca', 'Y',
		NULL, NULL,
		'- PUBLIC KEY -', '- PRIVATE KEY -', '- CSR ', 'myca',
		'aa:bb:cc', pkhidca,
		now() - '1 week'::interval, now() + '90 days'::interval
	) RETURNING * INTO x509ca;

	SELECT * INTO _d FROM x509_certificate
		WHERE x509_cert_id = x509ca.x509_cert_id;
	IF _d != x509ca THEN
		RAISE EXCEPTION 'Insert does not match';
	END IF;

	INSERT INTO x509_certificate (
		friendly_name, is_certificate_authority,
		signing_cert_id, x509_ca_cert_serial_number,
		public_key, private_key, certificate_sign_req, subject,
		subject_key_identifier, public_key_hash_id,
		valid_from, valid_to
	) VALUES (
		'mycert.example.org', 'N',
		x509ca.x509_cert_id, 10,
		'- PUBLIC KEY -', '- PRIVATE KEY -', '- CSR - ', 'mycert.example.org',
		'aa:bb:cc', pkhid ,
		now() - '1 week'::interval, now() + '90 days'::interval
	) RETURNING * INTO x509ca;


	SELECT * INTO _d FROM x509_certificate
		WHERE x509_cert_id = x509.x509_cert_id;
	IF _d != x509 THEN
		RAISE EXCEPTION 'Insert does not match';
	END IF;

	RAISE NOTICE '++ : inserting with no key or csr';
	BEGIN
		INSERT INTO x509_certificate (
			friendly_name, is_certificate_authority,
			signing_cert_id, x509_ca_cert_serial_number,
			public_key, private_key, certificate_sign_req, subject,
			subject_key_identifier, public_key_hash_id,
			valid_from, valid_to
		) VALUES (
			'mypubliconlycert.example.org', 'N',
			x509ca.x509_cert_id, 10,
			'- PUBLIC KEY -', NULL, NULL, 'mypubliconlycert.example.org',
			'aa:bb:cc', pkhid2 ,
			now() - '1 week'::interval, now() + '90 days'::interval
		) RETURNING * INTO _r;

		SELECT * INTO _d FROM x509_certificate
			WHERE x509_cert_id = _r.x509_cert_id;
		IF _d != _r THEN
			RAISE EXCEPTION 'Insert does not match: % %',
				to_jsonb(_r), to_jsonb(_d);
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;


	RAISE NOTICE '++ : inserting with only crt, key ';
	BEGIN
		INSERT INTO x509_certificate (
			friendly_name, is_certificate_authority,
			signing_cert_id, x509_ca_cert_serial_number,
			public_key, private_key, certificate_sign_req, subject,
			subject_key_identifier, public_key_hash_id,
			valid_from, valid_to
		) VALUES (
			'mywithkey.example.org', 'N',
			x509ca.x509_cert_id, 10,
			'- PUBLIC KEY -', '--KEY--', NULL,'mywithkey.example.org',
			'aa:bb:cc', pkhid ,
			now() - '1 week'::interval, now() + '90 days'::interval
		) RETURNING * INTO _r;

		SELECT * INTO _d FROM x509_certificate
			WHERE x509_cert_id = _r.x509_cert_id;
		IF _d != _r THEN
			RAISE EXCEPTION 'Insert does not match: % %',
				jsonb_pretty(to_jsonb(_r)), jsonb_pretty(to_jsonb(_d));
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ : inserting with only crt, csr ';
	BEGIN
		INSERT INTO x509_certificate (
			friendly_name, is_certificate_authority,
			signing_cert_id, x509_ca_cert_serial_number,
			public_key, private_key, certificate_sign_req, subject,
			subject_key_identifier, public_key_hash_id,
			valid_from, valid_to
		) VALUES (
			'mywithcsr.example.org', 'N',
			x509ca.x509_cert_id, 10,
			'- PUBLIC KEYx -', NULL, '-CSR-', 'mywithcsr.example.org',
			'aa:bb:cc', pkhid2 ,
			now() - '1 week'::interval, now() + '90 days'::interval
		) RETURNING * INTO _r;

		SELECT * INTO _d FROM x509_certificate
			WHERE x509_cert_id = _r.x509_cert_id;
		IF _d != _r THEN
			RAISE EXCEPTION 'Insert does not match';
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ : inserting with only key (ths is horrible, horrible, horrible, gross)... ';
	BEGIN
		INSERT INTO x509_certificate (
			friendly_name, is_certificate_authority,
			signing_cert_id, x509_ca_cert_serial_number,
			public_key, private_key, certificate_sign_req, subject,
			subject_key_identifier, public_key_hash_id,
			valid_from, valid_to
		) VALUES (
			'mywithcsr.example.org', 'N',
			x509ca.x509_cert_id, 10,
			NULL, '--KEY--', NULL, 'mywithcsr.example.org',
			'aa:bb:cc', pkhid2 ,
			now() - '1 week'::interval, now() + '90 days'::interval
		) RETURNING * INTO _r;

		SELECT * INTO _d FROM private_key
			WHERE private_key_id = _r.x509_cert_id;
		IF _d.private_key != _r.private_key THEN
			RAISE EXCEPTION 'Insert does not match: % %',
				jsonb_pretty(to_jsonb(_r)), jsonb_pretty(to_jsonb(_d));
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;


	RAISE NOTICE '++ deprecated_x509_regression: Wrapping up';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT deprecated_x509_regression();
-- set search_path=jazzhands;
DROP FUNCTION deprecated_x509_regression();

ROLLBACK TO x509_tests;

\t off
