-- Copyright (c) 2016-2017 Todd Kover
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

SAVEPOINT device_asset_removal_prep_test;

-- test this:
-- \ir ../../ddl/schema/pgsql/create_asset_move_RETIRE.sql

CREATE OR REPLACE FUNCTION validate_device_asset_removal_preps() RETURNS BOOLEAN AS $$
DECLARE
	_tal			integer;
	_ass			asset%ROWTYPE;
	_ass2			asset%ROWTYPE;
	_dev			device%ROWTYPE;
	_com1			component%ROWTYPE;
	_com2			component%ROWTYPE;
	_ct			component_type%ROWTYPE;
	_dt			device_type%ROWTYPE;
BEGIN
	RAISE NOTICE '++ Beginning tests of device_asset_removal_update_nontime...';

	INSERT INTO component_type (
		description, asset_permitted
	) values (
		'some sort of testing component', 'Y'
	) RETURNING * INTO _ct;

	INSERT INTO device_type (
		model, rack_units, has_802_3_interface,
		has_802_11_interface, snmp_capable, is_chassis, component_type_id
	) values (
		'JHTEST type', 2, 'N', 'N', 'N', 'Y', _ct.component_type_id
	) RETURNING * INTO _dt;

	INSERT INTO component (
		component_type_id, component_name
	) values (
		_ct.component_type_id, 'test component 1'
	) RETURNING * INTO _com1;

	INSERT INTO component (
		component_type_id, component_name
	) values (
		_ct.component_type_id, 'test component 2'
	) RETURNING * INTO _com2;

	RAISE NOTICE 'Checking if inserting an asset after device works right...';
	BEGIN
		INSERT INTO device (
			device_name, device_type_id, device_status, service_environment_id,
			is_monitored, component_id)
		VALUES (
			'asset test 1', _dt.device_type_id, 'up', 1,
			'N', _com1.component_id
		) RETURNING * INTO _dev;

		INSERT INTO asset (
			component_id, ownership_status
		) values (
			_com1.component_id, 'owned'
		) RETURNING * INTO _ass;

		SELECT * INTO _dev FROM device where device_id = _dev.device_id;
		IF _dev.component_id != _com1.component_id THEN
			RAISE EXCEPTION '.... it did not % %!', _dev, _com1;
		END IF;
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Checking if inserting a device after asset works right...';
	BEGIN
		INSERT INTO asset (
			component_id, ownership_status
		) values (
			_com1.component_id, 'owned'
		) RETURNING * INTO _ass;

		INSERT INTO device (
			device_name, device_type_id, device_status, service_environment_id,
			is_monitored, asset_id)
		VALUES (
			'asset test 1', _dt.device_type_id, 'up', 1,
			'N', _ass.asset_id
		) RETURNING * INTO _dev;

		IF _dev.component_id != _com1.component_id THEN
			RAISE EXCEPTION '.... it did not % v % -- % % %!', 
				_dev.component_id, _com1.component_id,_dev, _com1, _ass;
		END IF;
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Checking if changing a device component id goes to asset...';
	BEGIN
		INSERT INTO asset (
			component_id, ownership_status
		) values (
			_com1.component_id, 'owned'
		) RETURNING * INTO _ass;

		INSERT INTO asset (
			component_id, ownership_status
		) values (
			_com2.component_id, 'owned'
		) RETURNING * INTO _ass2;

		INSERT INTO device (
			device_name, device_type_id, device_status, service_environment_id,
			is_monitored, asset_id)
		VALUES (
			'asset test 1', _dt.device_type_id, 'up', 1,
			'N', _ass.asset_id
		) RETURNING * INTO _dev;

		UPDATE device
		SET component_id = _com2.component_id
		WHERE device_id = _dev.device_id
		RETURNING * INTO _dev;

		IF _dev.asset_id != _ass2.asset_id THEN
			RAISE EXCEPTION '.... it did not % v % -- % % % %!', 
				_dev.component_id, _com2.component_id,_dev, _com1, _com2, _ass;
		END IF;
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Checking if changing a device component id wo/asset fails...';
	BEGIN
		INSERT INTO asset (
			component_id, ownership_status
		) values (
			_com1.component_id, 'owned'
		) RETURNING * INTO _ass;

		INSERT INTO device (
			device_name, device_type_id, device_status, service_environment_id,
			is_monitored, asset_id)
		VALUES (
			'asset test 1', _dt.device_type_id, 'up', 1,
			'N', _ass.asset_id
		) RETURNING * INTO _dev;

		BEGIN
			UPDATE device
			SET component_id = _com2.component_id
			WHERE device_id = _dev.device_id
			RETURNING * INTO _dev;

			RAISE EXCEPTION '...  IT did not?!';
		EXCEPTION WHEN invalid_parameter_value THEN
			RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
		END;
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did (expected)!';
	END;

	RAISE NOTICE 'Checking if changing asset.asset_id fails';
	BEGIN
		INSERT INTO asset (
			component_id, ownership_status
		) values (
			_com1.component_id, 'owned'
		) RETURNING * INTO _ass;

		BEGIN
			UPDATE asset
			SET asset_id = asset_id + 100
			WHERE asset_id = _ass.asset_id;

			RAISE EXCEPTION '...  IT did?!';
		EXCEPTION WHEN invalid_parameter_value THEN
			RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
		END;
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did (expected)!';
	END;

	RAISE NOTICE 'Checking if changing asset.component_id changes device.component_id... ';
	BEGIN
		INSERT INTO device (
			device_name, device_type_id, device_status, service_environment_id,
			is_monitored, component_id)
		VALUES (
			'asset test 1', _dt.device_type_id, 'up', 1,
			'N', _com1.component_id
		) RETURNING * INTO _dev;

		INSERT INTO asset (
			component_id, ownership_status
		) values (
			_com1.component_id, 'owned'
		) RETURNING * INTO _ass;

		UPDATE asset SET component_id = _com2.component_id
		WHERE asset_id = _ass.asset_id;

		SELECT * INTO _dev FROM device where device_id = _dev.device_id;

		IF _dev.component_id != _com2.component_id THEN
			RAISE EXCEPTION '.... it did not % % %!', _dev, _com1, _com2;
		END IF;
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;



	RAISE NOTICE '++ End tests of device_asset_removal_update_nontime...';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT jazzhands.validate_device_asset_removal_preps();
DROP FUNCTION validate_device_asset_removal_preps();

ROLLBACK TO device_asset_removal_prep_test;

\t off
