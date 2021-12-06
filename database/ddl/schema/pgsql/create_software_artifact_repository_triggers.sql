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

CREATE OR REPLACE FUNCTION software_artifact_repository_uri_endpoint_enforce()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.software_artifact_repository_uri IS NULL AND NEW.service_endpoint_id IS NULL THEN
		RAISE EXCEPTION 'Must set either software_artifact_repository_uri or service_endpoint_id'
			USING ERRCODE = 'null_value_not_allowed';
	ELSIF NEW.software_artifact_repository_uri IS NOT NULL AND NEW.service_endpoint_id IS NOT NULL THEN
		RAISE EXCEPTION 'Must set only one of software_artifact_repository_uri or service_endpoint_id'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_software_artifact_repository_uri_endpoint_enforce
	ON software_artifact_repository_uri;
CREATE CONSTRAINT TRIGGER trigger_software_artifact_repository_uri_endpoint_enforce
	AFTER INSERT OR UPDATE OF software_artifact_repository_uri, service_endpoint_id
	ON software_artifact_repository_uri
	FOR EACH ROW
	EXECUTE PROCEDURE software_artifact_repository_uri_endpoint_enforce();

-----------------------------------------------------------------------------

