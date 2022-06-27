/*
 * Copyright (c) 2016 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION set_x509_certificate_ski_and_hashes()
RETURNS TRIGGER AS $$
DECLARE
	_hashes JSONB;
	_pkhid jazzhands.public_key_hash.public_key_hash_id%TYPE;
	_ski jazzhands.x509_signed_certificate.subject_key_identifier%TYPE;
BEGIN
	BEGIN
		IF NEW.public_key IS NOT NULL THEN
			_hashes := x509_plperl_cert_utils.get_public_key_hashes(NEW.public_key);
			_pkhid := x509_hash_manip.get_or_create_public_key_hash_id(_hashes);
			_ski := x509_plperl_cert_utils.get_public_key_ski(NEW.public_key);

			IF NEW.public_key_hash_id IS NOT NULL THEN
				IF NEW.public_key_hash_id IS DISTINCT FROM _pkhid THEN
					RAISE EXCEPTION 'public_key_hash_id does not match public_key'
					USING ERRCODE = 'data_exception';
				END IF;
			ELSE
				NEW.public_key_hash_id := _pkhid;
			END IF;

			IF NEW.subject_key_identifier IS NOT NULL THEN
				IF NEW.subject_key_identifier IS DISTINCT FROM _ski THEN
					RAISE EXCEPTION 'subject_key_identifier does not match public_key'
					USING ERRCODE = 'data_exception';
				END IF;
			ELSE
				NEW.subject_key_identifier := _ski;
			END IF;
		END IF;
	EXCEPTION
		WHEN undefined_function OR invalid_schema_name THEN NULL;
	END;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_x509_signed_set_ski_and_hashes ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_set_ski_and_hashes
	BEFORE INSERT OR UPDATE OF public_key, public_key_hash_id, subject_key_identifier
	ON x509_signed_certificate
	FOR EACH ROW
	EXECUTE PROCEDURE set_x509_certificate_ski_and_hashes();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION set_x509_certificate_private_key_id()
RETURNS TRIGGER AS $$
BEGIN
	UPDATE x509_signed_certificate x SET private_key_id = pk.private_key_id
	FROM private_key pk WHERE x.public_key_hash_id = pk.public_key_hash_id
	AND x.private_key_id IS NULL AND x.x509_signed_certificate_id = NEW.x509_signed_certificate_id;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_x509_signed_set_private_key_id ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_set_private_key_id
	AFTER INSERT OR UPDATE OF public_key, public_key_hash_id
	ON x509_signed_certificate
	FOR EACH ROW
	EXECUTE PROCEDURE set_x509_certificate_private_key_id();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION set_csr_hashes()
RETURNS TRIGGER AS $$
DECLARE
	_hashes JSONB;
	_pkhid jazzhands.certificate_signing_request.public_key_hash_id%TYPE;
BEGIN
	BEGIN
		_hashes := x509_plperl_cert_utils.get_csr_hashes(NEW.certificate_signing_request);
		_pkhid := x509_hash_manip.get_or_create_public_key_hash_id(_hashes);
		IF NEW.public_key_hash_id IS NOT NULL THEN
			IF NEW.public_key_hash_id IS DISTINCT FROM _pkhid THEN
				RAISE EXCEPTION 'public_key_hash_id does not match certificate_signing_request'
				USING ERRCODE = 'data_exception';
			END IF;
		ELSE
			NEW.public_key_hash_id := _pkhid;
		END IF;
	EXCEPTION
		WHEN undefined_function OR invalid_schema_name THEN NULL;
	END;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_csr_set_hashes ON certificate_signing_request;
CREATE TRIGGER trigger_csr_set_hashes
	BEFORE INSERT OR UPDATE OF certificate_signing_request, public_key_hash_id
	ON certificate_signing_request
	FOR EACH ROW
	EXECUTE PROCEDURE set_csr_hashes();

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION set_x509_certificate_fingerprints()
RETURNS TRIGGER AS $$
DECLARE
	_fingerprints JSONB;
	_cnt INTEGER;
BEGIN
	BEGIN
		IF NEW.public_key IS NOT NULL THEN
			_fingerprints := x509_plperl_cert_utils.get_public_key_fingerprints(NEW.public_key);
			_cnt := x509_hash_manip.set_x509_signed_certificate_fingerprints(NEW.x509_signed_certificate_id, _fingerprints);
		END IF;
	EXCEPTION
		WHEN undefined_function OR invalid_schema_name THEN NULL;
	END;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_x509_signed_set_fingerprints ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_set_fingerprints
	AFTER INSERT OR UPDATE OF public_key
	ON x509_signed_certificate
	FOR EACH ROW
	EXECUTE PROCEDURE set_x509_certificate_fingerprints();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION delete_dangling_public_key_hashes()
RETURNS TRIGGER AS $$
BEGIN
	DELETE FROM public_key_hash_hash
	WHERE public_key_hash_id NOT IN (
		SELECT public_key_hash_id
		FROM x509_signed_certificate
		WHERE public_key_hash_id IS NOT NULL
	) AND public_key_hash_id NOT IN (
		SELECT public_key_hash_id
		FROM private_key
		WHERE public_key_hash_id IS NOT NULL
	) AND public_key_hash_id NOT IN (
		SELECT public_key_hash_id
		FROM certificate_signing_request
		WHERE public_key_hash_id IS NOT NULL
	);

	DELETE FROM public_key_hash
	WHERE public_key_hash_id NOT IN (
		SELECT public_key_hash_id
		FROM x509_signed_certificate
		WHERE public_key_hash_id IS NOT NULL
	) AND public_key_hash_id NOT IN (
		SELECT public_key_hash_id
		FROM private_key
		WHERE public_key_hash_id IS NOT NULL
	) AND public_key_hash_id NOT IN (
		SELECT public_key_hash_id
		FROM certificate_signing_request
		WHERE public_key_hash_id IS NOT NULL
	);

	RETURN NULL;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_x509_signed_delete_dangling_hashes ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_delete_dangling_hashes
	AFTER DELETE OR UPDATE OF public_key_hash_id
	ON x509_signed_certificate
	FOR EACH STATEMENT
	EXECUTE PROCEDURE delete_dangling_public_key_hashes();

DROP TRIGGER IF EXISTS trigger_private_key_delete_dangling_hashes ON private_key;
CREATE TRIGGER trigger_private_key_delete_dangling_hashes
	AFTER DELETE OR UPDATE OF public_key_hash_id
	ON private_key
	FOR EACH STATEMENT
	EXECUTE PROCEDURE delete_dangling_public_key_hashes();
