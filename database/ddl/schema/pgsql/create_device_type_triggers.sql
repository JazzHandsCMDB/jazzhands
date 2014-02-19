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

-- (1) Previously, location.rack_* were NOT NULL.  Now trigger will enforce
--     that either all of rack_* or device_type_module_name is set but not
--     both.
-- (2) When device_type_module_name is set, there will be
--     trigger enforcement to ensure that it acts like a fk to
--     device_type_module.(device_type_id,device_type_module_name).  I did
--     not set this because it is possible for location.device_type_id to be
--     set to NULL when its not a device in a device
CREATE OR REPLACE FUNCTION location_complex_sanity() 
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	--
	-- If rack_* is set, then all rack_* must be set.
	--
	-- If rack_* is set, then device_type_module must not be set.
	--
	-- device_type_module_name is special
	--
	IF NEW.RACK_ID IS NOT NULL OR NEW.RACK_U_OFFSET_OF_DEVICE_TOP IS NOT NULL
			OR NEW.RACK_SIDE IS NOT NULL THEN
		-- default
		IF NEW.RACK_SIDE IS NULL THEN
			NEW.RACK_SIDE = 'FRONT';
		END IF;
		IF NEW.RACK_ID IS NULL OR NEW.RACK_U_OFFSET_OF_DEVICE_TOP IS NULL
				OR NEW.RACK_SIDE IS NULL THEN
			RAISE EXCEPTION 'LOCATION.RACK_* Values must be set if one is set.';
		END IF;
		IF NEW.DEVICE_TYPE_MODULE_NAME IS NOT NULL THEN
			RAISE EXCEPTION 'LOCATION.RACK_* must not be set at the same time as DEVICE_MODULE_NAME';
		END IF;
	ELSE
		IF NEW.DEVICE_TYPE_MODULE_NAME IS NULL THEN
			RAISE EXCEPTION 'All of LOCATION.RACK_* or DEVICE_MODULE_NAME must be set.';
		ELSE
			SELECT	COUNT(*)
			  INTO	_tally
			  FROM	device_type_module
			 WHERE	(NEW.device_type_id, NEW.device_type_module_name) 
			 		IN (device_type_id, device_type_module_name) ;

			IF _tally == 0 THEN
				RAISE EXCEPTION '(device_type_id, device_type_module_name) must exist in device_type_module.';
			END IF;
		END IF;
	END IF;
	
	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_location_complex_sanity ON location;
CREATE TRIGGER trigger_location_complex_sanity 
	BEFORE INSERT OR UPDATE
	ON location 
	FOR EACH ROW
	EXECUTE PROCEDURE location_complex_sanity();


CREATE OR REPLACE FUNCTION device_type_module_sanity_del() 
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	SELECT	COUNT(*)
	  INTO	_tally
	  FROM	location
	 WHERE	(OLD.device_type_id, OLD.device_type_module_name) 
		 		IN (device_type_id, device_type_module_name) ;

	IF _tally == 0 THEN
		RAISE EXCEPTION '(device_type_id, device_type_module_name) must NOT exist in location.';
	END IF;
	
	RETURN OLD;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_type_module_sanity_del 
	ON device_type_module;

CREATE TRIGGER trigger_device_type_module_sanity_del 
	BEFORE DELETE ON device_type_module 
	FOR EACH ROW
	EXECUTE PROCEDURE device_type_module_sanity_del();



-- Only one of device_type_module_z or device_type_side may be set.  If
-- the former, it means the module is inside the device, if the latter, its
-- visible outside of the device.
CREATE OR REPLACE FUNCTION device_type_module_sanity_set() 
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.DEVICE_TYPE_Z_OFFSET IS NOT NULL AND NEW.DEVICE_TYPE_SIDE IS NOT NULL THEN
		RAISE EXCEPTION 'Both Z Offset and Device_Type_Side may not be set';
	END IF;
	RETURN NEW;
END;
$$ 
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_type_module_sanity_set 
	ON device_type_module;

CREATE TRIGGER trigger_device_type_module_sanity_set 
	BEFORE INSERT OR DELETE ON device_type_module 
	FOR EACH ROW
	EXECUTE PROCEDURE device_type_module_sanity_set();

