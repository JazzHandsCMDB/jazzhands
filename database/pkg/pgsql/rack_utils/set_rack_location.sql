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
-- begin rack_utils.set_rack_location
--
-- The rack_utils version of this can not be used to insert a new rack
--
-- NOTE: even if device_id and component_id are not passed, the
-- rack_location is created if it does not exist and returned,
-- so this function may be used for that purpose
-------------------------------------------------------------------

-- Clean up deprecated versions of this function

DROP FUNCTION IF EXISTS rack_utils.set_rack_location ( integer, integer, integer, integer, character varying, boolean);

CREATE OR REPLACE FUNCTION rack_utils.set_rack_location (
	rack_id			jazzhands.rack.rack_id%TYPE DEFAULT NULL,
	site_code		jazzhands.site.site_code%TYPE DEFAULT NULL,
	room			jazzhands.rack.room%TYPE DEFAULT NULL,
	sub_room		jazzhands.rack.sub_room%TYPE DEFAULT NULL,
	rack_row		jazzhands.rack.rack_row%TYPE DEFAULT NULL,
	rack_name		jazzhands.rack.rack_name%TYPE DEFAULT NULL,
	device_id		jazzhands.device.device_id%TYPE DEFAULT NULL,
	component_id	jazzhands.component.component_id%TYPE DEFAULT NULL,
	rack_u_offset_of_device_top 
					jazzhands.rack_location.rack_u_offset_of_device_top%TYPE
					DEFAULT NULL,
	rack_side 		jazzhands.rack_location.rack_side%TYPE DEFAULT 'FRONT',
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
	RETURN rack_manip.set_rack_location(
		rack_id := rack_id,
		site_code := site_code,
		room := room,
		sub_room := sub_room,
		rack_row := rack_row,
		rack_name := rack_name,
		device_id := device_id,
		component_id := component_id,
		rack_u_offset_of_device_top := rack_u_offset_of_device_top,
		allow_duplicates := allow_duplicates
	);
		
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end rack_utils.set_rack_location
-------------------------------------------------------------------

