/*
 * Copyright (c) 2014-2015 Todd Kover
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

-------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- deal with model going away and being replaced with device_name
---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_type_model_to_name() 
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	IF TG_OP = 'UPDATE' AND  (NEW.model IS DISTINCT FROM OLD.model AND
			NEW.device_type_name IS DISTINCT FROM OLD.device_type_name) THEN
		RAISE EXCEPTION 'Only device_type_name should be updated.'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.model IS NOT NULL AND NEW.device_type_name IS NOT NULL THEN
			RAISE EXCEPTION 'Only model should be set.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	 
	END IF;

	IF TG_OP = 'UPDATE' THEN
		IF OLD.model IS DISTINCT FROM NEW.model THEN
			NEW.device_type_name = NEW.model;
		ELSIF OLD.device_type_name IS DISTINCT FROM NEW.device_type_name THEN
			NEW.model = NEW.device_type_name;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.model IS NOT NULL THEN
			NEW.device_type_name = NEW.model;
		ELSIF NEW.device_type_name IS NOT NULL THEN
			NEW.model = NEW.device_type_name;
		END IF;
	ELSE
	END IF;

	-- company_id is going away
	IF NEW.company_id IS NULL THEN
		NEW.company_id := 0;
	END IF;

	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_type_model_to_name 
	ON device_type;
CREATE TRIGGER trigger_device_type_model_to_name 
	BEFORE INSERT OR UPDATE OF device_type_name, model
	ON device_type 
	FOR EACH ROW 
	EXECUTE PROCEDURE device_type_model_to_name();
