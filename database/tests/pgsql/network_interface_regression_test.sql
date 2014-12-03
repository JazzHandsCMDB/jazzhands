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

CREATE OR REPLACE FUNCTION validate_network_interface_triggers() 
RETURNS BOOLEAN AS $$
DECLARE
	_tally		integer;
	_dev1		device%ROWTYPE;
	_ni			network_interface%ROWTYPE;
	_blk		netblock%ROWTYPE;
	_nb			netblock%ROWTYPE;
	_other		netblock%ROWTYPE;
BEGIN
	RAISE NOTICE 'Cleanup Records from Previous Tests';
	DELETE FROM network_interface where network_interface_name like 'JHTEST%';
	DELETE FROM network_interface where description like 'JHTEST%';
	DELETE FROM device where device_name like 'JHTEST%';
	DELETE from netblock where description like 'JHTEST%';
	DELETE from site where site_code like 'JHTEST%';

	RAISE NOTICE 'Inserting Test Data...';
	INSERT INTO site (site_code,site_status) values ('JHTEST01','ACTIVE');


	INSERT INTO device (
		device_type_id, device_name, device_status, site_code,
		service_environment_id, operating_system_id,
		is_monitored
	) values (
		1, 'JHTEST one', 'up', 'JHTEST01',
		(select service_environment_id from service_environment
		where service_environment_name = 'production'),
		0,
		'Y'
	) RETURNING * into _dev1;


	INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description
	) VALUES (
		'172.31.29.42/24', 'adhoc',
			'Y', 'N', 'Allocated',
			'JHTEST _blk'
	) RETURNING * INTO _other;

	INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description
	) VALUES (
		'172.31.30.0/24', 'default',
			'N', 'N', 'Allocated',
			'JHTEST _blk'
	) RETURNING * INTO _blk;

	INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description
	) VALUES (
		'172.31.30.1/24', 'default',
			'Y', 'N', 'Allocated',
			'JHTEST _nb'
	) RETURNING * INTO _nb;

	RAISE NOTICE 'Testing to see if is_single_address = Y works...';
	INSERT INTO network_interface (
		device_id, network_interface_name, network_interface_type,
		description,
		should_monitor, netblock_id
	) VALUES (
		_dev1.device_id, 'JHTEST0', 'broadcast', 'Y',
		'JHTEST0',
		_nb.netblock_id
	) RETURNING * INTO _ni;
	RAISE NOTICE '... it did!';

	RAISE NOTICE 'Testing to see if switching a block to N fails... ';
	BEGIN
		UPDATE netblock set ip_address = '172.31.30.0', 
				is_single_address = 'N'
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
		INSERT INTO network_interface (
			device_id, network_interface_name, network_interface_type,
			description,
			should_monitor, netblock_id
		) VALUES (
			_dev1.device_id, 'JHTEST1', 'broadcast', 'Y',
			'JHTEST1',
			_blk.netblock_id
		) RETURNING * INTO _ni;
		RAISE EXCEPTION '... it did not (!)';
	EXCEPTION WHEN foreign_key_violation THEN
		RAISE NOTICE '... It did, as expected';
	END;

	RAISE NOTICE 'Testing to see if network_interface_type != default fails...';
	BEGIN
		INSERT INTO network_interface (
			device_id, network_interface_name, network_interface_type,
			description,
			should_monitor, netblock_id
		) VALUES (
			_dev1.device_id, 'JHTEST2', 'broadcast', 'Y',
			'JHTEST2',
			_other.netblock_id
		) RETURNING * INTO _ni;
		RAISE EXCEPTION '... it did not (!)';
	EXCEPTION WHEN foreign_key_violation THEN
		RAISE NOTICE '... It did, as expected';
	END;

	RAISE NOTICE 'Cleanup Records';
	DELETE FROM network_interface where network_interface_name like 'JHTEST%';
	DELETE FROM network_interface where description like 'JHTEST%';
	DELETE FROM device where device_name like 'JHTEST%';
	DELETE from netblock where description like 'JHTEST%';
	DELETE from site where site_code like 'JHTEST%';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT jazzhands.validate_network_interface_triggers();
DROP FUNCTION validate_network_interface_triggers();

------------------------------ transition tests ----------------------------
CREATE OR REPLACE FUNCTION validate_network_interface_triggers_transition() 
RETURNS BOOLEAN AS $$
DECLARE
	_tally		integer;
	_dev1		device%ROWTYPE;
	_ni			network_interface%ROWTYPE;
	_blk		netblock%ROWTYPE;
	_nb1		netblock%ROWTYPE;
	_nb2		netblock%ROWTYPE;
BEGIN
	RAISE NOTICE 'Cleanup Records from Previous Tests';
	DELETE FROM network_interface_netblock where network_interface_id IN (
		select network_interface_id from network_interface
		where network_interface_name like 'JHTEST%'
	);
	DELETE FROM network_interface where network_interface_name like 'JHTEST%';
	DELETE FROM network_interface where description like 'JHTEST%';
	DELETE FROM device where device_name like 'JHTEST%';
	DELETE from netblock where description like 'JHTEST%';
	DELETE from site where site_code like 'JHTEST%';

	RAISE NOTICE 'Inserting Test Data for network_interface_netblock transition';
	INSERT INTO site (site_code,site_status) values ('JHTEST01','ACTIVE');


	INSERT INTO device (
		device_type_id, device_name, device_status, site_code,
		service_environment_id, operating_system_id,
		is_monitored
	) values (
		1, 'JHTEST one', 'up', 'JHTEST01',
		(select service_environment_id from service_environment
		where service_environment_name = 'production'),
		0,
		'Y'
	) RETURNING * into _dev1;


	INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description
	) VALUES (
		'172.31.30.0/24', 'default',
			'N', 'N', 'Allocated',
			'JHTEST _blk'
	) RETURNING * INTO _blk;

	INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description
	) VALUES (
		'172.31.30.3/24', 'default',
			'Y', 'N', 'Allocated',
			'JHTEST _nb1'
	) RETURNING * INTO _nb1;

	INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description
	) VALUES (
		'172.31.30.4/24', 'default',
			'Y', 'N', 'Allocated',
			'JHTEST _nb2'
	) RETURNING * INTO _nb2;

	RAISE NOTICE 'Testing to see if inserts work...';
	INSERT INTO network_interface (
		device_id, network_interface_name, network_interface_type,
		description,
		should_monitor, netblock_id
	) VALUES (
		_dev1.device_id, 'JHTEST0', 'broadcast', 
		'JHTEST0',
		'Y', _nb1.netblock_id
	) RETURNING * INTO _ni;

	SELECT count(*)
		INTO _tally
		FROM network_interface_netblock
		WHERE network_interface_id = _ni.network_interface_id
		AND netblock_id = _ni.netblock_id;
	IF _tally != 1 THEN
		RAISE EXCEPTION 'There should be one record.  There are %', _tally;
	END IF;

	RAISE NOTICE 'Testing to see if updates of network_interface.netblock_Id works from another value...';
	UPDATE network_interface
	SET netblock_id = _nb2.netblock_id
	WHERE network_interface_id = _ni.network_interface_id
	AND netblock_id = _nb1.netblock_id;

	SELECT count(*)
		INTO _tally
		FROM network_interface_netblock
		WHERE network_interface_id = _ni.network_interface_id
		AND netblock_id = _nb1.netblock_id;
	IF _tally != 0 THEN
		RAISE EXCEPTION 'There should be none of the old IP in network_interface_netblock.  There are %', _tally;
	END IF;
	RAISE NOTICE '... 0 records where expected';

	SELECT count(*)
		INTO _tally
		FROM network_interface_netblock
		WHERE network_interface_id = _ni.network_interface_id
		AND netblock_id = _nb2.netblock_id;
	IF _tally != 1 THEN
		RAISE EXCEPTION 'There should be one record of the new IP (%) in network_interface_netblock.  There are %', _nb2.netblock_id, _tally;
	END IF;
	RAISE NOTICE '... One record where expected';

	RAISE NOTICE 'Cleaning up % % %...', _nb1.netblock_id, _nb2.netblock_id, _ni.network_interface_id;
	DELETE FROM network_interface_netblock where netblock_id = _nb2.netblock_id;
	DELETE FROM network_interface_netblock where netblock_id = _nb1.netblock_id;
	DELETE FROM network_interface where network_interface_id = _ni.network_interface_id;

	RAISE NOTICE 'Now testing to see if network_interface_netblock records show up in network_interface...';

	INSERT INTO network_interface (
		device_id, network_interface_name, network_interface_type,
		description,
		should_monitor, netblock_id
	) VALUES (
		_dev1.device_id, 'JHTEST0', 'broadcast', 
		'JHTEST0',
		'Y', NULL
	) RETURNING * INTO _ni;

	RAISE NOTICE 'Testing for any records..';
	SELECT count(*)
		INTO _tally
		FROM network_interface_netblock
		WHERE network_interface_id = _ni.network_interface_id
	;
	IF _tally != 0 THEN
		RAISE EXCEPTION 'There should be zero records.  There are %', _tally;
	END IF;

	RAISE NOTICE 'Adding first block (%)...', _nb1.netblock_id;
	INSERT INTO network_interface_netblock
		(network_interface_id, netblock_id, network_interface_rank)
		VALUES
		(_ni.network_interface_id, _nb1.netblock_id, 10);
	SELECT count(*) INTO _tally from network_interface
		WHERE network_interface_id = _ni.network_interface_Id
		AND netblock_id = _nb1.netblock_id;
	IF _tally != 1 THEN
		RAISE EXCEPTION 'First: There should be One record.  There are %', _tally;
	END IF;

	RAISE NOTICE 'Adding second block (%)...', _nb2.netblock_id;
	INSERT INTO network_interface_netblock
		(network_interface_id, netblock_id, network_interface_rank)
		VALUES
		(_ni.network_interface_id, _nb2.netblock_id, 5);
	SELECT count(*) INTO _tally from network_interface
		WHERE network_interface_id = _ni.network_interface_Id
		AND netblock_id = _nb2.netblock_id;
	IF _tally != 1 THEN
		RAISE EXCEPTION 'There should be One records.  There are %', _tally;
	END IF;

	RAISE NOTICE 'DONE testing the other way...';

	RAISE NOTICE 'Cleanup Records';
	DELETE FROM network_interface_netblock where network_interface_id IN (
		select network_interface_id from network_interface
		where network_interface_name like 'JHTEST%'
	);
	DELETE FROM network_interface where network_interface_name like 'JHTEST%';
	DELETE FROM network_interface where description like 'JHTEST%';
	DELETE FROM device where device_name like 'JHTEST%';
	DELETE from netblock where description like 'JHTEST%';
	DELETE from site where site_code like 'JHTEST%';
	RAISE NOTICE 'End of network_interface_netblock transition tests...';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT jazzhands.validate_network_interface_triggers_transition();
DROP FUNCTION validate_network_interface_triggers_transition();

\t off
