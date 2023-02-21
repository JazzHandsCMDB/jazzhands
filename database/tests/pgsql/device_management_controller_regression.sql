-- Copyright (c) 2022 Todd Kover
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

-- \ir ../../ddl/schema/pgsql/create_device_management_controller_triggers.sql

\t on
SAVEPOINT dmc_test;

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION device_manageemnt_controller_regression() RETURNS BOOLEAN AS $$
DECLARE
	device1		device%ROWTYPE;
	device2		device%ROWTYPE;
	device3		device%ROWTYPE;
	device4		device%ROWTYPE;
	comp1		component%ROWTYPE;
	comp2		component%ROWTYPE;
	comp3		component%ROWTYPE;
	comp4		component%ROWTYPE;
	comptype	component_type%ROWTYPE;
	devtype		device_type%ROWTYPE;
	_r		RECORD;
	_d		RECORD;
BEGIN
	RAISE NOTICE '++ device_manageemnt_controller_regression: Inserting testing data';

	INSERT INTO component_type (
		description
	) values (
		'management controller test component_type'
	) RETURNING * INTO comptype;

	INSERT INTO device_type (
		model,
		component_type_id
	) values (
		'management controller test device_type',
		comptype.component_type_id
	) RETURNING * INTO devtype;

	INSERT INTO component (
		component_type_id, component_name
	) values (
		comptype.component_type_id, 'test component 1'
	) RETURNING * INTO comp1;
	INSERT INTO device (
		component_id,
		device_name,
		device_type_id,
		device_status,
		service_environment_id
	) values (
		comp1.component_id,
		'management controller test device 1',
		devtype.device_type_id,
		'up',
		1
	) RETURNING * INTO device1;

	INSERT INTO component (
		component_type_id, component_name
	) values (
		comptype.component_type_id, 'test component 1'
	) RETURNING * INTO comp2;
	INSERT INTO device (
		component_id,
		device_name,
		device_type_id,
		device_status,
		service_environment_id
	) values (
		comp2.component_id,
		'management controller test device 2',
		devtype.device_type_id,
		'up',
		1
	) RETURNING * INTO device2;

	INSERT INTO component (
		component_type_id, component_name
	) values (
		comptype.component_type_id, 'test component 1'
	) RETURNING * INTO comp3;
	INSERT INTO device (
		component_id,
		device_name,
		device_type_id,
		device_status,
		service_environment_id
	) values (
		comp3.component_id,
		'management controller test device 3',
		devtype.device_type_id,
		'up',
		1
	) RETURNING * INTO device3;

	INSERT INTO component (
		component_type_id, component_name
	) values (
		comptype.component_type_id, 'test component 1'
	) RETURNING * INTO comp4;
	INSERT INTO device (
		component_id,
		device_name,
		device_type_id,
		device_status,
		service_environment_id
	) values (
		comp4.component_id,
		'management controller test device 4',
		devtype.device_type_id,
		'up',
		1
	) RETURNING * INTO device4;

	---------------------------------------------------------------------------
	RAISE NOTICE '++ Checking insert...';
	INSERT INTO jazzhands.val_component_management_controller_type (
		component_management_controller_type
	) VALUES ( 'testbmc');
	INSERT INTO jazzhands.val_component_management_controller_type (
		component_management_controller_type
	) VALUES ( 'bmctest');

	INSERT INTO device_management_controller (
		device_id, manager_device_id, device_management_control_type, description
	) VALUES (
		device1.device_id, device2.device_id, 'testbmc', 'foobar'
	) RETURNING * INTO _r;

	SELECT * INTO _d FROM device_management_controller
	WHERE device_id = device1.device_id
	AND manager_device_id = device2.device_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Insert failed';
	END IF;

	IF _r != _d THEN
		RAISE EXCEPTION 'INSERT results do not match: % %', jsonb_pretty(to_jsonb(_r)), jsonb_pretty(to_jsonb(_d));
	END IF;

	IF _r.device_management_control_type != 'testbmc' THEN
		RAISE EXCEPTION 'device_management_control_type is not testbmc: %', _r.device_management_control_type;
	END IF;

	IF _r.description != 'foobar' THEN
		RAISE EXCEPTION 'description is not foobar: %', _r.description;
	END IF;

	RAISE NOTICE '... Insert worked...';

	---------------------------------------------------------------------------
	RAISE NOTICE '++ Checking update of device_id...';
	BEGIN
		UPDATE device_management_controller
		SET device_id = device3.device_id, device_management_control_type = 'bmctest'
		WHERE device_id = device1.device_id
		AND manager_device_id = device2.device_id
		RETURNING * INTO _r;

		SELECT * INTO _d FROM device_management_controller
		WHERE device_id = device3.device_id
		AND manager_device_id = device2.device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'Update failed';
		END IF;

		IF _r != _d THEN
			RAISE EXCEPTION 'UPDATE results do not match: % %', jsonb_pretty(to_jsonb(_r)), jsonb_pretty(to_jsonb(_d));
		END IF;

		IF _r.device_management_control_type != 'bmctest' THEN
			RAISE EXCEPTION 'device_management_control_type is not bmctest: %', _r.device_management_control_type;
		END IF;

		IF _r.description != 'foobar' THEN
			RAISE EXCEPTION 'description is not foobar: %', _r.description;
		END IF;

		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	 EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... Update worked... (%)', SQLERRM;
	END;

	---------------------------------------------------------------------------
	RAISE NOTICE '++ Checking update of manager_device_id...';
	BEGIN
		UPDATE device_management_controller
		SET manager_device_id = device3.device_id,
			description = 'barfoo'
		WHERE device_id = device1.device_id
		AND manager_device_id = device2.device_id
		RETURNING * INTO _r;

		SELECT * INTO _d FROM device_management_controller
		WHERE device_id = device1.device_id
		AND manager_device_id = device3.device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'Update failed';
		END IF;

		IF _r != _d THEN
			RAISE EXCEPTION 'UPDATE results do not match: % %', jsonb_pretty(to_jsonb(_r)), jsonb_pretty(to_jsonb(_d));
		END IF;

		IF _r.device_management_control_type != 'testbmc' THEN
			RAISE EXCEPTION 'device_management_control_type is not testbmc: %', _r.device_management_control_type;
		END IF;

		IF _r.description != 'barfoo' THEN
			RAISE EXCEPTION 'description is not foobar: %', _r.description;
		END IF;

		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	 EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... Update worked... (%)', SQLERRM;
	END;

	RAISE NOTICE '++ Checking Delete...';
	SELECT * INTO _d FROM device_management_controller
	WHERE device_id = device1.device_id
	AND manager_device_id = device2.device_id;

	DELETE FROM device_management_controller
	WHERE device_id = device1.device_id
	AND manager_device_id = device2.device_id
	RETURNING * INTO _r;

	IF _r != _d THEN
		RAISE EXCEPTION 'UPDATE results do not match: % %', jsonb_pretty(to_jsonb(_r)), jsonb_pretty(to_jsonb(_d));
	END IF;

	IF _r.device_management_control_type != 'testbmc' THEN
		RAISE EXCEPTION 'device_management_control_type is not testbmc: %', NEW.device_management_control_type;
	END IF;

	IF _r.description != 'foobar' THEN
		RAISE EXCEPTION 'description is not foobar: %', _r.description;
	END IF;
	RAISE NOTICE '... Delete worked';

	RAISE NOTICE '+++  done regression';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT device_manageemnt_controller_regression();
-- set search_path=jazzhands;
DROP FUNCTION device_manageemnt_controller_regression();

ROLLBACK TO dmc_test;

\t off
