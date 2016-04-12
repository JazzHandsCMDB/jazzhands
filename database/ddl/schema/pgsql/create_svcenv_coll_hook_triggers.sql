/*
 * Copyright (c) 2016 Todd Kover
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
-- $HeadURL$
-- $Id$
--

CREATE OR REPLACE FUNCTION service_env_collection_after_hooks()
RETURNS TRIGGER AS $$
BEGIN
	BEGIN
		PERFORM local_hooks.service_env_collection_after_hooks();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
			PERFORM 1;
	END;
	RETURN NULL;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_hier_service_env_collection_after_hooks
	 ON service_environment_coll_hier;
CREATE TRIGGER trigger_hier_service_env_collection_after_hooks
	AFTER INSERT OR UPDATE OR DELETE
	ON service_environment_coll_hier
	EXECUTE PROCEDURE service_env_collection_after_hooks();

DROP TRIGGER IF EXISTS trigger_member_service_env_collection_after_hooks
	 ON svc_environment_coll_svc_env;
CREATE TRIGGER trigger_member_service_env_collection_after_hooks
	AFTER INSERT OR UPDATE OR DELETE
	ON svc_environment_coll_svc_env
	EXECUTE PROCEDURE service_env_collection_after_hooks();
