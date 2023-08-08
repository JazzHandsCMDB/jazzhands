/*
 * Copyright (c) 2013-2020 Todd Kover
 * Copyright (c) 2019-2020 Matthew Ragan
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
	where nspname = 'device_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS device_manip;
		CREATE SCHEMA device_manip AUTHORIZATION jazzhands;
		REVOKE ALL ON SCHEMA device_manip FROM public;
		COMMENT ON SCHEMA device_manip IS 'part of jazzhands';

	END IF;
END;
$$;


-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_manip.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id$ -->');
END;
$$ LANGUAGE plpgsql;
--end of procedure id_tag
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin retire_device
-- returns t/f if the device was removed or not
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_manip.retire_device (
	Device_id device.device_id%type,
	retire_modules boolean DEFAULT false
) RETURNS boolean AS $$
DECLARE
	rv	boolean;
BEGIN
	-- return what the table has for this device
	SELECT success FROM device_manip.retire_devices(
			device_id_list := ARRAY[ retire_device.Device_id ]
		)
	INTO rv;

	RETURN rv;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of retire_device
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin retire_devices
-- returns a table of retirement success
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_manip.retire_devices (
	device_id_list	integer[]
) RETURNS TABLE (
	device_id	jazzhands.device.device_id%TYPE,
	success		boolean
) AS $$
DECLARE
	nb_list		integer[];
	sn_list		integer[];
	sn_rec		RECORD;
	mp_rec		RECORD;
	rl_list		integer[];
	dev_id		jazzhands.device.device_id%TYPE;
	se_id		jazzhands.service_environment.service_environment_id%TYPE;
	nb_id		jazzhands.netblock.netblock_id%TYPE;
	cp_list		integer[];
BEGIN
	BEGIN
		PERFORM local_hooks.retire_devices_early(device_id_list);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;
	--
	-- Add all of the BMCs for any retiring devices to the list in case
	-- they are not specified
	--
	device_id_list := array_cat(
		device_id_list,
		(SELECT
			array_agg(manager_device_id)
		FROM
			component_management_controller dmc
			JOIN (SELECT i.device_id, i.component_id 
				FROM jazzhands.device i) d
				USING (component_id)
			JOIN (SELECT i.device_id AS manager_device_id,
					i.component_id AS manager_component_id
					FROM jazzhands.device i) md
				USING (manager_component_id)
		WHERE
			d.device_id = ANY(device_id_list) AND
			component_management_controller_type = 'bmc'
		)
	);

	SELECT array_agg(component_id)
		INTO cp_list
		FROM device d
		WHERE d.device_id = ANY(device_id_list)
		AND d.component_id IS NOT NULL
	;

	--
	-- Delete layer3_interfaces
	--
	PERFORM device_manip.remove_layer3_interfaces(
		layer3_interface_id_list := ARRAY(
			SELECT
				layer3_interface_id
			FROM
				layer3_interface ni
			WHERE
				ni.device_id = ANY(device_id_list)
		)
	);

	--
	-- If device is a member of an MLAG, remove it.  This will also clean
	-- up any logical port assignments for this MLAG
	--

	FOREACH dev_id IN ARRAY device_id_list LOOP
		PERFORM logical_port_manip.remove_mlag_peer(device_id := dev_id);
	END LOOP;

	--
	-- Delete all layer2_connections involving these devices
	--

	WITH x AS (
		SELECT
			layer2_connection_id
		FROM
			layer2_connection l2c
		WHERE
			l2c.logical_port1_id IN (
				SELECT
					logical_port_id
				FROM
					logical_port lp
				WHERE
					lp.device_id = ANY(device_id_list)
			) OR
			l2c.logical_port2_id IN (
				SELECT
					logical_port_id
				FROM
					logical_port lp
				WHERE
					lp.device_id = ANY(device_id_list)
			)
	), z AS (
		DELETE FROM layer2_connection_layer2_network l2cl2n WHERE
			l2cl2n.layer2_connection_id IN (
				SELECT layer2_connection_id FROM x
			)
	)
	DELETE FROM layer2_connection l2c WHERE
		l2c.layer2_connection_id IN (
			SELECT layer2_connection_id FROM x
		);

	--
	-- Delete all logical ports for these devices
	--
	DELETE FROM logical_port lp WHERE lp.device_id = ANY(device_id_list);


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
			WHERE
				rack_location_id IS NOT NULL
			UNION
			SELECT
				rack_location_id
			FROM
				component
			WHERE
				rack_location_id IS NOT NULL
		);

	RAISE LOG 'Removing component_management_controller links...';

	DELETE FROM component_management_controller cmc WHERE
		cmc.component_id = ANY (cp_list) OR
		manager_component_id = ANY (cp_list);

	RAISE LOG 'Removing device_encapsulation_domain entries...';

	DELETE FROM device_encapsulation_domain ded WHERE
		ded.device_id = ANY (device_id_list);

	--
	-- Clear out all of the logical_volume crap
	--
	RAISE LOG 'Removing logical volume hierarchies...';
	SET CONSTRAINTS ALL DEFERRED;

	DELETE FROM volume_group_block_storage_device vgpv WHERE
		vgpv.device_id = ANY (device_id_list);
	DELETE FROM block_storage_device pv WHERE
		pv.device_id = ANY (device_id_list);
	DELETE FROM filesystem f WHERE
		f.device_id = ANY (device_id_list);
	--- XXXX check this
	DELETE FROM virtual_component_logical_volume uclv WHERE
		uclv.logical_volume_id IN (
			SELECT logical_volume_id
			FROM logical_volume lv
			WHERE lv.device_id = ANY (device_id_list)
		);

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
					component_id = NULL,
					service_environment_id = se_id,
					device_status = 'removed',
					description = NULL
				WHERE
					d.device_id = dev_id;

				device_id := dev_id;
				success := false;
				RETURN NEXT;
		END;
	END LOOP;

	BEGIN
		PERFORM local_hooks.retire_devices_late(device_id_list);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;
	RETURN;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of retire_devices
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin remove_layer3_interface
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_manip.remove_layer3_interface (
	layer3_interface_id	jazzhands.layer3_interface.layer3_interface_id%TYPE DEFAULT NULL,
	device_id				device.device_id%TYPE DEFAULT NULL,
	layer3_interface_name	jazzhands.layer3_interface.layer3_interface_name%TYPE DEFAULT NULL
) RETURNS boolean AS $$
DECLARE
	ni_id		ALIAS FOR layer3_interface_id;
	dev_id		ALIAS FOR device_id;
	ni_name		ALIAS FOR layer3_interface_name;
BEGIN
	IF layer3_interface_id IS NULL THEN
		IF device_id IS NULL OR layer3_interface_name IS NULL THEN
			RAISE 'Must pass either layer3_interface_id or device_id and layer3_interface_name to device_manip.delete_layer3_interface'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		SELECT
			ni.layer3_interface_id INTO ni_id
		FROM
			layer3_interface ni
		WHERE
			ni.device_id = dev_id AND
			ni.layer3_interface_name = ni_name;

		IF NOT FOUND THEN
			RETURN false;
		END IF;
	END IF;

	PERFORM * FROM device_manip.remove_layer3_interfaces(
			layer3_interface_id_list := ARRAY[ layer3_interface_id ]
		);

	RETURN true;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of remove_layer3_interface
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin remove_layer3_interfaces
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_manip.remove_layer3_interfaces (
	layer3_interface_id_list	integer[]
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

	RAISE LOG 'Removing layer3_interfaces with ids %',
		array_to_string(layer3_interface_id_list, ', ');

	RAISE LOG 'Retrieving netblock information...';

	SELECT
		array_agg(nin.netblock_id) INTO nb_list
	FROM
		layer3_interface_netblock nin
	WHERE
		nin.layer3_interface_id = ANY(layer3_interface_id_list);

	SELECT DISTINCT
		array_agg(shared_netblock_id) INTO sn_list
	FROM
		shared_netblock_layer3_interface snni
	WHERE
		snni.layer3_interface_id = ANY(layer3_interface_id_list);

	--
	-- Clean up network bits
	--

	RAISE LOG 'Removing shared netblocks...';

	DELETE FROM shared_netblock_layer3_interface WHERE
		layer3_interface_id IN (
			SELECT
				layer3_interface_id
			FROM
				layer3_interface ni
			WHERE
				ni.layer3_interface_id = ANY(layer3_interface_id_list)
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
		shared_netblock_layer3_interface USING (shared_netblock_id)
	WHERE
		shared_netblock_id = ANY(sn_list) AND
		layer3_interface_id IS NULL
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

	DELETE FROM layer3_interface_netblock WHERE layer3_interface_id IN (
		SELECT
			layer3_interface_id
	 	FROM
			layer3_interface ni
		WHERE
			ni.layer3_interface_id = ANY (layer3_interface_id_list)
	);

	RAISE LOG 'Removing layer3_interfaces...';

	DELETE FROM layer3_interface_purpose nip WHERE
		nip.layer3_interface_id = ANY(layer3_interface_id_list);

	DELETE FROM layer3_interface ni WHERE ni.layer3_interface_id =
		ANY(layer3_interface_id_list);

	RAISE LOG 'Removing netblocks (%) ... ', nb_list;
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
--end of remove_layer3_interfaces
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin retire_rack
-- returns t/f if the rack was removed or not
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION device_manip.retire_rack (
	rack_id	rack.rack_id%TYPE
) RETURNS boolean AS $$
BEGIN
	PERFORM device_manip.retire_racks(
		rack_id_list := ARRAY[ rack_id ]
	);
	RETURN true;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;

CREATE OR REPLACE FUNCTION device_manip.retire_racks (
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

	PERFORM device_manip.retire_devices(device_id_list := device_id_list);

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
			DELETE FROM rack_location rl WHERE rl.rack_id = rid;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
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
--end of retire_racks
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin device_manip.monitoring_off_in_rack
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_manip.monitoring_off_in_rack (
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
--end device_manip.monitoring_off_in_rack
-------------------------------------------------------------------

REVOKE ALL ON SCHEMA device_manip FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA device_manip FROM public;

GRANT ALL ON SCHEMA device_manip TO iud_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA device_manip TO iud_role;
