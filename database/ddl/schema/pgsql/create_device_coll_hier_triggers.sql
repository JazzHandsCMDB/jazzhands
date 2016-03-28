/*
 * Copyright (c) 2014 Todd Kover
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

CREATE OR REPLACE FUNCTION device_collection_hier_enforce()
RETURNS TRIGGER AS $$
DECLARE
	dct	val_device_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_device_collection_type
	WHERE	device_collection_type =
		(select device_collection_type from device_collection
			where device_collection_id = NEW.parent_device_collection_id);

	IF dct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Device Collections of type % may not be hierarcical',
			dct.device_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_device_collection_hier_enforce
	 ON device_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_device_collection_hier_enforce
        AFTER INSERT OR UPDATE 
        ON device_collection_hier
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE device_collection_hier_enforce();


-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION device_collection_member_enforce()
RETURNS TRIGGER AS $$
DECLARE
	dct	val_device_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_device_collection_type
	WHERE	device_collection_type =
		(select device_collection_type from device_collection
			where device_collection_id = NEW.device_collection_id);

	IF dct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from device_collection_device
		  where device_collection_id = NEW.device_collection_id;
		IF tally > dct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF dct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from device_collection_device
		  		inner join device_collection using (device_collection_id)
		  where device_id = NEW.device_id
		  and	device_collection_type = dct.device_collection_type;
		IF tally > dct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Device may not be a member of more than % collections of type %',
				dct.MAX_NUM_COLLECTIONS, dct.device_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_device_collection_member_enforce
	 ON device_collection_device;
CREATE CONSTRAINT TRIGGER trigger_device_collection_member_enforce
        AFTER INSERT OR UPDATE 
        ON device_collection_device
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE device_collection_member_enforce();
