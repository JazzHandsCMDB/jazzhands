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
BEGIN
	--
	-- device_utils.retire_devices will return whether the device was
	-- actually removed or not, but the previous function always returned
	-- true or raised an exception, even if the device was left around,
	-- so for the principle of least surprise, we're going to always return
	-- true for now
	--
	PERFORM * FROM device_utils.retire_devices(
			device_id_list := ARRAY[ in_Device_id ]
		);

	RETURN true;
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
	nb_list		integer[];
	sn_list		integer[];
	sn_rec		RECORD;
	rl_list		integer[];
	dev_id		jazzhands.device.device_id%TYPE;
	se_id		jazzhands.service_environment.service_environment_id%TYPE;
	nb_id		jazzhands.netblock.netblock_id%TYPE;
BEGIN
	--
	-- Add all of the BMCs for any retiring devices to the list in case
	-- they are not specified
	--
	device_id_list := array_cat(
		device_id_list,
		(SELECT
			array_agg(manager_device_id)
		FROM
			device_management_controller dmc
		WHERE
			dmc.device_id = ANY(device_id_list) AND
			device_mgmt_control_type = 'bmc'
		)
	);

	--
	-- Delete network_interfaces
	--
	PERFORM device_utils.remove_network_interfaces(
		network_interface_id_list := ARRAY(
			SELECT
				network_interface_id
			FROM
				network_interface ni
			WHERE
				ni.device_id = ANY(device_id_list)
		)
	);

	RAISE LOG 'Removing inter_component_connections...';

	WITH s AS (
		SELECT DISTINCT
			slot_id
		FROM
			v_device_slots ds
		WHERE
			ds.device_id = ANY(device_id_list)
	)
	DELETE FROM inter_component_connection WHERE
		slot1_id IN (SELECT slot_id FROM s) OR
		slot2_id IN (SELECT slot_id FROM s);

	RAISE LOG 'Removing device properties...';

	DELETE FROM property WHERE device_collection_id IN (
		SELECT
			dc.device_collection_id
		FROM
			device_collection dc JOIN
			device_collection_device dcd USING (device_collection_id)
		WHERE
			dc.device_collection_type = 'per-device' AND
			dcd.device_id = ANY(device_id_list)
	);

	RAISE LOG 'Removing per-device device_collections...';

	DELETE FROM
		device_collection_device dcd
	WHERE
		dcd.device_id = ANY(device_id_list) AND
		device_collection_id NOT IN (
			SELECT
				device_collection_id
			FROM
				device_collection
			WHERE
				device_collection_type = 'per-device'
		);

	--
	-- Make sure all rack_location stuff has been cleared out
	--

	RAISE LOG 'Removing rack_locations...';

	SELECT array_agg(rack_location_id) INTO rl_list FROM (
		SELECT DISTINCT
			rack_location_id
		FROM
			device d
		WHERE
			d.device_id = ANY(device_id_list) AND
			rack_location_id IS NOT NULL
		UNION
		SELECT DISTINCT
			rack_location_id
		FROM
			component c JOIN
			v_device_components dc USING (component_id)
		WHERE
			dc.device_id = ANY(device_id_list) AND
			rack_location_id IS NOT NULL
	) x;

	UPDATE
		device d
	SET
		rack_location_id = NULL
	WHERE
		d.device_id = ANY(device_id_list) AND
		rack_location_id IS NOT NULL;

	UPDATE
		component
	SET
		rack_location_id = NULL
	WHERE
		component_id IN (
			SELECT
				component_id
			FROM
				v_device_components dc
			WHERE
				dc.device_id = ANY(device_id_list)
		) AND
		rack_location_id IS NOT NULL;

	--
	-- Delete any now-abandoned rack_locations
	--
	DELETE FROM
		rack_location rl
	WHERE
		rack_location_id = ANY (rl_list) AND
		rack_location_id NOT IN (
			SELECT
				rack_location_id
			FROM
				device
			UNION
			SELECT
				rack_location_id
			FROM
				component
		);

	RAISE LOG 'Removing device_management_controller links...';

	DELETE FROM device_management_controller dmc WHERE
		dmc.device_id = ANY (device_id_list) OR
		manager_device_id = ANY (device_id_list);

	RAISE LOG 'Removing device_encapsulation_domain entries...';

	DELETE FROM device_encapsulation_domain ded WHERE
		ded.device_id = ANY (device_id_list);

	--
	-- Clear out all of the logical_volume crap
	--
	RAISE LOG 'Removing logical volume hierarchies...';
	SET CONSTRAINTS ALL DEFERRED;

	DELETE FROM volume_group_physicalish_vol vgpv WHERE
		vgpv.device_id = ANY (device_id_list);
	DELETE FROM physicalish_volume pv WHERE
		pv.device_id = ANY (device_id_list);

	WITH z AS (
		DELETE FROM volume_group vg
		WHERE vg.device_id = ANY (device_id_list)
		RETURNING vg.volume_group_id
	)
	DELETE FROM volume_group_purpose WHERE
		volume_group_id IN (SELECT volume_group_id FROM z);

	WITH z AS (
		DELETE FROM logical_volume lv
		WHERE lv.device_id = ANY (device_id_list)
		RETURNING lv.logical_volume_id
	), y AS (
		DELETE FROM logical_volume_purpose WHERE
			logical_volume_id IN (SELECT logical_volume_id FROM z)
	)
	DELETE FROM logical_volume_property WHERE
		logical_volume_id IN (SELECT logical_volume_id FROM z);

	SET CONSTRAINTS ALL IMMEDIATE;

	--
	-- Attempt to delete all of the devices
	--
	SELECT service_environment_id INTO se_id FROM service_environment WHERE
		service_environment_name = 'unallocated';

	FOREACH dev_id IN ARRAY device_id_list LOOP
		RAISE LOG 'Deleting device %', dev_id;

		BEGIN
			DELETE FROM device_note dn WHERE dn.device_id = dev_id;

			DELETE FROM device d WHERE d.device_id = dev_id;
			device_id := dev_id;
			success := true;
			RETURN NEXT;
		EXCEPTION
			WHEN foreign_key_violation THEN
				UPDATE device d SET
					device_name = NULL,
					service_environment_id = se_id,
					device_status = 'removed',
					is_monitored = 'N',
					should_fetch_config = 'N',
					description = NULL
				WHERE
					d.device_id = dev_id;

				device_id := dev_id;
				success := false;
				RETURN NEXT;
		END;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of retire_devices
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin remove_network_interface
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.remove_network_interface (
	network_interface_id	jazzhands.network_interface.network_interface_id%TYPE DEFAULT NULL,
	device_id				device.device_id%TYPE DEFAULT NULL,
	network_interface_name	jazzhands.network_interface.network_interface_name%TYPE DEFAULT NULL
) RETURNS boolean AS $$
DECLARE
	ni_id		ALIAS FOR network_interface_id;
	dev_id		ALIAS FOR device_id;
	ni_name		ALIAS FOR network_interface_name;
BEGIN
	IF network_interface_id IS NULL THEN
		IF device_id IS NULL OR network_interface_name IS NULL THEN
			RAISE 'Must pass either network_interface_id or device_id and network_interface_name to device_utils.delete_network_interface'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		SELECT
			ni.network_interface_id INTO ni_id
		FROM
			network_interface ni
		WHERE
			ni.device_id = dev_id AND
			ni.network_interface_name = ni_name;

		IF NOT FOUND THEN
			RETURN false;
		END IF;
	END IF;

	PERFORM * FROM device_utils.remove_network_interfaces(
			network_interface_id_list := ARRAY[ network_interface_id ]
		);

	RETURN true;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of remove_network_interface
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin remove_network_interfaces
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.remove_network_interfaces (
	network_interface_id_list	integer[]
) RETURNS boolean AS $$
DECLARE
	nb_list		integer[];
	sn_list		integer[];
	sn_rec		RECORD;
	nb_id		jazzhands.netblock.netblock_id%TYPE;
BEGIN
	--
	-- Save off some netblock information for now
	--

	RAISE LOG 'Removing network_interfaces with ids %',
		array_to_string(network_interface_id_list, ', ');

	RAISE LOG 'Retrieving netblock information...';

	SELECT
		array_agg(nin.netblock_id) INTO nb_list
	FROM
		network_interface_netblock nin
	WHERE
		nin.network_interface_id = ANY(network_interface_id_list);

	SELECT DISTINCT
		array_agg(shared_netblock_id) INTO sn_list
	FROM
		shared_netblock_network_int snni
	WHERE
		snni.network_interface_id = ANY(network_interface_id_list);

	--
	-- Clean up network bits
	--

	RAISE LOG 'Removing shared netblocks...';

	DELETE FROM shared_netblock_network_int WHERE
		network_interface_id IN (
			SELECT
				network_interface_id
			FROM
				network_interface ni
			WHERE
				ni.network_interface_id = ANY(network_interface_id_list)
		);

	--
	-- Clean up things for any shared_netblocks which are now orphaned
	-- Unfortunately, we have to do these as individual queries to catch
	-- exceptions
	--
	FOR sn_rec IN SELECT
		shared_netblock_id,
		netblock_id
	FROM
		shared_netblock s LEFT JOIN
		shared_netblock_network_int USING (shared_netblock_id)
	WHERE
		shared_netblock_id = ANY(sn_list) AND
		network_interface_id IS NULL
	LOOP
		BEGIN
			DELETE FROM dns_record dr WHERE
				dr.netblock_id = sn_rec.netblock_id;
			DELETE FROM shared_netblock sn WHERE
				sn.shared_netblock_id = sn_rec.shared_netblock_id;
			BEGIN
				DELETE FROM netblock n WHERE
					n.netblock_id = sn_rec.netblock_id;
			EXCEPTION WHEN foreign_key_violation THEN
				NULL;
			END;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	RAISE LOG 'Removing directly-assigned netblocks...';

	DELETE FROM network_interface_netblock WHERE network_interface_id IN (
			SELECT
				network_interface_id
		 	FROM
				network_interface ni
			WHERE
				ni.network_interface_id = ANY (network_interface_id_list)
	);

	RAISE LOG 'Removing network_interfaces...';

	DELETE FROM network_interface_purpose nip WHERE
		nip.network_interface_id = ANY(network_interface_id_list);

	DELETE FROM network_interface ni WHERE ni.network_interface_id =
		ANY(network_interface_id_list);

	RAISE LOG 'Removing netblocks...';
	IF nb_list IS NOT NULL THEN
		FOREACH nb_id IN ARRAY nb_list LOOP
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = nb_id;

				DELETE FROM netblock n WHERE
					n.netblock_id = nb_id;
			EXCEPTION WHEN foreign_key_violation THEN
				NULL;
			END;
		END LOOP;
	END IF;

	RETURN true;
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
	PERFORM device_utils.retire_racks(
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
	rid					ALIAS FOR rack_id;
	device_id_list		integer[];
	component_id_list	integer[];
	enc_domain_list		text[];
	empty_enc_domain_list		text[];
BEGIN
	BEGIN
		PERFORM local_hooks.rack_retire_early(rack_id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	--
	-- Get the list of devices which either are directly attached to
	-- a rack_location in this rack, or which are attached to a component
	-- which is attached to this rack.  Do this once, since it's an
	-- expensive query
	--
	device_id_list := ARRAY(
		SELECT
			device_id
		FROM
			device d JOIN
			rack_location rl USING (rack_location_id)
		WHERE
			rl.rack_id = ANY(rack_id_list)
		UNION
		SELECT
			device_id
		FROM
			rack_location rl JOIN
			component pc USING (rack_location_id) JOIN
			v_component_hier ch USING (component_id) JOIN
			device d ON (d.component_id = ch.child_component_id)
		WHERE
			rl.rack_id = ANY(rack_id_list)
	);

	--
	-- For components, just get a list of those directly attached to the rack
	-- and remove them.  We probably don't need to save this list, but just
	-- in case, we do
	--
	WITH x AS (
		UPDATE
			component AS c
		SET
			rack_location_id = NULL
		FROM
			rack_location rl
		WHERE
			rl.rack_location_id = c.rack_location_id AND
			rl.rack_id = ANY(rack_id_list)
		RETURNING
			c.component_id AS component_id
	) SELECT ARRAY(SELECT component_id FROM x) INTO component_id_list;

	--
	-- Get a list of all of the encapsulation_domains that are
	-- used by devices in these racks and stash them for later
	--
	enc_domain_list := ARRAY(
		SELECT DISTINCT
			encapsulation_domain
		FROM
			device_encapsulation_domain
		WHERE
			device_id = ANY(device_id_list)
	);

	PERFORM device_utils.retire_devices(device_id_list := device_id_list);

	--
	-- Check the encapsulation domains and for any that have no devices
	-- in them any more, clean up the layer2_networks for them
	--

	empty_enc_domain_list := ARRAY(
		SELECT
			encapsulation_domain
		FROM
			unnest(enc_domain_list) AS x(encapsulation_domain)
		WHERE
			encapsulation_domain NOT IN (
				SELECT encapsulation_domain FROM device_encapsulation_domain
			)
	);

	IF FOUND THEN
		PERFORM layerx_network_manip.delete_layer2_networks(
			layer2_network_id_list := ARRAY(
				SELECT
					layer2_network_id
				FROM
					layer2_network
				WHERE
					encapsulation_domain = ANY(empty_enc_domain_list)
			)
		);
		DELETE FROM encapsulation_domain WHERE
			encapsulation_domain = ANY(empty_enc_domain_list);
	END IF;

	BEGIN
		PERFORM local_hooks.racK_retire_late(rack_id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	FOREACH rid IN ARRAY rack_id_list LOOP
		BEGIN
			DELETE FROM rack r WHERE r.rack_id = rid;
			success := true;
			RETURN NEXT;
		EXCEPTION WHEN foreign_key_violation THEN
			UPDATE rack r SET
				room = NULL,
				sub_room = NULL,
				rack_row = NULL,
				rack_name = 'none',
				description = 'retired'
			WHERE	r.rack_id = rid;
			success := false;
			RETURN NEXT;
		END;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of retire_rack
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin device_utils.monitoring_off_in_rack
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_utils.monitoring_off_in_rack (
	rack_id	rack.rack_id%type
) RETURNS boolean AS $$
DECLARE
	rid	ALIAS FOR rack_id;
BEGIN
	BEGIN
		PERFORM local_hooks.monitoring_off_in_rack_early(
			rack_id, false
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	UPDATE device d SET
		is_monitored = 'N'
	WHERE
		is_monitored = 'Y' AND
		device_id IN (
			SELECT
				device_id
			FROM
				device d JOIN
				rack_location rl USING (rack_location_id)
			WHERE
				rl.rack_id = rid
		);

	BEGIN
		PERFORM local_hooks.monitoring_off_in_rack_late(
			rack_id, false
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	RETURN true;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end device_utils.monitoring_off_in_rack
-------------------------------------------------------------------
