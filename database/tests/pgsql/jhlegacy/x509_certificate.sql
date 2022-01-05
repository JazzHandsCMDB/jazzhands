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

-- \ir ../../../ddl/legacy.sql

-- Trigger tests
--
CREATE OR REPLACE FUNCTION x509_certificate_regresssion() RETURNS BOOLEAN AS $$
DECLARE
	crt			x509_signed_certificate%ROWTYPE;
	key			private_key%ROWTYPE;
	key2		private_key%ROWTYPE;
	csr			certificate_signing_request%ROWTYPE;
	lc			x509_certificate%ROWTYPE;
	pkhid		public_key_hash.public_key_hash_id%TYPE;
BEGIN
	RAISE NOTICE 'x509_certificate_regresssion: Cleanup Records from Previous Tests';

	RAISE NOTICE '++ x509_certificate_regresssion: Inserting testing data';

	INSERT INTO public_key_hash ( description ) VALUES ('JHTEST')
		RETURNING public_key_hash_id INTO pkhid;

	INSERT INTO x509_certificate (
		friendly_name, public_key, private_key, public_key_hash_id,
		certificate_sign_req, subject, subject_key_identifier,
		valid_from, valid_to
	) VALUES (
		'testca', '--pubkey--', '--privkey--', pkhid,
		'--csr--', 'CN=testca', 'aa:bb:cc',
		now() - '1 day'::interval, now() + '45 days'::interval
	) RETURNING * INTO lc;

	SELECT * INTO crt FROM x509_signed_certificate
	WHERE x509_signed_certificate_id = lc.x509_cert_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'x509_signed_certificate did not propagate';
	END IF;

	SELECT * INTO key FROM private_key
	WHERE private_key_id = crt.private_key_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'private_key not found';
	END IF;

	SELECT * INTO csr FROM certificate_signing_request
	WHERE certificate_signing_request_id = crt.certificate_signing_request_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'certificate_signing_request did not propagate';
	END IF;

	IF crt.public_key != '--pubkey--' THEN
		RAISE EXCEPTION 'public_key did not propoagate';
	END IF;

	IF key.private_key != '--privkey--' THEN
		RAISE EXCEPTION 'public_key did not propoagate';
	END IF;

	IF crt.public_key != '--pubkey--' THEN
		RAISE EXCEPTION 'public_key did not propoagate';
	END IF;

	IF csr.certificate_signing_request != '--csr--' THEN
		RAISE EXCEPTION 'certificate_sign_req did not propoagate';
	END IF;

	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT x509_certificate_regresssion();
-- set search_path=jazzhands;
DROP FUNCTION x509_certificate_regresssion();

ROLLBACK TO x509_tests;

\t off
