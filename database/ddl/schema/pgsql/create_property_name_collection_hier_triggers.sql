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

CREATE OR REPLACE FUNCTION property_name_collection_hier_enforce()
RETURNS TRIGGER AS $$
DECLARE
	pct	val_property_name_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	pct
	FROM	val_property_name_collection_type
	WHERE	property_name_collection_type =
		(select property_name_collection_type from property_name_collection
			where property_name_collection_id = NEW.property_name_collection_id);

	IF pct.can_have_hierarchy = false THEN
		RAISE EXCEPTION 'Property Collections of type % may not be hierarcical',
			pct.property_name_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_property_name_collection_hier_enforce
	 ON property_name_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_property_name_collection_hier_enforce
        AFTER INSERT OR UPDATE
        ON property_name_collection_hier
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE property_name_collection_hier_enforce();


-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION property_name_collection_member_enforce()
RETURNS TRIGGER AS $$
DECLARE
	pct	val_property_name_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	pct
	FROM	val_property_name_collection_type
	WHERE	property_name_collection_type =
		(select property_name_collection_type from property_name_collection
			where property_name_collection_id = NEW.property_name_collection_id);

	IF pct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from property_name_collection_property_name
		  where property_name_collection_id = NEW.property_name_collection_id;
		IF tally > pct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF pct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from property_name_collection_property_name
		  		inner join property_name_collection using (property_name_collection_id)
		  where
				property_name = NEW.property_name
		  and	property_type = NEW.property_type
		  and	property_name_collection_type = pct.property_name_collection_type;
		IF tally > pct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Property may not be a member of more than % collections of type %',
				pct.MAX_NUM_COLLECTIONS, pct.property_name_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_property_name_collection_member_enforce
	 ON property_name_collection_property_name;
CREATE CONSTRAINT TRIGGER trigger_property_name_collection_member_enforce
        AFTER INSERT OR UPDATE
        ON property_name_collection_property_name
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE property_name_collection_member_enforce();
