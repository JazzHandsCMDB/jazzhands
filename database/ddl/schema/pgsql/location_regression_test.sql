-- Copyright (c) 2014 Matthew Ragan
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

-- $Id$

\t on

CREATE FUNCTION validate_location_triggers() RETURNS BOOLEAN AS $$
DECLARE
	_device_id		device.device_id%TYPE;
	_location_id		location.location_id%TYPE;
	_device_type_id		device_type.device_type_id%TYPE;
	_module_name		device_type_module.device_type_module_name%TYPE;
BEGIN
	-- delete some stuff
	delete from device_type where model = 'testmodel';
	delete from device where device_name = 'testdevice';

	-- setup test record
	INSERT INTO device_type (
		model, rack_units, has_802_3_interface,
		has_802_11_interface, snmp_capable
	) values (
		'testmodel', 5, 'N', 'N', 'N'
	) RETURNING device_type_id INTO _device_type_id;

	-- test all the states
	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT validate_location_triggers();
DROP FUNCTION validate_location_triggers();

\t off
