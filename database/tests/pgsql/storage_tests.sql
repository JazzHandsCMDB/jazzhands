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
--

\set ON_ERROR_STOP

\ir ../../pkg/pgsql/property_utils.sql
\ir ../../ddl/schema/pgsql/create_filesystem_triggers.sql

\t on

savepoint pretest;
DROP FUNCTION IF EXISTS storage_regression_test();
CREATE FUNCTION storage_regression_test() RETURNS BOOLEAN AS $$
DECLARE
	_dt		device_type;
	_d		device;
	_ctid	component_type.component_type_id%TYPE;
	_r		RECORD;
BEGIN
	INSERT INTO device_type ( model) VALUES ( 'JHTEST') RETURNING * INTO _dt;

	INSERT INTO val_logical_volume_type (logical_volume_type) VALUES ('jhtest');

	INSERT INTO component_type (model) VALUES ('disk') RETURNING component_type_id INTO _ctid;
	INSERT INTO val_block_storage_device_type (block_storage_device_type)
		VALUES ('jhtestfs');

	INSERT INTO val_filesystem_type (
		filesystem_type,
		permit_mountpoint,
		permit_filesystem_label,
		permit_filesystem_serial
	) VALUES (
		'all',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED'
	);

	INSERT INTO val_filesystem_type (
		filesystem_type,
		permit_mountpoint,
		permit_filesystem_label,
		permit_filesystem_serial
	) VALUES (
		'mountpoint',
		'REQUIRED',
		'PROHIBITED',
		'PROHIBITED'
	);

	INSERT INTO val_filesystem_type (
		filesystem_type,
		permit_mountpoint,
		permit_filesystem_label,
		permit_filesystem_serial
	) VALUES (
		'label',
		'PROHIBITED',
		'REQUIRED',
		'PROHIBITED'
	);

	INSERT INTO val_filesystem_type (
		filesystem_type,
		permit_mountpoint,
		permit_filesystem_label,
		permit_filesystem_serial
	) VALUES (
		'serial',
		'PROHIBITED',
		'PROHIBITED',
		'REQUIRED'
	);

	INSERT INTO device (
		device_name,
		device_type_id,
		device_status,
		service_environment_id
	) VALUES (
		'JHSTORAGE test',
		_dt.device_type_id,
		'up',
		1
	) RETURNING * INTO _d;

	BEGIN
		RAISE NOTICE 'Checking for mountpoint';
		WITH c AS (
			INSERT INTO component ( component_type_id ) VALUES (_ctid) RETURNING *
		), bs AS (
			INSERT INTO block_storage_device (
				block_storage_device_name, block_storage_device_type,
				device_id, component_id
			) SELECT 'foo', 'jhtestfs', _d.device_id, component_id FROM c RETURNING *
		) INSERT INTO filesystem (
			block_storage_device_id, device_id, filesystem_type, mountpoint
		) SELECT block_storage_device_id, device_id, 'mountpoint', '/foo' FROM bs
		RETURNING * INTO _r;
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... ok';
	END;

	BEGIN
		RAISE NOTICE 'Checking for serial';
		WITH c AS (
			INSERT INTO component ( component_type_id ) VALUES (_ctid) RETURNING *
		), bs AS (
			INSERT INTO block_storage_device (
				block_storage_device_name, block_storage_device_type,
				device_id, component_id
			) SELECT 'bar', 'jhtestfs', _d.device_id, component_id FROM c RETURNING *
		) INSERT INTO filesystem (
			block_storage_device_id, device_id, filesystem_type, filesystem_serial
		) SELECT block_storage_device_id, device_id, 'serial', 'bar' FROM bs
		RETURNING * INTO _r;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... ok';
	END;

	BEGIN
		RAISE NOTICE 'Checking for label';
		WITH c AS (
			INSERT INTO component ( component_type_id ) VALUES (_ctid) RETURNING *
		), bs AS (
			INSERT INTO block_storage_device (
				block_storage_device_name, block_storage_device_type,
				device_id, component_id
			) SELECT 'baz', 'jhtestfs', _d.device_id, component_id FROM c RETURNING *
		) INSERT INTO filesystem (
			block_storage_device_id, device_id, filesystem_type, filesystem_label
		) SELECT block_storage_device_id, device_id, 'label', 'baz' FROM bs
	RETURNING * INTO _r;
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... ok';
	END;

	BEGIN
		RAISE NOTICE 'Checking for mountpoint fail on label...';
		WITH c AS (
			INSERT INTO component ( component_type_id ) VALUES (_ctid) RETURNING *
		), bs AS (
			INSERT INTO block_storage_device (
				block_storage_device_name, block_storage_device_type,
				device_id, component_id
			) SELECT 'mp1', 'jhtestfs', _d.device_id, component_id FROM c RETURNING *
		) INSERT INTO filesystem (
			block_storage_device_id, device_id, filesystem_type, mountpoint
		) SELECT block_storage_device_id, device_id, 'label', '/fp1' FROM bs
		RETURNING * INTO _r;
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '... failed correctly';
	END;

	BEGIN
		RAISE NOTICE 'Checking for mountpoint fail on serial...';
		WITH c AS (
			INSERT INTO component ( component_type_id ) VALUES (_ctid) RETURNING *
		), bs AS (
			INSERT INTO block_storage_device (
				block_storage_device_name, block_storage_device_type,
				device_id, component_id
			) SELECT 'mp1', 'jhtestfs', _d.device_id, component_id FROM c RETURNING *
		) INSERT INTO filesystem (
			block_storage_device_id, device_id, filesystem_type, mountpoint
		) SELECT block_storage_device_id, device_id, 'serial', '/fp1' FROM bs
		RETURNING * INTO _r;
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '... failed correctly';
	END;

	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT storage_regression_test();
DROP FUNCTION storage_regression_test();

ROLLBACK TO pretest;
\t off
