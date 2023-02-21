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

-------------------------------------------------------------------------------
--
-- Validate parameter "hashes" against JSON schema
--
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION x509_hash_manip._validate_parameter_hashes (
	hashes jsonb
) RETURNS BOOLEAN AS $$
DECLARE
	_res BOOLEAN;
BEGIN
	_res := validate_json_schema(
		$json$ {
			"type": "array",
			"items": {
				"type": "object",
				"properties": {
					"algorithm": { "type": "string" },
					"hash":	     { "type": "string" }
				}
			}
		} $json$::jsonb, hashes
	);

	RETURN _res;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO jazzhands;

-------------------------------------------------------------------------------
--
-- Make sure the specified hashes are present in public_key_hash_hash.
-- Add a row to public_key_hash if necessary. Returns public_key_hash_id.
--
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION x509_hash_manip.get_or_create_public_key_hash_id (
	hashes jsonb
) RETURNS jazzhands.public_key_hash.public_key_hash_id%TYPE AS $$
DECLARE
	_cnt BIGINT;
	_pkhid jazzhands.public_key_hash.public_key_hash_id%TYPE;
BEGIN
	IF NOT x509_hash_manip._validate_parameter_hashes(hashes) THEN
		RAISE EXCEPTION 'parameter "hashes" does not match JSON schema'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	WITH x AS (
		SELECT algorithm, hash
		FROM jsonb_to_recordset(hashes)
		AS jr(algorithm text, hash text)
	) SELECT count(DISTINCT pkhh.public_key_hash_id),
		min(pkhh.public_key_hash_id)
	INTO _cnt, _pkhid
	FROM jazzhands.public_key_hash_hash pkhh JOIN x
	ON  x.algorithm = pkhh.x509_fingerprint_hash_algorighm
	AND x.hash = pkhh.calculated_hash;

	IF _cnt = 0 THEN
		INSERT INTO jazzhands.public_key_hash(description) VALUES(NULL)
		RETURNING public_key_hash_id INTO _pkhid;
	ELSIF _cnt > 1 THEN
		RAISE EXCEPTION 'multiple public_key_hash_id values found'
		USING ERRCODE = 'data_exception';
	END IF;

	WITH x AS (
		SELECT algorithm, hash
		FROM jsonb_to_recordset(hashes)
		AS jr(algorithm text, hash text)
	) INSERT INTO jazzhands.public_key_hash_hash AS pkhh (
		public_key_hash_id,
		x509_fingerprint_hash_algorighm, calculated_hash
	) SELECT _pkhid, x.algorithm, x.hash FROM x
	ON CONFLICT(public_key_hash_id, x509_fingerprint_hash_algorighm)
	DO UPDATE SET calculated_hash = EXCLUDED.calculated_hash
	WHERE pkhh.calculated_hash IS DISTINCT FROM EXCLUDED.calculated_hash;

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
	hashes jsonb
) RETURNS INTEGER AS $$
DECLARE
	_pkhid jazzhands.public_key_hash_hash.public_key_hash_id%TYPE;
	_cnt INTEGER;
BEGIN
	_pkhid := x509_hash_manip.get_or_create_public_key_hash_id(hashes);

	UPDATE private_key p SET public_key_hash_id = _pkhid
	WHERE p.private_key_id = set_private_key_hashes.private_key_id
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
	hashes jsonb,
	update_private_key_hashes BOOLEAN DEFAULT false
) RETURNS INTEGER AS $$
DECLARE
	_pkid jazzhands.x509_signed_certificate.private_key_id%TYPE;
	_pkhid jazzhands.public_key_hash_hash.public_key_hash_id%TYPE;
	_cnt INTEGER;
BEGIN
	_pkhid := x509_hash_manip.get_or_create_public_key_hash_id(hashes);

	UPDATE x509_signed_certificate SET public_key_hash_id = _pkhid
	WHERE x509_signed_certificate_id = x509_cert_id
	AND public_key_hash_id IS DISTINCT FROM _pkhid
	RETURNING private_key_id INTO _pkid;

	GET DIAGNOSTICS _cnt = ROW_COUNT;

	IF update_private_key_hashes THEN
		RETURN _cnt + x509_hash_manip.set_private_key_hashes(_pkid, hashes);
	ELSE
		RETURN _cnt;
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO jazzhands;

-------------------------------------------------------------------------------
--
-- UPSERT the specified fingerprints into x509_signed_certificate_fingerprint
--
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION x509_hash_manip.set_x509_signed_certificate_fingerprints (
	x509_cert_id jazzhands.x509_signed_certificate.x509_signed_certificate_id%TYPE,
	fingerprints jsonb
) RETURNS INTEGER AS $$
DECLARE _cnt INTEGER;
BEGIN
	IF NOT x509_hash_manip._validate_parameter_hashes(fingerprints) THEN
		RAISE EXCEPTION 'parameter "fingerprints" does not match JSON schema'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	WITH x AS (
		SELECT algorithm, hash
		FROM jsonb_to_recordset(fingerprints)
		AS jr(algorithm text, hash text)
	) INSERT INTO x509_signed_certificate_fingerprint AS fp (
		x509_signed_certificate_id,
		x509_fingerprint_hash_algorighm, fingerprint
	) SELECT x509_cert_id, x.algorithm, x.hash FROM x
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
