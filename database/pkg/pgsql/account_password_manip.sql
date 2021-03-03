/*
 * Copyright (c) 2020 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *	  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * $Id$
 */

-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'account_password_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS account_password_manip;
		CREATE SCHEMA account_password_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA account_password_manip IS 'part of jazzhands';
		REVOKE ALL ON SCHEMA account_password_manip FROM public;
	END IF;
END;
$$;

--------------------------------------------------------------------------------
--
-- returns true if the provided password is one of the valid ones from the
-- user based on the routines that the db knows how to use.
--
-- raiseexception causes an exception to be raised if the user has no passwords
-- set, otherwise the user fails to authenticate.
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION account_password_manip.authenticate_account (
	account_id			INTEGER,
	password			TEXT,
	encode_method		TEXT DEFAULT 'aes-cbc/pad:pkcs',
	label				TEXT DEFAULT 'default',
	raiseexception		BOOLEAN default false
) RETURNS BOOLEAN AS $$
DECLARE
	plainpw	TEXT;
	crypt	TEXT;
	method	TEXT;
	_tally	INTEGER;	
BEGIN
	--
	-- decode the password into plaintext
	--
	plainpw := obfuscation_utils.deobfuscate_text (encoded := password,
		type := encode_method,
		label := label);

	--
	-- go through all of this user's passwords  that the database is capable
	-- of decoding.  This list should probably be expanded.
	--
	_tally := 0;
	FOR crypt, method IN SELECT  a.password, a.password_type
		FROM	account_password a
		WHERE	a.account_id = authenticate_account.account_id
		AND		password_type IN ( 'cryptMD5', 'blowfish', 
					'xdes', 'postgresMD5')
	LOOP
		IF pgcrypto.crypt(plainpw, crypt) = crypt THEN
			RETURN true;
		END IF;
		_tally := _tally+ 1;
	END LOOP;
	IF raiseexception AND _tally = 0 THEN
		RAISE EXCEPTION 'User has no passwords set'
			USING ERRCODE = 'cardinality_violation';
	END IF;
	RETURN false;
END;
$$
LANGUAGE plpgsql
SET search_path=jazzhands
SECURITY DEFINER;


--------------------------------------------------------------------------------
--
-- check to see if a password was previously used for an account.
--
-- looks through all possible old crypts that the db can figure out.
--
-- returns true if the password is previously unused, false if not
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION account_password_manip.check_account_password_reuse (
	account_id			INTEGER,
	password			TEXT,
	encode_method		TEXT DEFAULT 'pgp+base64',
	label				TEXT DEFAULT 'default',
	age					INTERVAL DEFAULT '0'
) RETURNS BOOLEAN AS $$
DECLARE
	plainpw	TEXT;
	crypt	TEXT;
	method	TEXT;
BEGIN
	--
	-- decode the password into plaintext
	--
	plainpw := obfuscation_utils.deobfuscate_text (encoded := password,
		type := encode_method,
		label := label);

	--
	-- go through all of this user's passwords  that the database is capable
	-- of decoding.  This list should probably be expanded.
	--
	FOR crypt, method IN SELECT  a.password, a.password_type
		FROM	audit.account_password a
		WHERE	a.account_id = check_account_password_reuse.account_id
		AND		"aud#action" IN ('INS','UPD')
		AND		password_type IN ( 'cryptMD5', 'blowfish', 
					'xdes', 'postgresMD5')
		AND		"aud#timestamp" <= now() - age
		ORDER BY "aud#timestamp" DESC
	LOOP
		IF pgcrypto.crypt(plainpw, crypt) = crypt THEN
			RETURN false;
		END IF;
	END LOOP;
	RETURN true;
END;
$$
LANGUAGE plpgsql
SET search_path=jazzhands
SECURITY DEFINER;

--------------------------------------------------------------------------------
-- set password(s) for an account.  This includes ones that can be done from the
-- db plus user overrides.
--
-- if a crypt is set to undef, it gets deleted.
-- if racecatch is set and one of the current known crypts matches and the
-- 	change time is within sixty seconds, return success.
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION account_password_manip.set_account_passwords (
	account_id			INTEGER,
	password			TEXT,
	encode_method		TEXT DEFAULT 'pgp+base64',
	change_time			TIMESTAMP DEFAULT now(),
	expire_time			TIMESTAMP DEFAULT NULL,
	crypts				JSONB DEFAULT '{}',
	label				TEXT DEFAULT 'default',
	purge				BOOLEAN DEFAULT TRUE,
	racecatch			BOOLEAN DEFAULT FALSE
) RETURNS INTEGER AS $$
DECLARE
	len			INTEGER;
	acid		account_collection.account_collection_id%TYPE;
	proplen		INTEGER;
	pwtype		TEXT;
	plainpw		TEXT;
	method		TEXT;
	value		TEXT;
	p_method	TEXT;
	p_value		TEXT;
	cols		TEXT[];
	vals		TEXT[];
	done		TEXT[];
	passed		TEXT[];
	upd			TEXT[];
	login		TEXT;
	curcrypt	TEXT[];
	_tally		INTEGER;
	_r			RECORD;
BEGIN
	--
	-- lock all the passwords for UPDATE.  Also keep track of all the recent
	--
	FOR _r IN SELECT ap.password, now()- ap.change_time <= '5 minutes'::interval AS recent
		FROM account_password ap 
		WHERE ap.account_id = set_account_passwords.account_id FOR UPDATE
	LOOP
		IF _r.recent THEN
			curcrypt := curcrypt || _r.password::text;
		END IF;
	END LOOP;


	--
	-- decode the password into plaintext
	--
	plainpw := obfuscation_utils.deobfuscate_text (encoded := password,
		type := encode_method,
		label := label);
	len := character_length(plainpw);

	IF racecatch AND curcrypt IS NOT NULL THEN
		FOREACH value IN ARRAY curcrypt LOOP
			IF pgcrypto.crypt(plainpw, value) = value THEN
				RETURN 1;
			END IF;
		END LOOP;
	END IF;
	value := NULL;

	-- figure out crypts that need to be added that we can handle
	--
	SELECT array_agg(KEY) INTO passed FROM jsonb_each_text(crypts);
	FOR pwtype IN SELECT property_value_password_type FROM property WHERE property_name = 'managedpwtype' AND property_type = 'Defaults'
	LOOP
		IF pwtype = SOME (passed) THEN
			CONTINUE;
		END IF;
		-- XXX - reallyneed to add SCRAM-SHA-256 for postgres. possibly 
		-- mysql and others since they're probably easy
		IF pwtype = 'cryptMD5' THEN
			crypts := jsonb_insert (crypts,
				ARRAY [ pwtype ],
				concat('"', pgcrypto.crypt(PASSWORD, pgcrypto.gen_salt('md5')), '"')::jsonb);
		ELSIF pwtype = 'blowfish' THEN
			crypts := jsonb_insert (crypts,
				ARRAY [ pwtype ],
				concat('"', pgcrypto.crypt(PASSWORD, pgcrypto.gen_salt('bf')), '"')::jsonb);
		ELSIF pwtype = 'xdes' THEN
			crypts := jsonb_insert (crypts,
				ARRAY [ pwtype ],
				concat('"', pgcrypto.crypt(PASSWORD, pgcrypto.gen_salt('xdes')), '"')::jsonb);
		ELSIF pwtype = 'postgresMD5' THEN
			SELECT	a.login INTO LOGIN
			FROM	account a
			WHERE	a.account_id = set_account_passwords.account_id;
			crypts := jsonb_insert (crypts,
				ARRAY [ pwtype ],
				concat('"md5', md5(concat(PASSWORD, LOGIN)), '"')::jsonb);
		ELSE
			RAISE EXCEPTION 'Unknown pwtype %', pwtype
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END LOOP;

	_tally := 0;
	FOR method, value IN SELECT * FROM jsonb_each_text(crypts)
		LOOP
			IF value IS NULL THEN
				DELETE FROM account_password ap WHERE password_type = method AND ap.account_id = set_account_passwords.account_id;
				CONTINUE;
			END IF;
			p_method := quote_nullable(method);
			p_value := quote_nullable(value);
			cols := ARRAY [ 'password_type', 'password', 'account_id' ];
			vals := ARRAY [ p_method, p_value, '$1' ];
			upd := ARRAY [ 'password_type = ' || p_method, 'password = ' || p_value ];

			IF change_time IS NOT NULL THEN
				cols := cols || quote_ident('change_time');
				vals := vals || quote_nullable(change_time);
				upd := upd || concat('change_time = ',
					 quote_nullable(change_time));

				--
				-- for any password changing, set the expire time so it 
				-- can fall back on default policy, even on NULL
				--
				cols := cols || quote_ident('expire_time');
				vals := vals || quote_nullable(expire_time);
				upd := upd || concat('expire_time = ',
					 quote_nullable(expire_time));
			END IF;
			--
			-- note that account_id is passed in as an argument
			--
			EXECUTE 'INSERT INTO account_password (' || 
					array_to_string(cols, ',') || ' ) VALUES ( ' || 
					array_to_string(vals, ',') || 
					') ON CONFLICT ON CONSTRAINT pk_accunt_password DO UPDATE SET ' || 
					array_to_string(upd, ',')
				USING account_id;
			done := done || method;
			_tally := _tally + 1;
		END LOOP;
	IF purge THEN
		DELETE FROM account_password
		WHERE account_password.account_id = set_account_passwords.account_id
			AND NOT password_type = ANY (done);
	END IF;
	--
	-- This is probably a hack that needs revisiting
	--
	FOR acid, proplen IN SELECT account_collection_id, property_value
		FROM property
		WHERE property_type = 'account-override'
		AND property_name = 'password_expiry_days'
		ORDER BY property_value::integer desc
	LOOP
		IF len >= proplen THEN
			--
			-- conflict means that they are already a part of this.
			--
			INSERT INTO account_collection_account (
				account_collection_id, account_id
			) VALUES (
				acid, set_account_passwords.account_id
			) ON CONFLICT ON CONSTRAINT pk_account_collection_user DO NOTHING;
		ELSE
			DELETE FROM account_collection_account ac 
				WHERE ac.account_collection_id = acid 
				AND ac.account_id = set_account_passwords.account_id;
		END IF;
	END LOOP;
	RETURN _tally;
END;
$$
LANGUAGE plpgsql
SET search_path=jazzhands
SECURITY DEFINER;

REVOKE ALL ON SCHEMA account_password_manip FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA account_password_manip FROM public;

GRANT USAGE ON SCHEMA account_password_manip TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA account_password_manip TO iud_role;
