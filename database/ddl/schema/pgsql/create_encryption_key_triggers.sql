/*
 * Copyright (c) 2023 Todd Kover
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

--
-- These triggers enforce that things that are direct to host can't become
-- accidentaly not direct to host.  It's possible, even probable that these
-- should be folded into other triggers, but due to time constraints did not
-- want to do that now.
--

\set ON_ERROR_STOP

CREATE OR REPLACE FUNCTION encryption_key_validation()
RETURNS TRIGGER AS $$
DECLARE
	_val	val_encryption_key_purpose;
BEGIN

	IF _val.permit_encryption_key_db_value = 'PROHIBITED' THEN
		IF NEW.encryption_key_db_value IS NOT NULL THEN
			RAISE EXCEPTION 'encryption_key_db_value must be null for this purpose/version'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF _val.permit_encryption_key_db_value = 'REQUIRED' THEN
		IF NEW.encryption_key_db_value IS NULL THEN
			RAISE EXCEPTION 'encryption_key_db_value must be set for this purpose/version'
				USING ERRCODE = 'not_null_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_encryption_key_validation
	ON encryption_key;
CREATE CONSTRAINT TRIGGER trigger_encryption_key_validation
	AFTER INSERT OR UPDATE OF encryption_key_db_value
	ON encryption_key
	DEFERRABLE FOR EACH ROW
	EXECUTE PROCEDURE encryption_key_validation();

-----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION val_encryption_key_purpose_validation()
RETURNS TRIGGER AS $$
DECLARE
	_val	val_encryption_key_purpose;
BEGIN
	IF NEW.permit_encryption_key_db_value = 'REQUIRED' THEN
		PERFORM *
			FROM encryption_key
			WHERE encryption_key_purpose = NEW.encryption_key_purpose
			AND encryption_key_purpose_version = NEw.encryption_key_purpose_version
			AND encryption_key_db_value IS NULL;

		IF FOUND THEN
			RAISE EXCEPTION 'encryption_key_db_value must be null for this purpose/version'
				USING ERRCODE = 'not_null_violation';
		END IF;
	ELSIF NEW.permit_encryption_key_db_value = 'PROHIBITED' THEN
		PERFORM *
			FROM encryption_key
			WHERE encryption_key_purpose = NEW.encryption_key_purpose
			AND encryption_key_purpose_version = NEw.encryption_key_purpose_version
			AND encryption_key_db_value IS NOT NULL;

		IF FOUND THEN
			RAISE EXCEPTION 'encryption_key_db_value must be null for this purpose/version'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_encryption_key_purpose_validation
	ON val_encryption_key_purpose;
CREATE CONSTRAINT TRIGGER trigger_val_encryption_key_purpose_validation
	AFTER INSERT OR UPDATE OF permit_encryption_key_db_value
	ON val_encryption_key_purpose
	DEFERRABLE FOR EACH ROW
	EXECUTE PROCEDURE val_encryption_key_purpose_validation();

-----------------------------------------------------------------------------
