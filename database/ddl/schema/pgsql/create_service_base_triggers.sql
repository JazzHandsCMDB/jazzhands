/*
 * Copyright (c) 2021 Todd Kover
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

CREATE OR REPLACE FUNCTION propagate_service_type_to_version()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.service_type IS NULL THEN
		SELECT service_type
		INTO NEW.service_type
		FROM service
		WHERE service_id = NEW.service_id;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_propagate_service_type_to_version
	ON service_version;
CREATE TRIGGER trigger_propagate_service_type_to_version
	BEFORE INSERT
	ON service_version
	FOR EACH ROW
	EXECUTE PROCEDURE propagate_service_type_to_version();

-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_service_namespace()
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
	_myns	TEXT;
BEGIN
	SELECT service_namespace
	INTO _myns
	FROM val_service_type
	WHERE service_type = NEW.service_type;

	--
	-- uniqueness within the same type is covered by an AK
	--
	SELECT count(*) INTO _tally
	FROM service
		JOIN val_service_type USING (service_type)
	WHERE service_name = NEW.service_name
	AND service_id  != NEW.service_id
	AND service_namespace = _myns;

	IF _tally > 0 THEN
		RAISE EXCEPTION '% is not unique within % namespace (%).',
			NEW.service_name, NEW.service_type, _myns
		USING ERRCODE = 'unique_violation';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_check_service_namespace
	ON service;
CREATE CONSTRAINT TRIGGER trigger_check_service_namespace
	AFTER INSERT OR UPDATE OF service_name, service_type
	ON service
	FOR EACH ROW
	EXECUTE PROCEDURE check_service_namespace();

-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_service_type_namespace()
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	SELECT coalesce(sum(n), 0)
	INTO _tally
	FROM (
		SELECT service_name, count(*) as n
		FROM service
			JOIN val_service_type USING (service_type)
		WHERE service_namespace = NEW.service_namespace
		GROUP BY 1
		HAVING count(*) > 1
	) x;

	IF _tally > 0 THEN
		RAISE EXCEPTION 'namespace % has % conflicting services',
			NEW.service_type, _tally
		USING ERRCODE = 'unique_violation';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_check_service_type_namespace
	ON val_service_type;
CREATE CONSTRAINT TRIGGER trigger_check_service_type_namespace
	AFTER UPDATE OF service_namespace
	ON val_service_type
	FOR EACH ROW
	EXECUTE PROCEDURE check_service_type_namespace();

-----------------------------------------------------------------------------
