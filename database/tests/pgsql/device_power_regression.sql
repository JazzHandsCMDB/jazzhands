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

-- 
-- Trigger tests
--
CREATE OR REPLACE FUNCTION device_power_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_rpc			device%ROWTYPE;
	_dev			device%ROWTYPE;
	_rpcdt			device_type%ROWTYPE;
	_devdt			device_type%ROWTYPE;
	_rpcpport		device_power_interface%ROWTYPE;
	_devpport		device_power_interface%ROWTYPE;
	_rpcptmpl		device_type_power_port_templt%ROWTYPE;
	_devptmpl		device_type_power_port_templt%ROWTYPE;
	_conn			device_power_connection%ROWTYPE;
BEGIN
	RAISE NOTICE 'Cleanup Records from Previous Tests';
	delete from device_power_connection
		where rpc_device_id in
			(select device_id from device where site_code like 'JHTEST%')
		or device_id in
			(select device_id from device where site_code like 'JHTEST%');
	delete from device_power_interface where device_id in
			(select device_id from device where site_code = 'JHTEST01');
	delete from device_type_power_port_templt where device_type_id in
			(select device_type_id from device_type 
				where model like 'JHTEST%');
	delete from device where site_code like 'JHTEST%' 
		or device_name like 'JHTEST%';
	delete from device_type where model like 'JHTEST%';
	delete from rack where site_code = 'JHTEST01';
	delete from site where site_code = 'JHTEST01';

	RAISE NOTICE '++ Inserting testing data';

	INSERT INTO site (
		site_code, site_status
	) VALUES (
		'JHTEST01', 'ACTIVE'
	);

	RAISE NOTICE ' ... test rpc';
	INSERT INTO device_type (
		model, rack_units, has_802_3_interface,
		has_802_11_interface, snmp_capable, is_chassis
	) values (
		'JHTEST rpc', 2, 'N', 'N', 'N', 'Y'
	) RETURNING * INTO _rpcdt;

	INSERT INTO device_type_power_port_templt (
		power_interface_port, device_type_id, power_plug_style,
		voltage, max_amperage, provides_power
	) values (
		'power5', _rpcdt.device_type_id, 'NEMA 5-15P',
		120, 15, 'Y'
	) RETURNING * INTO _rpcptmpl;

	INSERT INTO device (
		device_type_id, device_name, device_status, site_code,
		service_environment, operating_system_id,
		ownership_status, is_monitored
	) values (
		_rpcdt.device_type_id, 'JHTEST rpc', 'up', 'JHTEST01',
		'production', 0,
		'owned', 'Y'
	) RETURNING * into _rpc;

	RAISE NOTICE ' ... test dev';
	INSERT INTO device_type (
		model, rack_units, has_802_3_interface,
		has_802_11_interface, snmp_capable, is_chassis
	) values (
		'JHTEST dev', 2, 'N', 'N', 'N', 'Y'
	) RETURNING * INTO _devdt;

	INSERT INTO device_type_power_port_templt (
		power_interface_port, device_type_id, power_plug_style,
		voltage, max_amperage, provides_power
	) values (
		'power0', _devdt.device_type_id, 'NEMA L14-30P',
		120, 15, 'N'
	) RETURNING * INTO _devptmpl;

	INSERT INTO device (
		device_type_id, device_name, device_status, site_code,
		service_environment, operating_system_id,
		ownership_status, is_monitored
	) values (
		_devdt.device_type_id, 'JHTEST device', 'up', 'JHTEST01',
		'production', 0,
		'owned', 'Y'
	) RETURNING * into _dev;

	RAISE NOTICE '++ Beginning tests of device_power...';
	PERFORM port_utils.setup_device_power( _dev.device_id );
	PERFORM port_utils.setup_device_power( _rpc.device_id );


	RAISE NOTICE 'Testing if a device connection can have mismatched plugs...';
	BEGIN
		INSERT INTO device_power_connection (
			rpc_device_id, rpc_power_interface_port,
			device_id, power_interface_port
		) VALUES (
			_rpc.device_id, 'power5',
			_dev.device_id, 'power0'
		) RETURNING * INTO _conn;
		RAISE EXCEPTION '... It CAN. (BAD!)';
	EXCEPTION WHEN SQLSTATE 'JH360' THEN
		RAISE NOTICE '... It can not. (GOOD!)';
	END;

	UPDATE device_power_interface 
	   SET provides_power = 'Y', power_plug_style = 'NEMA 5-15P'
	 WHERE device_id = _dev.device_id and power_interface_port = 'power0';
	

	RAISE NOTICE 'Testing if a device connection can have provides_power set to Y...';
	BEGIN
		INSERT INTO device_power_connection (
			rpc_device_id, rpc_power_interface_port,
			device_id, power_interface_port
		) VALUES (
			_rpc.device_id, 'power5',
			_dev.device_id, 'power0'
		) RETURNING * INTO _conn;
		RAISE EXCEPTION '... It CAN. (BAD!)';
	EXCEPTION WHEN SQLSTATE 'JH363' THEN
		RAISE NOTICE '... It can not. (GOOD!)';
	END;

	update device_power_interface set provides_power = 'N'
		where (device_id = _rpc.device_id and power_interface_port = 'power5')
		 or   (device_id = _dev.device_id and power_interface_port = 'power0')
	;

	RAISE NOTICE 'Testing if a device connection can have provides_power set to N...';
	BEGIN
		INSERT INTO device_power_connection (
			rpc_device_id, rpc_power_interface_port,
			device_id, power_interface_port
		) VALUES (
			_rpc.device_id, 'power5',
			_dev.device_id, 'power0'
		) RETURNING * INTO _conn;
		RAISE EXCEPTION '... It CAN. (BAD!)';
	EXCEPTION WHEN SQLSTATE 'JH362' THEN
		RAISE NOTICE '... It can not. (GOOD!)';
	END;

	update device_power_interface set provides_power = 'Y'
		where (device_id = _rpc.device_id and power_interface_port = 'power5')
	;

	update device_power_interface set provides_power = 'N'
	where (device_id = _dev.device_id and power_interface_port = 'power0')
	;

	INSERT INTO device_power_connection (
		rpc_device_id, rpc_power_interface_port,
		device_id, power_interface_port
	) VALUES (
		_rpc.device_id, 'power5',
		_dev.device_id, 'power0'
	) RETURNING * INTO _conn;

	RAISE NOTICE 'Attempting to make the consumer a provider to see if it can..';
	BEGIN
		update device_power_interface set provides_power = 'Y'
		where (device_id = _dev.device_id and power_interface_port = 'power0')
		;
		RAISE EXCEPTION '... It CAN. (BAD!)';
	EXCEPTION WHEN SQLSTATE 'JH361' THEN
		RAISE NOTICE '... It can not. (GOOD!)';
	END;

	RAISE NOTICE 'Attempting to make the provider a consume to see if it can..';
	BEGIN
		update device_power_interface set provides_power = 'N'
			where (device_id = _rpc.device_id and power_interface_port = 'power5')
		;
		RAISE EXCEPTION '... It CAN. (BAD!)';
	EXCEPTION WHEN SQLSTATE 'JH361' THEN
		RAISE NOTICE '... It can not. (GOOD!)';
	END;

	RAISE NOTICE 'Attempting to change a provider plug style to see if it can...';
	BEGIN
		update device_power_interface set power_plug_style = 'NEMA L6-30P'
			where 
			(device_id = _rpc.device_id and power_interface_port = 'power5')
		;
		RAISE EXCEPTION '... It CAN. (BAD!)';
	EXCEPTION WHEN SQLSTATE 'JH360' THEN
		RAISE NOTICE '... It can not. (GOOD!)';
	END;

	RAISE NOTICE 'Attempting to change a consumer plug style to see if it can...';
	BEGIN
		update device_power_interface set power_plug_style = 'NEMA L6-30P'
			where 
			(device_id = _dev.device_id and power_interface_port = 'power0')
		;
		RAISE EXCEPTION '... It CAN. (BAD!)';
	EXCEPTION WHEN SQLSTATE 'JH360' THEN
		RAISE NOTICE '... It can not. (GOOD!)';
	END;

	RAISE NOTICE '++ Done tests of device_power...';
	RAISE NOTICE 'Cleanup Test Records';
	delete from device_power_connection
		where rpc_device_id in
			(select device_id from device where site_code like 'JHTEST%')
		or device_id in
			(select device_id from device where site_code like 'JHTEST%');
	delete from device_power_interface where device_id in
			(select device_id from device where site_code = 'JHTEST01');
	delete from device_type_power_port_templt where device_type_id in
			(select device_type_id from device_type 
				where model like 'JHTEST%');
	delete from device where site_code like 'JHTEST%' 
		or device_name like 'JHTEST%';
	delete from device_type where model like 'JHTEST%';
	delete from rack where site_code = 'JHTEST01';
	delete from site where site_code = 'JHTEST01';

	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT device_power_regression();
-- set search_path=jazzhands;
DROP FUNCTION device_power_regression();

\t off
