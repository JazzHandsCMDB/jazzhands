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


-- These next two triggers go away with device.location_id does.

--
-- This trigger enforces that new inserts only set one of location_id or
-- rack_location_id
--
-- It also enforces that if something updates rack_location_id that  it does
-- not also update location_id.
CREATE OR REPLACE FUNCTION aaa_device_location_migration_2() 
RETURNS TRIGGER AS $$
DECLARE
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.rack_location_id is not null and NEW.location_id is NOT NULL THEN
			RAISE EXCEPTION 'Only rack_location_id should be set.  Location_Id is going away.'
				USING ERRCODE = 'JH0FF';
		ELSIF NEW.rack_location_id IS NOT NULL OR NEW.location_Id IS NOT NULL THEN
			IF NEW.rack_location_id IS NULL THEN
				NEW.rack_location_id = NEW.location_id;
			ELSIF NEW.location_id IS NULL THEN
				NEW.location_id = NEW.rack_location_id;
			ELSE
				RAISE EXCEPTION 'This shold never happen';
			END IF;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		if OLD.RACK_LOCATION_ID != NEW.RACK_LOCATION_ID THEN
			IF NEW.LOCATION_ID != OLD.LOCATION_ID THEN
				RAISE EXCEPTION 'Only rack_location_id should be set.  Location_Id is going away.'
					USING ERRCODE = 'JH0FF';
			END IF;
			NEW.RACK_LOCATION_ID := NEW.LOCATION_ID;
		END IF;
	END IF;

	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_aaa_device_location_migration_2 ON device;
CREATE TRIGGER trigger_aaa_device_location_migration_2 
	BEFORE INSERT OR UPDATE of RACK_LOCATION_ID
	ON device 
	FOR EACH ROW
	EXECUTE PROCEDURE aaa_device_location_migration_2();


-- This ensures that if someone is updating location_id that they are not
-- also updating rack_location_id.  It runs before the previous trigger, but it
-- provides a similar sanity chek as the update clause of there.
CREATE OR REPLACE FUNCTION aaa_device_location_migration_1() 
RETURNS TRIGGER AS $$
DECLARE
BEGIN
	-- If location_id did not really change, then there is nothing to do here,
	-- although it is fishy
	if OLD.LOCATION_ID != NEW.LOCATION_ID THEN
		IF NEW.LOCATION_ID = NEW.RACK_LOCATION_ID THEN
			RAISE EXCEPTION 'Only rack_location_id should be set.  Location_Id is going away.'
				USING ERRCODE = 'JH0FF';
		END IF;
		NEW.RACK_LOCATION_ID := NEW.LOCATION_ID;
	else
		RAISE NOTICE 'aaa_device_location_migration_1 called for no apparent reason. This is fishy';
	END IF;
	return NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_aaa_device_location_migration_1 ON device;
CREATE TRIGGER trigger_aaa_device_location_migration_1 
	BEFORE UPDATE of LOCATION_ID
	ON device 
	FOR EACH ROW
	EXECUTE PROCEDURE aaa_device_location_migration_1();


----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- 
-- column retirement triggers above, below, not so much.
--
----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION device_one_location_validate() 
RETURNS TRIGGER AS $$
DECLARE
BEGIN
	IF NEW.RACK_LOCATION_ID IS NOT NULL AND NEW.CHASSIS_LOCATION_ID IS NOT NULL THEN
		RAISE EXCEPTION 'Both Rack_Location_Id and Chassis_Location_Id may not be set.'
			USING ERRCODE = 'unique_violation';
	END IF;

	IF NEW.CHASSIS_LOCATION_ID IS NOT NULL AND NEW.PARENT_DEVICE_ID IS NULL THEN
		RAISE EXCEPTION 'Must set parent_device_id if setting chassis location.'
			USING ERRCODE = 'foreign_key_violation';
	END IF;
	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_one_location_validate ON device;
CREATE TRIGGER trigger_device_one_location_validate 
	BEFORE INSERT OR UPDATE -- OF RACK_LOCATION_ID, CHASSIS_LOCATION_ID, PARENT_DEVICE_ID
	ON device 
	FOR EACH ROW
	EXECUTE PROCEDURE device_one_location_validate();


----------------------------------------------------------------------------

-- Only one of device_type_module_z or device_type_side may be set.  If
-- the former, it means the module is inside the device, if the latter, its
-- visible outside of the device.
CREATE OR REPLACE FUNCTION device_type_module_sanity_set() 
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.DEVICE_TYPE_Z_OFFSET IS NOT NULL AND NEW.DEVICE_TYPE_SIDE IS NOT NULL THEN
		RAISE EXCEPTION 'Both Z Offset and Device_Type_Side may not be set'
			USING ERRCODE = 'JH001';
	END IF;
	RETURN NEW;
END;
$$ 
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_type_module_sanity_set 
	ON device_type_module;
CREATE TRIGGER trigger_device_type_module_sanity_set 
	BEFORE INSERT OR UPDATE ON device_type_module 
	FOR EACH ROW
	EXECUTE PROCEDURE device_type_module_sanity_set();

-- 
-- device types marked with is_chassis = 'Y' need to keep that if there
-- are device_type_modules associated.
-- 
CREATE OR REPLACE FUNCTION device_type_chassis_check()
RETURNS TRIGGER AS $$
DECLARE
	_tally	integer;
BEGIN
	IF TG_OP != 'UPDATE' THEN
		RAISE EXCEPTION 'This should not happen %!', TG_OP;
	END IF;
	IF OLD.is_chassis = 'Y' THEN
		IF NEW.is_chassis = 'N' THEN
			SELECT 	count(*)
			  INTO	_tally
			  FROM	device_type_module
			 WHERE	device_type_id = NEW.device_type_id;

			IF _tally >  0 THEN
				RAISE EXCEPTION 'Is_chassis must be Y when a device_type still has device_type_module s'
					USING ERRCODE = 'foreign_key_violation';
			END IF;
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_type_chassis_check 
	ON device_type;
CREATE TRIGGER trigger_device_type_chassis_check 
	BEFORE UPDATE OF is_chassis
	ON device_type
	FOR EACH ROW
	EXECUTE PROCEDURE device_type_chassis_check();

--
-- related to above.  device_type_module.device_type_id must have
-- 
--
CREATE OR REPLACE FUNCTION device_type_module_chassis_check()
RETURNS TRIGGER AS $$
DECLARE
	_ischass	device_type.is_chassis%TYPE;
BEGIN
	SELECT 	is_chassis
	  INTO	_ischass
	  FROM	device_type
	 WHERE	device_type_id = NEW.device_type_id;

	IF _ischass = 'N' THEN
		RAISE EXCEPTION 'Is_chassis must be Y for chassis device_types'
			USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;

END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_type_module_chassis_check 
	ON device_type_module;
CREATE TRIGGER trigger_device_type_module_chassis_check 
	BEFORE INSERT OR UPDATE of DEVICE_TYPE_ID
	ON device_type_module 
	FOR EACH ROW
	EXECUTE PROCEDURE device_type_module_chassis_check();

