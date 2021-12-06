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

CREATE OR REPLACE FUNCTION service_endpoint_provider_dns_netblock_check()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.dns_record_id IS NULL AND  NEW.netblock_id IS NULL AND NEW.service_endpoint_provider_type != 'direct'THEN
		RAISE EXCEPTION 'One of dns_record_id OR netblock_id must be set for types other than direct'
       		USING ERRCODE = 'not_null_violation';
	ELSIF NEW.dns_record_id IS NOT NULL AND NEW.netblock_id IS NOT NULL THEN
		RAISE EXCEPTION 'Only One of dns_record_id OR netblock_id must be set'
       		USING ERRCODE = 'not_null_violation';
	END IF;

	-- XXX it is probable additional checks must be made on this.

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_endpoint_provider_dns_netblock_check
	ON service_endpoint_provider;
CREATE CONSTRAINT TRIGGER trigger_service_endpoint_provider_dns_netblock_check
	AFTER INSERT OR UPDATE OF dns_record_id, netblock_id
	ON service_endpoint_provider
	FOR EACH ROW
	EXECUTE PROCEDURE service_endpoint_provider_dns_netblock_check();
