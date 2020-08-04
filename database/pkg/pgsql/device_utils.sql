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
 * Copyright (c) 2013-2020 Todd Kover
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

-- Copyright (c) 2019, Matthew Ragan
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
--
-- TBD: retired
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
--begin retire_device
-- returns t/f if the device was removed or not
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.retire_device (
	in_Device_id device.device_id%type,
	retire_modules boolean DEFAULT false
) RETURNS boolean AS $$
BEGIN
	RETURN device_manip.retire_device( in_Device_id, retire_modules);
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of retire_device
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin retire_devices
-- returns a table of retirement success
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.retire_devices (
	device_id_list	integer[]
) RETURNS TABLE (
	device_id	jazzhands.device.device_id%TYPE,
	success		boolean
) AS $$
DECLARE
	_r	RECORD;
BEGIN
	FOR _r IN SELECT device_manip.retire_devices(device_id_list)
	LOOP
	END LOOP;
		device_id := _r.device_id;
		success := _r.success;
		RETURN NEXT;

	RETURN;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of retire_devices
-------------------------------------------------------------------

-------------------------------------------------------------------
-- begin remove_network_interface
-- XXX deprecated - going away
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.remove_network_interface (
	network_interface_id	jazzhands.layer3_interface.layer3_interface_id%TYPE 
								DEFAULT NULL,
	device_id				device.device_id%TYPE DEFAULT NULL,
	network_interface_name	jazzhands.layer3_interface.layer3_interface_name%TYPE 
								DEFAULT NULL
) RETURNS boolean AS $$
BEGIN
	RETURN device_manip.remove_layer3_interface(network_interface_id_list);
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of remove_network_interfaces
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin retire_rack
-- returns t/f if the rack was removed or not
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.retire_rack (
	rack_id	rack.rack_id%TYPE
) RETURNS boolean AS $$
BEGIN
	PERFORM device_manip.retire_racks(
		rack_id_list := ARRAY[ rack_id ]
	);
	RETURN true;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;

CREATE OR REPLACE FUNCTION device_utils.retire_racks (
	rack_id_list	integer[]
) RETURNS TABLE (
	rack_id		jazzhands.rack.rack_id%TYPE,
	success		boolean
) AS $$
DECLARE
	_r	RECORD;
BEGIN
	FOR _r IN SELECT device_utils.retire_racks( rack_id_list )
	LOOP
		rack_id		:= _r.rack_id;
		success		:= _r.success;
		RETURN NEXT;
	END LOOP;

	RETURN;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of retire_racks
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin device_utils.monitoring_off_in_rack
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.monitoring_off_in_rack (
	rack_id	rack.rack_id%type
) RETURNS boolean AS $$
BEGIN
	RETURN device_manip.monitoring_off_in_rack( rack_id );
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end device_utils.monitoring_off_in_rack
-------------------------------------------------------------------
