-- Copyright (c) 2014 Todd Kover
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

\set ON_ERROR_STOP

\t on

DROP FUNCTION IF EXISTS validate_device_location_triggers();
CREATE FUNCTION validate_device_location_triggers() RETURNS BOOLEAN AS $$
DECLARE
	_chassis		device%ROWTYPE;
	_sled			device%ROWTYPE;
	_chassisloc		rack_location%ROWTYPE;
	_chassisloc2		rack_location%ROWTYPE;
	_sledloc		chassis_location%ROWTYPE;
	_chassis_dt		device_type%ROWTYPE;
	_sled_dt		device_type%ROWTYPE;
	_sled_module		device_type_module%ROWTYPE;
	_rack			rack%ROWTYPE;
	_r			RECORD;
BEGIN
	-- delete some stuff
	RAISE NOTICE '++ Cleaning up records';
	delete from chassis_location where chassis_device_id in (
		select device_id from device where device_name like 'JHTEST%');
	delete from device_type_module_device_type where description
		like 'JHTEST%';
	delete from device where device_name like 'JHTEST%';
	delete from rack_location where rack_id in
		(select rack_id from rack where rack_name like 'JHTEST%');
	delete from device_type_module where description like 'JHTEST%';
	delete from device_type where model like 'JHTEST%';
	delete from rack where rack_name like 'JHTEST%';
	delete from site where site_code like 'JHTEST%';

	-- setup test record
	RAISE NOTICE '++ Inserting Test Data';
	INSERT INTO site (
		site_code, site_status
	) VALUES (
		'JHTEST01', 'ACTIVE'
	);

	INSERT INTO device_type (
		model, rack_units, has_802_3_interface,
		has_802_11_interface, snmp_capable, is_chassis
	) values (
		'JHTEST Chassis', 2, 'N', 'N', 'N', 'Y'
	) RETURNING * INTO _chassis_dt;

	INSERT INTO rack (
		site_code, rack_name, rack_style, rack_height_in_u, display_from_bottom
	) values (
		'JHTEST01', 'JHTEST-01', 'CABINET', 42, 'Y'
	) RETURNING * into _rack;

	INSERT INTO device_type (
		model, rack_units, has_802_3_interface,
		has_802_11_interface, snmp_capable, is_chassis
	) values (
		'JHTEST Sled', 0, 'N', 'N', 'N', 'N'
	) RETURNING * INTO _sled_dt;

	INSERT INTO rack_location (
		rack_id, rack_u_offset_of_device_top
	) VALUES (
		_rack.rack_id, 5
	) RETURNING * INTO _chassisloc;

	INSERT INTO rack_location (
		rack_id, rack_u_offset_of_device_top, rack_side
	) VALUES (
		_rack.rack_id, 10, 'FRONT'
	) RETURNING * INTO _chassisloc2;

	INSERT INTO device (
		device_type_id, device_name, device_status, site_code,
		service_environment, operating_system_id,
		ownership_status, is_monitored,
		rack_location_id
	) values (
		_chassis_dt.device_type_id, 'JHTEST chassis', 'up', 'JHTEST01',
		'production', 0,
		'owned', 'Y',
		_chassisloc.rack_location_id
	) RETURNING * into _chassis;
	RAISE NOTICE '++ Done inserting Test Data';

	RAISE NOTICE 'Testing if device_type_module_sanity_set fails to insert...';
	BEGIN
		INSERT INTO device_type_module (
			device_type_id, device_type_module_name, description,
			device_type_x_offset, device_type_y_offset,
			device_type_z_offset, device_type_side
		) VALUES (
			_chassis_dt.device_type_id, 'slot0', 'JHTEST',
			1, 1,
			1, 'FRONT'
		) returning * into _sled_module;

		RAISE EXCEPTION '... IT DOES NOT';
	EXCEPTION WHEN SQLSTATE 'JH001' THEN
		RAISE NOTICE '... It Does.';
	END;

	RAISE NOTICE 'Testing to see if a device_type_module can not be inserted with is_chassis = N...';
	BEGIN
		INSERT INTO device_type_module (
			device_type_id, device_type_module_name, description,
			device_type_x_offset, device_type_y_offset,
			device_type_side
		) VALUES (
			_sled_dt.device_type_id, 'slot0', 'JHTEST',
			1, 1,
			'FRONT'
		) returning * into _sled_module;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN foreign_key_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO device_type_module (
		device_type_id, device_type_module_name, description,
		device_type_x_offset, device_type_y_offset,
		device_type_side
	) VALUES (
		_chassis_dt.device_type_id, 'slot0', 'JHTEST',
		1, 1,
		'FRONT'
	) returning * into _sled_module;

	RAISE NOTICE 'Testing to see if a chassis device_type can have is_chassis set to N';
	BEGIN
		UPDATE device_type
		  SET  is_chassis = 'N'
		WHERE device_type_id = _chassis_dt.device_type_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN foreign_key_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Testing to see if a device_type_module can move to a device type with is_chassis = N';
	BEGIN
		UPDATE device_type_module
		  SET  device_type_id = _sled_dt.device_type_id
		WHERE device_type_id = _chassis_dt.device_type_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN foreign_key_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Testing to see if a chassis/module mismatch fails as expected...';

	BEGIN
		INSERT INTO chassis_location (
			chassis_device_type_id, device_type_module_name,
			chassis_device_id, module_device_type_id
		) values (
			_chassis_dt.device_type_id, _sled_module.device_type_module_name,
			_chassis.device_id, _sled_dt.device_type_id
		) RETURNING * into _sledloc;
		RAISE EXCEPTION '... IT DID NOT!';
	EXCEPTION WHEN foreign_key_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Inserting into device_type_module_device_type ...';
	INSERT INTO device_type_module_device_type (
		device_type_id, device_type_module_name,
		module_device_type_id, description
	) values (
		_chassis_dt.device_type_id, _sled_module.device_type_module_name,
		_sled_dt.device_type_id, 'JHTEST-MAP'
	);

	RAISE NOTICE 'Inserting into chassis_location...';
	INSERT INTO chassis_location (
		chassis_device_type_id, device_type_module_name,
		chassis_device_id, module_device_type_id
	) values (
		_chassis_dt.device_type_id, _sled_module.device_type_module_name,
		_chassis.device_id, _sled_dt.device_type_id
	) RETURNING * into _sledloc;

	RAISE NOTICE 'Attempting to insert a device with a chassis location and no parent to see if it fails... (% %)',
		_sled_dt.device_type_id, _sledloc.chassis_location_id;
	BEGIN
		INSERT INTO device (
			device_type_id, device_name, device_status, site_code,
			service_environment, operating_system_id,
			ownership_status, is_monitored,
			chassis_location_id
		) values (
			_sled_dt.device_type_id, 'JHTEST sled', 'up', 'JHTEST01',
			'production', 0,
			'owned', 'Y',
			_sledloc.chassis_location_id
		) RETURNING * into _sled;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN foreign_key_violation THEN
		RAISE NOTICE '... It did.';
	END;

	RAISE NOTICE 'Attempting to insert a device with both chassis and rack location to see if it fails...';
	BEGIN
		INSERT INTO device (
			device_type_id, device_name, device_status, site_code,
			service_environment, operating_system_id,
			ownership_status, is_monitored, parent_device_id,
			rack_location_id, chassis_location_id
		) values (
			_sled_dt.device_type_id, 'JHTEST sled', 'up', 'JHTEST01',
			'production', 0,
			'owned', 'Y', _chassis.device_Id,
			_chassisloc.rack_location_id, _sledloc.chassis_location_id
		) RETURNING * into _sled;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did.';
	END;

	RAISE NOTICE 'Inserting sled device; this should work...';
	INSERT INTO device (
		device_type_id, device_name, device_status, site_code,
		service_environment, operating_system_id,
		ownership_status, is_monitored, parent_device_id,
		chassis_location_id
	) values (
		_sled_dt.device_type_id, 'JHTEST sled', 'up', 'JHTEST01',
		'production', 0,
		'owned', 'Y', _chassis.device_id,
		_sledloc.chassis_location_id
	) RETURNING * into _sled;

	RAISE NOTICE 'Attempting to update a rack location to the sled and see if it fails...';
	BEGIN
		UPDATE device
		 SET   rack_location_id = _chassisloc.rack_location_id
		WHERE  device_id = _sled.device_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did.';
	END;

	-- test all the states
	-- run same queries as at the beginning
        SET CONSTRAINTS fk_chasloc_chass_devid DEFERRED;
        SET CONSTRAINTS fk_dev_chass_loc_id_mod_enfc DEFERRED;
	delete from chassis_location where chassis_device_id in (
		select device_id from device where device_name like 'JHTEST%');
	delete from device_type_module_device_type where description
		like 'JHTEST%';
	delete from device where device_name like 'JHTEST%';
	delete from rack_location where rack_id in
		(select rack_id from rack where rack_name like 'JHTEST%');
	delete from device_type_module where description like 'JHTEST%';
	delete from device_type where model like 'JHTEST%';
	delete from rack where rack_name like 'JHTEST%';
	delete from site where site_code like 'JHTEST%';
        SET CONSTRAINTS fk_chasloc_chass_devid IMMEDIATE;
        SET CONSTRAINTS fk_dev_chass_loc_id_mod_enfc IMMEDIATE;

	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT validate_device_location_triggers();
DROP FUNCTION validate_device_location_triggers();
\t off
