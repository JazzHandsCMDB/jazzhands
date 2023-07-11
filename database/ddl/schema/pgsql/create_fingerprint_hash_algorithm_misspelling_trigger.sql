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

---------------------------------------------------------------------------

--
-- transition misspelled column to new name..  _sigh_
--
-- This will all get dropped in >= 0.97
--
CREATE OR REPLACE FUNCTION check_fingerprint_hash_algorithm()
RETURNS TRIGGER AS $$
DECLARE
BEGIN
	--
	-- Give a release to deal with misspelling
	--
	IF TG_OP = 'INSERT' THEN
		IF NEW.x509_fingerprint_hash_algorighm IS NOT NULL AND NEW.cryptographic_hash_algorithm IS NOT NULL
		THEN
			RAISE EXCEPTION 'Should only set cryptographic_hash_algorithm'
				USING ERRCODE = 'invalid_parameter_value';
		ELSIF NEW.x509_fingerprint_hash_algorighm IS NULL THEN
			NEW.x509_fingerprint_hash_algorighm := NEW.cryptographic_hash_algorithm;
		ELSE
			NEW.cryptographic_hash_algorithm := NEW.x509_fingerprint_hash_algorighm;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.x509_fingerprint_hash_algorighm IS DISTINCT FROM NEW.x509_fingerprint_hash_algorighm AND
			OLD.x509_fingerprint_hash_algorighm IS DISTINCT FROM NEW.cryptographic_hash_algorithm
		THEN
			RAISE EXCEPTION 'Should only set cryptographic_hash_algorithm'
				USING ERRCODE = 'invalid_parameter_value';
		ELSIF OLD.x509_fingerprint_hash_algorighm IS DISTINCT FROM NEW.cryptographic_hash_algorithm THEN
			NEW.x509_fingerprint_hash_algorighm := NEW.cryptographic_hash_algorithm;
		ELSE
			NEW.cryptographic_hash_algorithm := NEW.x509_fingerprint_hash_algorighm;
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_fingerprint_hash_algorithm
	ON val_x509_fingerprint_hash_algorithm;
CREATE TRIGGER trigger_fingerprint_hash_algorithm
	BEFORE INSERT OR UPDATE OF x509_fingerprint_hash_algorighm, cryptographic_hash_algorithm
	ON val_x509_fingerprint_hash_algorithm
	FOR EACH ROW
	EXECUTE PROCEDURE check_fingerprint_hash_algorithm();

DROP TRIGGER IF EXISTS trigger_fingerprint_hash_algorithm
	ON public_key_hash_hash;
CREATE TRIGGER trigger_fingerprint_hash_algorithm
	BEFORE INSERT OR UPDATE OF x509_fingerprint_hash_algorighm, cryptographic_hash_algorithm
	ON public_key_hash_hash
	FOR EACH ROW
	EXECUTE PROCEDURE check_fingerprint_hash_algorithm();

DROP TRIGGER IF EXISTS trigger_fingerprint_hash_algorithm
	ON x509_signed_certificate_fingerprint;
CREATE TRIGGER trigger_fingerprint_hash_algorithm
	BEFORE INSERT OR UPDATE OF x509_fingerprint_hash_algorighm, cryptographic_hash_algorithm
	ON x509_signed_certificate_fingerprint
	FOR EACH ROW
	EXECUTE PROCEDURE check_fingerprint_hash_algorithm();
