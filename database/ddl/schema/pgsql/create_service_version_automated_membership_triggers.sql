/*
 * Copyright (c) 2021-2023 Todd Kover
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


CREATE OR REPLACE FUNCTION manip_all_svc_collection_members()
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		INSERT INTO service_version_collection_service_version (
			service_version_collection_id, service_version_id
		) SELECT service_version_collection_id, NEW.service_version_id
		FROM service_version_collection
			JOIN service_version_collection_purpose
				USING (service_version_collection_id)
		WHERE service_version_collection_purpose IN ('all','current')
		AND service_id = NEW.service_id;
	ELSIF TG_OP = 'UPDATE' THEN
		UPDATE service_version_collection_service_version
		SET service_version_collection_id = (
			SELECT service_version_collection_id
			FROM service_version_collection_purpose
			WHERE service_id = NEW.service_id
			AND service_version_collection_purpose = 'current'
		) WHERE service_version_collection_id = (
			SELECT service_version_collection_id
			FROM service_version_collection_purpose
			WHERE service_id = OLD.service_id
			AND service_version_collection_purpose = 'current'
		);
		UPDATE service_version_collection_service_version
		SET service_version_collection_id = (
			SELECT service_version_collection_id
			FROM service_version_collection_purpose
			WHERE service_id = NEW.service_id
			AND service_version_collection_purpose = 'all'
		) WHERE service_version_collection_id = (
			SELECT service_version_collection_id
			FROM service_version_collection_purpose
			WHERE service_id = OLD.service_id
			AND service_version_collection_purpose = 'all'
		);
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM service_version_collection_service_version
		WHERE service_version_id = OLD.service_version_id
		AND service_version_collection_id IN (
			SELECT service_version_collection_id
			FROM service_version_collection
				JOIN service_version_collection_purpose
					USING (service_version_collection_id)
			WHERE service_id = OLD.service_id
			AND service_version_collection_purpose IN ( 'all', 'current' )
		);
		RETURN OLD;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_all_svc_collection_members
	ON service_version;
CREATE TRIGGER trigger_manip_all_svc_collection_members
	AFTER INSERT OR UPDATE OF service_id
	ON service_version
	FOR EACH ROW
	EXECUTE PROCEDURE manip_all_svc_collection_members();

DROP TRIGGER IF EXISTS trigger_manip_all_svc_collection_members_del
	ON service_version;
CREATE TRIGGER trigger_manip_all_svc_collection_members_del
	BEFORE DELETE
	ON service_version
	FOR EACH ROW
	EXECUTE PROCEDURE manip_all_svc_collection_members();

-----------------------------------------------------------------------------

---
--- Check if there are service_version_collection_purpose mismatches when
--- a service_id is changed.
---
CREATE OR REPLACE FUNCTION service_version_service_version_purpose_enforce()
RETURNS TRIGGER AS $$
BEGIN
	PERFORM *
	FROM service_version_collection_service_version
		JOIN service_version_collection_purpose svcp
			USING (service_version_collection_id)
		JOIN service_version_collection_service_version svcsv
			USING (service_version_collection_id)
	WHERE svcp.service_id != NEW.service_id
	AND svcsv.service_version_id = NEW.service_version_id;

	IF FOUND THEN
		RAISE EXCEPTION 'A service_version_collection_purpose for this service does not allow changing the service_id'
			USING ERRCODE = 'foreign_key_violation';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_version_service_version_purpose_enforce
	ON service_version;
CREATE CONSTRAINT TRIGGER trigger_service_version_service_version_purpose_enforce
	AFTER UPDATE OF service_id
	ON service_version
	FOR EACH ROW
	EXECUTE PROCEDURE service_version_service_version_purpose_enforce();

-----------------------------------------------------------------------------
