
-- Copyright (c) 2021, Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- $Id$
--

--
-- Traverses all the middle layers to map endpoints to instances.  This does
-- not actually include the endpoints although queries probably will.
--
CREATE OR REPLACE VIEW v_service_endpoint_service_instance AS
SELECT	service_endpoint_id, service_endpoint_provider_service_instance_id,
	service_instance_id
FROM	service_endpoint_service_endpoint_provider_collection
	JOIN service_endpoint_provider_collection
		USING (service_endpoint_provider_collection_id)
	JOIN service_endpoint_provider_collection_service_endpoint_provider
		USING (service_endpoint_provider_collection_id)
	JOIN service_endpoint_provider USING (service_endpoint_provider_id)
	JOIN service_endpoint_provider_service_instance
		USING (service_endpoint_provider_id)
;
