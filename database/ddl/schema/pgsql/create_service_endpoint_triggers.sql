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

--
-- service_endpoint_uri_fragment can be a the path to a file.
-- This may be problematic since it requires URI escaping but I was not sure
-- if that belonged in a new column or not.
--
CREATE OR REPLACE FUNCTION validate_service_endpoint_fksets()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.dns_record_id IS NOT NULL
		OR NEW.port_range_id IS NOT NULL
	THEN
		IF NEW.dns_record_id IS NULL
			OR NEW.port_range_id IS NULL
		THEN
			RAISE EXCEPTION 'both dns_record_id and port_range_id must be set'
				USING ERRCODE = 'not_null_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_service_endpoint_fksets
	ON service_endpoint;
CREATE CONSTRAINT TRIGGER trigger_validate_service_endpoint_fksets
	AFTER INSERT OR UPDATE OF dns_record_id, port_range_id
	ON service_endpoint
	FOR EACH ROW
	EXECUTE PROCEDURE validate_service_endpoint_fksets();

-----------------------------------------------------------------------------
