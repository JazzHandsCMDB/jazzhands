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

\ir ../../../pkg/pgsql/device_utils.sql

\t on
SAVEPOINT devices_tests;

SET search_path=jazzhands_legacy;

-- 
-- Trigger tests
--
CREATE OR REPLACE FUNCTION devices_regression() RETURNS BOOLEAN AS $$
DECLARE
	_dt		device_type%rowtype;
	_se		service_environment%rowtype;
	_d1		device%rowtype;
BEGIN
	RAISE NOTICE 'devices_regression...';

	INSERT INTO service_environment (
		service_environment_name, production_state
	) VALUES (
		'JHTEST', 'development'
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

	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT devices_regression();
DROP FUNCTION devices_regression();

ROLLBACK TO devices_tests;

\t off
