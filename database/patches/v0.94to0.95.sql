--
-- Copyright (c) 2022 Todd Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.


\pset pager
/*
Invoked:

	--suffix=v95
	--scan
	--pre
	pre
	--post
	post
	--final
	final
	--nocleanup
	--reinsert-dir=i
	private_key
	certificate_signing_request
	x509_signed_certificate
	val_device_management_controller_type:val_component_management_controller_type
	device_management_controller:component_management_controller
	netblock
	layer3_network
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance(false);
select clock_timestamp(), now(), clock_timestamp() - now() AS len;


-- BEGIN Misc that does not apply to above
--
-- sanity check since this will break things later
--
DO $$
BEGIN
	PERFORM * from device_management_controller 
	JOIN device d  USING (device_Id) 
	JOIN (SELECT device_id AS manager_device_id, component_id AS manager_component_id, device_name, device_status FROm device) md 
		USING (manager_device_id) 
	WHERE component_Id IS NULL OR manager_component_id IS NULL;

	IF FOUND THEN
		RAISE EXCEPTION 'There are devices that are part of the manageement controller process without components, so failing.';
	END IF;
END;
$$;

DO
$$
DECLARE
	_t	INTEGER;
BEGIN
	SELECT count(*) INTO _t FROM asset
	WHERE ownership_status != 'leased'
	AND lease_expiration_date IS NOT NULL;

	IF _t > 0 THEN
		RAISE EXCEPTION 'Need to reset assset.lease_expiration_date to NULL for non-leased assets.';
	END IF;
END;
$$;

--
-- this gets created later but breaks recreating an AK
--
ALTER TABLE IF EXISTS jazzhands.certificate_signing_request
        DROP CONSTRAINT IF EXISTS fk_csr_pvtkeyid;
ALTER TABLE IF EXISTS jazzhands.certificate_signing_request
        DROP CONSTRAINT IF EXISTS fk_csr_pvtkeyid_pkhid;


-- END Misc that does not apply to above
--
-- BEGIN: process_ancillary_schema(schema_support)
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_schema_support']);
-- DONE: process_ancillary_schema(schema_support)
--
-- Process middle (non-trigger) schema jazzhands_cache
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_cache']);
--
-- Process middle (non-trigger) schema account_collection_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_collection_manip']);
--
-- Process middle (non-trigger) schema account_password_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_password_manip']);
--
-- Process middle (non-trigger) schema approval_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_approval_utils']);
--
-- Process middle (non-trigger) schema audit
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_audit']);
--
-- Process middle (non-trigger) schema auto_ac_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_auto_ac_manip']);
--
-- Process middle (non-trigger) schema backend_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_backend_utils']);
--
-- Process middle (non-trigger) schema company_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_company_manip']);
--
-- Process middle (non-trigger) schema component_connection_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_connection_utils']);
--
-- Process middle (non-trigger) schema component_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_manip']);
--
-- Process middle (non-trigger) schema component_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_utils']);
--
-- Process middle (non-trigger) schema device_manip
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('device_manip', 'remove_layer3_interfaces');
SELECT schema_support.save_grants_for_replay('device_manip', 'remove_layer3_interfaces');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_manip.remove_layer3_interfaces ( integer[] );
CREATE OR REPLACE FUNCTION device_manip.remove_layer3_interfaces(layer3_interface_id_list integer[])
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
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
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'device_manip' AND type = 'function' AND object IN ('remove_layer3_interfaces');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc remove_layer3_interfaces failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('device_manip', 'retire_devices');
SELECT schema_support.save_grants_for_replay('device_manip', 'retire_devices');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_manip.retire_devices ( integer[] );
CREATE OR REPLACE FUNCTION device_manip.retire_devices(device_id_list integer[])
 RETURNS TABLE(device_id integer, success boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
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

	DELETE FROM volume_group_physicalish_volume vgpv WHERE
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
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'device_manip' AND type = 'function' AND object IN ('retire_devices');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc retire_devices failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_manip']);
--
-- Process middle (non-trigger) schema device_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_utils']);
--
-- Process middle (non-trigger) schema dns_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_manip']);
--
-- Process middle (non-trigger) schema dns_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_utils']);
--
-- Process middle (non-trigger) schema jazzhands
--
DROP TRIGGER IF EXISTS trigger_pvtkey_pkh_signed_validate ON jazzhands.private_key;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands'::text, object := 'pvtkey_pkh_signed_validate (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands'::text]);
DROP FUNCTION IF EXISTS jazzhands.pvtkey_pkh_signed_validate (  );
DROP TRIGGER IF EXISTS trigger_x509_signed_pkh_csr_validate ON jazzhands.certificate_signing_request;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands'::text, object := 'x509_signed_pkh_csr_validate (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands'::text]);
DROP FUNCTION IF EXISTS jazzhands.x509_signed_pkh_csr_validate (  );
DROP TRIGGER IF EXISTS trigger_x509_signed_pkh_pvtkey_validate ON jazzhands.x509_signed_certificate;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands'::text, object := 'x509_signed_pkh_pvtkey_validate (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands'::text]);
DROP FUNCTION IF EXISTS jazzhands.x509_signed_pkh_pvtkey_validate (  );
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands']);
--
-- Process middle (non-trigger) schema layerx_network_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_layerx_network_manip']);
--
-- Process middle (non-trigger) schema logical_port_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_logical_port_manip']);
--
-- Process middle (non-trigger) schema lv_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_lv_manip']);
--
-- Process middle (non-trigger) schema net_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_net_manip']);
--
-- Process middle (non-trigger) schema netblock_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_manip']);
--
-- Process middle (non-trigger) schema netblock_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_utils']);
--
-- Process middle (non-trigger) schema network_strings
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_network_strings']);
--
-- Process middle (non-trigger) schema obfuscation_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_obfuscation_utils']);
--
-- Process middle (non-trigger) schema person_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_person_manip']);
--
-- Process middle (non-trigger) schema pgcrypto
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_pgcrypto']);
--
-- Process middle (non-trigger) schema physical_address_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_physical_address_utils']);
--
-- Process middle (non-trigger) schema port_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_port_utils']);
--
-- Process middle (non-trigger) schema property_utils
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('property_utils', 'validate_property');
SELECT schema_support.save_grants_for_replay('property_utils', 'validate_property');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS property_utils.validate_property ( new jazzhands.property );
CREATE OR REPLACE FUNCTION property_utils.validate_property(new jazzhands.property)
 RETURNS jazzhands.property
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	tally				integer;
	v_prop				VAL_Property%ROWTYPE;
	v_proptype			VAL_Property_Type%ROWTYPE;
	v_account_collection		account_collection%ROWTYPE;
	v_company_collection		company_collection%ROWTYPE;
	v_device_collection		device_collection%ROWTYPE;
	v_dns_domain_collection		dns_domain_collection%ROWTYPE;
	v_layer2_network_collection	layer2_network_collection%ROWTYPE;
	v_layer3_network_collection	layer3_network_collection%ROWTYPE;
	v_netblock_collection		netblock_collection%ROWTYPE;
	v_network_range				network_range%ROWTYPE;
	v_property_name_collection		property_name_collection%ROWTYPE;
	v_service_environment_collection	service_environment_collection%ROWTYPE;
	v_service_version_collection	service_version_collection%ROWTYPE;
	v_num				integer;
	v_listvalue			Property.Property_Value%TYPE;
BEGIN
	-- Pull in the data from the property and property_type so we can
	-- figure out what is and is not valid

	BEGIN
		SELECT * INTO STRICT v_prop FROM VAL_Property WHERE
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type;

		SELECT * INTO STRICT v_proptype FROM VAL_Property_Type WHERE
			Property_Type = NEW.Property_Type;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE EXCEPTION
				'Property name (%) or type (%) does not exist',
				NEW.property_name, NEW.property_type
				USING ERRCODE = 'foreign_key_violation';
			RETURN NULL;
	END;

	-- Check to see if the property itself is multivalue. That is, if only
	-- one value can be set for this property for a specific property LHS
	IF (v_prop.is_multivalue = false) THEN
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type AND
			account_collection_id IS NOT DISTINCT FROM NEW.account_collection_id
				AND
			account_id IS NOT DISTINCT FROM NEW.account_id AND
			account_realm_id IS NOT DISTINCT FROM NEW.account_realm_id AND
			company_collection_id IS NOT DISTINCT FROM NEW.company_collection_id AND
			company_id IS NOT DISTINCT FROM NEW.company_id AND
			device_collection_id IS NOT DISTINCT FROM NEW.device_collection_id AND
			dns_domain_collection_id IS NOT DISTINCT FROM
				NEW.dns_domain_collection_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			network_range_id IS NOT DISTINCT FROM NEW.network_range_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			property_name_collection_id IS NOT DISTINCT FROM NEW.property_name_collection_id AND
			service_environment_collection_id IS NOT DISTINCT FROM
				NEW.service_environment_collection_id AND
			service_version_collection_id IS NOT DISTINCT FROM
				NEW.service_version_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code AND
			x509_signed_certificate_id IS NOT DISTINCT FROM
				NEW.x509_signed_certificate_id
		;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property of type (%,%) already exists for given LHS and property is not multivalue',
				NEW.Property_Name, NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	ELSE
		-- check for the same lhs+rhs existing, which is basically a dup row
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type AND
			account_collection_id IS NOT DISTINCT FROM NEW.account_collection_id
				AND
			account_id IS NOT DISTINCT FROM NEW.account_id AND
			account_realm_id IS NOT DISTINCT FROM NEW.account_realm_id AND
			company_collection_id IS NOT DISTINCT FROM NEW.company_collection_id AND
			company_id IS NOT DISTINCT FROM NEW.company_id AND
			device_collection_id IS NOT DISTINCT FROM NEW.device_collection_id AND
			dns_domain_collection_id IS NOT DISTINCT FROM
				NEW.dns_domain_collection_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			network_range_id IS NOT DISTINCT FROM NEW.network_range_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			property_name_collection_id IS NOT DISTINCT FROM NEW.property_name_collection_id AND
			service_environment_collection_id IS NOT DISTINCT FROM
				NEW.service_environment_collection_id AND
			service_version_collection_id IS NOT DISTINCT FROM
				NEW.service_version_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code AND
			x509_signed_certificate_id IS NOT DISTINCT FROM
				NEW.x509_signed_certificate_id AND
			property_value IS NOT DISTINCT FROM NEW.property_value AND
			property_value_json IS NOT DISTINCT FROM
				NEW.property_value_json AND
			property_value_boolean IS NOT DISTINCT FROM
				NEW.property_value_boolean AND
			property_value_timestamp IS NOT DISTINCT FROM
				NEW.property_value_timestamp AND
			property_value_account_collection_id IS NOT DISTINCT FROM
				NEW.property_value_account_collection_id AND
			property_value_device_collection_id IS NOT DISTINCT FROM
				NEW.property_value_device_collection_id AND
			property_value_netblock_collection_id IS NOT DISTINCT FROM
				NEW.property_value_netblock_collection_id AND
			property_value_service_version_collection_id IS NOT DISTINCT FROM
				NEW.property_value_service_version_collection_id AND
			property_value_password_type IS NOT DISTINCT FROM
				NEW.property_value_password_type AND
			property_value_token_collection_id IS NOT DISTINCT FROM
				NEW.property_value_token_collection_id AND
			property_value_encryption_key_id IS NOT DISTINCT FROM
				NEW.property_value_encryption_key_id AND
			property_value_private_key_id IS NOT DISTINCT FROM
				NEW.property_value_private_key_id AND
			start_date IS NOT DISTINCT FROM NEW.start_date AND
			finish_date IS NOT DISTINCT FROM NEW.finish_date
		;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property of (n,t) (%,%) already exists for given property',
				NEW.Property_Name, NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;

	END IF;

	-- Check to see if the property type is multivalue. That is, if only
	-- one property and value can be set for any properties with this type
	-- for a specific property LHS

	IF (v_proptype.is_multivalue = false) THEN
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Type = NEW.Property_Type AND
			account_collection_id IS NOT DISTINCT FROM NEW.account_collection_id
				AND
			account_id IS NOT DISTINCT FROM NEW.account_id AND
			account_realm_id IS NOT DISTINCT FROM NEW.account_realm_id AND
			company_collection_id IS NOT DISTINCT FROM NEW.company_collection_id AND
			company_id IS NOT DISTINCT FROM NEW.company_id AND
			device_collection_id IS NOT DISTINCT FROM NEW.device_collection_id AND
			dns_domain_collection_id IS NOT DISTINCT FROM
				NEW.dns_domain_collection_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			network_range_id IS NOT DISTINCT FROM NEW.network_range_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			property_name_collection_id IS NOT DISTINCT FROM NEW.property_name_collection_id AND
			service_environment_collection_id IS NOT DISTINCT FROM
				NEW.service_environment_collection_id AND
			service_version_collection_id IS NOT DISTINCT FROM
				NEW.service_version_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code AND
			x509_signed_certificate_id IS NOT DISTINCT FROM
				NEW.x509_signed_certificate_id
		;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property % of type % already exists for given LHS and property type is not multivalue',
				NEW.Property_Name, NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- now validate the property_value columns.
	tally := 0;

	--
	-- first determine if the property_value is set properly.
	--

	-- iterate over each of fk PROPERTY_VALUE columns and if a valid
	-- value is set, increment tally, otherwise raise an exception.
	IF NEW.Property_Value_JSON IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'json' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be JSON' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Password_Type IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'password_type' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Password_Type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Token_collection_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'token_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Token_Collection_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Account_collection_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'account_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be account_collection_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_netblock_collection_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'netblock_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be netblock_collection_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_service_version_collection_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'service_version_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be service_version_collection_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Timestamp IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'timestamp' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Timestamp' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Device_collection_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'device_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Device_Collection_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.property_value_boolean IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'boolean' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be boolean' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.property_value_encryption_key_id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'encryption_key_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be encryption_key_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.property_value_private_key_id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'private_key_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be private_key_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	-- at this point, tally will be set to 1 if one of the other property
	-- values is set to something valid. Now, check the various options for
	-- PROPERTY_VALUE itself. If a new type is added to the val table, this
	-- trigger needs to be updated or it will be considered invalid. If a
	-- new PROPERTY_VALUE_* column is added, then it will pass through without
	-- trigger modification. This should be considered bad.
	IF NEW.Property_Value IS NOT NULL THEN
		tally := tally + 1;
		IF v_prop.Property_Data_Type = 'number' THEN
			BEGIN
				v_num := to_number(NEW.property_value, '9');
			EXCEPTION
				WHEN OTHERS THEN
					RAISE 'Property_Value must be numeric' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_prop.Property_Data_Type = 'list' THEN
			BEGIN
				SELECT Valid_Property_Value INTO STRICT v_listvalue FROM
					VAL_Property_Value WHERE
						Property_Name = NEW.Property_Name AND
						Property_Type = NEW.Property_Type AND
						Valid_Property_Value = NEW.Property_Value;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					RAISE 'Property_Value must be a valid value' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_prop.Property_Data_Type = 'boolean' THEN
			RAISE 'Boolean values are set in Property_Value_Boolean' USING
				ERRCODE = 'invalid_parameter_value';
		ELSIF v_prop.Property_Data_Type != 'string' THEN
			RAISE 'Property_Value may not be set for this Property_Data_Type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_prop.Property_Data_Type != 'none' AND tally = 0 THEN
		RAISE 'One of the PROPERTY_VALUE fields must be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	IF tally > 1 THEN
		RAISE 'Only one of the PROPERTY_VALUE fields may be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	-- If the LHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-account), and verify that if so
	IF NEW.account_collection_id IS NOT NULL THEN
		IF v_prop.account_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection
					FROM account_collection WHERE
					account_collection_Id = NEW.account_collection_id;
				IF v_account_collection.account_collection_Type != v_prop.account_collection_type
				THEN
					RAISE 'account_collection_id must be of type %',
					v_prop.account_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a company_collection_ID, check to see if it must be a
	-- specific type (e.g. per-company), and verify that if so
	IF NEW.company_collection_id IS NOT NULL THEN
		IF v_prop.company_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_company_collection
					FROM company_collection WHERE
					company_collection_Id = NEW.company_collection_id;
				IF v_company_collection.company_collection_Type != v_prop.company_collection_type
				THEN
					RAISE 'company_collection_id must be of type %',
					v_prop.company_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a device_collection_ID, check to see if it must be a
	-- specific type (e.g. per-device), and verify that if so
	IF NEW.device_collection_id IS NOT NULL THEN
		IF v_prop.device_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_device_collection
					FROM device_collection WHERE
					device_collection_Id = NEW.device_collection_id;
				IF v_device_collection.device_collection_Type != v_prop.device_collection_type
				THEN
					RAISE 'device_collection_id must be of type %',
					v_prop.device_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a dns_domain_collection_ID, check to see if it must be a
	-- specific type (e.g. per-dns_domain), and verify that if so
	IF NEW.dns_domain_collection_id IS NOT NULL THEN
		IF v_prop.dns_domain_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_dns_domain_collection
					FROM dns_domain_collection WHERE
					dns_domain_collection_Id = NEW.dns_domain_collection_id;
				IF v_dns_domain_collection.dns_domain_collection_Type != v_prop.dns_domain_collection_type
				THEN
					RAISE 'dns_domain_collection_id must be of type %',
					v_prop.dns_domain_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a layer2_network_collection_ID, check to see if it must be a
	-- specific type (e.g. per-layer2_network), and verify that if so
	IF NEW.layer2_network_collection_id IS NOT NULL THEN
		IF v_prop.layer2_network_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_layer2_network_collection
					FROM layer2_network_collection WHERE
					layer2_network_collection_Id = NEW.layer2_network_collection_id;
				IF v_layer2_network_collection.layer2_network_collection_Type != v_prop.layer2_network_collection_type
				THEN
					RAISE 'layer2_network_collection_id must be of type %',
					v_prop.layer2_network_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a layer3_network_collection_ID, check to see if it must be a
	-- specific type (e.g. per-layer3_network), and verify that if so
	IF NEW.layer3_network_collection_id IS NOT NULL THEN
		IF v_prop.layer3_network_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_layer3_network_collection
					FROM layer3_network_collection WHERE
					layer3_network_collection_Id = NEW.layer3_network_collection_id;
				IF v_layer3_network_collection.layer3_network_collection_Type != v_prop.layer3_network_collection_type
				THEN
					RAISE 'layer3_network_collection_id must be of type %',
					v_prop.layer3_network_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a netblock_collection_ID, check to see if it must be a
	-- specific type (e.g. per-netblock), and verify that if so
	IF NEW.netblock_collection_id IS NOT NULL THEN
		IF v_prop.netblock_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_netblock_collection
					FROM netblock_collection WHERE
					netblock_collection_Id = NEW.netblock_collection_id;
				IF v_netblock_collection.netblock_collection_Type != v_prop.netblock_collection_type
				THEN
					RAISE 'netblock_collection_id must be of type %',
					v_prop.netblock_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a network_range_id, check to see if it must
	-- be a specific type and verify that if so
	IF NEW.netblock_collection_id IS NOT NULL THEN
		IF v_prop.network_range_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_network_range
					FROM network_range WHERE
					network_range_id = NEW.network_range_id;
				IF v_network_range.network_range_type != v_prop.network_range_type
				THEN
					RAISE 'network_range_id must be of type %',
					v_prop.network_range_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a property_name_collection_ID, check to see if it must be a
	-- specific type (e.g. per-property), and verify that if so
	IF NEW.property_name_collection_id IS NOT NULL THEN
		IF v_prop.property_name_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_property_name_collection
					FROM property_name_collection WHERE
					property_name_collection_Id = NEW.property_name_collection_id;
				IF v_property_name_collection.property_name_collection_Type != v_prop.property_name_collection_type
				THEN
					RAISE 'property_name_collection_id must be of type %',
					v_prop.property_name_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a service_environment_collection_ID, check to see if it must be a
	-- specific type (e.g. per-service_env), and verify that if so
	IF NEW.service_environment_collection_id IS NOT NULL THEN
		IF v_prop.service_environment_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_service_environment_collection
					FROM service_environment_collection WHERE
					service_environment_collection_Id = NEW.service_environment_collection_id;
				IF v_service_environment_collection.service_environment_collection_Type != v_prop.service_environment_collection_type
				THEN
					RAISE 'service_environment_collection_id must be of type %',
					v_prop.service_environment_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;
	IF NEW.service_version_collection_id IS NOT NULL THEN
		IF v_prop.service_version_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_service_version_collection
					FROM service_version_collection WHERE
					service_version_collection_Id = NEW.service_version_collection_id;
				IF v_service_version_collection.service_version_collection_Type != v_prop.service_version_collection_type
				THEN
					RAISE 'service_version_collection_id must be of type %',
					v_prop.service_version_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-account), and verify that if so
	IF NEW.Property_Value_Account_collection_Id IS NOT NULL THEN
		IF v_prop.property_value_account_collection_type_restriction IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection
					FROM account_collection WHERE
					account_collection_Id = NEW.Property_Value_Account_collection_Id;
				IF v_account_collection.account_collection_Type != v_prop.property_value_account_collection_type_restriction
				THEN
					RAISE 'Property_Value_Account_collection_Id must be of type %',
					v_prop.property_value_account_collection_type_restriction
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a netblock_collection_ID, check to see if it must be a
	-- specific type and verify that if so
	IF NEW.Property_Value_netblock_collection_Id IS NOT NULL THEN
		IF v_prop.property_value_netblock_collection_type_restriction IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_netblock_collection
					FROM netblock_collection WHERE
					netblock_collection_Id = NEW.Property_Value_netblock_collection_Id;
				IF v_netblock_collection.netblock_collection_Type != v_prop.property_value_netblock_collection_type_restriction
				THEN
					RAISE 'Property_Value_netblock_collection_Id must be of type %',
					v_prop.property_value_netbloc_collection_type_restriction
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a service_version_collection_id, check to see if it must be a
	-- specific type and verify that if so
	IF NEW.property_value_service_version_collection_id IS NOT NULL THEN
		IF v_prop.property_value_service_version_collection_id IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_service_version_collection
					FROM service_version_collection WHERE
					service_version_collection_Id = NEW.property_value_service_version_collection_id;
				IF v_service_version_collection.service_version_collection_Type != v_prop.property_value_service_version_collection_type_restriction
				THEN
					RAISE 'Property_Value_service_version_collection_Id must be of type %',
					v_prop.property_value_service_version_collection_type_restriction
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a device_collection_id, check to see if it must be a
	-- specific type and verify that if so
	IF NEW.Property_Value_Device_collection_Id IS NOT NULL THEN
		IF v_prop.property_value_device_collection_type_restriction IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_device_collection
					FROM device_collection WHERE
					device_collection_id = NEW.Property_Value_Device_collection_Id;
				IF v_device_collection.device_collection_type !=
					v_prop.property_value_device_collection_type_restriction
				THEN
					RAISE 'Property_Value_Device_collection_Id must be of type %',
					v_prop.property_value_device_collection_type_restriction
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	--
	--
	IF v_prop.property_data_type = 'json' THEN
		IF NOT validate_json_schema(
				v_prop.property_value_json_schema,
				NEW.property_value_json) THEN
			RAISE EXCEPTION 'JSON provided must match the json schema'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	-- At this point, the RHS has been checked, so now we verify data
	-- set on the LHS

	-- There needs to be a stanza here for every "lhs". If a new column is
	-- added to the property table, a new stanza needs to be added here,
	-- otherwise it will not be validated. This should be considered bad.

	IF v_prop.Permit_Company_Id = 'REQUIRED' THEN
			IF NEW.Company_Id IS NULL THEN
				RAISE 'Company_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Company_Id = 'PROHIBITED' THEN
			IF NEW.Company_Id IS NOT NULL THEN
				RAISE 'Company_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Company_Collection_Id = 'REQUIRED' THEN
			IF NEW.Company_Collection_Id IS NULL THEN
				RAISE 'Company_Collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Company_Collection_Id = 'PROHIBITED' THEN
			IF NEW.Company_Collection_Id IS NOT NULL THEN
				RAISE 'Company_Collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Device_Collection_Id = 'REQUIRED' THEN
			IF NEW.Device_Collection_Id IS NULL THEN
				RAISE 'Device_Collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;

	ELSIF v_prop.Permit_Device_Collection_Id = 'PROHIBITED' THEN
			IF NEW.Device_Collection_Id IS NOT NULL THEN
				RAISE 'Device_Collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_service_environment_collection_id = 'REQUIRED' THEN
			IF NEW.service_environment_collection_id IS NULL THEN
				RAISE 'service_environment_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_service_environment_collection_id = 'PROHIBITED' THEN
			IF NEW.service_environment_collection_id IS NOT NULL THEN
				RAISE 'service_environment is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_service_version_collection_id = 'REQUIRED' THEN
			IF NEW.service_version_collection_id IS NULL THEN
				RAISE 'service_version_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_service_version_collection_id = 'PROHIBITED' THEN
			IF NEW.service_version_collection_id IS NOT NULL THEN
				RAISE 'service_version_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Operating_System_Id = 'REQUIRED' THEN
			IF NEW.Operating_System_Id IS NULL THEN
				RAISE 'Operating_System_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Operating_System_Id = 'PROHIBITED' THEN
			IF NEW.Operating_System_Id IS NOT NULL THEN
				RAISE 'Operating_System_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_operating_system_snapshot_id = 'REQUIRED' THEN
			IF NEW.operating_system_snapshot_id IS NULL THEN
				RAISE 'operating_system_snapshot_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_operating_system_snapshot_id = 'PROHIBITED' THEN
			IF NEW.operating_system_snapshot_id IS NOT NULL THEN
				RAISE 'operating_system_snapshot_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Site_Code = 'REQUIRED' THEN
			IF NEW.Site_Code IS NULL THEN
				RAISE 'Site_Code is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Site_Code = 'PROHIBITED' THEN
			IF NEW.Site_Code IS NOT NULL THEN
				RAISE 'Site_Code is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Account_Id = 'REQUIRED' THEN
			IF NEW.Account_Id IS NULL THEN
				RAISE 'Account_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Account_Id = 'PROHIBITED' THEN
			IF NEW.Account_Id IS NOT NULL THEN
				RAISE 'Account_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Account_Realm_Id = 'REQUIRED' THEN
			IF NEW.Account_Realm_Id IS NULL THEN
				RAISE 'Account_Realm_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Account_Realm_Id = 'PROHIBITED' THEN
			IF NEW.Account_Realm_Id IS NOT NULL THEN
				RAISE 'Account_Realm_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_account_collection_Id = 'REQUIRED' THEN
			IF NEW.account_collection_Id IS NULL THEN
				RAISE 'account_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_account_collection_Id = 'PROHIBITED' THEN
			IF NEW.account_collection_Id IS NOT NULL THEN
				RAISE 'account_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_layer2_network_collection_id = 'REQUIRED' THEN
			IF NEW.layer2_network_collection_id IS NULL THEN
				RAISE 'layer2_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer2_network_collection_id = 'PROHIBITED' THEN
			IF NEW.layer2_network_collection_id IS NOT NULL THEN
				RAISE 'layer2_network_collection_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_layer3_network_collection_id = 'REQUIRED' THEN
			IF NEW.layer3_network_collection_id IS NULL THEN
				RAISE 'layer3_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer3_network_collection_id = 'PROHIBITED' THEN
			IF NEW.layer3_network_collection_id IS NOT NULL THEN
				RAISE 'layer3_network_collection_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_netblock_collection_Id = 'REQUIRED' THEN
			IF NEW.netblock_collection_Id IS NULL THEN
				RAISE 'netblock_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_netblock_collection_Id = 'PROHIBITED' THEN
			IF NEW.netblock_collection_Id IS NOT NULL THEN
				RAISE 'netblock_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_network_range_id = 'REQUIRED' THEN
			IF NEW.network_range_id IS NULL THEN
				RAISE 'network_range_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_network_range_id = 'PROHIBITED' THEN
			IF NEW.network_range_id IS NOT NULL THEN
				RAISE 'network_range_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_property_name_collection_Id = 'REQUIRED' THEN
			IF NEW.property_name_collection_Id IS NULL THEN
				RAISE 'property_name_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_property_name_collection_Id = 'PROHIBITED' THEN
			IF NEW.property_name_collection_Id IS NOT NULL THEN
				RAISE 'property_name_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Property_Rank = 'REQUIRED' THEN
			IF NEW.property_rank IS NULL THEN
				RAISE 'property_rank is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Property_Rank = 'PROHIBITED' THEN
			IF NEW.property_rank IS NOT NULL THEN
				RAISE 'property_rank is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'property_utils' AND type = 'function' AND object IN ('validate_property');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc validate_property failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_property_utils']);
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('property_utils', 'validate_val_property');
DROP FUNCTION IF EXISTS property_utils.validate_val_property ( new jazzhands.val_property );
CREATE OR REPLACE FUNCTION property_utils.validate_val_property(new jazzhands.val_property)
 RETURNS jazzhands.val_property
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
BEGIN
	IF NEW.property_data_type = 'json' AND NEW.property_value_json_schema IS NULL THEN
		RAISE 'property_data_type json requires a schema to be set'
			USING ERRCODE = 'invalid_parameter_value';
	ELSIF NEW.property_data_type != 'json' AND NEW.property_value_json_schema IS NOT NULL THEN
		RAISE 'property_data_type % may not have a json schema set',
			NEW.property_data_type
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NEW.account_collection_type IS NOT NULL AND
		NEW.permit_account_collection_id = 'PROHIBITED'
	THEN
		RAISE EXCEPTION 'May not set account_collection_type when PROHIBITED'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NEW.company_collection_type IS NOT NULL AND
		NEW.permit_company_collection_id = 'PROHIBITED'
	THEN
		RAISE EXCEPTION 'May not set company_collection_type when PROHIBITED'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NEW.device_collection_type IS NOT NULL AND
		NEW.permit_device_collection_id = 'PROHIBITED'
	THEN
		RAISE EXCEPTION 'May not set device_collection_type when PROHIBITED'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NEW.dns_domain_collection_type IS NOT NULL AND
		NEW.permit_dns_domain_collection_id = 'PROHIBITED'
	THEN
		RAISE EXCEPTION 'May not set dns_domain_collection_type when PROHIBITED'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NEW.layer2_network_collection_type IS NOT NULL AND
		NEW.permit_layer2_network_collection_id = 'PROHIBITED'
	THEN
		RAISE EXCEPTION 'May not set layer2_network_collection_type when PROHIBITED'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NEW.layer3_network_collection_type IS NOT NULL AND
		NEW.permit_layer3_network_collection_id = 'PROHIBITED'
	THEN
		RAISE EXCEPTION 'May not set layer3_network_collection_type when PROHIBITED'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NEW.netblock_collection_type IS NOT NULL AND
		NEW.permit_netblock_collection_id = 'PROHIBITED'
	THEN
		RAISE EXCEPTION 'May not set netblock_collection_type when PROHIBITED'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NEW.network_range_type IS NOT NULL AND
		NEW.permit_network_range_id = 'PROHIBITED'
	THEN
		RAISE EXCEPTION 'May not set network_range_collection_type when PROHIBITED'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NEW.property_name_collection_type IS NOT NULL AND
		NEW.permit_property_name_collection_id = 'PROHIBITED'
	THEN
		RAISE EXCEPTION 'May not set property_name_collection_type when PROHIBITED'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NEW.service_environment_collection_type IS NOT NULL AND
		NEW.permit_service_environment_collection_id = 'PROHIBITED'
	THEN
		RAISE EXCEPTION 'May not set service_environment_collection_type when PROHIBITED'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NEW.service_version_collection_type IS NOT NULL AND
		NEW.permit_service_version_collection_id = 'PROHIBITED'
	THEN
		RAISE EXCEPTION 'May not set service_version_collection_type when PROHIBITED'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	--

	IF NEW.property_value_account_collection_type_restriction IS NOT NULL AND
		NEW.property_data_type != 'account_collection_id'
	THEN
		RAISE EXCEPTION 'May not set property_value_account_collection_type_restriction when property_data_type is not account_collection_id'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NEW.property_value_device_collection_type_restriction IS NOT NULL AND
		NEW.property_data_type != 'device_collection_id'
	THEN
		RAISE EXCEPTION 'May not set property_value_device_collection_type_restriction when property_data_type is not device_collection_id'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NEW.property_value_netblock_collection_type_restriction IS NOT NULL AND
		NEW.property_data_type != 'netblock_collection_id'
	THEN
		RAISE EXCEPTION 'May not set property_value_netblock_collection_type_restriction when property_data_type is not netblock_collection_id'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NEW.property_value_service_version_collection_type_restriction IS NOT NULL AND
		NEW.property_data_type != 'service_version_collection_id'
	THEN
		RAISE EXCEPTION 'May not set property_value_service_version_collection_type_restriction when property_data_type is not service_version_collection_id'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	RETURN NEW;
END;
$function$
;

--
-- Process middle (non-trigger) schema rack_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_rack_utils']);
--
-- Process middle (non-trigger) schema schema_support
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_schema_support']);
--
-- Process middle (non-trigger) schema script_hooks
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_script_hooks']);
--
-- Process middle (non-trigger) schema service_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_service_manip']);
--
-- Process middle (non-trigger) schema service_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_service_utils']);
--
-- Process middle (non-trigger) schema snapshot_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_snapshot_manip']);
--
-- Process middle (non-trigger) schema time_util
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_time_util']);
--
-- Process middle (non-trigger) schema token_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_token_utils']);
--
-- Process middle (non-trigger) schema versioning_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_versioning_utils']);
--
-- Process middle (non-trigger) schema x509_hash_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_hash_manip']);
--
-- Process middle (non-trigger) schema x509_plperl_cert_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_plperl_cert_utils']);
--
-- Process middle (non-trigger) schema jazzhands_legacy
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy']);
-- Processing tables in main schema...
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Processing minor changes to private_key
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'private_key');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'private_key');
ALTER TABLE "jazzhands"."private_key" ALTER COLUMN "public_key_hash_id" SET NOT NULL;
DROP INDEX "jazzhands"."fk_pvtkey_enctype";
DROP INDEX "jazzhands"."xif2private_key";
DROP INDEX "jazzhands"."xifprivate_key_pubkey_hash";
DROP INDEX IF EXISTS "jazzhands"."xif_private_key_enc_key_id";
CREATE INDEX xif_private_key_enc_key_id ON jazzhands.private_key USING btree (encryption_key_id);
DROP INDEX IF EXISTS "jazzhands"."xif_private_key_pkhid";
CREATE INDEX xif_private_key_pkhid ON jazzhands.private_key USING btree (public_key_hash_id);
DROP INDEX IF EXISTS "jazzhands"."xif_pvtkey_enctype";
CREATE INDEX xif_pvtkey_enctype ON jazzhands.private_key USING btree (private_key_encryption_type);
ALTER TABLE private_key DROP CONSTRAINT IF EXISTS ak_private_key_public_key_hash_id;
ALTER TABLE private_key
	ADD CONSTRAINT ak_private_key_public_key_hash_id
	UNIQUE (private_key_id, public_key_hash_id);

ALTER TABLE private_key DROP CONSTRAINT IF EXISTS fk_pctkey_enctype;
ALTER TABLE private_key
	ADD CONSTRAINT fk_pctkey_enctype
	FOREIGN KEY (private_key_encryption_type) REFERENCES jazzhands.val_private_key_encryption_type(private_key_encryption_type) DEFERRABLE;

ALTER TABLE private_key DROP CONSTRAINT IF EXISTS fk_private_key_pubkey_hash;
ALTER TABLE private_key
	ADD CONSTRAINT fk_private_key_pubkey_hash
	FOREIGN KEY (public_key_hash_id) REFERENCES jazzhands.public_key_hash(public_key_hash_id) DEFERRABLE;

ALTER TABLE private_key DROP CONSTRAINT IF EXISTS fk_pvtkey_enckey_id;
ALTER TABLE private_key
	ADD CONSTRAINT fk_pvtkey_enckey_id
	FOREIGN KEY (encryption_key_id) REFERENCES jazzhands.encryption_key(encryption_key_id) DEFERRABLE;

DROP INDEX IF EXISTS "jazzhands_audit"."aud_private_key_ak_private_key_public_key_hash_id";
CREATE INDEX aud_private_key_ak_private_key_public_key_hash_id ON jazzhands_audit.private_key USING btree (private_key_id, public_key_hash_id);
select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE certificate_signing_request
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'certificate_signing_request', 'certificate_signing_request');

-- FOREIGN KEYS FROM
ALTER TABLE x509_signed_certificate DROP CONSTRAINT IF EXISTS fk_csr_pvtkeyid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.certificate_signing_request DROP CONSTRAINT IF EXISTS fk_pvtkey_csr;
ALTER TABLE jazzhands.certificate_signing_request DROP CONSTRAINT IF EXISTS fk_x509_csr_public_key_hash;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'certificate_signing_request', newobject := 'certificate_signing_request', newmap := '{"ak_cert_sign_request_pkhid":{"columns":["certificate_signing_request_id","public_key_hash_id"],"def":"UNIQUE (certificate_signing_request_id, public_key_hash_id)","deferrable":false,"deferred":false,"name":"ak_cert_sign_request_pkhid","type":"u"},"pk_certificate_signing_request":{"columns":["certificate_signing_request_id"],"def":"PRIMARY KEY (certificate_signing_request_id)","deferrable":false,"deferred":false,"name":"pk_certificate_signing_request","type":"p"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.certificate_signing_request DROP CONSTRAINT IF EXISTS pk_certificate_signing_request;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."fk_csr_pvtkeyid";
DROP INDEX IF EXISTS "jazzhands"."xif_x509_csr_public_key_hash";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_certificate_signing_request ON jazzhands.certificate_signing_request;
DROP TRIGGER IF EXISTS trigger_audit_certificate_signing_request ON jazzhands.certificate_signing_request;
DROP FUNCTION IF EXISTS perform_audit_certificate_signing_request();
DROP TRIGGER IF EXISTS trigger_csr_set_hashes ON jazzhands.certificate_signing_request;
DROP TRIGGER IF EXISTS trigger_x509_signed_pkh_csr_validate ON jazzhands.certificate_signing_request;
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands.certificate_signing_request ALTER COLUMN "certificate_signing_request_id" DROP IDENTITY;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'certificate_signing_request', tags := ARRAY['table_certificate_signing_request']);
---- BEGIN jazzhands_audit.certificate_signing_request TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'certificate_signing_request', tags := ARRAY['table_certificate_signing_request']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'certificate_signing_request', 'certificate_signing_request');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'certificate_signing_request');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.certificate_signing_request DROP CONSTRAINT IF EXISTS certificate_signing_request_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_certificate_signing_request_pk_certificate_signing_request";
DROP INDEX IF EXISTS "jazzhands_audit"."certificate_signing_request_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."certificate_signing_request_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."certificate_signing_request_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.certificate_signing_request ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.certificate_signing_request TEARDOWN


ALTER TABLE certificate_signing_request RENAME TO certificate_signing_request_v95;
ALTER TABLE jazzhands_audit.certificate_signing_request RENAME TO certificate_signing_request_v95;

CREATE TABLE jazzhands.certificate_signing_request
(
	certificate_signing_request_id	integer NOT NULL,
	friendly_name	varchar(255) NOT NULL,
	subject	varchar(255) NOT NULL,
	certificate_signing_request	text NOT NULL,
	public_key_hash_id	integer NOT NULL,
	private_key_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'certificate_signing_request', false);
ALTER TABLE certificate_signing_request
	ALTER COLUMN certificate_signing_request_id
	ADD GENERATED BY DEFAULT AS IDENTITY;

INSERT INTO certificate_signing_request (
	certificate_signing_request_id,
	friendly_name,
	subject,
	certificate_signing_request,
	public_key_hash_id,
	private_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	certificate_signing_request_id,
	friendly_name,
	subject,
	certificate_signing_request,
	public_key_hash_id,
	private_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM certificate_signing_request_v95;


INSERT INTO jazzhands_audit.certificate_signing_request (
	certificate_signing_request_id,
	friendly_name,
	subject,
	certificate_signing_request,
	public_key_hash_id,
	private_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	certificate_signing_request_id,
	friendly_name,
	subject,
	certificate_signing_request,
	public_key_hash_id,
	private_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.certificate_signing_request_v95;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.certificate_signing_request ADD CONSTRAINT ak_cert_sign_request_pkhid UNIQUE (certificate_signing_request_id, public_key_hash_id);
ALTER TABLE jazzhands.certificate_signing_request ADD CONSTRAINT pk_certificate_signing_request PRIMARY KEY (certificate_signing_request_id);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.certificate_signing_request IS 'Certificiate Signing Requests generated from public key.  This is mostly kept for posterity since its possible to generate these at-wil from the private key.';
COMMENT ON COLUMN jazzhands.certificate_signing_request.certificate_signing_request_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN jazzhands.certificate_signing_request.friendly_name IS 'human readable name for certificate.  often just the CN.';
COMMENT ON COLUMN jazzhands.certificate_signing_request.subject IS 'Textual representation of a certificate subject. Certificate subject is a part of X509 certificate specifications.  This is the full subject from the certificate.  Friendly Name provides a human readable one.';
COMMENT ON COLUMN jazzhands.certificate_signing_request.certificate_signing_request IS 'Textual representation of a certificate signing certificate';
COMMENT ON COLUMN jazzhands.certificate_signing_request.public_key_hash_id IS 'Used as a unique id that identifies hashes on the same public key.  This is primarily used to correlate private keys and x509 certicates.';
COMMENT ON COLUMN jazzhands.certificate_signing_request.private_key_id IS 'Uniquely identifies Certificate';
-- INDEXES
CREATE INDEX xif_x509_csr_pkhid ON jazzhands.certificate_signing_request USING btree (private_key_id, public_key_hash_id);
CREATE INDEX xif_x509_csr_public_key_hash ON jazzhands.certificate_signing_request USING btree (public_key_hash_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between certificate_signing_request and jazzhands.x509_signed_certificate
ALTER TABLE jazzhands.x509_signed_certificate
	ADD CONSTRAINT fk_csr_pvtkeyid
	FOREIGN KEY (certificate_signing_request_id, public_key_hash_id) REFERENCES jazzhands.certificate_signing_request(certificate_signing_request_id, public_key_hash_id) DEFERRABLE;

-- FOREIGN KEYS TO
-- consider FK certificate_signing_request and private_key
ALTER TABLE jazzhands.certificate_signing_request
	ADD CONSTRAINT fk_csr_pvtkeyid_pkhid
	FOREIGN KEY (private_key_id, public_key_hash_id) REFERENCES jazzhands.private_key(private_key_id, public_key_hash_id) DEFERRABLE;
-- consider FK certificate_signing_request and public_key_hash
ALTER TABLE jazzhands.certificate_signing_request
	ADD CONSTRAINT fk_x509_csr_public_key_hash
	FOREIGN KEY (public_key_hash_id) REFERENCES jazzhands.public_key_hash(public_key_hash_id) DEFERRABLE;

-- TRIGGERS
-- considering NEW jazzhands.set_csr_hashes
CREATE OR REPLACE FUNCTION jazzhands.set_csr_hashes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_hashes JSONB;
	_pkhid jazzhands.certificate_signing_request.public_key_hash_id%TYPE;
BEGIN
	BEGIN
		_hashes := x509_plperl_cert_utils.get_csr_hashes(NEW.certificate_signing_request);
		_pkhid := x509_hash_manip.get_or_create_public_key_hash_id(_hashes);
		IF NEW.public_key_hash_id IS NOT NULL THEN
			IF NEW.public_key_hash_id IS DISTINCT FROM _pkhid THEN
				RAISE EXCEPTION 'public_key_hash_id does not match certificate_signing_request'
				USING ERRCODE = 'data_exception';
			END IF;
		ELSE
			NEW.public_key_hash_id := _pkhid;
		END IF;
	EXCEPTION
		WHEN undefined_function OR invalid_schema_name THEN NULL;
	END;
	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.set_csr_hashes() FROM public;
CREATE TRIGGER trigger_csr_set_hashes BEFORE INSERT OR UPDATE OF certificate_signing_request, public_key_hash_id ON jazzhands.certificate_signing_request FOR EACH ROW EXECUTE FUNCTION jazzhands.set_csr_hashes();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('certificate_signing_request');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for certificate_signing_request  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'certificate_signing_request');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'certificate_signing_request');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'certificate_signing_request');
DROP TABLE IF EXISTS certificate_signing_request_v95;
DROP TABLE IF EXISTS jazzhands_audit.certificate_signing_request_v95;
-- DONE DEALING WITH TABLE certificate_signing_request (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('certificate_signing_request');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old certificate_signing_request failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('certificate_signing_request');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new certificate_signing_request failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
-- Processing minor changes to x509_signed_certificate
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'x509_signed_certificate');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'x509_signed_certificate');
ALTER TABLE "jazzhands"."x509_signed_certificate" ALTER COLUMN "public_key_hash_id" SET NOT NULL;
DROP INDEX "jazzhands"."xif3x509_signed_certificate";
DROP INDEX "jazzhands"."xif4x509_signed_certificate";
DROP INDEX "jazzhands"."xif5x509_signed_certificate";
DROP INDEX "jazzhands"."xif6x509_signed_certificate";
DROP INDEX "jazzhands"."xifx509_signed_cert_pkhash";
DROP INDEX IF EXISTS "jazzhands"."xif9x509_signed_certificate";
CREATE INDEX xif9x509_signed_certificate ON jazzhands.x509_signed_certificate USING btree (certificate_signing_request_id, public_key_hash_id);
DROP INDEX IF EXISTS "jazzhands"."xif_x509sign_pkhid";
CREATE INDEX xif_x509sign_pkhid ON jazzhands.x509_signed_certificate USING btree (public_key_hash_id);
DROP INDEX IF EXISTS "jazzhands"."xif_x509sign_pvtkeyid_pkhid";
CREATE INDEX xif_x509sign_pvtkeyid_pkhid ON jazzhands.x509_signed_certificate USING btree (private_key_id, public_key_hash_id);
DROP INDEX IF EXISTS "jazzhands"."xif_x509sign_revoke_reason";
CREATE INDEX xif_x509sign_revoke_reason ON jazzhands.x509_signed_certificate USING btree (x509_revocation_reason);
DROP INDEX IF EXISTS "jazzhands"."xif_x509sign_x509_cert_type";
CREATE INDEX xif_x509sign_x509_cert_type ON jazzhands.x509_signed_certificate USING btree (x509_certificate_type);
ALTER TABLE x509_signed_certificate
	RENAME CONSTRAINT ak_x509_cert_cert_ca_ser TO ak_x509sign_cert_ca_serial;

ALTER TABLE x509_signed_certificate
	RENAME CONSTRAINT pk_x509_certificate TO pk_x509_signed_certificate;

ALTER TABLE x509_signed_certificate DROP CONSTRAINT IF EXISTS fk_csr_pvtkeyid;
ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT fk_csr_pvtkeyid
	FOREIGN KEY (certificate_signing_request_id, public_key_hash_id) REFERENCES jazzhands.certificate_signing_request(certificate_signing_request_id, public_key_hash_id) DEFERRABLE;

ALTER TABLE x509_signed_certificate DROP CONSTRAINT IF EXISTS fk_pvtkey_x509crt;
ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT fk_pvtkey_x509crt
	FOREIGN KEY (private_key_id, public_key_hash_id) REFERENCES jazzhands.private_key(private_key_id, public_key_hash_id) DEFERRABLE;

ALTER TABLE x509_signed_certificate DROP CONSTRAINT IF EXISTS fk_x509_cert_cert;
ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT fk_x509_cert_cert
	FOREIGN KEY (signing_cert_id) REFERENCES jazzhands.x509_signed_certificate(x509_signed_certificate_id) DEFERRABLE;

ALTER TABLE x509_signed_certificate DROP CONSTRAINT IF EXISTS fk_x509_cert_revoc_reason;
ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT fk_x509_cert_revoc_reason
	FOREIGN KEY (x509_revocation_reason) REFERENCES jazzhands.val_x509_revocation_reason(x509_revocation_reason) DEFERRABLE;

ALTER TABLE x509_signed_certificate DROP CONSTRAINT IF EXISTS fk_x509_signed_cert_pkhash;
ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT fk_x509_signed_cert_pkhash
	FOREIGN KEY (public_key_hash_id) REFERENCES jazzhands.public_key_hash(public_key_hash_id) DEFERRABLE;

ALTER TABLE x509_signed_certificate DROP CONSTRAINT IF EXISTS fk_x509crtid_crttype;
ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT fk_x509crtid_crttype
	FOREIGN KEY (x509_certificate_type) REFERENCES jazzhands.val_x509_certificate_type(x509_certificate_type) DEFERRABLE;

DROP INDEX "jazzhands_audit"."aud_x509_signed_certificate_ak_x509_cert_cert_ca_ser";
DROP INDEX "jazzhands_audit"."aud_x509_signed_certificate_pk_x509_certificate";
DROP INDEX IF EXISTS "jazzhands_audit"."aud_x509_signed_certificate_ak_x509sign_cert_ca_serial";
CREATE INDEX aud_x509_signed_certificate_ak_x509sign_cert_ca_serial ON jazzhands_audit.x509_signed_certificate USING btree (signing_cert_id, x509_ca_cert_serial_number);
DROP INDEX IF EXISTS "jazzhands_audit"."aud_x509_signed_certificate_pk_x509_signed_certificate";
CREATE INDEX aud_x509_signed_certificate_pk_x509_signed_certificate ON jazzhands_audit.x509_signed_certificate USING btree (x509_signed_certificate_id);
select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE val_device_management_controller_type
-- ... renaming to val_component_management_controller_type (jazzhands))
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_device_management_controller_type', 'val_component_management_controller_type');
-- transfering grants from old object to new
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'val_device_management_controller_type', 'val_component_management_controller_type');

-- FOREIGN KEYS FROM
ALTER TABLE device_management_controller DROP CONSTRAINT IF EXISTS fk_dev_mgmt_cntrl_val_ctrl_typ;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'val_device_management_controller_type', newobject := 'val_component_management_controller_type', newmap := '{"pk_val_device_mgmt_ctrl_type":{"columns":["component_management_controller_type"],"def":"PRIMARY KEY (component_management_controller_type)","deferrable":false,"deferred":false,"name":"pk_val_device_mgmt_ctrl_type","type":"p"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_device_management_controller_type DROP CONSTRAINT IF EXISTS pk_val_device_mgmt_ctrl_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_device_management_controller_type ON jazzhands.val_device_management_controller_type;
DROP TRIGGER IF EXISTS trigger_audit_val_device_management_controller_type ON jazzhands.val_device_management_controller_type;
DROP FUNCTION IF EXISTS perform_audit_val_device_management_controller_type();
-- default sequences associations and sequences (values rebuilt at end, if needed)
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'val_device_management_controller_type', tags := ARRAY['table_val_component_management_controller_type']);
---- BEGIN jazzhands_audit.val_device_management_controller_type TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'val_device_management_controller_type', tags := ARRAY['table_val_component_management_controller_type']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'val_device_management_controller_type', 'val_component_management_controller_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'val_device_management_controller_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.val_device_management_controller_type DROP CONSTRAINT IF EXISTS val_device_management_controller_type_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_0val_device_management_controller_type_pk_val_device_mgmt_c";
DROP INDEX IF EXISTS "jazzhands_audit"."val_device_management_controller_type_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."val_device_management_controller_type_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."val_device_management_controller_type_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.val_device_management_controller_type ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.val_device_management_controller_type TEARDOWN


ALTER TABLE val_device_management_controller_type RENAME TO val_device_management_controller_type_v95;
ALTER TABLE jazzhands_audit.val_device_management_controller_type RENAME TO val_device_management_controller_type_v95;

CREATE TABLE jazzhands.val_component_management_controller_type
(
	component_management_controller_type	varchar(255) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_component_management_controller_type', false);
--# no idea what I was thinking:SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_component_management_controller_type');


-- BEGIN Manually written insert function

INSERT INTO val_component_management_controller_type (
	component_management_controller_type,		-- new column (component_management_controller_type)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	device_management_controller_type,		-- new column (component_management_controller_type)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_device_management_controller_type_v95;


INSERT INTO jazzhands_audit.val_component_management_controller_type (
	component_management_controller_type,		-- new column (component_management_controller_type)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	device_management_controller_type,		-- new column (component_management_controller_type)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_device_management_controller_type_v95;



-- END Manually written insert function

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_component_management_controller_type ADD CONSTRAINT pk_val_device_mgmt_ctrl_type PRIMARY KEY (component_management_controller_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_component_management_controller_type and jazzhands.component_management_controller
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.component_management_controller
--	ADD CONSTRAINT fk_dev_mgmt_cntrl_val_ctrl_typ
--	FOREIGN KEY (component_management_controller_type) REFERENCES jazzhands.val_component_management_controller_type(component_management_controller_type);


-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_component_management_controller_type');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_component_management_controller_type  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_component_management_controller_type');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_component_management_controller_type');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_component_management_controller_type');
DROP TABLE IF EXISTS val_device_management_controller_type_v95;
DROP TABLE IF EXISTS jazzhands_audit.val_device_management_controller_type_v95;
-- DONE DEALING WITH TABLE val_component_management_controller_type (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_device_management_controller_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old val_device_management_controller_type failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_component_management_controller_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new val_component_management_controller_type failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE device_management_controller
-- ... renaming to component_management_controller (jazzhands))
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_management_controller', 'component_management_controller');
-- transfering grants from old object to new
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'device_management_controller', 'component_management_controller');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.device_management_controller DROP CONSTRAINT IF EXISTS fk_dev_mgmt_cntrl_val_ctrl_typ;
ALTER TABLE jazzhands.device_management_controller DROP CONSTRAINT IF EXISTS fk_dev_mgmt_ctlr_dev_id;
ALTER TABLE jazzhands.device_management_controller DROP CONSTRAINT IF EXISTS fk_dvc_mgmt_ctrl_mgr_dev_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'device_management_controller', newobject := 'component_management_controller', newmap := '{"pk_component_management_controller":{"columns":["manager_component_id","component_id"],"def":"PRIMARY KEY (manager_component_id, component_id)","deferrable":false,"deferred":false,"name":"pk_component_management_controller","type":"p"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.device_management_controller DROP CONSTRAINT IF EXISTS pk_device_management_controller;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1device_management_controller";
DROP INDEX IF EXISTS "jazzhands"."xif2device_management_controller";
DROP INDEX IF EXISTS "jazzhands"."xif3device_management_controller";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_device_management_controller ON jazzhands.device_management_controller;
DROP TRIGGER IF EXISTS trigger_audit_device_management_controller ON jazzhands.device_management_controller;
DROP FUNCTION IF EXISTS perform_audit_device_management_controller();
-- default sequences associations and sequences (values rebuilt at end, if needed)
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'device_management_controller', tags := ARRAY['table_component_management_controller']);
---- BEGIN jazzhands_audit.device_management_controller TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'device_management_controller', tags := ARRAY['table_component_management_controller']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'device_management_controller', 'component_management_controller');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'device_management_controller');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.device_management_controller DROP CONSTRAINT IF EXISTS device_management_controller_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_0device_management_controller_pk_device_management_controll";
DROP INDEX IF EXISTS "jazzhands_audit"."device_management_controller_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."device_management_controller_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."device_management_controller_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.device_management_controller ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.device_management_controller TEARDOWN


ALTER TABLE device_management_controller RENAME TO device_management_controller_v95;
ALTER TABLE jazzhands_audit.device_management_controller RENAME TO device_management_controller_v95;

CREATE TABLE jazzhands.component_management_controller
(
	manager_component_id	integer NOT NULL,
	component_id	integer NOT NULL,
	component_management_controller_type	varchar(255) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'component_management_controller', false);
--# no idea what I was thinking:SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'component_management_controller');


-- BEGIN Manually written insert function

INSERT INTO component_management_controller (
	manager_component_id,		-- new column (manager_component_id)
	component_id,		-- new column (component_id)
	component_management_controller_type,		-- new column (component_management_controller_type)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	manager_component_id,		-- new column (manager_component_id)
	component_id,		-- new column (component_id)
	device_management_control_type,		-- new column (component_management_controller_type)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_management_controller_v95
	JOIN (SELECT device_id, component_id FROM
		device WHERE component_id IS NOT NULL) c  USING (device_id)
	JOIN (SELECT device_id AS manager_device_id,
		component_id AS manager_component_id
		FROM device WHERE component_id IS NOT NULL
		) mc USING (manager_device_id)
;


WITH base AS (
	SELECT device_id, component_id
	FROM (
		SELECT	device_id, component_id,
			rank() OVER (PARTITION BY device_id ORDER BY "aud#seq" DESC) as rnk
		FROM	jazzhands_audit.device
		WHERE	component_id IS NOT NULL
	) q WHERE rnk = 1
) INSERT INTO jazzhands_audit.component_management_controller (
	manager_component_id,		-- new column (manager_component_id)
	component_id,		-- new column (component_id)
	component_management_controller_type,		-- new column (component_management_controller_type)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	manager_component_id,		-- new column (manager_component_id)
	component_id,		-- new column (component_id)
	device_management_control_type,		-- new column (component_management_controller_type)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.device_management_controller_v95
	JOIN base USING (device_id)
	JOIN (SELECT device_id AS manager_device_id,
		component_id AS manager_component_id
		FROM base
		) mc USING (manager_device_id)
;



-- END Manually written insert function

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.component_management_controller ADD CONSTRAINT pk_component_management_controller PRIMARY KEY (manager_component_id, component_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif3component_management_controller ON jazzhands.component_management_controller USING btree (component_management_controller_type);
CREATE INDEX xif4component_management_controller ON jazzhands.component_management_controller USING btree (manager_component_id);
CREATE INDEX xif5component_management_controller ON jazzhands.component_management_controller USING btree (component_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK component_management_controller and component
ALTER TABLE jazzhands.component_management_controller
	ADD CONSTRAINT fk_comp_mgmt_control_component_id
	FOREIGN KEY (component_id) REFERENCES jazzhands.component(component_id) DEFERRABLE;
-- consider FK component_management_controller and component
ALTER TABLE jazzhands.component_management_controller
	ADD CONSTRAINT fk_comp_mgmt_control_component_manager_id
	FOREIGN KEY (manager_component_id) REFERENCES jazzhands.component(component_id) DEFERRABLE;
-- consider FK component_management_controller and val_component_management_controller_type
ALTER TABLE jazzhands.component_management_controller
	ADD CONSTRAINT fk_dev_mgmt_cntrl_val_ctrl_typ
	FOREIGN KEY (component_management_controller_type) REFERENCES jazzhands.val_component_management_controller_type(component_management_controller_type);

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('component_management_controller');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for component_management_controller  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'component_management_controller');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'component_management_controller');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'component_management_controller');
DROP TABLE IF EXISTS device_management_controller_v95;
DROP TABLE IF EXISTS jazzhands_audit.device_management_controller_v95;
-- DONE DEALING WITH TABLE component_management_controller (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('device_management_controller');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old device_management_controller failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('component_management_controller');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new component_management_controller failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
-- Processing minor changes to netblock
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'netblock');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'netblock');
DROP INDEX "jazzhands"."idx_netblk_netblkstatus";
DROP INDEX "jazzhands"."ix_netblk_ip_address_parent";
DROP INDEX "jazzhands"."xif6netblock";
DROP INDEX "jazzhands"."xif7netblock";
DROP INDEX IF EXISTS "jazzhands"."xif_netblock_ip_address_parent";
CREATE INDEX xif_netblock_ip_address_parent ON jazzhands.netblock USING btree (parent_netblock_id);
DROP INDEX IF EXISTS "jazzhands"."xif_netblock_ip_universe_id";
CREATE INDEX xif_netblock_ip_universe_id ON jazzhands.netblock USING btree (ip_universe_id);
DROP INDEX IF EXISTS "jazzhands"."xif_netblock_netblock_type";
CREATE INDEX xif_netblock_netblock_type ON jazzhands.netblock USING btree (netblock_type);
DROP INDEX IF EXISTS "jazzhands"."xif_netblock_status";
CREATE INDEX xif_netblock_status ON jazzhands.netblock USING btree (netblock_status);
ALTER TABLE netblock DROP CONSTRAINT IF EXISTS ak_netblock_id_parent_netblock_id;
ALTER TABLE netblock
	ADD CONSTRAINT ak_netblock_id_parent_netblock_id
	UNIQUE (netblock_id, parent_netblock_id);

DROP INDEX IF EXISTS "jazzhands_audit"."aud_netblock_ak_netblock_id_parent_netblock_id";
CREATE INDEX aud_netblock_ak_netblock_id_parent_netblock_id ON jazzhands_audit.netblock USING btree (netblock_id, parent_netblock_id);
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Processing minor changes to layer3_network
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'layer3_network');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'layer3_network');
DROP INDEX IF EXISTS "jazzhands"."xif_l3net_netblock_defgw_parent_netblock";
CREATE INDEX xif_l3net_netblock_defgw_parent_netblock ON jazzhands.layer3_network USING btree (default_gateway_netblock_id, netblock_id);
select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE val_property
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property', 'val_property');

-- FOREIGN KEYS FROM
ALTER TABLE property_name_collection_property_name DROP CONSTRAINT IF EXISTS fk_prop_col_propnamtyp;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_nmtyp;
ALTER TABLE val_property_value DROP CONSTRAINT IF EXISTS fk_valproval_namtyp;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_prop_svcemvcoll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_prop_val_devcol_typ_rstr_dc;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_prop_val_devcoll_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_acct_coll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_comp_coll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_l2netype;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_l3netwok_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_nblk_coll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_pv_svc_version_collection_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_svc_version_collection_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_property_dnsdomcolltype;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_property_netblkcolltype;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_property_val_propcolltype;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valnetrng_val_prop;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_propdttyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_proptyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_pv_actyp_rst;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands', object := 'val_property', newobject := 'val_property', newmap := '{"pk_val_property":{"columns":["property_name","property_type"],"def":"PRIMARY KEY (property_name, property_type)","deferrable":false,"deferred":false,"name":"pk_val_property","type":"p"}}');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS pk_val_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif10val_property";
DROP INDEX IF EXISTS "jazzhands"."xif12val_property";
DROP INDEX IF EXISTS "jazzhands"."xif13val_property";
DROP INDEX IF EXISTS "jazzhands"."xif14val_property";
DROP INDEX IF EXISTS "jazzhands"."xif15val_property";
DROP INDEX IF EXISTS "jazzhands"."xif1val_property";
DROP INDEX IF EXISTS "jazzhands"."xif2val_property";
DROP INDEX IF EXISTS "jazzhands"."xif3val_property";
DROP INDEX IF EXISTS "jazzhands"."xif4val_property";
DROP INDEX IF EXISTS "jazzhands"."xif5val_property";
DROP INDEX IF EXISTS "jazzhands"."xif6val_property";
DROP INDEX IF EXISTS "jazzhands"."xif7val_property";
DROP INDEX IF EXISTS "jazzhands"."xif8val_property";
DROP INDEX IF EXISTS "jazzhands"."xif9val_property";
DROP INDEX IF EXISTS "jazzhands"."xifval_prop_pv_svc_version_collection_type";
DROP INDEX IF EXISTS "jazzhands"."xifval_prop_svc_version_collection_type";
DROP INDEX IF EXISTS "jazzhands"."xifval_property_val_propcolltype";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1034200204;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1063245312;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1279907540;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1315394496;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1430936437;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1430936438;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_151657048;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1581934381;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1987241427;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1994384843;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2002842082;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2070965452;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_439888051;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_504174938;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_618591244;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_733000589;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_842506143;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_osid;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_property ON jazzhands.val_property;
DROP TRIGGER IF EXISTS trigger_audit_val_property ON jazzhands.val_property;
DROP FUNCTION IF EXISTS perform_audit_val_property();
DROP TRIGGER IF EXISTS trigger_validate_val_property ON jazzhands.val_property;
DROP TRIGGER IF EXISTS trigger_validate_val_property_after ON jazzhands.val_property;
-- default sequences associations and sequences (values rebuilt at end, if needed)
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'val_property', tags := ARRAY['table_val_property']);
---- BEGIN jazzhands_audit.val_property TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'val_property', tags := ARRAY['table_val_property']);
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_audit', 'val_property', 'val_property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'val_property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.val_property DROP CONSTRAINT IF EXISTS val_property_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_val_property_pk_val_property";
DROP INDEX IF EXISTS "jazzhands_audit"."val_property_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."val_property_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."val_property_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.val_property ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.val_property TEARDOWN


ALTER TABLE val_property RENAME TO val_property_v95;
ALTER TABLE jazzhands_audit.val_property RENAME TO val_property_v95;

CREATE TABLE jazzhands.val_property
(
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	account_collection_type	varchar(50)  NULL,
	company_collection_type	varchar(50)  NULL,
	device_collection_type	varchar(50)  NULL,
	dns_domain_collection_type	varchar(50)  NULL,
	layer2_network_collection_type	varchar(50)  NULL,
	layer3_network_collection_type	varchar(50)  NULL,
	netblock_collection_type	varchar(50)  NULL,
	network_range_type	varchar(50)  NULL,
	property_name_collection_type	varchar(50)  NULL,
	service_environment_collection_type	varchar(50)  NULL,
	service_version_collection_type	varchar(255)  NULL,
	is_multivalue	boolean NOT NULL,
	property_value_account_collection_type_restriction	varchar(50)  NULL,
	property_value_device_collection_type_restriction	varchar(50)  NULL,
	property_value_netblock_collection_type_restriction	varchar(50)  NULL,
	property_value_service_version_collection_type_restriction	varchar(255)  NULL,
	property_data_type	varchar(50) NOT NULL,
	property_value_json_schema	jsonb  NULL,
	permit_account_collection_id	character(10) NOT NULL,
	permit_account_id	character(10) NOT NULL,
	permit_account_realm_id	character(10) NOT NULL,
	permit_company_id	character(10) NOT NULL,
	permit_company_collection_id	character(10) NOT NULL,
	permit_device_collection_id	character(10) NOT NULL,
	permit_dns_domain_collection_id	character(10) NOT NULL,
	permit_layer2_network_collection_id	character(10) NOT NULL,
	permit_layer3_network_collection_id	character(10) NOT NULL,
	permit_netblock_collection_id	character(10) NOT NULL,
	permit_network_range_id	character(10) NOT NULL,
	permit_operating_system_id	character(10) NOT NULL,
	permit_operating_system_snapshot_id	character(10) NOT NULL,
	permit_property_name_collection_id	character(10) NOT NULL,
	permit_service_environment_collection_id	character(10) NOT NULL,
	permit_service_version_collection_id	character(10) NOT NULL,
	permit_site_code	character(10) NOT NULL,
	permit_x509_signed_certificate_id	character(10) NOT NULL,
	permit_property_rank	character(10) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_property', false);
ALTER TABLE val_property
	ALTER is_multivalue
	SET DEFAULT false;
ALTER TABLE val_property
	ALTER permit_account_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_realm_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_company_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_company_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_network_range_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_operating_system_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_operating_system_snapshot_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_name_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_service_environment_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_service_version_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_x509_signed_certificate_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;

INSERT INTO val_property (
	property_name,
	property_type,
	description,
	account_collection_type,
	company_collection_type,
	device_collection_type,
	dns_domain_collection_type,
	layer2_network_collection_type,
	layer3_network_collection_type,
	netblock_collection_type,
	network_range_type,
	property_name_collection_type,
	service_environment_collection_type,
	service_version_collection_type,
	is_multivalue,
	property_value_account_collection_type_restriction,
	property_value_device_collection_type_restriction,
	property_value_netblock_collection_type_restriction,
	property_value_service_version_collection_type_restriction,		-- new column (property_value_service_version_collection_type_restriction)
	property_data_type,
	property_value_json_schema,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_collection_id,
	permit_layer2_network_collection_id,
	permit_layer3_network_collection_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_operating_system_snapshot_id,
	permit_property_name_collection_id,
	permit_service_environment_collection_id,
	permit_service_version_collection_id,
	permit_site_code,
	permit_x509_signed_certificate_id,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_name,
	property_type,
	description,
	account_collection_type,
	company_collection_type,
	device_collection_type,
	dns_domain_collection_type,
	layer2_network_collection_type,
	layer3_network_collection_type,
	netblock_collection_type,
	network_range_type,
	property_name_collection_type,
	service_environment_collection_type,
	service_version_collection_type,
	is_multivalue,
	property_value_account_collection_type_restriction,
	property_value_device_collection_type_restriction,
	property_value_netblock_collection_type_restriction,
	NULL,		-- new column (property_value_service_version_collection_type_restriction)
	property_data_type,
	property_value_json_schema,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_collection_id,
	permit_layer2_network_collection_id,
	permit_layer3_network_collection_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_operating_system_snapshot_id,
	permit_property_name_collection_id,
	permit_service_environment_collection_id,
	permit_service_version_collection_id,
	permit_site_code,
	permit_x509_signed_certificate_id,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_property_v95;


INSERT INTO jazzhands_audit.val_property (
	property_name,
	property_type,
	description,
	account_collection_type,
	company_collection_type,
	device_collection_type,
	dns_domain_collection_type,
	layer2_network_collection_type,
	layer3_network_collection_type,
	netblock_collection_type,
	network_range_type,
	property_name_collection_type,
	service_environment_collection_type,
	service_version_collection_type,
	is_multivalue,
	property_value_account_collection_type_restriction,
	property_value_device_collection_type_restriction,
	property_value_netblock_collection_type_restriction,
	property_value_service_version_collection_type_restriction,		-- new column (property_value_service_version_collection_type_restriction)
	property_data_type,
	property_value_json_schema,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_collection_id,
	permit_layer2_network_collection_id,
	permit_layer3_network_collection_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_operating_system_snapshot_id,
	permit_property_name_collection_id,
	permit_service_environment_collection_id,
	permit_service_version_collection_id,
	permit_site_code,
	permit_x509_signed_certificate_id,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	property_name,
	property_type,
	description,
	account_collection_type,
	company_collection_type,
	device_collection_type,
	dns_domain_collection_type,
	layer2_network_collection_type,
	layer3_network_collection_type,
	netblock_collection_type,
	network_range_type,
	property_name_collection_type,
	service_environment_collection_type,
	service_version_collection_type,
	is_multivalue,
	property_value_account_collection_type_restriction,
	property_value_device_collection_type_restriction,
	property_value_netblock_collection_type_restriction,
	NULL,		-- new column (property_value_service_version_collection_type_restriction)
	property_data_type,
	property_value_json_schema,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_collection_id,
	permit_layer2_network_collection_id,
	permit_layer3_network_collection_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_operating_system_snapshot_id,
	permit_property_name_collection_id,
	permit_service_environment_collection_id,
	permit_service_version_collection_id,
	permit_site_code,
	permit_x509_signed_certificate_id,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_property_v95;

ALTER TABLE jazzhands.val_property
	ALTER is_multivalue
	SET DEFAULT false;
ALTER TABLE jazzhands.val_property
	ALTER permit_account_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_account_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_account_realm_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_company_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_company_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_dns_domain_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_layer2_network_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_layer3_network_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_network_range_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_operating_system_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_operating_system_snapshot_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_property_name_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_service_environment_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_service_version_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_x509_signed_certificate_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands.val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_property ADD CONSTRAINT pk_val_property PRIMARY KEY (property_name, property_type);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.val_property IS 'valid values and attributes for (name,type) pairs in the property table.  This defines how triggers enforce aspects of the property table';
COMMENT ON COLUMN jazzhands.val_property.property_name IS 'property name for validation purposes';
COMMENT ON COLUMN jazzhands.val_property.property_type IS 'property type for validation purposes';
COMMENT ON COLUMN jazzhands.val_property.account_collection_type IS 'type restriction of the account_collection_id on LHS';
COMMENT ON COLUMN jazzhands.val_property.company_collection_type IS 'type restriction of company_collection_id on LHS';
COMMENT ON COLUMN jazzhands.val_property.device_collection_type IS 'type restriction of device_collection_id on LHS';
COMMENT ON COLUMN jazzhands.val_property.dns_domain_collection_type IS 'type restriction of dns_domain_collection_id restriction on LHS';
COMMENT ON COLUMN jazzhands.val_property.netblock_collection_type IS 'type restriction of netblock_collection_id on LHS';
COMMENT ON COLUMN jazzhands.val_property.property_name_collection_type IS 'type restriction of property_collection_id on LHS';
COMMENT ON COLUMN jazzhands.val_property.service_environment_collection_type IS 'type restriction of service_enviornment_collection_id on LHS';
COMMENT ON COLUMN jazzhands.val_property.is_multivalue IS 'If N, acts like an alternate key on property.(lhs,property_name,property_type)';
COMMENT ON COLUMN jazzhands.val_property.property_value_account_collection_type_restriction IS 'if property_value is account_collection_Id, this limits the account_collection_types that can be used in that column.';
COMMENT ON COLUMN jazzhands.val_property.property_value_device_collection_type_restriction IS 'if property_value is devicet_collection_Id, this limits the devicet_collection_types that can be used in that column.';
COMMENT ON COLUMN jazzhands.val_property.property_value_netblock_collection_type_restriction IS 'if property_value isnetblockt_collection_Id, this limits the netblockt_collection_types that can be used in that column.';
COMMENT ON COLUMN jazzhands.val_property.property_data_type IS 'which, if any, of the property_table_* columns should be used for this value.   May turn more complex enforcement via trigger';
COMMENT ON COLUMN jazzhands.val_property.permit_account_collection_id IS 'defines permissibility/requirement of account_collection_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_account_id IS 'defines permissibility/requirement of account_idon LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_account_realm_id IS 'defines permissibility/requirement of account_realm_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_company_id IS 'defines permissibility/requirement of company_id on LHS of property.  *NOTE*  THIS COLUMN WILL BE REMOVED IN >0.65';
COMMENT ON COLUMN jazzhands.val_property.permit_company_collection_id IS 'defines permissibility/requirement of company_collection_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_device_collection_id IS 'defines permissibility/requirement of device_collection_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_dns_domain_collection_id IS 'defines permissibility/requirement of dns_domain_collection_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_layer2_network_collection_id IS 'defines permissibility/requirement of layer2_network_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_layer3_network_collection_id IS 'defines permissibility/requirement of layer3_network_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_netblock_collection_id IS 'defines permissibility/requirement of netblock_collection_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_operating_system_id IS 'defines permissibility/requirement of operating_system_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_operating_system_snapshot_id IS 'defines permissibility/requirement of operating_system_snapshot_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_property_name_collection_id IS 'defines permissibility/requirement of property_collection_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_service_environment_collection_id IS 'defines permissibility/requirement of service_env_collection_id on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_site_code IS 'defines permissibility/requirement of site_code on LHS of property';
COMMENT ON COLUMN jazzhands.val_property.permit_property_rank IS 'defines permissibility of property_rank, and if it should be part of the "lhs" of the given property';
-- INDEXES
CREATE INDEX xif10val_property ON jazzhands.val_property USING btree (netblock_collection_type);
CREATE INDEX xif12val_property ON jazzhands.val_property USING btree (service_environment_collection_type);
CREATE INDEX xif13val_property ON jazzhands.val_property USING btree (layer3_network_collection_type);
CREATE INDEX xif14val_property ON jazzhands.val_property USING btree (layer2_network_collection_type);
CREATE INDEX xif15val_property ON jazzhands.val_property USING btree (network_range_type);
CREATE INDEX xif1val_property ON jazzhands.val_property USING btree (property_data_type);
CREATE INDEX xif2val_property ON jazzhands.val_property USING btree (property_type);
CREATE INDEX xif3val_property ON jazzhands.val_property USING btree (property_value_account_collection_type_restriction);
CREATE INDEX xif4val_property ON jazzhands.val_property USING btree (property_value_netblock_collection_type_restriction);
CREATE INDEX xif5val_property ON jazzhands.val_property USING btree (property_value_device_collection_type_restriction);
CREATE INDEX xif6val_property ON jazzhands.val_property USING btree (account_collection_type);
CREATE INDEX xif7val_property ON jazzhands.val_property USING btree (company_collection_type);
CREATE INDEX xif8val_property ON jazzhands.val_property USING btree (device_collection_type);
CREATE INDEX xif9val_property ON jazzhands.val_property USING btree (dns_domain_collection_type);
CREATE INDEX xifval_prop_pv_svc_version_collection_type ON jazzhands.val_property USING btree (property_value_service_version_collection_type_restriction);
CREATE INDEX xifval_prop_svc_version_collection_type ON jazzhands.val_property USING btree (service_version_collection_type);
CREATE INDEX xifval_property_val_propcolltype ON jazzhands.val_property USING btree (property_name_collection_type);

-- CHECK CONSTRAINTS
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_1034200204
	CHECK ((permit_account_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_1063245312
	CHECK ((permit_property_rank = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_1279907540
	CHECK ((permit_service_environment_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_1315394496
	CHECK ((permit_operating_system_snapshot_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_1430936437
	CHECK ((permit_layer2_network_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_1430936438
	CHECK ((permit_layer3_network_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_151657048
	CHECK ((permit_account_realm_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_1581934381
	CHECK ((permit_property_name_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_1987241427
	CHECK ((permit_account_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_1994384843
	CHECK ((permit_netblock_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_2002842082
	CHECK ((permit_company_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_2070965452
	CHECK ((permit_device_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_439888051
	CHECK ((permit_dns_domain_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_504174938
	CHECK ((permit_network_range_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_618591244
	CHECK ((permit_x509_signed_certificate_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_733000589
	CHECK ((permit_company_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT check_prp_prmt_842506143
	CHECK ((permit_site_code = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT ckc_json_schema_only_for_json_835572742
	CHECK ((((property_value_json_schema IS NULL) AND ((property_data_type)::text <> 'json'::text)) OR ((property_value_json_schema IS NOT NULL) AND ((property_data_type)::text = 'json'::text))));
ALTER TABLE jazzhands.val_property ADD CONSTRAINT ckc_val_prop_osid
	CHECK ((permit_operating_system_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar])));

-- FOREIGN KEYS FROM
-- consider FK between val_property and jazzhands.property_name_collection_property_name
ALTER TABLE jazzhands.property_name_collection_property_name
	ADD CONSTRAINT fk_prop_col_propnamtyp
	FOREIGN KEY (property_name, property_type) REFERENCES jazzhands.val_property(property_name, property_type);
-- consider FK between val_property and jazzhands.property
ALTER TABLE jazzhands.property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES jazzhands.val_property(property_name, property_type);
-- consider FK between val_property and jazzhands.val_property_value
ALTER TABLE jazzhands.val_property_value
	ADD CONSTRAINT fk_valproval_namtyp
	FOREIGN KEY (property_name, property_type) REFERENCES jazzhands.val_property(property_name, property_type);

-- FOREIGN KEYS TO
-- consider FK val_property and val_service_environment_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_prop_svcemvcoll_type
	FOREIGN KEY (service_environment_collection_type) REFERENCES jazzhands.val_service_environment_collection_type(service_environment_collection_type);
-- consider FK val_property and val_device_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_prop_val_devcol_typ_rstr_dc
	FOREIGN KEY (property_value_device_collection_type_restriction) REFERENCES jazzhands.val_device_collection_type(device_collection_type);
-- consider FK val_property and val_device_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_prop_val_devcoll_id
	FOREIGN KEY (device_collection_type) REFERENCES jazzhands.val_device_collection_type(device_collection_type);
-- consider FK val_property and val_account_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_prop_acct_coll_type
	FOREIGN KEY (account_collection_type) REFERENCES jazzhands.val_account_collection_type(account_collection_type);
-- consider FK val_property and val_company_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_prop_comp_coll_type
	FOREIGN KEY (company_collection_type) REFERENCES jazzhands.val_company_collection_type(company_collection_type);
-- consider FK val_property and val_layer2_network_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_prop_l2netype
	FOREIGN KEY (layer2_network_collection_type) REFERENCES jazzhands.val_layer2_network_collection_type(layer2_network_collection_type);
-- consider FK val_property and val_layer3_network_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_prop_l3netwok_type
	FOREIGN KEY (layer3_network_collection_type) REFERENCES jazzhands.val_layer3_network_collection_type(layer3_network_collection_type);
-- consider FK val_property and val_netblock_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_prop_nblk_coll_type
	FOREIGN KEY (property_value_netblock_collection_type_restriction) REFERENCES jazzhands.val_netblock_collection_type(netblock_collection_type);
-- consider FK val_property and val_service_version_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_prop_pv_svc_version_collection_type
	FOREIGN KEY (property_value_service_version_collection_type_restriction) REFERENCES jazzhands.val_service_version_collection_type(service_version_collection_type);
-- consider FK val_property and val_service_version_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_prop_svc_version_collection_type
	FOREIGN KEY (service_version_collection_type) REFERENCES jazzhands.val_service_version_collection_type(service_version_collection_type);
-- consider FK val_property and val_dns_domain_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_property_dnsdomcolltype
	FOREIGN KEY (dns_domain_collection_type) REFERENCES jazzhands.val_dns_domain_collection_type(dns_domain_collection_type);
-- consider FK val_property and val_netblock_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_property_netblkcolltype
	FOREIGN KEY (netblock_collection_type) REFERENCES jazzhands.val_netblock_collection_type(netblock_collection_type);
-- consider FK val_property and val_property_name_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_val_property_val_propcolltype
	FOREIGN KEY (property_name_collection_type) REFERENCES jazzhands.val_property_name_collection_type(property_name_collection_type);
-- consider FK val_property and val_network_range_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_valnetrng_val_prop
	FOREIGN KEY (network_range_type) REFERENCES jazzhands.val_network_range_type(network_range_type);
-- consider FK val_property and val_property_data_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_valprop_propdttyp
	FOREIGN KEY (property_data_type) REFERENCES jazzhands.val_property_data_type(property_data_type);
-- consider FK val_property and val_property_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_valprop_proptyp
	FOREIGN KEY (property_type) REFERENCES jazzhands.val_property_type(property_type);
-- consider FK val_property and val_account_collection_type
ALTER TABLE jazzhands.val_property
	ADD CONSTRAINT fk_valprop_pv_actyp_rst
	FOREIGN KEY (property_value_account_collection_type_restriction) REFERENCES jazzhands.val_account_collection_type(account_collection_type);

-- TRIGGERS
-- considering NEW jazzhands.validate_val_property
CREATE OR REPLACE FUNCTION jazzhands.validate_val_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN

	PERFORM property_utils.validate_val_property(NEW);

	IF TG_OP = 'UPDATE' AND OLD.property_data_type != NEW.property_data_type THEN
		SELECT	count(*)
		INTO	_tally
		FROM	property
		WHERE	property_name = NEW.property_name
		AND		property_type = NEW.property_type;

		IF _tally > 0  THEN
			RAISE 'May not change property type if there are existing properties'
				USING ERRCODE = 'foreign_key_violation';

		END IF;
	END IF;

	IF TG_OP = 'INSERT' AND NEW.permit_company_id != 'PROHIBITED' OR
		( TG_OP = 'UPDATE' AND NEW.permit_company_id != 'PROHIBITED' AND
			OLD.permit_company_id IS DISTINCT FROM NEW.permit_company_id )
	THEN
		RAISE 'property.company_id is being retired.  Please use per-company collections'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.validate_val_property() FROM public;
CREATE TRIGGER trigger_validate_val_property BEFORE INSERT OR UPDATE OF property_data_type, property_value_json_schema, permit_company_id ON jazzhands.val_property FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_val_property();

-- considering NEW jazzhands.validate_val_property_after
CREATE OR REPLACE FUNCTION jazzhands.validate_val_property_after()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_r	property%ROWTYPE;
BEGIN
	FOR _r IN SELECT * FROM property
		WHERE property_name = NEW.property_name
		AND property_type = NEW.property_type
	LOOP
		PERFORM property_utils.validate_property(_r);
	END LOOP;
	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.validate_val_property_after() FROM public;
CREATE CONSTRAINT TRIGGER trigger_validate_val_property_after AFTER UPDATE ON jazzhands.val_property DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_val_property_after();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_property');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_property  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_property');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_property');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_property');
DROP TABLE IF EXISTS val_property_v95;
DROP TABLE IF EXISTS jazzhands_audit.val_property_v95;
-- DONE DEALING WITH TABLE val_property (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_property');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old val_property failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_property');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new val_property failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE device_management_controller
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'device_management_controller', 'device_management_controller');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'audit', object := 'device_management_controller', tags := ARRAY['view_device_management_controller']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS audit.device_management_controller;
CREATE VIEW audit.device_management_controller AS
 WITH p AS NOT MATERIALIZED (
         SELECT q.device_id,
            q.component_id
           FROM ( SELECT device.device_id,
                    device.component_id,
                    rank() OVER (PARTITION BY device.device_id ORDER BY device."aud#timestamp" DESC) AS rnk
                   FROM jazzhands_audit.device
                  WHERE device.component_id IS NOT NULL) q
          WHERE q.rnk = 1
        )
 SELECT md.manager_device_id,
    d.device_id,
    c.component_management_controller_type AS device_mgmt_control_type,
    c.description,
    c.data_ins_user,
    c.data_ins_date,
    c.data_upd_user,
    c.data_upd_date,
    c."aud#action",
    c."aud#timestamp",
    c."aud#realtime",
    c."aud#txid",
    c."aud#user",
    c."aud#seq"
   FROM jazzhands_audit.component_management_controller c
     JOIN ( SELECT p.device_id,
            p.component_id
           FROM p) d USING (component_id)
     JOIN ( SELECT p.device_id AS manager_device_id,
            p.component_id AS manager_component_id
           FROM p) md USING (manager_component_id);

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'audit' AND type = 'view' AND object IN ('device_management_controller','device_management_controller');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of device_management_controller failed but that is ok';
	NULL;
END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'audit' AND object IN ('device_management_controller');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for device_management_controller  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_management_controller (audit)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('device_management_controller');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old device_management_controller failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('device_management_controller');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new device_management_controller failed but that is ok';
	NULL;
END;
$$;

--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE val_device_mgmt_ctrl_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_device_mgmt_ctrl_type', 'val_device_mgmt_ctrl_type');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'audit', object := 'val_device_mgmt_ctrl_type', tags := ARRAY['view_val_device_mgmt_ctrl_type']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS audit.val_device_mgmt_ctrl_type;
CREATE VIEW audit.val_device_mgmt_ctrl_type AS
 SELECT val_component_management_controller_type.component_management_controller_type AS device_mgmt_control_type,
    val_component_management_controller_type.description,
    val_component_management_controller_type.data_ins_user,
    val_component_management_controller_type.data_ins_date,
    val_component_management_controller_type.data_upd_user,
    val_component_management_controller_type.data_upd_date,
    val_component_management_controller_type."aud#action",
    val_component_management_controller_type."aud#timestamp",
    val_component_management_controller_type."aud#realtime",
    val_component_management_controller_type."aud#txid",
    val_component_management_controller_type."aud#user",
    val_component_management_controller_type."aud#seq"
   FROM jazzhands_audit.val_component_management_controller_type;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'audit' AND type = 'view' AND object IN ('val_device_mgmt_ctrl_type','val_device_mgmt_ctrl_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of val_device_mgmt_ctrl_type failed but that is ok';
	NULL;
END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'audit' AND object IN ('val_device_mgmt_ctrl_type');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_device_mgmt_ctrl_type  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_device_mgmt_ctrl_type (audit)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('val_device_mgmt_ctrl_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old val_device_mgmt_ctrl_type failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('val_device_mgmt_ctrl_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new val_device_mgmt_ctrl_type failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE device_management_controller (jazzhands)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'device_management_controller');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_audit', 'device_management_controller');
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands.device_management_controller;
CREATE VIEW jazzhands.device_management_controller AS
 SELECT md.manager_device_id,
    d.device_id,
    c.component_management_controller_type AS device_management_control_type,
    c.description,
    c.data_ins_user,
    c.data_ins_date,
    c.data_upd_user,
    c.data_upd_date
   FROM jazzhands.component_management_controller c
     JOIN ( SELECT device.device_id,
            device.component_id
           FROM jazzhands.device) d USING (component_id)
     JOIN ( SELECT device.device_id AS manager_device_id,
            device.component_id AS manager_component_id
           FROM jazzhands.device) md USING (manager_component_id);

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object IN ('device_management_controller','device_management_controller');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of device_management_controller failed but that is ok';
	NULL;
END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- considering NEW jazzhands.device_management_controller_del
CREATE OR REPLACE FUNCTION jazzhands.device_management_controller_del()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_c			jazzhands.component_management_controller.component_id%TYPE;
	_mc			jazzhands.component_management_controller.component_id%TYPE;
	_cmc		jazzhands.component_management_controller%ROWTYPE;
BEGIN
	SELECT	component_id
	INTO	_c
	FROM	device
	WHERE	device_id = OLD.device_id;

	SELECT	component_id
	INTO	_mc
	FROM	device
	WHERE	device_id = OLD.manager_device_id;

	DELETE FROM component_management_controller
	WHERE component_id IS NOT DISTINCT FROM  _c
	AND manager_component_id IS NOT DISTINCT FROM _mc
	RETURNING * INTO _cmc;

	OLD.device_mgmt_control_type	= _cmc.component_management_controller_type;
	OLD.description					= _cmc.description;

	OLD.data_ins_user := _cmc.data_ins_user;
	OLD.data_ins_date := _cmc.data_ins_date;
	OLD.data_upd_user := _cmc.data_upd_user;
	OLD.data_upd_date := _cmc.data_upd_date;

	RETURN OLD;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.device_management_controller_del() FROM public;
CREATE TRIGGER trigger_device_management_controller_del INSTEAD OF DELETE ON jazzhands.device_management_controller FOR EACH ROW EXECUTE FUNCTION jazzhands.device_management_controller_del();

-- considering NEW jazzhands.device_management_controller_ins
CREATE OR REPLACE FUNCTION jazzhands.device_management_controller_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_c		jazzhands.component_management_controller.component_id%TYPE;
	_mc		jazzhands.component_management_controller.component_id%TYPE;
	_cmc	jazzhands.component_management_controller%ROWTYPE;
BEGIN
	SELECT	component_id
	INTO	_c
	FROM	device
	WHERE	device_id IS NOT DISTINCT FROM NEW.device_id;

	IF _c IS NULL THEN
			RAISE EXCEPTION 'device_id may not be NULL or there is no component associated with the device.'
			USING ERRCODE = 'not_null_violation';
	END IF;

	SELECT	component_id
	INTO	_mc
	FROM	device
	WHERE	device_id IS NOT DISTINCT FROM NEW.manager_device_id;

	IF _mc IS NULL THEN
			RAISE EXCEPTION 'manager_device_id may not be NULL or there is no component associated with the device.'
			USING ERRCODE = 'not_null_violation';
	END IF;

	INSERT INTO component_management_controller (
		manager_component_id, component_id,
		component_management_controller_type, description
	) VALUES (
		_mc, _c,
		NEW.device_mgmt_control_type, NEW.description
	) RETURNING * INTO _cmc;

	NEW.data_ins_user := _cmc.data_ins_user;
	NEW.data_ins_date := _cmc.data_ins_date;
	NEW.data_upd_user := _cmc.data_upd_user;
	NEW.data_upd_date := _cmc.data_upd_date;

	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.device_management_controller_ins() FROM public;
CREATE TRIGGER trigger_device_management_controller_ins INSTEAD OF INSERT ON jazzhands.device_management_controller FOR EACH ROW EXECUTE FUNCTION jazzhands.device_management_controller_ins();

-- considering NEW jazzhands.device_management_controller_upd
CREATE OR REPLACE FUNCTION jazzhands.device_management_controller_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	upd_query	TEXT[];
	_c			jazzhands.component_management_controller.component_id%TYPE;
	_oc			jazzhands.component_management_controller.component_id%TYPE;
	_omc		jazzhands.component_management_controller.component_id%TYPE;
	_cmc		jazzhands.component_management_controller%ROWTYPE;
BEGIN
	upd_query := NULL;
	IF OLD.device_id IS DISTINCT FROM NEW.device_id THEN
		SELECT	component_id
		INTO	_c
		FROM	device
		WHERE	device_id IS NOT DISTINCT FROM NEW.device_id;

		IF _c IS NULL THEN
				RAISE EXCEPTION 'device_id may not be NULL or there is no component associated with the device.'
				USING ERRCODE = 'not_null_violation';
		END IF;

		upd_query := array_append(upd_query,
			'component_id = ' || quote_nullable(_c));
	END IF;

	IF OLD.manager_device_id IS DISTINCT FROM NEW.manager_device_id THEN
		SELECT	component_id
		INTO	_c
		FROM	device
		WHERE	device_id IS NOT DISTINCT FROM NEW.manager_device_id;

		IF _c IS NULL THEN
				RAISE EXCEPTION 'manager_device_id may not be NULL or there is no component associated with the device.'
				USING ERRCODE = 'not_null_violation';
		END IF;

		upd_query := array_append(upd_query,
			'manager_component_id = ' || quote_nullable(_c));
	END IF;

	IF NEW.description IS DISTINCT FROM OLD.description THEN
		upd_query := array_append(upd_query,
		'description = ' || quote_nullable(NEW.description));
	END IF;

	IF NEW.device_mgmt_control_type IS DISTINCT FROM OLD.device_mgmt_control_type THEN
		upd_query := array_append(upd_query,
		'component_management_controller_type = ' || quote_nullable(NEW.device_mgmt_control_type));
	END IF;

	IF upd_query IS NOT NULL THEN
		SELECT component_id INTO _cmc.component_id
		FROM device WHERE device_id = OLD.device_id;

		SELECT component_id INTO _cmc.manager_component_id
		FROM device WHERE device_id = OLD.manager_device_id;

		EXECUTE 'UPDATE component_management_controller SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE component_id = $1 AND manager_component_id = $2 RETURNING *'
			USING _cmc.component_id, _cmc.manager_component_id
			INTO _cmc;

		NEW.device_mgmt_control_type	= _cmc.component_management_controller_type;
	  	NEW.description					= _cmc.description;

		NEW.data_ins_user := _cmc.data_ins_user;
		NEW.data_ins_date := _cmc.data_ins_date;
		NEW.data_upd_user := _cmc.data_upd_user;
		NEW.data_upd_date := _cmc.data_upd_date;
	END IF;

	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.device_management_controller_upd() FROM public;
CREATE TRIGGER trigger_device_management_controller_upd INSTEAD OF UPDATE ON jazzhands.device_management_controller FOR EACH ROW EXECUTE FUNCTION jazzhands.device_management_controller_upd();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('device_management_controller');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for device_management_controller  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_management_controller (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('device_management_controller');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old device_management_controller failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('device_management_controller');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new device_management_controller failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
select clock_timestamp(), clock_timestamp() - now() AS len;
--
-- Process all procs in jazzhands_cache
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_cache']);
--
-- Process all procs in account_collection_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_collection_manip']);
--
-- Process all procs in account_password_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_account_password_manip']);
--
-- Process all procs in approval_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_approval_utils']);
--
-- Process all procs in audit
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_audit']);
--
-- Process all procs in auto_ac_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_auto_ac_manip']);
--
-- Process all procs in backend_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_backend_utils']);
--
-- Process all procs in company_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_company_manip']);
--
-- Process all procs in component_connection_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_connection_utils']);
--
-- Process all procs in component_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_manip']);
--
-- Process all procs in component_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_utils']);
--
-- Process all procs in device_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_manip']);
--
-- Process all procs in device_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_utils']);
--
-- Process all procs in dns_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_manip']);
--
-- Process all procs in dns_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_utils']);
--
-- Process all procs in jazzhands
--
select clock_timestamp(), clock_timestamp() - now() AS len;
DROP TRIGGER IF EXISTS trigger_pvtkey_pkh_signed_validate ON jazzhands.private_key;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands'::text, object := 'pvtkey_pkh_signed_validate (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands'::text]);
DROP FUNCTION IF EXISTS jazzhands.pvtkey_pkh_signed_validate (  );
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'service_environment_ins');
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_ins');
CREATE OR REPLACE FUNCTION jazzhands.service_environment_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_se	service_environment%ROWTYPE;
BEGIN
	IF NEW.service_environment_id IS NOT NULL THEN
		INSERT INTO service_environment (
				service_environment_id,
       		service_environment_name,
       		service_environment_type,
       		production_state,
       		description,
       		external_id
		) VALUES (
				NEW.service_environment_id,
       		NEW.service_environment_name,
       		'default',
       		NEW.production_state,
       		NEW.description,
       		NEW.external_id
		) RETURNING * INTO _se;
	ELSE
		INSERT INTO service_environment (
       		service_environment_name,
       		service_environment_type,
       		production_state,
       		description,
       		external_id
		) VALUES (
       		NEW.service_environment_name,
       		'default',
       		NEW.production_state,
       		NEW.description,
       		NEW.external_id
		) RETURNING * INTO _se;

	END IF;

	NEW.service_environment_id		:= _se.service_environment_id;
	NEW.service_environment_name	:= _se.service_environment_name;
	NEW.production_state			:= _se.production_state;
	NEW.description					:= _se.description;
	NEW.external_id					:= _se.external_id;
	NEW.data_ins_user				:= _se.data_ins_user;
	NEW.data_ins_date				:= _se.data_ins_date;
	NEW.data_upd_user				:= _se.data_upd_user;
	NEW.data_upd_date				:= _se.data_upd_date;

	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('service_environment_ins');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc service_environment_ins failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'service_environment_upd');
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_upd');
CREATE OR REPLACE FUNCTION jazzhands.service_environment_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	upd_query		TEXT[];
	_se			service_environment%ROWTYPE;
BEGIN
	IF OLD.service_environment_id IS DISTINCT FROM NEW.service_environment_id THEN
		RAISE EXCEPTION 'May not update service_environment_id'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	upd_query := NULL;
	IF NEW.service_environment_name IS DISTINCT FROM OLD.service_environment_name THEN
		upd_query := array_append(upd_query,
			'service_environment_name = ' || quote_nullable(NEW.service_environment_name));
	END IF;
	IF NEW.production_state IS DISTINCT FROM OLD.production_state THEN
		upd_query := array_append(upd_query,
			'production_state = ' || quote_nullable(NEW.production_state));
	END IF;
	IF NEW.description IS DISTINCT FROM OLD.description THEN
		upd_query := array_append(upd_query,
			'description = ' || quote_nullable(NEW.description));
	END IF;
	IF NEW.external_id IS DISTINCT FROM OLD.external_id THEN
		upd_query := array_append(upd_query,
			'external_id = ' || quote_nullable(NEW.external_id));
	END IF;

	IF upd_query IS NOT NULL THEN
		EXECUTE 'UPDATE service_environment SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE service_environment_id = $1 RETURNING *'
		USING OLD.service_environment_id
		INTO _se;

		NEW.service_environment_id		:= _se.service_environment_id;
		NEW.service_environment_name	:= _se.service_environment_name;
		NEW.production_state			:= _se.production_state;
		NEW.description					:= _se.description;
		NEW.external_id					:= _se.external_id;
		NEW.data_ins_user				:= _se.data_ins_user;
		NEW.data_ins_date				:= _se.data_ins_date;
		NEW.data_upd_user				:= _se.data_upd_user;
		NEW.data_upd_date				:= _se.data_upd_date;
	END IF;

	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('service_environment_upd');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc service_environment_upd failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'validate_val_property');
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_val_property');
CREATE OR REPLACE FUNCTION jazzhands.validate_val_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN

	PERFORM property_utils.validate_val_property(NEW);

	IF TG_OP = 'UPDATE' AND OLD.property_data_type != NEW.property_data_type THEN
		SELECT	count(*)
		INTO	_tally
		FROM	property
		WHERE	property_name = NEW.property_name
		AND		property_type = NEW.property_type;

		IF _tally > 0  THEN
			RAISE 'May not change property type if there are existing properties'
				USING ERRCODE = 'foreign_key_violation';

		END IF;
	END IF;

	IF TG_OP = 'INSERT' AND NEW.permit_company_id != 'PROHIBITED' OR
		( TG_OP = 'UPDATE' AND NEW.permit_company_id != 'PROHIBITED' AND
			OLD.permit_company_id IS DISTINCT FROM NEW.permit_company_id )
	THEN
		RAISE 'property.company_id is being retired.  Please use per-company collections'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('validate_val_property');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc validate_val_property failed but that is ok';
	NULL;
END;
$$;

DROP TRIGGER IF EXISTS trigger_x509_signed_pkh_csr_validate ON jazzhands.certificate_signing_request;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands'::text, object := 'x509_signed_pkh_csr_validate (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands'::text]);
DROP FUNCTION IF EXISTS jazzhands.x509_signed_pkh_csr_validate (  );
DROP TRIGGER IF EXISTS trigger_x509_signed_pkh_pvtkey_validate ON jazzhands.x509_signed_certificate;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands'::text, object := 'x509_signed_pkh_pvtkey_validate (  )'::text, tags := ARRAY['process_all_procs_in_schema_jazzhands'::text]);
DROP FUNCTION IF EXISTS jazzhands.x509_signed_pkh_pvtkey_validate (  );
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands']);
-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.device_management_controller_del()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_c			jazzhands.component_management_controller.component_id%TYPE;
	_mc			jazzhands.component_management_controller.component_id%TYPE;
	_cmc		jazzhands.component_management_controller%ROWTYPE;
BEGIN
	SELECT	component_id
	INTO	_c
	FROM	device
	WHERE	device_id = OLD.device_id;

	SELECT	component_id
	INTO	_mc
	FROM	device
	WHERE	device_id = OLD.manager_device_id;

	DELETE FROM component_management_controller
	WHERE component_id IS NOT DISTINCT FROM  _c
	AND manager_component_id IS NOT DISTINCT FROM _mc
	RETURNING * INTO _cmc;

	OLD.device_mgmt_control_type	= _cmc.component_management_controller_type;
	OLD.description					= _cmc.description;

	OLD.data_ins_user := _cmc.data_ins_user;
	OLD.data_ins_date := _cmc.data_ins_date;
	OLD.data_upd_user := _cmc.data_upd_user;
	OLD.data_upd_date := _cmc.data_upd_date;

	RETURN OLD;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.device_management_controller_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_c		jazzhands.component_management_controller.component_id%TYPE;
	_mc		jazzhands.component_management_controller.component_id%TYPE;
	_cmc	jazzhands.component_management_controller%ROWTYPE;
BEGIN
	SELECT	component_id
	INTO	_c
	FROM	device
	WHERE	device_id IS NOT DISTINCT FROM NEW.device_id;

	IF _c IS NULL THEN
			RAISE EXCEPTION 'device_id may not be NULL or there is no component associated with the device.'
			USING ERRCODE = 'not_null_violation';
	END IF;

	SELECT	component_id
	INTO	_mc
	FROM	device
	WHERE	device_id IS NOT DISTINCT FROM NEW.manager_device_id;

	IF _mc IS NULL THEN
			RAISE EXCEPTION 'manager_device_id may not be NULL or there is no component associated with the device.'
			USING ERRCODE = 'not_null_violation';
	END IF;

	INSERT INTO component_management_controller (
		manager_component_id, component_id,
		component_management_controller_type, description
	) VALUES (
		_mc, _c,
		NEW.device_mgmt_control_type, NEW.description
	) RETURNING * INTO _cmc;

	NEW.data_ins_user := _cmc.data_ins_user;
	NEW.data_ins_date := _cmc.data_ins_date;
	NEW.data_upd_user := _cmc.data_upd_user;
	NEW.data_upd_date := _cmc.data_upd_date;

	RETURN NEW;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.device_management_controller_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	upd_query	TEXT[];
	_c			jazzhands.component_management_controller.component_id%TYPE;
	_oc			jazzhands.component_management_controller.component_id%TYPE;
	_omc		jazzhands.component_management_controller.component_id%TYPE;
	_cmc		jazzhands.component_management_controller%ROWTYPE;
BEGIN
	upd_query := NULL;
	IF OLD.device_id IS DISTINCT FROM NEW.device_id THEN
		SELECT	component_id
		INTO	_c
		FROM	device
		WHERE	device_id IS NOT DISTINCT FROM NEW.device_id;

		IF _c IS NULL THEN
				RAISE EXCEPTION 'device_id may not be NULL or there is no component associated with the device.'
				USING ERRCODE = 'not_null_violation';
		END IF;

		upd_query := array_append(upd_query,
			'component_id = ' || quote_nullable(_c));
	END IF;

	IF OLD.manager_device_id IS DISTINCT FROM NEW.manager_device_id THEN
		SELECT	component_id
		INTO	_c
		FROM	device
		WHERE	device_id IS NOT DISTINCT FROM NEW.manager_device_id;

		IF _c IS NULL THEN
				RAISE EXCEPTION 'manager_device_id may not be NULL or there is no component associated with the device.'
				USING ERRCODE = 'not_null_violation';
		END IF;

		upd_query := array_append(upd_query,
			'manager_component_id = ' || quote_nullable(_c));
	END IF;

	IF NEW.description IS DISTINCT FROM OLD.description THEN
		upd_query := array_append(upd_query,
		'description = ' || quote_nullable(NEW.description));
	END IF;

	IF NEW.device_mgmt_control_type IS DISTINCT FROM OLD.device_mgmt_control_type THEN
		upd_query := array_append(upd_query,
		'component_management_controller_type = ' || quote_nullable(NEW.device_mgmt_control_type));
	END IF;

	IF upd_query IS NOT NULL THEN
		SELECT component_id INTO _cmc.component_id
		FROM device WHERE device_id = OLD.device_id;

		SELECT component_id INTO _cmc.manager_component_id
		FROM device WHERE device_id = OLD.manager_device_id;

		EXECUTE 'UPDATE component_management_controller SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE component_id = $1 AND manager_component_id = $2 RETURNING *'
			USING _cmc.component_id, _cmc.manager_component_id
			INTO _cmc;

		NEW.device_mgmt_control_type	= _cmc.component_management_controller_type;
	  	NEW.description					= _cmc.description;

		NEW.data_ins_user := _cmc.data_ins_user;
		NEW.data_ins_date := _cmc.data_ins_date;
		NEW.data_upd_user := _cmc.data_upd_user;
		NEW.data_upd_date := _cmc.data_upd_date;
	END IF;

	RETURN NEW;
END;
$function$
;

--
-- Process all procs in layerx_network_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_layerx_network_manip']);
--
-- Process all procs in logical_port_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_logical_port_manip']);
--
-- Process all procs in lv_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_lv_manip']);
--
-- Process all procs in net_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_net_manip']);
--
-- Process all procs in netblock_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_manip']);
--
-- Process all procs in netblock_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_netblock_utils']);
--
-- Process all procs in network_strings
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_network_strings']);
--
-- Process all procs in obfuscation_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_obfuscation_utils']);
--
-- Process all procs in person_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_person_manip']);
--
-- Process all procs in pgcrypto
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_pgcrypto']);
--
-- Process all procs in physical_address_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_physical_address_utils']);
--
-- Process all procs in port_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_port_utils']);
--
-- Process all procs in property_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_property_utils']);
--
-- Process all procs in rack_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_rack_utils']);
--
-- Process all procs in schema_support
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_schema_support']);
--
-- Process all procs in script_hooks
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_script_hooks']);
--
-- Process all procs in service_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_service_manip']);
--
-- Process all procs in service_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_service_utils']);
--
-- Process all procs in snapshot_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_snapshot_manip']);
--
-- Process all procs in time_util
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_time_util']);
--
-- Process all procs in token_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_token_utils']);
--
-- Process all procs in versioning_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_versioning_utils']);
--
-- Process all procs in x509_hash_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_hash_manip']);
--
-- Process all procs in x509_plperl_cert_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_plperl_cert_utils']);
--
-- Recreate the saved views in the base schema
--
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', type := 'view');


-- BEGIN Misc that does not apply to above
-- migration process did not find this, so doing by hand.
ALTER TABLE ONLY jazzhands.layer3_network
	ADD CONSTRAINT fk_l3net_netblock_defgw_parent_netblock FOREIGN KEY (default_gateway_netblock_id, netblock_id)
	REFERENCES jazzhands.netblock(netblock_id, parent_netblock_id);

--
-- this should be polled, but stuff 'n things.
--
ALTER TABLE asset ADD CONSTRAINT ckc_only_leased_has_expiration_138754876 
	CHECK ((((lease_expiration_date IS NULL) AND ((ownership_status) <> 'leased')) OR ((ownership_status) = 'leased')));

SELECT schema_support.set_schema_version(
	version := '0.95',
	schema := 'jazzhands'
);

--
-- there may be a bug.
--
DELETE FROM jazzhands_cache.ct_jazzhands_legacy_device_support WHERE device_id
IN (
	SELECT device_id FROM (
		select * from
		jazzhands_cache.v_jazzhands_legacy_device_support
		except (
			select *
			from jazzhands_cache.ct_jazzhands_legacy_device_support
		)
	) i
);


-- END Misc that does not apply to above
--
-- BEGIN: process_ancillary_schema(jazzhands_legacy)
--
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE device_management_controller
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'device_management_controller', 'device_management_controller');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'device_management_controller', tags := ARRAY['view_device_management_controller']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.device_management_controller;
CREATE VIEW jazzhands_legacy.device_management_controller AS
 SELECT md.manager_device_id,
    d.device_id,
    c.component_management_controller_type AS device_mgmt_control_type,
    c.description,
    c.data_ins_user,
    c.data_ins_date,
    c.data_upd_user,
    c.data_upd_date
   FROM jazzhands.component_management_controller c
     JOIN ( SELECT device.device_id,
            device.component_id
           FROM jazzhands.device) d USING (component_id)
     JOIN ( SELECT device.device_id AS manager_device_id,
            device.component_id AS manager_component_id
           FROM jazzhands.device) md USING (manager_component_id);

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('device_management_controller','device_management_controller');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of device_management_controller failed but that is ok';
	NULL;
END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- considering NEW jazzhands.device_management_controller_del
CREATE OR REPLACE FUNCTION jazzhands.device_management_controller_del()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_c			jazzhands.component_management_controller.component_id%TYPE;
	_mc			jazzhands.component_management_controller.component_id%TYPE;
	_cmc		jazzhands.component_management_controller%ROWTYPE;
BEGIN
	SELECT	component_id
	INTO	_c
	FROM	device
	WHERE	device_id = OLD.device_id;

	SELECT	component_id
	INTO	_mc
	FROM	device
	WHERE	device_id = OLD.manager_device_id;

	DELETE FROM component_management_controller
	WHERE component_id IS NOT DISTINCT FROM  _c
	AND manager_component_id IS NOT DISTINCT FROM _mc
	RETURNING * INTO _cmc;

	OLD.device_mgmt_control_type	= _cmc.component_management_controller_type;
	OLD.description					= _cmc.description;

	OLD.data_ins_user := _cmc.data_ins_user;
	OLD.data_ins_date := _cmc.data_ins_date;
	OLD.data_upd_user := _cmc.data_upd_user;
	OLD.data_upd_date := _cmc.data_upd_date;

	RETURN OLD;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.device_management_controller_del() FROM public;
CREATE TRIGGER trigger_device_management_controller_del INSTEAD OF DELETE ON jazzhands_legacy.device_management_controller FOR EACH ROW EXECUTE FUNCTION jazzhands.device_management_controller_del();

-- considering NEW jazzhands.device_management_controller_ins
CREATE OR REPLACE FUNCTION jazzhands.device_management_controller_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_c		jazzhands.component_management_controller.component_id%TYPE;
	_mc		jazzhands.component_management_controller.component_id%TYPE;
	_cmc	jazzhands.component_management_controller%ROWTYPE;
BEGIN
	SELECT	component_id
	INTO	_c
	FROM	device
	WHERE	device_id IS NOT DISTINCT FROM NEW.device_id;

	IF _c IS NULL THEN
			RAISE EXCEPTION 'device_id may not be NULL or there is no component associated with the device.'
			USING ERRCODE = 'not_null_violation';
	END IF;

	SELECT	component_id
	INTO	_mc
	FROM	device
	WHERE	device_id IS NOT DISTINCT FROM NEW.manager_device_id;

	IF _mc IS NULL THEN
			RAISE EXCEPTION 'manager_device_id may not be NULL or there is no component associated with the device.'
			USING ERRCODE = 'not_null_violation';
	END IF;

	INSERT INTO component_management_controller (
		manager_component_id, component_id,
		component_management_controller_type, description
	) VALUES (
		_mc, _c,
		NEW.device_mgmt_control_type, NEW.description
	) RETURNING * INTO _cmc;

	NEW.data_ins_user := _cmc.data_ins_user;
	NEW.data_ins_date := _cmc.data_ins_date;
	NEW.data_upd_user := _cmc.data_upd_user;
	NEW.data_upd_date := _cmc.data_upd_date;

	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.device_management_controller_ins() FROM public;
CREATE TRIGGER trigger_device_management_controller_ins INSTEAD OF INSERT ON jazzhands_legacy.device_management_controller FOR EACH ROW EXECUTE FUNCTION jazzhands.device_management_controller_ins();

-- considering NEW jazzhands.device_management_controller_upd
CREATE OR REPLACE FUNCTION jazzhands.device_management_controller_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	upd_query	TEXT[];
	_c			jazzhands.component_management_controller.component_id%TYPE;
	_oc			jazzhands.component_management_controller.component_id%TYPE;
	_omc		jazzhands.component_management_controller.component_id%TYPE;
	_cmc		jazzhands.component_management_controller%ROWTYPE;
BEGIN
	upd_query := NULL;
	IF OLD.device_id IS DISTINCT FROM NEW.device_id THEN
		SELECT	component_id
		INTO	_c
		FROM	device
		WHERE	device_id IS NOT DISTINCT FROM NEW.device_id;

		IF _c IS NULL THEN
				RAISE EXCEPTION 'device_id may not be NULL or there is no component associated with the device.'
				USING ERRCODE = 'not_null_violation';
		END IF;

		upd_query := array_append(upd_query,
			'component_id = ' || quote_nullable(_c));
	END IF;

	IF OLD.manager_device_id IS DISTINCT FROM NEW.manager_device_id THEN
		SELECT	component_id
		INTO	_c
		FROM	device
		WHERE	device_id IS NOT DISTINCT FROM NEW.manager_device_id;

		IF _c IS NULL THEN
				RAISE EXCEPTION 'manager_device_id may not be NULL or there is no component associated with the device.'
				USING ERRCODE = 'not_null_violation';
		END IF;

		upd_query := array_append(upd_query,
			'manager_component_id = ' || quote_nullable(_c));
	END IF;

	IF NEW.description IS DISTINCT FROM OLD.description THEN
		upd_query := array_append(upd_query,
		'description = ' || quote_nullable(NEW.description));
	END IF;

	IF NEW.device_mgmt_control_type IS DISTINCT FROM OLD.device_mgmt_control_type THEN
		upd_query := array_append(upd_query,
		'component_management_controller_type = ' || quote_nullable(NEW.device_mgmt_control_type));
	END IF;

	IF upd_query IS NOT NULL THEN
		SELECT component_id INTO _cmc.component_id
		FROM device WHERE device_id = OLD.device_id;

		SELECT component_id INTO _cmc.manager_component_id
		FROM device WHERE device_id = OLD.manager_device_id;

		EXECUTE 'UPDATE component_management_controller SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE component_id = $1 AND manager_component_id = $2 RETURNING *'
			USING _cmc.component_id, _cmc.manager_component_id
			INTO _cmc;

		NEW.device_mgmt_control_type	= _cmc.component_management_controller_type;
	  	NEW.description					= _cmc.description;

		NEW.data_ins_user := _cmc.data_ins_user;
		NEW.data_ins_date := _cmc.data_ins_date;
		NEW.data_upd_user := _cmc.data_upd_user;
		NEW.data_upd_date := _cmc.data_upd_date;
	END IF;

	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.device_management_controller_upd() FROM public;
CREATE TRIGGER trigger_device_management_controller_upd INSTEAD OF UPDATE ON jazzhands_legacy.device_management_controller FOR EACH ROW EXECUTE FUNCTION jazzhands.device_management_controller_upd();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('device_management_controller');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for device_management_controller  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE device_management_controller (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('device_management_controller');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old device_management_controller failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('device_management_controller');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new device_management_controller failed but that is ok';
	NULL;
END;
$$;

--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE val_device_mgmt_ctrl_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands_legacy', 'val_device_mgmt_ctrl_type', 'val_device_mgmt_ctrl_type');
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'val_device_mgmt_ctrl_type', tags := ARRAY['view_val_device_mgmt_ctrl_type']);
-- restore any missing random views that may be cached that this one needs.
DROP VIEW IF EXISTS jazzhands_legacy.val_device_mgmt_ctrl_type;
CREATE VIEW jazzhands_legacy.val_device_mgmt_ctrl_type AS
 SELECT val_component_management_controller_type.component_management_controller_type AS device_mgmt_control_type,
    val_component_management_controller_type.description,
    val_component_management_controller_type.data_ins_user,
    val_component_management_controller_type.data_ins_date,
    val_component_management_controller_type.data_upd_user,
    val_component_management_controller_type.data_upd_date
   FROM jazzhands.val_component_management_controller_type;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object IN ('val_device_mgmt_ctrl_type','val_device_mgmt_ctrl_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of val_device_mgmt_ctrl_type failed but that is ok';
	NULL;
END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND object IN ('val_device_mgmt_ctrl_type');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_device_mgmt_ctrl_type  failed but that is ok';
		NULL;
END;
$$;

-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_device_mgmt_ctrl_type (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('val_device_mgmt_ctrl_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of old val_device_mgmt_ctrl_type failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('val_device_mgmt_ctrl_type');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of new val_device_mgmt_ctrl_type failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy']);
-- DONE: process_ancillary_schema(jazzhands_legacy)
--
-- BEGIN: Fix cache table entries.
--
-- removing old
-- adding new cache tables that are not there
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled
	) SELECT 'jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  WHERE ('jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled
	) SELECT 'jazzhands_cache' , 'ct_device_components' , 'jazzhands_cache' , 'v_device_components' , '1'  WHERE ('jazzhands_cache' , 'ct_device_components' , 'jazzhands_cache' , 'v_device_components' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled
	) SELECT 'jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  WHERE ('jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled
	) SELECT 'jazzhands_cache' , 'ct_account_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_account_collection_hier_from_ancestor' , '1'  WHERE ('jazzhands_cache' , 'ct_account_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_account_collection_hier_from_ancestor' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled
	) SELECT 'jazzhands_cache' , 'ct_device_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_device_collection_hier_from_ancestor' , '1'  WHERE ('jazzhands_cache' , 'ct_device_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_device_collection_hier_from_ancestor' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled
	) SELECT 'jazzhands_cache' , 'ct_netblock_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_netblock_collection_hier_from_ancestor' , '1'  WHERE ('jazzhands_cache' , 'ct_netblock_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_netblock_collection_hier_from_ancestor' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled
	) SELECT 'jazzhands_cache' , 'ct_jazzhands_legacy_device_support' , 'jazzhands_cache' , 'v_jazzhands_legacy_device_support' , '1'  WHERE ('jazzhands_cache' , 'ct_jazzhands_legacy_device_support' , 'jazzhands_cache' , 'v_jazzhands_legacy_device_support' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
--
-- DONE: Fix cache table entries.
--


-- Clean Up

--
-- BEGIN: Procesing things saved for end
--
SAVEPOINT beforerecreate;

--
-- END: Procesing things saved for end
--

SELECT schema_support.replay_object_recreates(beverbose := true);
SELECT schema_support.replay_saved_grants(beverbose := true);

--
-- BEGIN: Running final cache table sync
SAVEPOINT beforecache;
SELECT schema_support.synchronize_cache_tables();

--
-- END: Running final cache table sync
SAVEPOINT beforereset;
SELECT schema_support.reset_all_schema_table_sequences('jazzhands');
SELECT schema_support.reset_all_schema_table_sequences('jazzhands_audit');
SAVEPOINT beforegrant;


-- BEGIN final checks

UPDATE val_property
SET device_collection_type = 'JazzHandsLegacySupport-AutoMgmtProtocol',
	property_value_device_collection_type_restriction = NULL
WHERE property_name = 'AutoMgmtProtocol'
AND property_type = 'JazzHandsLegacySupport';

SELECT property_utils.validate_val_property(v)
FROM val_property v;


-- END final checks
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT insert,update,delete on all tables in schema jazzhands_legacy to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
GRANT select on all tables in schema jazzhands_audit to ro_role;
GRANT select on all sequences in schema jazzhands_audit to ro_role;
GRANT select on all tables in schema jazzhands_audit to ro_role;
GRANT select on all sequences in schema jazzhands_audit to ro_role;
-- schema_support changes.  schema_owners needs to be documented somewhere
GRANT execute on all functions in schema schema_support to schema_owners;
REVOKE execute on all functions in schema schema_support from public;

SELECT schema_support.end_maintenance();
SAVEPOINT maintend;
select clock_timestamp(), now(), clock_timestamp() - now() AS len;
