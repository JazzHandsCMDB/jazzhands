-------------------------------------------------------------------
-- begin swap_device_ip_addresses
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_manip.swap_device_ip_adresses (
	device1_id device.device_id%TYPE,
	device2_id device.device_id%TYPE,
	swap_mac_addresses boolean DEFAULT FALSE
)
	RETURNS void
	AS $$
BEGIN
	IF swap_mac_addresses THEN
		WITH swp AS (
			SELECT
				l3in1.netblock_id AS nb_id1,
				l3i1.layer3_interface_id AS l3if_id1,
				l3i1.mac_addr AS l3if_mac1,
				l3in2.netblock_id AS nb_id2,
				l3i2.layer3_interface_id AS l3if_id2,
				l3i2.mac_addr AS l3if_mac2
			FROM
				layer3_interface l3i1
				JOIN layer3_interface l3i2 ON l3i1.device_id =
					CASE l3i2.device_id
						WHEN device1_id THEN device2_id
						WHEN device2_id THEN device1_id
					END
					AND l3i1.layer3_interface_name = l3i2.layer3_interface_name
				JOIN layer3_interface_netblock l3in1
					ON l3i1.layer3_interface_id = l3in1.layer3_interface_id
					AND l3i1.device_id = l3in1.device_id
			JOIN layer3_interface_netblock l3in2
					ON l3i2.layer3_interface_id = l3in2.layer3_interface_id
					AND l3i2.device_id = l3in2.device_id
			WHERE l3i1.device_id IN (device1_id, device2_id)
		), upd_l3in AS (
			UPDATE layer3_interface_netblock ul3in
			SET layer3_interface_id = swp.l3if_id1
			FROM swp
			WHERE ul3in.layer3_interface_id = swp.l3if_id2
			RETURNING *
		),
		upd_snl3i AS (
			UPDATE shared_netblock_layer3_interface shnl3i
			SET layer3_interface_id = swp.l3if_id1
			FROM swp
			WHERE shnl3i.layer3_interface_id = swp.l3if_id2
			RETURNING *
		),
		upd_svc_instance AS (
			UPDATE jazzhands.service_instance usvcins
			SET netblock_id = swp.nb_id1
			FROM swp
			WHERE usvcins.netblock_id = swp.nb_id2
			RETURNING *
		) UPDATE layer3_interface ul3i
			SET mac_addr = swp.l3if_mac1
			FROM swp
			WHERE ul3i.layer3_interface_id = swp.l3if_id2
			AND device_id IN ( SELECT device_Id FROM upd_svc_instance)
			AND device_id IN ( SELECT device_Id FROM upd_l3in)
			AND device_id IN ( SELECT device_Id FROM upd_snl3i)
		;
	ELSE
		SET CONSTRAINTS jazzhands.ak_service_instance_device_is_primary DEFERRED;
		SET CONSTRAINTS jazzhands.uq_l3int_devid_name DEFERRED;
		WITH swp AS (
				SELECT
					device1_id AS device_id, device2_id AS new_device_id
							UNION
				SELECT device2_id, device1_id
		), upd_svc_instance AS (
			UPDATE service_instance si
			SET device_id = swp.new_device_id
			FROM swp
			WHERE swp.device_id = si.device_id
				AND netblock_id IS NOT NULL
			RETURNING swp.device_id
		), upd_l3i_net AS (
			UPDATE layer3_interface_netblock l3in
			SET device_id = swp.new_device_id
			FROM swp
			WHERE swp.device_id = l3in.device_id
			RETURNING swp.device_id
		) UPDATE layer3_interface l3i
			SET device_id = swp.new_device_id
			FROM swp
			WHERE swp.device_id = l3i.device_id
			AND swp.device_id IN ( SELECT device_id FROM upd_svc_instance)
			AND swp.device_id IN ( SELECT device_id FROM upd_l3i_net);

		SET CONSTRAINTS jazzhands.ak_service_instance_device_is_primary IMMEDIATE;
		SET CONSTRAINTS jazzhands.uq_l3int_devid_name IMMEDIATE;
	END IF;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER SET search_path TO jazzhands;

