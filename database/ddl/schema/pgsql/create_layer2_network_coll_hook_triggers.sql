/*
 * Copyright (c) 2016-2019 Todd Kover
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

CREATE OR REPLACE FUNCTION layer2_network_collection_after_hooks()
RETURNS TRIGGER AS $$
BEGIN
	BEGIN
		PERFORM local_hooks.layer2_network_collection_after_hooks();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
			PERFORM 1;
	END;
	RETURN NULL;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_hier_layer2_network_collection_after_hooks
	 ON layer2_network_collection_hier;
CREATE TRIGGER trigger_hier_layer2_network_collection_after_hooks
	AFTER INSERT OR UPDATE OR DELETE
	ON layer2_network_collection_hier
	EXECUTE PROCEDURE layer2_network_collection_after_hooks();

DROP TRIGGER IF EXISTS trigger_member_layer2_network_collection_after_hooks
	 ON layer2_network_collection_layer2_network;
CREATE TRIGGER trigger_member_layer2_network_collection_after_hooks
	AFTER INSERT OR UPDATE OR DELETE
	ON layer2_network_collection_layer2_network
	EXECUTE PROCEDURE layer2_network_collection_after_hooks();
