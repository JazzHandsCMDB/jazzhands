/*
 * Copyright (c) 2020 Todd Kover
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

\set ON_ERROR_STOP

/*
 * deal with the insertion of images
 */

/*
 * This exists just to make it so that the users that manipulate pictures
 * can be kept out of the jazzhands schema.
 */
CREATE OR REPLACE FUNCTION jazzhands_legacy.insert_person_image_into_base_schema(
	NEW	jazzhands_legacy.person_image
)
RETURNS jazzhands_legacy.person_image AS $$
BEGIN
	INSERT INTO jazzhands.person_image(
		person_image_id,
		person_id,
		person_image_order,
		image_type,
		image_blob,
		image_checksum,
		image_label,
		description
	) VALUES (
		concat(NEW.person_image_id, nextval('jazzhands.person_image_person_image_id_seq'))::integer,
		NEW.person_id,
		NEW.person_image_order,
		NEW.image_type,
		NEW.image_blob,
		NEW.image_checksum,
		NEW.image_label,
		NEW.description
	) RETURNING * INTO NEW;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION ins_person_image()
RETURNS TRIGGER AS $$
DECLARE
   b	integer;
   str	varchar;
BEGIN

	--
	-- actually insert the trigger
	--
	NEW := jazzhands_legacy.insert_person_image_into_base_schema(NEW);

	--
	-- This is copied from the jazzhands.fix_person_image_oid_ownership()
	-- trigger
	--

	b := NEW.image_blob;
	BEGIN
		str := 'GRANT SELECT on LARGE OBJECT ' || b || ' to picture_image_ro';
		EXECUTE str;
		str :=  'GRANT UPDATE on LARGE OBJECT ' || b || ' to picture_image_rw';
		EXECUTE str;
	EXCEPTION WHEN OTHERS THEN
		RAISE NOTICE 'Unable to grant on %', b;
	END;

	BEGIN
		EXECUTE 'ALTER large object ' || b || ' owner to jazzhands';
	EXCEPTION WHEN OTHERS THEN
		RAISE NOTICE 'Unable to adjust ownership of %', b;
	END;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY INVOKER;


DROP TRIGGER IF EXISTS trigger_ins_person_image ON person_image;
CREATE TRIGGER trigger_ins_person_image
INSTEAD OF INSERT
    ON jazzhands_legacy.person_image
    FOR EACH ROW
    EXECUTE PROCEDURE ins_person_image();
