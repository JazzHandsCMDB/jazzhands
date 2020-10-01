-- Copyright (c) 2016, Matthew Ragan
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

-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'rack_utils';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS rack_utils;
		CREATE SCHEMA rack_utils AUTHORIZATION jazzhands;
		REVOKE ALL ON SCHEMA rack_utils FROM public;
		COMMENT ON SCHEMA rack_utils IS 'part of jazzhands';

	END IF;
END;
$$;

-------------------------------------------------------------------
-- begin rack_utils.set_rack_location
--
-- NOTE: even if device_id and component_id are not passed, the
-- rack_location is created if it does not exist and returned,
-- so this function may be used for that purpose
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rack_utils.set_rack_location (
	rack_id			jazzhands.rack.rack_id%TYPE,
	device_id		jazzhands.device.device_id%TYPE DEFAULT NULL,
	component_id	jazzhands.component.component_id%TYPE DEFAULT NULL,
	rack_u_offset_of_device_top 
					jazzhands.rack_location.rack_u_offset_of_device_top%TYPE
					DEFAULT NULL,
	rack_side 		jazzhands.rack_location.rack_side%TYPE DEFAULT 'FRONT',
	allow_duplicates	boolean DEFAULT true
) RETURNS jazzhands.rack_location.rack_location_id%TYPE AS $$
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
		RAISE 'rack_id must be specified to rack_utils.set_rack_location()';
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
		SELECT * INTO rec FROM component c WHERE d.component_id = cid;
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
--end rack_utils.set_rack_location
-------------------------------------------------------------------

REVOKE ALL ON SCHEMA rack_utils FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA rack_utils FROM public;

GRANT USAGE ON SCHEMA rack_utils TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA rack_utils TO iud_role;
