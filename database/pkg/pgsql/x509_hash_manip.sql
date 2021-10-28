-- Copyright (c) 2021, Bernard Jech
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

\set ON_ERROR_STOP

DO $$
BEGIN
	CREATE SCHEMA x509_hash_manip AUTHORIZATION jazzhands;
	REVOKE ALL ON SCHEMA x509_hash_manip FROM public;
	COMMENT ON SCHEMA x509_hash_manip IS 'part of jazzhands';
EXCEPTION
	WHEN duplicate_schema THEN NULL;
END $$;

DO $$
BEGIN
	CREATE TYPE x509_hash_manip.algorithm_hash_tuple AS (
		algorithm VARCHAR(255),
		hash_value VARCHAR(255)
	);
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

-------------------------------------------------------------------------------
--
-- Make sure the specified hashes are present in public_key_hash_hash.
-- Add a row to public_key_hash if necessary. Returns public_key_hash_id.
--
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION x509_hash_manip.get_public_key_hash_id (
	hashes x509_hash_manip.algorithm_hash_tuple[]
) RETURNS jazzhands.public_key_hash.public_key_hash_id%TYPE AS $$
DECLARE
	_cnt BIGINT;
	_pkhid jazzhands.public_key_hash.public_key_hash_id%TYPE;
BEGIN
	WITH x AS ( SELECT unnest(hashes) AS hav )
	SELECT count(DISTINCT pkhh.public_key_hash_id),
		min(pkhh.public_key_hash_id)
	INTO _cnt, _pkhid
	FROM jazzhands.public_key_hash_hash pkhh JOIN x
	ON  (x.hav::x509_hash_manip.algorithm_hash_tuple).hash_value
		= pkhh.calculated_hash
	AND (x.hav::x509_hash_manip.algorithm_hash_tuple).algorithm
		= pkhh.x509_fingerprint_hash_algorighm;

	IF _cnt = 0 THEN
		INSERT INTO jazzhands.public_key_hash(description) VALUES(NULL)
		RETURNING public_key_hash_id INTO _pkhid;
	ELSIF _cnt > 1 THEN
		RAISE EXCEPTION 'multiple public_key_hash_id values found'
		USING ERRCODE = 'data_exception';
	END IF;

	WITH x AS ( SELECT unnest(hashes) AS hav )
	INSERT INTO jazzhands.public_key_hash_hash(
		public_key_hash_id,
		x509_fingerprint_hash_algorighm, calculated_hash
	) SELECT _pkhid,
		(x.hav::x509_hash_manip.algorithm_hash_tuple).algorithm,
		(x.hav::x509_hash_manip.algorithm_hash_tuple).hash_value
	FROM x
	ON CONFLICT(public_key_hash_id, x509_fingerprint_hash_algorighm)
	DO NOTHING;

RETURN _pkhid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO jazzhands;

-------------------------------------------------------------------------------
--
-- Make sure the specified hashes are present in public_key_hash_hash
-- Add a row to public_key_hash if necessary. Update public_key_hash_id
-- of the specified private key if it needs to be updated.
--
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION x509_hash_manip.set_private_key_hashes (
	private_key_id private_key.private_key_id%TYPE,
	hashes x509_hash_manip.algorithm_hash_tuple[]
) RETURNS INTEGER AS $$
DECLARE
	_pkhid jazzhands.public_key_hash_hash.public_key_hash_id%TYPE;
	_cnt INTEGER;
BEGIN
	_pkhid := x509_hash_manip.get_public_key_hash_id(hashes);

	UPDATE private_key p SET public_key_hash_id = _pkhid
	WHERE p.private_key_id = set_private_key_hash.private_key_id
	AND public_key_hash_id IS DISTINCT FROM _pkhid;

	GET DIAGNOSTICS _cnt = ROW_COUNT;

	RETURN _cnt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO jazzhands;

-------------------------------------------------------------------------------
--
-- Make sure the specified hashes are present in public_key_hash_hash
-- Add a row to public_key_hash if necessary. Update public_key_hash_id
-- of the specified x509_signed_certificate if it needs to be updated.
--
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION x509_hash_manip.set_x509_signed_certificate_hashes (
	x509_cert_id jazzhands.x509_signed_certificate.x509_signed_certificate_id%TYPE,
	hashes x509_hash_manip.algorithm_hash_tuple[]
) RETURNS INTEGER AS $$
DECLARE
	_pkhid jazzhands.public_key_hash_hash.public_key_hash_id%TYPE;
	_cnt INTEGER;
BEGIN
	_pkhid := x509_hash_manip.get_public_key_hash_id(hashes);

	UPDATE x509_signed_certificate SET public_key_hash_id = _pkhid
	WHERE x509_signed_certificate_id = x509_cert_id
	AND public_key_hash_id IS DISTINCT FROM _pkhid;

	GET DIAGNOSTICS _cnt = ROW_COUNT;

	RETURN _cnt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO jazzhands;

-------------------------------------------------------------------------------
--
-- UPSERT the specified fingerprints into x509_signed_certificate_fingerprint
--
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION x509_hash_manip.set_x509_signed_certificate_fingerprints (
	x509_cert_id jazzhands.x509_signed_certificate.x509_signed_certificate_id%TYPE,
	fingerprints x509_hash_manip.algorithm_hash_tuple[]
) RETURNS INTEGER AS $$
DECLARE _cnt INTEGER;
BEGIN
	WITH x AS ( SELECT unnest(fingerprints) AS hav )
	INSERT INTO x509_signed_certificate_fingerprint AS fp (
		x509_signed_certificate_id,
		x509_fingerprint_hash_algorighm, fingerprint
	) SELECT x509_cert_id,
		(x.hav::x509_hash_manip.algorithm_hash_tuple).algorithm,
		(x.hav::x509_hash_manip.algorithm_hash_tuple).hash_value
	FROM x
	ON CONFLICT (
	    x509_signed_certificate_id, x509_fingerprint_hash_algorighm
	) DO UPDATE SET fingerprint = EXCLUDED.fingerprint
	WHERE fp.fingerprint IS DISTINCT FROM EXCLUDED.fingerprint;

	GET DIAGNOSTICS _cnt = ROW_COUNT;

	RETURN _cnt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO jazzhands;

REVOKE ALL ON SCHEMA x509_hash_manip  FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA x509_hash_manip FROM public;

GRANT USAGE ON SCHEMA x509_hash_manip TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA x509_hash_manip TO iud_role;
