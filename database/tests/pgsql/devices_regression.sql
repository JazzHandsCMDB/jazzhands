-- Copyright (c) 2019-2023 Todd Kover
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

\ir ../../pkg/pgsql/device_utils.sql
\ir ../../ddl/schema/pgsql/create_device_component_virtual_sync.sql

\t on
SAVEPOINT devices_tests;

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION devices_regression() RETURNS BOOLEAN AS $$
DECLARE
	_dt		device_type%rowtype;
	_dtv	device_type%rowtype;
	_dtnv	device_type%rowtype;
	_se		service_environment%rowtype;
	_d1		device%rowtype;
	_dv		device%rowtype;
	_dnv	device%rowtype;
	_cv		component%ROWTYPE;
	_cnv	component%ROWTYPE;
	_ctt	component_type%ROWTYPE;
	_ctf	component_type%ROWTYPE;
	_rl		rack_location.rack_location_id%TYPE;
BEGIN
	RAISE NOTICE 'devices_regression...';

	INSERT INTO service_environment (
		service_environment_name, service_environment_type, production_state
	) VALUES (
		'JHTEST', 'default', 'development'
	) RETURNING * INTO _se;

	INSERT INTO device_type ( device_type_name ) VALUES ('JHTESTMODEL')
		RETURNING * INTO _dt;

	INSERT INTO device (
		device_name, device_status, device_type_id, service_environment_id
	) VALUES (
		'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id
	) RETURNING * INTO _d1;

	RAISE NOTICE 'Trying to retire a device...';
	PERFORM device_utils.retire_device( _d1.device_id);

	RAISE NOTICE 'Adding component Types...';
	INSERT INTO component_type ( is_virtual_component )
		VALUES ( false ) RETURNING * INTO _ctf;
	INSERT INTO component_type ( is_virtual_component )
		VALUES ( true ) RETURNING * INTO _ctt;

	RAISE NOTICE 'Adding components...';
	INSERT INTO component ( component_type_id )
		VALUES ( _ctt.component_type_id ) RETURNING * INTO _cv;
	INSERT INTO component ( component_type_id )
		VALUES ( _ctf.component_type_id ) RETURNING * INTO _cnv;

	RAISE NOTICE 'Adding device_types ...';
	INSERT INTO device_type (device_type_name, component_type_id)
		VALUES ('JH Virtual', _cv.component_type_id)
		RETURNING * INTO _dtv;
	INSERT INTO device_type (device_type_name, component_type_id)
		VALUES ('JH Non-Virtual', _cnv.component_type_id)
		RETURNING * INTO _dtnv;


	RAISE NOTICE '+++ checking for device/component virutal mismatch I';
	BEGIN
		BEGIN
			INSERT INTO device (
				device_name, device_type_id, device_status, component_id,
				service_environment_id, is_virtual_device
			) VALUES (
				'mismatchvirtual', _dtv.device_type_id, 'up', _cv.component_id,
				_se.service_environment_id, false
			);
		EXCEPTION WHEN foreign_key_violation THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE '+++ checking for device/component virutal mismatch II';
	BEGIN
		BEGIN
			INSERT INTO device (
				device_name, device_type_id, device_status, component_id,
				service_environment_id, is_virtual_device
			) VALUES (
				'mismatchvirtual', _dtnv.device_type_id, 'up', _cnv.component_id,
				_se.service_environment_id, true
			);
		EXCEPTION WHEN foreign_key_violation THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE '+++ Inserting matching virtual device...';
	INSERT INTO device (
		device_name, device_type_id, device_status, component_id,
		service_environment_id, is_virtual_device
	) VALUES (
		'virtual', _dtv.device_type_id, 'up', _cv.component_id,
		_se.service_environment_id, true
	) RETURNING * INTO _dv;

	RAISE NOTICE '+++ Inserting matching non-virtual device...';
	INSERT INTO device (
		device_name, device_type_id, device_status, component_id,
		service_environment_id, is_virtual_device
	) VALUES (
		'non-virtual', _dtnv.device_type_id, 'up', _cnv.component_id,
		_se.service_environment_id, false
	) RETURNING * INTO _dnv;

	RAISE NOTICE '+++ Changing component_type false->true';
	BEGIN
		BEGIN
			UPDATE component_type
			SET is_virtual_component = true
			WHERE component_type_id = _cv.component_type_id;
		EXCEPTION WHEN foreign_key_violation THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE '+++ Changing component_type true->false';
	BEGIN
		BEGIN
			UPDATE component_type
			SET is_virtual_component = false
			WHERE component_type_id = _cnv.component_type_id;
		EXCEPTION WHEN foreign_key_violation THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE '+++ Changing device false->true';
	BEGIN
		BEGIN
			UPDATE device
			SET is_virtual_device = true
			WHERE device_id = _dnv.device_id;
		EXCEPTION WHEN foreign_key_violation THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE '+++ Changing device true->false';
	BEGIN
		BEGIN
			UPDATE device
			SET is_virtual_device = false
			WHERE device_id = _dv.device_id;
		EXCEPTION WHEN foreign_key_violation THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE '+++ Checking if virtual device can not have a rack_location_id';
	BEGIN
		BEGIN

			INSERT INTO site (site_code, site_status)
				VALUES ('JHSITE0', 'ACTIVE');

			WITH r AS (
				INSERT INTO rack (
					site_code, rack_name, rack_style, rack_height_in_u,
					display_from_bottom
				) VALUES (
					'JHSITE0', 'Rack0', 'CABINET', 50, true
				) RETURNING *
			)
				INSERT INTO rack_location (
				rack_id, rack_u_offset_of_device_top, rack_side
			) SELECT rack_id, 20, 'FRONT' FROM r
				RETURNING rack_location_id INTO _rl;

			UPDATE device SET rack_location_id = _rl
				WHERE device_id = _dv.device_id;

			RAISE EXCEPTION 'Ugh, It worked!';
		EXCEPTION WHEN check_violation THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE '+++ Checking if non-virtual device can have a rack_location_id';
	BEGIN
		INSERT INTO site (site_code, site_status)
			VALUES ('JHSITE0', 'ACTIVE');

		WITH r AS (
			INSERT INTO rack (
				site_code, rack_name, rack_style, rack_height_in_u,
				display_from_bottom
			) VALUES (
				'JHSITE0', 'Rack0', 'CABINET', 50, true
			) RETURNING *
		)
			INSERT INTO rack_location (
				rack_id, rack_u_offset_of_device_top, rack_side
		) SELECT rack_id, 20, 'FRONT' FROM r
			RETURNING rack_location_id INTO _rl;

		UPDATE device SET rack_location_id = _rl
			WHERE device_id = _dnv.device_id;

		RAISE EXCEPTION 'Uh oh';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '... It failed! (yay) (%)', SQLERRM;
	END;


	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT devices_regression();
DROP FUNCTION devices_regression();

ROLLBACK TO devices_tests;

\t off
