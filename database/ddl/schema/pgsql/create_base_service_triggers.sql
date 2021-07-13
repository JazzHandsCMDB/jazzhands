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
