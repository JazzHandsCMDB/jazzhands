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

\ir ../../ddl/schema/pgsql/create_filesystem_compat_triggers.sql

\t on

savepoint pretest;
DROP FUNCTION IF EXISTS filesystem_compat_tests();
CREATE FUNCTION filesystem_compat_tests() RETURNS BOOLEAN AS $$
DECLARE
	_dt		device_type;
	_bsd	block_storage_device;
	_d		device;
	_r		RECORD;
	_lv		logical_volume;
	_vg		volume_group;
	_lvp	logical_volume_property;
	_fs		filesystem;
BEGIN
	INSERT INTO device_type ( model) VALUES ( 'JHTEST') RETURNING * INTO _dt;
	INSERT INTO val_block_storage_device_type (block_storage_device_type, permit_logical_volume_id)
		VALUES ('jhtestfs', 'REQUIRED');

	INSERT INTO val_filesystem_type (
		filesystem_type, permit_mountpoint, permit_filesystem_label,
		permit_filesystem_serial
	) VALUES ( 'all', 'ALLOWED', 'ALLOWED', 'ALLOWED');

	INSERT INTO val_logical_volume_property (
		logical_volume_property_name, filesystem_type
	) VALUES
		('MountPoint', 'all'),
		('Serial', 'all'),
		('Label', 'all');

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

	INSERT INTO val_logical_volume_type (logical_volume_type) VALUES ('jhtest');
	INSERT INTO val_volume_group_type ( volume_group_type )
		VALUES ('JHTEST');
	INSERT INTO volume_group (
		volume_group_name, volume_group_type, device_id,
		volume_group_size_in_bytes
	) VALUES (
		'JHTEST', 'JHTEST', _d.device_id, 42
	) RETURNING * INTO _vg;
	INSERT INTO logical_volume (
		logical_volume_name, logical_volume_type, device_id,
		volume_group_id, logical_volume_size_in_bytes, filesystem_type
	) VALUES (
		'JHTEST', 'jhtest', _d.device_id,
		_vg.volume_group_id, 42, 'all'
	) RETURNING * INTO _lv;

	INSERT INTO block_storage_device (
		block_storage_device_name, block_storage_device_type,
		device_id, logical_volume_id
	) VALUES (
		'JHTEST', 'jhtestfs',
		_d.device_id, _lv.logical_volume_id
	) RETURNING * INTO _bsd;

	BEGIN
		RAISE NOTICE '+++ Checking if mountpoint propagate...';

		INSERT INTO filesystem (
			block_storage_device_id, device_id, filesystem_type, mountpoint
		) VALUES (
			_bsd.block_storage_device_id, _d.device_id, 'all', '/hate'
		);

		SELECT * INTO _lvp
		FROM logical_volume_property
		WHERE logical_volume_id = _lv.logical_volume_id
		AND logical_volume_property_name = 'MountPoint';

		IF NOT FOUND THEN
			RAISE EXCEPTION ' ... mountpoint did not propagate at all';
		ELSIF _lvp.logical_volume_property_value IS DISTINCT FROM '/hate'
		THEN
			RAISE EXCEPTION ' ... mountpoint propogated oddly: % v %',
				_lvp.logical_volume_property_value, '/hate';
		END IF;
		RAISE NOTICE '... insert propagated';

		UPDATE filesystem SET mountpoint = '/sleep'
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		SELECT * INTO _lvp
		FROM logical_volume_property
		WHERE logical_volume_id = _lv.logical_volume_id
		AND logical_volume_property_name = 'MountPoint';

		IF NOT FOUND THEN
			RAISE EXCEPTION ' ... mountpoint update did not propagate at all';
		ELSIF _lvp.logical_volume_property_value IS DISTINCT FROM '/sleep'
		THEN
			RAISE EXCEPTION ' ... mountpoint propogated oddly: % v %',
				_lvp.logical_volume_property_value, '/sleep';
		END IF;

		RAISE NOTICE '... update propagated';
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... ok';
	END;

	BEGIN
		RAISE NOTICE '+++ Checking if serial propagate...';

		INSERT INTO filesystem (
			block_storage_device_id, device_id, filesystem_type, filesystem_serial
		) VALUES (
			_bsd.block_storage_device_id, _d.device_id, 'all', '1234567890'
		);

		SELECT * INTO _lvp
		FROM logical_volume_property
		WHERE logical_volume_id = _lv.logical_volume_id
		AND logical_volume_property_name = 'Serial';

		IF NOT FOUND THEN
			RAISE EXCEPTION ' ... serial did not propagate at all';
		ELSIF _lvp.logical_volume_property_value IS DISTINCT FROM '1234567890'
		THEN
			RAISE EXCEPTION ' ... serial propogated oddly: % v %',
				_lvp.logical_volume_property_value, '1234567890';
		END IF;
		RAISE NOTICE '... insert propagated';

		UPDATE filesystem SET filesystem_serial = '987654321'
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		SELECT * INTO _lvp
		FROM logical_volume_property
		WHERE logical_volume_id = _lv.logical_volume_id
		AND logical_volume_property_name = 'Serial';

		IF NOT FOUND THEN
			RAISE EXCEPTION ' ... serial update did not propagate at all';
		ELSIF _lvp.logical_volume_property_value IS DISTINCT FROM '987654321'
		THEN
			RAISE EXCEPTION ' ... serial propogated oddly: % v %',
				_lvp.logical_volume_property_value, '987654321';
		END IF;

		RAISE NOTICE '... update propagated';
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... ok';
	END;

	BEGIN
		RAISE NOTICE '+++ Checking if label propagate...';

		INSERT INTO filesystem (
			block_storage_device_id, device_id, filesystem_type, filesystem_label
		) VALUES (
			_bsd.block_storage_device_id, _d.device_id, 'all', 'AF40C0F0-8CCF-4AF8-A414-F34FA35775A1'
		);

		SELECT * INTO _lvp
		FROM logical_volume_property
		WHERE logical_volume_id = _lv.logical_volume_id
		AND logical_volume_property_name = 'Label';

		IF NOT FOUND THEN
			RAISE EXCEPTION ' ... label did not propagate at all';
		ELSIF _lvp.logical_volume_property_value IS DISTINCT FROM 'AF40C0F0-8CCF-4AF8-A414-F34FA35775A1'
		THEN
			RAISE EXCEPTION ' ... label propogated oddly: % v %',
				_lvp.logical_volume_property_value, 'AF40C0F0-8CCF-4AF8-A414-F34FA35775A1';
		END IF;
		RAISE NOTICE '... insert propagated';

		UPDATE filesystem SET filesystem_label = '86F42A3D-BDE0-473C-8A5E-14D0FC32814F'
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		SELECT * INTO _lvp
		FROM logical_volume_property
		WHERE logical_volume_id = _lv.logical_volume_id
		AND logical_volume_property_name = 'Label';

		IF NOT FOUND THEN
			RAISE EXCEPTION ' ... label update did not propagate at all';
		ELSIF _lvp.logical_volume_property_value IS DISTINCT FROM '86F42A3D-BDE0-473C-8A5E-14D0FC32814F'
		THEN
			RAISE EXCEPTION ' ... label propogated oddly: % v %',
				_lvp.logical_volume_property_value, '86F42A3D-BDE0-473C-8A5E-14D0FC32814F';
		END IF;

		RAISE NOTICE '... update propagated';
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... ok';
	END;

	------------------------------------------------------------------------
	-- now try the other way...
	BEGIN
		RAISE NOTICE '++ trying to add a logical_volume_property for mountpoint...';
		INSERT INTO logical_volume_property (
			logical_volume_id, logical_volume_type, filesystem_type,
			logical_volume_property_name, logical_volume_property_value
		) VALUES (
			_lv.logical_volume_id, _lv.logical_volume_type, 'all',
			'MountPoint', '/hate'
		);

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION '... could not find filesystem mountpoint';
		ELSIF _fs.mountpoint IS DISTINCT FROM '/hate' THEN
			RAISE EXCEPTION ' ... label propogated oddly: % v %',
				_fs.mountpoint, '/hate';
		END IF;
		RAISE NOTICE '.....  inserting mountpoint worked';

		---
		INSERT INTO logical_volume_property (
			logical_volume_id, logical_volume_type, filesystem_type,
			logical_volume_property_name, logical_volume_property_value
		) VALUES (
			_lv.logical_volume_id, _lv.logical_volume_type, 'all',
			'Serial', 'C00X59'
		);

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION '... could not find filesystem';
		ELSIF _fs.filesystem_serial IS DISTINCT FROM 'C00X59' THEN
			RAISE EXCEPTION ' ... serial propogated oddly: % v %',
				_fs.filesystem_serial, 'C00X59';
		END IF;
		RAISE NOTICE '.....  inserting serial worked';

		---
		INSERT INTO logical_volume_property (
			logical_volume_id, logical_volume_type, filesystem_type,
			logical_volume_property_name, logical_volume_property_value
		) VALUES (
			_lv.logical_volume_id, _lv.logical_volume_type, 'all',
			'Label', 'AAD59997-3F75-40FA-BD65-2A780CADEE68'
		) RETURNING * INTO _lvp;

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION '... could not find filesystem';
		ELSIF _fs.filesystem_label IS DISTINCT FROM 'AAD59997-3F75-40FA-BD65-2A780CADEE68' THEN
			RAISE EXCEPTION ' ... label propogated oddly: % v %',
				_fs.filesystem_label, 'AAD59997-3F75-40FA-BD65-2A780CADEE68';
		END IF;
		RAISE NOTICE '.....  updating label worked';

		---
		UPDATE logical_volume_property SET logical_volume_property_value =
			'D15E0D6B-4E24-4A8D-A39D-44906E28BD25'
			WHERE logical_volume_property_id = _lvp.logical_volume_property_id
			RETURNING * INTO _lvp;

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION '... could not find filesystem';
		ELSIF _fs.filesystem_label IS DISTINCT FROM 'D15E0D6B-4E24-4A8D-A39D-44906E28BD25' THEN
			RAISE EXCEPTION ' ... label propogated oddly: % v %',
				_fs.filesystem_label, 'AAD59997-3F75-40FA-BD65-2A780CADEE68';
		END IF;
		RAISE NOTICE '.....  inserting label worked';

		---
		DELETE FROM logical_volume_property
			WHERE logical_volume_property_id = _lvp.logical_volume_property_id;

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION '... could not find filesystem';
		ELSIF _fs.filesystem_label IS NOT NULL THEN
			RAISE EXCEPTION ' ... label propogated oddly: % v %',
				_fs.filesystem_label, 'NULL';
		END IF;
		RAISE NOTICE '.....  deleting label worked';

		---
		DELETE FROM logical_volume_property
			WHERE logical_volume_id = _lv.logical_volume_id
			AND logical_volume_property_name in ('MountPoint','Serial','Label');

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF FOUND THEN
			RAISE EXCEPTION 'Filesystem was not properly deleted';
		END IF;
		RAISE NOTICE '.....  deleting everything worked';

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... ok';
	END;

	BEGIN
		RAISE NOTICE '++ trying to add a logical_volume_property for serial...';
		INSERT INTO logical_volume_property (
			logical_volume_id, logical_volume_type, filesystem_type,
			logical_volume_property_name, logical_volume_property_value
		) VALUES (
			_lv.logical_volume_id, _lv.logical_volume_type, 'all',
			'Serial', 'C00X59'
		);

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION '... could not find filesystem';
		ELSIF _fs.filesystem_serial IS DISTINCT FROM 'C00X59' THEN
			RAISE EXCEPTION ' ... serial propogated oddly: % v %',
				_fs.filesystem_serial, 'C00X59';
		END IF;
		RAISE NOTICE '.....  inserting serial worked';

		---
		INSERT INTO logical_volume_property (
			logical_volume_id, logical_volume_type, filesystem_type,
			logical_volume_property_name, logical_volume_property_value
		) VALUES (
			_lv.logical_volume_id, _lv.logical_volume_type, 'all',
			'MountPoint', '/hate'
		);

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION '... could not find filesystem mountpoint';
		ELSIF _fs.mountpoint IS DISTINCT FROM '/hate' THEN
			RAISE EXCEPTION ' ... label propogated oddly: % v %',
				_fs.mountpoint, '/hate';
		END IF;
		RAISE NOTICE '.....  inserting mountpoint worked';

		---
		INSERT INTO logical_volume_property (
			logical_volume_id, logical_volume_type, filesystem_type,
			logical_volume_property_name, logical_volume_property_value
		) VALUES (
			_lv.logical_volume_id, _lv.logical_volume_type, 'all',
			'Label', 'AAD59997-3F75-40FA-BD65-2A780CADEE68'
		) RETURNING * INTO _lvp;

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION '... could not find filesystem';
		ELSIF _fs.filesystem_label IS DISTINCT FROM 'AAD59997-3F75-40FA-BD65-2A780CADEE68' THEN
			RAISE EXCEPTION ' ... label propogated oddly: % v %',
				_fs.filesystem_label, 'AAD59997-3F75-40FA-BD65-2A780CADEE68';
		END IF;
		RAISE NOTICE '.....  updating label worked';

		---
		UPDATE logical_volume_property SET logical_volume_property_value =
			'D15E0D6B-4E24-4A8D-A39D-44906E28BD25'
			WHERE logical_volume_property_id = _lvp.logical_volume_property_id
			RETURNING * INTO _lvp;

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION '... could not find filesystem';
		ELSIF _fs.filesystem_label IS DISTINCT FROM 'D15E0D6B-4E24-4A8D-A39D-44906E28BD25' THEN
			RAISE EXCEPTION ' ... label propogated oddly: % v %',
				_fs.filesystem_label, 'AAD59997-3F75-40FA-BD65-2A780CADEE68';
		END IF;
		RAISE NOTICE '.....  inserting label worked';

		---
		DELETE FROM logical_volume_property
			WHERE logical_volume_property_id = _lvp.logical_volume_property_id;

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION '... could not find filesystem';
		ELSIF _fs.filesystem_label IS NOT NULL THEN
			RAISE EXCEPTION ' ... label propogated oddly: % v %',
				_fs.filesystem_label, 'NULL';
		END IF;
		RAISE NOTICE '.....  deleting label worked';

		---
		DELETE FROM logical_volume_property
			WHERE logical_volume_id = _lv.logical_volume_id
			AND logical_volume_property_name in ('MountPoint','Serial','Label');

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF FOUND THEN
			RAISE EXCEPTION 'Filesystem was not properly deleted';
		END IF;
		RAISE NOTICE '.....  deleting everything worked';

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... ok';
	END;

	BEGIN
		RAISE NOTICE '++ trying to add a logical_volume_property for label...';
		INSERT INTO logical_volume_property (
			logical_volume_id, logical_volume_type, filesystem_type,
			logical_volume_property_name, logical_volume_property_value
		) VALUES (
			_lv.logical_volume_id, _lv.logical_volume_type, 'all',
			'Label', '2810584B-5134-4D42-B59D-038A900DF459'
		) RETURNING * INTO _lvp;

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION '... could not find filesystem';
		ELSIF _fs.filesystem_label IS DISTINCT FROM '2810584B-5134-4D42-B59D-038A900DF459' THEN
			RAISE EXCEPTION ' ... label propogated oddly: % v %',
				_fs.filesystem_label, '2810584B-5134-4D42-B59D-038A900DF459';
		END IF;
		RAISE NOTICE '.....  updating label worked';

		---
		INSERT INTO logical_volume_property (
			logical_volume_id, logical_volume_type, filesystem_type,
			logical_volume_property_name, logical_volume_property_value
		) VALUES (
			_lv.logical_volume_id, _lv.logical_volume_type, 'all',
			'Serial', 'C00X59'
		);

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION '... could not find filesystem';
		ELSIF _fs.filesystem_serial IS DISTINCT FROM 'C00X59' THEN
			RAISE EXCEPTION ' ... serial propogated oddly: % v %',
				_fs.filesystem_serial, 'C00X59';
		END IF;
		RAISE NOTICE '.....  inserting serial worked';

		---
		INSERT INTO logical_volume_property (
			logical_volume_id, logical_volume_type, filesystem_type,
			logical_volume_property_name, logical_volume_property_value
		) VALUES (
			_lv.logical_volume_id, _lv.logical_volume_type, 'all',
			'MountPoint', '/hate'
		);

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION '... could not find filesystem mountpoint';
		ELSIF _fs.mountpoint IS DISTINCT FROM '/hate' THEN
			RAISE EXCEPTION ' ... label propogated oddly: % v %',
				_fs.mountpoint, '/hate';
		END IF;
		RAISE NOTICE '.....  inserting mountpoint worked';

		---
		UPDATE logical_volume_property SET logical_volume_property_value =
			'D15E0D6B-4E24-4A8D-A39D-44906E28BD25'
			WHERE logical_volume_property_id = _lvp.logical_volume_property_id
			RETURNING * INTO _lvp;

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION '... could not find filesystem';
		ELSIF _fs.filesystem_label IS DISTINCT FROM 'D15E0D6B-4E24-4A8D-A39D-44906E28BD25' THEN
			RAISE EXCEPTION ' ... label propogated oddly: % v %',
				_fs.filesystem_label, 'AAD59997-3F75-40FA-BD65-2A780CADEE68';
		END IF;
		RAISE NOTICE '.....  inserting label worked';

		---
		DELETE FROM logical_volume_property
			WHERE logical_volume_property_id = _lvp.logical_volume_property_id;

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION '... could not find filesystem';
		ELSIF _fs.filesystem_label IS NOT NULL THEN
			RAISE EXCEPTION ' ... label propogated oddly: % v %',
				_fs.filesystem_label, 'NULL';
		END IF;
		RAISE NOTICE '.....  deleting label worked';

		---
		DELETE FROM logical_volume_property
			WHERE logical_volume_id = _lv.logical_volume_id
			AND logical_volume_property_name in ('MountPoint','Serial','Label');

		SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

		IF FOUND THEN
			RAISE EXCEPTION 'Filesystem was not properly deleted';
		END IF;
		RAISE NOTICE '.....  deleting everything worked';

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... ok';
	END;

	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT filesystem_compat_tests();
DROP FUNCTION filesystem_compat_tests();

ROLLBACK TO pretest;
\t off
