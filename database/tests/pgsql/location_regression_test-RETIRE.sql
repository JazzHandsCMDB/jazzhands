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


DROP FUNCTION IF EXISTS validate_device_location_namechange_triggers();
CREATE FUNCTION validate_device_location_namechange_triggers() RETURNS BOOLEAN AS $$
DECLARE
	_chassis		device%ROWTYPE;
	_chassisloc		rack_location%ROWTYPE;
	_chassisloc2	rack_location%ROWTYPE;
	_chassis_dt		device_type%ROWTYPE;
	_rack			rack%ROWTYPE;
	_nrack			rack%ROWTYPE;
	_r				RECORD;
	_loc			location%ROWTYPE;
	_nloc			location%ROWTYPE;
BEGIN
	-- delete some stuff
	SET CONSTRAINTS fk_chasloc_chass_devid DEFERRED;
	SET CONSTRAINTS fk_dev_chass_loc_id_mod_enfc DEFERRED;
	RAISE NOTICE '++ Cleaning up records';
	delete from chassis_location where chassis_device_id in (
		select device_id from device where device_name like 'JHTEST%');
	delete from device where device_name like 'JHTEST%';
	delete from rack_location where rack_id in
		(select rack_id from rack where rack_name like 'JHTEST%');
	delete from device_type_module where description like 'JHTEST%';
	delete from device_type where model like 'JHTEST%';
	delete from rack where rack_name like 'JHTEST%';
	delete from site where site_code like 'JHTEST%';
	SET constraints FK_CHASLOC_CHASS_DEVID immediate;
	SET constraints fk_dev_chass_loc_id_mod_enfc immediate;

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

	INSERT INTO rack_location (
		rack_id, rack_u_offset_of_device_top, rack_side
	) VALUES (
		_rack.rack_id, 5, 'FRONT'
	) RETURNING * INTO _chassisloc;

	INSERT INTO rack_location (
		rack_id, rack_u_offset_of_device_top, rack_side
	) VALUES (
		_rack.rack_id, 10, 'FRONT'
	) RETURNING * INTO _chassisloc2;

	RAISE NOTICE '++ Done inserting Test Data';

	RAISE NOTICE 'Testing if both device.rack_location_id and location_id may not be set on insert.';
	BEGIN
		INSERT INTO device (
			device_type_id, device_name, device_status, site_code,
			service_environment, operating_system_id,
			ownership_status, is_monitored,
			rack_location_id, location_id
		) values (
			_chassis_dt.device_type_id, 'JHTEST chassis', 'up', 'JHTEST01',
			'production', 0,
			'owned', 'Y',
			_chassisloc.rack_location_id, _chassisloc.rack_location_id
		) RETURNING * into _chassis;
		RAISE EXCEPTION 'Insert that touches both device.rack_location_id and location_id suceeded when it should not.';
	EXCEPTION WHEN SQLSTATE 'JH0FF' THEN
		RAISE NOTICE 'Insert that touches both device.rack_location_id and location_id failed as expected.';
	END;

	RAISE NOTICE 'Testing if setting location_id propagates to rack_location_id on insert';
	INSERT INTO device (
		device_type_id, device_name, device_status, site_code,
		service_environment, operating_system_id,
		ownership_status, is_monitored,
		location_id
	) values (
		_chassis_dt.device_type_id, 'JHTEST chassis', 'up', 'JHTEST01',
		'production', 0,
		'owned', 'Y',
		_chassisloc.rack_location_id
	) RETURNING * into _chassis;
	IF _chassis.LOCATION_ID = _chassis.RACK_LOCATION_ID THEN
		RAISE NOTICE '... It did.';
	ELSE
		RAISE EXCEPTION '... IT DID NOT';
	END IF;

	RAISE NOTICE 'Testing if updating both rack_location_id and location_id fails as expected';
	BEGIN
		UPDATE DEVICE
		  set	location_id = _chassisloc2.rack_location_id,
		  	rack_location_id = _chassisloc2.rack_location_id
		where	device_id = _chassis.device_id;
		RAISE EXCEPTION '... IT DID NOT';
	EXCEPTION WHEN SQLSTATE 'JH0FF' THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Testing if updating rack_location_id propagates to location_id';
	UPDATE DEVICE
	  set	location_id = _chassisloc2.rack_location_id
	where	device_id = _chassis.device_id;
	SELECT * into _chassis from device where device_id = _chassis.device_id;
	IF _chassis.LOCATION_ID = _chassis.RACK_LOCATION_ID THEN
		RAISE NOTICE '... It did.';
	ELSE
		RAISE EXCEPTION '... IT DID NOT';
	END IF;

	RAISE NOTICE 'Testing if updating location_id propagates to rack_location_id';
	UPDATE DEVICE
	  set	rack_location_id = _chassisloc.rack_location_id
	where	device_id = _chassis.device_id;
	SELECT * into _chassis from device where device_id = _chassis.device_id;
	IF _chassis.LOCATION_ID = _chassis.RACK_LOCATION_ID THEN
		RAISE NOTICE '... It did.';
	ELSE
		RAISE EXCEPTION '... IT DID NOT';
	END IF;

	RAISE NOTICE 'Checking to see if inserts to location work... ';
	INSERT INTO location (
		rack_id, rack_u_offset_of_device_top, rack_side,
		inter_device_offset
	) values (
		_rack.rack_id, 15, 'FRONT',
		15
	) RETURNING * INTO _loc;

	IF _loc.location_id is NULL or _loc.rack_id != _rack.rack_id or _loc.rack_u_offset_of_device_top != 15 or _loc.rack_side != 'FRONT' THEN
		RAISE EXCEPTION '... They do not: %', _loc;
	ELSE
		RAISE NOTICE '... They do: %', _loc;
	END IF;

	RAISE NOTICE 'Checking to see if updates on location work... ';
	INSERT INTO rack (
		site_code, rack_name, rack_style, rack_height_in_u, display_from_bottom
	) values (
		'JHTEST01', 'JHTEST-02', 'CABINET', 42, 'Y'
	) RETURNING * into _nrack;

	UPDATE location set
		location_id = location_id + 1,
		rack_id = _nrack.rack_id,
		rack_side = 'BACK',
		rack_u_offset_of_device_top = 17
	WHERE location_id = _loc.location_id;

	SELECT * INTO _nloc from location where location_id = _loc.location_id + 1;

	IF _nloc.location_id is NULL or _nloc.location_id != _loc.location_id + 1 or _nloc.rack_id != _nrack.rack_id or _nloc.rack_u_offset_of_device_top != 17 or _nloc.rack_side != 'BACK' THEN
		RAISE EXCEPTION '... They do: % %', _loc, _nloc;
	ELSE
		RAISE NOTICE '... They do: % %', _loc, _nloc;
	END IF;

	RAISE NOTICE 'Checking to see if updating things to raises an exception...';
	UPDATE location 
	set location_id = location_id 
	where location_id = _nloc.location_id;
	RAISE NOTICE '... It does';

	RAISE NOTICE 'Deleting a record to see if it goes away...';
	DELETE from location where location_id = _nloc.location_id;

	SELECT * INTO _nloc from location where location_id = _loc.location_id + 1;
	IF _nloc.location_id IS NULL THEN
		RAISE NOTICE '... It does.';
	ELSE
		RAISE EXCEPTION '... It does NOT %', _nloc;
	END IF;

	-- test all the states
	-- run same deletes as at start
	SET CONSTRAINTS fk_chasloc_chass_devid DEFERRED;
	SET CONSTRAINTS fk_dev_chass_loc_id_mod_enfc DEFERRED;
	RAISE NOTICE '++ Cleaning up records';
	delete from chassis_location where chassis_device_id in (
		select device_id from device where device_name like 'JHTEST%');
	delete from device where device_name like 'JHTEST%';
	delete from rack_location where rack_id in
		(select rack_id from rack where rack_name like 'JHTEST%');
	delete from device_type_module where description like 'JHTEST%';
	delete from device_type where model like 'JHTEST%';
	delete from rack where rack_name like 'JHTEST%';
	delete from site where site_code like 'JHTEST%';
	SET constraints FK_CHASLOC_CHASS_DEVID immediate;
	SET constraints fk_dev_chass_loc_id_mod_enfc immediate;
	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT validate_device_location_namechange_triggers();
DROP FUNCTION validate_device_location_namechange_triggers();
