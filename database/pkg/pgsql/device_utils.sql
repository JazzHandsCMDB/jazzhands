-- Copyright (c) 2005-2010, Vonage Holdings Corp.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

/*
 * Copyright (c) 2013-2014 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * $Id$
 */

-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'device_utils';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS device_utils;
		CREATE SCHEMA device_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA device_utils IS 'part of jazzhands';

	END IF;
END;
$$;


-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id$ -->');
END;
$$ LANGUAGE plpgsql;
--end of procedure id_tag
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin retire_device_ancillary - THIS SHOULD DIE
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.retire_device_ancillary (
	in_Device_id device.device_id%type
) RETURNS VOID AS $$
DECLARE
	v_loc_id	rack_location.rack_location_id%type;
BEGIN
	delete from device_collection_device where device_id = in_Device_id;
	delete from snmp_commstr where device_id = in_Device_id;

	select	rack_location_id
	  into	v_loc_id
	  from	device
	 where	device_id = in_Device_id;

	IF v_loc_id is not NULL  THEN
		update device set rack_location_Id = NULL where device_id = in_device_id;
		delete from rack_location where rack_location_id = v_loc_id;
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-------------------------------------------------------------------
--end of retire_device_ancillary
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin purge_physical_path
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.purge_physical_path (
	_in_l1c	layer1_connection.layer1_connection_id%TYPE
) RETURNS VOID AS $$
DECLARE
	_r	RECORD;
BEGIN
	FOR _r IN 
	      SELECT  pc.physical_connection_id,
			pc.cable_type,
			p1.physical_port_id as pc_p1_physical_port_id,
			p1.port_name as pc_p1_physical_port_name,
			d1.device_id as pc_p1_device_id,
			d1.device_name as pc_p1_device_name,
			p2.physical_port_id as pc_p2_physical_port_id,
			p2.port_name as pc_p2_physical_port_name,
			d2.device_id as pc_p2_device_id,
			d2.device_name as pc_p2_device_name
		  FROM  v_physical_connection vpc
			INNER JOIN physical_connection pc
				USING (physical_connection_id)
			INNER JOIN physical_port p1
				ON p1.physical_port_id = pc.physical_port1_id
			INNER JOIN device d1
				ON d1.device_id = p1.device_id
			INNER JOIN physical_port p2
				ON p2.physical_port_id = pc.physical_port2_id
			INNER JOIN device d2
				ON d2.device_id = p2.device_id
		WHERE   vpc.inter_component_connection_id = _in_l1c
		ORDER BY level
	LOOP
		DELETE from physical_connecion where physical_connection_id =
			_r.physical_connection_id;
	END LOOP;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--ENDin purge_physical_path
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin purge_l1_connection_from_port
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.purge_l1_connection_from_port (
	_in_portid	physical_port.physical_port_id%TYPE
) RETURNS VOID AS $$
DECLARE
	_r	RECORD;
BEGIN
	FOR _r IN 
		SELECT * FROM layer1_connection WHERE
			physical_port1_id = _in_portid or physical_port2_id = _in_portid
	LOOP
		PERFORM device_utils.purge_physical_path(
			_r.layer1_connection_id
		);
		DELETE from layer1_connection WHERE layer1_connection_id =
			_r.layer1_connection_id;
	END LOOP;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--END purge_l1_connection_from_port
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin purge_physical_ports
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.purge_physical_ports (
	_in_devid	device.device_id%TYPE
) RETURNS VOID AS $$
DECLARE
	_r	RECORD;
BEGIN
	FOR _r IN 
		SELECT * FROM physical_port WHERE device_id = _in_devid
	LOOP
		PERFORM device_utils.purge_l1_connection_from_port(
			_r.physical_port_id
		);
		DELETE from physical_port WHERE physical_port_id =
			_r.physical_port_id;
	END LOOP;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--END purge_physical_ports
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin purge_power_ports
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.purge_power_ports (
	_in_devid	device.device_id%TYPE
) RETURNS VOID AS $$
DECLARE
	_r	RECORD;
BEGIN
	DELETE FROM device_power_connection
	 WHERE  ( device_id = _in_devid AND
				power_interface_port IN
				(SELECT power_interface_port
				   FROM device_power_interface
				  WHERE device_id = _in_devid
				)
			)
	 OR	     ( rpc_device_id = _in_devid AND
			rpc_power_interface_port IN
				(SELECT power_interface_port
				   FROM device_power_interface
				  WHERE device_id = _in_devid
				)
			);

	DELETE FROM device_power_interface
	 WHERE  device_id = _in_devid;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--END purge_power_ports
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin retire_device
-- returns t/f if the device was removed or not
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.retire_device (
	in_Device_id device.device_id%type,
	retire_modules boolean DEFAULT false
) RETURNS boolean AS $$
DECLARE
	tally		INTEGER;
	_r			RECORD;
	_d			DEVICE%ROWTYPE;
	_mgrid		DEVICE.DEVICE_ID%TYPE;
	_purgedev	boolean;
BEGIN
	_purgedev := false;

	BEGIN
		PERFORM local_hooks.device_retire_early(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT * INTO _d FROM device WHERE device_id = in_Device_id;
	delete from dns_record where netblock_id in (
		select netblock_id 
		from network_interface where device_id = in_Device_id
	);

	delete from network_interface_purpose where device_id = in_Device_id;

	DELETE FROM network_interface_netblock
	WHERE network_interface_id IN (
			SELECT network_interface_id
		 	FROM network_interface
			WHERE device_id = in_Device_id
	);

	DELETE FROM network_interface WHERE device_id = in_Device_id;

	PERFORM device_utils.purge_physical_ports( in_Device_id);
--	PERFORM device_utils.purge_power_ports( in_Device_id);

	delete from property where device_collection_id in (
		SELECT	dc.device_collection_id 
		  FROM	device_collection dc
				INNER JOIN device_collection_device dcd
		 			USING (device_collection_id)
		WHERE	dc.device_collection_type = 'per-device'
		  AND	dcd.device_id = in_Device_id
	);

	delete from device_collection_device where device_id = in_Device_id
		AND device_collection_id NOT IN (
			select device_collection_id
			FROM device_collection
			WHERE device_collection_type != 'per-device'
		);
	delete from snmp_commstr where device_id = in_Device_id;

		
	IF _d.rack_location_id IS NOT NULL  THEN
		UPDATE device SET rack_location_id = NULL 
		WHERE device_id = in_Device_id;

		-- This should not be permitted based on constraints, but in case
		-- that constraint had to be disabled...
		SELECT	count(*)
		  INTO	tally
		  FROM	device
		 WHERE	rack_location_id = _d.RACK_LOCATION_ID;

		IF tally = 0 THEN
			DELETE FROM rack_location 
			WHERE rack_location_id = _d.RACK_LOCATION_ID;
		END IF;
	END IF;

	IF _d.chassis_location_id IS NOT NULL THEN
		RAISE EXCEPTION 'Retiring modules is not supported yet.';
	END IF;

	SELECT	manager_device_id
	INTO	_mgrid
	 FROM	device_management_controller
	WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
	LIMIT 1;

	IF _mgrid IS NOT NULL THEN
		DELETE FROM device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
			AND manager_device_id = _mgrid;

		PERFORM device_utils.retire_device( manager_device_id)
		  FROM	device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc';
	END IF;

	BEGIN
		PERFORM local_hooks.device_retire_late(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT count(*)
	INTO tally
	FROM device_note
	WHERE device_id = in_Device_id;

	--
	-- If there is no notes or serial number its save to remove
	-- 
	IF tally = 0 AND _d.ASSET_ID is NULL THEN
		_purgedev := true;
	END IF;

	IF _purgedev THEN
		--
		-- If there is an fk violation, we just preserve the record but
		-- delete all the identifying characteristics
		--
		BEGIN
			DELETE FROM device where device_id = in_Device_Id;
			return false;
		EXCEPTION WHEN foreign_key_violation THEN
			PERFORM 1;
		END;
	END IF;

	UPDATE device SET 
		device_name =NULL,
		service_environment_id = (
			select service_environment_id from service_environment
			where service_environment_name = 'unallocated'),
		device_status = 'removed',
		voe_symbolic_track_id = NULL,
		is_monitored = 'N',
		should_fetch_config = 'N',
		description = NULL
	WHERE device_id = in_Device_id;

	return true;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of retire_device
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin retire_rack
-- returns t/f if the device was removed or not
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.retire_rack (
	_in_rack_id	rack.rack_id%type
) RETURNS boolean AS $$
DECLARE
	_r	RECORD;
BEGIN

	BEGIN
		PERFORM local_hooks.rack_retire_early(_in_rack_id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	FOR _r IN SELECT device_id
			FROM device 
				INNER JOIN rack_location using (rack_location_id)
				INNER JOIN rack using (rack_id)
			WHERE rack_id = _in_rack_id
	LOOP
		PERFORM device_utils.retire_device( _r.device_id, true );
	END LOOP;

	BEGIN
		PERFORM local_hooks.racK_retire_late(_in_rack_id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	BEGIN
		DELETE FROM RACK where rack_id = _in_rack_id;
		RETURN false;
	EXCEPTION WHEN foreign_key_violation THEN
		UPDATE rack SET
			room = NULL,
			sub_room = NULL,
			rack_row = NULL,
			rack_name = 'none',
			description = 'retired'
		WHERE	rack_id = _in_rack_id;
	END;
	RETURN true;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of retire_rack
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin device_utils.monitoring_off_in_rack
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.monitoring_off_in_rack (
	_in_rack_id	rack.rack_id%type
) RETURNS boolean AS $$
BEGIN
	BEGIN
		PERFORM local_hooks.monitoring_off_in_rack_early(
			_in_rack_id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	UPDATE device
	  SET	is_monitored = 'N'
	 WHERE	is_monitored = 'Y'
	 AND	device_id in (
	 		SELECT device_id
			 FROM	device
			 	INNER JOIN rack_location 
					USING (rack_location_id)
			WHERE	rack_id = 67
	);

	BEGIN
		PERFORM local_hooks.monitoring_off_in_rack_late(
			_in_rack_id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	RETURN true;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end device_utils.monitoring_off_in_rack
-------------------------------------------------------------------
