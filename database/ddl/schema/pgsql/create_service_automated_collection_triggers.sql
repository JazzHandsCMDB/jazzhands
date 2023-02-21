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


CREATE OR REPLACE FUNCTION create_all_services_collection()
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		INSERT INTO service_version_collection (
			service_version_collection_name, service_version_collection_type
		) VALUES
			( NEW.service_name, 'all-services' ),
			( NEW.service_name, 'current-services' );
	ELSIF TG_OP = 'UPDATE' THEN
		UPDATE service_version_collection
		SET service_version_collection_name = NEW.service_name
		WHERE service_version_collection_type
			IN ( 'all-services', 'current-services')
		AND service_version_collection_name = OLD.service_name;
	ELSIF TG_OP = 'DELETE' THEN
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
	AFTER INSERT OR UPDATE OF service_name
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

