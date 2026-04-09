-- Copyright (c) 2026, Matthew Ragan
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-------------------------------------------------------------------
-- begin rack_manip.set_rack_location
--
-- If insert_rack is true and both site_code and rack_name at a minimum
-- are passed, the rack will be inserted into the database if it does
-- not exist
--
-- NOTE: even if device_id and component_id are not passed, the
-- rack_location is created if it does not exist and returned,
-- so this function may be used for that purpose
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION rack_manip.set_rack_location (
	rack_id			jazzhands.rack.rack_id%TYPE DEFAULT NULL,
	site_code		jazzhands.site.site_code%TYPE DEFAULT NULL,
	room			jazzhands.rack.room%TYPE DEFAULT NULL,
	sub_room		jazzhands.rack.sub_room%TYPE DEFAULT NULL,
	rack_row		jazzhands.rack.rack_row%TYPE DEFAULT NULL,
	rack_name		jazzhands.rack.rack_name%TYPE DEFAULT NULL,
	rack_style		jazzhands.rack.rack_style%TYPE DEFAULT 'CABINET',
	rack_height_in_u	integer DEFAULT 48,
	display_from_bottom	boolean DEFAULT true,
	device_id		jazzhands.device.device_id%TYPE DEFAULT NULL,
	component_id	jazzhands.component.component_id%TYPE DEFAULT NULL,
	rack_u_offset_of_device_top 
					jazzhands.rack_location.rack_u_offset_of_device_top%TYPE
					DEFAULT NULL,
	rack_side 		jazzhands.rack_location.rack_side%TYPE DEFAULT 'FRONT',
	insert_rack			boolean DEFAULT false,
	allow_duplicates	boolean DEFAULT true
) RETURNS jazzhands.rack_location.rack_location_id%TYPE AS $$

#variable_conflict use_variable

DECLARE
	rid		ALIAS FOR	rack_id;
	devid	ALIAS FOR	device_id;
	cid		ALIAS FOR	component_id;
	rack_u	ALIAS FOR	rack_u_offset_of_device_top;
	side	ALIAS FOR	rack_side;
	rlid	jazzhands.rack_location.rack_location_id%TYPE;
	rec		RECORD;
	tally	integer;
BEGIN
	IF rack_id IS NULL THEN
		IF site_code IS NULL OR rack_name IS NULL THEN
			RAISE 'Either rack_id or both site_code and rack_name must be specified to rack_manip.set_rack_location()';
		END IF;
		SELECT
			r.rack_id INTO rid
		FROM
			rack r
		WHERE
			r.site_code IS NOT DISTINCT FROM site_code AND
			r.room IS NOT DISTINCT FROM room AND
			r.sub_room IS NOT DISTINCT FROM sub_room AND
			r.rack_row IS NOT DISTINCT FROM rack_row AND
			r.rack_name IS NOT DISTINCT FROM rack_name;

		IF NOT FOUND THEN
			IF NOT insert_rack THEN
				RAISE 'Rack not found and insert_rack is false';
			END IF;

			INSERT INTO rack(
				site_code,
				room,
				sub_room,
				rack_row,
				rack_name,
				rack_style,
				rack_height_in_u,
				display_from_bottom
			) VALUES (
				site_code,
				room,
				sub_room,
				rack_row,
				rack_name,
				rack_style,
				rack_height_in_u,
				display_from_bottom
			)
			RETURNING * INTO rec;
			rack_id := rec.rack_id;

			RAISE INFO 'Rack id is %', rack_id;
		END IF;
	END IF;

	SELECT
		rl.rack_location_id INTO rlid
	FROM
		rack_location rl
	WHERE
		rl.rack_id = rid AND
		rl.rack_u_offset_of_device_top IS NOT DISTINCT FROM rack_u AND
		rl.rack_side = side;
	
	IF NOT FOUND THEN
		INSERT INTO rack_location (
			rack_id,
			rack_u_offset_of_device_top,
			rack_side
		) VALUES (
			rid,
			rack_u,
			side
		) RETURNING rack_location_id INTO rlid;
	END IF;
	
	IF device_id IS NOT NULL THEN
		SELECT * INTO rec FROM device d WHERE d.device_id = devid;
		IF rec.rack_location_id IS DISTINCT FROM rlid THEN
			UPDATE device d SET rack_location_id = rlid WHERE
				d.device_id = devid;
			BEGIN
				DELETE FROM rack_location rl WHERE rl.rack_location_id = 
					rec.rack_location_id;
			EXCEPTION
				WHEN foreign_key_violation THEN
					NULL;
			END;
		END IF;
	END IF;

	IF component_id IS NOT NULL THEN
		SELECT * INTO rec FROM component c WHERE c.component_id = cid;
		IF rec.rack_location_id IS DISTINCT FROM rlid THEN
			UPDATE component c SET rack_location_id = rlid WHERE
				c.component_id = cid;
			BEGIN
				DELETE FROM rack_location rl WHERE rl.rack_location_id = 
					rec.rack_location_id;
			EXCEPTION
				WHEN foreign_key_violation THEN
					NULL;
			END;
		END IF;
	END IF;
	RETURN rlid;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end rack_manip.set_rack_location
-------------------------------------------------------------------

