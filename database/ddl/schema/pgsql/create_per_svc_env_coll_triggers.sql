/*
 * Copyright (c) 2013 Todd Kover
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
CREATE OR REPLACE FUNCTION delete_per_svc_env_svc_env_collection() 
RETURNS TRIGGER AS $$
DECLARE
	secid	service_environment_collection.service_env_collection_id%TYPE;
BEGIN
	SELECT	service_env_collection_id
	  FROM  service_environment_collection
	  INTO	secid
	 WHERE	service_env_collection_type = 'per-environment'
	   AND	service_env_collection_id in
		(select service_env_collection_id
		 from svc_environment_coll_svc_env
		where service_environment = OLD.service_environment
		)
	ORDER BY service_env_collection_id
	LIMIT 1;

	IF secid IS NOT NULL THEN
		DELETE FROM svc_environment_coll_svc_env
		WHERE service_env_collection_id = secid;

		DELETE from service_environment_collection
		WHERE service_env_collection_id = secid;
	END IF;

	RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_delete_per_svc_env_svc_env_collection ON service_environment;
CREATE TRIGGER trigger_delete_per_svc_env_svc_env_collection 
BEFORE DELETE
ON service_environment
FOR EACH ROW EXECUTE PROCEDURE delete_per_svc_env_svc_env_collection();

------------------------------------------------------------------------------


-- On inserts and updates, ensure the per-environment service collection 
-- is updated correctly.
CREATE OR REPLACE FUNCTION update_per_svc_env_svc_env_collection()
RETURNS TRIGGER AS $$
DECLARE
	secid		service_environment_collection.service_env_collection_id%TYPE;
BEGIN
	IF TG_OP = 'INSERT' THEN
		insert into service_environment_collection 
			(service_env_collection_name, service_env_collection_type)
		values
			(NEW.service_environment, 'per-environment')
		RETURNING service_env_collection_id INTO secid;
		insert into svc_environment_coll_svc_env 
			(service_env_collection_id, service_environment)
		VALUES
			(secid, NEW.service_environment);
	ELSIF TG_OP = 'UPDATE'  AND OLD.service_environment != NEW.service_environment THEN
		UPDATE	service_environment_collection
		   SET	service_env_collection_name = NEW.service_environment
		 WHERE	service_env_collection_name != NEW.service_environment
		   AND	service_env_collection_type = 'per-environment'
		   AND	service_environment in (
			SELECT	service_environment
			  FROM	svc_environment_coll_svc_env
			 WHERE	service_environment = NEW.service_environment
			);
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_per_svc_env_svc_env_collection ON service_environment;
CREATE TRIGGER trigger_update_per_svc_env_svc_env_collection 
AFTER INSERT OR UPDATE
ON service_environment 
FOR EACH ROW EXECUTE PROCEDURE update_per_svc_env_svc_env_collection();
