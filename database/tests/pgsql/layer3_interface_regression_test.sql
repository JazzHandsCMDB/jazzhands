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

CREATE OR REPLACE FUNCTION validate_layer3_interface_triggers() 
RETURNS BOOLEAN AS $$
DECLARE
	_tally		integer;
	_dev1		device%ROWTYPE;
	_ni			layer3_interface%ROWTYPE;
	_nin		layer3_interface_netblock%ROWTYPE;
	_blk		netblock%ROWTYPE;
	_nb			netblock%ROWTYPE;
	_other		netblock%ROWTYPE;
BEGIN
	RAISE NOTICE 'Cleanup Records from Previous Tests';
	DELETE FROM layer3_interface where layer3_interface_name like 'JHTEST%';
	DELETE FROM layer3_interface where description like 'JHTEST%';
	DELETE FROM device where device_name like 'JHTEST%';
	DELETE from netblock where description like 'JHTEST%';
	DELETE from site where site_code like 'JHTEST%';

	RAISE NOTICE 'Inserting Test Data...';
	INSERT INTO site (site_code,site_status) values ('JHTEST01','ACTIVE');


	INSERT INTO device (
		device_type_id, device_name, device_status, site_code,
		service_environment_id, operating_system_id
	) values (
		1, 'JHTEST one', 'up', 'JHTEST01',
		(select service_environment_id from service_environment
		where service_environment_name = 'production'),
		0
	) RETURNING * into _dev1;


	INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description
	) VALUES (
		'172.31.29.42/24', 'adhoc',
			true, false, 'Allocated',
			'JHTEST _blk'
	) RETURNING * INTO _other;

	INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description
	) VALUES (
		'172.31.30.0/24', 'default',
			false, false, 'Allocated',
			'JHTEST _blk'
	) RETURNING * INTO _blk;

	INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description
	) VALUES (
		'172.31.30.1/24', 'default',
			true, false, 'Allocated',
			'JHTEST _nb'
	) RETURNING * INTO _nb;

	RAISE NOTICE 'Testing to see if is_single_address = Y works...';
	WITH ni AS (
		INSERT INTO layer3_interface (
			device_id, layer3_interface_name, layer3_interface_type,
			description, should_monitor
		) VALUES (
			_dev1.device_id, 'JHTEST0', 'broadcast', 
			'JHTEST0', true
		) RETURNING *
	),z AS ( INSERT INTO layer3_interface_netblock
			(layer3_interface_id, netblock_id)
		SELECT layer3_interface_id, _nb.netblock_id
		FROM ni
	) SELECT * INTO _ni FROM ni;
	RAISE NOTICE '... it did!';

	RAISE NOTICE 'Testing to see if switching a block to N fails... ';
	BEGIN
		UPDATE netblock set ip_address = '172.31.30.0', 
				is_single_address = false
			WHERE netblock_id = _nb.netblock_id;
		RAISE EXCEPTION '... it did not (!)';
	EXCEPTION WHEN foreign_key_violation THEN
		RAISE NOTICE '... It did, as expected';
	END;

	RAISE NOTICE 'Testing to see if switching a block to not default... ';
	BEGIN
		UPDATE netblock set netblock_type = 'adhoc'
			WHERE netblock_id = _nb.netblock_id;
		RAISE EXCEPTION '... it did not (!)';
	EXCEPTION WHEN foreign_key_violation THEN
		RAISE NOTICE '... It did, as expected';
	END;

	RAISE NOTICE 'Testing to see if is_single_address = N fails...';
	BEGIN
		WITH ni AS (
			INSERT INTO layer3_interface (
				device_id, layer3_interface_name, layer3_interface_type,
				description,
				should_monitor
			) VALUES (
				_dev1.device_id, 'JHTEST1', 'broadcast', 
				'JHTEST1',
				true 
			) RETURNING * 
		),z AS ( INSERT INTO layer3_interface_netblock
				(layer3_interface_id, netblock_id)
			SELECT layer3_interface_id, _blk.netblock_id
			FROM ni
		) SELECT * INTO _ni FROM ni;
		RAISE EXCEPTION '... it did not (!)';
	EXCEPTION WHEN foreign_key_violation THEN
		RAISE NOTICE '... It did, as expected';
	END;

	RAISE NOTICE 'Testing to see if layer3_interface_type != default fails...';
	BEGIN
		WITH ni AS (
			INSERT INTO layer3_interface (
				device_id, layer3_interface_name, layer3_interface_type,
				description, should_monitor
			) VALUES (
				_dev1.device_id, 'JHTEST2', 'broadcast', 
				'JHTEST2',
				true
			) RETURNING *
		),z AS ( INSERT INTO layer3_interface_netblock
				(layer3_interface_id, netblock_id)
			SELECT layer3_interface_id, _other.netblock_id
			FROM ni
		) SELECT * INTO _ni FROM ni;
		RAISE EXCEPTION '... it did not (!)';
	EXCEPTION WHEN foreign_key_violation THEN
		RAISE NOTICE '... It did, as expected';
	END;

	RAISE NOTICE 'Cleanup Records';
	DELETE FROM layer3_interface_netblock where layer3_interface_id IN (
		SELECT layer3_interface_id FROM layer3_interface
		WHERE layer3_interface_name like 'JHTEST%'
	);
	DELETE FROM layer3_interface where layer3_interface_name like 'JHTEST%';
	DELETE FROM layer3_interface where description like 'JHTEST%';
	DELETE FROM device where device_name like 'JHTEST%';
	DELETE from netblock where description like 'JHTEST%';
	DELETE from site where site_code like 'JHTEST%';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT jazzhands.validate_layer3_interface_triggers();
DROP FUNCTION validate_layer3_interface_triggers();

\t off
