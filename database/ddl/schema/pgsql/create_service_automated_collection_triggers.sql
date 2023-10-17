/*
 * Copyright (c) 2021-2023 Todd Kover
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


CREATE OR REPLACE FUNCTION create_all_services_collection()
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		WITH svc AS (
			INSERT INTO service_version_collection (
				service_version_collection_name, service_version_collection_type
			) VALUES
				(concat_ws(':', NEW.service_type,NEW.service_name),
					'all-services' )
			RETURNING *
		) INSERT INTO service_version_collection_purpose (
			service_version_collection_id, service_version_collection_purpose,
			service_id
		) SELECT service_version_collection_id, 'all', NEW.service_id
		FROM svc;

		WITH svc AS (
			INSERT INTO service_version_collection (
				service_version_collection_name, service_version_collection_type
			) VALUES
				(concat_ws(':', NEW.service_type,NEW.service_name),
					'current-services' )
			RETURNING *
		) INSERT INTO service_version_collection_purpose (
			service_version_collection_id, service_version_collection_purpose,
			service_id
		) SELECT service_version_collection_id, 'current', NEW.service_id
		FROM svc;
	ELSIF TG_OP = 'UPDATE' THEN
		UPDATE service_version_collection svc
			SET service_version_collection_name =
				concat_ws(':', NEW.service_type,NEW.service_name)
			FROM service_version_collection_purpose svcp
			WHERE svc.service_version_collection_id
					= svcp.service_version_collection_id
			AND service_collection_purpose IN ('all', 'current');
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM service_version_collection_purpose
		WHERE service_version_collection_purpose IN ('current', 'all')
		AND service_id = OLD.service_id;

		RETURN OLD;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_create_all_services_collection
	ON service;
CREATE TRIGGER trigger_create_all_services_collection
	AFTER INSERT OR UPDATE OF service_name, service_type
	ON service
	FOR EACH ROW
	EXECUTE PROCEDURE create_all_services_collection();

DROP TRIGGER IF EXISTS trigger_create_all_services_collection_del
	ON service;
CREATE TRIGGER trigger_create_all_services_collection_del
	BEFORE DELETE
	ON service
	FOR EACH ROW
	EXECUTE PROCEDURE create_all_services_collection();

