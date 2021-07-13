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

-- XXX some things need to be thoguht about:
-- 1) service_endpoint_service_sla_service_feature may end up with unresolvable
--		features and thta should probably be ok
-- 2) if features are deleted, this should cause probelms if things expect
--		them.
--
-- 3) all this probably needs someone to go through and makes sure there's not
-- 		checks that need to be added.  This is a good first start, but...

-- XXX These really should traverse hierarchies.
CREATE OR REPLACE FUNCTION service_instance_feature_check()
RETURNS TRIGGER AS $$
BEGIN
	PERFORM *
	FROM service_version_collection_permitted_feature svcpf
		-- may not need this join
		JOIN service_version_collection svc
			USING (service_version_collection_id)
		JOIN service_version_collection_service_version svscsv
			USING (service_version_collection_id)
		JOIN service_instance si USING (service_version_id)
	WHERE	svcpf.service_feature = NEW.service_feature
	AND		si.service_instance_id = NEW.service_instance_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Feature not permitted for this service'
       		USING ERRCODE = 'foreign_key_violation',
       		HINT = 'An entry in service_version_collection_permitted_feature may be required';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_instance_feature_check
	ON service_instance_provided_feature;
CREATE CONSTRAINT TRIGGER trigger_service_instance_feature_check
	AFTER INSERT
	ON service_instance_provided_feature
	FOR EACH ROW
	EXECUTE PROCEDURE service_instance_feature_check();

------------------------------------------------------------------------------

-- There should actually check to see if the rename causes a problem or not
-- but in the interest of time spent, decided to punt on that to later, which
-- almost certainly cause someone angst.
CREATE OR REPLACE FUNCTION service_instance_service_feature_rename()
RETURNS TRIGGER AS $$
BEGIN
	IF OLD.serice_feature != NEW.service_feature THEN
		RAISE EXCEPTION 'Features may not be renaemd due to possible constraint issues'
       		USING ERRCODE = 'invalid_paramater',
       		HINT = 'This feature is not implemented';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_instance_service_feature_rename
	ON service_instance_provided_feature;
CREATE CONSTRAINT TRIGGER trigger_service_instance_service_feature_rename
	AFTER UPDATE OF service_feature, service_instance_id
	ON service_instance_provided_feature
	FOR EACH ROW
	EXECUTE PROCEDURE service_instance_service_feature_rename();

--

CREATE OR REPLACE FUNCTION service_version_feature_permitted_rename()
RETURNS TRIGGER AS $$
BEGIN
	IF OLD.serice_feature != NEW.service_feature THEN
		RAISE EXCEPTION 'Features may not be renaemd due to possible constraint issues'
       		USING ERRCODE = 'invalid_paramater',
       		HINT = 'This feature is not implemented';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_version_feature_permitted_rename
	ON service_version_collection_permitted_feature;
CREATE CONSTRAINT TRIGGER trigger_service_version_feature_permitted_rename
	AFTER UPDATE OF service_feature
	ON service_version_collection_permitted_feature
	FOR EACH ROW
	EXECUTE PROCEDURE service_version_feature_permitted_rename();

------------------------------------------------------------------------------

--
-- XXX This should both check to see if a rename is actually a problem AND
-- check to see if there are some services between minimum and maimum that
-- satisfy it, but second check is more coarse.
--
CREATE OR REPLACE FUNCTION service_depend_feature_check()
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'UPDATE' AND OLD.serice_feature != NEW.service_feature THEN
		RAISE EXCEPTION 'Features may not be renaemd due to possible constraint issues'
       		USING ERRCODE = 'invalid_paramater',
       		HINT = 'This feature is not implemented';
	END IF;

	PERFORM *
	FROM (select service_depend_id, service_id from service_version) sd
		JOIN service_version USING (service_id)
		JOIN service_instance si USING (service_version_id)
		JOIN service_version_collection_service_version svscsv
			USING (service_version_id)
		JOIN service_version_collection svc
			USING (service_version_collection_id)
		JOIN service_version_collection_permitted_feature svcpf
			USING (service_version_collection_id)
	WHERE	svcpf.service_feature = NEW.service_feature
	AND	sd.service_depend = NEW.service_depend_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'service_feature is not offered by any versions of service'
       		USING ERRCODE = 'foreign_key_violation',
       		HINT = 'An entry in service_version_collection_permitted_feature may be required';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_depend_feature_check
	ON service_depend_service_feature;
CREATE CONSTRAINT TRIGGER trigger_service_depend_feature_check
	AFTER INSERT OR UPDATE OF service_feature
	ON service_depend_service_feature
	FOR EACH ROW
	EXECUTE PROCEDURE service_depend_feature_check();

------------------------------------------------------------------------------

