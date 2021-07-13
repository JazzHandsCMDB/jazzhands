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

CREATE OR REPLACE FUNCTION device_collection_after_hooks()
RETURNS TRIGGER AS $$
BEGIN
	BEGIN
		PERFORM local_hooks.device_collection_after_hooks();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
			PERFORM 1;
	END;
	RETURN NULL;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_hier_device_collection_after_hooks
	 ON device_collection_hier;
CREATE TRIGGER trigger_hier_device_collection_after_hooks
	AFTER INSERT OR UPDATE OR DELETE
	ON device_collection_hier
	EXECUTE PROCEDURE device_collection_after_hooks();

DROP TRIGGER IF EXISTS trigger_member_device_collection_after_hooks
	 ON device_collection_device;
CREATE TRIGGER trigger_member_device_collection_after_hooks
	AFTER INSERT OR UPDATE OR DELETE
	ON device_collection_device
	EXECUTE PROCEDURE device_collection_after_hooks();

---

CREATE OR REPLACE FUNCTION device_collection_hier_after_row_hooks()
RETURNS TRIGGER AS $$
BEGIN
	BEGIN
		IF TG_OP = 'DELETE' THEN
			PERFORM local_hooks.device_collection_hier_after_row_hooks(TG_OP, OLD, NULL);
		ELSIF TG_OP = 'UPDATE' THEN
			PERFORM local_hooks.device_collection_hier_after_row_hooks(TG_OP, OLD, NEW);
		ELSIF TG_OP = 'INSERT' THEN
			PERFORM local_hooks.device_collection_hier_after_row_hooks(TG_OP, NULL, NEW);
		END IF;
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
			PERFORM 1;
	END;
	RETURN NULL;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_hier_device_collection_after_row_hooks
	 ON device_collection_hier;
CREATE TRIGGER trigger_hier_device_collection_after_row_hooks
	AFTER INSERT OR UPDATE OR DELETE
	ON device_collection_hier
	FOR EACH ROW
	EXECUTE PROCEDURE device_collection_hier_after_row_hooks();

CREATE OR REPLACE FUNCTION device_collection_device_after_row_hooks()
RETURNS TRIGGER AS $$
BEGIN
	BEGIN
		IF TG_OP = 'DELETE' THEN
			PERFORM local_hooks.device_collection_device_after_row_hooks(TG_OP, OLD, NULL);
		ELSIF TG_OP = 'UPDATE' THEN
			PERFORM local_hooks.device_collection_device_after_row_hooks(TG_OP, OLD, NEW);
		ELSIF TG_OP = 'INSERT' THEN
			PERFORM local_hooks.device_collection_device_after_row_hooks(TG_OP, NULL, NEW);
		END IF;
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
			PERFORM 1;
	END;
	RETURN NULL;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_member_device_collection_after_row_hooks
	 ON device_collection_device;
CREATE TRIGGER trigger_member_device_collection_after_row_hooks
	AFTER INSERT OR UPDATE OR DELETE
	ON device_collection_device
	FOR EACH ROW
	EXECUTE PROCEDURE device_collection_device_after_row_hooks();
