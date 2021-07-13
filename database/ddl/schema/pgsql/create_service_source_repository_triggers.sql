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

CREATE OR REPLACE FUNCTION source_repository_url_endpoint_enforcement()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.source_repository_url IS NULL AND NEW.service_endpoint_id IS NULL THEN
		RAISE EXCEPTION 'Must set either source_repository_url or service_endpoint_id'
			USING ERRCODE = 'null_value_not_allowed';
	ELSIF NEW.source_repository_url IS NOT NULL AND NEW.service_endpoint_id IS NOT NULL THEN
		RAISE EXCEPTION 'Must set only one of source_repository_url or service_endpoint_id'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_source_repository_url_endpoint_enforcement
	ON source_repository_url;
CREATE CONSTRAINT TRIGGER trigger_source_repository_url_endpoint_enforcement
	AFTER INSERT OR UPDATE OF source_repository_url, service_endpoint_id
	ON source_repository_url
	FOR EACH ROW
	EXECUTE PROCEDURE source_repository_url_endpoint_enforcement();

-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION service_source_repository_sanity()
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	--
	-- check to see if there's another primary, if so fail.
	---
	IF NEW.is_primary THEN
		SELECT count(*) INTO _tally
		FROM service_source_repository
		WHERE service_id = NEW.service_id
		AND service_source_repository_id != NEW.service_source_repository_id
		AND is_primary;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'A primary source repository already exists for this service'
				USING ERRCODE = 'unique_violation';
		END IF;

	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_source_repository_sanity
	ON service_source_repository;
CREATE CONSTRAINT TRIGGER trigger_service_source_repository_sanity
	AFTER INSERT OR UPDATE OF is_primary
	ON service_source_repository
	FOR EACH ROW
	EXECUTE PROCEDURE service_source_repository_sanity();

-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION service_version_source_repository_service_match_check()
RETURNS TRIGGER AS $$
BEGIN
	PERFORM *
	FROM service_source_repository
	WHERE service_source_repository_id = NEW.service_source_repository_id
	AND service_id = (SELECT service_id FROM service_version WHERE service_version_id = NEW.service_version_id);

	IF NOT FOUND THEN
		RAISE EXCEPTION 'source repository is not associted with the service'
			USING ERRCODE = 'invalid_parameter_value',
			HINT = 'consider adding a row to service_source_repository';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_version_source_repository_service_match_check
	ON service_version_source_repository;
CREATE CONSTRAINT TRIGGER trigger_service_version_source_repository_service_match_check
	AFTER INSERT OR UPDATE OF service_version_id, service_source_repository_id
	ON service_version_source_repository
	FOR EACH ROW
	EXECUTE PROCEDURE service_version_source_repository_service_match_check();

-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION service_source_repository_service_match_check()
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	RAISE EXCEPTION 'Can not change service_id or service_source_repository_id due to missing trigger'
		USING HINT = 'need trigger that compares to service_version_source_repository_service_match_check';
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_source_repository_service_match_check
	ON service_source_repository;
CREATE CONSTRAINT TRIGGER trigger_service_source_repository_service_match_check
	AFTER UPDATE OF service_id, service_source_repository_id
	ON service_source_repository
	FOR EACH ROW
	EXECUTE PROCEDURE service_source_repository_service_match_check();

-----------------------------------------------------------------------------
