/*
 * Copyright (c) 2014-2019 Todd Kover
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

CREATE OR REPLACE FUNCTION service_environment_collection_hier_enforce()
RETURNS TRIGGER AS $$
DECLARE
	serviceenvt	val_service_environment_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	serviceenvt
	FROM	val_service_environment_collection_type
	WHERE	service_environment_collection_type =
		(select service_environment_collection_type
			from service_environment_collection
			where service_environment_collection_id =
				NEW.service_environment_collection_id);

	IF serviceenvt.can_have_hierarchy = false THEN
		RAISE EXCEPTION 'Service Environment Collections of type % may not be hierarcical',
			serviceenvt.service_environment_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_environment_collection_hier_enforce
	 ON service_environment_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_service_environment_collection_hier_enforce
        AFTER INSERT OR UPDATE
        ON service_environment_collection_hier
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE service_environment_collection_hier_enforce();


-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION service_environment_collection_member_enforce()
RETURNS TRIGGER AS $$
DECLARE
	serviceenvt	val_service_environment_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	serviceenvt
	FROM	val_service_environment_collection_type
	WHERE	service_environment_collection_type =
		(select service_environment_collection_type
			from service_environment_collection
			where service_environment_collection_id =
				NEW.service_environment_collection_id);

	IF serviceenvt.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from service_environment_collection_service_environment
		  where service_environment_collection_id = NEW.service_environment_collection_id;
		IF tally > serviceenvt.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF serviceenvt.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from service_environment_collection_service_environment
		  		inner join service_environment_collection
					USING (service_environment_collection_id)
		  where service_environment_id = NEW.service_environment_id
		  and	service_environment_collection_type =
					serviceenvt.service_environment_collection_type;
		IF tally > serviceenvt.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Service Environment may not be a member of more than % collections of type %',
				serviceenvt.MAX_NUM_COLLECTIONS, serviceenvt.service_environment_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_environment_collection_member_enforce
	 ON service_environment_collection_service_environment;
CREATE CONSTRAINT TRIGGER trigger_service_environment_collection_member_enforce
        AFTER INSERT OR UPDATE
        ON service_environment_collection_service_environment
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE service_environment_collection_member_enforce();
