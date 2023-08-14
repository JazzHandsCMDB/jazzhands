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

\set ON_ERROR_STOP

DO $$
BEGIN
	CREATE SCHEMA x509_manip AUTHORIZATION jazzhands;
	REVOKE ALL ON SCHEMA x509_manip FROM public;
	COMMENT ON SCHEMA x509_manip IS 'part of jazzhands';
EXCEPTION
	WHEN duplicate_schema THEN NULL;
END $$;

---
--- This is pretty much lifted from
--- https://stackoverflow.com/questions/33486595/postgresql-convert-hex-string-of-a-very-large-number-to-a-numeric
---
CREATE OR REPLACE FUNCTION hex_to_numeric (hexval TEXT)
RETURNS NUMERIC (1000)
AS $$
DECLARE
    intVal		NUMERIC(1000) := 0;
    hexLength	INTEGER;
    i			iNTEGER;
    hexDigit	TEXT;
BEGIN
	IF hexval IS NULL THEN
		RETURN NULL;
	END IF;

    hexLength := length(hexval);
    FOR i IN 1..hexLength LOOP
        hexDigit := substr(hexVal, hexLength - i + 1, 1);
        intVal := intVal + CASE WHEN hexDigit BETWEEN '0' AND '9' THEN
            CAST(hexDigit AS numeric(1000))
        WHEN upper(hexDigit) BETWEEN 'A' AND 'F' THEN
            CAST(ascii(upper(hexDigit)) - 55 AS numeric(1000))
        END * CAST(16 AS numeric(1000)) ^ CAST(i - 1 AS numeric(1000));
    END LOOP;
    RETURN intVal;
END;
$$
LANGUAGE 'plpgsql'
SECURITY INVOKER IMMUTABLE STRICT;

----------------------------------------------------------------------------
---
--- given a PEM style x509 signed certificate, and optionally a breakdown of
--- its component prts in json, insert it into the database
---
--- The parsed argument is optional and only needs to be set if pl/perl is not
--- enbled in the database.
---
--- See database/pkg/pgsql/x509_plperl_cert_utils.sql for the formatting
---
----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION x509_manip.insert_x509_certificate (
	certificate	TEXT,
	parsed		JSONB DEFAULT NULL,
	public_key_hashes		 JSONB DEFAULT NULL
) RETURNS x509_signed_certificate AS $$
DECLARE
	_x509			x509_signed_certificate;
	_parsed			JSONB;
	_pubkeyhashes	JSONB;
	_pkid			private_key.private_key_id%TYPE;
	_csrid			private_key.private_key_id%TYPE;
	_ca				x509_signed_certificate.x509_signed_certificate_id%TYPE;
	_caserial		NUMERIC(1000);
	_e				JSONB;
	field			TEXT;
BEGIN
	BEGIN
		_parsed := x509_plperl_cert_utils.parse_x509_certificate(
			certificate := insert_x509_certificate.certificate
		);

		_pubkeyhashes := x509_plperl_cert_utils.get_public_key_hashes(
			insert_x509_certificate.certificate
		);

		IF parsed IS NOT NULL OR public_key_hashes IS NOT NULL THEN
			RAISE EXCEPTION 'Database is configured to parse the certificate, so the second option is not permitted'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF _parsed IS NULL OR _pubkeyhashes IS NULL THEN
			RAISE EXCEPTION 'X509 Certificate is invalid or something fundemental was wrong with parsing' 
				USING ERRCODE = 'data_exception';
		END IF;
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		IF parsed IS NULL OR public_key_hashes IS NULL THEN
			RAISE EXCEPTION 'Must pass summary/fingerprint json about certificate because pl/perl module not setup.'
				USING ERRCODE = 'invalid_parameter_value',
				HINT = format('%s %s', SQLSTATE, SQLERRM);
		ELSE
			_parsed := parsed;
			_pubkeyhashes := public_key_hashes;
		END IF;
	END;

	FOREACH field IN ARRAY ARRAY[
		'self_signed',
		'subject',
		'friendly_name',
		'subject_key_identifier',
		'is_ca',
		'valid_from', 
		'valid_to']
	LOOP
		IF NOT _parsed ? field THEN
			RAISE EXCEPTION 'Must include % parameter', field
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END LOOP;

	---
	--- arguably self signing certs should point to themselves...
	---
	IF _parsed->>'self_signed' IS NULL THEN
		IF NOT _parsed ? 'issuer' OR _parsed->>'issuer' IS NULL THEN
			RAISE EXCEPTION 'Must include issuer'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF NOT _parsed ? 'serial' OR _parsed->>'serial' IS NULL THEN
			RAISE EXCEPTION 'Must serial number'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		SELECT x509_signed_certificate_id
		INTO _ca
		FROM x509_signed_certificate
		WHERE subject = _parsed->>'issuer'
		AND subject_key_identifier = _parsed->>'authority_key_identifier'
		LIMIT 1;

		_caserial := hex_to_numeric(_parsed->>'serial');
	ELSE
		_ca := NULL;
		_caserial := NULL;
	END IF;
		

	FOR _e IN SELECT jsonb_array_elements(_pubkeyhashes)
	LOOP
		SELECT pk.private_key_id
		INTO _pkid
		FROM	private_key pk
			JOIN public_key_hash USING (public_key_hash_id)
			JOIN public_key_hash_hash USING (public_key_hash_id)
			LEFT JOIN x509_signed_certificate x509 USING (public_key_hash_id)
		WHERE cryptographic_hash_algorithm = _e->>'algorithm'
		AND calculated_hash = _e->>'hash'
		ORDER BY 
			CASE WHEN x509.is_active THEN 0 ELSE 1 END,
			CASE WHEN x509.x509_signed_certificate_id IS NULL THEN 0 ELSE 1 END,
			pk.data_upd_date desc, pk.data_ins_date desc;
		IF FOUND THEN
			EXIT;
		END IF;
	END LOOP;

	--- This is kind of gross because it just finds the newest one and
	---	associates it
	FOR _e IN SELECT jsonb_array_elements(_pubkeyhashes)
	LOOP
		SELECT csr.certificate_signing_request_id
		INTO _csrid
		FROM	certificate_signing_request csr
			JOIN public_key_hash USING (public_key_hash_id)
			JOIN public_key_hash_hash USING (public_key_hash_id)
			LEFT JOIN x509_signed_certificate x509 USING (public_key_hash_id)
		WHERE cryptographic_hash_algorithm = _e->>'algorithm'
		AND calculated_hash = _e->>'hash'
		ORDER BY 
			CASE WHEN x509.is_active THEN 0 ELSE 1 END,
			CASE WHEN x509.x509_signed_certificate_id IS NULL THEN 0 ELSE 1 END,
			csr.data_upd_date desc, csr.data_ins_date desc;

		IF FOUND THEN
			EXIT;
		END IF;
	END LOOP;

	INSERT INTO x509_signed_certificate (
		x509_certificate_type, subject, friendly_name, 
		subject_key_identifier,
		is_certificate_authority,
		signing_cert_id, x509_ca_cert_serial_number,
		public_key, certificate_signing_request_id, private_key_id,
		valid_from, valid_to
	) VALUES (
		'default', _parsed->>'subject', _parsed->>'friendly_name',
		_parsed->>'subject_key_identifier',
		CASE WHEN _parsed->>'is_ca' IS NULL THEN false ELSE true END,
		_ca, _caserial,
		insert_x509_certificate.certificate, _csrid, _pkid,
		CAST(_parsed->>'valid_from' AS TIMESTAMP),
		CAST(_parsed->>'valid_to' AS TIMESTAMP)
	) RETURNING * INTO _x509;

	FOR _e IN SELECT jsonb_array_elements(_parsed->'keyUsage')
	LOOP
			---
			--- This is a little wonky.
			---
		    INSERT INTO x509_key_usage_attribute (
			 	x509_signed_certificate_id, x509_key_usage, 
				x509_key_usgage_category
			) SELECT _x509.x509_signed_certificate_id, _e #>>'{}',
				x509_key_usage_category
			FROM x509_key_usage_categorization
			WHERE x509_key_usage_category =  _e #>>'{}'
			ORDER BY 
				CASE WHEN x509_key_usage_category = 'ca' THEN 1
					WHEN x509_key_usage_category = 'revocation' THEN 2
					WHEN x509_key_usage_category = 'application' THEN 3
					WHEN x509_key_usage_category = 'service' THEN 4
					ELSE 5 END,
				x509_key_usage_category
			LIMIT 1;
	END LOOP;

	RETURN _x509;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO jazzhands;


----------------------------------------------------------------------------
---
--- given a PEM style certificate signing request, and optionally a breakdown 
--- of its component prts in json, insert it into the database
---
--- The parsed argument is optional and only needs to be set if pl/perl is not
--- enbled in the database.
---
--- See database/pkg/pgsql/x509_plperl_cert_utils.sql for the formatting
---
--- XXX - consider whether or not to link existing CAs  flag?
---
--- XXX - idempotent??
----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION x509_manip.insert_csr (
	csr			TEXT,
	parsed		JSONB DEFAULT NULL,
	public_key_hashes JSONB DEFAULT NULL
) RETURNS certificate_signing_request AS $$
DECLARE
	_csr			certificate_signing_request;
	_parsed			JSONB;
	_pubkeyhashes	JSONB;
	_pkid			private_key.private_key_id%TYPE;
	_ca				x509_signed_certificate.x509_signed_certificate_id%TYPE;
	_e				JSONB;
	field			TEXT;
BEGIN
	BEGIN
		_parsed := x509_plperl_cert_utils.parse_csr(
			certificate_signing_request := insert_csr.csr
		);

		_pubkeyhashes := x509_plperl_cert_utils.get_csr_hashes(
			insert_csr.csr
		);

		IF parsed IS NOT NULL OR public_key_hashes IS NOT NULL THEN
			RAISE EXCEPTION 'Database is configured to parse the CSR, so the second option is not permitted'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF _parsed IS NULL OR _pubkeyhashes IS NULL THEN
			RAISE EXCEPTION 'Certificate Signing Request is invalid or something fundemental was wrong with parsing' 
				USING ERRCODE = 'data_exception';
		END IF;
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		IF parsed IS NULL OR public_key_hashes IS NULL THEN
			RAISE EXCEPTION 'Must pass summary/fingerprint json about CSR because pl/perl module not setup.'
				USING ERRCODE = 'invalid_parameter_value',
				HINT = format('%s %s', SQLSTATE, SQLERRM);
		ELSE
			_parsed := parsed;
			_pubkeyhashes := public_key_hashes;
		END IF;
	END;

	FOREACH field IN ARRAY ARRAY[
		'subject',
		'friendly_name']
	LOOP
		IF NOT _parsed ? field THEN
			RAISE EXCEPTION 'Must include % parameter', field
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END LOOP;

	FOR _e IN SELECT jsonb_array_elements(_pubkeyhashes)
	LOOP
		SELECT pk.private_key_id
		INTO _pkid
		FROM	private_key pk
			JOIN public_key_hash USING (public_key_hash_id)
			JOIN public_key_hash_hash USING (public_key_hash_id)
			LEFT JOIN x509_signed_certificate x509 USING (public_key_hash_id)
		WHERE cryptographic_hash_algorithm = _e->>'algorithm'
		AND calculated_hash = _e->>'hash'
		ORDER BY 
			CASE WHEN x509.is_active THEN 0 ELSE 1 END,
			CASE WHEN x509.x509_signed_certificate_id IS NULL THEN 0 ELSE 1 END,
			pk.data_upd_date desc, pk.data_ins_date desc;
		IF FOUND THEN
			EXIT;
		END IF;
	END LOOP;

	INSERT INTO certificate_signing_request (
		friendly_name, subject, certificate_signing_request, private_key_id
	) VALUES (
		_parsed->>'friendly_name', _parsed->>'subject', csr, _pkid
	) RETURNING * INTO _csr;

	RETURN _csr;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO jazzhands;

----------------------------------------------------------------------------
REVOKE ALL ON SCHEMA x509_manip  FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA x509_manip FROM public;

GRANT USAGE ON SCHEMA x509_manip TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA x509_manip TO iud_role;
