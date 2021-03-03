-- Copyright (c) 2019 Todd Kover
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
SAVEPOINT jazzhands_legacy_device_test;

-- \ir ../../../ddl/legacy.sql
-- \ir ../../../ddl/cache/pgsql/create_ct_jazzhands_legacy_device.sql

set search_path=jazzhands_legacy;
--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION jazzhands_legacy_device_regressions() RETURNS BOOLEAN AS $$
DECLARE
	_dt			device_type%ROWTYPE;
	_se			service_environment%ROWTYPE;
	_d1			device%ROWTYPE;
	_d2			device%ROWTYPE;
	_dcd		device_collection_device%ROWTYPE;
	_dc			device_collection%ROWTYPE;
	_dc2		device_collection%ROWTYPE;
BEGIN
	RAISE NOTICE 'jazzhands_legacy_device_regressionermgr Cleanup Records from Previous Tests';

	RAISE NOTICE '++ Inserting testing data';

	WITH t AS (
		INSERT INTO val_device_collection_type (
			device_collection_type
		) VALUES (
			'JHTEST-DC'
		) RETURNING *
	) INSERT INTO device_collection
		(device_collection_name, device_collection_type)
		SELECT 'JHTEST--DC', device_collection_type
		FROM t
		RETURNING * INTO _dc;

	INSERT INTO service_environment (
		service_environment_name, production_state
	) VALUES (
		'JHTEST', 'development'
	) RETURNING * INTO _se;

	INSERT INTO device_type ( device_type_name ) VALUES ('JHTESTMODEL')
		RETURNING * INTO _dt;

	------------
	RAISE NOTICE '++ Trying basic device...';
	INSERT INTO device (
		device_name, device_status, device_type_id, service_environment_id
	) VALUES (
		'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id
	) RETURNING * INTO _d1;

	SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
	IF _d2 != _d1 THEN
		RAISE EXCEPTION 'after insert, devices do not match - % %', to_json(_d1), to_json(_d2);
	END IF;

	DELETE FROM device where device_id = _d1.device_id RETURNING * INTO _d2;
	IF _d2 != _d1 THEN
		RAISE EXCEPTION 'afer delete, devices do not match - % %', to_json(_d1), to_json(_d2);
	END IF;

	--------------------
	RAISE NOTICE '++ Starting with is_locally_managed = Y and toggling';
	INSERT INTO device (
		device_name, device_status, device_type_id, service_environment_id,
		is_locally_managed
	) VALUES (
		'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
		'Y'
	) RETURNING * INTO _d1;

	SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
	IF _d2 != _d1 THEN
		RAISE EXCEPTION 'after insert 2, devices do not match - % %', to_json(_d1), to_json(_d2);
	END IF;
	IF _d2.is_locally_managed != 'Y' THEN
		RAISE EXCEPTION 'after insert 2 is_locally_managed is not Y: %',
			to_json(_d2);
	END IF;

	RAISE NOTICE '++ update to N...';
	BEGIN
		UPDATE device SET is_locally_managed = 'N'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_locally_managed/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		IF _d1.is_locally_managed != 'N' THEN
			RAISE EXCEPTION '... is_locally_managed was not changed to N';
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ update to false...';
	BEGIN
		UPDATE device SET is_locally_managed = false
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_locally_managed/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ update to N...';
	BEGIN
		UPDATE device SET is_locally_managed = 'B'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_locally_managed/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ update to NULL...';
	BEGIN
		UPDATE device SET is_locally_managed = NULL
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_locally_managed/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN not_null_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	--------------------
	RAISE NOTICE '++ Starting with is_locally_managed = N and toggling';
	INSERT INTO device (
		device_name, device_status, device_type_id, service_environment_id,
		is_locally_managed
	) VALUES (
		'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
		'N'
	) RETURNING * INTO _d1;

	SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
	IF _d2 != _d1 THEN
		RAISE EXCEPTION 'after insert 2, devices do not match - % %', to_json(_d1), to_json(_d2);
	END IF;
	IF _d2.is_locally_managed != 'N' THEN
		RAISE EXCEPTION 'after insert 2 is_locally_managed is not N: %',
			to_json(_d2);
	END IF;

	BEGIN
		UPDATE device SET is_locally_managed = 'Y'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_locally_managed/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		IF _d1.is_locally_managed != 'Y' THEN
			RAISE EXCEPTION '... is_locally_managed was not changed to N';
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET is_locally_managed = false
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_locally_managed/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET is_locally_managed = 'B'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_locally_managed/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET is_locally_managed = NULL
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_locally_managed/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN not_null_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	--------------------
	RAISE NOTICE '++ Starting with is_monitored = Y and toggling';
	INSERT INTO device (
		device_name, device_status, device_type_id, service_environment_id,
		is_monitored
	) VALUES (
		'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
		'Y'
	) RETURNING * INTO _d1;

	SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
	IF _d2 != _d1 THEN
		RAISE EXCEPTION 'after insert 2, devices do not match - % %', to_json(_d1), to_json(_d2);
	END IF;
	IF _d2.is_monitored != 'Y' THEN
		RAISE EXCEPTION 'after insert 2 is_monitored is not Y: %',
			to_json(_d2);
	END IF;

	BEGIN
		UPDATE device SET is_monitored = 'N'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_monitored/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		IF _d1.is_monitored != 'N' THEN
			RAISE EXCEPTION '... is_monitored was not changed to N';
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET is_monitored = false
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_monitored/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET is_monitored = 'B'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_monitored/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET is_monitored = NULL
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_monitored/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN not_null_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	--------------------
	RAISE NOTICE '++ Starting with is_monitored = N and toggling';
	INSERT INTO device (
		device_name, device_status, device_type_id, service_environment_id,
		is_monitored
	) VALUES (
		'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
		'N'
	) RETURNING * INTO _d1;

	SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
	IF _d2 != _d1 THEN
		RAISE EXCEPTION 'after insert 2, devices do not match - % %', to_json(_d1), to_json(_d2);
	END IF;
	IF _d2.is_monitored != 'N' THEN
		RAISE EXCEPTION 'after insert 2 is_monitored is not N: %',
			to_json(_d2);
	END IF;

	BEGIN
		UPDATE device SET is_monitored = 'Y'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_monitored/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		IF _d1.is_monitored != 'Y' THEN
			RAISE EXCEPTION '... is_locally_managed was not changed to N';
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET is_monitored = false
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_monitored/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET is_monitored = 'B'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_monitored/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET is_monitored = NULL
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_locally_managed/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN not_null_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	--------------------

	--------------------
	RAISE NOTICE '++ Starting with should_fetch_config = Y and toggling';
	INSERT INTO device (
		device_name, device_status, device_type_id, service_environment_id,
		should_fetch_config
	) VALUES (
		'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
		'Y'
	) RETURNING * INTO _d1;

	SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
	IF _d2 != _d1 THEN
		RAISE EXCEPTION 'after insert 2, devices do not match - % %', to_json(_d1), to_json(_d2);
	END IF;
	IF _d2.should_fetch_config != 'Y' THEN
		RAISE EXCEPTION 'after insert 2 should_fetch_config is not Y: %',
			to_json(_d2);
	END IF;

	BEGIN
		UPDATE device SET should_fetch_config = 'N'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... should_fetch_config/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		IF _d1.should_fetch_config != 'N' THEN
			RAISE EXCEPTION '... is_locally_managed was not changed to N';
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET should_fetch_config = false
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... should_fetch_config/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET should_fetch_config = 'B'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... should_fetch_config/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET should_fetch_config = NULL
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... should_fetch_config/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN not_null_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	--------------------
	RAISE NOTICE '++ Starting with should_fetch_config = N and toggling';
	INSERT INTO device (
		device_name, device_status, device_type_id, service_environment_id,
		should_fetch_config
	) VALUES (
		'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
		'N'
	) RETURNING * INTO _d1;

	SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
	IF _d2 != _d1 THEN
		RAISE EXCEPTION 'after insert 2, devices do not match - % %', to_json(_d1), to_json(_d2);
	END IF;
	IF _d2.should_fetch_config != 'N' THEN
		RAISE EXCEPTION 'after insert 2 should_fetch_config is not N: %',
			to_json(_d2);
	END IF;

	BEGIN
		UPDATE device SET should_fetch_config = 'Y'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... should_fetch_config/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		IF _d1.should_fetch_config != 'Y' THEN
			RAISE EXCEPTION '... is_locally_managed was not changed to N';
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET should_fetch_config = false
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... should_fetch_config/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET should_fetch_config = 'B'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... should_fetch_config/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET should_fetch_config = NULL
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... should_fetch_config/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN not_null_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	--------------------
	RAISE NOTICE '++ Starting with is_monitored = Y and toggling';
	INSERT INTO device (
		device_name, device_status, device_type_id, service_environment_id,
		is_monitored
	) VALUES (
		'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
		'Y'
	) RETURNING * INTO _d1;

	SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
	IF _d2 != _d1 THEN
		RAISE EXCEPTION 'after insert 2, devices do not match - % %', to_json(_d1), to_json(_d2);
	END IF;
	IF _d2.is_monitored != 'Y' THEN
		RAISE EXCEPTION 'after insert 2 is_monitored is not Y: %',
			to_json(_d2);
	END IF;

	BEGIN
		UPDATE device SET is_monitored = 'N'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_monitored/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		IF _d1.should_fetch_config != 'N' THEN
			RAISE EXCEPTION '... is_locally_managed was not changed to N';
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET is_monitored = false
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_monitored/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET is_monitored = 'B'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_monitored/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET is_monitored = NULL
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_monitored/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN not_null_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	--------------------
	RAISE NOTICE '++ Starting with is_monitored = N and toggling';
	INSERT INTO device (
		device_name, device_status, device_type_id, service_environment_id,
		is_monitored
	) VALUES (
		'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
		'N'
	) RETURNING * INTO _d1;

	SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
	IF _d2 != _d1 THEN
		RAISE EXCEPTION 'after insert 2, devices do not match - % %', to_json(_d1), to_json(_d2);
	END IF;
	IF _d2.is_monitored != 'N' THEN
		RAISE EXCEPTION 'after insert 2 is_monitored is not N: %',
			to_json(_d2);
	END IF;

	BEGIN
		UPDATE device SET is_monitored = 'Y'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_monitored/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		IF _d1.is_monitored != 'Y' THEN
			RAISE EXCEPTION '... is_locally_managed was not changed to N';
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET is_monitored = false
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_monitored/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET is_monitored = 'B'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_monitored/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN check_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	BEGIN
		UPDATE device SET is_monitored = NULL
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_locally_managed/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;
		RAISE EXCEPTION '%', 'If suceeded!  Bad!';
	EXCEPTION WHEN not_null_violation THEN
		RAISE NOTICE '.... it failed correctly...! (%)', SQLERRM;
	END;

	--------------------
	RAISE NOTICE '++ Trying all the things Y...';
	INSERT INTO device (
		device_name, device_status, device_type_id, service_environment_id,
		auto_mgmt_protocol, is_locally_managed, is_monitored, should_fetch_config
	) VALUES (
		'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
		'ssh', 'Y', 'Y', 'Y'
	) RETURNING * INTO _d1;

	SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
	IF _d2 != _d1 THEN
		RAISE EXCEPTION 'after insert 2, devices do not match - % %', to_json(_d1), to_json(_d2);
	END IF;
	IF _d2.auto_mgmt_protocol != 'ssh' OR
		_d2.is_locally_managed != 'Y' OR
		_d2.is_monitored != 'Y' OR
		_d2.should_fetch_config != 'Y'
	THEN
		RAISE EXCEPTION 'after insert 2, one of the deprecated columsn is not Y/ssh: %',
			to_json(_d2);
	END IF;

	RAISE NOTICE 'changing if switching to N/telnet works... ';
	BEGIN
		UPDATE device SET auto_mgmt_protocol = 'telnet'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... auto_mgmt_protocol/telnet devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;

		UPDATE device SET is_locally_managed = 'N'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_locally_managed/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;

		UPDATE device SET is_monitored = 'N'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION '... is_monitored/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;

		UPDATE device SET should_fetch_config = 'N'
			WHERE device_id = _d1.device_id RETURNING * INTO _d1;
		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2 != _d1 THEN
			RAISE EXCEPTION 'should_fetch_config/N devices do not match - % %', to_json(_d1), to_json(_d2);
		END IF;

		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d2.auto_mgmt_protocol != 'telnet' OR
			_d2.is_locally_managed != 'N' OR
			_d2.is_monitored != 'N' OR
			_d2.should_fetch_config != 'N'
		THEN
			RAISE EXCEPTION 'Full check one of the deprecated columsn is not N/telnet: %',
				to_json(_d2);
		END IF;

		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	DELETE FROM device WHERE device_id = _d1.device_id;

	-- Not checking things for the absense of the property because they ust
	-- won't show up.

	RAISE NOTICE 'Checking if removing AutoMgmtProtocol property breaks insert...';
	BEGIN
		DELETE FROM property
		WHERE property_name = 'AutoMgmtProtocol'
		AND property_type = 'JazzHandsLegacySupport';
		INSERT INTO device (
			device_name, device_status, device_type_id, service_environment_id,
			auto_mgmt_protocol
		) VALUES (
			'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
			'ssh'
		) RETURNING * INTO _d1;
		RAISE EXCEPTION '%', 'It DID NOT! BAD!';
	EXCEPTION WHEN error_in_assignment THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ Checking if removing is_locally_managed property breaks insert...';
	BEGIN
		DELETE FROM property
		WHERE property_name = 'IsLocallyManagedDevice'
		AND property_type = 'JazzHandsLegacySupport';
		INSERT INTO device (
			device_name, device_status, device_type_id, service_environment_id,
			is_locally_managed
		) VALUES (
			'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
			'Y'
		) RETURNING * INTO _d1;
		RAISE EXCEPTION '%', 'It DID NOT! BAD!';
	EXCEPTION WHEN error_in_assignment THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ Checking if removing is_monitored property breaks insert...';
	BEGIN
		DELETE FROM property
		WHERE property_name = 'IsMonitoredDevice'
		AND property_type = 'JazzHandsLegacySupport';
		INSERT INTO device (
			device_name, device_status, device_type_id, service_environment_id,
			is_monitored
		) VALUES (
			'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
			'Y'
		) RETURNING * INTO _d1;
		RAISE EXCEPTION '%', 'It DID NOT! BAD!';
	EXCEPTION WHEN error_in_assignment THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ Checking if removing should_fetch_config property breaks insert...';
	BEGIN
		DELETE FROM property
		WHERE property_name = 'ShouldConfigFetch'
		AND property_type = 'JazzHandsLegacySupport';
		INSERT INTO device (
			device_name, device_status, device_type_id, service_environment_id,
			should_fetch_config
		) VALUES (
			'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
			'Y'
		) RETURNING * INTO _d1;
		RAISE EXCEPTION '%', 'It DID NOT! BAD!';
	EXCEPTION WHEN error_in_assignment THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	DELETE FROM device WHERE device_id = _d1.device_id;

	INSERT INTO device (
		device_name, device_status, device_type_id, service_environment_id,
		auto_mgmt_protocol, is_locally_managed, is_monitored, should_fetch_config
	) VALUES (
		'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
		'ssh', 'Y', 'Y', 'Y'
	) RETURNING * INTO _d1;
	DELETE FROM device WHERE device_id = _d1.device_id;

	RAISE NOTICE '++ Checking to see if updating legacy device collections works...';
	INSERT INTO device (
		device_name, device_status, device_type_id, service_environment_id,
		is_monitored
	) VALUES (
		'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
		'Y'
	) RETURNING * INTO _d1;
	BEGIN
		UPDATE device_collection_device
		SET device_collection_id = (
			SELECT device_collection_id
			FROM device_collection JOIN property
				USING (device_collection_id)
			WHERE property_name = 'ShouldConfigFetch'
			AND property_type = 'JazzHandsLegacySupport'
			LIMIT 1
			)
		WHERE device_id = _d1.device_id
		AND device_collection_id IN (
			SELECT device_collection_id
			FROM device_collection JOIN property
				USING (device_collection_id)
			WHERE property_name = 'IsMonitoredDevice'
			AND property_type = 'JazzHandsLegacySupport'
			LIMIT 1
		) RETURNING * INTO _dcd;

		SELECT * INTO _d1 FROM device WHERE device_id = _dcd.device_id;
		IF _d1.is_monitored != 'N' OR _d1.should_fetch_config != 'Y' THEN
			RAISE EXCEPTION 'It did not work: % and %',
				_d1.is_monitored, _d1.should_fetch_config;
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;
	DELETE FROM device WHERE device_id = _d1.device_id;

	RAISE NOTICE '++ Checking to see if is_locally_managed to ssh works';
	INSERT INTO device (
		device_name, device_status, device_type_id, service_environment_id,
		is_locally_managed
	) VALUES (
		'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
		'Y'
	) RETURNING * INTO _d1;
	BEGIN
		UPDATE device_collection_device
		SET device_collection_id = (
			SELECT device_collection_id
			FROM device_collection JOIN property
				USING (device_collection_id)
			WHERE property_name = 'AutoMgmtProtocol'
			AND property_type = 'JazzHandsLegacySupport'
			AND property_value = 'telnet'
			LIMIT 1
			)
		WHERE device_id = _d1.device_id
		AND device_collection_id IN (
			SELECT device_collection_id
			FROM device_collection JOIN property
				USING (device_collection_id)
			WHERE property_name = 'IsLocallyManagedDevice'
			AND property_type = 'JazzHandsLegacySupport'
			LIMIT 1
		) RETURNING * INTO _dcd;

		SELECT * INTO _d1 FROM device WHERE device_id = _dcd.device_id;
		IF _d1.is_locally_managed != 'N' OR _d1.auto_mgmt_protocol != 'telnet' THEN
			RAISE EXCEPTION 'It did not work: % and %',
				_d1.is_locally_managed, _d1.auto_mgmt_protocol;
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;
	DELETE FROM device WHERE device_id = _d1.device_id;

	RAISE NOTICE '++ Checking to see if ssh to should_fetch_config works';
	BEGIN
		INSERT INTO device (
			device_name, device_status, device_type_id, service_environment_id,
			auto_mgmt_protocol, is_locally_managed
		) VALUES (
			'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
			'ssh', 'N'
		) RETURNING * INTO _d1;
		UPDATE device_collection_device
		SET device_collection_id = (
			SELECT device_collection_id
			FROM device_collection JOIN property
				USING (device_collection_id)
			WHERE property_name = 'IsLocallyManagedDevice'
			AND property_type = 'JazzHandsLegacySupport'
			LIMIT 1
			)
		WHERE device_id = _d1.device_id
		AND device_collection_id IN (
			SELECT device_collection_id
			FROM device_collection JOIN property
				USING (device_collection_id)
			WHERE property_name = 'AutoMgmtProtocol'
			AND property_type = 'JazzHandsLegacySupport'
			AND property_value = 'ssh'
			LIMIT 1
		) RETURNING * INTO _dcd;

		SELECT * INTO _d1 FROM device WHERE device_id = _dcd.device_id;
		IF _d1.should_fetch_config != 'N' OR _d1.auto_mgmt_protocol != 'ssh' THEN
			RAISE EXCEPTION 'It did not work: % and %',
				_d1.should_fetch_config, _d1.auto_mgmt_protocol;
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ Checking to see if should_fetch_config to telnet works';
	BEGIN
		INSERT INTO device (
			device_name, device_status, device_type_id, service_environment_id,
			should_fetch_config, is_locally_managed
		) VALUES (
			'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
			'Y', 'N'
		) RETURNING * INTO _d1;
		UPDATE device_collection_device
		SET device_collection_id = (
			SELECT device_collection_id
			FROM device_collection JOIN property
				USING (device_collection_id)
			WHERE property_name = 'AutoMgmtProtocol'
			AND property_type = 'JazzHandsLegacySupport'
			AND property_value = 'telnet'
			LIMIT 1
			)
		WHERE device_id = _d1.device_id
		AND device_collection_id IN (
			SELECT device_collection_id
			FROM device_collection JOIN property
				USING (device_collection_id)
			WHERE property_name = 'IsLocallyManagedDevice'
			AND property_type = 'JazzHandsLegacySupport'
			LIMIT 1
		) RETURNING * INTO _dcd;

		SELECT * INTO _d1 FROM device WHERE device_id = _dcd.device_id;
		IF _d1.should_fetch_config != 'Y' OR _d1.auto_mgmt_protocol IS NOT NULL THEN
			RAISE EXCEPTION 'It did not work: % and %',
				_d1.should_fetch_config, _d1.auto_mgmt_protocol;
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ Checking to see changing from is_monitored to non-legacy else completely works';
	BEGIN
		INSERT INTO device (
			device_name, device_status, device_type_id, service_environment_id,
			is_monitored
		) VALUES (
			'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
			'N'
		) RETURNING * INTO _d1;
		UPDATE device_collection_device
		SET device_collection_id = _dc.device_collection_id
		WHERE device_id = _d1.device_id
		AND device_collection_id IN (
			SELECT device_collection_id
			FROM device_collection JOIN property
				USING (device_collection_id)
			WHERE property_name = 'IsMonitored'
			AND property_type = 'JazzHandsLegacySupport'
			LIMIT 1
		) RETURNING * INTO _dcd;

		SELECT * INTO _d1 FROM device WHERE device_id = _dcd.device_id;
		IF _d1.is_monitored != 'N' THEN
			RAISE EXCEPTION 'It did not work: %',
				_d1.should_fetch_config;
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ Changing from something else to a legacy type (%)',
		_dc.device_collection_id;
	BEGIN
		INSERT INTO device (
			device_name, device_status, device_type_id, service_environment_id,
			is_monitored
		) VALUES (
			'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
			'N'
		) RETURNING * INTO _d1;

		INSERT INTO device_collection_device (
			device_collection_id, device_id
		) VALUES (
			_dc.device_collection_id, _d1.device_id
		);

		UPDATE device_collection_device
		SET device_collection_id = (
			SELECT device_collection_id
			FROM device_collection JOIN property
				USING (device_collection_id)
			WHERE property_name = 'IsMonitoredDevice'
			AND property_type = 'JazzHandsLegacySupport'
			LIMIT 1
		) WHERE device_id = _d1.device_id
		AND device_collection_id = _dc.device_collection_id
		RETURNING * INTO _dcd;

		SELECT * INTO _d1 FROM device WHERE device_id = _dcd.device_id;
		IF _d1.is_monitored != 'Y' THEN
			RAISE EXCEPTION 'It did not work: %',
				_d1.should_fetch_config;
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;
	DELETE FROM device WHERE device_id = _d1.device_id;


	RAISE NOTICE '++ Making sure unrelated device collection inserts/updates/deletes work';
	BEGIN
		INSERT INTO device (
			device_name, device_status, device_type_id, service_environment_id,
			auto_mgmt_protocol, is_locally_managed, is_monitored, should_fetch_config
		) VALUES (
			'JHTEST01', 'up', _dt.device_type_id, _se.service_environment_id,
			'ssh', 'Y', 'Y', 'Y'
		) RETURNING * INTO _d1;

		INSERT INTO device_collection (
			device_collection_name, device_collection_type
		) VALUES (
			'JHTEST-DC-2', 'JHTEST-DC'
		) RETURNING * INTO _dc2;

		INSERT INTO device_collection_device (
			device_collection_id, device_id
		) VALUES (
			_dc.device_collection_id, _d1.device_id
		);

		UPDATE device_collection_device
		SET device_collection_id = _dc2.device_collection_id
		WHERE device_id = _d1.device_id
		AND device_collection_id = _dc.device_collection_id
		RETURNING * INTO _dcd;

		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d1 != _d2 THEN
			RAISE EXCEPTION '... (1) Devices do not match % %',
				jsonb_pretty(to_json(_d1)::jsonb),
				jsonb_pretty(to_json(_d1)::jsonb);
		END IF;

		DELETE FROM device_collection_device
		WHERE device_id = _d1.device_id
		AND device_collection_id
			IN (_dc.device_collection_id, _dc2.device_collection_id);

		PERFORM *
		FROM device_collection_device
		WHERE device_id = _d1.device_id
		AND device_collection_id
			IN (_dc.device_collection_id, _dc2.device_collection_id);

		IF FOUND THEN
			RAISE EXCEPTION '... devices did not get deleted from device collections';
		END IF;

		SELECT * INTO _d2 FROM device WHERE device_id = _d1.device_id;
		IF _d1 != _d2 THEN
			RAISE EXCEPTION '... (2) Devices do not match % %',
				jsonb_pretty(to_json(_d1)::jsonb),
				jsonb_pretty(to_json(_d1)::jsonb);
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;
	DELETE FROM device WHERE device_id = _d1.device_id;

	--
	-- NOTE:  Using jazzhands schema explicitly to make sure that
	-- both schemas can coeexit.
	--
	RAISE NOTICE '++ Cleaning up...';
	DELETE FROM jazzhands.device WHERE device_name ~ 'JHTEST';
	DELETE FROM jazzhands.device_type WHERE device_type_name ~ 'JHTEST';
	DELETE FROM jazzhands.service_environment WHERE service_environment_name ~ 'JHTEST';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT jazzhands_legacy_device_regressions();
DROP FUNCTION jazzhands_legacy_device_regressions();

ROLLBACK TO jazzhands_legacy_device_test;

\t off
