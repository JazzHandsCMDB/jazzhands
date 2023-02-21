/*
 * Copyright (c) 2013-2019 Todd Kover
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


-- Manage per-service_environment collections.
--
-- When a service environment is added, updated or removed, there is a
-- per-environment
-- service environment collection that goes along with it

-- XXX Need automated test cases

-- before a serivce environment is deleted, remove the
-- collection its a part of, -- if appropriate
CREATE OR REPLACE FUNCTION delete_per_service_environment_service_environment_collection()
RETURNS TRIGGER AS $$
DECLARE
	secid	service_environment_collection.service_environment_collection_id%TYPE;
BEGIN
	SELECT	service_environment_collection_id
	  FROM  service_environment_collection
	  INTO	secid
	 WHERE	service_environment_collection_type = 'per-environment'
	   AND	service_environment_collection_id in
		(select service_environment_collection_id
		 from service_environment_collection_service_environment
		where service_environment_id = OLD.service_environment_id
		)
	ORDER BY service_environment_collection_id
	LIMIT 1;

	IF secid IS NOT NULL THEN
		DELETE FROM service_environment_collection_service_environment
		WHERE service_environment_collection_id = secid;

		DELETE from service_environment_collection
		WHERE service_environment_collection_id = secid;
	END IF;

	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_delete_per_service_environment_service_environment_collection
	ON service_environment;
CREATE TRIGGER trigger_delete_per_service_environment_service_environment_collection
	BEFORE DELETE
	ON service_environment
	FOR EACH ROW EXECUTE PROCEDURE delete_per_service_environment_service_environment_collection();

------------------------------------------------------------------------------


-- On inserts and updates, ensure the per-environment service collection
-- is updated correctly.
CREATE OR REPLACE FUNCTION update_per_service_environment_service_environment_collection()
RETURNS TRIGGER AS $$
DECLARE
	secid		service_environment_collection.service_environment_collection_id%TYPE;
	_newname		TEXT;
BEGIN
	_newname = concat(NEW.service_environment_name, '_', NEW.service_environment_id);
	IF TG_OP = 'INSERT' THEN
		insert into service_environment_collection
			(service_environment_collection_name, service_environment_collection_type)
		values
			(_newname, 'per-environment')
		RETURNING service_environment_collection_id INTO secid;
		insert into service_environment_collection_service_environment
			(service_environment_collection_id, service_environment_id)
		VALUES
			(secid, NEW.service_environment_id);
	ELSIF TG_OP = 'UPDATE'  AND OLD.service_environment_id != NEW.service_environment_id THEN
		UPDATE	service_environment_collection
		   SET	service_environment_collection_name = _newname
		 WHERE	service_environment_collection_name != _newname
		   AND	service_environment_collection_type = 'per-environment'
		   AND	service_environment_collection_id in (
			SELECT	service_environment_collection_id
			  FROM	service_environment_collection_service_environment
			 WHERE	service_environment_id =
				NEW.service_environment_id
			);
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_per_service_environment_service_environment_collection
	ON service_environment;
CREATE TRIGGER trigger_update_per_service_environment_service_environment_collection
	AFTER INSERT OR UPDATE
	ON service_environment
	FOR EACH ROW EXECUTE PROCEDURE update_per_service_environment_service_environment_collection();
