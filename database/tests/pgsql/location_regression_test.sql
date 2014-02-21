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
	_chassis		device%ROWTYPE;
	_sled			device%ROWTYPE;
	_chassloc		location%ROWTYPE;
	_sledloc		location%ROWTYPE;
	_chassis_dt		device_type%ROWTYPE;
	_sled_dt		device_type%ROWTYPE;
	_sled_module		device_type_module%ROWTYPE;
	_rack			rack%ROWTYPE;
BEGIN
	-- delete some stuff
	RAISE NOTICE '++ Cleaning up records';
	delete from location where  device_type_id in (
		select device_type_id from device_type where model like 'JHTEST%');
	delete from device_type_module where description like 'JHTEST%';
	delete from device where device_name like 'JHTEST%';
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

	-- setup test record
	INSERT INTO device_type (
		model, rack_units, has_802_3_interface,
		has_802_11_interface, snmp_capable, is_chassis
	) values (
		'JHTEST Sled', 0, 'N', 'N', 'N', 'N'
	) RETURNING * INTO _sled_dt;

	INSERT INTO device (
		device_type_id, device_name, device_status, site_code,
		service_environment, operating_system_id,
		ownership_status, is_monitored
	) values (
		_chassis_dt.device_type_id, 'JHTEST chassis', 'up', 'JHTEST01',
		'production', 0,
		'owned', 'Y'
	) RETURNING * into _chassis;

	INSERT INTO device (
		device_type_id, device_name, device_status, site_code,
		service_environment, operating_system_id,
		ownership_status, is_monitored
	) values (
		_sled_dt.device_type_id, 'JHTEST sled', 'up', 'JHTEST01',
		'production', 0,
		'owned', 'Y'
	) RETURNING * into _sled;

	INSERT INTO rack (
		site_code, rack_name, rack_style, rack_height_in_u, display_from_bottom
	) values (
		'JHTEST01', 'JHTEST-01', 'CABINET', 42, 'Y'
	) RETURNING * into _rack;

	RAISE NOTICE '++ Done inserting Test Data';

	RAISE NOTICE 'Testing device_type_module_sanity_set on INSERT...';
	BEGIN
		INSERT INTO device_type_module (
			device_type_id, device_type_module_name, description,
			device_type_x_offset, device_type_y_offset, 
			device_type_z_offset, device_type_side
		) values (
			_sled_dt.device_type_id, 'sled0', 'JHTEST-sled',
			0, 1,
			5, 'FRONT'
		) RETURNING *  into _sled_module;
		RAISE EXCEPTION 'Inerting a module with both z and side suceeded when it should not.';
	EXCEPTION WHEN SQLSTATE 'JH350' THEN
		RAISE NOTICE 'Inserting a module with both z and side failed as expected.';
	END;

	INSERT INTO device_type_module (
		device_type_id, device_type_module_name, description,
		device_type_x_offset, device_type_y_offset, 
		device_type_side
	) values (
		_sled_dt.device_type_id, 'sled0', 'JHTEST-sled',
		0, 1,
		'FRONT'
	) RETURNING *  into _sled_module;

	RAISE NOTICE 'Testing device_type_module_sanity_set on UPDATE...';
	BEGIN
		UPDATE device_type_module
		SET	device_type_z_offset = 5
		WHERE device_type_id = _sled_dt.device_type_id
		AND device_type_module_name = 'sled0';
		RAISE EXCEPTION 'Updating a module with both z and side suceeded when it should not  - % %', _sled_dt.device_type_id, 'sled0';
	EXCEPTION WHEN SQLSTATE 'JH350' THEN
		RAISE NOTICE 'Updating a module with both z and side failed as expected.';
	END;

	RAISE NOTICE 'Done with testing device_type_module_sanity_set...';
	RAISE NOTICE 'Testing location_complex_sanity...';

	BEGIN
		INSERT INTO location (
			device_type_id, device_type_module_name, 
			rack_u_offset_of_device_top, rack_side
		) values (
			_chassis_dt.device_type_id, 'sled0', 
			10, 'FRONT'
		);
		RAISE EXCEPTION 'NULL location.rack_id suceeded on insert when it should not';
	EXCEPTION WHEN not_null_violation THEN
		RAISE NOTICE 'NULL location.rack_id failed to insert as expected';
	END;

	BEGIN
		INSERT INTO location (
			device_type_id, device_type_module_name,  rack_id,
			rack_side
		) values (
			_chassis_dt.device_type_id, 'sled0', _rack.rack_id,
			'FRONT'
		);
		RAISE EXCEPTION 'NULL location.rack_u_offset_of_device_top suceeded on insert when it should not';
	EXCEPTION WHEN not_null_violation THEN
		RAISE NOTICE 'NULL location.rack_u_offset_of_device_top failed on insert when it should';
	END;

	BEGIN
		INSERT INTO location (
			device_type_id, device_type_module_name, rack_id,
			rack_u_offset_of_device_top, rack_side
		) values (
			_chassis_dt.device_type_id, 'sled0', _rack.rack_id,
			10, 'FRONT'
		);
		RAISE EXCEPTION 'insert into location with both rack values and module sets works when it does not';
	EXCEPTION WHEN SQLSTATE 'JH350' THEN
		RAISE NOTICE 'insert into location with both rack values and module failed as expected';
	END;

	RAISE NOTICE 'Not testing location.rack_side NULLability since it defaults to FRONT (in a trigger)';

	INSERT INTO location (
		device_type_id, rack_id, rack_u_offset_of_device_top
	) values (
		_chassis_dt.device_type_id, _rack.rack_id, 50
	) RETURNING * into _chassloc;

	BEGIN
		UPDATE location set rack_id = NULL
		WHERE location_id = _chassloc.location_id;
		RAISE EXCEPTION 'update rack_id to NULL suceeded when it should have failed.';
	EXCEPTION WHEN not_null_violation THEN
		RAISE NOTICE 'update rack_id to NULL failed when it should have.';
	END;

	BEGIN
		UPDATE location set rack_u_offset_of_device_top = NULL
		WHERE location_id = _chassloc.location_id;
		RAISE EXCEPTION 'update rack_u_offset_of_device_top to NULL suceeded when it should have failed.';
	EXCEPTION WHEN not_null_violation THEN
		RAISE NOTICE 'update rack_u_offset_of_device_top to NULL failed when it should have.';
	END;

	INSERT INTO location (
		device_type_id, device_type_module_name
	) values (
		_sled_dt.device_type_id, 'sled0'
	) RETURNING * into _sledloc;

	RAISE NOTICE 'Done testing location_complex_sanity...';

	RAISE NOTICE 'Need to test device_type_module_sanity_del';

	-- test all the states
	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT validate_location_triggers();
DROP FUNCTION validate_location_triggers();

\t off
