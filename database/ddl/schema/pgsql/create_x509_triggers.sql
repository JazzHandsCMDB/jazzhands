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

CREATE OR REPLACE FUNCTION pvtkey_ski_signed_validate()
RETURNS TRIGGER AS $$
DECLARE
	ski	TEXT;
BEGIN
	SELECT	subject_key_identifier
	INTO	ski
	FROM	x509_signed_certificate x
	WHERE	x.private_key_id = NEW.private_key_id;

	IF FOUND AND ski != NEW.subject_key_identifier THEN
		RAISE EXCEPTION 'subject key identifier must match private key in x509_signing_certificate' USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_pvtkey_ski_signed_validate ON private_key;
CREATE TRIGGER trigger_pvtkey_ski_signed_validate
	AFTER UPDATE OF subject_key_identifier
	ON private_key
	FOR EACH ROW
	EXECUTE PROCEDURE pvtkey_ski_signed_validate();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION x509_signed_ski_pvtkey_validate()
RETURNS TRIGGER AS $$
DECLARE
	ski	TEXT;
BEGIN
	--
	-- XXX needs to be tweaked to ensure that both are set or not set.
	--
	IF NEW.private_key_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT	subject_key_identifier
	INTO	ski
	FROM	private_key p
	WHERE	p.private_key_id = NEW.private_key_id;

	IF FOUND AND ski != NEW.subject_key_identifier THEN
		RAISE EXCEPTION 'subject key identifier must match private key in private_key' USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_x509_signed_ski_pvtkey_validate ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_ski_pvtkey_validate
	AFTER INSERT OR UPDATE OF subject_key_identifier, private_key_id
	ON x509_signed_certificate
	FOR EACH ROW
	EXECUTE PROCEDURE x509_signed_ski_pvtkey_validate();

---------------------------------------------------------------------------
