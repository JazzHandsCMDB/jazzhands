-- Copyright (c) 2023 Todd Kover
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

\ir ../../ddl/schema/pgsql/create_rack_compat_trigger.sql

\t on

savepoint pretest;
DROP FUNCTION IF EXISTS check_rack_location_compat();
CREATE FUNCTION check_rack_location_compat() RETURNS BOOLEAN AS $$
DECLARE
	_dev	device%ROWTYPE;
	_comp	component%ROWTYPE;
	_dt		device_type%ROWTYPE;
	_se		service_environment.service_environment_id%TYPE;
	_rl1	rack_location.rack_location_id%TYPE;
	_rl2	rack_location.rack_location_id%TYPE;
	_ctid	component.component_id%TYPE;
	_d		RECORD;
	_r		RECORD;
BEGIN
	-- delete some stuff
	RAISE NOTICE '++ Checking if Rack Device/Component Compat works';

	INSERT INTO service_environment (
		service_environment_name, service_environment_type, production_state
	) VALUES (
		'jhtest', 'default', 'development'
	) RETURNING service_environment_id INTO _se;

	RAISE NOTICE '++ Inserting Test Data';
	INSERT INTO site (
		site_code, site_status
	) VALUES (
		'JHTEST01', 'ACTIVE'
	);

	INSERT INTO component_type (
		model, is_rack_mountable, is_virtual_component
	) VALUES ('jh comp1', true, false) RETURNING component_type_id INTO _ctid;

	INSERT INTO device_type (device_type_name, component_type_id)
		VALUES ('test', _ctid )
		RETURNING * INTO _dt;

	INSERT INTO site (site_code, site_status) VALUES ('JHSITE0', 'ACTIVE');

	WITH r AS (
		INSERT INTO rack (
			site_code, rack_name, rack_style, rack_height_in_u,
			display_from_bottom
		) VALUES (
			'JHSITE0', 'Rack0', 'CABINET', 50, true
		) RETURNING *
	) INSERT INTO rack_location (
			rack_id, rack_u_offset_of_device_top, rack_side
		) SELECT rack_id, 20, 'FRONT'
			FROM r RETURNING rack_location_id INTO _rl1;

	WITH r AS (
		INSERT INTO rack (
			site_code, rack_name, rack_style, rack_height_in_u,
			display_from_bottom
		) VALUES (
			'JHSITE0', 'Rack1', 'CABINET', 50, true
		) RETURNING *
	) INSERT INTO rack_location (
			rack_id, rack_u_offset_of_device_top, rack_side
		) SELECT rack_id, 24, 'FRONT' FROM r
			RETURNING rack_location_id INTO _rl2;

	----
	BEGIN
		RAISE NOTICE '++ Checking if Rack Component, Device Compat works';
		INSERT INTO component ( component_type_id, rack_location_id )
			VALUES (_ctid, _rl1) RETURNING * INTO _comp;

		INSERT INTO device (device_type_id, device_status, component_id,
			service_environment_id
		) VALUES (
			_dt.device_type_id, 'up', _comp.component_id, _se
		) RETURNING * INTO _d;

		SELECT * INTO _r FROM device WHERE device_id = _d.device_id;

		IF _r != _d THEN
			RAISE EXCEPTION 'INSERT return dow not match what was inserted';
		END IF;

		IF _d.rack_location_id IS DISTINCT FROM _rl1 THEN
			RAISE EXCEPTION 'rack_location did not get populated from component % %', _r.rack_location_id, _rl1;
		END IF;
		RAISE EXCEPTION 'All good' USING ERRCODE = 'JH999';

		---

		RAISE NOTICE '... Checking if changing component propagates';
		UPDATE component SET rack_location_id = _rl2 RETURNING * INTO _d;
		SELECT * INTO _r FROM component WHERE component_id = _comp.component_id;
		IF _r != _d THEN
			RAISE EXCEPTION 'UPDATE component return dow not match what was inserted';
		END IF;
		IF _d.rack_location_id IS DISTINCT FROM _rl2 THEN
			RAISE EXCEPTION 'rack_location did not get set';
		END IF;
		SELECT * INTO _r FROM device WHERE device_id = _dev.device_id;
		IF _d.rack_location_id IS DISTINCT FROM _rl2 THEN
			RAISE EXCEPTION 'rack_location did not migrate from component to device';
		END IF;
		RAISE NOTICE '... it worked';
		RAISE EXCEPTION 'All good' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '++ Done Checking if Rack Component, Device Compat works: %', SQLERRM;
	END;
	----

	BEGIN
		RAISE NOTICE '++ Checking if Rack Device, Component Compat works';
		INSERT INTO component ( component_type_id )
			VALUES (_ctid ) RETURNING * INTO _comp;

		INSERT INTO device (device_type_id, device_status, component_id,
			service_environment_id, rack_location_id
		) VALUES (
			_dt.device_type_id, 'up', _comp.component_id, _se, _rl1
		) RETURNING * INTO _d;

		SELECT * INTO _r FROM device WHERE device_id = _d.device_id;

		IF _r != _d THEN
			RAISE EXCEPTION 'INSERT return dow not match what was inserted';
		END IF;

		IF _d.rack_location_id IS DISTINCT FROM _rl1 THEN
			RAISE EXCEPTION 'rack_location did not get populated from component';
		END IF;
		SELECT * INTO _r FROM component WHERE component_id = _comp.component_id;
		IF _r.rack_location_id IS DISTINCT FROM _rl1 THEN
			RAISE EXCEPTION 'rack_location did not migrate from component to device ( % % % )', _r.rack_location_id, _rl1, _rl2;
		END IF;

		RAISE NOTICE '... it worked';

		----

		RAISE NOTICE '... Checking if changing device propagates';
		UPDATE device SET rack_location_id = _rl2 RETURNING * INTO _d;
		SELECT * INTO _r FROM device WHERE device_id = _d.device_id;
		IF _r != _d THEN
			RAISE EXCEPTION 'UPDATE component return dow not match what was inserted';
		END IF;
		IF _d.rack_location_id IS DISTINCT FROM _rl2 THEN
			RAISE EXCEPTION 'rack_location did not get set';
		END IF;
		SELECT * INTO _r FROM component WHERE component_id = _comp.component_id;
		IF _d.rack_location_id IS DISTINCT FROM _rl2 THEN
			RAISE EXCEPTION 'rack_location did not migrate from device to component (% %)', _d.rack_location_id, _rl2;
		END IF;
		RAISE NOTICE '... it worked';
		RAISE EXCEPTION 'All good' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '++ DONE Checking if Rack Device, Component Compat works';
	END;


	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT check_rack_location_compat();
DROP FUNCTION check_rack_location_compat();

ROLLBACK TO pretest;
\t off
