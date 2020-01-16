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

\set ON_ERROR_STOP

---------------------------------------------------------------------------
--
-- Triggers to drop > 0.72 to deal with x509 changes.
--
---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ins_x509_certificate()
RETURNS TRIGGER AS $$
DECLARE
	key	private_key.private_key_id%TYPE;
	csr	certificate_signing_request.certificate_signing_request_id%TYPE;
	crt	x509_signed_certificate.x509_signed_certificate_id%TYPE;
BEGIN
	IF NEW.private_key IS NOT NULL THEN
		INSERT INTO private_key (
			private_key_encryption_type,
			is_active,
			subject_key_identifier,
			private_key,
			passphrase,
			encryption_key_id
		) VALUES (
			'rsa',
			NEW.is_active,
			NEW.subject_key_identifier,
			NEW.private_key,
			NEW.passphrase,
			NEW.encryption_key_id
		) RETURNING private_key_id INTO key;
		NEW.x509_cert_id := key;
	ELSE
		IF NEW.subject_key_identifier IS NOT NULL THEN
			SELECT private_key_id
			INTO key
			FROM private_key
			WHERE subject_key_identifier = NEW.subject_key_identifier;

			SELECT private_key
			INTO NEW.private_key
			FROM private_key
			WHERE private_key_id = key;
		END IF;
	END IF;

	IF NEW.certificate_sign_req IS NOT NULL THEN
		INSERT INTO certificate_signing_request (
			friendly_name,
			subject,
			certificate_signing_request,
			private_key_id
		) VALUES (
			NEW.friendly_name,
			NEW.subject,
			NEW.certificate_sign_req,
			key
		) RETURNING certificate_signing_request_id INTO csr;
		IF NEW.x509_cert_id IS NULL THEN
			NEW.x509_cert_id := csr;
		END IF;
	ELSE
		IF NEW.subject_key_identifier IS NOT NULL THEN
			SELECT certificate_signing_request_id
			INTO csr
			FROM certificate_signing_request
				JOIN private_key USING (private_key_id)
			WHERE subject_key_identifier = NEW.subject_key_identifier
			ORDER BY certificate_signing_request_id
			LIMIT 1;

			SELECT certificate_signing_request
			INTO NEW.certificate_sign_req
			FROM certificate_signing_request
			WHERE certificate_signing_request_id  = csr;
		END IF;
	END IF;

	IF NEW.public_key IS NOT NULL THEN
		INSERT INTO x509_signed_certificate (
			friendly_name,
			is_active,
			is_certificate_authority,
			signing_cert_id,
			x509_ca_cert_serial_number,
			public_key,
			subject,
			subject_key_identifier,
			valid_from,
			valid_to,
			x509_revocation_date,
			x509_revocation_reason,
			ocsp_uri,
			crl_uri,
			private_key_id,
			certificate_signing_request_id
		) VALUES (
			NEW.friendly_name,
			NEW.is_active,
			NEW.is_certificate_authority,
			NEW.signing_cert_id,
			NEW.x509_ca_cert_serial_number,
			NEW.public_key,
			NEW.subject,
			NEW.subject_key_identifier,
			NEW.valid_from,
			NEW.valid_to,
			NEW.x509_revocation_date,
			NEW.x509_revocation_reason,
			NEW.ocsp_uri,
			NEW.crl_uri,
			key,
			csr
		) RETURNING x509_signed_certificate_id INTO crt;
		NEW.x509_cert_id := crt;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_ins_x509_certificate ON x509_certificate;
CREATE TRIGGER trigger_ins_x509_certificate
	INSTEAD OF INSERT ON x509_certificate
	FOR EACH ROW
	EXECUTE PROCEDURE ins_x509_certificate();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION upd_x509_certificate()
RETURNS TRIGGER AS $$
DECLARE
	upq	TEXT[];
	crt	x509_signed_certificate%ROWTYPE;
	key private_key.private_key_id%TYPE;
BEGIN
	SELECT * INTO crt FROM x509_signed_certificate
	WHERE x509_signed_certificate_id = OLD.x509_cert_id;

	IF OLD.x509_cert_id != NEW.x509_cert_id THEN
		RAISE EXCEPTION 'Can not change x509_cert_id' USING ERRCODE = 'invalid_parameter_value';
	END IF;

	key := crt.private_key_id;

	IF crt.private_key_ID IS NULL AND NEW.private_key IS NOT NULL THEN
		WITH ins AS (
			INSERT INTO private_key (
				private_key_encryption_type,
				is_active,
				subject_key_identifier,
				private_key,
				passphrase,
				encryption_key_id
			) VALUES (
				'rsa',
				NEW.is_active,
				NEW.subject_key_identifier,
				NEW.private_key,
				NEW.passphrase,
				NEW.encryption_key_id
			) RETURNING *
		), upd AS (
			UPDATE x509_signed_certificate
			SET private_key_id = ins.private_key_id
			WHERE x509_signed_certificate_id = OLD.x509_cert_id
			RETURNING *
		)  SELECT private_key_id INTO key FROM upd;
	ELSIF crt.private_key_id IS NOT NULL AND NEW.private_key IS NULL THEN
		UPDATE x509_signed_certificate
			SET private_key_id = NULL
			WHERE x509_signed_certificate_id = OLD.x509_cert_id;
		BEGIN
			DELETE FROM private_key where private_key_id = crt.private_key_id;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	ELSIF crt.private_key_id IS NOT NULL THEN
		IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
			upq := array_append(upq,
				'is_active = ' || quote_literal(NEW.is_active)
			);
		END IF;

		IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
			upq := array_append(upq,
				'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier)
			);
		END IF;

		IF OLD.private_key IS DISTINCT FROM NEW.private_key THEN
			upq := array_append(upq,
				'private_key = ' || quote_nullable(NEW.private_key)
			);
		END IF;

		IF OLD.passphrase IS DISTINCT FROM NEW.passphrase THEN
			upq := array_append(upq,
				'passphrase = ' || quote_nullable(NEW.passphrase)
			);
		END IF;

		IF OLD.encryption_key_id IS DISTINCT FROM NEW.encryption_key_id THEN
			upq := array_append(upq,
				'encryption_key_id = ' || quote_nullable(NEW.encryption_key_id)
			);
		END IF;

		IF array_length(upq, 1) > 0 THEN
			EXECUTE 'UPDATE private_key SET '
				|| array_to_string(upq, ', ')
				|| ' WHERE private_key_id = '
				|| crt.private_key_id;
		END IF;
	END IF;

	upq := NULL;
	IF crt.certificate_signing_request_id IS NULL AND NEW.certificate_sign_req IS NOT NULL THEN
		WITH ins AS (
			INSERT INTO certificate_signing_request (
				friendly_name,
				subject,
				certificate_signing_request,
				private_key_id
			) VALUES (
				NEW.friendly_name,
				NEW.subject,
				NEW.certificate_sign_req,
				key
			) RETURNING *
		) UPDATE x509_signed_certificate
		SET certificate_signing_request_id = ins.certificate_signing_request_id
		WHERE x509_signed_certificate_id = OLD.x509_cert_id;
	ELSIF crt.certificate_signing_request_id IS NOT NULL AND
				NEW.certificate_sign_req IS NULL THEN
		-- if its removed, we still keep the csr/key link
		WITH del AS (
			UPDATE x509_signed_certificate
			SET certificate_signing_request = NULL
			WHERE x509_signed_certificate_id = OLD.x509_cert_id
			RETURNING *
		) DELETE FROM certificate_signing_request
		WHERE certificate_signing_request_id =
			crt.certificate_signing_request_id;
	ELSE
		IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
			upq := array_append(upq,
				'friendly_name = ' || quote_literal(NEW.friendly_name)
			);
		END IF;

		IF OLD.subject IS DISTINCT FROM NEW.subject THEN
			upq := array_append(upq,
				'subject = ' || quote_literal(NEW.subject)
			);
		END IF;

		IF OLD.certificate_sign_req IS DISTINCT FROM
				NEW.certificate_sign_req THEN
			upq := array_append(upq,
				'certificate_signing_request = ' ||
					quote_literal(NEW.certificate_sign_req)
			);
		END IF;

		IF array_length(upq, 1) > 0 THEN
			EXECUTE 'UPDATE certificate_signing_request SET '
				|| array_to_string(upq, ', ')
				|| ' WHERE x509_signed_certificate_id = '
				|| crt.x509_signed_certificate_id;
		END IF;
	END IF;

	upq := NULL;
	IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
		upq := array_append(upq,
			'is_active = ' || quote_literal(NEW.is_active)
		);
	END IF;
	IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
		upq := array_append(upq,
			'friendly_name = ' || quote_literal(NEW.friendly_name)
		);
	END IF;
	IF OLD.subject IS DISTINCT FROM NEW.subject THEN
		upq := array_append(upq,
			'subject = ' || quote_literal(NEW.subject)
		);
	END IF;
	IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
		upq := array_append(upq,
			'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier)
		);
	END IF;
	IF OLD.is_certificate_authority IS DISTINCT FROM NEW.is_certificate_authority THEN
		upq := array_append(upq,
			'is_certificate_authority = ' || quote_nullable(NEW.is_certificate_authority)
		);
	END IF;
	IF OLD.signing_cert_id IS DISTINCT FROM NEW.signing_cert_id THEN
		upq := array_append(upq,
			'signing_cert_id = ' || quote_nullable(NEW.signing_cert_id)
		);
	END IF;
	IF OLD.x509_ca_cert_serial_number IS DISTINCT FROM NEW.x509_ca_cert_serial_number THEN
		upq := array_append(upq,
			'x509_ca_cert_serial_number = ' || quote_nullable(NEW.x509_ca_cert_serial_number)
		);
	END IF;
	IF OLD.public_key IS DISTINCT FROM NEW.public_key THEN
		upq := array_append(upq,
			'public_key = ' || quote_nullable(NEW.public_key)
		);
	END IF;
	IF OLD.valid_from IS DISTINCT FROM NEW.valid_from THEN
		upq := array_append(upq,
			'valid_from = ' || quote_nullable(NEW.valid_from)
		);
	END IF;
	IF OLD.valid_to IS DISTINCT FROM NEW.valid_to THEN
		upq := array_append(upq,
			'valid_to = ' || quote_nullable(NEW.valid_to)
		);
	END IF;
	IF OLD.x509_revocation_date IS DISTINCT FROM NEW.x509_revocation_date THEN
		upq := array_append(upq,
			'x509_revocation_date = ' || quote_nullable(NEW.x509_revocation_date)
		);
	END IF;
	IF OLD.x509_revocation_reason IS DISTINCT FROM NEW.x509_revocation_reason THEN
		upq := array_append(upq,
			'x509_revocation_reason = ' || quote_nullable(NEW.x509_revocation_reason)
		);
	END IF;
	IF OLD.ocsp_uri IS DISTINCT FROM NEW.ocsp_uri THEN
		upq := array_append(upq,
			'ocsp_uri = ' || quote_nullable(NEW.ocsp_uri)
		);
	END IF;
	IF OLD.crl_uri IS DISTINCT FROM NEW.crl_uri THEN
		upq := array_append(upq,
			'crl_uri = ' || quote_nullable(NEW.crl_uri)
		);
	END IF;

	IF array_length(upq, 1) > 0 THEN
		EXECUTE 'UPDATE x509_signed_certificate SET '
			|| array_to_string(upq, ', ')
			|| ' WHERE x509_signed_certificate_id = '
			|| NEW.x509_cert_id;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_upd_x509_certificate ON x509_certificate;
CREATE TRIGGER trigger_upd_x509_certificate
	INSTEAD OF UPDATE ON x509_certificate
	FOR EACH ROW
	EXECUTE PROCEDURE upd_x509_certificate();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION del_x509_certificate()
RETURNS TRIGGER AS $$
DECLARE
	crt	x509_signed_certificate%ROWTYPE;
BEGIN
	SELECT * INTO crt FROM x509_signed_certificate
		WHERE x509_signed_certificate_id = OLD.x509_cert_id;

	DELETE FROM x509_signed_certificate
		WHERE x509_signed_certificate_id = OLD.x509_cert_id;

	IF crt.private_key_id IS NOT NULL THEN
		DELETE FROM private_key
		WHERE private_key_id = crt.private_key_id;
	END IF;

	IF crt.private_key_id IS NOT NULL THEN
		DELETE FROM certificate_signing_request
		WHERE certificate_signing_request_id =
			crt.certificate_signing_request_id;
	END IF;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_del_x509_certificate ON x509_certificate;
CREATE TRIGGER trigger_del_x509_certificate
	INSTEAD OF DELETE ON x509_certificate
	FOR EACH ROW
	EXECUTE PROCEDURE del_x509_certificate();

