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
	-- Remove service instances
	--
	PERFORM service_manip.remove_service_instance(si.service_instance_id)
		FROM service_instance si
		WHERE si.device_id = ANY(device_id_list);

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

	--
	-- This is second to last because the last step is to delete the device
	-- and these need to happen to cleanup possible foreign keys
	--
	BEGIN
		PERFORM local_hooks.retire_devices_late(device_id_list);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

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

	RETURN;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of retire_devices
-------------------------------------------------------------------

