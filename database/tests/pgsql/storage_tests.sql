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
\ir ../../ddl/schema/pgsql/create_block_storage_device_triggers.sql

\t on

savepoint pretest;
DROP FUNCTION IF EXISTS storage_regression_test();
CREATE FUNCTION storage_regression_test() RETURNS BOOLEAN AS $$
DECLARE
	_dt		device_type;
	_d		device;
	_ctid	component_type.component_type_id%TYPE;
	_r		RECORD;
	_bsd	block_storage_device%ROWTYPE;
	_bsda	block_storage_device%ROWTYPE;
	_bsdb	block_storage_device%ROWTYPE;
	_vg		volume_group%ROWTYPE;
	_lv		logical_volume%ROWTYPE;
	_c		component%ROWTYPE;
	_ebsd	encrypted_block_storage_device%ROWTYPE;
BEGIN
	INSERT INTO device_type ( model) VALUES ( 'JHTEST') RETURNING * INTO _dt;

	INSERT INTO val_logical_volume_type (logical_volume_type) VALUES ('jhtest');

	INSERT INTO component_type (model) VALUES ('disk') RETURNING component_type_id INTO _ctid;
	INSERT INTO val_block_storage_device_type (block_storage_device_type, permit_component_id)
		VALUES ('jhtestfs', 'REQUIRED');


	INSERT INTO val_encryption_method (encryption_method, cipher, key_size, cipher_chain_mode, cipher_padding, passphrase_cryptographic_hash_algorithm ) VALUES ('JHTEST', 'none', 0, 'none', 'none', 'none');
	INSERT INTO val_encryption_key_purpose (encryption_key_purpose, encryption_key_purpose_version) VALUES ('JHTEST', 1);

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

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
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
		RAISE NOTICE '... failed correctly: (%: %)', SQLSTATE, SQLERRM;
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
		RAISE NOTICE '... failed correctly: (%: %)', SQLSTATE, SQLERRM;
	END;

	------------------------------------------------------------------------
	BEGIN
		RAISE NOTICE 'Checking if required logical_volume_id fails right...';

		WITH ct AS (
			INSERT INTO component_type ( model ) VALUES ( 'JHTEST ')
				RETURNING *
		) INSERT INTO component ( component_type_id )
			SELECT component_type_id FROM ct
			RETURNING * INTO _c;

		INSERT INTO val_block_storage_device_type (
			block_storage_device_type, permit_logical_volume_id,
			permit_component_id, permit_encrypted_block_storage_device_id
		) VALUES (
			'JHTEST', 'REQUIRED',
			'REQUIRED', 'PROHIBITED'
		);

		INSERT INTO block_storage_device (
			block_storage_device_name, block_storage_device_type,
			component_id, device_id
		) VALUES ( 'jhtest', 'JHTEST', _c.component_id, _d.device_id );
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '... correctly';
	END;

	BEGIN
		RAISE NOTICE 'Checking if required permit_encrypted_block_storage_device_id fails right...';

		WITH ct AS (
			INSERT INTO component_type ( model ) VALUES ( 'JHTEST ')
				RETURNING *
		) INSERT INTO component ( component_type_id )
			SELECT component_type_id FROM ct
			RETURNING * INTO _c;

		INSERT INTO val_block_storage_device_type (
			block_storage_device_type, permit_logical_volume_id,
			permit_component_id, permit_encrypted_block_storage_device_id
		) VALUES (
			'JHTEST', 'PROHIBITED',
			'REQUIRED', 'REQUIRED'
		);

		INSERT INTO block_storage_device (
			block_storage_device_name, block_storage_device_type,
			component_id, device_id
		) VALUES ( 'jhtest', 'JHTEST', _c.component_id, _d.device_id );
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '... failed correctly: (%: %)', SQLSTATE, SQLERRM;
	END;

	BEGIN
		RAISE NOTICE 'Checking if prohibited component_id fails right...';

		WITH ct AS (
			INSERT INTO component_type ( model ) VALUES ( 'JHTEST ')
				RETURNING *
		) INSERT INTO component ( component_type_id )
			SELECT component_type_id FROM ct
			RETURNING * INTO _c;

		INSERT INTO val_block_storage_device_type (
			block_storage_device_type, permit_logical_volume_id,
			permit_component_id, permit_encrypted_block_storage_device_id
		) VALUES (
			'JHTEST', 'PROHIBITED',
			'PROHIBITED', 'PROHIBITED'
		);

		INSERT INTO block_storage_device (
			block_storage_device_name, block_storage_device_type,
			component_id, device_id
		) VALUES ( 'jhtest', 'JHTEST', _c.component_id, _d.device_id );
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '... failed correctly: (%: %)', SQLSTATE, SQLERRM;
	END;

	BEGIN
		RAISE NOTICE 'Checking if prohibited component_id succeeeds right...';

		WITH ct AS (
			INSERT INTO component_type ( model ) VALUES ( 'JHTEST ')
				RETURNING *
		) INSERT INTO component ( component_type_id )
			SELECT component_type_id FROM ct
			RETURNING * INTO _c;

		INSERT INTO val_block_storage_device_type (
			block_storage_device_type, permit_logical_volume_id,
			permit_component_id, permit_encrypted_block_storage_device_id
		) VALUES (
			'JHTEST', 'PROHIBITED',
			'REQUIRED', 'PROHIBITED'
		);

		INSERT INTO block_storage_device (
			block_storage_device_name, block_storage_device_type,
			component_id, device_id
		) VALUES ( 'jhtest', 'JHTEST', _c.component_id, _d.device_id );

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... ok';
	END;

	BEGIN
		RAISE NOTICE 'Checking if required component_id succeeds right...';

		WITH ct AS (
			INSERT INTO component_type ( model ) VALUES ( 'JHTEST ')
				RETURNING *
		) INSERT INTO component ( component_type_id )
			SELECT component_type_id FROM ct
			RETURNING * INTO _c;

		INSERT INTO val_block_storage_device_type (
			block_storage_device_type, permit_logical_volume_id,
			permit_component_id, permit_encrypted_block_storage_device_id
		) VALUES (
			'JHTEST', 'PROHIBITED',
			'REQUIRED', 'PROHIBITED'
		);

		INSERT INTO block_storage_device (
			block_storage_device_name, block_storage_device_type,
			component_id, device_id
		) VALUES ( 'jhtest', 'JHTEST', _c.component_id, _d.device_id );
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... ok';
	END;

	BEGIN
		RAISE NOTICE 'Checking if prohibited encrypted_block_storage_device_id fails right...';

		WITH ct AS (
			INSERT INTO component_type ( model ) VALUES ( 'JHTEST ')
				RETURNING *
		) INSERT INTO component ( component_type_id )
			SELECT component_type_id FROM ct
			RETURNING * INTO _c;

		INSERT INTO val_block_storage_device_type (
			block_storage_device_type, permit_logical_volume_id,
			permit_component_id, permit_encrypted_block_storage_device_id
		) VALUES (
			'JHTEST', 'PROHIBITED',
			'REQUIRED', 'PROHIBITED'
		);

		INSERT INTO block_storage_device (
			block_storage_device_name, block_storage_device_type,
			component_id, device_id
		) VALUES ( 'jhtest', 'JHTEST',
			_c.component_id, _d.device_id
		) RETURNING * INTO _bsd;

		WITH enc AS (
			INSERT INTO encryption_key (
				encryption_key_db_value, encryption_key_purpose,
				encryption_key_purpose_version, encryption_method
			) VALUES (
				'', 'JHTEST',
				1, 'JHTEST'
			) RETURNING *
		) INSERT INTO encrypted_block_storage_device (
			block_storage_device_encryption_system, block_storage_device_id,
			encryption_key_id
		) SELECT 'LUKS', _bsd.block_storage_device_id, encryption_key_id
			FROM enc
			RETURNING * INTO _ebsd;

		INSERT INTO val_block_storage_device_type (
			block_storage_device_type, permit_logical_volume_id, is_encrypted,
			permit_component_id, permit_encrypted_block_storage_device_id
		) VALUES (
			'EJHTEST', 'PROHIBITED', true,
			'PROHIBITED', 'PROHIBITED'
		);

		BEGIN
			INSERT INTO block_storage_device (
				block_storage_device_name, block_storage_device_type,
				encrypted_block_storage_device_id, device_id
			) VALUES ( 'jhtest', 'EJHTEST',
				_ebsd.encrypted_block_storage_device_id, _d.device_id );
		EXCEPTION WHEN invalid_parameter_value THEN
			RAISE EXCEPTION 'worked: (%: %)', SQLSTATE, SQLERRM 
				USING ERRCODE = 'JH999';
		END;

		RAISE EXCEPTION '... It succeeded, ugh';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... failed correctly: (%: %)', SQLSTATE, SQLERRM;
	END;

	BEGIN
		RAISE NOTICE 'Checking if is_encrytped = true  fails right...';

		WITH ct AS (
			INSERT INTO component_type ( model ) VALUES ( 'JHTEST ')
				RETURNING *
		) INSERT INTO component ( component_type_id )
			SELECT component_type_id FROM ct
			RETURNING * INTO _c;

		INSERT INTO val_block_storage_device_type (
			block_storage_device_type, permit_logical_volume_id,
			permit_component_id, permit_encrypted_block_storage_device_id
		) VALUES (
			'JHTEST', 'PROHIBITED',
			'REQUIRED', 'PROHIBITED'
		);

		INSERT INTO block_storage_device (
			block_storage_device_name, block_storage_device_type,
			component_id, device_id
		) VALUES ( 'jhtest', 'JHTEST',
			_c.component_id, _d.device_id
		) RETURNING * INTO _bsd;

		WITH enc AS (
			INSERT INTO encryption_key (
				encryption_key_db_value, encryption_key_purpose,
				encryption_key_purpose_version, encryption_method
			) VALUES (
				'', 'JHTEST',
				1, 'JHTEST'
			) RETURNING *
		) INSERT INTO encrypted_block_storage_device (
			block_storage_device_encryption_system, block_storage_device_id,
			encryption_key_id
		) SELECT 'LUKS', _bsd.block_storage_device_id, encryption_key_id
			FROM enc
			RETURNING * INTO _ebsd;

		INSERT INTO val_block_storage_device_type (
			block_storage_device_type, permit_logical_volume_id, is_encrypted,
			permit_component_id, permit_encrypted_block_storage_device_id
		) VALUES (
			'EJHTEST', 'PROHIBITED', true,
			'PROHIBITED', 'REQUIRED'
		);
		BEGIN
			INSERT INTO block_storage_device (
				block_storage_device_name, block_storage_device_type,
				is_encrypted, encrypted_block_storage_device_id, device_id
			) VALUES ( 'jhtest', 'EJHTEST',
				false, _ebsd.encrypted_block_storage_device_id, _d.device_id );
		EXCEPTION WHEN invalid_parameter_value THEN
			RAISE EXCEPTION 'worked: (%: %)', SQLSTATE, SQLERRM 
				USING ERRCODE = 'JH999';
		END;

		RAISE EXCEPTION 'it worked, ugh';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... failed correctly: (%: %)', SQLSTATE, SQLERRM;
	END;


	BEGIN
		RAISE NOTICE 'Checking if permitted encrypted_block_storage_device_id fails right...';

		WITH ct AS (
			INSERT INTO component_type ( model ) VALUES ( 'JHTEST ')
				RETURNING *
		) INSERT INTO component ( component_type_id )
			SELECT component_type_id FROM ct
			RETURNING * INTO _c;

		INSERT INTO val_block_storage_device_type (
			block_storage_device_type, permit_logical_volume_id,
			permit_component_id, permit_encrypted_block_storage_device_id
		) VALUES (
			'JHTEST', 'PROHIBITED',
			'REQUIRED', 'PROHIBITED'
		);

		INSERT INTO block_storage_device (
			block_storage_device_name, block_storage_device_type,
			component_id, device_id
		) VALUES ( 'jhtest', 'JHTEST',
			_c.component_id, _d.device_id
		) RETURNING * INTO _bsd;

		WITH enc AS (
			INSERT INTO encryption_key (
				encryption_key_db_value, encryption_key_purpose,
				encryption_key_purpose_version, encryption_method
			) VALUES (
				'', 'JHTEST',
				1, 'JHTEST'
			) RETURNING *
		) INSERT INTO encrypted_block_storage_device (
			block_storage_device_encryption_system, block_storage_device_id,
			encryption_key_id
		) SELECT 'LUKS', _bsd.block_storage_device_id, encryption_key_id
			FROM enc
			RETURNING * INTO _ebsd;

		INSERT INTO val_block_storage_device_type (
			block_storage_device_type, permit_logical_volume_id, is_encrypted,
			permit_component_id, permit_encrypted_block_storage_device_id
		) VALUES (
			'EJHTEST', 'PROHIBITED', true,
			'PROHIBITED', 'REQUIRED'
		);
		INSERT INTO block_storage_device (
			block_storage_device_name, block_storage_device_type,
			is_encrypted, encrypted_block_storage_device_id, device_id
		) VALUES ( 'jhtest', 'EJHTEST',
			true, _ebsd.encrypted_block_storage_device_id, _d.device_id );

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... ok';
	END;

	BEGIN
		RAISE NOTICE 'Checking if prohibited logical_volume_id works...';

		INSERT INTO val_volume_group_type ( volume_group_type )
			VALUES ('JHTEST');
		INSERT INTO val_logical_volume_type ( logical_volume_type )
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
			'JHTEST', 'JHTEST', _d.device_id,
			_vg.volume_group_id, 42, 'all'
		) RETURNING * INTO _lv;

		INSERT INTO val_block_storage_device_type (
			block_storage_device_type, permit_logical_volume_id,
			permit_component_id, permit_encrypted_block_storage_device_id
		) VALUES (
			'JHTEST', 'PROHIBITED',
			'PROHIBITED', 'REQUIRED'
		);

		BEGIN
			INSERT INTO block_storage_device (
				block_storage_device_name, block_storage_device_type,
				logical_volume_id, device_id
			) VALUES ( 'jhtest', 'JHTEST',
				_lv.logical_volume_id, _d.device_id
			);
		EXCEPTION WHEN invalid_parameter_value THEN
			RAISE EXCEPTION 'worked: (%: %)', SQLSTATE, SQLERRM 
				USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION '... It succeeded, ugh';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... failed correctly: (%: %)', SQLSTATE, SQLERRM;
	END;

	BEGIN
		RAISE NOTICE 'Checking allow_mulitiple_block_storage_devices on new...';

		INSERT INTO val_volume_group_relation (
			volume_group_relation ) VALUES ('jhthing');

		INSERT INTO val_volume_group_type ( volume_group_type, allow_mulitiple_block_storage_devices )
			VALUES ('JHTEST', true);

		INSERT INTO val_block_storage_device_type (
			block_storage_device_type, permit_component_id
		) VALUES (
			'JHTESTBSD', 'REQIURED'
		);

		WITH c AS (
			INSERT INTO component ( component_type_id ) 
			VALUES (_ctid) RETURNING *
		) INSERT INTO block_storage_device (
			block_storage_device_name, block_storage_device_type,
			component_id, device_id
		) SELECT 'jhtest0', 'JHTESTBSD', component_Id, _d.device_id
			FROM c
		RETURNING * INTO _bsda;

		WITH c AS (
			INSERT INTO component ( component_type_id ) 
			VALUES (_ctid) RETURNING *
		) INSERT INTO block_storage_device (
			block_storage_device_name, block_storage_device_type,
			component_id, device_id
		) SELECT 'jhtest1', 'JHTESTBSD', component_Id, _d.device_id
			FROM c
		RETURNING * INTO _bsdb;

		INSERT INTO volume_group (
			volume_group_name, volume_group_type, device_id,
			volume_group_size_in_bytes
		) VALUES ( 'JHTEST', 'JHTEST', _d.device_id, 42 )
			RETURNING * INTO _vg;

		INSERT INTO volume_group_block_storage_device (
			volume_group_id, blocK_storage_device_id, volume_group_relation
		) VALUES (
			_vg.volume_group_id, _bsda.block_storage_device_id, 'jhthing'
		);
		

		INSERT INTO volume_group_block_storage_device (
			volume_group_id, blocK_storage_device_id, volume_group_relation
		) VALUES (
			_vg.volume_group_id, _bsdb.block_storage_device_id, 'jhthing'
		);
		
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
		RAISE EXCEPTION '... It succeeded, ugh';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... failed correctly: (%: %)', SQLSTATE, SQLERRM;
	END;

	BEGIN
		RAISE NOTICE 'Checking NOT allow_mulitiple_block_storage_devices on new...';

		INSERT INTO val_volume_group_relation (
			volume_group_relation ) VALUES ('jhthing');

		INSERT INTO val_volume_group_type ( volume_group_type, allow_mulitiple_block_storage_devices )
			VALUES ('JHTEST', false);

		INSERT INTO val_block_storage_device_type (
			block_storage_device_type, permit_component_id
		) VALUES (
			'JHTESTBSD', 'REQIURED'
		);

		WITH c AS (
			INSERT INTO component ( component_type_id ) 
			VALUES (_ctid) RETURNING *
		) INSERT INTO block_storage_device (
			block_storage_device_name, block_storage_device_type,
			component_id, device_id
		) SELECT 'jhtest0', 'JHTESTBSD', component_Id, _d.device_id
			FROM c
		RETURNING * INTO _bsda;

		WITH c AS (
			INSERT INTO component ( component_type_id ) 
			VALUES (_ctid) RETURNING *
		) INSERT INTO block_storage_device (
			block_storage_device_name, block_storage_device_type,
			component_id, device_id
		) SELECT 'jhtest1', 'JHTESTBSD', component_Id, _d.device_id
			FROM c
		RETURNING * INTO _bsdb;

		INSERT INTO volume_group (
			volume_group_name, volume_group_type, device_id,
			volume_group_size_in_bytes
		) VALUES ( 'JHTEST', 'JHTEST', _d.device_id, 42 )
			RETURNING * INTO _vg;

		INSERT INTO volume_group_block_storage_device (
			volume_group_id, blocK_storage_device_id, volume_group_relation
		) VALUES (
			_vg.volume_group_id, _bsda.block_storage_device_id, 'jhthing'
		);
		
		BEGIN
			INSERT INTO volume_group_block_storage_device (
				volume_group_id, blocK_storage_device_id, volume_group_relation
			) VALUES (
				_vg.volume_group_id, _bsdb.block_storage_device_id, 'jhthing'
			);
		EXCEPTION WHEN unique_violation THEN
			RAISE EXCEPTION 'worked: (%: %)', SQLSTATE, SQLERRM 
				USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION '... It succeeded, ugh';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... failed correctly: (%: %)', SQLSTATE, SQLERRM;
	END;

	BEGIN
		RAISE NOTICE 'Checking if allow_mulitiple_block_storage_devices change fails properly...';

		INSERT INTO val_volume_group_relation (
			volume_group_relation ) VALUES ('jhthing');

		INSERT INTO val_volume_group_type ( volume_group_type, allow_mulitiple_block_storage_devices )
			VALUES ('JHTEST', true);

		INSERT INTO val_block_storage_device_type (
			block_storage_device_type, permit_component_id
		) VALUES (
			'JHTESTBSD', 'REQIURED'
		);

		WITH c AS (
			INSERT INTO component ( component_type_id ) 
			VALUES (_ctid) RETURNING *
		) INSERT INTO block_storage_device (
			block_storage_device_name, block_storage_device_type,
			component_id, device_id
		) SELECT 'jhtest0', 'JHTESTBSD', component_Id, _d.device_id
			FROM c
		RETURNING * INTO _bsda;

		WITH c AS (
			INSERT INTO component ( component_type_id ) 
			VALUES (_ctid) RETURNING *
		) INSERT INTO block_storage_device (
			block_storage_device_name, block_storage_device_type,
			component_id, device_id
		) SELECT 'jhtest1', 'JHTESTBSD', component_Id, _d.device_id
			FROM c
		RETURNING * INTO _bsdb;

		INSERT INTO volume_group (
			volume_group_name, volume_group_type, device_id,
			volume_group_size_in_bytes
		) VALUES ( 'JHTEST', 'JHTEST', _d.device_id, 42 )
			RETURNING * INTO _vg;

		INSERT INTO volume_group_block_storage_device (
			volume_group_id, blocK_storage_device_id, volume_group_relation
		) VALUES (
			_vg.volume_group_id, _bsda.block_storage_device_id, 'jhthing'
		);
		
		INSERT INTO volume_group_block_storage_device (
			volume_group_id, blocK_storage_device_id, volume_group_relation
		) VALUES (
			_vg.volume_group_id, _bsdb.block_storage_device_id, 'jhthing'
		);

		BEGIN
			UPDATE val_volume_group_type
				SET allow_mulitiple_block_storage_devices = false
				WHERE volume_group_type = 'JHTEST';
		EXCEPTION WHEN unique_violation THEN
			RAISE EXCEPTION 'worked: (%: %)', SQLSTATE, SQLERRM 
				USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION '... It succeeded, ugh';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... failed correctly: (%: %)', SQLSTATE, SQLERRM;
	END;

	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT storage_regression_test();
DROP FUNCTION storage_regression_test();

ROLLBACK TO pretest;
\t off
