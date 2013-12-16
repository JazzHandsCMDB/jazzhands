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


-- Manage per-device device collections.
--
-- When a device is added, updated or removed, there is a per-device
-- device-collection that goes along with it

-- XXX Need automated test cases

-- before a device is deleted, remove the per-device device collections, 
-- if appropriate
CREATE OR REPLACE FUNCTION delete_per_device_device_collection() 
RETURNS TRIGGER AS $$
DECLARE
	dcid			jazzhands.device_collection.device_collection_id%TYPE;
BEGIN
	SELECT	device_collection_id
	  FROM  jazzhands.device_collection
	  INTO	dcid
	 WHERE	device_collection_type = 'per-device'
	   AND	device_collection_id in
		(select device_collection_id
		 from jazzhands.device_collection_device
		where device_id = OLD.device_id
		)
	ORDER BY device_collection_id
	LIMIT 1;

	IF dcid IS NOT NULL THEN
		DELETE FROM jazzhands.device_collection_device
		WHERE device_collection_id = dcid;

		DELETE from jazzhands.device_collection
		WHERE device_collection_id = dcid;
	END IF;

	RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_delete_per_device_device_collection ON Device;
CREATE TRIGGER trigger_delete_per_device_device_collection 
BEFORE DELETE
ON device
FOR EACH ROW EXECUTE PROCEDURE delete_per_device_device_collection();

------------------------------------------------------------------------------


-- On inserts and updates, ensure the per-device device collection is updated
-- correctly.
CREATE OR REPLACE FUNCTION update_per_device_device_collection()
RETURNS TRIGGER AS $$
DECLARE
	dcid		jazzhands.device_collection.device_collection_id%TYPE;
	newname		jazzhands.device_collection.device_collection_name%TYPE;
BEGIN
	IF NEW.device_name IS NOT NULL THEN
		newname = NEW.device_name || '_' || NEW.device_id;
	ELSE
		newname = 'per_d_dc_contrived_' || NEW.device_id;
	END IF;

	IF TG_OP = 'INSERT' THEN
		insert into jazzhands.device_collection 
			(device_collection_name, device_collection_type)
		values
			(newname, 'per-device')
		RETURNING device_collection_id INTO dcid;
		insert into jazzhands.device_collection_device 
			(device_collection_id, device_id)
		VALUES
			(dcid, NEW.device_id);
	ELSIF TG_OP = 'UPDATE'  THEN
		UPDATE	device_collection
		   SET	device_collection_name = newname
		 WHERE	device_collection_name != newname
		   AND	device_collection_type = 'per-device'
		   AND	device_collection_id in (
			SELECT	device_collection_id
			  FROM	jazzhands.device_collection_device
			 WHERE	device_id = NEW.device_id
			);
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_per_device_device_collection ON device;
CREATE TRIGGER trigger_update_per_device_device_collection 
AFTER INSERT OR UPDATE
ON device 
FOR EACH ROW EXECUTE PROCEDURE update_per_device_device_collection();

--- Other triggers on device

CREATE OR REPLACE FUNCTION verify_device_voe() RETURNS TRIGGER AS $$
DECLARE
	voe_sw_pkg_repos		jazzhands.sw_package_repository.sw_package_repository_id%TYPE;
	os_sw_pkg_repos		jazzhands.operating_system.sw_package_repository_id%TYPE;
	voe_sym_trx_sw_pkg_repo_id	jazzhands.voe_symbolic_track.sw_package_repository_id%TYPE;
BEGIN

	IF (NEW.operating_system_id IS NOT NULL)
	THEN
		SELECT sw_package_repository_id INTO os_sw_pkg_repos
			FROM
				jazzhands.operating_system
			WHERE
				operating_system_id = NEW.operating_system_id;
	END IF;

	IF (NEW.voe_id IS NOT NULL) THEN
		SELECT sw_package_repository_id INTO voe_sw_pkg_repos
			FROM
				jazzhands.voe
			WHERE
				voe_id=NEW.voe_id;
		IF (voe_sw_pkg_repos != os_sw_pkg_repos) THEN
			RAISE EXCEPTION 
				'Device OS and VOE have different SW Pkg Repositories';
		END IF;
	END IF;

	IF (NEW.voe_symbolic_track_id IS NOT NULL) THEN
		SELECT sw_package_repository_id INTO voe_sym_trx_sw_pkg_repo_id	
			FROM
				jazzhands.voe_symbolic_track
			WHERE
				voe_symbolic_track_id=NEW.voe_symbolic_track_id;
		IF (voe_sym_trx_sw_pkg_repo_id != os_sw_pkg_repos) THEN
			RAISE EXCEPTION 
				'Device OS and VOE track have different SW Pkg Repositories';
		END IF;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_verify_device_voe ON device;
CREATE TRIGGER trigger_verify_device_voe BEFORE INSERT OR UPDATE
ON device FOR EACH ROW EXECUTE PROCEDURE verify_device_voe();

