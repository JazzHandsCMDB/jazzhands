/*
 * Copyright (c) 2020 Todd Kover
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

\set ON_ERROR_STOP

-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'obfuscation_utils';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS obfuscation_utils;
		CREATE SCHEMA obfuscation_utils AUTHORIZATION jazzhands;
		REVOKE ALL ON schema obfuscation_utils FROM public;
		COMMENT ON SCHEMA obfuscation_utils IS 'part of jazzhands';

	END IF;
END;
$$;


--
-- This returns a session key that can be used to encrypt arguments
-- to the database.  Its primary use is to encrypt arguments to
-- functions so that sensitive data does not get logged to the database
-- logs.   It is probably overkill forthis. 
--
CREATE OR REPLACE FUNCTION obfuscation_utils.get_session_secret(
	label TEXT DEFAULT 'default'
) RETURNS TEXT AS $$
DECLARE
	_key TEXT;
BEGIN
	BEGIN
		CREATE TEMPORARY TABLE __jazzhands_session_key__ (
			type text NOT NULL,
			role text NOT NULL,
			key text NOT NULL,
			PRIMARY KEY(type, role)
		);
	EXCEPTION WHEN SQLSTATE '42P07' THEN
		NULL;
	END;

	PERFORM setseed(1-extract(epoch from now())/extract(epoch from clock_timestamp()));
	BEGIN
		_key := substring(
			encode(pgcrypto.digest(random()::text, 'sha256'), 'base64'),
			1, 32);
	EXCEPTION WHEN invalid_schema_name THEN
		_key := substring(md5(random()::text), 1, 32);
	END;

	BEGIN
		-- This means no pgcrypto but we don't want things to fail...
		INSERT INTO __jazzhands_session_key__ (type, role,key) 
			VALUES (label, current_user, _key);
	EXCEPTION WHEN unique_violation THEN
		NULL;
	END;

	SELECT __jazzhands_session_key__.key 
		INTO _key 
		FROM __jazzhands_session_key__ 
		WHERE type = label
		AND role = current_user;
	RETURN(_key);
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;

--
-- This takes 'encoded' text and using the method described in 'type'
-- will pass it through deobfuscation/encryption routines.  For encrypted
-- methods, it's assumed that get_session_secret() was called to get a
-- secret earlier using the same (or no) label.  This is primarily used
-- to hide arguments so that query logs are sufficiently safe.
--
-- the pgp type can be problematic for VMs or things that have an issue
-- with entropy.
--
-- type pgp just passes through to pgcrypto.pgp_sym_decrypt_bytea.
-- pgp+base64 decosed base64 and passes to the same.  This is because
-- pgcrypto didn't deal with some armoring well.
--
-- The XX:cbc/pad:pkcs (bf and aes tested) just pass through to
-- pgcrypto.decrypt_iv .  Encoded is a mime64 encoded iv, followed by a
-- dash, followed bya mime64 encoded encrpyted string.
--
CREATE OR REPLACE FUNCTION obfuscation_utils.deobfuscate_text(
	encoded		text,
	type 		TEXT,
	label		TEXT DEFAULT 'default'
) RETURNS TEXT AS $$
DECLARE
	_key	BYTEA;
	_de	BYTEA;
	_iv	BYTEA;
	_enc	BYTEA;
	_parts	TEXT[];
	_len	INTEGER;
BEGIN
	_key := obfuscation_utils.get_session_secret(label)::text;
	IF type = 'base64' THEN
		RETURN decode(encoded, 'base64');
	ELSIF type ~ '^pgp' THEN
		IF  type = 'pgp+base64' THEN
			--
			-- not using armor because of compatablity issues with 
			-- Crypt::OpenPGP armoring that I gave up on.
			--
			encoded := decode(encoded, 'base64');
		END IF;
		IF _key IS NULL THEN
			RAISE EXCEPTION 'pgp requries setup';
		END IF;
		_de := pgcrypto.pgp_sym_decrypt_bytea(encoded::bytea, _key::text);
		RETURN encode(_de, 'escape');
	ELSIF type = 'none' THEN
		RETURN encoded;
	ELSIF type ~ 'cbc/pad:pkcs' THEN
		_parts := regexp_matches(encoded, '^([^-]+)-(.+)$');
		_iv := decode(_parts[1], 'base64');
		_enc := decode(_parts[2], 'base64');

		_de := pgcrypto.decrypt_iv(_enc::bytea, _key, _iv, type);
		RETURN encode(_de, 'escape');
	ELSE
		RAISE EXCEPTION 'unknown decryption type %', type
			USING ERRCODE = invalid_paramter;
	END IF;
	RETURN NULL;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;

REVOKE ALL ON SCHEMA obfuscation_utils  FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA obfuscation_utils  FROM public;

GRANT USAGE ON SCHEMA obfuscation_utils TO ro_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA obfuscation_utils TO ro_role;
