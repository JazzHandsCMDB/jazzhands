--
-- Copyright (c) 2017 Todd Kover
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

/*
Invoked:

	--col-default=dns_domain_name:soa_name
	--col-default=ip_namespace:'default'
	--post
	post
	--pre
	pre
	--suffix=v79
	--first=mv_unix_group_mappings
	--first=mv_unix_passwd_mappings
	--first=v_property
	--first=ip_universe
	--reinsert-dir=i
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();


-- BEGIN Misc that does not apply to above
-- changing argument names
DROP FUNCTION device_utils.monitoring_off_in_rack(integer);
DROP FUNCTION device_utils.retire_rack(integer);

-- the order of this matters, so just make it die early as its
-- eventually recreated
-- SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_domain_nouniverse');
-- SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dns_domain_nouniverse');
-- DROP VIEW IF EXISTS v_dns_domain_nouniverse;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_changes_pending');
DROP VIEW IF EXISTS v_dns_changes_pending;

DROP MATERIALIZED VIEW IF EXISTS mv_unix_passwd_mappings;
DROP MATERIALIZED VIEW IF EXISTS mv_unix_group_mappings;


-- END Misc that does not apply to above
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'layerx_network_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS layerx_network_manip;
		CREATE SCHEMA layerx_network_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA layerx_network_manip IS 'part of jazzhands';
	END IF;
END;
			$$;--
-- Process middle (non-trigger) schema jazzhands
--
--
-- Process middle (non-trigger) schema net_manip
--
--
-- Process middle (non-trigger) schema network_strings
--
--
-- Process middle (non-trigger) schema time_util
--
--
-- Process middle (non-trigger) schema dns_utils
--
-- New function
CREATE OR REPLACE FUNCTION dns_utils.add_dns_domain(soa_name character varying, dns_domain_type character varying DEFAULT NULL::character varying, ip_universes integer[] DEFAULT NULL::integer[], add_nameservers boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	elements		text[];
	parent_zone		text;
	parent_id		dns_domain.dns_domain_id%type;
	domain_id		dns_domain.dns_domain_id%type;
	elem			text;
	sofar			text;
	rvs_nblk_id		netblock.netblock_id%type;
	univ			ip_universe.ip_universe_id%type;
BEGIN
	IF soa_name IS NULL THEN
		RETURN NULL;
	END IF;
	elements := regexp_split_to_array(soa_name, '\.');
	sofar := '';
	FOREACH elem in ARRAY elements
	LOOP
		IF octet_length(sofar) > 0 THEN
			sofar := sofar || '.';
		END IF;
		sofar := sofar || elem;
		parent_zone := regexp_replace(soa_name, '^'||sofar||'.', '');
		EXECUTE 'SELECT dns_domain_id FROM dns_domain 
			WHERE soa_name = $1' INTO parent_id USING soa_name;
		IF parent_id IS NOT NULL THEN
			EXIT;
		END IF;
	END LOOP;

	IF ip_universes IS NULL THEN
		SELECT array_agg(ip_universe_id) 
		INTO	ip_universes
		FROM	ip_universe
		WHERE	ip_universe_name = 'default';
	END IF;

	IF dns_domain_type IS NULL THEN
		IF soa_name ~ '^.*(in-addr|ip6)\.arpa$' THEN
			dns_domain_type := 'reverse';
		END IF;
	END IF;

	IF dns_domain_type IS NULL THEN
		RAISE EXCEPTION 'Unable to guess dns_domain_type for %',
			soa_name USING ERRCODE = 'not_null_violation'; 
	END IF;

	EXECUTE '
		INSERT INTO dns_domain (
			soa_name,
			parent_dns_domain_id,
			dns_domain_type
		) VALUES (
			$1,
			$2,
			$3
		) RETURNING dns_domain_id' INTO domain_id 
		USING soa_name, 
			parent_id,
			dns_domain_type
	;

	FOREACH univ IN ARRAY ip_universes
	LOOP
		EXECUTE '
			INSERT INTO dns_domain_ip_universe (
				dns_domain_id,
				ip_universe_id,
				soa_class,
				soa_mname,
				soa_rname,
				should_generate
			) VALUES (
				$1,
				$2,
				$3,
				$4,
				$5,
				$6
			);'
			USING domain_id, univ,
				'IN',
				(select property_value from property 
					where property_type = 'Defaults'
					and property_name = '_dnsmname' ORDER BY property_id LIMIT 1),
				(select property_value from property 
					where property_type = 'Defaults'
					and property_name = '_dnsrname' ORDER BY property_id LIMIT 1),
				'Y'
		;
	END LOOP;

	IF dns_domain_type = 'reverse' THEN
		rvs_nblk_id := dns_utils.get_or_create_rvs_netblock_link(
			soa_name, domain_id);
	END IF;

	IF add_nameservers THEN
		PERFORM dns_utils.add_ns_records(domain_id);
	END IF;

	RETURN domain_id;
END;
$function$
;

--
-- Process middle (non-trigger) schema person_manip
--
--
-- Process middle (non-trigger) schema auto_ac_manip
--
--
-- Process middle (non-trigger) schema company_manip
--
--
-- Process middle (non-trigger) schema token_utils
--
--
-- Process middle (non-trigger) schema port_support
--
--
-- Process middle (non-trigger) schema port_utils
--
--
-- Process middle (non-trigger) schema device_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'purge_l1_connection_from_port');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.purge_l1_connection_from_port ( _in_portid integer );
CREATE OR REPLACE FUNCTION device_utils.purge_l1_connection_from_port(_in_portid integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'purge_physical_path');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.purge_physical_path ( _in_l1c integer );
CREATE OR REPLACE FUNCTION device_utils.purge_physical_path(_in_l1c integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'purge_physical_ports');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.purge_physical_ports ( _in_devid integer );
CREATE OR REPLACE FUNCTION device_utils.purge_physical_ports(_in_devid integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'retire_device');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.retire_device ( in_device_id integer, retire_modules boolean );
CREATE OR REPLACE FUNCTION device_utils.retire_device(in_device_id integer, retire_modules boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION device_utils.monitoring_off_in_rack(rack_id integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION device_utils.remove_network_interface(network_interface_id integer DEFAULT NULL::integer, device_id integer DEFAULT NULL::integer, network_interface_name character varying DEFAULT NULL::character varying)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION device_utils.remove_network_interfaces(network_interface_id_list integer[])
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION device_utils.retire_devices(device_id_list integer[])
 RETURNS TABLE(device_id integer, success boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
					voe_symbolic_track_id = NULL,
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION device_utils.retire_rack(rack_id integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM device_utils.retire_racks(
		rack_id_list := ARRAY[ rack_id ]
	);
	RETURN true;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION device_utils.retire_racks(rack_id_list integer[])
 RETURNS TABLE(rack_id integer, success boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

--
-- Process middle (non-trigger) schema netblock_utils
--
--
-- Process middle (non-trigger) schema netblock_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock ( parent_netblock_id integer, netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying );
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS SETOF netblock
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	netblock_rec	RECORD;
BEGIN
	RETURN QUERY
		SELECT * into netblock_rec FROM netblock_manip.allocate_netblock(
		parent_netblock_list := ARRAY[parent_netblock_id],
		netmask_bits := netmask_bits,
		address_type := address_type,
		can_subnet := can_subnet,
		description := description,
		allocation_method := allocation_method,
		ip_address := ip_address,
		rnd_masklen_threshold := rnd_masklen_threshold,
		rnd_max_count := rnd_max_count,
		netblock_status := netblock_status
	);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock ( parent_netblock_list integer[], netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying );
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS SETOF netblock
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	parent_rec		RECORD;
	netblock_rec	RECORD;
	inet_rec		RECORD;
	loopback_bits	integer;
	inet_family		integer;
	ip_addr			ALIAS FOR ip_address;
BEGIN
	IF parent_netblock_list IS NULL THEN
		RAISE 'parent_netblock_list must be specified'
		USING ERRCODE = 'null_value_not_allowed';
	END IF;

	IF address_type NOT IN ('netblock', 'single', 'loopback') THEN
		RAISE 'address_type must be one of netblock, single, or loopback'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF netmask_bits IS NULL AND address_type = 'netblock' THEN
		RAISE EXCEPTION
			'You must specify a netmask when address_type is netblock'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF ip_address IS NOT NULL THEN
		SELECT
			array_agg(netblock_id)
		INTO
			parent_netblock_list
		FROM
			netblock n
		WHERE
			ip_addr <<= n.ip_address AND
			netblock_id = ANY(parent_netblock_list);

		IF parent_netblock_list IS NULL THEN
			RETURN;
		END IF;
	END IF;

	-- Lock the parent row, which should keep parallel processes from
	-- trying to obtain the same address

	FOR parent_rec IN SELECT * FROM jazzhands.netblock WHERE netblock_id =
			ANY(allocate_netblock.parent_netblock_list) ORDER BY netblock_id
			FOR UPDATE LOOP

		IF parent_rec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'parent_netblock_id refers to a single_address netblock'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF inet_family IS NULL THEN
			inet_family := family(parent_rec.ip_address);
		ELSIF inet_family != family(parent_rec.ip_address)
				AND ip_address IS NULL THEN
			RAISE EXCEPTION 'Allocation may not mix IPv4 and IPv6 addresses'
			USING ERRCODE = 'JH10F';
		END IF;

		IF address_type = 'loopback' THEN
			loopback_bits :=
				CASE WHEN
					family(parent_rec.ip_address) = 4 THEN 32 ELSE 128 END;

			IF parent_rec.can_subnet = 'N' THEN
				RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
					USING ERRCODE = 'JH10B';
			END IF;
		ELSIF address_type = 'single' THEN
			IF parent_rec.can_subnet = 'Y' THEN
				RAISE EXCEPTION
					'parent subnet for single address must have can_subnet set to N'
					USING ERRCODE = 'JH10B';
			END IF;
		ELSIF address_type = 'netblock' THEN
			IF parent_rec.can_subnet = 'N' THEN
				RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
					USING ERRCODE = 'JH10B';
			END IF;
		END IF;
	END LOOP;

 	IF NOT FOUND THEN
 		RETURN;
 	END IF;

	IF address_type = 'loopback' THEN
		-- If we're allocating a loopback address, then we need to create
		-- a new parent to hold the single loopback address

		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := loopback_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN;
		END IF;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'N',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO parent_rec;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			parent_rec.netblock_type,
			'Y',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN NEXT netblock_rec;
		RETURN;
	END IF;

	IF address_type = 'single' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			single_address := true,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			rnd_masklen_threshold := rnd_masklen_threshold,
			rnd_max_count := rnd_max_count,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN;
		END IF;

		RAISE DEBUG 'ip_address is %', inet_rec.ip_address;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'Y',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		RETURN NEXT netblock_rec;
		RETURN;
	END IF;
	IF address_type = 'netblock' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := netmask_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1);

		IF NOT FOUND THEN
			RETURN;
		END IF;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'N',
			CASE WHEN can_subnet THEN 'Y' ELSE 'N' END,
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		RAISE DEBUG 'Allocated netblock_id % for %',
			netblock_rec.netblock_id,
			netblock_rec.ip_address;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN NEXT netblock_rec;
		RETURN;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'create_network_range');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.create_network_range ( start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer, description character varying, allow_assigned boolean );
CREATE OR REPLACE FUNCTION netblock_manip.create_network_range(start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer DEFAULT NULL::integer, description character varying DEFAULT NULL::character varying, allow_assigned boolean DEFAULT false)
 RETURNS network_range
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	par_netblock	RECORD;
	start_netblock	RECORD;
	stop_netblock	RECORD;
	netrange		RECORD;
	nrtype			ALIAS FOR network_range_type;
	pnbid			ALIAS FOR parent_netblock_id;
BEGIN
	--
	-- If the network range already exists, then just return it
	--
	SELECT
		nr.* INTO netrange
	FROM
		jazzhands.network_range nr JOIN
		jazzhands.netblock startnb ON (nr.start_netblock_id =
			startnb.netblock_id) JOIN
		jazzhands.netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND
		host(startnb.ip_address) = host(start_ip_address) AND
		host(stopnb.ip_address) = host(stop_ip_address) AND
		CASE WHEN pnbid IS NOT NULL THEN
			(pnbid = nr.parent_netblock_id)
		ELSE
			true
		END;

	IF FOUND THEN
		RETURN netrange;
	END IF;

	--
	-- If any other network ranges exist that overlap this, then error
	--
	PERFORM
		*
	FROM
		jazzhands.network_range nr JOIN
		jazzhands.netblock startnb ON
			(nr.start_netblock_id = startnb.netblock_id) JOIN
		jazzhands.netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND ((
			host(startnb.ip_address)::inet <= host(start_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(start_ip_address)::inet
		) OR (
			host(startnb.ip_address)::inet <= host(stop_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(stop_ip_address)::inet
		));

	IF FOUND THEN
		RAISE 'create_network_range: a network_range of type % already exists that has addresses between % and %',
			nrtype, start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	IF parent_netblock_id IS NOT NULL THEN
		SELECT * INTO par_netblock FROM jazzhands.netblock WHERE
			netblock_id = pnbid;
		IF NOT FOUND THEN
			RAISE 'create_network_range: parent_netblock_id % does not exist',
				parent_netblock_id USING ERRCODE = 'foreign_key_violation';
		END IF;
	ELSE
		SELECT * INTO par_netblock FROM jazzhands.netblock WHERE netblock_id = (
			SELECT
				*
			FROM
				netblock_utils.find_best_parent_id(
					in_ipaddress := start_ip_address,
					in_is_single_address := 'Y'
				)
		);

		IF NOT FOUND THEN
			RAISE 'create_network_range: valid parent netblock for start_ip_address % does not exist',
				start_ip_address USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	IF par_netblock.can_subnet != 'N' OR
			par_netblock.is_single_address != 'N' THEN
		RAISE 'create_network_range: parent netblock % must not be subnettable or a single address',
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not contained by parent netblock % (%)',
			start_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (stop_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: stop_ip_address % is not contained by parent netblock % (%)',
			stop_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <= stop_ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not lower than stop_ip_address %',
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	--
	-- Validate that there are not currently any addresses assigned in the
	-- range, unless allow_assigned is set
	--
	IF NOT allow_assigned THEN
		PERFORM
			*
		FROM
			jazzhands.netblock n
		WHERE
			n.parent_netblock_id = par_netblock.netblock_id AND
			host(n.ip_address)::inet > host(start_ip_address)::inet AND
			host(n.ip_address)::inet < host(stop_ip_address)::inet;

		IF FOUND THEN
			RAISE 'create_network_range: netblocks are already present for parent netblock % betweeen % and %',
			par_netblock.netblock_id,
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	--
	-- Ok, well, we should be able to insert things now
	--

	SELECT
		*
	FROM
		jazzhands.netblock n
	INTO
		start_netblock
	WHERE
		host(n.ip_address)::inet = start_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(start_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO start_netblock;
	END IF;

	SELECT
		*
	FROM
		jazzhands.netblock n
	INTO
		stop_netblock
	WHERE
		host(n.ip_address)::inet = stop_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(stop_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO stop_netblock;
	END IF;

	INSERT INTO network_range (
		network_range_type,
		description,
		parent_netblock_id,
		start_netblock_id,
		stop_netblock_id
	) VALUES (
		nrtype,
		description,
		par_netblock.netblock_id,
		start_netblock.netblock_id,
		stop_netblock.netblock_id
	) RETURNING * INTO netrange;

	RETURN netrange;

	RETURN NULL;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'delete_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.delete_netblock ( in_netblock_id integer );
CREATE OR REPLACE FUNCTION netblock_manip.delete_netblock(in_netblock_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	/*
	 * Update netblocks that use this as a parent to point to my parent
	 */
	SELECT
		netblock_id INTO par_nbid
	FROM
		jazzhands.netblock
	WHERE
		netblock_id = in_netblock_id;

	UPDATE
		jazzhands.netblock
	SET
		parent_netblock_id = par_nbid
	WHERE
		parent_netblock_id = in_netblock_id;

	/*
	 * Now delete the record
	 */
	DELETE FROM jazzhands.netblock WHERE netblock_id = in_netblock_id;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'recalculate_parentage');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.recalculate_parentage ( in_netblock_id integer );
CREATE OR REPLACE FUNCTION netblock_manip.recalculate_parentage(in_netblock_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	nbrec		RECORD;
	childrec	RECORD;
	nbid		jazzhands.netblock.netblock_id%type;
	ipaddr		inet;

BEGIN
	SELECT * INTO nbrec FROM jazzhands.netblock WHERE
		netblock_id = in_netblock_id;

	nbid := netblock_utils.find_best_parent_id(in_netblock_id);

	UPDATE jazzhands.netblock SET parent_netblock_id = nbid
		WHERE netblock_id = in_netblock_id;

	FOR childrec IN SELECT * FROM jazzhands.netblock WHERE
		parent_netblock_id = nbid
		AND netblock_id != in_netblock_id
	LOOP
		IF (childrec.ip_address <<= nbrec.ip_address) THEN
			UPDATE jazzhands.netblock SET parent_netblock_id = in_netblock_id
				WHERE netblock_id = childrec.netblock_id;
		END IF;
	END LOOP;
	RETURN nbid;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION netblock_manip.set_interface_addresses(network_interface_id integer DEFAULT NULL::integer, device_id integer DEFAULT NULL::integer, network_interface_name text DEFAULT NULL::text, network_interface_type text DEFAULT 'broadcast'::text, ip_address_hash jsonb DEFAULT NULL::jsonb, create_layer3_networks boolean DEFAULT false, move_addresses text DEFAULT 'if_same_device'::text, address_errors text DEFAULT 'error'::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
--
-- ip_address_hash consists of the following elements
--
--		"ip_addresses" : [ (inet | netblock) ... ]
--		"shared_ip_addresses" : [ (inet | netblock) ... ]
--
-- where inet is a text string that can be legally converted to type inet
-- and netblock is a JSON object with fields:
--		"ip_address" : inet
--		"ip_universe_id" : integer (default 0)
--		"netblock_type" : text (default 'default')
--		"protocol" : text (default 'VRRP')
--
-- If either "ip_addresses" or "shared_ip_addresses" does not exist, it
-- will not be processed.  If the key is present and is an empty array or
-- null, then all IP addresses of those types will be removed from the
-- interface
--
-- 'protocol' is only valid for shared addresses, which is how the address
-- is shared.  Valid values can be found in the val_shared_netblock_protocol
-- table
--
DECLARE
	ni_id			ALIAS FOR network_interface_id;
	dev_id			ALIAS FOR device_id;
	ni_name			ALIAS FOR network_interface_name;
	ni_type			ALIAS FOR network_interface_type;

	addrs_ary		jsonb;
	ipaddr			inet;
	universe		integer;
	nb_type			text;
	protocol		text;

	c				integer;
	i				integer;

	nb_rec			RECORD;
	pnb_rec			RECORD;
	layer3_rec		RECORD;
	sn_rec			RECORD;
	ni_rec			RECORD;
	nin_rec			RECORD;
	nb_id			jazzhands.netblock.netblock_id%TYPE;
	nb_id_ary		integer[];
	ni_id_ary		integer[];
	del_list		integer[];
BEGIN
	--
	-- Validate that we got enough information passed to do things
	--

	IF ip_address_hash IS NULL OR NOT
		(jsonb_typeof(ip_address_hash) = 'object')
	THEN
		RAISE 'Must pass ip_addresses to netblock_manip.set_interface_addresses';
	END IF;

	IF network_interface_id IS NULL THEN
		IF device_id IS NULL OR network_interface_name IS NULL THEN
			RAISE 'netblock_manip.assign_shared_netblock: must pass either network_interface_id or device_id and network_interface_name'
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
			INSERT INTO network_interface(
				device_id,
				network_interface_name,
				network_interface_type,
				should_monitor
			) VALUES (
				dev_id,
				ni_name,
				ni_type,
				'N'
			) RETURNING network_interface.network_interface_id INTO ni_id;
		END IF;
	END IF;

	SELECT * INTO ni_rec FROM network_interface ni WHERE 
		ni.network_interface_id = ni_id;

	--
	-- First, loop through ip_addresses passed and process those
	--

	IF ip_address_hash ? 'ip_addresses' AND
		jsonb_typeof(ip_address_hash->'ip_addresses') = 'array'
	THEN
		RAISE DEBUG 'Processing ip_addresses...';
		--
		-- Loop through each member of the ip_addresses array
		-- and process each address
		--
		addrs_ary := ip_address_hash->'ip_addresses';
		c := jsonb_array_length(addrs_ary);
		i := 0;
		nb_id_ary := NULL;
		WHILE (i < c) LOOP
			IF jsonb_typeof(addrs_ary->i) = 'string' THEN
				--
				-- If this is a string, use it as an inet with default
				-- universe and netblock_type
				--
				ipaddr := addrs_ary->>i;
				universe := 0;
				nb_type := 'default';
			ELSIF jsonb_typeof(addrs_ary->i) = 'object' THEN
				--
				-- If this is an object, require 'ip_address' key
				-- optionally use 'ip_universe_id' and 'netblock_type' keys
				-- to override the defaults
				--
				IF NOT addrs_ary->i ? 'ip_address' THEN
					RAISE E'Object in array element % of ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses does not contain ip_address key:\n%',
						i, jsonb_pretty(addrs_ary->i);
				END IF;
				ipaddr := addrs_ary->i->>'ip_address';

				IF addrs_ary->i ? 'ip_universe_id' THEN
					universe := addrs_ary->i->'ip_universe_id';
				ELSE
					universe := 0;
				END IF;

				IF addrs_ary->i ? 'netblock_type' THEN
					nb_type := addrs_ary->i->>'netblock_type';
				ELSE
					nb_type := 'default';
				END IF;
			ELSE
				RAISE 'Invalid type in array element % of ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses (%)',
					i, jsonb_typeof(addrs_ary->i);
			END IF;
			--
			-- We're done with the array, so increment the counter so
			-- we don't have to deal with it later
			--
			i := i + 1;

			RAISE DEBUG 'Address is %, universe is %, nb type is %',
				ipaddr, universe, nb_type;

			--
			-- This is a hack, because Juniper is really annoying about this.
			-- If masklen < 8, then ignore this netblock (we specifically
			-- want /8, because of 127/8 and 10/8, which someone could
			-- maybe want to not subnet.
			--
			-- This should probably be a configuration parameter, but it's not.
			--
			CONTINUE WHEN masklen(ipaddr) < 8;

			--
			-- Check to see if this is a netblock that we have been
			-- told to explicitly ignore
			--
			PERFORM
				ip_address
			FROM
				netblock n JOIN
				netblock_collection_netblock ncn USING (netblock_id) JOIN
				v_netblock_coll_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_nblk_coll_id =
						nce.root_netblock_collection_id
				)
			WHERE
				ipaddr <<= n.ip_address AND
				n.ip_universe_id = universe AND
				n.netblock_type = nb_type;

			--
			-- If we found this netblock in the ignore list, then just
			-- skip it
			--
			IF FOUND THEN
				RAISE DEBUG 'Skipping ignored address %', ipaddr;
				CONTINUE;
			END IF;

			--
			-- Look for an is_single_address='Y', can_subnet='N' netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = 'Y' AND
				can_subnet = 'N' AND
				netblock_type = nb_type AND
				ip_universe_id = universe AND
				host(ip_address) = host(ipaddr);

			IF FOUND THEN
				RAISE DEBUG E'Located netblock:\n%',
					jsonb_pretty(to_jsonb(nb_rec));

				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);

				--
				-- Look to see if there's a layer3_network for the
				-- parent netblock
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.netblock_id = nb_rec.parent_netblock_id;

				IF FOUND THEN
					RAISE DEBUG E'Located layer3_network:\n%',
						jsonb_pretty(to_jsonb(layer3_rec));
				ELSE
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
			ELSE
				--
				-- If the parent netblock does not exist, then create it
				-- if we were passed the option to
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.ip_universe_id = universe AND
					n.netblock_type = nb_type AND
					is_single_address = 'N' AND
					can_subnet = 'N' AND
					n.ip_address >>= ipaddr;

				IF NOT FOUND THEN
					RAISE DEBUG 'Parent netblock with ip_address %, netblock_type %, ip_universe_id % not found',
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					--
					-- Check to see if the netblock exists, but is
					-- marked can_subnet='Y'.  If so, fix it
					--
					SELECT 
						* INTO pnb_rec
					FROM
						netblock n
					WHERE
						n.ip_universe_id = universe AND
						n.netblock_type = nb_type AND
						n.is_single_address = 'N' AND
						n.can_subnet = 'Y' AND
						n.ip_address = network(ipaddr);

					IF FOUND THEN
						UPDATE netblock n SET
							can_subnet = 'N'
						WHERE
							n.netblock_id = pnb_rec.netblock_id;
						pnb_rec.can_subnet = 'N';
					ELSE
						INSERT INTO netblock (
							ip_address,
							netblock_type,
							is_single_address,
							can_subnet,
							ip_universe_id,
							netblock_status
						) VALUES (
							network(ipaddr),
							nb_type,
							'N',
							'N',
							universe,
							'Allocated'
						) RETURNING * INTO pnb_rec;
					END IF;

					WITH l3_ins AS (
						INSERT INTO layer3_network(
							netblock_id
						) VALUES (
							pnb_rec.netblock_id
						) RETURNING *
					)
					SELECT
						pnb_rec.netblock_id,
						pnb_rec.ip_address,
						l3_ins.layer3_network_id,
						NULL::inet
					INTO layer3_rec
					FROM
						l3_ins;
				ELSIF layer3_rec.layer3_network_id IS NULL THEN
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--

					RAISE DEBUG 'layer3_network for parent netblock % not found (ip_address %, netblock_type %, ip_universe_id %)',
						layer3_rec.netblock_id,
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
				RAISE DEBUG E'Located layer3_network:\n%',
					jsonb_pretty(to_jsonb(layer3_rec));
				--
				-- Parents should be all set up now.  Insert the netblock
				--
				INSERT INTO netblock (
					ip_address,
					netblock_type,
					ip_universe_id,
					is_single_address,
					can_subnet,
					netblock_status
				) VALUES (
					ipaddr,
					nb_type,
					universe,
					'Y',
					'N',
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;
			--
			-- Now that we have the netblock and everything, check to see
			-- if this netblock is already assigned to this network_interface
			--
			PERFORM * FROM
				network_interface_netblock nin
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id = ni_id;

			IF FOUND THEN
				RAISE DEBUG 'Netblock % already found on network_interface',
					nb_rec.netblock_id;
				CONTINUE;
			END IF;

			--
			-- See if this netblock is on something else, and delete it
			-- if move_addresses is set, otherwise skip it
			--
			SELECT 
				ni.network_interface_id,
				nin.netblock_id,
				ni.device_id
			INTO nin_rec
			FROM
				network_interface_netblock nin JOIN
				network_interface ni USING (network_interface_id)
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id != ni_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND 
					nin_rec.device_id = ni_rec.device_id
				)
				THEN
					DELETE FROM
						network_interface_netblock
					WHERE
						netblock_id = nb_rec.netblock_id;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSE
						RAISE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;
					END IF;
				END IF;
			END IF;

			--
			-- See if this netblock is on a shared_address somewhere, and
			-- move it only if move_addresses is 'always'
			--
			SELECT * FROM
				shared_netblock sn
			INTO sn_rec
			WHERE
				sn.netblock_id = nb_rec.netblock_id;

			IF FOUND THEN
				IF move_addresses IS NULL OR move_addresses != 'always' THEN
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, sn.shared_netblock_id;
						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, sn.shared_netblock_id;
						CONTINUE;
					ELSE
						RAISE 'Netblock % is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, sn.shared_netblock_id;
						CONTINUE;
					END IF;
				END IF;

				DELETE FROM
					shared_netblock_network_int snni
				WHERE
					snni.shared_netblock_id = sn_rec.shared_netblock_id;

				DELETE FROM
					shared_network sn
				WHERE
					sn.netblock_id = sn_rec.shared_netblock_id;
			END IF;

			--
			-- Insert the netblock onto the interface using the next
			-- rank
			--
			INSERT INTO network_interface_netblock (
				network_interface_id,
				netblock_id,
				network_interface_rank
			) SELECT
				ni_id,
				nb_rec.netblock_id,
				COALESCE(MAX(network_interface_rank) + 1, 0)
			FROM
				network_interface_netblock nin
			WHERE
				nin.network_interface_id = ni_id
			RETURNING * INTO nin_rec;

			RAISE DEBUG E'Inserted into:\n%',
				jsonb_pretty(to_jsonb(nin_rec));
		END LOOP;
		--
		-- Remove any netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR nin_rec IN
			DELETE FROM
				network_interface_netblock nin
			WHERE
				(nin.network_interface_id, nin.netblock_id) IN (
				SELECT
					nin2.network_interface_id,
					nin2.netblock_id
				FROM
					network_interface_netblock nin2 JOIN
					netblock n USING (netblock_id)
				WHERE
					nin2.network_interface_id = ni_id AND NOT (
						nin.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_coll_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_nblk_coll_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed netblock % from network_interface %',
				nin_rec.netblock_id,
				nin_rec.network_interface_id;
			--
			-- Remove any DNS records and/or netblocks that aren't used
			--
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = nin_rec.netblock_id;
				DELETE FROM netblock_collection_netblock WHERE
					netblock_id = nin_rec.netblock_id;
				DELETE FROM netblock WHERE netblock_id =
					nin_rec.netblock_id;
			EXCEPTION
				WHEN foreign_key_violation THEN NULL;
			END;
		END LOOP;
	END IF;

	--
	-- Loop through shared_ip_addresses passed and process those
	--

	IF ip_address_hash ? 'shared_ip_addresses' AND
		jsonb_typeof(ip_address_hash->'shared_ip_addresses') = 'array'
	THEN
		RAISE DEBUG 'Processing shared_ip_addresses...';
		--
		-- Loop through each member of the shared_ip_addresses array
		-- and process each address
		--
		addrs_ary := ip_address_hash->'shared_ip_addresses';
		c := jsonb_array_length(addrs_ary);
		i := 0;
		nb_id_ary := NULL;
		WHILE (i < c) LOOP
			IF jsonb_typeof(addrs_ary->i) = 'string' THEN
				--
				-- If this is a string, use it as an inet with default
				-- universe and netblock_type
				--
				ipaddr := addrs_ary->>i;
				universe := 0;
				nb_type := 'default';
				protocol := 'VRRP';
			ELSIF jsonb_typeof(addrs_ary->i) = 'object' THEN
				--
				-- If this is an object, require 'ip_address' key
				-- optionally use 'ip_universe_id' and 'netblock_type' keys
				-- to override the defaults
				--
				IF NOT addrs_ary->i ? 'ip_address' THEN
					RAISE E'Object in array element % of shared_ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses does not contain ip_address key:\n%',
						i, jsonb_pretty(addrs_ary->i);
				END IF;
				ipaddr := addrs_ary->i->>'ip_address';

				IF addrs_ary->i ? 'ip_universe_id' THEN
					universe := addrs_ary->i->'ip_universe_id';
				ELSE
					universe := 0;
				END IF;

				IF addrs_ary->i ? 'netblock_type' THEN
					nb_type := addrs_ary->i->>'netblock_type';
				ELSE
					nb_type := 'default';
				END IF;

				IF addrs_ary->i ? 'shared_netblock_protocol' THEN
					protocol := addrs_ary->i->>'shared_netblock_protocol';
				ELSIF addrs_ary->i ? 'protocol' THEN
					protocol := addrs_ary->i->>'protocol';
				ELSE
					protocol := 'VRRP';
				END IF;
			ELSE
				RAISE 'Invalid type in array element % of shared_ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses (%)',
					i, jsonb_typeof(addrs_ary->i);
			END IF;
			--
			-- We're done with the array, so increment the counter so
			-- we don't have to deal with it later
			--
			i := i + 1;

			RAISE DEBUG 'Address is %, universe is %, nb type is %',
				ipaddr, universe, nb_type;

			--
			-- Check to see if this is a netblock that we have been
			-- told to explicitly ignore
			--
			PERFORM
				ip_address
			FROM
				netblock n JOIN
				netblock_collection_netblock ncn USING (netblock_id) JOIN
				v_netblock_coll_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_nblk_coll_id =
						nce.root_netblock_collection_id
				)
			WHERE
				ipaddr <<= n.ip_address AND
				n.ip_universe_id = universe AND
				n.netblock_type = nb_type;

			--
			-- If we found this netblock in the ignore list, then just
			-- skip it
			--
			IF FOUND THEN
				RAISE DEBUG 'Skipping ignored address %', ipaddr;
				CONTINUE;
			END IF;

			--
			-- Look for an is_single_address='Y', can_subnet='N' netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = 'Y' AND
				can_subnet = 'N' AND
				netblock_type = nb_type AND
				ip_universe_id = universe AND
				host(ip_address) = host(ipaddr);

			IF FOUND THEN
				RAISE DEBUG E'Located netblock:\n%',
					jsonb_pretty(to_jsonb(nb_rec));

				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);

				--
				-- Look to see if there's a layer3_network for the
				-- parent netblock
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.netblock_id = nb_rec.parent_netblock_id;

				IF FOUND THEN
					RAISE DEBUG E'Located layer3_network:\n%',
						jsonb_pretty(to_jsonb(layer3_rec));
				ELSE
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
			ELSE
				--
				-- If the parent netblock does not exist, then create it
				-- if we were passed the option to
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.ip_universe_id = universe AND
					n.netblock_type = nb_type AND
					is_single_address = 'N' AND
					can_subnet = 'N' AND
					n.ip_address >>= ipaddr;

				IF NOT FOUND THEN
					RAISE DEBUG 'Parent netblock with ip_address %, netblock_type %, ip_universe_id % not found',
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					WITH nb_ins AS (
						INSERT INTO netblock (
							ip_address,
							netblock_type,
							is_single_address,
							can_subnet,
							ip_universe_id,
							netblock_status
						) VALUES (
							network(ipaddr),
							nb_type,
							'N',
							'N',
							universe,
							'Allocated'
						) RETURNING *
					), l3_ins AS (
						INSERT INTO layer3_network(
							netblock_id
						)
						SELECT
							netblock_id
						FROM
							nb_ins
						RETURNING *
					)
					SELECT
						nb_ins.netblock_id,
						nb_ins.ip_address,
						l3_ins.layer3_network_id,
						NULL
					INTO layer3_rec
					FROM
						nb_ins,
						l3_ins;
				ELSIF layer3_rec.layer3_network_id IS NULL THEN
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--

					RAISE DEBUG 'layer3_network for parent netblock % not found (ip_address %, netblock_type %, ip_universe_id %)',
						layer3_rec.netblock_id,
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
				RAISE DEBUG E'Located layer3_network:\n%',
					jsonb_pretty(to_jsonb(layer3_rec));
				--
				-- Parents should be all set up now.  Insert the netblock
				--
				INSERT INTO netblock (
					ip_address,
					netblock_type,
					ip_universe_id,
					is_single_address,
					can_subnet,
					netblock_status
				) VALUES (
					ipaddr,
					nb_type,
					universe,
					'Y',
					'N',
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;

			--
			-- See if this netblock is directly on any network_interface, and
			-- delete it if force is set, otherwise skip it
			--
			ni_id_ary := ARRAY[]::integer[];

			SELECT 
				ni.network_interface_id,
				nin.netblock_id,
				ni.device_id
			INTO nin_rec
			FROM
				network_interface_netblock nin JOIN
				network_interface ni USING (network_interface_id)
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id != ni_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND 
					nin_rec.device_id = ni_rec.device_id
				)
				THEN
					--
					-- Remove the netblocks from the network_interfaces,
					-- but save them for later so that we can migrate them
					-- after we make sure the shared_netblock exists.
					--
					-- Also, append the network_inteface_id that we
					-- specifically care about, and we'll add them all
					-- below
					--
					WITH z AS (
						DELETE FROM
							network_interface_netblock
						WHERE
							netblock_id = nb_rec.netblock_id
						RETURNING network_interface_id
					)
					SELECT array_agg(network_interface_id) FROM
						(SELECT network_interface_id FROM z) v
					INTO ni_id_ary;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSE
						RAISE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;
					END IF;
				END IF;

			END IF;

			IF NOT(ni_id = ANY(ni_id_ary)) THEN
				ni_id_ary := array_append(ni_id_ary, ni_id);
			END IF;

			--
			-- See if this netblock already belongs to a shared_network
			--
			SELECT * FROM
				shared_netblock sn
			INTO sn_rec
			WHERE
				sn.netblock_id = nb_rec.netblock_id;

			IF FOUND THEN
				IF sn_rec.shared_netblock_protocol != protocol THEN
					RAISE 'Netblock % (%) is assigned to shared_network %, but the shared_network_protocol does not match (% vs. %)',
						nb_rec.netblock_id,
						nb_rec.ip_address,
						sn_rec.shared_netblock_id,
						sn_rec.shared_netblock_protocol,
						protocol;
				END IF;
			ELSE
				INSERT INTO shared_netblock (
					shared_netblock_protocol,
					netblock_id
				) VALUES (
					protocol,
					nb_rec.netblock_id
				) RETURNING * INTO sn_rec;
			END IF;

			--
			-- Add this to any interfaces that we found above that
			-- need this
			--

			INSERT INTO shared_netblock_network_int (
				shared_netblock_id,
				network_interface_id,
				priority
			) SELECT
				sn_rec.shared_netblock_id,
				x.network_interface_id,
				0
			FROM
				unnest(ni_id_ary) x(network_interface_id)
			ON CONFLICT ON CONSTRAINT pk_ip_group_network_interface DO NOTHING;

			RAISE DEBUG E'Inserted shared_netblock % onto interfaces:\n%',
				sn_rec.shared_netblock_id, jsonb_pretty(to_jsonb(ni_id_ary));
		END LOOP;
		--
		-- Remove any shared_netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR nin_rec IN
			DELETE FROM
				shared_netblock_network_int snni
			WHERE
				(snni.network_interface_id, snni.shared_netblock_id) IN (
				SELECT
					snni2.network_interface_id,
					snni2.shared_netblock_id
				FROM
					shared_netblock_network_int snni2 JOIN
					shared_netblock sn USING (shared_netblock_id) JOIN
					netblock n USING (netblock_id)
				WHERE
					snni2.network_interface_id = ni_id AND NOT (
						sn.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_coll_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_nblk_coll_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed shared_netblock % from network_interface %',
				nin_rec.shared_netblock_id,
				nin_rec.network_interface_id;

			--
			-- Remove any DNS records, netblocks and shared_netblocks
			-- that aren't used
			--
			SELECT netblock_id INTO nb_id FROM shared_netblock sn WHERE
				sn.shared_netblock_id = nin_rec.shared_netblock_id;
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = nb_id;
				DELETE FROM netblock_collection_netblock ncn WHERE
					ncn.netblock_id = nb_id;
				DELETE FROM shared_netblock WHERE netblock_id = nb_id;
				DELETE FROM netblock WHERE netblock_id = nb_id;
			EXCEPTION
				WHEN foreign_key_violation THEN NULL;
			END;
		END LOOP;
	END IF;
	RETURN true;
END;
$function$
;

--
-- Process middle (non-trigger) schema physical_address_utils
--
--
-- Process middle (non-trigger) schema component_utils
--
--
-- Process middle (non-trigger) schema snapshot_manip
--
--
-- Process middle (non-trigger) schema lv_manip
--
--
-- Process middle (non-trigger) schema approval_utils
--
--
-- Process middle (non-trigger) schema account_collection_manip
--
--
-- Process middle (non-trigger) schema script_hooks
--
--
-- Process middle (non-trigger) schema backend_utils
--
--
-- Process middle (non-trigger) schema schema_support
--
--
-- Process middle (non-trigger) schema rack_utils
--
--
-- Process middle (non-trigger) schema layerx_network_manip
--
-- New function
CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer2_network(layer2_network_id integer, purge_network_interfaces boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
	PERFORM * FROM layerx_network_manip.delete_layer2_networks(
		layer2_network_id_list := ARRAY[ layer2_network_id ],
		purge_network_interfaces := purge_network_interfaces
	);
END $function$
;

-- New function
CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer2_networks(layer2_network_id_list integer[], purge_network_interfaces boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	netblock_id_list	integer[];
BEGIN
	BEGIN
		PERFORM local_hooks.delete_layer2_networks_before_hooks(
			layer2_network_id_list := layer2_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	IF (purge_network_interfaces) THEN
		SELECT ARRAY(
			SELECT
				n.netblock_id AS netblock_id
			FROM
				jazzhands.layer2_network l2 JOIN
				jazzhands.layer3_network l3 USING (layer2_network_id) JOIN
				jazzhands.netblock p USING (netblock_id) JOIN
				jazzhands.netblock n ON (p.netblock_id = n.parent_netblock_id)
			WHERE
				l2.layer2_network_id = ANY(layer2_network_id_list)
		) INTO netblock_id_list;

		WITH nin_del AS (
			DELETE FROM
				jazzhands.network_interface_netblock 
			WHERE
				netblock_id = ANY(netblock_id_list)
			RETURNING network_interface_id
		), snni_del AS (
			DELETE FROM
				jazzhands.shared_netblock_network_int
			WHERE
				shared_netblock_id IN (
					SELECT shared_netblock_id FROM jazzhands.shared_netblock
					WHERE netblock_id = ANY(netblock_id_list)
				)
			RETURNING network_interface_id
		)
		DELETE FROM jazzhands.network_interface
		WHERE
			network_interface_id IN (
				SELECT network_interface_id FROM nin_del
				UNION
				SELECT network_interface_id FROM snni_del
			);
	END IF;


	WITH x AS (
		SELECT
			p.netblock_id AS netblock_id,
			l2.layer2_network_id AS layer2_network_id,
			l3.layer3_network_id AS layer3_network_id
		FROM
			jazzhands.layer2_network l2 JOIN
			jazzhands.layer3_network l3 USING (layer2_network_id) JOIN
			jazzhands.netblock p USING (netblock_id)
		WHERE
			l2.layer2_network_id = ANY(layer2_network_id_list)
	), l3_coll_del AS (
		DELETE FROM
			jazzhands.l3_network_coll_l3_network
		WHERE
			layer3_network_id IN (SELECT layer3_network_id FROM x)
	), l3_del AS (
		DELETE FROM
			jazzhands.layer3_network
		WHERE
			layer3_network_id in (SELECT layer3_network_id FROM x)
	), l2_coll_del AS (
		DELETE FROM
			jazzhands.l2_network_coll_l2_network
		WHERE
			layer2_network_id IN (SELECT layer2_network_id FROM x)
	), l2_del AS (
		DELETE FROM
			jazzhands.layer2_network
		WHERE
			layer2_network_id IN (SELECT layer2_network_id FROM x)
	), nb_sel AS (
		SELECT
			n.netblock_id
		FROM
			jazzhands.netblock n JOIN
			x ON (n.parent_netblock_id = x.netblock_id)
	), dns_del AS (
		DELETE FROM
			jazzhands.dns_record
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	), nb_del as (
		DELETE FROM
			jazzhands.netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	), sn_del as (
		DELETE FROM
			jazzhands.shared_netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	)
	DELETE FROM
		jazzhands.netblock
	WHERE
		netblock_id IN (SELECT netblock_id FROM x);

	BEGIN
		PERFORM local_hooks.delete_layer2_networks_after_hooks(
			layer2_network_id_list := layer2_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

END $function$
;

-- Creating new sequences....


--------------------------------------------------------------------
-- DEALING WITH TABLE mv_unix_group_mappings
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'mv_unix_group_mappings');
-- DONE DEALING WITH OLD TABLE mv_unix_group_mappings
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE mv_unix_passwd_mappings
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'mv_unix_passwd_mappings');
-- DONE DEALING WITH OLD TABLE mv_unix_passwd_mappings
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_property
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_property', 'v_property');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_property');
DROP VIEW IF EXISTS jazzhands.v_property;
CREATE VIEW jazzhands.v_property AS
 SELECT property.property_id,
    property.account_collection_id,
    property.account_id,
    property.account_realm_id,
    property.company_collection_id,
    property.company_id,
    property.device_collection_id,
    property.dns_domain_collection_id,
    property.layer2_network_collection_id,
    property.layer3_network_collection_id,
    property.netblock_collection_id,
    property.network_range_id,
    property.operating_system_id,
    property.operating_system_snapshot_id,
    property.person_id,
    property.property_collection_id,
    property.service_env_collection_id,
    property.site_code,
    property.x509_signed_certificate_id,
    property.property_name,
    property.property_type,
    property.property_value,
    property.property_value_timestamp,
    property.property_value_company_id,
    property.property_value_account_coll_id,
    property.property_value_device_coll_id,
    property.property_value_nblk_coll_id,
    property.property_value_password_type,
    property.property_value_person_id,
    property.property_value_sw_package_id,
    property.property_value_token_col_id,
    property.property_rank,
    property.start_date,
    property.finish_date,
    property.is_enabled,
    property.data_ins_user,
    property.data_ins_date,
    property.data_upd_user,
    property.data_upd_date
   FROM property
  WHERE property.is_enabled = 'Y'::bpchar AND (property.start_date IS NULL AND property.finish_date IS NULL OR property.start_date IS NULL AND now() <= property.finish_date OR property.start_date <= now() AND property.finish_date IS NULL OR property.start_date <= now() AND now() <= property.finish_date);

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_property';
SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_property
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE ip_universe
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'ip_universe', 'ip_universe');

-- FOREIGN KEYS FROM
ALTER TABLE dns_record DROP CONSTRAINT IF EXISTS fk_dns_rec_ip_universe;
ALTER TABLE netblock DROP CONSTRAINT IF EXISTS fk_nblk_ip_universe_id;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'ip_universe');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.ip_universe DROP CONSTRAINT IF EXISTS ak_ip_universe_name;
ALTER TABLE jazzhands.ip_universe DROP CONSTRAINT IF EXISTS pk_ip_universe;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_ip_universe ON jazzhands.ip_universe;
DROP TRIGGER IF EXISTS trigger_audit_ip_universe ON jazzhands.ip_universe;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'ip_universe');
---- BEGIN audit.ip_universe TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'ip_universe', 'ip_universe');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'ip_universe');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.ip_universe DROP CONSTRAINT IF EXISTS ip_universe_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_ip_universe_ak_ip_universe_name";
DROP INDEX IF EXISTS "audit"."aud_ip_universe_pk_ip_universe";
DROP INDEX IF EXISTS "audit"."ip_universe_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.ip_universe TEARDOWN


ALTER TABLE ip_universe RENAME TO ip_universe_v79;
ALTER TABLE audit.ip_universe RENAME TO ip_universe_v79;

CREATE TABLE ip_universe
(
	ip_universe_id	integer NOT NULL,
	ip_universe_name	varchar(50) NOT NULL,
	ip_namespace	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'ip_universe', false);
ALTER TABLE ip_universe
	ALTER ip_universe_id
	SET DEFAULT nextval('ip_universe_ip_universe_id_seq'::regclass);
INSERT INTO ip_universe (
	ip_universe_id,
	ip_universe_name,
	ip_namespace,		-- new column (ip_namespace)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	ip_universe_id,
	ip_universe_name,
	'default',		-- new column (ip_namespace)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM ip_universe_v79;

INSERT INTO audit.ip_universe (
	ip_universe_id,
	ip_universe_name,
	ip_namespace,		-- new column (ip_namespace)
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
	ip_universe_id,
	ip_universe_name,
	'default',		-- new column (ip_namespace)
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
FROM audit.ip_universe_v79;

ALTER TABLE ip_universe
	ALTER ip_universe_id
	SET DEFAULT nextval('ip_universe_ip_universe_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE ip_universe ADD CONSTRAINT ak_ip_universe_name UNIQUE (ip_universe_name);
ALTER TABLE ip_universe ADD CONSTRAINT pk_ip_universe PRIMARY KEY (ip_universe_id);

-- Table/Column Comments
COMMENT ON COLUMN ip_universe.ip_namespace IS 'defeines the namespace for a given ip universe -- all universes in this namespace are considered unique for netblock validations';
-- INDEXES
CREATE INDEX xif1ip_universe ON ip_universe USING btree (ip_namespace);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between ip_universe and dns_record
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dns_rec_ip_universe
	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);
-- consider FK between ip_universe and dns_change_record
-- Skipping this FK since column does not exist yet
--ALTER TABLE dns_change_record
--	ADD CONSTRAINT fk_dnschgrec_ip_universe
--	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);

-- consider FK between ip_universe and dns_domain_ip_universe
-- Skipping this FK since column does not exist yet
--ALTER TABLE dns_domain_ip_universe
--	ADD CONSTRAINT fk_dnsdom_ipu_ipu
--	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);

-- consider FK between ip_universe and ip_universe_visibility
-- Skipping this FK since column does not exist yet
--ALTER TABLE ip_universe_visibility
--	ADD CONSTRAINT fk_ip_universe_vis_ip_univ
--	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);

-- consider FK between ip_universe and ip_universe_visibility
-- Skipping this FK since column does not exist yet
--ALTER TABLE ip_universe_visibility
--	ADD CONSTRAINT fk_ip_universe_vis_ip_univ_vis
--	FOREIGN KEY (visible_ip_universe_id) REFERENCES ip_universe(ip_universe_id);

-- consider FK between ip_universe and netblock
ALTER TABLE netblock
	ADD CONSTRAINT fk_nblk_ip_universe_id
	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);

-- FOREIGN KEYS TO
-- consider FK ip_universe and val_ip_namespace
-- Skipping this FK since column does not exist yet
--ALTER TABLE ip_universe
--	ADD CONSTRAINT r_815
--	FOREIGN KEY (ip_namespace) REFERENCES val_ip_namespace(ip_namespace);


-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'ip_universe');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'ip_universe');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'ip_universe');
ALTER SEQUENCE ip_universe_ip_universe_id_seq
	 OWNED BY ip_universe.ip_universe_id;
DROP TABLE IF EXISTS ip_universe_v79;
DROP TABLE IF EXISTS audit.ip_universe_v79;
-- DONE DEALING WITH TABLE ip_universe
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_dns_srv_service
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_dns_srv_service', 'val_dns_srv_service');

-- FOREIGN KEYS FROM
ALTER TABLE dns_record DROP CONSTRAINT IF EXISTS fk_dnsrec_vdnssrvsrvc;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_dns_srv_service');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_dns_srv_service DROP CONSTRAINT IF EXISTS pk_val_dns_srv_srvice;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_dns_srv_service ON jazzhands.val_dns_srv_service;
DROP TRIGGER IF EXISTS trigger_audit_val_dns_srv_service ON jazzhands.val_dns_srv_service;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_dns_srv_service');
---- BEGIN audit.val_dns_srv_service TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_dns_srv_service', 'val_dns_srv_service');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_dns_srv_service');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.val_dns_srv_service DROP CONSTRAINT IF EXISTS val_dns_srv_service_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_val_dns_srv_service_pk_val_dns_srv_srvice";
DROP INDEX IF EXISTS "audit"."val_dns_srv_service_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_dns_srv_service TEARDOWN


ALTER TABLE val_dns_srv_service RENAME TO val_dns_srv_service_v79;
ALTER TABLE audit.val_dns_srv_service RENAME TO val_dns_srv_service_v79;

CREATE TABLE val_dns_srv_service
(
	dns_srv_service	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_dns_srv_service', false);
INSERT INTO val_dns_srv_service (
	dns_srv_service,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	dns_srv_service,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_dns_srv_service_v79;

INSERT INTO audit.val_dns_srv_service (
	dns_srv_service,
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
	dns_srv_service,
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
FROM audit.val_dns_srv_service_v79;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_dns_srv_service ADD CONSTRAINT pk_val_dns_srv_srvice PRIMARY KEY (dns_srv_service);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_dns_srv_service and dns_record
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsrec_vdnssrvsrvc
	FOREIGN KEY (dns_srv_service) REFERENCES val_dns_srv_service(dns_srv_service);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_dns_srv_service');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'val_dns_srv_service');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_dns_srv_service');
DROP TABLE IF EXISTS val_dns_srv_service_v79;
DROP TABLE IF EXISTS audit.val_dns_srv_service_v79;
-- DONE DEALING WITH TABLE val_dns_srv_service
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_ip_namespace
CREATE TABLE val_ip_namespace
(
	ip_namespace	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_ip_namespace', true);
--
-- Copying initialization data
--

INSERT INTO val_ip_namespace (
ip_namespace,description
) VALUES
	('default','default namespace')
;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_ip_namespace ADD CONSTRAINT pk_val_ip_namespace PRIMARY KEY (ip_namespace);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_ip_namespace and ip_universe
ALTER TABLE ip_universe
	ADD CONSTRAINT r_815
	FOREIGN KEY (ip_namespace) REFERENCES val_ip_namespace(ip_namespace);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_ip_namespace');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'val_ip_namespace');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_ip_namespace');
-- DONE DEALING WITH TABLE val_ip_namespace
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_property
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property', 'val_property');

-- FOREIGN KEYS FROM
ALTER TABLE property_collection_property DROP CONSTRAINT IF EXISTS fk_prop_col_propnamtyp;
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
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_property_dnsdomcolltype;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_property_netblkcolltype;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valnetrng_val_prop;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_propdttyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_proptyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_pv_actyp_rst;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_vla_property_val_propcollty;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS pk_val_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif10val_property";
DROP INDEX IF EXISTS "jazzhands"."xif11val_property";
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
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1494616001;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1664370664;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1804972034;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_185689986;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_185755522;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2016888554;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2139007167;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_271462566;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_354296970;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_366948481;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_606225804;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_cmp_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_ismulti;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_osid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pacct_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdevcol_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdnsdomid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_prodstate;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pucls_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_sitec;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_property ON jazzhands.val_property;
DROP TRIGGER IF EXISTS trigger_audit_val_property ON jazzhands.val_property;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_property');
---- BEGIN audit.val_property TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_property', 'val_property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.val_property DROP CONSTRAINT IF EXISTS val_property_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_val_property_pk_val_property";
DROP INDEX IF EXISTS "audit"."val_property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_property TEARDOWN


ALTER TABLE val_property RENAME TO val_property_v79;
ALTER TABLE audit.val_property RENAME TO val_property_v79;

CREATE TABLE val_property
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
	property_collection_type	varchar(50)  NULL,
	service_env_collection_type	varchar(50)  NULL,
	is_multivalue	character(1) NOT NULL,
	prop_val_acct_coll_type_rstrct	varchar(50)  NULL,
	prop_val_dev_coll_type_rstrct	varchar(50)  NULL,
	prop_val_nblk_coll_type_rstrct	varchar(50)  NULL,
	property_data_type	varchar(50) NOT NULL,
	permit_account_collection_id	character(10) NOT NULL,
	permit_account_id	character(10) NOT NULL,
	permit_account_realm_id	character(10) NOT NULL,
	permit_company_id	character(10) NOT NULL,
	permit_company_collection_id	character(10) NOT NULL,
	permit_device_collection_id	character(10) NOT NULL,
	permit_dns_domain_coll_id	character(10) NOT NULL,
	permit_layer2_network_coll_id	character(10) NOT NULL,
	permit_layer3_network_coll_id	character(10) NOT NULL,
	permit_netblock_collection_id	character(10) NOT NULL,
	permit_network_range_id	character(10) NOT NULL,
	permit_operating_system_id	character(10) NOT NULL,
	permit_os_snapshot_id	character(10) NOT NULL,
	permit_person_id	character(10) NOT NULL,
	permit_property_collection_id	character(10) NOT NULL,
	permit_service_env_collection	character(10) NOT NULL,
	permit_site_code	character(10) NOT NULL,
	permit_x509_signed_cert_id	varchar(50) NOT NULL,
	permit_property_rank	character(10) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_property', false);
ALTER TABLE val_property
	ALTER is_multivalue
	SET DEFAULT 'N'::bpchar;
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
	ALTER permit_dns_domain_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_coll_id
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
	ALTER permit_os_snapshot_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_person_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_service_env_collection
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_x509_signed_cert_id
	SET DEFAULT 'PROHIBITED'::character varying;
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
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_coll_id,
	permit_layer2_network_coll_id,
	permit_layer3_network_coll_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_x509_signed_cert_id,
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
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_coll_id,
	permit_layer2_network_coll_id,
	permit_layer3_network_coll_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_x509_signed_cert_id,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_property_v79;

INSERT INTO audit.val_property (
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
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_coll_id,
	permit_layer2_network_coll_id,
	permit_layer3_network_coll_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_x509_signed_cert_id,
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
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_coll_id,
	permit_layer2_network_coll_id,
	permit_layer3_network_coll_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_x509_signed_cert_id,
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
FROM audit.val_property_v79;

ALTER TABLE val_property
	ALTER is_multivalue
	SET DEFAULT 'N'::bpchar;
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
	ALTER permit_dns_domain_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_coll_id
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
	ALTER permit_os_snapshot_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_person_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_service_env_collection
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_x509_signed_cert_id
	SET DEFAULT 'PROHIBITED'::character varying;
ALTER TABLE val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_property ADD CONSTRAINT pk_val_property PRIMARY KEY (property_name, property_type);

-- Table/Column Comments
COMMENT ON TABLE val_property IS 'valid values and attributes for (name,type) pairs in the property table.  This defines how triggers enforce aspects of the property table';
COMMENT ON COLUMN val_property.property_name IS 'property name for validation purposes';
COMMENT ON COLUMN val_property.property_type IS 'property type for validation purposes';
COMMENT ON COLUMN val_property.account_collection_type IS 'type restriction of the account_collection_id on LHS';
COMMENT ON COLUMN val_property.company_collection_type IS 'type restriction of company_collection_id on LHS';
COMMENT ON COLUMN val_property.device_collection_type IS 'type restriction of device_collection_id on LHS';
COMMENT ON COLUMN val_property.dns_domain_collection_type IS 'type restriction of dns_domain_collection_id restriction on LHS';
COMMENT ON COLUMN val_property.netblock_collection_type IS 'type restriction of netblock_collection_id on LHS';
COMMENT ON COLUMN val_property.property_collection_type IS 'type restriction of property_collection_id on LHS';
COMMENT ON COLUMN val_property.service_env_collection_type IS 'type restriction of service_enviornment_collection_id on LHS';
COMMENT ON COLUMN val_property.is_multivalue IS 'If N, acts like an alternate key on property.(lhs,property_name,property_type)';
COMMENT ON COLUMN val_property.prop_val_acct_coll_type_rstrct IS 'if property_value is account_collection_Id, this limits the account_collection_types that can be used in that column.';
COMMENT ON COLUMN val_property.prop_val_dev_coll_type_rstrct IS 'if property_value is devicet_collection_Id, this limits the devicet_collection_types that can be used in that column.';
COMMENT ON COLUMN val_property.prop_val_nblk_coll_type_rstrct IS 'if property_value isnetblockt_collection_Id, this limits the netblockt_collection_types that can be used in that column.';
COMMENT ON COLUMN val_property.property_data_type IS 'which, if any, of the property_table_* columns should be used for this value.   May turn more complex enforcement via trigger';
COMMENT ON COLUMN val_property.permit_account_collection_id IS 'defines permissibility/requirement of account_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_account_id IS 'defines permissibility/requirement of account_idon LHS of property';
COMMENT ON COLUMN val_property.permit_account_realm_id IS 'defines permissibility/requirement of account_realm_id on LHS of property';
COMMENT ON COLUMN val_property.permit_company_id IS 'defines permissibility/requirement of company_id on LHS of property.  *NOTE*  THIS COLUMN WILL BE REMOVED IN >0.65';
COMMENT ON COLUMN val_property.permit_company_collection_id IS 'defines permissibility/requirement of company_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_device_collection_id IS 'defines permissibility/requirement of device_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_dns_domain_coll_id IS 'defines permissibility/requirement of dns_domain_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_layer2_network_coll_id IS 'defines permissibility/requirement of layer2_network_id on LHS of property';
COMMENT ON COLUMN val_property.permit_layer3_network_coll_id IS 'defines permissibility/requirement of layer3_network_id on LHS of property';
COMMENT ON COLUMN val_property.permit_netblock_collection_id IS 'defines permissibility/requirement of netblock_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_operating_system_id IS 'defines permissibility/requirement of operating_system_id on LHS of property';
COMMENT ON COLUMN val_property.permit_os_snapshot_id IS 'defines permissibility/requirement of operating_system_snapshot_id on LHS of property';
COMMENT ON COLUMN val_property.permit_person_id IS 'defines permissibility/requirement of person_id on LHS of property';
COMMENT ON COLUMN val_property.permit_property_collection_id IS 'defines permissibility/requirement of property_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_service_env_collection IS 'defines permissibility/requirement of service_env_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_site_code IS 'defines permissibility/requirement of site_code on LHS of property';
COMMENT ON COLUMN val_property.permit_property_rank IS 'defines permissibility of property_rank, and if it should be part of the "lhs" of the given property';
-- INDEXES
CREATE INDEX xif10val_property ON val_property USING btree (netblock_collection_type);
CREATE INDEX xif11val_property ON val_property USING btree (property_collection_type);
CREATE INDEX xif12val_property ON val_property USING btree (service_env_collection_type);
CREATE INDEX xif13val_property ON val_property USING btree (layer3_network_collection_type);
CREATE INDEX xif14val_property ON val_property USING btree (layer2_network_collection_type);
CREATE INDEX xif15val_property ON val_property USING btree (network_range_type);
CREATE INDEX xif1val_property ON val_property USING btree (property_data_type);
CREATE INDEX xif2val_property ON val_property USING btree (property_type);
CREATE INDEX xif3val_property ON val_property USING btree (prop_val_acct_coll_type_rstrct);
CREATE INDEX xif4val_property ON val_property USING btree (prop_val_nblk_coll_type_rstrct);
CREATE INDEX xif5val_property ON val_property USING btree (prop_val_dev_coll_type_rstrct);
CREATE INDEX xif6val_property ON val_property USING btree (account_collection_type);
CREATE INDEX xif7val_property ON val_property USING btree (company_collection_type);
CREATE INDEX xif8val_property ON val_property USING btree (device_collection_type);
CREATE INDEX xif9val_property ON val_property USING btree (dns_domain_collection_type);

-- CHECK CONSTRAINTS
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1494616001
	CHECK (permit_dns_domain_coll_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1664370664
	CHECK (permit_network_range_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1804972034
	CHECK (permit_os_snapshot_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_185689986
	CHECK (permit_layer2_network_coll_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_185755522
	CHECK (permit_layer3_network_coll_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2016888554
	CHECK (permit_account_realm_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2139007167
	CHECK (permit_property_rank = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_271462566
	CHECK (permit_property_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_354296970
	CHECK (permit_netblock_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_366948481
	CHECK (permit_company_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_606225804
	CHECK (permit_person_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_cmp_id
	CHECK (permit_company_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_ismulti
	CHECK (is_multivalue = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_osid
	CHECK (permit_operating_system_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pacct_id
	CHECK (permit_account_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdevcol_id
	CHECK (permit_device_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_prodstate
	CHECK (permit_service_env_collection = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pucls_id
	CHECK (permit_account_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_sitec
	CHECK (permit_site_code = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between val_property and property_collection_property
ALTER TABLE property_collection_property
	ADD CONSTRAINT fk_prop_col_propnamtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK between val_property and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK between val_property and val_property_value
ALTER TABLE val_property_value
	ADD CONSTRAINT fk_valproval_namtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);

-- FOREIGN KEYS TO
-- consider FK val_property and val_service_env_coll_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_svcemvcoll_type
	FOREIGN KEY (service_env_collection_type) REFERENCES val_service_env_coll_type(service_env_collection_type);
-- consider FK val_property and val_device_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_val_devcol_typ_rstr_dc
	FOREIGN KEY (prop_val_dev_coll_type_rstrct) REFERENCES val_device_collection_type(device_collection_type);
-- consider FK val_property and val_device_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_val_devcoll_id
	FOREIGN KEY (device_collection_type) REFERENCES val_device_collection_type(device_collection_type);
-- consider FK val_property and val_account_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_acct_coll_type
	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_property and val_company_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_comp_coll_type
	FOREIGN KEY (company_collection_type) REFERENCES val_company_collection_type(company_collection_type);
-- consider FK val_property and val_layer2_network_coll_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_l2netype
	FOREIGN KEY (layer2_network_collection_type) REFERENCES val_layer2_network_coll_type(layer2_network_collection_type);
-- consider FK val_property and val_layer3_network_coll_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_l3netwok_type
	FOREIGN KEY (layer3_network_collection_type) REFERENCES val_layer3_network_coll_type(layer3_network_collection_type);
-- consider FK val_property and val_netblock_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_nblk_coll_type
	FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_property and val_dns_domain_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_property_dnsdomcolltype
	FOREIGN KEY (dns_domain_collection_type) REFERENCES val_dns_domain_collection_type(dns_domain_collection_type);
-- consider FK val_property and val_netblock_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_property_netblkcolltype
	FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_property and val_network_range_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valnetrng_val_prop
	FOREIGN KEY (network_range_type) REFERENCES val_network_range_type(network_range_type);
-- consider FK val_property and val_property_data_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_propdttyp
	FOREIGN KEY (property_data_type) REFERENCES val_property_data_type(property_data_type);
-- consider FK val_property and val_property_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_proptyp
	FOREIGN KEY (property_type) REFERENCES val_property_type(property_type);
-- consider FK val_property and val_account_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_pv_actyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_property and val_property_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_vla_property_val_propcollty
	FOREIGN KEY (property_collection_type) REFERENCES val_property_collection_type(property_collection_type);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_property');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'val_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_property');
DROP TABLE IF EXISTS val_property_v79;
DROP TABLE IF EXISTS audit.val_property_v79;
-- DONE DEALING WITH TABLE val_property
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_sw_package_format

-- FOREIGN KEYS FROM
ALTER TABLE sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_vswpkgfmt;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_sw_package_format');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_sw_package_format DROP CONSTRAINT IF EXISTS pk_val_sw_package_format;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_sw_package_format ON jazzhands.val_sw_package_format;
DROP TRIGGER IF EXISTS trigger_audit_val_sw_package_format ON jazzhands.val_sw_package_format;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_sw_package_format');
---- BEGIN audit.val_sw_package_format TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_sw_package_format');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.val_sw_package_format DROP CONSTRAINT IF EXISTS val_sw_package_format_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_val_sw_package_format_pk_val_sw_package_format";
DROP INDEX IF EXISTS "audit"."val_sw_package_format_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_sw_package_format TEARDOWN


ALTER TABLE val_sw_package_format RENAME TO val_sw_package_format_v79;
ALTER TABLE audit.val_sw_package_format RENAME TO val_sw_package_format_v79;

DROP TABLE IF EXISTS val_sw_package_format_v79;
DROP TABLE IF EXISTS audit.val_sw_package_format_v79;
-- DONE DEALING WITH OLD TABLE val_sw_package_format
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_symbolic_track_name

-- FOREIGN KEYS FROM
ALTER TABLE voe_symbolic_track DROP CONSTRAINT IF EXISTS fk_vsymbtrk_ref_vvsymbtrnm;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_symbolic_track_name');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_symbolic_track_name DROP CONSTRAINT IF EXISTS pk_val_symbolic_track_name;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_symbolic_track_name ON jazzhands.val_symbolic_track_name;
DROP TRIGGER IF EXISTS trigger_audit_val_symbolic_track_name ON jazzhands.val_symbolic_track_name;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_symbolic_track_name');
---- BEGIN audit.val_symbolic_track_name TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_symbolic_track_name');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.val_symbolic_track_name DROP CONSTRAINT IF EXISTS val_symbolic_track_name_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_val_symbolic_track_name_pk_val_symbolic_track_name";
DROP INDEX IF EXISTS "audit"."val_symbolic_track_name_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_symbolic_track_name TEARDOWN


ALTER TABLE val_symbolic_track_name RENAME TO val_symbolic_track_name_v79;
ALTER TABLE audit.val_symbolic_track_name RENAME TO val_symbolic_track_name_v79;

DROP TABLE IF EXISTS val_symbolic_track_name_v79;
DROP TABLE IF EXISTS audit.val_symbolic_track_name_v79;
-- DONE DEALING WITH OLD TABLE val_symbolic_track_name
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_upgrade_severity

-- FOREIGN KEYS FROM
ALTER TABLE voe_relation DROP CONSTRAINT IF EXISTS fk_voe_rltn_ref_vupgsev;
ALTER TABLE voe_symbolic_track DROP CONSTRAINT IF EXISTS fk_voesymbtrk_ref_vupgsev;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_upgrade_severity');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_upgrade_severity DROP CONSTRAINT IF EXISTS pk_val_upgrade_severity;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_upgrade_severity ON jazzhands.val_upgrade_severity;
DROP TRIGGER IF EXISTS trigger_audit_val_upgrade_severity ON jazzhands.val_upgrade_severity;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_upgrade_severity');
---- BEGIN audit.val_upgrade_severity TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_upgrade_severity');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.val_upgrade_severity DROP CONSTRAINT IF EXISTS val_upgrade_severity_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_val_upgrade_severity_pk_val_upgrade_severity";
DROP INDEX IF EXISTS "audit"."val_upgrade_severity_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_upgrade_severity TEARDOWN


ALTER TABLE val_upgrade_severity RENAME TO val_upgrade_severity_v79;
ALTER TABLE audit.val_upgrade_severity RENAME TO val_upgrade_severity_v79;

DROP TABLE IF EXISTS val_upgrade_severity_v79;
DROP TABLE IF EXISTS audit.val_upgrade_severity_v79;
-- DONE DEALING WITH OLD TABLE val_upgrade_severity
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_voe_state

-- FOREIGN KEYS FROM
ALTER TABLE voe DROP CONSTRAINT IF EXISTS fk_voe_ref_vvoestate;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_voe_state');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_voe_state DROP CONSTRAINT IF EXISTS pk_val_voe_state;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_voe_state ON jazzhands.val_voe_state;
DROP TRIGGER IF EXISTS trigger_audit_val_voe_state ON jazzhands.val_voe_state;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_voe_state');
---- BEGIN audit.val_voe_state TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_voe_state');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.val_voe_state DROP CONSTRAINT IF EXISTS val_voe_state_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_val_voe_state_pk_val_voe_state";
DROP INDEX IF EXISTS "audit"."val_voe_state_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_voe_state TEARDOWN


ALTER TABLE val_voe_state RENAME TO val_voe_state_v79;
ALTER TABLE audit.val_voe_state RENAME TO val_voe_state_v79;

DROP TABLE IF EXISTS val_voe_state_v79;
DROP TABLE IF EXISTS audit.val_voe_state_v79;
-- DONE DEALING WITH OLD TABLE val_voe_state
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE account
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'account', 'account');

-- FOREIGN KEYS FROM
ALTER TABLE account_ssh_key DROP CONSTRAINT IF EXISTS fk_account_ssh_key_ssh_key_id;
ALTER TABLE account_assignd_cert DROP CONSTRAINT IF EXISTS fk_acct_asdcrt_acctid;
ALTER TABLE account_token DROP CONSTRAINT IF EXISTS fk_acct_ref_acct_token;
ALTER TABLE account_auth_log DROP CONSTRAINT IF EXISTS fk_acctauthlog_accid;
ALTER TABLE account_password DROP CONSTRAINT IF EXISTS fk_acctpwd_acct_id;
ALTER TABLE account_collection_account DROP CONSTRAINT IF EXISTS fk_acol_account_id;
ALTER TABLE appaal_instance DROP CONSTRAINT IF EXISTS fk_appaal_i_reference_fo_accti;
ALTER TABLE approval_instance_item DROP CONSTRAINT IF EXISTS fk_appinstitm_app_acctid;
ALTER TABLE approval_instance_step DROP CONSTRAINT IF EXISTS fk_appinststep_app_acct_id;
ALTER TABLE approval_instance_step_notify DROP CONSTRAINT IF EXISTS fk_appr_inst_step_notif_acct;
ALTER TABLE account_unix_info DROP CONSTRAINT IF EXISTS fk_auxifo_acct_id;
ALTER TABLE department DROP CONSTRAINT IF EXISTS fk_dept_mgr_acct_id;
ALTER TABLE device_collection_assignd_cert DROP CONSTRAINT IF EXISTS fk_devcolascrt_flownacctid;
ALTER TABLE klogin DROP CONSTRAINT IF EXISTS fk_klgn_acct_dst_id;
ALTER TABLE klogin DROP CONSTRAINT IF EXISTS fk_klgn_acct_id;
ALTER TABLE pseudo_klogin DROP CONSTRAINT IF EXISTS fk_pklgn_acct_dstid;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_acctid;
ALTER TABLE sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_sys_user;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS fk_account_acct_rlm_id;
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS fk_account_acctrole;
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS fk_account_company_person;
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS fk_account_prsn_cmpy_acct;
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS fk_acct_stat_id;
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS fk_acct_vacct_type;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'account');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS ak_acct_acctid_realm_id;
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS ak_uq_account_lgn_realm;
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS pk_account_id;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_account_account_status";
DROP INDEX IF EXISTS "jazzhands"."idx_account_account_tpe";
DROP INDEX IF EXISTS "jazzhands"."xif11account";
DROP INDEX IF EXISTS "jazzhands"."xif12account";
DROP INDEX IF EXISTS "jazzhands"."xif8account";
DROP INDEX IF EXISTS "jazzhands"."xif9account";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.account DROP CONSTRAINT IF EXISTS check_yes_no_355473735;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_account_change_realm_aca_realm ON jazzhands.account;
DROP TRIGGER IF EXISTS trig_add_account_automated_reporting_ac ON jazzhands.account;
DROP TRIGGER IF EXISTS trig_add_automated_ac_on_account ON jazzhands.account;
DROP TRIGGER IF EXISTS trig_rm_account_automated_reporting_ac ON jazzhands.account;
DROP TRIGGER IF EXISTS trig_rm_automated_ac_on_account ON jazzhands.account;
DROP TRIGGER IF EXISTS trig_userlog_account ON jazzhands.account;
DROP TRIGGER IF EXISTS trigger_account_enforce_is_enabled ON jazzhands.account;
DROP TRIGGER IF EXISTS trigger_account_validate_login ON jazzhands.account;
DROP TRIGGER IF EXISTS trigger_audit_account ON jazzhands.account;
DROP TRIGGER IF EXISTS trigger_create_new_unix_account ON jazzhands.account;
DROP TRIGGER IF EXISTS trigger_delete_peraccount_account_collection ON jazzhands.account;
DROP TRIGGER IF EXISTS trigger_update_peraccount_account_collection ON jazzhands.account;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'account');
---- BEGIN audit.account TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'account', 'account');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'account');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.account DROP CONSTRAINT IF EXISTS account_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."account_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."aud_account_ak_acct_acctid_realm_id";
DROP INDEX IF EXISTS "audit"."aud_account_ak_uq_account_lgn_realm";
DROP INDEX IF EXISTS "audit"."aud_account_pk_account_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.account TEARDOWN


ALTER TABLE account RENAME TO account_v79;
ALTER TABLE audit.account RENAME TO account_v79;

CREATE TABLE account
(
	account_id	integer NOT NULL,
	login	varchar(50) NOT NULL,
	person_id	integer NOT NULL,
	company_id	integer NOT NULL,
	is_enabled	character(1) NOT NULL,
	account_realm_id	integer NOT NULL,
	account_status	varchar(50) NOT NULL,
	account_role	varchar(50) NOT NULL,
	account_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	external_id	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'account', false);
ALTER TABLE account
	ALTER account_id
	SET DEFAULT nextval('account_account_id_seq'::regclass);
INSERT INTO account (
	account_id,
	login,
	person_id,
	company_id,
	is_enabled,
	account_realm_id,
	account_status,
	account_role,
	account_type,
	description,
	external_id,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	account_id,
	login,
	person_id,
	company_id,
	is_enabled,
	account_realm_id,
	account_status,
	account_role,
	account_type,
	description,
	NULL,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM account_v79;

INSERT INTO audit.account (
	account_id,
	login,
	person_id,
	company_id,
	is_enabled,
	account_realm_id,
	account_status,
	account_role,
	account_type,
	description,
	external_id,		-- new column (external_id)
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
	account_id,
	login,
	person_id,
	company_id,
	is_enabled,
	account_realm_id,
	account_status,
	account_role,
	account_type,
	description,
	NULL,		-- new column (external_id)
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
FROM audit.account_v79;

ALTER TABLE account
	ALTER account_id
	SET DEFAULT nextval('account_account_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE account ADD CONSTRAINT ak_acct_acctid_realm_id UNIQUE (account_id, account_realm_id);
ALTER TABLE account ADD CONSTRAINT ak_uq_account_lgn_realm UNIQUE (account_realm_id, login);
ALTER TABLE account ADD CONSTRAINT pk_account_id PRIMARY KEY (account_id);

-- Table/Column Comments
COMMENT ON COLUMN account.is_enabled IS 'This column is trigger enforced to match what val_person_status says is the correct value for account_status';
COMMENT ON COLUMN account.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX idx_account_account_status ON account USING btree (account_status);
CREATE INDEX idx_account_account_tpe ON account USING btree (account_type);
CREATE INDEX xif11account ON account USING btree (company_id, person_id);
CREATE INDEX xif12account ON account USING btree (person_id, company_id, account_realm_id);
CREATE INDEX xif8account ON account USING btree (account_realm_id);
CREATE INDEX xif9account ON account USING btree (account_role);

-- CHECK CONSTRAINTS
ALTER TABLE account ADD CONSTRAINT check_yes_no_355473735
	CHECK (is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between account and account_ssh_key
ALTER TABLE account_ssh_key
	ADD CONSTRAINT fk_account_ssh_key_ssh_key_id
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK between account and account_assignd_cert
ALTER TABLE account_assignd_cert
	ADD CONSTRAINT fk_acct_asdcrt_acctid
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK between account and account_token
ALTER TABLE account_token
	ADD CONSTRAINT fk_acct_ref_acct_token
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK between account and account_auth_log
ALTER TABLE account_auth_log
	ADD CONSTRAINT fk_acctauthlog_accid
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK between account and account_password
ALTER TABLE account_password
	ADD CONSTRAINT fk_acctpwd_acct_id
	FOREIGN KEY (account_id, account_realm_id) REFERENCES account(account_id, account_realm_id);
-- consider FK between account and account_collection_account
ALTER TABLE account_collection_account
	ADD CONSTRAINT fk_acol_account_id
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK between account and appaal_instance
ALTER TABLE appaal_instance
	ADD CONSTRAINT fk_appaal_i_reference_fo_accti
	FOREIGN KEY (file_owner_account_id) REFERENCES account(account_id);
-- consider FK between account and approval_instance_item
ALTER TABLE approval_instance_item
	ADD CONSTRAINT fk_appinstitm_app_acctid
	FOREIGN KEY (approved_account_id) REFERENCES account(account_id);
-- consider FK between account and approval_instance_step
ALTER TABLE approval_instance_step
	ADD CONSTRAINT fk_appinststep_app_acct_id
	FOREIGN KEY (approver_account_id) REFERENCES account(account_id);
-- consider FK between account and approval_instance_step_notify
ALTER TABLE approval_instance_step_notify
	ADD CONSTRAINT fk_appr_inst_step_notif_acct
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK between account and account_unix_info
ALTER TABLE account_unix_info
	ADD CONSTRAINT fk_auxifo_acct_id
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK between account and department
ALTER TABLE department
	ADD CONSTRAINT fk_dept_mgr_acct_id
	FOREIGN KEY (manager_account_id) REFERENCES account(account_id);
-- consider FK between account and device_collection_assignd_cert
ALTER TABLE device_collection_assignd_cert
	ADD CONSTRAINT fk_devcolascrt_flownacctid
	FOREIGN KEY (file_owner_account_id) REFERENCES account(account_id);
-- consider FK between account and klogin
ALTER TABLE klogin
	ADD CONSTRAINT fk_klgn_acct_dst_id
	FOREIGN KEY (dest_account_id) REFERENCES account(account_id);
-- consider FK between account and klogin
ALTER TABLE klogin
	ADD CONSTRAINT fk_klgn_acct_id
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK between account and pseudo_klogin
ALTER TABLE pseudo_klogin
	ADD CONSTRAINT fk_pklgn_acct_dstid
	FOREIGN KEY (dest_account_id) REFERENCES account(account_id);
-- consider FK between account and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctid
	FOREIGN KEY (account_id) REFERENCES account(account_id);

-- FOREIGN KEYS TO
-- consider FK account and account_realm
ALTER TABLE account
	ADD CONSTRAINT fk_account_acct_rlm_id
	FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id);
-- consider FK account and val_account_role
ALTER TABLE account
	ADD CONSTRAINT fk_account_acctrole
	FOREIGN KEY (account_role) REFERENCES val_account_role(account_role);
-- consider FK account and person_company
ALTER TABLE account
	ADD CONSTRAINT fk_account_company_person
	FOREIGN KEY (company_id, person_id) REFERENCES person_company(company_id, person_id) DEFERRABLE;
-- consider FK account and person_account_realm_company
ALTER TABLE account
	ADD CONSTRAINT fk_account_prsn_cmpy_acct
	FOREIGN KEY (person_id, company_id, account_realm_id) REFERENCES person_account_realm_company(person_id, company_id, account_realm_id) DEFERRABLE;
-- consider FK account and val_person_status
ALTER TABLE account
	ADD CONSTRAINT fk_acct_stat_id
	FOREIGN KEY (account_status) REFERENCES val_person_status(person_status);
-- consider FK account and val_account_type
ALTER TABLE account
	ADD CONSTRAINT fk_acct_vacct_type
	FOREIGN KEY (account_type) REFERENCES val_account_type(account_type);

-- TRIGGERS
-- consider NEW jazzhands.account_change_realm_aca_realm
CREATE OR REPLACE FUNCTION jazzhands.account_change_realm_aca_realm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_account
			JOIN account_collection USING (account_collection_id)
			JOIN val_account_collection_type vt USING (account_collection_type)
	WHERE	vt.account_realm_id IS NOT NULL
	AND		vt.account_realm_id != NEW.account_realm_id
	AND		account_id = NEW.account_id;

	IF _tally > 0 THEN
		RAISE EXCEPTION 'New account realm (%) is part of % account collections with a type restriction',
			NEW.account_realm_id,
			_tally
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trig_account_change_realm_aca_realm BEFORE UPDATE OF account_realm_id ON account FOR EACH ROW EXECUTE PROCEDURE account_change_realm_aca_realm();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.account_automated_reporting_ac
CREATE OR REPLACE FUNCTION jazzhands.account_automated_reporting_ac()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_numrpt	INTEGER;
	_r		RECORD;
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.account_role != 'primary' THEN
			RETURN OLD;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.account_role != 'primary' AND OLD.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	END IF;

	-- XXX check account realm to see if we should be inserting for this
	-- XXX account realm

	IF TG_OP = 'INSERT' THEN
		PERFORM auto_ac_manip.make_all_auto_acs_right(
			account_id := NEW.account_id,
			account_realm_id := NEW.account_realm_id,
			login := NEW.login
		);
	ELSIF TG_OP = 'UPDATE' THEN
		PERFORM auto_ac_manip.rename_automated_report_acs(
			NEW.account_id, OLD.login, NEW.login, NEW.account_realm_id);
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM account_collection_account WHERE account_id
			= OLD.account_id
		AND account_collection_id IN ( select account_collection_id
			FROM account_collection where account_collection_type
			= 'automated'
		);
		-- PERFORM auto_ac_manip.destroy_report_account_collections(
		-- 	account_id := OLD.account_id,
		-- 	account_realm_id := OLD.account_realm_id
		-- );
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;
CREATE TRIGGER trig_add_account_automated_reporting_ac AFTER INSERT OR UPDATE OF login, account_status ON account FOR EACH ROW EXECUTE PROCEDURE account_automated_reporting_ac();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.automated_ac_on_account
CREATE OR REPLACE FUNCTION jazzhands.automated_ac_on_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_r		RECORD;
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.account_role != 'primary' THEN
			RETURN OLD;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.account_role != 'primary' AND OLD.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	END IF;


	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE'  THEN
		PERFORM auto_ac_manip.make_site_acs_right(NEW.account_id);
		PERFORM auto_ac_manip.make_personal_acs_right(NEW.account_id);

		-- update the person's manager to match
		WITH RECURSIVE map AS (
			SELECT account_id as root_account_id,
				account_id, login, manager_account_id, manager_login
			FROM v_account_manager_map
			UNION
			SELECT map.root_account_id, m.account_id, m.login,
				m.manager_account_id, m.manager_login
				from v_account_manager_map m
					join map on m.account_id = map.manager_account_id
			), x AS ( SELECT auto_ac_manip.make_auto_report_acs_right(
					account_id := manager_account_id,
					account_realm_id := NEW.account_realm_id,
					login := manager_login)
				FROM map
				WHERE root_account_id = NEW.account_id
			) SELECT count(*) INTO _tally FROM x;
	END IF;

	IF TG_OP = 'UPDATE'  THEN
		PERFORM auto_ac_manip.make_site_acs_right(OLD.account_id);
		PERFORM auto_ac_manip.make_personal_acs_right(OLD.account_id);
	END IF;

	-- when deleting, do nothing rather than calling the above, same as
	-- update; pointless because account is getting deleted anyway.

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;
CREATE TRIGGER trig_add_automated_ac_on_account AFTER INSERT OR UPDATE OF account_type, account_role, account_status ON account FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_account();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.account_automated_reporting_ac
CREATE OR REPLACE FUNCTION jazzhands.account_automated_reporting_ac()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_numrpt	INTEGER;
	_r		RECORD;
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.account_role != 'primary' THEN
			RETURN OLD;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.account_role != 'primary' AND OLD.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	END IF;

	-- XXX check account realm to see if we should be inserting for this
	-- XXX account realm

	IF TG_OP = 'INSERT' THEN
		PERFORM auto_ac_manip.make_all_auto_acs_right(
			account_id := NEW.account_id,
			account_realm_id := NEW.account_realm_id,
			login := NEW.login
		);
	ELSIF TG_OP = 'UPDATE' THEN
		PERFORM auto_ac_manip.rename_automated_report_acs(
			NEW.account_id, OLD.login, NEW.login, NEW.account_realm_id);
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM account_collection_account WHERE account_id
			= OLD.account_id
		AND account_collection_id IN ( select account_collection_id
			FROM account_collection where account_collection_type
			= 'automated'
		);
		-- PERFORM auto_ac_manip.destroy_report_account_collections(
		-- 	account_id := OLD.account_id,
		-- 	account_realm_id := OLD.account_realm_id
		-- );
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;
CREATE TRIGGER trig_rm_account_automated_reporting_ac BEFORE DELETE ON account FOR EACH ROW EXECUTE PROCEDURE account_automated_reporting_ac();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.automated_ac_on_account
CREATE OR REPLACE FUNCTION jazzhands.automated_ac_on_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_r		RECORD;
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.account_role != 'primary' THEN
			RETURN OLD;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.account_role != 'primary' AND OLD.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	END IF;


	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE'  THEN
		PERFORM auto_ac_manip.make_site_acs_right(NEW.account_id);
		PERFORM auto_ac_manip.make_personal_acs_right(NEW.account_id);

		-- update the person's manager to match
		WITH RECURSIVE map AS (
			SELECT account_id as root_account_id,
				account_id, login, manager_account_id, manager_login
			FROM v_account_manager_map
			UNION
			SELECT map.root_account_id, m.account_id, m.login,
				m.manager_account_id, m.manager_login
				from v_account_manager_map m
					join map on m.account_id = map.manager_account_id
			), x AS ( SELECT auto_ac_manip.make_auto_report_acs_right(
					account_id := manager_account_id,
					account_realm_id := NEW.account_realm_id,
					login := manager_login)
				FROM map
				WHERE root_account_id = NEW.account_id
			) SELECT count(*) INTO _tally FROM x;
	END IF;

	IF TG_OP = 'UPDATE'  THEN
		PERFORM auto_ac_manip.make_site_acs_right(OLD.account_id);
		PERFORM auto_ac_manip.make_personal_acs_right(OLD.account_id);
	END IF;

	-- when deleting, do nothing rather than calling the above, same as
	-- update; pointless because account is getting deleted anyway.

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;
CREATE TRIGGER trig_rm_automated_ac_on_account BEFORE DELETE ON account FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_account();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.account_enforce_is_enabled
CREATE OR REPLACE FUNCTION jazzhands.account_enforce_is_enabled()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	correctval	char(1);
BEGIN
	SELECT is_enabled INTO correctval
	FROM val_person_status
	WHERE person_status = NEW.account_status;

	IF TG_OP = 'INSERT' THEN
		IF NEW.is_enabled is NULL THEN
			NEW.is_enabled = correctval;
		ELSIF NEW.is_enabled != correctval THEN
			RAISE EXCEPTION 'May not set IS_ENABLED to an invalid value (%) for given account_status: %', NEW.is_enabled, NEW.account_status
				USING errcode = 'integrity_constraint_violation';
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.account_status != OLD.account_status THEN
			IF NEW.is_enabled != correctval THEN
				NEW.is_enabled := correctval;
			END IF;
		ELSIF NEW.is_enabled != correctval THEN
			RAISE EXCEPTION 'May not update IS_ENABLED to an invalid value (%->%) for given account_status: %', OLD.account_status, NEW.account_status, NEW.is_enabled
			USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_account_enforce_is_enabled BEFORE INSERT OR UPDATE OF account_status, is_enabled ON account FOR EACH ROW EXECUTE PROCEDURE account_enforce_is_enabled();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.account_status_after_hooks
CREATE OR REPLACE FUNCTION jazzhands.account_status_after_hooks()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	BEGIN
		PERFORM local_hooks.account_status_after_hooks();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
	RETURN NULL;
END;
$function$
;
CREATE TRIGGER trigger_account_status_after_hooks AFTER UPDATE OF account_status ON account FOR EACH ROW EXECUTE PROCEDURE account_status_after_hooks();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.account_validate_login
CREATE OR REPLACE FUNCTION jazzhands.account_validate_login()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	regexp		text;
	correctval	char(1);
BEGIN
	SELECT property_value
	INTO   regexp
	FROM	property
	WHERE	account_realm_id = NEW.account_realm_id
	AND		property_name = 'login_restriction'
	AND		property_type = 'Defaults';

	IF FOUND THEN
		-- ~ '[^-/@a-z0-9_]+' THEN
		IF NEW.login  ~ regexp THEN
			RAISE EXCEPTION 'May not set login to an invalid value (%)', NEW.login
				USING errcode = 'integrity_constraint_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_account_validate_login BEFORE INSERT OR UPDATE OF login ON account FOR EACH ROW EXECUTE PROCEDURE account_validate_login();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.create_new_unix_account
CREATE OR REPLACE FUNCTION jazzhands.create_new_unix_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	unix_id 		INTEGER;
	_account_collection_id 	INTEGER;
	_arid			INTEGER;
BEGIN
	--
	-- This should be a property that shows which account collections
	-- get unix accounts created by default, but the mapping of unix-groups
	-- to account collection across realms needs to be resolved
	--
	SELECT  account_realm_id
	INTO    _arid
	FROM    property
	WHERE   property_name = '_root_account_realm_id'
	AND     property_type = 'Defaults';

	IF _arid IS NOT NULL AND NEW.account_realm_id = _arid THEN
		IF NEW.person_id != 0 THEN
			PERFORM person_manip.setup_unix_account(
				in_account_id := NEW.account_id,
				in_account_type := NEW.account_type
			);
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_create_new_unix_account AFTER INSERT ON account FOR EACH ROW EXECUTE PROCEDURE create_new_unix_account();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.delete_peraccount_account_collection
CREATE OR REPLACE FUNCTION jazzhands.delete_peraccount_account_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	acid			account_collection.account_collection_id%TYPE;
BEGIN
	IF TG_OP = 'DELETE' THEN
		SELECT	account_collection_id
		  INTO	acid
		  FROM	account_collection ac
				INNER JOIN account_collection_account aca
					USING (account_collection_id)
		 WHERE	aca.account_id = OLD.account_Id
		   AND	ac.account_collection_type = 'per-account';

		IF acid is NOT NULL THEN
			DELETE from account_collection_account
			where account_collection_id = acid;

			DELETE from account_collection
			where account_collection_id = acid;
		END IF;
	END IF;
	RETURN OLD;
END;
$function$
;
CREATE TRIGGER trigger_delete_peraccount_account_collection BEFORE DELETE ON account FOR EACH ROW EXECUTE PROCEDURE delete_peraccount_account_collection();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.update_peraccount_account_collection
CREATE OR REPLACE FUNCTION jazzhands.update_peraccount_account_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	def_acct_rlm	account_realm.account_realm_id%TYPE;
	acid			account_collection.account_collection_id%TYPE;
DECLARE
	newname	TEXT;
BEGIN
	newname = concat(NEW.login, '_', NEW.account_id);
	if TG_OP = 'INSERT' THEN
		insert into account_collection
			(account_collection_name, account_collection_type)
		values
			(newname, 'per-account')
		RETURNING account_collection_id INTO acid;
		insert into account_collection_account
			(account_collection_id, account_id)
		VALUES
			(acid, NEW.account_id);
	END IF;

	IF TG_OP = 'UPDATE' AND OLD.login != NEW.login THEN
		UPDATE	account_collection
		    set	account_collection_name = newname
		  where	account_collection_type = 'per-account'
		    and	account_collection_id = (
				SELECT	account_collection_id
		  		FROM	account_collection ac
						INNER JOIN account_collection_account aca
							USING (account_collection_id)
		 		WHERE	aca.account_id = OLD.account_Id
		   		AND	ac.account_collection_type = 'per-account'
			);
	END IF;
	return NEW;
END;
$function$
;
CREATE TRIGGER trigger_update_peraccount_account_collection AFTER INSERT OR UPDATE ON account FOR EACH ROW EXECUTE PROCEDURE update_peraccount_account_collection();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'account');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'account');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'account');
ALTER SEQUENCE account_account_id_seq
	 OWNED BY account.account_id;
DROP TABLE IF EXISTS account_v79;
DROP TABLE IF EXISTS audit.account_v79;
-- DONE DEALING WITH TABLE account
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE account_collection
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_collection', 'account_collection');

-- FOREIGN KEYS FROM
ALTER TABLE sudo_acct_col_device_collectio DROP CONSTRAINT IF EXISTS fk_acctcol_ref_sudoaccldcl_ra;
ALTER TABLE account_collection_account DROP CONSTRAINT IF EXISTS fk_acctcol_usr_ucol_id;
ALTER TABLE account_collection_hier DROP CONSTRAINT IF EXISTS fk_acctcolhier_acctcolid;
ALTER TABLE account_collection_hier DROP CONSTRAINT IF EXISTS fk_acctcolhier_cldacctcolid;
ALTER TABLE appaal_instance DROP CONSTRAINT IF EXISTS fk_appaal_inst_filgrpacctcolid;
ALTER TABLE account_unix_info DROP CONSTRAINT IF EXISTS fk_auxifo_unxgrp_acctcolid;
ALTER TABLE department DROP CONSTRAINT IF EXISTS fk_dept_usr_col_id;
ALTER TABLE device_collection_ssh_key DROP CONSTRAINT IF EXISTS fk_dev_coll_ssh_key_acct_col;
ALTER TABLE device_collection_assignd_cert DROP CONSTRAINT IF EXISTS fk_devcol_asscrt_acctcolid;
ALTER TABLE klogin DROP CONSTRAINT IF EXISTS fk_klogin_ref_acct_col_id;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_acct_col;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_pval_acct_colid;
ALTER TABLE sudo_acct_col_device_collectio DROP CONSTRAINT IF EXISTS fk_sudoaccoll_fk_sudo_u_actcl;
ALTER TABLE unix_group DROP CONSTRAINT IF EXISTS fk_unxgrp_uclsid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.account_collection DROP CONSTRAINT IF EXISTS fk_acctcol_usrcoltyp;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'account_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.account_collection DROP CONSTRAINT IF EXISTS pk_account_collection;
ALTER TABLE jazzhands.account_collection DROP CONSTRAINT IF EXISTS uq_acct_collection_name;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_acctcol_acctcoltype";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_account_collection_realm ON jazzhands.account_collection;
DROP TRIGGER IF EXISTS trig_userlog_account_collection ON jazzhands.account_collection;
DROP TRIGGER IF EXISTS trigger_audit_account_collection ON jazzhands.account_collection;
DROP TRIGGER IF EXISTS trigger_validate_account_collection_type_change ON jazzhands.account_collection;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'account_collection');
---- BEGIN audit.account_collection TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'account_collection', 'account_collection');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'account_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.account_collection DROP CONSTRAINT IF EXISTS account_collection_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."account_collection_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."aud_account_collection_pk_account_collection";
DROP INDEX IF EXISTS "audit"."aud_account_collection_uq_acct_collection_name";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.account_collection TEARDOWN


ALTER TABLE account_collection RENAME TO account_collection_v79;
ALTER TABLE audit.account_collection RENAME TO account_collection_v79;

CREATE TABLE account_collection
(
	account_collection_id	integer NOT NULL,
	account_collection_name	varchar(255) NOT NULL,
	account_collection_type	varchar(50) NOT NULL,
	external_id	varchar(255)  NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'account_collection', false);
ALTER TABLE account_collection
	ALTER account_collection_id
	SET DEFAULT nextval('account_collection_account_collection_id_seq'::regclass);
INSERT INTO account_collection (
	account_collection_id,
	account_collection_name,
	account_collection_type,
	external_id,		-- new column (external_id)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	account_collection_id,
	account_collection_name,
	account_collection_type,
	NULL,		-- new column (external_id)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM account_collection_v79;

INSERT INTO audit.account_collection (
	account_collection_id,
	account_collection_name,
	account_collection_type,
	external_id,		-- new column (external_id)
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
	account_collection_id,
	account_collection_name,
	account_collection_type,
	NULL,		-- new column (external_id)
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
FROM audit.account_collection_v79;

ALTER TABLE account_collection
	ALTER account_collection_id
	SET DEFAULT nextval('account_collection_account_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE account_collection ADD CONSTRAINT pk_account_collection PRIMARY KEY (account_collection_id);
ALTER TABLE account_collection ADD CONSTRAINT uq_acct_collection_name UNIQUE (account_collection_name, account_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN account_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX xif_acctcol_acctcoltype ON account_collection USING btree (account_collection_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between account_collection and sudo_acct_col_device_collectio
ALTER TABLE sudo_acct_col_device_collectio
	ADD CONSTRAINT fk_acctcol_ref_sudoaccldcl_ra
	FOREIGN KEY (run_as_account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK between account_collection and account_collection_account
ALTER TABLE account_collection_account
	ADD CONSTRAINT fk_acctcol_usr_ucol_id
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK between account_collection and account_collection_hier
ALTER TABLE account_collection_hier
	ADD CONSTRAINT fk_acctcolhier_acctcolid
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK between account_collection and account_collection_hier
ALTER TABLE account_collection_hier
	ADD CONSTRAINT fk_acctcolhier_cldacctcolid
	FOREIGN KEY (child_account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK between account_collection and appaal_instance
ALTER TABLE appaal_instance
	ADD CONSTRAINT fk_appaal_inst_filgrpacctcolid
	FOREIGN KEY (file_group_acct_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK between account_collection and account_unix_info
ALTER TABLE account_unix_info
	ADD CONSTRAINT fk_auxifo_unxgrp_acctcolid
	FOREIGN KEY (unix_group_acct_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK between account_collection and department
ALTER TABLE department
	ADD CONSTRAINT fk_dept_usr_col_id
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK between account_collection and device_collection_ssh_key
ALTER TABLE device_collection_ssh_key
	ADD CONSTRAINT fk_dev_coll_ssh_key_acct_col
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK between account_collection and device_collection_assignd_cert
ALTER TABLE device_collection_assignd_cert
	ADD CONSTRAINT fk_devcol_asscrt_acctcolid
	FOREIGN KEY (file_group_acct_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK between account_collection and klogin
ALTER TABLE klogin
	ADD CONSTRAINT fk_klogin_ref_acct_col_id
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK between account_collection and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_acct_col
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK between account_collection and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_acct_colid
	FOREIGN KEY (property_value_account_coll_id) REFERENCES account_collection(account_collection_id);
-- consider FK between account_collection and sudo_acct_col_device_collectio
ALTER TABLE sudo_acct_col_device_collectio
	ADD CONSTRAINT fk_sudoaccoll_fk_sudo_u_actcl
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK between account_collection and unix_group
ALTER TABLE unix_group
	ADD CONSTRAINT fk_unxgrp_uclsid
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);

-- FOREIGN KEYS TO
-- consider FK account_collection and val_account_collection_type
ALTER TABLE account_collection
	ADD CONSTRAINT fk_acctcol_usrcoltyp
	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);

-- TRIGGERS
-- consider NEW jazzhands.account_collection_realm
CREATE OR REPLACE FUNCTION jazzhands.account_collection_realm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_at		val_account_collection_type%ROWTYPE;
	_tally	integer;
BEGIN
	SELECT * INTO _at FROM val_account_collection_type
	WHERE account_collection_type = NEW.account_collection_type;

	IF _at.account_realm_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_account
			JOIN account a USING (account_id)
	WHERE	account_collection_id = NEW.account_collection_id
	AND		a.account_realm_id != _at.account_realm_id;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Unable to set account_realm restriction because there are accounts assigned that do not match it'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_hier h
			JOIN account_collection pac USING (account_collection_id)
			JOIN val_account_collection_type pat USING (account_collection_type)
			JOIN account_collection cac ON
				h.child_account_collection_id = cac.account_collection_id
			JOIN val_account_collection_type cat ON
				cac.account_collection_type = cat.account_collection_type
	WHERE	(
				pac.account_collection_id = NEW.account_collection_id
			OR		cac.account_collection_id = NEW.account_collection_id
			)
	AND		pat.account_realm_id IS DISTINCT FROM cat.account_realm_id
	;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Unable to set account_realm restriction because there are account collections in the hierarchy that do not match'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trig_account_collection_realm AFTER UPDATE OF account_collection_type ON account_collection FOR EACH ROW EXECUTE PROCEDURE account_collection_realm();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.validate_account_collection_type_change
CREATE OR REPLACE FUNCTION jazzhands.validate_account_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.account_collection_type != NEW.account_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.account_collection_type = OLD.account_collection_type
		AND	p.account_collection_id = NEW.account_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'account_collection % of type % is used by % restricted properties.',
				NEW.account_collection_id, NEW.account_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_validate_account_collection_type_change BEFORE UPDATE OF account_collection_type ON account_collection FOR EACH ROW EXECUTE PROCEDURE validate_account_collection_type_change();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'account_collection');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'account_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'account_collection');
ALTER SEQUENCE account_collection_account_collection_id_seq
	 OWNED BY account_collection.account_collection_id;
DROP TABLE IF EXISTS account_collection_v79;
DROP TABLE IF EXISTS audit.account_collection_v79;
-- DONE DEALING WITH TABLE account_collection
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE company
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'company', 'company');

-- FOREIGN KEYS FROM
ALTER TABLE account_realm_company DROP CONSTRAINT IF EXISTS fk_acct_rlm_cmpy_cmpy_id;
ALTER TABLE circuit DROP CONSTRAINT IF EXISTS fk_circuit_aloc_companyid;
ALTER TABLE circuit DROP CONSTRAINT IF EXISTS fk_circuit_vend_companyid;
ALTER TABLE circuit DROP CONSTRAINT IF EXISTS fk_circuit_zloc_company_id;
ALTER TABLE company_collection_company DROP CONSTRAINT IF EXISTS fk_company_coll_company_id;
ALTER TABLE company_type DROP CONSTRAINT IF EXISTS fk_company_type_company_id;
ALTER TABLE component_type DROP CONSTRAINT IF EXISTS fk_component_type_company_id;
ALTER TABLE contract DROP CONSTRAINT IF EXISTS fk_contract_company_id;
ALTER TABLE department DROP CONSTRAINT IF EXISTS fk_dept_company;
ALTER TABLE device_type DROP CONSTRAINT IF EXISTS fk_devtyp_company;
ALTER TABLE netblock DROP CONSTRAINT IF EXISTS fk_netblock_company;
ALTER TABLE operating_system DROP CONSTRAINT IF EXISTS fk_os_company;
ALTER TABLE person_company DROP CONSTRAINT IF EXISTS fk_person_company_company_id;
ALTER TABLE physical_address DROP CONSTRAINT IF EXISTS fk_physaddr_company_id;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_compid;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_pval_compid;
ALTER TABLE person_contact DROP CONSTRAINT IF EXISTS fk_prsn_contect_cr_cmpyid;
ALTER TABLE site DROP CONSTRAINT IF EXISTS fk_site_colo_company_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.company DROP CONSTRAINT IF EXISTS fk_company_parent_company_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'company');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.company DROP CONSTRAINT IF EXISTS pk_company;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1company";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.company DROP CONSTRAINT IF EXISTS ckc_cmpy_shrt_name_195335815;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_company ON jazzhands.company;
DROP TRIGGER IF EXISTS trigger_audit_company ON jazzhands.company;
DROP TRIGGER IF EXISTS trigger_company_insert_function_nudge ON jazzhands.company;
DROP TRIGGER IF EXISTS trigger_delete_per_company_company_collection ON jazzhands.company;
DROP TRIGGER IF EXISTS trigger_update_per_company_company_collection ON jazzhands.company;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'company');
---- BEGIN audit.company TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'company', 'company');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'company');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.company DROP CONSTRAINT IF EXISTS company_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_company_pk_company";
DROP INDEX IF EXISTS "audit"."company_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.company TEARDOWN


ALTER TABLE company RENAME TO company_v79;
ALTER TABLE audit.company RENAME TO company_v79;

CREATE TABLE company
(
	company_id	integer NOT NULL,
	company_name	varchar(255) NOT NULL,
	company_short_name	varchar(50)  NULL,
	parent_company_id	integer  NULL,
	description	varchar(4000)  NULL,
	external_id	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'company', false);
ALTER TABLE company
	ALTER company_id
	SET DEFAULT nextval('company_company_id_seq'::regclass);
INSERT INTO company (
	company_id,
	company_name,
	company_short_name,
	parent_company_id,
	description,
	external_id,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	company_id,
	company_name,
	company_short_name,
	parent_company_id,
	description,
	NULL,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM company_v79;

INSERT INTO audit.company (
	company_id,
	company_name,
	company_short_name,
	parent_company_id,
	description,
	external_id,		-- new column (external_id)
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
	company_id,
	company_name,
	company_short_name,
	parent_company_id,
	description,
	NULL,		-- new column (external_id)
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
FROM audit.company_v79;

ALTER TABLE company
	ALTER company_id
	SET DEFAULT nextval('company_company_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE company ADD CONSTRAINT pk_company PRIMARY KEY (company_id);

-- Table/Column Comments
COMMENT ON COLUMN company.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX xif1company ON company USING btree (parent_company_id);

-- CHECK CONSTRAINTS
ALTER TABLE company ADD CONSTRAINT ckc_cmpy_shrt_name_195335815
	CHECK (((company_short_name)::text = lower((company_short_name)::text)) AND ((company_short_name)::text !~~ '% %'::text));

-- FOREIGN KEYS FROM
-- consider FK between company and account_realm_company
ALTER TABLE account_realm_company
	ADD CONSTRAINT fk_acct_rlm_cmpy_cmpy_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK between company and circuit
ALTER TABLE circuit
	ADD CONSTRAINT fk_circuit_aloc_companyid
	FOREIGN KEY (aloc_lec_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK between company and circuit
ALTER TABLE circuit
	ADD CONSTRAINT fk_circuit_vend_companyid
	FOREIGN KEY (vendor_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK between company and circuit
ALTER TABLE circuit
	ADD CONSTRAINT fk_circuit_zloc_company_id
	FOREIGN KEY (zloc_lec_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK between company and company_collection_company
ALTER TABLE company_collection_company
	ADD CONSTRAINT fk_company_coll_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id);
-- consider FK between company and company_type
ALTER TABLE company_type
	ADD CONSTRAINT fk_company_type_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK between company and component_type
ALTER TABLE component_type
	ADD CONSTRAINT fk_component_type_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id);
-- consider FK between company and contract
ALTER TABLE contract
	ADD CONSTRAINT fk_contract_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK between company and department
ALTER TABLE department
	ADD CONSTRAINT fk_dept_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK between company and device_type
ALTER TABLE device_type
	ADD CONSTRAINT fk_devtyp_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK between company and netblock
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblock_company
	FOREIGN KEY (nic_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK between company and operating_system
ALTER TABLE operating_system
	ADD CONSTRAINT fk_os_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK between company and person_company
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK between company and physical_address
ALTER TABLE physical_address
	ADD CONSTRAINT fk_physaddr_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK between company and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_compid
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK between company and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_compid
	FOREIGN KEY (property_value_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK between company and person_contact
ALTER TABLE person_contact
	ADD CONSTRAINT fk_prsn_contect_cr_cmpyid
	FOREIGN KEY (person_contact_cr_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK between company and site
ALTER TABLE site
	ADD CONSTRAINT fk_site_colo_company_id
	FOREIGN KEY (colo_company_id) REFERENCES company(company_id) DEFERRABLE;

-- FOREIGN KEYS TO
-- consider FK company and company
ALTER TABLE company
	ADD CONSTRAINT fk_company_parent_company_id
	FOREIGN KEY (parent_company_id) REFERENCES company(company_id) DEFERRABLE;

-- TRIGGERS
-- consider NEW jazzhands.company_insert_function_nudge
CREATE OR REPLACE FUNCTION jazzhands.company_insert_function_nudge()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	BEGIN
		IF current_setting('jazzhands.permit_company_insert') != 'permit' THEN
			RAISE EXCEPTION  'You may not directly insert into company.'
				USING ERRCODE = 'insufficient_privilege';
		END IF;
	EXCEPTION WHEN undefined_object THEN
			RAISE EXCEPTION  'You may not directly insert into company'
				USING ERRCODE = 'insufficient_privilege';
	END;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_company_insert_function_nudge BEFORE INSERT ON company FOR EACH ROW EXECUTE PROCEDURE company_insert_function_nudge();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.delete_per_company_company_collection
CREATE OR REPLACE FUNCTION jazzhands.delete_per_company_company_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dcid			company_collection.company_collection_id%TYPE;
BEGIN
	SELECT	company_collection_id
	  FROM  company_collection
	  INTO	dcid
	 WHERE	company_collection_type = 'per-company'
	   AND	company_collection_id in
		(select company_collection_id
		 from company_collection_company
		where company_id = OLD.company_id
		)
	ORDER BY company_collection_id
	LIMIT 1;

	IF dcid IS NOT NULL THEN
		DELETE FROM company_collection_company
		WHERE company_collection_id = dcid;

		DELETE from company_collection
		WHERE company_collection_id = dcid;
	END IF;

	RETURN OLD;
END;
$function$
;
CREATE TRIGGER trigger_delete_per_company_company_collection BEFORE DELETE ON company FOR EACH ROW EXECUTE PROCEDURE delete_per_company_company_collection();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.update_per_company_company_collection
CREATE OR REPLACE FUNCTION jazzhands.update_per_company_company_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dcid		company_collection.company_collection_id%TYPE;
	newname		company_collection.company_collection_name%TYPE;
BEGIN
	IF NEW.company_name IS NOT NULL THEN
		newname = NEW.company_name || '_' || NEW.company_id;
	ELSE
		newname = 'per_d_dc_contrived_' || NEW.company_id;
	END IF;

	IF TG_OP = 'INSERT' THEN
		insert into company_collection
			(company_collection_name, company_collection_type)
		values
			(newname, 'per-company')
		RETURNING company_collection_id INTO dcid;
		insert into company_collection_company
			(company_collection_id, company_id)
		VALUES
			(dcid, NEW.company_id);
	ELSIF TG_OP = 'UPDATE'  THEN
		UPDATE	company_collection
		   SET	company_collection_name = newname
		 WHERE	company_collection_name != newname
		   AND	company_collection_type = 'per-company'
		   AND	company_collection_id in (
			SELECT	company_collection_id
			  FROM	company_collection_company
			 WHERE	company_id = NEW.company_id
			);
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_update_per_company_company_collection AFTER INSERT OR UPDATE ON company FOR EACH ROW EXECUTE PROCEDURE update_per_company_company_collection();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'company');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'company');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'company');
ALTER SEQUENCE company_company_id_seq
	 OWNED BY company.company_id;
DROP TABLE IF EXISTS company_v79;
DROP TABLE IF EXISTS audit.company_v79;
-- DONE DEALING WITH TABLE company
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE company_collection
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'company_collection', 'company_collection');

-- FOREIGN KEYS FROM
ALTER TABLE company_collection_hier DROP CONSTRAINT IF EXISTS fk_comp_coll_comp_coll_id;
ALTER TABLE company_collection_hier DROP CONSTRAINT IF EXISTS fk_comp_coll_comp_coll_kid_id;
ALTER TABLE company_collection_company DROP CONSTRAINT IF EXISTS fk_company_coll_company_coll_i;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_prop_compcoll_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.company_collection DROP CONSTRAINT IF EXISTS fk_comp_coll_com_coll_type;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'company_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.company_collection DROP CONSTRAINT IF EXISTS ak_company_collection_namtyp;
ALTER TABLE jazzhands.company_collection DROP CONSTRAINT IF EXISTS pk_company_collection;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifcomp_coll_com_coll_type";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_company_collection ON jazzhands.company_collection;
DROP TRIGGER IF EXISTS trigger_audit_company_collection ON jazzhands.company_collection;
DROP TRIGGER IF EXISTS trigger_validate_company_collection_type_change ON jazzhands.company_collection;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'company_collection');
---- BEGIN audit.company_collection TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'company_collection', 'company_collection');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'company_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.company_collection DROP CONSTRAINT IF EXISTS company_collection_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_company_collection_ak_company_collection_namtyp";
DROP INDEX IF EXISTS "audit"."aud_company_collection_pk_company_collection";
DROP INDEX IF EXISTS "audit"."company_collection_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.company_collection TEARDOWN


ALTER TABLE company_collection RENAME TO company_collection_v79;
ALTER TABLE audit.company_collection RENAME TO company_collection_v79;

CREATE TABLE company_collection
(
	company_collection_id	integer NOT NULL,
	company_collection_name	varchar(255) NOT NULL,
	company_collection_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	external_id	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'company_collection', false);
ALTER TABLE company_collection
	ALTER company_collection_id
	SET DEFAULT nextval('company_collection_company_collection_id_seq'::regclass);
INSERT INTO company_collection (
	company_collection_id,
	company_collection_name,
	company_collection_type,
	description,
	external_id,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	company_collection_id,
	company_collection_name,
	company_collection_type,
	description,
	NULL,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM company_collection_v79;

INSERT INTO audit.company_collection (
	company_collection_id,
	company_collection_name,
	company_collection_type,
	description,
	external_id,		-- new column (external_id)
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
	company_collection_id,
	company_collection_name,
	company_collection_type,
	description,
	NULL,		-- new column (external_id)
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
FROM audit.company_collection_v79;

ALTER TABLE company_collection
	ALTER company_collection_id
	SET DEFAULT nextval('company_collection_company_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE company_collection ADD CONSTRAINT ak_company_collection_namtyp UNIQUE (company_collection_name, company_collection_type);
ALTER TABLE company_collection ADD CONSTRAINT pk_company_collection PRIMARY KEY (company_collection_id);

-- Table/Column Comments
COMMENT ON COLUMN company_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX xifcomp_coll_com_coll_type ON company_collection USING btree (company_collection_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between company_collection and company_collection_hier
ALTER TABLE company_collection_hier
	ADD CONSTRAINT fk_comp_coll_comp_coll_id
	FOREIGN KEY (company_collection_id) REFERENCES company_collection(company_collection_id);
-- consider FK between company_collection and company_collection_hier
ALTER TABLE company_collection_hier
	ADD CONSTRAINT fk_comp_coll_comp_coll_kid_id
	FOREIGN KEY (child_company_collection_id) REFERENCES company_collection(company_collection_id);
-- consider FK between company_collection and company_collection_company
ALTER TABLE company_collection_company
	ADD CONSTRAINT fk_company_coll_company_coll_i
	FOREIGN KEY (company_collection_id) REFERENCES company_collection(company_collection_id);
-- consider FK between company_collection and property
ALTER TABLE property
	ADD CONSTRAINT fk_prop_compcoll_id
	FOREIGN KEY (company_collection_id) REFERENCES company_collection(company_collection_id);

-- FOREIGN KEYS TO
-- consider FK company_collection and val_company_collection_type
ALTER TABLE company_collection
	ADD CONSTRAINT fk_comp_coll_com_coll_type
	FOREIGN KEY (company_collection_type) REFERENCES val_company_collection_type(company_collection_type);

-- TRIGGERS
-- consider NEW jazzhands.validate_company_collection_type_change
CREATE OR REPLACE FUNCTION jazzhands.validate_company_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.company_collection_type != NEW.company_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.company_collection_type = OLD.company_collection_type
		AND	p.company_collection_id = NEW.company_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'company_collection % of type % is used by % restricted properties.',
				NEW.company_collection_id, NEW.company_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_validate_company_collection_type_change BEFORE UPDATE OF company_collection_type ON company_collection FOR EACH ROW EXECUTE PROCEDURE validate_company_collection_type_change();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'company_collection');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'company_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'company_collection');
ALTER SEQUENCE company_collection_company_collection_id_seq
	 OWNED BY company_collection.company_collection_id;
DROP TABLE IF EXISTS company_collection_v79;
DROP TABLE IF EXISTS audit.company_collection_v79;
-- DONE DEALING WITH TABLE company_collection
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE department
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'department', 'department');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_badge_type;
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_company;
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_mgr_acct_id;
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_usr_col_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'department');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS pk_deptid;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_dept_deptcode_companyid";
DROP INDEX IF EXISTS "jazzhands"."xif6department";
DROP INDEX IF EXISTS "jazzhands"."xifdept_badge_type";
DROP INDEX IF EXISTS "jazzhands"."xifdept_company";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS ckc_is_active_dept;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_department ON jazzhands.department;
DROP TRIGGER IF EXISTS trigger_audit_department ON jazzhands.department;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'department');
---- BEGIN audit.department TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'department', 'department');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'department');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.department DROP CONSTRAINT IF EXISTS department_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_department_pk_deptid";
DROP INDEX IF EXISTS "audit"."department_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.department TEARDOWN


ALTER TABLE department RENAME TO department_v79;
ALTER TABLE audit.department RENAME TO department_v79;

CREATE TABLE department
(
	account_collection_id	integer NOT NULL,
	company_id	integer NOT NULL,
	manager_account_id	integer  NULL,
	is_active	character(1) NOT NULL,
	dept_code	varchar(30)  NULL,
	cost_center_name	varchar(255)  NULL,
	cost_center_number	integer  NULL,
	default_badge_type_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'department', false);
ALTER TABLE department
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
INSERT INTO department (
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center_name,
	cost_center_number,
	default_badge_type_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center_name,
	cost_center_number,
	default_badge_type_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM department_v79;

INSERT INTO audit.department (
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center_name,
	cost_center_number,
	default_badge_type_id,
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
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center_name,
	cost_center_number,
	default_badge_type_id,
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
FROM audit.department_v79;

ALTER TABLE department
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE department ADD CONSTRAINT pk_deptid PRIMARY KEY (account_collection_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX idx_dept_deptcode_companyid ON department USING btree (dept_code, company_id);
CREATE INDEX xif6department ON department USING btree (manager_account_id);
CREATE INDEX xifdept_badge_type ON department USING btree (default_badge_type_id);
CREATE INDEX xifdept_company ON department USING btree (company_id);

-- CHECK CONSTRAINTS
ALTER TABLE department ADD CONSTRAINT ckc_is_active_dept
	CHECK ((is_active = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_active)::text = upper((is_active)::text)));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK department and badge_type
ALTER TABLE department
	ADD CONSTRAINT fk_dept_badge_type
	FOREIGN KEY (default_badge_type_id) REFERENCES badge_type(badge_type_id);
-- consider FK department and company
ALTER TABLE department
	ADD CONSTRAINT fk_dept_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK department and account
ALTER TABLE department
	ADD CONSTRAINT fk_dept_mgr_acct_id
	FOREIGN KEY (manager_account_id) REFERENCES account(account_id);
-- consider FK department and account_collection
ALTER TABLE department
	ADD CONSTRAINT fk_dept_usr_col_id
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'department');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'department');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'department');
DROP TABLE IF EXISTS department_v79;
DROP TABLE IF EXISTS audit.department_v79;
-- DONE DEALING WITH TABLE department
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE device
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device', 'device');

-- FOREIGN KEYS FROM
ALTER TABLE chassis_location DROP CONSTRAINT IF EXISTS fk_chass_loc_chass_devid;
ALTER TABLE device_encapsulation_domain DROP CONSTRAINT IF EXISTS fk_dev_encap_domain_devid;
ALTER TABLE device_management_controller DROP CONSTRAINT IF EXISTS fk_dev_mgmt_ctlr_dev_id;
ALTER TABLE device_ssh_key DROP CONSTRAINT IF EXISTS fk_dev_ssh_key_ssh_key_id;
ALTER TABLE device_ticket DROP CONSTRAINT IF EXISTS fk_dev_tkt_dev_id;
ALTER TABLE device_type DROP CONSTRAINT IF EXISTS fk_dev_typ_idealized_dev_id;
ALTER TABLE device_type DROP CONSTRAINT IF EXISTS fk_dev_typ_tmplt_dev_typ_id;
ALTER TABLE device_collection_device DROP CONSTRAINT IF EXISTS fk_devcolldev_dev_id;
ALTER TABLE device_layer2_network DROP CONSTRAINT IF EXISTS fk_device_l2_net_devid;
ALTER TABLE device_note DROP CONSTRAINT IF EXISTS fk_device_note_device;
ALTER TABLE device_management_controller DROP CONSTRAINT IF EXISTS fk_dvc_mgmt_ctrl_mgr_dev_id;
ALTER TABLE logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_device_id;
ALTER TABLE mlag_peering DROP CONSTRAINT IF EXISTS fk_mlag_peering_devid1;
ALTER TABLE mlag_peering DROP CONSTRAINT IF EXISTS fk_mlag_peering_devid2;
ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS fk_netint_device_id;
ALTER TABLE network_interface_purpose DROP CONSTRAINT IF EXISTS fk_netint_purpose_device_id;
ALTER TABLE network_service DROP CONSTRAINT IF EXISTS fk_netsvc_device_id;
ALTER TABLE physicalish_volume DROP CONSTRAINT IF EXISTS fk_physvol_device_id;
ALTER TABLE snmp_commstr DROP CONSTRAINT IF EXISTS fk_snmpstr_device_id;
ALTER TABLE static_route DROP CONSTRAINT IF EXISTS fk_statrt_devsrc_id;
ALTER TABLE volume_group DROP CONSTRAINT IF EXISTS fk_volgrp_devid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_chasloc_chass_devid;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_chass_loc_id_mod_enfc;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_devtp_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_os_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_rack_location_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_ref_mgmt_proto;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_asset_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_comp_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_dev_v_svcenv;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_dev_val_status;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_fk_voe;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_id_dnsrecord;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_ref_parent_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_ref_voesymbtrk;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_site_code;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'device');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ak_device_chassis_location_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ak_device_rack_location_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS pk_device;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_dev_islclymgd";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_ismonitored";
DROP INDEX IF EXISTS "jazzhands"."idx_device_type_location";
DROP INDEX IF EXISTS "jazzhands"."xif_dev_chass_loc_id_mod_enfc";
DROP INDEX IF EXISTS "jazzhands"."xif_dev_os_id";
DROP INDEX IF EXISTS "jazzhands"."xif_device_asset_id";
DROP INDEX IF EXISTS "jazzhands"."xif_device_comp_id";
DROP INDEX IF EXISTS "jazzhands"."xif_device_dev_v_svcenv";
DROP INDEX IF EXISTS "jazzhands"."xif_device_dev_val_status";
DROP INDEX IF EXISTS "jazzhands"."xif_device_fk_voe";
DROP INDEX IF EXISTS "jazzhands"."xif_device_id_dnsrecord";
DROP INDEX IF EXISTS "jazzhands"."xif_device_site_code";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_locally_manage_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_monitored_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_virtual_device_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_should_fetch_conf_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS dev_osid_notnull;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069051;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069052;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069057;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069059;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069060;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS aaa_trigger_device_asset_id_fix ON jazzhands.device;
DROP TRIGGER IF EXISTS trig_userlog_device ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_audit_device ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_create_device_component ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_delete_per_device_device_collection ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_device_one_location_validate ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_update_per_device_device_collection ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_validate_device_component_assignment ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_verify_device_voe ON jazzhands.device;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'device');
---- BEGIN audit.device TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'device', 'device');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'device');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.device DROP CONSTRAINT IF EXISTS device_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_device_ak_device_chassis_location_id";
DROP INDEX IF EXISTS "audit"."aud_device_ak_device_rack_location_id";
DROP INDEX IF EXISTS "audit"."aud_device_pk_device";
DROP INDEX IF EXISTS "audit"."device_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.device TEARDOWN


ALTER TABLE device RENAME TO device_v79;
ALTER TABLE audit.device RENAME TO device_v79;

CREATE TABLE device
(
	device_id	integer NOT NULL,
	component_id	integer  NULL,
	device_type_id	integer NOT NULL,
	device_name	varchar(255)  NULL,
	site_code	varchar(50)  NULL,
	identifying_dns_record_id	integer  NULL,
	host_id	varchar(255)  NULL,
	physical_label	varchar(255)  NULL,
	rack_location_id	integer  NULL,
	chassis_location_id	integer  NULL,
	parent_device_id	integer  NULL,
	description	varchar(255)  NULL,
	external_id	varchar(255)  NULL,
	device_status	varchar(50) NOT NULL,
	operating_system_id	integer NOT NULL,
	service_environment_id	integer NOT NULL,
	auto_mgmt_protocol	varchar(50)  NULL,
	is_locally_managed	character(1) NOT NULL,
	is_monitored	character(1) NOT NULL,
	is_virtual_device	character(1) NOT NULL,
	should_fetch_config	character(1) NOT NULL,
	date_in_service	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device', false);
ALTER TABLE device
	ALTER device_id
	SET DEFAULT nextval('device_device_id_seq'::regclass);
ALTER TABLE device
	ALTER operating_system_id
	SET DEFAULT 0;
ALTER TABLE device
	ALTER is_locally_managed
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE device
	ALTER is_virtual_device
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device
	ALTER should_fetch_config
	SET DEFAULT 'Y'::bpchar;
INSERT INTO device (
	device_id,
	component_id,
	device_type_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	host_id,
	physical_label,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	external_id,		-- new column (external_id)
	device_status,
	operating_system_id,
	service_environment_id,
	auto_mgmt_protocol,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	device_id,
	component_id,
	device_type_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	host_id,
	physical_label,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	NULL,		-- new column (external_id)
	device_status,
	operating_system_id,
	service_environment_id,
	auto_mgmt_protocol,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_v79;

INSERT INTO audit.device (
	device_id,
	component_id,
	device_type_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	host_id,
	physical_label,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	external_id,		-- new column (external_id)
	device_status,
	operating_system_id,
	service_environment_id,
	auto_mgmt_protocol,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	date_in_service,
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
	device_id,
	component_id,
	device_type_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	host_id,
	physical_label,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	NULL,		-- new column (external_id)
	device_status,
	operating_system_id,
	service_environment_id,
	auto_mgmt_protocol,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	date_in_service,
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
FROM audit.device_v79;

ALTER TABLE device
	ALTER device_id
	SET DEFAULT nextval('device_device_id_seq'::regclass);
ALTER TABLE device
	ALTER operating_system_id
	SET DEFAULT 0;
ALTER TABLE device
	ALTER is_locally_managed
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE device
	ALTER is_virtual_device
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device
	ALTER should_fetch_config
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device ADD CONSTRAINT ak_device_chassis_location_id UNIQUE (chassis_location_id);
-- ALTER TABLE device ADD CONSTRAINT ak_device_rack_location_id UNIQUE (rack_location_id);
ALTER TABLE device ADD CONSTRAINT pk_device PRIMARY KEY (device_id);

-- Table/Column Comments
COMMENT ON COLUMN device.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX idx_dev_islclymgd ON device USING btree (is_locally_managed);
CREATE INDEX idx_dev_ismonitored ON device USING btree (is_monitored);
CREATE INDEX idx_device_type_location ON device USING btree (device_type_id);
CREATE INDEX xif_dev_chass_loc_id_mod_enfc ON device USING btree (chassis_location_id, parent_device_id, device_type_id);
CREATE INDEX xif_dev_os_id ON device USING btree (operating_system_id);
CREATE INDEX xif_device_comp_id ON device USING btree (component_id);
CREATE INDEX xif_device_dev_v_svcenv ON device USING btree (service_environment_id);
CREATE INDEX xif_device_dev_val_status ON device USING btree (device_status);
CREATE INDEX xif_device_id_dnsrecord ON device USING btree (identifying_dns_record_id);
CREATE INDEX xif_device_site_code ON device USING btree (site_code);

-- CHECK CONSTRAINTS
ALTER TABLE device ADD CONSTRAINT ckc_is_locally_manage_device
	CHECK ((is_locally_managed = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_locally_managed)::text = upper((is_locally_managed)::text)));
ALTER TABLE device ADD CONSTRAINT ckc_is_monitored_device
	CHECK ((is_monitored = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_monitored)::text = upper((is_monitored)::text)));
ALTER TABLE device ADD CONSTRAINT ckc_is_virtual_device_device
	CHECK ((is_virtual_device = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_virtual_device)::text = upper((is_virtual_device)::text)));
ALTER TABLE device ADD CONSTRAINT ckc_should_fetch_conf_device
	CHECK ((should_fetch_config = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_fetch_config)::text = upper((should_fetch_config)::text)));
ALTER TABLE device ADD CONSTRAINT dev_osid_notnull
	CHECK (operating_system_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069051
	CHECK (device_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069052
	CHECK (device_type_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069057
	CHECK (is_monitored IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069059
	CHECK (is_virtual_device IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069060
	CHECK (should_fetch_config IS NOT NULL);

-- FOREIGN KEYS FROM
-- consider FK between device and chassis_location
ALTER TABLE chassis_location
	ADD CONSTRAINT fk_chass_loc_chass_devid
	FOREIGN KEY (chassis_device_id) REFERENCES device(device_id) DEFERRABLE;
-- consider FK between device and device_encapsulation_domain
ALTER TABLE device_encapsulation_domain
	ADD CONSTRAINT fk_dev_encap_domain_devid
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK between device and device_management_controller
ALTER TABLE device_management_controller
	ADD CONSTRAINT fk_dev_mgmt_ctlr_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK between device and device_ssh_key
ALTER TABLE device_ssh_key
	ADD CONSTRAINT fk_dev_ssh_key_ssh_key_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK between device and device_ticket
ALTER TABLE device_ticket
	ADD CONSTRAINT fk_dev_tkt_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK between device and device_type
ALTER TABLE device_type
	ADD CONSTRAINT fk_dev_typ_idealized_dev_id
	FOREIGN KEY (idealized_device_id) REFERENCES device(device_id);
-- consider FK between device and device_type
ALTER TABLE device_type
	ADD CONSTRAINT fk_dev_typ_tmplt_dev_typ_id
	FOREIGN KEY (template_device_id) REFERENCES device(device_id);
-- consider FK between device and device_collection_device
ALTER TABLE device_collection_device
	ADD CONSTRAINT fk_devcolldev_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK between device and device_layer2_network
ALTER TABLE device_layer2_network
	ADD CONSTRAINT fk_device_l2_net_devid
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK between device and device_note
ALTER TABLE device_note
	ADD CONSTRAINT fk_device_note_device
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK between device and device_management_controller
ALTER TABLE device_management_controller
	ADD CONSTRAINT fk_dvc_mgmt_ctrl_mgr_dev_id
	FOREIGN KEY (manager_device_id) REFERENCES device(device_id);
-- consider FK between device and logical_volume
ALTER TABLE logical_volume
	ADD CONSTRAINT fk_logvol_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id) DEFERRABLE;
-- consider FK between device and mlag_peering
ALTER TABLE mlag_peering
	ADD CONSTRAINT fk_mlag_peering_devid1
	FOREIGN KEY (device1_id) REFERENCES device(device_id);
-- consider FK between device and mlag_peering
ALTER TABLE mlag_peering
	ADD CONSTRAINT fk_mlag_peering_devid2
	FOREIGN KEY (device2_id) REFERENCES device(device_id);
-- consider FK between device and network_interface
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK between device and network_interface_purpose
ALTER TABLE network_interface_purpose
	ADD CONSTRAINT fk_netint_purpose_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK between device and network_service
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK between device and physicalish_volume
ALTER TABLE physicalish_volume
	ADD CONSTRAINT fk_physvol_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id) DEFERRABLE;
-- consider FK between device and snmp_commstr
ALTER TABLE snmp_commstr
	ADD CONSTRAINT fk_snmpstr_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK between device and static_route
ALTER TABLE static_route
	ADD CONSTRAINT fk_statrt_devsrc_id
	FOREIGN KEY (device_src_id) REFERENCES device(device_id);
-- consider FK between device and volume_group
ALTER TABLE volume_group
	ADD CONSTRAINT fk_volgrp_devid
	FOREIGN KEY (device_id) REFERENCES device(device_id) DEFERRABLE;

-- FOREIGN KEYS TO
-- consider FK device and chassis_location
ALTER TABLE device
	ADD CONSTRAINT fk_chasloc_chass_devid
	FOREIGN KEY (chassis_location_id) REFERENCES chassis_location(chassis_location_id) DEFERRABLE;
-- consider FK device and chassis_location
ALTER TABLE device
	ADD CONSTRAINT fk_dev_chass_loc_id_mod_enfc
	FOREIGN KEY (chassis_location_id, parent_device_id, device_type_id) REFERENCES chassis_location(chassis_location_id, chassis_device_id, module_device_type_id) DEFERRABLE;
-- consider FK device and device_type
ALTER TABLE device
	ADD CONSTRAINT fk_dev_devtp_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
-- consider FK device and operating_system
ALTER TABLE device
	ADD CONSTRAINT fk_dev_os_id
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
-- consider FK device and rack_location
ALTER TABLE device
	ADD CONSTRAINT fk_dev_rack_location_id
	FOREIGN KEY (rack_location_id) REFERENCES rack_location(rack_location_id);
-- consider FK device and val_device_auto_mgmt_protocol
ALTER TABLE device
	ADD CONSTRAINT fk_dev_ref_mgmt_proto
	FOREIGN KEY (auto_mgmt_protocol) REFERENCES val_device_auto_mgmt_protocol(auto_mgmt_protocol);
-- consider FK device and component
ALTER TABLE device
	ADD CONSTRAINT fk_device_comp_id
	FOREIGN KEY (component_id) REFERENCES component(component_id);
-- consider FK device and service_environment
ALTER TABLE device
	ADD CONSTRAINT fk_device_dev_v_svcenv
	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);
-- consider FK device and val_device_status
ALTER TABLE device
	ADD CONSTRAINT fk_device_dev_val_status
	FOREIGN KEY (device_status) REFERENCES val_device_status(device_status);
-- consider FK device and dns_record
ALTER TABLE device
	ADD CONSTRAINT fk_device_id_dnsrecord
	FOREIGN KEY (identifying_dns_record_id) REFERENCES dns_record(dns_record_id) DEFERRABLE;
-- consider FK device and device
ALTER TABLE device
	ADD CONSTRAINT fk_device_ref_parent_device
	FOREIGN KEY (parent_device_id) REFERENCES device(device_id);
-- consider FK device and site
ALTER TABLE device
	ADD CONSTRAINT fk_device_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);

-- TRIGGERS
-- consider NEW jazzhands.create_device_component_by_trigger
CREATE OR REPLACE FUNCTION jazzhands.create_device_component_by_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	devtype		RECORD;
	ctid		integer;
	cid			integer;
	scarr       integer[];
	dcarr       integer[];
	server_ver	integer;
BEGIN

	SELECT
		dt.device_type_id,
		dt.component_type_id,
		dt.template_device_id,
		d.component_id
	INTO
		devtype
	FROM
		device_type dt LEFT JOIN
		device d ON (dt.template_device_id = d.device_id)
	WHERE
		dt.device_type_id = NEW.device_type_id;

	IF NEW.component_id IS NOT NULL THEN
		IF devtype.component_type_id IS NOT NULL THEN
			SELECT
				component_type_id INTO ctid
			FROM
				component c
			WHERE
				c.component_id = NEW.component_id;

			IF ctid != devtype.component_type_id THEN
				UPDATE
					component
				SET
					component_type_id = devtype.component_type_id
				WHERE
					component_id = NEW.component_id;
			END IF;
		END IF;

		RETURN NEW;
	END IF;

	--
	-- If template_device_id doesn't exist, then create an instance of
	-- the component_id if it exists
	--
	IF devtype.component_id IS NULL THEN
		--
		-- If the component_id doesn't exist, then we're done
		--
		IF devtype.component_type_id IS NULL THEN
			RETURN NEW;
		END IF;
		--
		-- Insert a component of the given type and tie it to the device
		--
		INSERT INTO component (component_type_id)
			VALUES (devtype.component_type_id)
			RETURNING component_id INTO cid;

		NEW.component_id := cid;
		RETURN NEW;
	ELSE
		SELECT setting INTO server_ver FROM pg_catalog.pg_settings
			WHERE name = 'server_version_num';

		IF (server_ver < 90400) THEN
			--
			-- This is pretty nasty; welcome to SQL
			--
			--
			-- This returns data into a temporary table (ugh) that's used as a
			-- key/value store to map each template component to the
			-- newly-created one
			--
			CREATE TEMPORARY TABLE trig_comp_ins AS
			WITH comp_ins AS (
				INSERT INTO component (
					component_type_id
				) SELECT
					c.component_type_id
				FROM
					device_type dt JOIN
					v_device_components dc ON
						(dc.device_id = dt.template_device_id) JOIN
					component c USING (component_id)
				WHERE
					device_type_id = NEW.device_type_id
				ORDER BY
					level, c.component_type_id
				RETURNING component_id
			)
			SELECT
				src_comp.component_id as src_component_id,
				dst_comp.component_id as dst_component_id,
				src_comp.level as level
			FROM
				(SELECT
					c.component_id,
					level,
					row_number() OVER (ORDER BY level, c.component_type_id)
						AS rownum
				 FROM
					device_type dt JOIN
					v_device_components dc ON
						(dc.device_id = dt.template_device_id) JOIN
					component c USING (component_id)
				 WHERE
					device_type_id = NEW.device_type_id
				) src_comp,
				(SELECT
					component_id,
					row_number() OVER () AS rownum
				 FROM
					comp_ins
				) dst_comp
			WHERE
				src_comp.rownum = dst_comp.rownum;

			/*
				 Now take the mapping of components that were inserted above,
				 and tie the new components to the appropriate slot on the
				 parent.
				 The logic below is:
					- Take the template component, and locate its parent slot
					- Find the correct slot on the corresponding new parent
					  component by locating one with the same slot_name and
					  slot_type_id on the mapped parent component_id
					- Update the parent_slot_id of the component with the
					  mapped component_id to this slot_id

				 This works even if the top-level component is attached to some
				 other device, since there will not be a mapping for those in
				 the table to locate.
			*/

			UPDATE
				component dc
			SET
				parent_slot_id = ds.slot_id
			FROM
				trig_comp_ins tt,
				trig_comp_ins ptt,
				component sc,
				slot ss,
				slot ds
			WHERE
				tt.src_component_id = sc.component_id AND
				tt.dst_component_id = dc.component_id AND
				ss.slot_id = sc.parent_slot_id AND
				ss.component_id = ptt.src_component_id AND
				ds.component_id = ptt.dst_component_id AND
				ss.slot_type_id = ds.slot_type_id AND
				ss.slot_name = ds.slot_name;

			SELECT dst_component_id INTO cid FROM trig_comp_ins WHERE
				level = 1;

			NEW.component_id := cid;

			DROP TABLE trig_comp_ins;

			RETURN NEW;
		ELSE
			WITH dev_comps AS (
				SELECT
					c.component_id,
					c.component_type_id,
					level,
					row_number() OVER (ORDER BY level, c.component_type_id) AS
						rownum
				FROM
					device_type dt JOIN
					v_device_components dc ON
						(dc.device_id = dt.template_device_id) JOIN
					component c USING (component_id)
				WHERE
					device_type_id = NEW.device_type_id
			),
			comp_ins AS (
				INSERT INTO component (
					component_type_id
				) SELECT
					component_type_id
				FROM
					dev_comps
				ORDER BY
					rownum
				RETURNING component_id, component_type_id
			),
			comp_ins_arr AS (
				SELECT
					array_agg(component_id) AS dst_arr
				FROM
					comp_ins
			),
			dev_comps_arr AS (
				SELECT
					array_agg(component_id) as src_arr
				FROM
					dev_comps
			)
			SELECT src_arr, dst_arr INTO scarr, dcarr FROM
				dev_comps_arr, comp_ins_arr;

			UPDATE
				component dc
			SET
				parent_slot_id = ds.slot_id
			FROM
				unnest(scarr, dcarr) AS
					tt(src_component_id, dst_component_id),
				unnest(scarr, dcarr) AS
					ptt(src_component_id, dst_component_id),
				component sc,
				slot ss,
				slot ds
			WHERE
				tt.src_component_id = sc.component_id AND
				tt.dst_component_id = dc.component_id AND
				ss.slot_id = sc.parent_slot_id AND
				ss.component_id = ptt.src_component_id AND
				ds.component_id = ptt.dst_component_id AND
				ss.slot_type_id = ds.slot_type_id AND
				ss.slot_name = ds.slot_name;

			SELECT
				component_id INTO NEW.component_id
			FROM
				component c
			WHERE
				component_id = ANY(dcarr) AND
				parent_slot_id IS NULL;

			RETURN NEW;
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_create_device_component BEFORE INSERT OR UPDATE OF device_type_id ON device FOR EACH ROW EXECUTE PROCEDURE create_device_component_by_trigger();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.delete_per_device_device_collection
CREATE OR REPLACE FUNCTION jazzhands.delete_per_device_device_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dcid			device_collection.device_collection_id%TYPE;
BEGIN
	SELECT	device_collection_id
	  FROM  device_collection
	  INTO	dcid
	 WHERE	device_collection_type = 'per-device'
	   AND	device_collection_id in
		(select device_collection_id
		 from device_collection_device
		where device_id = OLD.device_id
		)
	ORDER BY device_collection_id
	LIMIT 1;

	IF dcid IS NOT NULL THEN
		DELETE FROM device_collection_device
		WHERE device_collection_id = dcid;

		DELETE from device_collection
		WHERE device_collection_id = dcid;
	END IF;

	RETURN OLD;
END;
$function$
;
CREATE TRIGGER trigger_delete_per_device_device_collection BEFORE DELETE ON device FOR EACH ROW EXECUTE PROCEDURE delete_per_device_device_collection();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.device_one_location_validate
CREATE OR REPLACE FUNCTION jazzhands.device_one_location_validate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
BEGIN
	IF NEW.RACK_LOCATION_ID IS NOT NULL AND NEW.CHASSIS_LOCATION_ID IS NOT NULL THEN
		RAISE EXCEPTION 'Both Rack_Location_Id and Chassis_Location_Id may not be set.'
			USING ERRCODE = 'unique_violation';
	END IF;

	IF NEW.CHASSIS_LOCATION_ID IS NOT NULL AND NEW.PARENT_DEVICE_ID IS NULL THEN
		RAISE EXCEPTION 'Must set parent_device_id if setting chassis location.'
			USING ERRCODE = 'foreign_key_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_device_one_location_validate BEFORE INSERT OR UPDATE ON device FOR EACH ROW EXECUTE PROCEDURE device_one_location_validate();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.update_per_device_device_collection
CREATE OR REPLACE FUNCTION jazzhands.update_per_device_device_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dcid		device_collection.device_collection_id%TYPE;
	newname		device_collection.device_collection_name%TYPE;
BEGIN
	IF NEW.device_name IS NOT NULL THEN
		newname = NEW.device_name || '_' || NEW.device_id;
	ELSE
		newname = 'per_d_dc_contrived_' || NEW.device_id;
	END IF;

	IF TG_OP = 'INSERT' THEN
		insert into device_collection
			(device_collection_name, device_collection_type)
		values
			(newname, 'per-device')
		RETURNING device_collection_id INTO dcid;
		insert into device_collection_device
			(device_collection_id, device_id)
		VALUES
			(dcid, NEW.device_id);
	ELSIF TG_OP = 'UPDATE'  THEN
		UPDATE	device_collection
		   SET	device_collection_name = newname
		 WHERE	device_collection_name != newname
		   AND	device_collection_type = 'per-device'
		   AND	device_collection_id in (
			SELECT	device_collection_id
			  FROM	device_collection_device
			 WHERE	device_id = NEW.device_id
			);
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_update_per_device_device_collection AFTER INSERT OR UPDATE ON device FOR EACH ROW EXECUTE PROCEDURE update_per_device_device_collection();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.validate_device_component_assignment
CREATE OR REPLACE FUNCTION jazzhands.validate_device_component_assignment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dtid		device_type.device_type_id%TYPE;
	dt_ctid		component.component_type_id%TYPE;
	ctid		component.component_type_id%TYPE;
BEGIN
	-- If no component_id is set, then we're done

	IF NEW.component_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT
		device_type_id, component_type_id
	INTO
		dtid, dt_ctid
	FROM
		device_type
	WHERE
		device_type_id = NEW.device_type_id;

	IF NOT FOUND OR dt_ctid IS NULL THEN
		RAISE EXCEPTION 'No component_type_id set for device type'
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	SELECT
		component_type_id INTO ctid
	FROM
		component
	WHERE
		component_id = NEW.component_id;

	IF NOT FOUND OR ctid IS DISTINCT FROM dt_ctid THEN
		RAISE EXCEPTION 'Component type of component_id % (%s) does not match component_type for device_type_id % (%)',
			NEW.component_id, ctid, dtid, dt_ctid
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_validate_device_component_assignment AFTER INSERT OR UPDATE OF device_type_id, component_id ON device DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE validate_device_component_assignment();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'device');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device');
ALTER SEQUENCE device_device_id_seq
	 OWNED BY device.device_id;
DROP TABLE IF EXISTS device_v79;
DROP TABLE IF EXISTS audit.device_v79;
-- DONE DEALING WITH TABLE device
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE device_collection
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_collection', 'device_collection');

-- FOREIGN KEYS FROM
ALTER TABLE device_collection_ssh_key DROP CONSTRAINT IF EXISTS fk_dev_coll_ssh_key_devcoll;
ALTER TABLE device_collection_assignd_cert DROP CONSTRAINT IF EXISTS fk_devcolascrt_devcolid;
ALTER TABLE appaal_instance_device_coll DROP CONSTRAINT IF EXISTS fk_devcoll_ref_appaalinstdcoll;
ALTER TABLE device_collection_device DROP CONSTRAINT IF EXISTS fk_devcolldev_dev_colid;
ALTER TABLE device_collection_hier DROP CONSTRAINT IF EXISTS fk_devcollhier_devcol_id;
ALTER TABLE device_collection_hier DROP CONSTRAINT IF EXISTS fk_devcollhier_pdevcol_id;
ALTER TABLE klogin_mclass DROP CONSTRAINT IF EXISTS fk_klgnmcl_devcoll_id;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_prop_pv_devcolid;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_devcolid;
ALTER TABLE sudo_acct_col_device_collectio DROP CONSTRAINT IF EXISTS fk_sudo_ucl_fk_dev_co_device_c;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.device_collection DROP CONSTRAINT IF EXISTS fk_devc_devctyp_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'device_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.device_collection DROP CONSTRAINT IF EXISTS ak_uq_devicecoll_name_type;
ALTER TABLE jazzhands.device_collection DROP CONSTRAINT IF EXISTS pk_device_collection;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_devcoll_devcolltype";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_device_collection ON jazzhands.device_collection;
DROP TRIGGER IF EXISTS trigger_audit_device_collection ON jazzhands.device_collection;
DROP TRIGGER IF EXISTS trigger_validate_device_collection_type_change ON jazzhands.device_collection;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'device_collection');
---- BEGIN audit.device_collection TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'device_collection', 'device_collection');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'device_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.device_collection DROP CONSTRAINT IF EXISTS device_collection_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_device_collection_ak_uq_devicecoll_name_type";
DROP INDEX IF EXISTS "audit"."aud_device_collection_pk_device_collection";
DROP INDEX IF EXISTS "audit"."device_collection_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.device_collection TEARDOWN


ALTER TABLE device_collection RENAME TO device_collection_v79;
ALTER TABLE audit.device_collection RENAME TO device_collection_v79;

CREATE TABLE device_collection
(
	device_collection_id	integer NOT NULL,
	device_collection_name	varchar(255) NOT NULL,
	device_collection_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	external_id	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_collection', false);
ALTER TABLE device_collection
	ALTER device_collection_id
	SET DEFAULT nextval('device_collection_device_collection_id_seq'::regclass);
INSERT INTO device_collection (
	device_collection_id,
	device_collection_name,
	device_collection_type,
	description,
	external_id,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	device_collection_id,
	device_collection_name,
	device_collection_type,
	description,
	NULL,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_collection_v79;

INSERT INTO audit.device_collection (
	device_collection_id,
	device_collection_name,
	device_collection_type,
	description,
	external_id,		-- new column (external_id)
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
	device_collection_id,
	device_collection_name,
	device_collection_type,
	description,
	NULL,		-- new column (external_id)
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
FROM audit.device_collection_v79;

ALTER TABLE device_collection
	ALTER device_collection_id
	SET DEFAULT nextval('device_collection_device_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_collection ADD CONSTRAINT ak_uq_devicecoll_name_type UNIQUE (device_collection_name, device_collection_type);
ALTER TABLE device_collection ADD CONSTRAINT pk_device_collection PRIMARY KEY (device_collection_id);

-- Table/Column Comments
COMMENT ON COLUMN device_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX idx_devcoll_devcolltype ON device_collection USING btree (device_collection_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between device_collection and device_collection_ssh_key
ALTER TABLE device_collection_ssh_key
	ADD CONSTRAINT fk_dev_coll_ssh_key_devcoll
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
-- consider FK between device_collection and device_collection_assignd_cert
ALTER TABLE device_collection_assignd_cert
	ADD CONSTRAINT fk_devcolascrt_devcolid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
-- consider FK between device_collection and appaal_instance_device_coll
ALTER TABLE appaal_instance_device_coll
	ADD CONSTRAINT fk_devcoll_ref_appaalinstdcoll
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
-- consider FK between device_collection and device_collection_device
ALTER TABLE device_collection_device
	ADD CONSTRAINT fk_devcolldev_dev_colid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
-- consider FK between device_collection and device_collection_hier
ALTER TABLE device_collection_hier
	ADD CONSTRAINT fk_devcollhier_devcol_id
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
-- consider FK between device_collection and device_collection_hier
ALTER TABLE device_collection_hier
	ADD CONSTRAINT fk_devcollhier_pdevcol_id
	FOREIGN KEY (parent_device_collection_id) REFERENCES device_collection(device_collection_id);
-- consider FK between device_collection and klogin_mclass
ALTER TABLE klogin_mclass
	ADD CONSTRAINT fk_klgnmcl_devcoll_id
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
-- consider FK between device_collection and property
ALTER TABLE property
	ADD CONSTRAINT fk_prop_pv_devcolid
	FOREIGN KEY (property_value_device_coll_id) REFERENCES device_collection(device_collection_id);
-- consider FK between device_collection and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_devcolid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
-- consider FK between device_collection and sudo_acct_col_device_collectio
ALTER TABLE sudo_acct_col_device_collectio
	ADD CONSTRAINT fk_sudo_ucl_fk_dev_co_device_c
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);

-- FOREIGN KEYS TO
-- consider FK device_collection and val_device_collection_type
ALTER TABLE device_collection
	ADD CONSTRAINT fk_devc_devctyp_id
	FOREIGN KEY (device_collection_type) REFERENCES val_device_collection_type(device_collection_type);

-- TRIGGERS
-- consider NEW jazzhands.validate_device_collection_type_change
CREATE OR REPLACE FUNCTION jazzhands.validate_device_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.device_collection_type != NEW.device_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.device_collection_type = OLD.device_collection_type
		AND	p.device_collection_id = NEW.device_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'device_collection % of type % is used by % restricted properties.',
				NEW.device_collection_id, NEW.device_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_validate_device_collection_type_change BEFORE UPDATE OF device_collection_type ON device_collection FOR EACH ROW EXECUTE PROCEDURE validate_device_collection_type_change();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_collection');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'device_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_collection');
ALTER SEQUENCE device_collection_device_collection_id_seq
	 OWNED BY device_collection.device_collection_id;
DROP TABLE IF EXISTS device_collection_v79;
DROP TABLE IF EXISTS audit.device_collection_v79;
-- DONE DEALING WITH TABLE device_collection
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE dns_change_record
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_change_record', 'dns_change_record');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.dns_change_record DROP CONSTRAINT IF EXISTS fk_dns_chg_dns_domain;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'dns_change_record');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.dns_change_record DROP CONSTRAINT IF EXISTS pk_dns_change_record;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1dns_change_record";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_dns_change_record ON jazzhands.dns_change_record;
DROP TRIGGER IF EXISTS trigger_audit_dns_change_record ON jazzhands.dns_change_record;
DROP TRIGGER IF EXISTS trigger_dns_change_record_pgnotify ON jazzhands.dns_change_record;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'dns_change_record');
---- BEGIN audit.dns_change_record TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'dns_change_record', 'dns_change_record');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'dns_change_record');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.dns_change_record DROP CONSTRAINT IF EXISTS dns_change_record_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_dns_change_record_pk_dns_change_record";
DROP INDEX IF EXISTS "audit"."dns_change_record_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.dns_change_record TEARDOWN


ALTER TABLE dns_change_record RENAME TO dns_change_record_v79;
ALTER TABLE audit.dns_change_record RENAME TO dns_change_record_v79;

CREATE TABLE dns_change_record
(
	dns_change_record_id	bigint NOT NULL,
	dns_domain_id	integer  NULL,
	ip_universe_id	integer  NULL,
	ip_address	inet  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'dns_change_record', false);
ALTER TABLE dns_change_record
	ALTER dns_change_record_id
	SET DEFAULT nextval('dns_change_record_dns_change_record_id_seq'::regclass);
INSERT INTO dns_change_record (
	dns_change_record_id,
	dns_domain_id,
	ip_universe_id,		-- new column (ip_universe_id)
	ip_address,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	dns_change_record_id,
	dns_domain_id,
	NULL,		-- new column (ip_universe_id)
	ip_address,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM dns_change_record_v79;

INSERT INTO audit.dns_change_record (
	dns_change_record_id,
	dns_domain_id,
	ip_universe_id,		-- new column (ip_universe_id)
	ip_address,
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
	dns_change_record_id,
	dns_domain_id,
	NULL,		-- new column (ip_universe_id)
	ip_address,
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
FROM audit.dns_change_record_v79;

ALTER TABLE dns_change_record
	ALTER dns_change_record_id
	SET DEFAULT nextval('dns_change_record_dns_change_record_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE dns_change_record ADD CONSTRAINT pk_dns_change_record PRIMARY KEY (dns_change_record_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1dns_change_record ON dns_change_record USING btree (dns_domain_id);
CREATE INDEX xif2dns_change_record ON dns_change_record USING btree (ip_universe_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK dns_change_record and dns_domain
ALTER TABLE dns_change_record
	ADD CONSTRAINT fk_dns_chg_dns_domain
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK dns_change_record and ip_universe
ALTER TABLE dns_change_record
	ADD CONSTRAINT fk_dnschgrec_ip_universe
	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);

-- TRIGGERS
-- consider NEW jazzhands.dns_change_record_pgnotify
CREATE OR REPLACE FUNCTION jazzhands.dns_change_record_pgnotify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	NOTIFY dns_zone_gen;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_dns_change_record_pgnotify AFTER INSERT OR UPDATE ON dns_change_record FOR EACH STATEMENT EXECUTE PROCEDURE dns_change_record_pgnotify();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'dns_change_record');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'dns_change_record');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'dns_change_record');
ALTER SEQUENCE dns_change_record_dns_change_record_id_seq
	 OWNED BY dns_change_record.dns_change_record_id;
DROP TABLE IF EXISTS dns_change_record_v79;
DROP TABLE IF EXISTS audit.dns_change_record_v79;
-- DONE DEALING WITH TABLE dns_change_record
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE dns_domain
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain', 'dns_domain');

-- FOREIGN KEYS FROM
ALTER TABLE dns_change_record DROP CONSTRAINT IF EXISTS fk_dns_chg_dns_domain;
ALTER TABLE dns_domain_collection_dns_dom DROP CONSTRAINT IF EXISTS fk_dns_dom_coll_dns_domid;
ALTER TABLE dns_record DROP CONSTRAINT IF EXISTS fk_dnsid_dnsdom_id;
ALTER TABLE network_range DROP CONSTRAINT IF EXISTS fk_net_range_dns_domain_id;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_dnsdomid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.dns_domain DROP CONSTRAINT IF EXISTS fk_dns_dom_dns_dom_typ;
ALTER TABLE jazzhands.dns_domain DROP CONSTRAINT IF EXISTS fk_dnsdom_dnsdom_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'dns_domain');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.dns_domain DROP CONSTRAINT IF EXISTS pk_dns_domain;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_dnsdomain_parentdnsdomain";
DROP INDEX IF EXISTS "jazzhands"."xifdns_dom_dns_dom_type";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.dns_domain DROP CONSTRAINT IF EXISTS ckc_should_generate_dns_doma;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_dns_domain ON jazzhands.dns_domain;
DROP TRIGGER IF EXISTS trigger_audit_dns_domain ON jazzhands.dns_domain;
DROP TRIGGER IF EXISTS trigger_dns_domain_trigger_change ON jazzhands.dns_domain;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'dns_domain');
---- BEGIN audit.dns_domain TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'dns_domain', 'dns_domain');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'dns_domain');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.dns_domain DROP CONSTRAINT IF EXISTS dns_domain_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_dns_domain_pk_dns_domain";
DROP INDEX IF EXISTS "audit"."dns_domain_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.dns_domain TEARDOWN


ALTER TABLE dns_domain RENAME TO dns_domain_v79;
ALTER TABLE audit.dns_domain RENAME TO dns_domain_v79;

CREATE TABLE dns_domain
(
	dns_domain_id	integer NOT NULL,
	soa_name	varchar(255) NOT NULL,
	dns_domain_name	varchar(255) NOT NULL,
	dns_domain_type	varchar(50) NOT NULL,
	parent_dns_domain_id	integer  NULL,
	description	varchar(255)  NULL,
	external_id	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'dns_domain', false);
ALTER TABLE dns_domain
	ALTER dns_domain_id
	SET DEFAULT nextval('dns_domain_dns_domain_id_seq'::regclass);
INSERT INTO dns_domain (
	dns_domain_id,
	soa_name,
	dns_domain_name,		-- new column (dns_domain_name)
	dns_domain_type,
	parent_dns_domain_id,
	description,		-- new column (description)
	external_id,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	dns_domain_id,
	soa_name,
	soa_name,		-- new column (dns_domain_name)
	dns_domain_type,
	parent_dns_domain_id,
	NULL,		-- new column (description)
	NULL,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM dns_domain_v79;

INSERT INTO audit.dns_domain (
	dns_domain_id,
	soa_name,
	dns_domain_name,		-- new column (dns_domain_name)
	dns_domain_type,
	parent_dns_domain_id,
	description,		-- new column (description)
	external_id,		-- new column (external_id)
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
	dns_domain_id,
	soa_name,
	soa_name,		-- new column (dns_domain_name)
	dns_domain_type,
	parent_dns_domain_id,
	NULL,		-- new column (description)
	NULL,		-- new column (external_id)
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
FROM audit.dns_domain_v79;

ALTER TABLE dns_domain
	ALTER dns_domain_id
	SET DEFAULT nextval('dns_domain_dns_domain_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE dns_domain ADD CONSTRAINT ak_dns_domain_name_type UNIQUE (dns_domain_name, dns_domain_type);
ALTER TABLE dns_domain ADD CONSTRAINT pk_dns_domain PRIMARY KEY (dns_domain_id);

-- Table/Column Comments
COMMENT ON COLUMN dns_domain.soa_name IS 'legacy name for zone.  This is being replaced with dns_domain_name and the other should be set and not this one (which will be syncd by trigger until it goes away).';
COMMENT ON COLUMN dns_domain.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX idx_dnsdomain_parentdnsdomain ON dns_domain USING btree (parent_dns_domain_id);
CREATE INDEX xifdns_dom_dns_dom_type ON dns_domain USING btree (dns_domain_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between dns_domain and dns_change_record
ALTER TABLE dns_change_record
	ADD CONSTRAINT fk_dns_chg_dns_domain
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK between dns_domain and dns_domain_collection_dns_dom
ALTER TABLE dns_domain_collection_dns_dom
	ADD CONSTRAINT fk_dns_dom_coll_dns_domid
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK between dns_domain and dns_domain_ip_universe
-- Skipping this FK since column does not exist yet
--ALTER TABLE dns_domain_ip_universe
--	ADD CONSTRAINT fk_dnsdom_ipu_dnsdomid
--	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);

-- consider FK between dns_domain and dns_record
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsid_dnsdom_id
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK between dns_domain and network_range
ALTER TABLE network_range
	ADD CONSTRAINT fk_net_range_dns_domain_id
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);

-- FOREIGN KEYS TO
-- consider FK dns_domain and val_dns_domain_type
ALTER TABLE dns_domain
	ADD CONSTRAINT fk_dns_dom_dns_dom_typ
	FOREIGN KEY (dns_domain_type) REFERENCES val_dns_domain_type(dns_domain_type);
-- consider FK dns_domain and dns_domain
ALTER TABLE dns_domain
	ADD CONSTRAINT fk_dnsdom_dnsdom_id
	FOREIGN KEY (parent_dns_domain_id) REFERENCES dns_domain(dns_domain_id);

-- TRIGGERS
-- consider NEW jazzhands.dns_domain_soa_name_retire
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_soa_name_retire()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.dns_domain_name IS NOT NULL and NEW.soa_name IS NOT NULL THEN
			RAISE EXCEPTION 'Must only set dns_domain_name, not soa_name'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF NEW.soa_name IS NULL THEN
			NEW.soa_name = NEW.dns_domain_name;
		ELSIF NEW.dns_domain_name IS NULL THEN
			NEW.dns_domain_name = NEW.soa_name;
		ELSE
			RAISE EXCEPTION 'DNS DOMAIN NAME insert checker failed';
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.dns_domain_name IS DISTINCT FROM NEW.dns_domain_name AND
			OLD.soa_name IS DISTINCT FROM NEW.soa_name
		THEN
			RAISE EXCEPTION 'Must only change dns_domain_name, not soa_name'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF OLD.dns_domain_name IS DISTINCT FROM NEW.dns_domain_name THEN
			NEW.soa_name = NEW.dns_domain_name;
		ELSIF OLD.soa_name IS DISTINCT FROM NEW.soa_name THEN
			NEW.dns_domain_name = NEW.soa_name;
		END IF;
	END IF;

	-- RAISE EXCEPTION 'Need to write this trigger.';
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_dns_domain_soa_name_retire BEFORE INSERT OR UPDATE OF soa_name, dns_domain_name ON dns_domain FOR EACH ROW EXECUTE PROCEDURE dns_domain_soa_name_retire();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.dns_domain_trigger_change
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_trigger_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	PERFORM *
	FROM dns_domain_ip_universe
	WHERE dns_domain_id = NEW.dns_domain_id
	AND SHOULD_GENERATE = 'Y';
	IF FOUND THEN
		insert into DNS_CHANGE_RECORD
			(dns_domain_id) VALUES (NEW.dns_domain_id);
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_dns_domain_trigger_change AFTER INSERT OR UPDATE OF soa_name ON dns_domain FOR EACH ROW EXECUTE PROCEDURE dns_domain_trigger_change();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'dns_domain');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'dns_domain');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'dns_domain');
ALTER SEQUENCE dns_domain_dns_domain_id_seq
	 OWNED BY dns_domain.dns_domain_id;
-- need to get data out of these later.
-- DROP TABLE IF EXISTS dns_domain_v79;
-- DROP TABLE IF EXISTS audit.dns_domain_v79;
-- DONE DEALING WITH TABLE dns_domain
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE dns_domain_collection
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_collection', 'dns_domain_collection');

-- FOREIGN KEYS FROM
ALTER TABLE dns_domain_collection_dns_dom DROP CONSTRAINT IF EXISTS fk_dns_dom_coll_dns_dom_dns_do;
ALTER TABLE dns_domain_collection_hier DROP CONSTRAINT IF EXISTS fk_dns_domain_coll_id;
ALTER TABLE dns_domain_collection_hier DROP CONSTRAINT IF EXISTS fk_dns_domain_coll_id_child;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_dns_dom_collect;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.dns_domain_collection DROP CONSTRAINT IF EXISTS fk_dns_dom_coll_typ_val;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'dns_domain_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.dns_domain_collection DROP CONSTRAINT IF EXISTS ak_dns_domain_collection_namty;
ALTER TABLE jazzhands.dns_domain_collection DROP CONSTRAINT IF EXISTS pk_dns_domain_collection;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1dns_domain_collection";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_collection ON jazzhands.dns_domain_collection;
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_collection ON jazzhands.dns_domain_collection;
DROP TRIGGER IF EXISTS trigger_validate_dns_domain_collection_type_change ON jazzhands.dns_domain_collection;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'dns_domain_collection');
---- BEGIN audit.dns_domain_collection TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'dns_domain_collection', 'dns_domain_collection');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'dns_domain_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.dns_domain_collection DROP CONSTRAINT IF EXISTS dns_domain_collection_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_dns_domain_collection_ak_dns_domain_collection_namty";
DROP INDEX IF EXISTS "audit"."aud_dns_domain_collection_pk_dns_domain_collection";
DROP INDEX IF EXISTS "audit"."dns_domain_collection_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.dns_domain_collection TEARDOWN


ALTER TABLE dns_domain_collection RENAME TO dns_domain_collection_v79;
ALTER TABLE audit.dns_domain_collection RENAME TO dns_domain_collection_v79;

CREATE TABLE dns_domain_collection
(
	dns_domain_collection_id	integer NOT NULL,
	dns_domain_collection_name	varchar(50) NOT NULL,
	dns_domain_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	external_id	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'dns_domain_collection', false);
ALTER TABLE dns_domain_collection
	ALTER dns_domain_collection_id
	SET DEFAULT nextval('dns_domain_collection_dns_domain_collection_id_seq'::regclass);
INSERT INTO dns_domain_collection (
	dns_domain_collection_id,
	dns_domain_collection_name,
	dns_domain_collection_type,
	description,
	external_id,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	dns_domain_collection_id,
	dns_domain_collection_name,
	dns_domain_collection_type,
	description,
	NULL,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM dns_domain_collection_v79;

INSERT INTO audit.dns_domain_collection (
	dns_domain_collection_id,
	dns_domain_collection_name,
	dns_domain_collection_type,
	description,
	external_id,		-- new column (external_id)
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
	dns_domain_collection_id,
	dns_domain_collection_name,
	dns_domain_collection_type,
	description,
	NULL,		-- new column (external_id)
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
FROM audit.dns_domain_collection_v79;

ALTER TABLE dns_domain_collection
	ALTER dns_domain_collection_id
	SET DEFAULT nextval('dns_domain_collection_dns_domain_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE dns_domain_collection ADD CONSTRAINT ak_dns_domain_collection_namty UNIQUE (dns_domain_collection_name, dns_domain_collection_type);
ALTER TABLE dns_domain_collection ADD CONSTRAINT pk_dns_domain_collection PRIMARY KEY (dns_domain_collection_id);

-- Table/Column Comments
COMMENT ON COLUMN dns_domain_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX xif1dns_domain_collection ON dns_domain_collection USING btree (dns_domain_collection_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between dns_domain_collection and dns_domain_collection_dns_dom
ALTER TABLE dns_domain_collection_dns_dom
	ADD CONSTRAINT fk_dns_dom_coll_dns_dom_dns_do
	FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);
-- consider FK between dns_domain_collection and dns_domain_collection_hier
ALTER TABLE dns_domain_collection_hier
	ADD CONSTRAINT fk_dns_domain_coll_id
	FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);
-- consider FK between dns_domain_collection and dns_domain_collection_hier
ALTER TABLE dns_domain_collection_hier
	ADD CONSTRAINT fk_dns_domain_coll_id_child
	FOREIGN KEY (child_dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);
-- consider FK between dns_domain_collection and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_dns_dom_collect
	FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);

-- FOREIGN KEYS TO
-- consider FK dns_domain_collection and val_dns_domain_collection_type
ALTER TABLE dns_domain_collection
	ADD CONSTRAINT fk_dns_dom_coll_typ_val
	FOREIGN KEY (dns_domain_collection_type) REFERENCES val_dns_domain_collection_type(dns_domain_collection_type);

-- TRIGGERS
-- consider NEW jazzhands.validate_dns_domain_collection_type_change
CREATE OR REPLACE FUNCTION jazzhands.validate_dns_domain_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.dns_domain_collection_type != NEW.dns_domain_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.dns_domain_collection_type = OLD.dns_domain_collection_type
		AND	p.dns_domain_collection_id = NEW.dns_domain_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'dns_domain_collection % of type % is used by % restricted properties.',
				NEW.dns_domain_collection_id, NEW.dns_domain_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_validate_dns_domain_collection_type_change BEFORE UPDATE OF dns_domain_collection_type ON dns_domain_collection FOR EACH ROW EXECUTE PROCEDURE validate_dns_domain_collection_type_change();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'dns_domain_collection');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'dns_domain_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'dns_domain_collection');
ALTER SEQUENCE dns_domain_collection_dns_domain_collection_id_seq
	 OWNED BY dns_domain_collection.dns_domain_collection_id;
DROP TABLE IF EXISTS dns_domain_collection_v79;
DROP TABLE IF EXISTS audit.dns_domain_collection_v79;
-- DONE DEALING WITH TABLE dns_domain_collection
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE dns_domain_ip_universe
CREATE TABLE dns_domain_ip_universe
(
	dns_domain_id	integer NOT NULL,
	ip_universe_id	integer NOT NULL,
	soa_class	varchar(50)  NULL,
	soa_ttl	integer  NULL,
	soa_serial	integer  NULL,
	soa_refresh	integer  NULL,
	soa_retry	integer  NULL,
	soa_expire	integer  NULL,
	soa_minimum	integer  NULL,
	soa_mname	varchar(255)  NULL,
	soa_rname	varchar(255) NOT NULL,
	should_generate	character(1) NOT NULL,
	last_generated	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);


-- BEGIN Manually written insert function

INSERT INTO dns_domain_ip_universe (
	dns_domain_id,
	ip_universe_id,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	should_generate,
	last_generated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	dns_domain_id,
	0,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	should_generate,
	last_generated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM dns_domain_v79;

SELECT schema_support.build_audit_table('audit', 'jazzhands', 'dns_domain_ip_universe', true);

INSERT INTO audit.dns_domain_ip_universe (
	dns_domain_id,
	ip_universe_id,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	should_generate,
	last_generated,
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
	dns_domain_id,
	0,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	should_generate,
	last_generated,
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
FROM audit.dns_domain_v79
ORDER BY "aud#seq";

-- existed from earlier.
DROP TABLE IF EXISTS dns_domain_v79;
DROP TABLE IF EXISTS audit.dns_domain_v79;

DO $$
DECLARE
	_x      INTEGER;
	_t      TEXT;
BEGIN
	SELECT coalesce(max("aud#seq"), 0) + 1 INTO _x FROM audit.dns_domain_ip_universe;

	RAISE NOTICE '%', _x;
	_t := 'SELECT setval(''audit.dns_domain_ip_universe_seq'', '|| _x || ')';
	RAISE NOTICE '%', _t;
	EXECUTE _t;
END;
$$;



-- END Manually written insert function
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'dns_domain_ip_universe');

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE dns_domain_ip_universe ADD CONSTRAINT pk_dns_domain_ip_universe PRIMARY KEY (dns_domain_id, ip_universe_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifdnsdom_ipu_dnsdomid ON dns_domain_ip_universe USING btree (dns_domain_id);
CREATE INDEX xifdnsdom_ipu_ipu ON dns_domain_ip_universe USING btree (ip_universe_id);

-- CHECK CONSTRAINTS
ALTER TABLE dns_domain_ip_universe ADD CONSTRAINT validation_rule_675_1416260427
	CHECK ((should_generate = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_generate)::text = upper((should_generate)::text)));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK dns_domain_ip_universe and dns_domain
ALTER TABLE dns_domain_ip_universe
	ADD CONSTRAINT fk_dnsdom_ipu_dnsdomid
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK dns_domain_ip_universe and ip_universe
ALTER TABLE dns_domain_ip_universe
	ADD CONSTRAINT fk_dnsdom_ipu_ipu
	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);

-- TRIGGERS
-- consider NEW jazzhands.dns_domain_ip_universe_trigger_change
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_ip_universe_trigger_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF NEW.should_generate = 'Y' THEN
		insert into DNS_CHANGE_RECORD
			(dns_domain_id) VALUES (NEW.dns_domain_id);
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_dns_domain_ip_universe_trigger_change AFTER INSERT OR UPDATE OF soa_class, soa_ttl, soa_refresh, soa_retry, soa_expire, soa_minimum, soa_mname, soa_rname, should_generate ON dns_domain_ip_universe FOR EACH ROW EXECUTE PROCEDURE dns_domain_ip_universe_trigger_change();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'dns_domain_ip_universe');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'dns_domain_ip_universe');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'dns_domain_ip_universe');
-- DONE DEALING WITH TABLE dns_domain_ip_universe
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE ip_universe_visibility
CREATE TABLE ip_universe_visibility
(
	ip_universe_id	integer NOT NULL,
	visible_ip_universe_id	integer NOT NULL,
	propagate_dns	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'ip_universe_visibility', true);
ALTER TABLE ip_universe_visibility
	ALTER propagate_dns
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE ip_universe_visibility ADD CONSTRAINT pk_ip_universe_visibility PRIMARY KEY (ip_universe_id, visible_ip_universe_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifip_universe_vis_ip_univ ON ip_universe_visibility USING btree (ip_universe_id);
CREATE INDEX xifip_universe_vis_ip_univ_vis ON ip_universe_visibility USING btree (visible_ip_universe_id);

-- CHECK CONSTRAINTS
ALTER TABLE ip_universe_visibility ADD CONSTRAINT check_yes_no_1739765916
	CHECK (propagate_dns = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK ip_universe_visibility and ip_universe
ALTER TABLE ip_universe_visibility
	ADD CONSTRAINT fk_ip_universe_vis_ip_univ
	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);
-- consider FK ip_universe_visibility and ip_universe
ALTER TABLE ip_universe_visibility
	ADD CONSTRAINT fk_ip_universe_vis_ip_univ_vis
	FOREIGN KEY (visible_ip_universe_id) REFERENCES ip_universe(ip_universe_id);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'ip_universe_visibility');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'ip_universe_visibility');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'ip_universe_visibility');
-- DONE DEALING WITH TABLE ip_universe_visibility
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE layer2_network
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'layer2_network', 'layer2_network');

-- FOREIGN KEYS FROM
ALTER TABLE device_layer2_network DROP CONSTRAINT IF EXISTS fk_device_l2_net_l2netid;
ALTER TABLE layer2_connection_l2_network DROP CONSTRAINT IF EXISTS fk_l2c_l2n_l2netid;
ALTER TABLE layer2_connection_l2_network DROP CONSTRAINT IF EXISTS fk_l2cl2n_l2net_id_encap_typ;
ALTER TABLE l2_network_coll_l2_network DROP CONSTRAINT IF EXISTS fk_l2netcl2net_l2netid;
ALTER TABLE layer3_network DROP CONSTRAINT IF EXISTS fk_l3net_l2net;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.layer2_network DROP CONSTRAINT IF EXISTS fk_l2_net_encap_domain;
ALTER TABLE jazzhands.layer2_network DROP CONSTRAINT IF EXISTS fk_l2_net_encap_range_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'layer2_network');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.layer2_network DROP CONSTRAINT IF EXISTS ak_l2_net_l2net_encap_typ;
ALTER TABLE jazzhands.layer2_network DROP CONSTRAINT IF EXISTS ak_l2net_encap_name;
ALTER TABLE jazzhands.layer2_network DROP CONSTRAINT IF EXISTS ak_l2net_encap_tag;
ALTER TABLE jazzhands.layer2_network DROP CONSTRAINT IF EXISTS pk_layer2_network;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_l2_net_encap_domain";
DROP INDEX IF EXISTS "jazzhands"."xif_l2_net_encap_range_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_layer2_network ON jazzhands.layer2_network;
DROP TRIGGER IF EXISTS trigger_audit_layer2_network ON jazzhands.layer2_network;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'layer2_network');
---- BEGIN audit.layer2_network TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'layer2_network', 'layer2_network');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'layer2_network');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.layer2_network DROP CONSTRAINT IF EXISTS layer2_network_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_layer2_network_ak_l2_net_l2net_encap_typ";
DROP INDEX IF EXISTS "audit"."aud_layer2_network_ak_l2net_encap_name";
DROP INDEX IF EXISTS "audit"."aud_layer2_network_ak_l2net_encap_tag";
DROP INDEX IF EXISTS "audit"."aud_layer2_network_pk_layer2_network";
DROP INDEX IF EXISTS "audit"."layer2_network_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.layer2_network TEARDOWN


ALTER TABLE layer2_network RENAME TO layer2_network_v79;
ALTER TABLE audit.layer2_network RENAME TO layer2_network_v79;

CREATE TABLE layer2_network
(
	layer2_network_id	integer NOT NULL,
	encapsulation_name	varchar(32)  NULL,
	encapsulation_domain	varchar(50)  NULL,
	encapsulation_type	varchar(50)  NULL,
	encapsulation_tag	integer  NULL,
	description	varchar(255)  NULL,
	external_id	varchar(255)  NULL,
	encapsulation_range_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer2_network', false);
ALTER TABLE layer2_network
	ALTER layer2_network_id
	SET DEFAULT nextval('layer2_network_layer2_network_id_seq'::regclass);
INSERT INTO layer2_network (
	layer2_network_id,
	encapsulation_name,
	encapsulation_domain,
	encapsulation_type,
	encapsulation_tag,
	description,
	external_id,		-- new column (external_id)
	encapsulation_range_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	layer2_network_id,
	encapsulation_name,
	encapsulation_domain,
	encapsulation_type,
	encapsulation_tag,
	description,
	NULL,		-- new column (external_id)
	encapsulation_range_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM layer2_network_v79;

INSERT INTO audit.layer2_network (
	layer2_network_id,
	encapsulation_name,
	encapsulation_domain,
	encapsulation_type,
	encapsulation_tag,
	description,
	external_id,		-- new column (external_id)
	encapsulation_range_id,
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
	layer2_network_id,
	encapsulation_name,
	encapsulation_domain,
	encapsulation_type,
	encapsulation_tag,
	description,
	NULL,		-- new column (external_id)
	encapsulation_range_id,
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
FROM audit.layer2_network_v79;

ALTER TABLE layer2_network
	ALTER layer2_network_id
	SET DEFAULT nextval('layer2_network_layer2_network_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer2_network ADD CONSTRAINT ak_l2_net_l2net_encap_typ UNIQUE (layer2_network_id, encapsulation_type);
ALTER TABLE layer2_network ADD CONSTRAINT ak_l2net_encap_name UNIQUE (encapsulation_domain, encapsulation_type, encapsulation_name);
ALTER TABLE layer2_network ADD CONSTRAINT ak_l2net_encap_tag UNIQUE (encapsulation_type, encapsulation_domain, encapsulation_tag);
ALTER TABLE layer2_network ADD CONSTRAINT pk_layer2_network PRIMARY KEY (layer2_network_id);

-- Table/Column Comments
COMMENT ON COLUMN layer2_network.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
COMMENT ON COLUMN layer2_network.encapsulation_range_id IS 'Administrative information about which range this is a part of';
-- INDEXES
CREATE INDEX xif_l2_net_encap_domain ON layer2_network USING btree (encapsulation_domain, encapsulation_type);
CREATE INDEX xif_l2_net_encap_range_id ON layer2_network USING btree (encapsulation_range_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between layer2_network and device_layer2_network
ALTER TABLE device_layer2_network
	ADD CONSTRAINT fk_device_l2_net_l2netid
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);
-- consider FK between layer2_network and layer2_connection_l2_network
ALTER TABLE layer2_connection_l2_network
	ADD CONSTRAINT fk_l2c_l2n_l2netid
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);
-- consider FK between layer2_network and layer2_connection_l2_network
ALTER TABLE layer2_connection_l2_network
	ADD CONSTRAINT fk_l2cl2n_l2net_id_encap_typ
	FOREIGN KEY (layer2_network_id, encapsulation_type) REFERENCES layer2_network(layer2_network_id, encapsulation_type);
-- consider FK between layer2_network and l2_network_coll_l2_network
ALTER TABLE l2_network_coll_l2_network
	ADD CONSTRAINT fk_l2netcl2net_l2netid
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);
-- consider FK between layer2_network and layer3_network
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3net_l2net
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);

-- FOREIGN KEYS TO
-- consider FK layer2_network and encapsulation_domain
ALTER TABLE layer2_network
	ADD CONSTRAINT fk_l2_net_encap_domain
	FOREIGN KEY (encapsulation_domain, encapsulation_type) REFERENCES encapsulation_domain(encapsulation_domain, encapsulation_type);
-- consider FK layer2_network and encapsulation_range
ALTER TABLE layer2_network
	ADD CONSTRAINT fk_l2_net_encap_range_id
	FOREIGN KEY (encapsulation_range_id) REFERENCES encapsulation_range(encapsulation_range_id);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer2_network');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'layer2_network');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer2_network');
ALTER SEQUENCE layer2_network_layer2_network_id_seq
	 OWNED BY layer2_network.layer2_network_id;
DROP TABLE IF EXISTS layer2_network_v79;
DROP TABLE IF EXISTS audit.layer2_network_v79;
-- DONE DEALING WITH TABLE layer2_network
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE layer2_network_collection
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'layer2_network_collection', 'layer2_network_collection');

-- FOREIGN KEYS FROM
ALTER TABLE layer2_network_collection_hier DROP CONSTRAINT IF EXISTS fk_l2net_collhier_chldl2net;
ALTER TABLE layer2_network_collection_hier DROP CONSTRAINT IF EXISTS fk_l2net_collhier_l2net;
ALTER TABLE l2_network_coll_l2_network DROP CONSTRAINT IF EXISTS fk_l2netcl2net_collid;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_prop_l2_netcollid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.layer2_network_collection DROP CONSTRAINT IF EXISTS fk_l2netcoll_type;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'layer2_network_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.layer2_network_collection DROP CONSTRAINT IF EXISTS ak_l2network_coll_name_type;
ALTER TABLE jazzhands.layer2_network_collection DROP CONSTRAINT IF EXISTS pk_layer2_network_collection;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_l2netcoll_type";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS l2_net_coll_member_enforce_on_type_change ON jazzhands.layer2_network_collection;
DROP TRIGGER IF EXISTS trig_userlog_layer2_network_collection ON jazzhands.layer2_network_collection;
DROP TRIGGER IF EXISTS trigger_audit_layer2_network_collection ON jazzhands.layer2_network_collection;
DROP TRIGGER IF EXISTS trigger_validate_layer2_network_collection_type_change ON jazzhands.layer2_network_collection;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'layer2_network_collection');
---- BEGIN audit.layer2_network_collection TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'layer2_network_collection', 'layer2_network_collection');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'layer2_network_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.layer2_network_collection DROP CONSTRAINT IF EXISTS layer2_network_collection_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_layer2_network_collection_ak_l2network_coll_name_type";
DROP INDEX IF EXISTS "audit"."aud_layer2_network_collection_pk_layer2_network_collection";
DROP INDEX IF EXISTS "audit"."layer2_network_collection_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.layer2_network_collection TEARDOWN


ALTER TABLE layer2_network_collection RENAME TO layer2_network_collection_v79;
ALTER TABLE audit.layer2_network_collection RENAME TO layer2_network_collection_v79;

CREATE TABLE layer2_network_collection
(
	layer2_network_collection_id	integer NOT NULL,
	layer2_network_collection_name	varchar(255) NOT NULL,
	layer2_network_collection_type	varchar(50)  NULL,
	description	varchar(255)  NULL,
	external_id	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer2_network_collection', false);
ALTER TABLE layer2_network_collection
	ALTER layer2_network_collection_id
	SET DEFAULT nextval('layer2_network_collection_layer2_network_collection_id_seq'::regclass);
INSERT INTO layer2_network_collection (
	layer2_network_collection_id,
	layer2_network_collection_name,
	layer2_network_collection_type,
	description,
	external_id,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	layer2_network_collection_id,
	layer2_network_collection_name,
	layer2_network_collection_type,
	description,
	NULL,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM layer2_network_collection_v79;

INSERT INTO audit.layer2_network_collection (
	layer2_network_collection_id,
	layer2_network_collection_name,
	layer2_network_collection_type,
	description,
	external_id,		-- new column (external_id)
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
	layer2_network_collection_id,
	layer2_network_collection_name,
	layer2_network_collection_type,
	description,
	NULL,		-- new column (external_id)
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
FROM audit.layer2_network_collection_v79;

ALTER TABLE layer2_network_collection
	ALTER layer2_network_collection_id
	SET DEFAULT nextval('layer2_network_collection_layer2_network_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer2_network_collection ADD CONSTRAINT ak_l2network_coll_name_type UNIQUE (layer2_network_collection_name, layer2_network_collection_type);
ALTER TABLE layer2_network_collection ADD CONSTRAINT pk_layer2_network_collection PRIMARY KEY (layer2_network_collection_id);

-- Table/Column Comments
COMMENT ON COLUMN layer2_network_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX xif_l2netcoll_type ON layer2_network_collection USING btree (layer2_network_collection_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between layer2_network_collection and layer2_network_collection_hier
ALTER TABLE layer2_network_collection_hier
	ADD CONSTRAINT fk_l2net_collhier_chldl2net
	FOREIGN KEY (child_l2_network_coll_id) REFERENCES layer2_network_collection(layer2_network_collection_id);
-- consider FK between layer2_network_collection and layer2_network_collection_hier
ALTER TABLE layer2_network_collection_hier
	ADD CONSTRAINT fk_l2net_collhier_l2net
	FOREIGN KEY (layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id);
-- consider FK between layer2_network_collection and l2_network_coll_l2_network
ALTER TABLE l2_network_coll_l2_network
	ADD CONSTRAINT fk_l2netcl2net_collid
	FOREIGN KEY (layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id);
-- consider FK between layer2_network_collection and property
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l2_netcollid
	FOREIGN KEY (layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id);

-- FOREIGN KEYS TO
-- consider FK layer2_network_collection and val_layer2_network_coll_type
ALTER TABLE layer2_network_collection
	ADD CONSTRAINT fk_l2netcoll_type
	FOREIGN KEY (layer2_network_collection_type) REFERENCES val_layer2_network_coll_type(layer2_network_collection_type);

-- TRIGGERS
-- consider NEW jazzhands.l2_net_coll_member_enforce_on_type_change
CREATE OR REPLACE FUNCTION jazzhands.l2_net_coll_member_enforce_on_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	l2ct		val_layer2_network_coll_type%ROWTYPE;
	old_l2ct	val_layer2_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	l2ct
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type = NEW.layer2_network_collection_type;

	SELECT *
	INTO	old_l2ct
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type = OLD.layer2_network_collection_type;

	--
	-- We only need to check this if we are enforcing now where we didn't used
	-- to need to
	--
	IF l2ct.max_num_members IS NOT NULL AND
			l2ct.max_num_members IS DISTINCT FROM old_l2ct.max_num_members THEN
		select count(*)
		  into tally
		  from l2_network_coll_l2_network
		  where layer2_network_collection_id = NEW.layer2_network_collection_id;
		IF tally > l2ct.max_num_members THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF l2ct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		SELECT MAX(l2count) FROM (
			SELECT
				COUNT(*) AS l2count
			FROM
				l2_network_coll_l2_network JOIN
				layer2_network_collection USING (layer2_network_collection_id)
			WHERE
				layer2_network_collection_type = NEW.layer2_network_collection_type
			GROUP BY
				layer2_network_id
		) x INTO tally;

		IF tally > l2ct.max_num_collections THEN
			RAISE EXCEPTION 'Layer2 network may not be a member of more than % collections of type %',
				l2ct.MAX_NUM_COLLECTIONS, l2ct.layer2_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER l2_net_coll_member_enforce_on_type_change AFTER UPDATE OF layer2_network_collection_type ON layer2_network_collection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE l2_net_coll_member_enforce_on_type_change();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.validate_layer2_network_collection_type_change
CREATE OR REPLACE FUNCTION jazzhands.validate_layer2_network_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.layer2_network_collection_type != NEW.layer2_network_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.layer2_network_collection_type = OLD.layer2_network_collection_type
		AND	p.layer2_network_collection_id = NEW.layer2_network_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'layer2_network_collection % of type % is used by % restricted properties.',
				NEW.layer2_network_collection_id, NEW.layer2_network_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_validate_layer2_network_collection_type_change BEFORE UPDATE OF layer2_network_collection_type ON layer2_network_collection FOR EACH ROW EXECUTE PROCEDURE validate_layer2_network_collection_type_change();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer2_network_collection');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'layer2_network_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer2_network_collection');
ALTER SEQUENCE layer2_network_collection_layer2_network_collection_id_seq
	 OWNED BY layer2_network_collection.layer2_network_collection_id;
DROP TABLE IF EXISTS layer2_network_collection_v79;
DROP TABLE IF EXISTS audit.layer2_network_collection_v79;
-- DONE DEALING WITH TABLE layer2_network_collection
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE layer3_network
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'layer3_network', 'layer3_network');

-- FOREIGN KEYS FROM
ALTER TABLE l3_network_coll_l3_network DROP CONSTRAINT IF EXISTS fk_l3netcol_l3_net_l3netid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS fk_l3_net_def_gate_nbid;
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS fk_l3net_l2net;
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS fk_l3net_rndv_pt_nblk_id;
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS fk_layer3_network_netblock_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'layer3_network');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS ak_layer3_network_netblock_id;
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS pk_layer3_network;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_l3_net_def_gate_nbid";
DROP INDEX IF EXISTS "jazzhands"."xif_l3net_l2net";
DROP INDEX IF EXISTS "jazzhands"."xif_l3net_rndv_pt_nblk_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_layer3_network ON jazzhands.layer3_network;
DROP TRIGGER IF EXISTS trigger_audit_layer3_network ON jazzhands.layer3_network;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'layer3_network');
---- BEGIN audit.layer3_network TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'layer3_network', 'layer3_network');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'layer3_network');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.layer3_network DROP CONSTRAINT IF EXISTS layer3_network_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_layer3_network_ak_layer3_network_netblock_id";
DROP INDEX IF EXISTS "audit"."aud_layer3_network_pk_layer3_network";
DROP INDEX IF EXISTS "audit"."layer3_network_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.layer3_network TEARDOWN


ALTER TABLE layer3_network RENAME TO layer3_network_v79;
ALTER TABLE audit.layer3_network RENAME TO layer3_network_v79;

CREATE TABLE layer3_network
(
	layer3_network_id	integer NOT NULL,
	netblock_id	integer NOT NULL,
	layer2_network_id	integer  NULL,
	default_gateway_netblock_id	integer  NULL,
	rendezvous_netblock_id	integer  NULL,
	description	varchar(255)  NULL,
	external_id	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer3_network', false);
ALTER TABLE layer3_network
	ALTER layer3_network_id
	SET DEFAULT nextval('layer3_network_layer3_network_id_seq'::regclass);
INSERT INTO layer3_network (
	layer3_network_id,
	netblock_id,
	layer2_network_id,
	default_gateway_netblock_id,
	rendezvous_netblock_id,
	description,
	external_id,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	layer3_network_id,
	netblock_id,
	layer2_network_id,
	default_gateway_netblock_id,
	rendezvous_netblock_id,
	description,
	NULL,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM layer3_network_v79;

INSERT INTO audit.layer3_network (
	layer3_network_id,
	netblock_id,
	layer2_network_id,
	default_gateway_netblock_id,
	rendezvous_netblock_id,
	description,
	external_id,		-- new column (external_id)
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
	layer3_network_id,
	netblock_id,
	layer2_network_id,
	default_gateway_netblock_id,
	rendezvous_netblock_id,
	description,
	NULL,		-- new column (external_id)
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
FROM audit.layer3_network_v79;

ALTER TABLE layer3_network
	ALTER layer3_network_id
	SET DEFAULT nextval('layer3_network_layer3_network_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer3_network ADD CONSTRAINT ak_layer3_network_netblock_id UNIQUE (netblock_id) DEFERRABLE;
ALTER TABLE layer3_network ADD CONSTRAINT pk_layer3_network PRIMARY KEY (layer3_network_id);

-- Table/Column Comments
COMMENT ON COLUMN layer3_network.rendezvous_netblock_id IS 'Multicast Rendevous Point Address';
COMMENT ON COLUMN layer3_network.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX xif_l3_net_def_gate_nbid ON layer3_network USING btree (default_gateway_netblock_id);
CREATE INDEX xif_l3net_l2net ON layer3_network USING btree (layer2_network_id);
CREATE INDEX xif_l3net_rndv_pt_nblk_id ON layer3_network USING btree (rendezvous_netblock_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between layer3_network and l3_network_coll_l3_network
ALTER TABLE l3_network_coll_l3_network
	ADD CONSTRAINT fk_l3netcol_l3_net_l3netid
	FOREIGN KEY (layer3_network_id) REFERENCES layer3_network(layer3_network_id);

-- FOREIGN KEYS TO
-- consider FK layer3_network and netblock
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3_net_def_gate_nbid
	FOREIGN KEY (default_gateway_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK layer3_network and layer2_network
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3net_l2net
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);
-- consider FK layer3_network and netblock
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3net_rndv_pt_nblk_id
	FOREIGN KEY (rendezvous_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK layer3_network and netblock
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_layer3_network_netblock_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer3_network');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'layer3_network');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer3_network');
ALTER SEQUENCE layer3_network_layer3_network_id_seq
	 OWNED BY layer3_network.layer3_network_id;
DROP TABLE IF EXISTS layer3_network_v79;
DROP TABLE IF EXISTS audit.layer3_network_v79;
-- DONE DEALING WITH TABLE layer3_network
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE layer3_network_collection
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'layer3_network_collection', 'layer3_network_collection');

-- FOREIGN KEYS FROM
ALTER TABLE l3_network_coll_l3_network DROP CONSTRAINT IF EXISTS fk_l3netcol_l3_net_l3netcolid;
ALTER TABLE layer3_network_collection_hier DROP CONSTRAINT IF EXISTS fk_l3nethier_chld_l3netid;
ALTER TABLE layer3_network_collection_hier DROP CONSTRAINT IF EXISTS fk_l3nethierl3netid;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_prop_l3_netcoll_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.layer3_network_collection DROP CONSTRAINT IF EXISTS fk_l3_netcol_netcol_type;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'layer3_network_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.layer3_network_collection DROP CONSTRAINT IF EXISTS ak_l3netcoll_name_type;
ALTER TABLE jazzhands.layer3_network_collection DROP CONSTRAINT IF EXISTS pk_layer3_network_collection;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_l3_netcol_netcol_type";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS l3_net_coll_member_enforce_on_type_change ON jazzhands.layer3_network_collection;
DROP TRIGGER IF EXISTS trig_userlog_layer3_network_collection ON jazzhands.layer3_network_collection;
DROP TRIGGER IF EXISTS trigger_audit_layer3_network_collection ON jazzhands.layer3_network_collection;
DROP TRIGGER IF EXISTS trigger_validate_layer3_network_collection_type_change ON jazzhands.layer3_network_collection;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'layer3_network_collection');
---- BEGIN audit.layer3_network_collection TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'layer3_network_collection', 'layer3_network_collection');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'layer3_network_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.layer3_network_collection DROP CONSTRAINT IF EXISTS layer3_network_collection_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_layer3_network_collection_ak_l3netcoll_name_type";
DROP INDEX IF EXISTS "audit"."aud_layer3_network_collection_pk_layer3_network_collection";
DROP INDEX IF EXISTS "audit"."layer3_network_collection_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.layer3_network_collection TEARDOWN


ALTER TABLE layer3_network_collection RENAME TO layer3_network_collection_v79;
ALTER TABLE audit.layer3_network_collection RENAME TO layer3_network_collection_v79;

CREATE TABLE layer3_network_collection
(
	layer3_network_collection_id	integer NOT NULL,
	layer3_network_collection_name	varchar(255) NOT NULL,
	layer3_network_collection_type	varchar(50)  NULL,
	description	varchar(255)  NULL,
	external_id	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer3_network_collection', false);
ALTER TABLE layer3_network_collection
	ALTER layer3_network_collection_id
	SET DEFAULT nextval('layer3_network_collection_layer3_network_collection_id_seq'::regclass);
INSERT INTO layer3_network_collection (
	layer3_network_collection_id,
	layer3_network_collection_name,
	layer3_network_collection_type,
	description,
	external_id,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	layer3_network_collection_id,
	layer3_network_collection_name,
	layer3_network_collection_type,
	description,
	NULL,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM layer3_network_collection_v79;

INSERT INTO audit.layer3_network_collection (
	layer3_network_collection_id,
	layer3_network_collection_name,
	layer3_network_collection_type,
	description,
	external_id,		-- new column (external_id)
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
	layer3_network_collection_id,
	layer3_network_collection_name,
	layer3_network_collection_type,
	description,
	NULL,		-- new column (external_id)
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
FROM audit.layer3_network_collection_v79;

ALTER TABLE layer3_network_collection
	ALTER layer3_network_collection_id
	SET DEFAULT nextval('layer3_network_collection_layer3_network_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer3_network_collection ADD CONSTRAINT ak_l3netcoll_name_type UNIQUE (layer3_network_collection_name, layer3_network_collection_type);
ALTER TABLE layer3_network_collection ADD CONSTRAINT pk_layer3_network_collection PRIMARY KEY (layer3_network_collection_id);

-- Table/Column Comments
COMMENT ON COLUMN layer3_network_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX xif_l3_netcol_netcol_type ON layer3_network_collection USING btree (layer3_network_collection_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between layer3_network_collection and l3_network_coll_l3_network
ALTER TABLE l3_network_coll_l3_network
	ADD CONSTRAINT fk_l3netcol_l3_net_l3netcolid
	FOREIGN KEY (layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id);
-- consider FK between layer3_network_collection and layer3_network_collection_hier
ALTER TABLE layer3_network_collection_hier
	ADD CONSTRAINT fk_l3nethier_chld_l3netid
	FOREIGN KEY (child_l3_network_coll_id) REFERENCES layer3_network_collection(layer3_network_collection_id);
-- consider FK between layer3_network_collection and layer3_network_collection_hier
ALTER TABLE layer3_network_collection_hier
	ADD CONSTRAINT fk_l3nethierl3netid
	FOREIGN KEY (layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id);
-- consider FK between layer3_network_collection and property
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l3_netcoll_id
	FOREIGN KEY (layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id);

-- FOREIGN KEYS TO
-- consider FK layer3_network_collection and val_layer3_network_coll_type
ALTER TABLE layer3_network_collection
	ADD CONSTRAINT fk_l3_netcol_netcol_type
	FOREIGN KEY (layer3_network_collection_type) REFERENCES val_layer3_network_coll_type(layer3_network_collection_type);

-- TRIGGERS
-- consider NEW jazzhands.l3_net_coll_member_enforce_on_type_change
CREATE OR REPLACE FUNCTION jazzhands.l3_net_coll_member_enforce_on_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	l3ct		val_layer3_network_coll_type%ROWTYPE;
	old_l3ct	val_layer3_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	l3ct
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type = NEW.layer3_network_collection_type;

	SELECT *
	INTO	old_l3ct
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type = OLD.layer3_network_collection_type;

	--
	-- We only need to check this if we are enforcing now where we didn't used
	-- to need to
	--
	IF l3ct.max_num_members IS NOT NULL AND
			l3ct.max_num_members IS DISTINCT FROM old_l3ct.max_num_members THEN
		select count(*)
		  into tally
		  from l3_network_coll_l3_network
		  where layer3_network_collection_id = NEW.layer3_network_collection_id;
		IF tally > l3ct.max_num_members THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF l3ct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		SELECT MAX(l3count) FROM (
			SELECT
				COUNT(*) AS l3count
			FROM
				l3_network_coll_l3_network JOIN
				layer3_network_collection USING (layer3_network_collection_id)
			WHERE
				layer3_network_collection_type = NEW.layer3_network_collection_type
			GROUP BY
				layer3_network_id
		) x INTO tally;

		IF tally > l3ct.max_num_collections THEN
			RAISE EXCEPTION 'Layer2 network may not be a member of more than % collections of type %',
				l3ct.MAX_NUM_COLLECTIONS, l3ct.layer3_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER l3_net_coll_member_enforce_on_type_change AFTER UPDATE OF layer3_network_collection_type ON layer3_network_collection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE l3_net_coll_member_enforce_on_type_change();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.validate_layer3_network_collection_type_change
CREATE OR REPLACE FUNCTION jazzhands.validate_layer3_network_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.layer3_network_collection_type != NEW.layer3_network_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.layer3_network_collection_type = OLD.layer3_network_collection_type
		AND	p.layer3_network_collection_id = NEW.layer3_network_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'layer3_network_collection % of type % is used by % restricted properties.',
				NEW.layer3_network_collection_id, NEW.layer3_network_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_validate_layer3_network_collection_type_change BEFORE UPDATE OF layer3_network_collection_type ON layer3_network_collection FOR EACH ROW EXECUTE PROCEDURE validate_layer3_network_collection_type_change();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer3_network_collection');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'layer3_network_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer3_network_collection');
ALTER SEQUENCE layer3_network_collection_layer3_network_collection_id_seq
	 OWNED BY layer3_network_collection.layer3_network_collection_id;
DROP TABLE IF EXISTS layer3_network_collection_v79;
DROP TABLE IF EXISTS audit.layer3_network_collection_v79;
-- DONE DEALING WITH TABLE layer3_network_collection
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE netblock
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock', 'netblock');

-- FOREIGN KEYS FROM
ALTER TABLE dns_record DROP CONSTRAINT IF EXISTS fk_dnsid_nblk_id;
ALTER TABLE layer3_network DROP CONSTRAINT IF EXISTS fk_l3_net_def_gate_nbid;
ALTER TABLE layer3_network DROP CONSTRAINT IF EXISTS fk_l3net_rndv_pt_nblk_id;
ALTER TABLE layer3_network DROP CONSTRAINT IF EXISTS fk_layer3_network_netblock_id;
ALTER TABLE netblock_collection_netblock DROP CONSTRAINT IF EXISTS fk_nblk_col_nblk_nblkid;
ALTER TABLE network_range DROP CONSTRAINT IF EXISTS fk_net_range_start_netblock;
ALTER TABLE network_range DROP CONSTRAINT IF EXISTS fk_net_range_stop_netblock;
ALTER TABLE static_route_template DROP CONSTRAINT IF EXISTS fk_netblock_st_rt_dst_net;
ALTER TABLE static_route_template DROP CONSTRAINT IF EXISTS fk_netblock_st_rt_src_net;
ALTER TABLE network_interface_netblock DROP CONSTRAINT IF EXISTS fk_netint_nb_netint_id;
ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS fk_netint_netblk_v4id;
ALTER TABLE network_range DROP CONSTRAINT IF EXISTS fk_netrng_prngnblkid;
ALTER TABLE shared_netblock DROP CONSTRAINT IF EXISTS fk_shared_net_netblock_id;
ALTER TABLE site_netblock DROP CONSTRAINT IF EXISTS fk_site_netblock_ref_netblock;
ALTER TABLE static_route DROP CONSTRAINT IF EXISTS fk_statrt_nblk_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS fk_nblk_ip_universe_id;
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS fk_netblk_netblk_parid;
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS fk_netblock_company;
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS fk_netblock_nblk_typ;
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS fk_netblock_v_netblock_stat;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'netblock');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS ak_netblock_params;
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS pk_netblock;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_netblk_netblkstatus";
DROP INDEX IF EXISTS "jazzhands"."idx_netblock_host_ip_address";
DROP INDEX IF EXISTS "jazzhands"."ix_netblk_ip_address";
DROP INDEX IF EXISTS "jazzhands"."ix_netblk_ip_address_parent";
DROP INDEX IF EXISTS "jazzhands"."netblock_case_idx";
DROP INDEX IF EXISTS "jazzhands"."xif5netblock";
DROP INDEX IF EXISTS "jazzhands"."xif6netblock";
DROP INDEX IF EXISTS "jazzhands"."xif7netblock";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS check_yes_no_172122967;
ALTER TABLE jazzhands.netblock DROP CONSTRAINT IF EXISTS ckc_is_single_address_netblock;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS aaa_ta_manipulate_netblock_parentage ON jazzhands.netblock;
DROP TRIGGER IF EXISTS tb_a_validate_netblock ON jazzhands.netblock;
DROP TRIGGER IF EXISTS tb_manipulate_netblock_parentage ON jazzhands.netblock;
DROP TRIGGER IF EXISTS trig_userlog_netblock ON jazzhands.netblock;
DROP TRIGGER IF EXISTS trigger_audit_netblock ON jazzhands.netblock;
DROP TRIGGER IF EXISTS trigger_check_ip_universe_netblock ON jazzhands.netblock;
DROP TRIGGER IF EXISTS trigger_nb_dns_a_rec_validation ON jazzhands.netblock;
DROP TRIGGER IF EXISTS trigger_netblock_single_address_ni ON jazzhands.netblock;
DROP TRIGGER IF EXISTS trigger_validate_netblock_parentage ON jazzhands.netblock;
DROP TRIGGER IF EXISTS trigger_validate_netblock_to_range_changes ON jazzhands.netblock;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'netblock');
---- BEGIN audit.netblock TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'netblock', 'netblock');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'netblock');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.netblock DROP CONSTRAINT IF EXISTS netblock_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_netblock_ak_netblock_params";
DROP INDEX IF EXISTS "audit"."aud_netblock_pk_netblock";
DROP INDEX IF EXISTS "audit"."netblock_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.netblock TEARDOWN


ALTER TABLE netblock RENAME TO netblock_v79;
ALTER TABLE audit.netblock RENAME TO netblock_v79;

CREATE TABLE netblock
(
	netblock_id	integer NOT NULL,
	ip_address	inet NOT NULL,
	netblock_type	varchar(50) NOT NULL,
	is_single_address	character(1) NOT NULL,
	can_subnet	character(1) NOT NULL,
	parent_netblock_id	integer  NULL,
	netblock_status	varchar(50) NOT NULL,
	nic_id	varchar(255)  NULL,
	nic_company_id	integer  NULL,
	ip_universe_id	integer NOT NULL,
	description	varchar(255)  NULL,
	external_id	varchar(255)  NULL,
	reservation_ticket_number	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'netblock', false);
ALTER TABLE netblock
	ALTER netblock_id
	SET DEFAULT nextval('netblock_netblock_id_seq'::regclass);
ALTER TABLE netblock
	ALTER ip_universe_id
	SET DEFAULT 0;
INSERT INTO netblock (
	netblock_id,
	ip_address,
	netblock_type,
	is_single_address,
	can_subnet,
	parent_netblock_id,
	netblock_status,
	nic_id,
	nic_company_id,
	ip_universe_id,
	description,
	external_id,		-- new column (external_id)
	reservation_ticket_number,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	netblock_id,
	ip_address,
	netblock_type,
	is_single_address,
	can_subnet,
	parent_netblock_id,
	netblock_status,
	nic_id,
	nic_company_id,
	ip_universe_id,
	description,
	NULL,		-- new column (external_id)
	reservation_ticket_number,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM netblock_v79;

INSERT INTO audit.netblock (
	netblock_id,
	ip_address,
	netblock_type,
	is_single_address,
	can_subnet,
	parent_netblock_id,
	netblock_status,
	nic_id,
	nic_company_id,
	ip_universe_id,
	description,
	external_id,		-- new column (external_id)
	reservation_ticket_number,
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
	netblock_id,
	ip_address,
	netblock_type,
	is_single_address,
	can_subnet,
	parent_netblock_id,
	netblock_status,
	nic_id,
	nic_company_id,
	ip_universe_id,
	description,
	NULL,		-- new column (external_id)
	reservation_ticket_number,
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
FROM audit.netblock_v79;

ALTER TABLE netblock
	ALTER netblock_id
	SET DEFAULT nextval('netblock_netblock_id_seq'::regclass);
ALTER TABLE netblock
	ALTER ip_universe_id
	SET DEFAULT 0;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE netblock ADD CONSTRAINT ak_netblock_params UNIQUE (ip_address, netblock_type, ip_universe_id, is_single_address);
ALTER TABLE netblock ADD CONSTRAINT pk_netblock PRIMARY KEY (netblock_id);

-- Table/Column Comments
COMMENT ON COLUMN netblock.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX idx_netblk_netblkstatus ON netblock USING btree (netblock_status);
CREATE INDEX idx_netblock_host_ip_address ON netblock USING btree (host(ip_address));
CREATE INDEX ix_netblk_ip_address ON netblock USING btree (ip_address);
CREATE INDEX ix_netblk_ip_address_parent ON netblock USING btree (parent_netblock_id);
CREATE INDEX netblock_case_idx ON netblock USING btree ((
CASE
    WHEN family(ip_address) = 4 THEN ip_address - '0.0.0.0'::inet
    ELSE NULL::bigint
END));
CREATE INDEX xif5netblock ON netblock USING btree (nic_company_id);
CREATE INDEX xif6netblock ON netblock USING btree (ip_universe_id);
CREATE INDEX xif7netblock ON netblock USING btree (netblock_type);

-- CHECK CONSTRAINTS
ALTER TABLE netblock ADD CONSTRAINT check_yes_no_172122967
	CHECK (can_subnet = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE netblock ADD CONSTRAINT ckc_is_single_address_netblock
	CHECK ((is_single_address IS NULL) OR ((is_single_address = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_single_address)::text = upper((is_single_address)::text))));

-- FOREIGN KEYS FROM
-- consider FK between netblock and dns_record
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsid_nblk_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and layer3_network
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3_net_def_gate_nbid
	FOREIGN KEY (default_gateway_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and layer3_network
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3net_rndv_pt_nblk_id
	FOREIGN KEY (rendezvous_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and layer3_network
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_layer3_network_netblock_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and netblock_collection_netblock
ALTER TABLE netblock_collection_netblock
	ADD CONSTRAINT fk_nblk_col_nblk_nblkid
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and network_range
ALTER TABLE network_range
	ADD CONSTRAINT fk_net_range_start_netblock
	FOREIGN KEY (start_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and network_range
ALTER TABLE network_range
	ADD CONSTRAINT fk_net_range_stop_netblock
	FOREIGN KEY (stop_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and static_route_template
ALTER TABLE static_route_template
	ADD CONSTRAINT fk_netblock_st_rt_dst_net
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and static_route_template
ALTER TABLE static_route_template
	ADD CONSTRAINT fk_netblock_st_rt_src_net
	FOREIGN KEY (netblock_src_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and network_interface_netblock
ALTER TABLE network_interface_netblock
	ADD CONSTRAINT fk_netint_nb_netint_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id) DEFERRABLE;
-- consider FK between netblock and network_interface
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_netblk_v4id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and network_range
ALTER TABLE network_range
	ADD CONSTRAINT fk_netrng_prngnblkid
	FOREIGN KEY (parent_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and shared_netblock
ALTER TABLE shared_netblock
	ADD CONSTRAINT fk_shared_net_netblock_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and site_netblock
ALTER TABLE site_netblock
	ADD CONSTRAINT fk_site_netblock_ref_netblock
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
-- consider FK between netblock and static_route
ALTER TABLE static_route
	ADD CONSTRAINT fk_statrt_nblk_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);

-- FOREIGN KEYS TO
-- consider FK netblock and ip_universe
ALTER TABLE netblock
	ADD CONSTRAINT fk_nblk_ip_universe_id
	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);
-- consider FK netblock and netblock
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblk_netblk_parid
	FOREIGN KEY (parent_netblock_id) REFERENCES netblock(netblock_id) DEFERRABLE INITIALLY DEFERRED;
-- consider FK netblock and company
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblock_company
	FOREIGN KEY (nic_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK netblock and val_netblock_type
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblock_nblk_typ
	FOREIGN KEY (netblock_type) REFERENCES val_netblock_type(netblock_type);
-- consider FK netblock and val_netblock_status
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblock_v_netblock_stat
	FOREIGN KEY (netblock_status) REFERENCES val_netblock_status(netblock_status);

-- TRIGGERS
-- consider NEW jazzhands.manipulate_netblock_parentage_after
CREATE OR REPLACE FUNCTION jazzhands.manipulate_netblock_parentage_after()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$

DECLARE
	nbtype				record;
	v_netblock_type		val_netblock_type.netblock_type%TYPE;
	v_row_count			integer;
	v_trigger			record;
BEGIN
	/*
	 * Get the parameters for the given netblock type to see if we need
	 * to do anything
	 */

	IF TG_OP = 'DELETE' THEN
		v_trigger := OLD;
	ELSE
		v_trigger := NEW;
	END IF;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = v_trigger.netblock_type;

	IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
		RETURN NULL;
	END IF;

	/*
	 * If we are deleting, attach all children to the parent and wipe
	 * hands on pants;
	 */
	IF TG_OP = 'DELETE' THEN
		UPDATE
			netblock
		SET
			parent_netblock_id = OLD.parent_netblock_id
		WHERE
			parent_netblock_id = OLD.netblock_id;

		GET DIAGNOSTICS v_row_count = ROW_COUNT;
	--	IF (v_row_count > 0) THEN
			RAISE DEBUG 'Set parent for all child netblocks of deleted netblock % (address %, is_single_address %) to % (% rows updated)',
				OLD.netblock_id,
				OLD.ip_address,
				OLD.is_single_address,
				OLD.parent_netblock_id,
				v_row_count;
	--	END IF;

		RETURN NULL;
	END IF;

	IF NEW.is_single_address = 'Y' THEN
		RETURN NULL;
	END IF;

	RAISE DEBUG 'Setting parent for all child netblocks of parent netblock % that belong to %',
		NEW.parent_netblock_id,
		NEW.netblock_id;

	IF NEW.parent_netblock_id IS NULL THEN
		UPDATE
			netblock
		SET
			parent_netblock_id = NEW.netblock_id
		WHERE
			parent_netblock_id IS NULL AND
			ip_address <<= NEW.ip_address AND
			netblock_id != NEW.netblock_id AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id = NEW.ip_universe_id;
		RETURN NULL;
	ELSE
		-- We don't need to specify the netblock_type or ip_universe_id here
		-- because the parent would have had to match
		UPDATE
			netblock
		SET
			parent_netblock_id = NEW.netblock_id
		WHERE
			parent_netblock_id = NEW.parent_netblock_id AND
			ip_address <<= NEW.ip_address AND
			netblock_id != NEW.netblock_id;
		RETURN NULL;
	END IF;
END;
$function$
;
CREATE CONSTRAINT TRIGGER aaa_ta_manipulate_netblock_parentage AFTER INSERT OR DELETE ON netblock NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE manipulate_netblock_parentage_after();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.validate_netblock
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	nbtype				RECORD;
	v_netblock_id		netblock.netblock_id%TYPE;
	parent_netblock		RECORD;
	universes			integer[];
	netmask_bits		integer;
	tally				integer;
BEGIN
	IF NEW.ip_address IS NULL THEN
		RAISE EXCEPTION 'Column ip_address may not be null'
			USING ERRCODE = 'not_null_violation';
	END IF;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	IF NEW.is_single_address = 'Y' THEN
		IF nbtype.db_forced_hierarchy = 'Y' THEN
			RAISE DEBUG 'Calculating netmask for new netblock';

			v_netblock_id := netblock_utils.find_best_parent_id(
				NEW.ip_address,
				NULL,
				NEW.netblock_type,
				NEW.ip_universe_id,
				NEW.is_single_address,
				NEW.netblock_id
				);

			IF v_netblock_id IS NULL THEN
				RAISE EXCEPTION 'A single address (%) must be the child of a parent netblock, which must have can_subnet=N', NEW.ip_address
					USING ERRCODE = 'JH105';
			END IF;

			SELECT masklen(ip_address) INTO netmask_bits FROM
				netblock WHERE netblock_id = v_netblock_id;

			NEW.ip_address := set_masklen(NEW.ip_address, netmask_bits);
		END IF;
	END IF;

	/* Done with handling of netmasks */

	IF NEW.can_subnet = 'Y' AND NEW.is_single_address = 'Y' THEN
		RAISE EXCEPTION 'Single addresses may not be subnettable'
			USING ERRCODE = 'JH106';
	END IF;

	IF NEW.is_single_address = 'N' AND (NEW.ip_address != cidr(NEW.ip_address))
			THEN
		RAISE EXCEPTION
			'Non-network bits must be zero if is_single_address is N for %',
			NEW.ip_address
			USING ERRCODE = 'JH103';
	END IF;

	/*
	 * This used to only happen for not-rfc1918 space, but that sort of
	 * uniqueness enforcement is done through ip universes now.
	 */
	PERFORM netblock_id
	   FROM netblock
	  WHERE ip_address = NEW.ip_address AND
			ip_universe_id = NEW.ip_universe_id AND
			netblock_type = NEW.netblock_type AND
			is_single_address = NEW.is_single_address;
	IF (TG_OP = 'INSERT' AND FOUND) THEN
		RAISE EXCEPTION 'Unique Constraint Violated on IP Address: %',
			NEW.ip_address
			USING ERRCODE= 'unique_violation';
	END IF;
	IF (TG_OP = 'UPDATE') THEN
		IF (NEW.ip_address != OLD.ip_address AND FOUND) THEN
			RAISE EXCEPTION
				'Unique Constraint Violated on IP Address: %',
				NEW.ip_address
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	/*
	 * for networks, check for uniqueness across ip universe and ip visibility
	 */
	IF NEW.is_single_address = 'N' THEN
		WITH x AS (
				SELECT	ip_universe_id
				FROM	ip_universe
				WHERE	ip_namespace IN (
							SELECT ip_namespace FROM ip_universe
							WHERE ip_universe_id = NEW.ip_universe_id
						)
				AND		ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	visible_ip_universe_id
				FROM	ip_universe_visibility
				WHERE	ip_universe_id = NEW.ip_universe_id
				AND		ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	ip_universe_id
				FROM	ip_universe_visibility
				WHERE	visible_ip_universe_id = NEW.ip_universe_id
				AND		visible_ip_universe_id != NEW.ip_universe_id
		) SELECT count(*) INTO tally
		FROM netblock
		WHERE ip_address = NEW.ip_address AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id IN (select ip_universe_id FROM x) AND
			is_single_address = 'N' AND
			netblock_id != NEW.netblock_id
		;

		IF tally >  0 THEN
			RAISE EXCEPTION
				'IP Universe Constraint Violated on IP Address: % Universe: %',
				NEW.ip_address, NEW.ip_universe_id
				USING ERRCODE= 'unique_violation';
		END IF;

		IF NEW.can_subnet = 'N' THEN
			WITH x AS (
				SELECT	ip_universe_id
				FROM	ip_universe
				WHERE	ip_namespace IN (
							SELECT ip_namespace FROM ip_universe
							WHERE ip_universe_id = NEW.ip_universe_id
						)
				AND		ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	visible_ip_universe_id
				FROM	ip_universe_visibility
				WHERE	ip_universe_id = NEW.ip_universe_id
				AND		visible_ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	ip_universe_id
				FROM	ip_universe_visibility
				WHERE	visible_ip_universe_id = NEW.ip_universe_id
				AND		ip_universe_id != NEW.ip_universe_id
			) SELECT count(*) INTO tally
			FROM netblock
			WHERE
				ip_universe_id IN (select ip_universe_id FROM x) AND
				(
					ip_address <<= NEW.ip_address OR
					ip_address >>= NEW.ip_address
				) AND
				netblock_type = NEW.netblock_type AND
				is_single_address = 'N' AND
				can_subnet = 'N' AND
				netblock_id != NEW.netblock_id
			;

			IF tally >  0 THEN
				RAISE EXCEPTION
					'Can Subnet = N IP Universe Constraint Violated on IP Address: % Universe: %',
					NEW.ip_address, NEW.ip_universe_id
					USING ERRCODE= 'unique_violation';
			END IF;
		END IF;
	END IF;

	/*
	 * Parent validation is performed in the deferred after trigger
	 */

	 RETURN NEW;
END;
$function$
;
CREATE TRIGGER tb_a_validate_netblock BEFORE INSERT OR UPDATE OF netblock_id, ip_address, netblock_type, is_single_address, can_subnet, parent_netblock_id, ip_universe_id ON netblock FOR EACH ROW EXECUTE PROCEDURE validate_netblock();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.manipulate_netblock_parentage_before
CREATE OR REPLACE FUNCTION jazzhands.manipulate_netblock_parentage_before()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$

DECLARE
	nbtype				record;
	v_netblock_type		val_netblock_type.netblock_type%TYPE;
BEGIN
	/*
	 * Get the parameters for the given netblock type to see if we need
	 * to do anything
	 */

	RAISE DEBUG 'Performing % on netblock %', TG_OP, NEW.netblock_id;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
		RETURN NEW;
	END IF;

	/*
	 * Find the correct parent netblock
	 */

	RAISE DEBUG 'Setting forced hierarchical netblock %', NEW.netblock_id;
	NEW.parent_netblock_id := netblock_utils.find_best_parent_id(
		NEW.ip_address,
		NULL,
		NEW.netblock_type,
		NEW.ip_universe_id,
		NEW.is_single_address,
		NEW.netblock_id
		);

	RAISE DEBUG 'Setting parent for netblock % (%, type %, universe %, single-address %) to %',
		NEW.netblock_id, NEW.ip_address, NEW.netblock_type,
		NEW.ip_universe_id, NEW.is_single_address,
		NEW.parent_netblock_id;

	/*
	 * If we are an end-node, then we're done
	 */

	IF NEW.is_single_address = 'Y' THEN
		RETURN NEW;
	END IF;

	/*
	 * If we're updating and we're a container netblock, find
	 * all of the children of our new parent that should be ours and take
	 * them.  They will already be guaranteed to be of the correct
	 * netblock_type and ip_universe_id.  We can't do this for inserts
	 * because the row doesn't exist causing foreign key problems, so
	 * that needs to be done in an after trigger.
	 */
	IF TG_OP = 'UPDATE' THEN
		RAISE DEBUG 'Setting parent for all child netblocks of parent netblock % that belong to %',
			NEW.parent_netblock_id,
			NEW.netblock_id;
		UPDATE
			netblock
		SET
			parent_netblock_id = NEW.netblock_id
		WHERE
			parent_netblock_id = NEW.parent_netblock_id AND
			ip_address <<= NEW.ip_address AND
			netblock_id != NEW.netblock_id;

		RAISE DEBUG 'Setting parent for all child netblocks of netblock % that no longer belong to it to %',
			NEW.parent_netblock_id,
			NEW.netblock_id;
		RAISE DEBUG 'Setting parent % to %',
			OLD.netblock_id,
			OLD.parent_netblock_id;
		UPDATE
			netblock
		SET
			parent_netblock_id = OLD.parent_netblock_id
		WHERE
			parent_netblock_id = NEW.netblock_id AND
			(ip_universe_id != NEW.ip_universe_id OR
			 netblock_type != NEW.netblock_type OR
			 NOT(ip_address <<= NEW.ip_address));
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE TRIGGER tb_manipulate_netblock_parentage BEFORE INSERT OR UPDATE OF ip_address, netblock_type, ip_universe_id, netblock_id, can_subnet, is_single_address ON netblock FOR EACH ROW EXECUTE PROCEDURE manipulate_netblock_parentage_before();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.check_ip_universe_netblock
CREATE OR REPLACE FUNCTION jazzhands.check_ip_universe_netblock()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM *
	FROM dns_record
	WHERE netblock_id IN (NEW.netblock_id, OLD.netblock_id)
	AND ip_universe_id != NEW.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION
			'IP Universes for netblocks must match dns records and netblocks'
			USING ERRCODE = 'foreign_key_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_check_ip_universe_netblock AFTER UPDATE OF netblock_id, ip_universe_id ON netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE check_ip_universe_netblock();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.nb_dns_a_rec_validation
CREATE OR REPLACE FUNCTION jazzhands.nb_dns_a_rec_validation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tal	integer;
BEGIN
	IF family(OLD.ip_address) != family(NEW.ip_address) THEN
		--
		-- The dns_value_record_id check is not strictly needed since
		-- the "dns_value_record_id" points to something of the same type
		-- and the trigger would catch that, but its here in case some
		-- assumption later changes and its good to test for..
		IF family(NEW.ip_address) = 6 THEN
			SELECT count(*)
			INTO	_tal
			FROM	dns_record
			WHERE	(
						netblock_id = NEW.netblock_id
						AND		dns_type = 'A'
					)
			OR		(
						dns_value_record_id IN (
							SELECT dns_record_id
							FROM	dns_record
							WHERE	netblock_id = NEW.netblock_id
							AND		dns_type = 'A'
						)
					);

			IF _tal > 0 THEN
				RAISE EXCEPTION 'A records must be assigned to IPv4 records'
					USING ERRCODE = 'JH200';
			END IF;
		END IF;

		IF family(NEW.ip_address) = 4 THEN
			SELECT count(*)
			INTO	_tal
			FROM	dns_record
			WHERE	(
						netblock_id = NEW.netblock_id
						AND		dns_type = 'AAAA'
					)
			OR		(
						dns_value_record_id IN (
							SELECT dns_record_id
							FROM	dns_record
							WHERE	netblock_id = NEW.netblock_id
							AND		dns_type = 'AAAA'
						)
					);

			IF _tal > 0 THEN
				RAISE EXCEPTION 'AAAA records must be assigned to IPv6 records'
					USING ERRCODE = 'JH200';
			END IF;
		END IF;
	END IF;

	IF NEW.is_single_address = 'N' THEN
			SELECT count(*)
			INTO	_tal
			FROM	dns_record
			WHERE	netblock_id = NEW.netblock_id
			AND		dns_type IN ('A', 'AAAA');

		IF _tal > 0 THEN
			RAISE EXCEPTION 'Non-single addresses may not have % records', NEW.dns_type
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_nb_dns_a_rec_validation BEFORE UPDATE OF ip_address, is_single_address ON netblock FOR EACH ROW EXECUTE PROCEDURE nb_dns_a_rec_validation();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.netblock_single_address_ni
CREATE OR REPLACE FUNCTION jazzhands.netblock_single_address_ni()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF (NEW.is_single_address = 'N' AND OLD.is_single_address = 'Y') OR
		(NEW.netblock_type != 'default' AND OLD.netblock_type = 'default')
			THEN
		select count(*)
		INTO _tally
		FROM network_interface
		WHERE netblock_id = NEW.netblock_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'network interfaces must refer to single ip addresses of type default address (%,%)', NEW.ip_address, NEW.netblock_id
				USING errcode = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_netblock_single_address_ni BEFORE UPDATE OF is_single_address, netblock_type ON netblock FOR EACH ROW EXECUTE PROCEDURE netblock_single_address_ni();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.validate_netblock_parentage
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_parentage()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	nbrec			record;
	realnew			record;
	nbtype			record;
	parent_nbid		netblock.netblock_id%type;
	ipaddr			inet;
	parent_ipaddr	inet;
	single_count	integer;
	nonsingle_count	integer;
	pip	    		netblock.ip_address%type;
BEGIN

	RAISE DEBUG 'Validating % of netblock %', TG_OP, NEW.netblock_id;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	/*
	 * It's possible that due to delayed triggers that what is stored in
	 * NEW is not current, so fetch the current values
	 */

	SELECT * INTO realnew FROM netblock WHERE netblock_id =
		NEW.netblock_id;
	IF NOT FOUND THEN
		/*
		 * If the netblock isn't there, it was subsequently deleted, so
		 * our parentage doesn't need to be checked
		 */
		RETURN NULL;
	END IF;


	/*
	 * If the parent changed above (or somewhere else between update and
	 * now), just bail, because another trigger will have been fired that
	 * we can do the full check with.
	 */
	IF NEW.parent_netblock_id != realnew.parent_netblock_id AND
		realnew.parent_netblock_id IS NOT NULL
	THEN
		RAISE DEBUG '... skipping for now';
		RETURN NULL;
	END IF;

	/*
	 * Validate that parent and all children are of the same netblock_type and
	 * in the same ip_universe.  We care about this even if the
	 * netblock type is not a validated type.
	 */

	RAISE DEBUG 'Verifying child ip_universe and type match';
	PERFORM netblock_id FROM netblock WHERE
		parent_netblock_id = realnew.netblock_id AND
		netblock_type != realnew.netblock_type AND
		ip_universe_id != realnew.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 'JH109';
	END IF;

	RAISE DEBUG '... OK';

	/*
	 * validate that this netblock is attached to its correct parent
	 */
	IF realnew.parent_netblock_id IS NULL THEN
		IF nbtype.is_validated_hierarchy='N' THEN
			RETURN NULL;
		END IF;
		RAISE DEBUG 'Checking hierarchical netblock_id % with NULL parent',
			NEW.netblock_id;

		IF realnew.is_single_address = 'Y' THEN
			RAISE 'A single address (%) must be the child of a parent netblock, which must have can_subnet=N',
				realnew.ip_address
				USING ERRCODE = 'JH105';
		END IF;

		/*
		 * Validate that a netblock has a parent, unless
		 * it is the root of a hierarchy
		 */
		parent_nbid := netblock_utils.find_best_parent_id(
			realnew.ip_address,
			NULL,
			realnew.netblock_type,
			realnew.ip_universe_id,
			realnew.is_single_address,
			realnew.netblock_id
		);

		IF parent_nbid IS NOT NULL THEN
			SELECT * INTO nbrec FROM netblock WHERE netblock_id =
				parent_nbid;

			RAISE EXCEPTION 'Netblock % (%) has NULL parent; should be % (%)',
				realnew.netblock_id, realnew.ip_address,
				parent_nbid, nbrec.ip_address USING ERRCODE = 'JH102';
		END IF;

		/*
		 * Validate that none of the other top-level netblocks should
		 * belong to this netblock
		 */
		PERFORM netblock_id FROM netblock WHERE
			parent_netblock_id IS NULL AND
			netblock_id != NEW.netblock_id AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id = NEW.ip_universe_id AND
			ip_address <<= NEW.ip_address;
		IF FOUND THEN
			RAISE EXCEPTION 'Other top-level netblocks should belong to this parent'
				USING ERRCODE = 'JH108';
		END IF;
	ELSE
	 	/*
		 * Reject a block that is self-referential
		 */
	 	IF realnew.parent_netblock_id = realnew.netblock_id THEN
			RAISE EXCEPTION 'Netblock may not have itself as a parent'
				USING ERRCODE = 'JH101';
		END IF;

		SELECT * INTO nbrec FROM netblock WHERE netblock_id =
			realnew.parent_netblock_id;

		/*
		 * This shouldn't happen, but may because of deferred constraints
		 */
		IF NOT FOUND THEN
			RAISE EXCEPTION 'Parent netblock % does not exist',
			realnew.parent_netblock_id
			USING ERRCODE = 'foreign_key_violation';
		END IF;

		IF nbrec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'A parent netblock (% for %) may not be a single address',
			nbrec.netblock_id, realnew.ip_address
			USING ERRCODE = 'JH10A';
		END IF;

		IF nbrec.ip_universe_id != realnew.ip_universe_id OR
				nbrec.netblock_type != realnew.netblock_type THEN
			RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 'JH109';
		END IF;

		IF nbtype.is_validated_hierarchy='N' THEN
			RETURN NULL;
		ELSE
			parent_nbid := netblock_utils.find_best_parent_id(
				realnew.ip_address,
				NULL,
				realnew.netblock_type,
				realnew.ip_universe_id,
				realnew.is_single_address,
				realnew.netblock_id
				);

			IF realnew.can_subnet = 'N' THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					is_single_address = 'N';
				IF FOUND THEN
					RAISE EXCEPTION 'A non-subnettable netblock (%) may not have child network netblocks',
					realnew.netblock_id
					USING ERRCODE = 'JH10B';
				END IF;
			END IF;
			IF realnew.is_single_address = 'Y' THEN
				SELECT * INTO nbrec FROM netblock
					WHERE netblock_id = realnew.parent_netblock_id;
				IF (nbrec.can_subnet = 'Y') THEN
					RAISE 'Parent netblock % for single-address % must have can_subnet=N',
						nbrec.netblock_id,
						realnew.ip_address
						USING ERRCODE = 'JH10D';
				END IF;
				IF (masklen(realnew.ip_address) !=
						masklen(nbrec.ip_address)) THEN
					RAISE 'Parent netblock % does not have the same netmask as single-address child % (% vs %)',
						parent_nbid, realnew.netblock_id,
						masklen(nbrec.ip_address),
						masklen(realnew.ip_address)
						USING ERRCODE = 'JH105';
				END IF;
			END IF;
			IF (parent_nbid IS NULL OR realnew.parent_netblock_id != parent_nbid) THEN
				SELECT ip_address INTO parent_ipaddr FROM netblock
				WHERE
					netblock_id = parent_nbid;
				SELECT ip_address INTO ipaddr FROM netblock WHERE
					netblock_id = realnew.parent_netblock_id;

				RAISE EXCEPTION
					'Parent netblock % (%) for netblock % (%) is not the correct parent (should be % (%))',
					realnew.parent_netblock_id, ipaddr,
					realnew.netblock_id, realnew.ip_address,
					parent_nbid, parent_ipaddr
					USING ERRCODE = 'JH102';
			END IF;
			/*
			 * Validate that all children are is_single_address='Y' or
			 * all children are is_single_address='N'
			 */
			SELECT count(*) INTO single_count FROM netblock WHERE
				is_single_address='Y' and parent_netblock_id =
				realnew.parent_netblock_id;
			SELECT count(*) INTO nonsingle_count FROM netblock WHERE
				is_single_address='N' and parent_netblock_id =
				realnew.parent_netblock_id;

			IF (single_count > 0 and nonsingle_count > 0) THEN
				SELECT * INTO nbrec FROM netblock WHERE netblock_id =
					realnew.parent_netblock_id;
				RAISE EXCEPTION 'Netblock % (%) may not have direct children for both single and multiple addresses simultaneously',
					nbrec.netblock_id, nbrec.ip_address
					USING ERRCODE = 'JH107';
			END IF;
			/*
			 *  If we're updating and we changed our ip_address (including
			 *  netmask bits), then check that our children still belong to
			 *  us
			 */
			 IF (TG_OP = 'UPDATE' AND NEW.ip_address != OLD.ip_address) THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					((is_single_address = 'Y' AND NEW.ip_address !=
						ip_address::cidr) OR
					(is_single_address = 'N' AND realnew.netblock_id !=
						netblock_utils.find_best_parent_id(netblock_id)));
				IF FOUND THEN
					RAISE EXCEPTION 'Update for netblock % (%) causes parent to have children that do not belong to it',
						realnew.netblock_id, realnew.ip_address
						USING ERRCODE = 'JH10E';
				END IF;
			END IF;

			/*
			 * Validate that none of the children of the parent netblock are
			 * children of this netblock (e.g. if inserting into the middle
			 * of the hierarchy)
			 */
			IF (realnew.is_single_address = 'N') THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.parent_netblock_id AND
					netblock_id != realnew.netblock_id AND
					ip_address <<= realnew.ip_address;
				IF FOUND THEN
					RAISE EXCEPTION 'Other netblocks have children that should belong to parent % (%)',
						realnew.parent_netblock_id, realnew.ip_address
						USING ERRCODE = 'JH108';
				END IF;
			END IF;
		END IF;
	END IF;

	RETURN NULL;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_parentage AFTER INSERT OR UPDATE OF netblock_id, ip_address, netblock_type, is_single_address, can_subnet, parent_netblock_id, ip_universe_id ON netblock DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE PROCEDURE validate_netblock_parentage();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.validate_netblock_to_range_changes
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_to_range_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM
	FROM	network_range nr
			JOIN netblock p on p.netblock_id = nr.parent_netblock_id
			JOIN netblock start on start.netblock_id = nr.start_netblock_id
			JOIN netblock stop on stop.netblock_id = nr.stop_netblock_id
			JOIN val_network_range_type vnrt USING (network_range_type)
	WHERE	( p.netblock_id = NEW.netblock_id
				OR start.netblock_id = NEW.netblock_id
				OR stop.netblock_id = NEW.netblock_id
			) AND (
					p.can_subnet = 'Y'
				OR 	start.is_single_address = 'N'
				OR 	stop.is_single_address = 'N'
				OR NOT (
					host(start.ip_address)::inet <<= p.ip_address
					AND host(stop.ip_address)::inet <<= p.ip_address
				)
				OR ( vnrt.netblock_type IS NOT NULL
				AND NOT
					( start.netblock_type IS NOT DISTINCT FROM vnrt.netblock_type
					AND	stop.netblock_type IS NOT DISTINCT FROM vnrt.netblock_type
					)
				)
			)
	;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock changes conflict with network range requirements '
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END; $function$
;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_to_range_changes AFTER UPDATE OF ip_address, is_single_address, can_subnet, netblock_type ON netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE validate_netblock_to_range_changes();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'netblock');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'netblock');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'netblock');
ALTER SEQUENCE netblock_netblock_id_seq
	 OWNED BY netblock.netblock_id;
DROP TABLE IF EXISTS netblock_v79;
DROP TABLE IF EXISTS audit.netblock_v79;
-- DONE DEALING WITH TABLE netblock
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE netblock_collection
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock_collection', 'netblock_collection');

-- FOREIGN KEYS FROM
ALTER TABLE netblock_collection_hier DROP CONSTRAINT IF EXISTS fk_nblk_c_hier_chld_nc;
ALTER TABLE netblock_collection_hier DROP CONSTRAINT IF EXISTS fk_nblk_c_hier_prnt_nc;
ALTER TABLE netblock_collection_netblock DROP CONSTRAINT IF EXISTS fk_nblk_col_nblk_nbcolid;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_nblk_coll_id;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_pv_nblkcol_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.netblock_collection DROP CONSTRAINT IF EXISTS fk_nblk_coll_v_nblk_c_typ;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'netblock_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.netblock_collection DROP CONSTRAINT IF EXISTS pk_netblock_collection;
ALTER TABLE jazzhands.netblock_collection DROP CONSTRAINT IF EXISTS uq_netblock_collection_name;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifk_nb_col_val_nb_col_typ";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.netblock_collection DROP CONSTRAINT IF EXISTS check_ip_family_1970633785;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_netblock_collection ON jazzhands.netblock_collection;
DROP TRIGGER IF EXISTS trigger_audit_netblock_collection ON jazzhands.netblock_collection;
DROP TRIGGER IF EXISTS trigger_validate_netblock_collection_type_change ON jazzhands.netblock_collection;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'netblock_collection');
---- BEGIN audit.netblock_collection TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'netblock_collection', 'netblock_collection');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'netblock_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.netblock_collection DROP CONSTRAINT IF EXISTS netblock_collection_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_netblock_collection_pk_netblock_collection";
DROP INDEX IF EXISTS "audit"."aud_netblock_collection_uq_netblock_collection_name";
DROP INDEX IF EXISTS "audit"."netblock_collection_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.netblock_collection TEARDOWN


ALTER TABLE netblock_collection RENAME TO netblock_collection_v79;
ALTER TABLE audit.netblock_collection RENAME TO netblock_collection_v79;

CREATE TABLE netblock_collection
(
	netblock_collection_id	integer NOT NULL,
	netblock_collection_name	varchar(255) NOT NULL,
	netblock_collection_type	varchar(50)  NULL,
	netblock_ip_family_restrict	integer  NULL,
	description	varchar(255)  NULL,
	external_id	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'netblock_collection', false);
ALTER TABLE netblock_collection
	ALTER netblock_collection_id
	SET DEFAULT nextval('netblock_collection_netblock_collection_id_seq'::regclass);
INSERT INTO netblock_collection (
	netblock_collection_id,
	netblock_collection_name,
	netblock_collection_type,
	netblock_ip_family_restrict,
	description,
	external_id,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	netblock_collection_id,
	netblock_collection_name,
	netblock_collection_type,
	netblock_ip_family_restrict,
	description,
	NULL,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM netblock_collection_v79;

INSERT INTO audit.netblock_collection (
	netblock_collection_id,
	netblock_collection_name,
	netblock_collection_type,
	netblock_ip_family_restrict,
	description,
	external_id,		-- new column (external_id)
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
	netblock_collection_id,
	netblock_collection_name,
	netblock_collection_type,
	netblock_ip_family_restrict,
	description,
	NULL,		-- new column (external_id)
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
FROM audit.netblock_collection_v79;

ALTER TABLE netblock_collection
	ALTER netblock_collection_id
	SET DEFAULT nextval('netblock_collection_netblock_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE netblock_collection ADD CONSTRAINT pk_netblock_collection PRIMARY KEY (netblock_collection_id);
ALTER TABLE netblock_collection ADD CONSTRAINT uq_netblock_collection_name UNIQUE (netblock_collection_name, netblock_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN netblock_collection.netblock_ip_family_restrict IS 'member netblocks must have  and netblock collections must match this restriction, if set.';
COMMENT ON COLUMN netblock_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX xifk_nb_col_val_nb_col_typ ON netblock_collection USING btree (netblock_collection_type);

-- CHECK CONSTRAINTS
ALTER TABLE netblock_collection ADD CONSTRAINT check_ip_family_1970633785
	CHECK (netblock_ip_family_restrict = ANY (ARRAY[4, 6]));

-- FOREIGN KEYS FROM
-- consider FK between netblock_collection and netblock_collection_hier
ALTER TABLE netblock_collection_hier
	ADD CONSTRAINT fk_nblk_c_hier_chld_nc
	FOREIGN KEY (child_netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK between netblock_collection and netblock_collection_hier
ALTER TABLE netblock_collection_hier
	ADD CONSTRAINT fk_nblk_c_hier_prnt_nc
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK between netblock_collection and netblock_collection_netblock
ALTER TABLE netblock_collection_netblock
	ADD CONSTRAINT fk_nblk_col_nblk_nbcolid
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK between netblock_collection and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nblk_coll_id
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK between netblock_collection and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_pv_nblkcol_id
	FOREIGN KEY (property_value_nblk_coll_id) REFERENCES netblock_collection(netblock_collection_id);

-- FOREIGN KEYS TO
-- consider FK netblock_collection and val_netblock_collection_type
ALTER TABLE netblock_collection
	ADD CONSTRAINT fk_nblk_coll_v_nblk_c_typ
	FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type);

-- TRIGGERS
-- consider NEW jazzhands.validate_netblock_collection_type_change
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.netblock_collection_type != NEW.netblock_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.netblock_collection_type = OLD.netblock_collection_type
		AND	p.netblock_collection_id = NEW.netblock_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'netblock_collection % of type % is used by % restricted properties.',
				NEW.netblock_collection_id, NEW.netblock_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_validate_netblock_collection_type_change BEFORE UPDATE OF netblock_collection_type ON netblock_collection FOR EACH ROW EXECUTE PROCEDURE validate_netblock_collection_type_change();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'netblock_collection');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'netblock_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'netblock_collection');
ALTER SEQUENCE netblock_collection_netblock_collection_id_seq
	 OWNED BY netblock_collection.netblock_collection_id;
DROP TABLE IF EXISTS netblock_collection_v79;
DROP TABLE IF EXISTS audit.netblock_collection_v79;
-- DONE DEALING WITH TABLE netblock_collection
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE operating_system
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'operating_system', 'operating_system');

-- FOREIGN KEYS FROM
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_dev_os_id;
ALTER TABLE operating_system_snapshot DROP CONSTRAINT IF EXISTS fk_os_snap_osid;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_osid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS fk_os_company;
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS fk_os_fk_val_dev_arch;
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS fk_os_os_family;
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS fk_os_ref_swpkgrepos;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'operating_system');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS pk_operating_system;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_os_company";
DROP INDEX IF EXISTS "jazzhands"."xif_os_os_family";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_operating_system ON jazzhands.operating_system;
DROP TRIGGER IF EXISTS trigger_audit_operating_system ON jazzhands.operating_system;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'operating_system');
---- BEGIN audit.operating_system TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'operating_system', 'operating_system');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'operating_system');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.operating_system DROP CONSTRAINT IF EXISTS operating_system_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_operating_system_pk_operating_system";
DROP INDEX IF EXISTS "audit"."operating_system_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.operating_system TEARDOWN


ALTER TABLE operating_system RENAME TO operating_system_v79;
ALTER TABLE audit.operating_system RENAME TO operating_system_v79;

CREATE TABLE operating_system
(
	operating_system_id	integer NOT NULL,
	operating_system_name	varchar(255) NOT NULL,
	company_id	integer  NULL,
	major_version	varchar(50) NOT NULL,
	version	varchar(255) NOT NULL,
	operating_system_family	varchar(50)  NULL,
	processor_architecture	varchar(50)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'operating_system', false);
ALTER TABLE operating_system
	ALTER operating_system_id
	SET DEFAULT nextval('operating_system_operating_system_id_seq'::regclass);
INSERT INTO operating_system (
	operating_system_id,
	operating_system_name,
	company_id,
	major_version,
	version,
	operating_system_family,
	processor_architecture,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	operating_system_id,
	operating_system_name,
	company_id,
	major_version,
	version,
	operating_system_family,
	processor_architecture,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM operating_system_v79;

INSERT INTO audit.operating_system (
	operating_system_id,
	operating_system_name,
	company_id,
	major_version,
	version,
	operating_system_family,
	processor_architecture,
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
	operating_system_id,
	operating_system_name,
	company_id,
	major_version,
	version,
	operating_system_family,
	processor_architecture,
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
FROM audit.operating_system_v79;

ALTER TABLE operating_system
	ALTER operating_system_id
	SET DEFAULT nextval('operating_system_operating_system_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE operating_system ADD CONSTRAINT pk_operating_system PRIMARY KEY (operating_system_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_os_company ON operating_system USING btree (company_id);
CREATE INDEX xif_os_os_family ON operating_system USING btree (operating_system_family);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between operating_system and device
ALTER TABLE device
	ADD CONSTRAINT fk_dev_os_id
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
-- consider FK between operating_system and operating_system_snapshot
ALTER TABLE operating_system_snapshot
	ADD CONSTRAINT fk_os_snap_osid
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
-- consider FK between operating_system and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_osid
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);

-- FOREIGN KEYS TO
-- consider FK operating_system and company
ALTER TABLE operating_system
	ADD CONSTRAINT fk_os_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK operating_system and val_processor_architecture
ALTER TABLE operating_system
	ADD CONSTRAINT fk_os_fk_val_dev_arch
	FOREIGN KEY (processor_architecture) REFERENCES val_processor_architecture(processor_architecture);
-- consider FK operating_system and val_operating_system_family
ALTER TABLE operating_system
	ADD CONSTRAINT fk_os_os_family
	FOREIGN KEY (operating_system_family) REFERENCES val_operating_system_family(operating_system_family);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'operating_system');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'operating_system');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'operating_system');
ALTER SEQUENCE operating_system_operating_system_id_seq
	 OWNED BY operating_system.operating_system_id;
DROP TABLE IF EXISTS operating_system_v79;
DROP TABLE IF EXISTS audit.operating_system_v79;
-- DONE DEALING WITH TABLE operating_system
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE property
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'property', 'property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_compcoll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_l2_netcollid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_l3_netcoll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_net_range_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_os_snapshot;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_pv_devcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_svc_env_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_x509_crt_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acct_col;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acctid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acctrealmid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_compid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_devcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_dns_dom_collect;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_dnsdomid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_nblk_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_nmtyp;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_osid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_person_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_prop_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pv_nblkcol_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_acct_colid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_compid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_pwdtyp;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_swpkgid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_tokcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_site_code;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_val_prsnid;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS pk_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif30property";
DROP INDEX IF EXISTS "jazzhands"."xif31property";
DROP INDEX IF EXISTS "jazzhands"."xif32property";
DROP INDEX IF EXISTS "jazzhands"."xif33property";
DROP INDEX IF EXISTS "jazzhands"."xif_prop_compcoll_id";
DROP INDEX IF EXISTS "jazzhands"."xif_prop_os_snapshot";
DROP INDEX IF EXISTS "jazzhands"."xif_prop_pv_devcolid";
DROP INDEX IF EXISTS "jazzhands"."xif_prop_svc_env_coll_id";
DROP INDEX IF EXISTS "jazzhands"."xif_property_acctrealmid";
DROP INDEX IF EXISTS "jazzhands"."xif_property_dns_dom_collect";
DROP INDEX IF EXISTS "jazzhands"."xif_property_nblk_coll_id";
DROP INDEX IF EXISTS "jazzhands"."xif_property_person_id";
DROP INDEX IF EXISTS "jazzhands"."xif_property_prop_coll_id";
DROP INDEX IF EXISTS "jazzhands"."xif_property_pv_nblkcol_id";
DROP INDEX IF EXISTS "jazzhands"."xif_property_val_prsnid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_account_id";
DROP INDEX IF EXISTS "jazzhands"."xifprop_acctcol_id";
DROP INDEX IF EXISTS "jazzhands"."xifprop_compid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_devcolid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_dnsdomid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_nmtyp";
DROP INDEX IF EXISTS "jazzhands"."xifprop_osid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_acct_colid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_compid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_pwdtyp";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_swpkgid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_tokcolid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_site_code";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS ckc_prop_isenbld;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_property ON jazzhands.property;
DROP TRIGGER IF EXISTS trigger_audit_property ON jazzhands.property;
DROP TRIGGER IF EXISTS trigger_validate_property ON jazzhands.property;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'property');
---- BEGIN audit.property TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'property', 'property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.property DROP CONSTRAINT IF EXISTS property_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_property_pk_property";
DROP INDEX IF EXISTS "audit"."property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.property TEARDOWN


ALTER TABLE property RENAME TO property_v79;
ALTER TABLE audit.property RENAME TO property_v79;

CREATE TABLE property
(
	property_id	integer NOT NULL,
	account_collection_id	integer  NULL,
	account_id	integer  NULL,
	account_realm_id	integer  NULL,
	company_collection_id	integer  NULL,
	company_id	integer  NULL,
	device_collection_id	integer  NULL,
	dns_domain_collection_id	integer  NULL,
	layer2_network_collection_id	integer  NULL,
	layer3_network_collection_id	integer  NULL,
	netblock_collection_id	integer  NULL,
	network_range_id	integer  NULL,
	operating_system_id	integer  NULL,
	operating_system_snapshot_id	integer  NULL,
	person_id	integer  NULL,
	property_collection_id	integer  NULL,
	service_env_collection_id	integer  NULL,
	site_code	varchar(50)  NULL,
	x509_signed_certificate_id	integer  NULL,
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	property_value	varchar(1024)  NULL,
	property_value_timestamp	timestamp without time zone  NULL,
	property_value_company_id	integer  NULL,
	property_value_account_coll_id	integer  NULL,
	property_value_device_coll_id	integer  NULL,
	property_value_nblk_coll_id	integer  NULL,
	property_value_password_type	varchar(50)  NULL,
	property_value_person_id	integer  NULL,
	property_value_sw_package_id	integer  NULL,
	property_value_token_col_id	integer  NULL,
	property_rank	integer  NULL,
	start_date	timestamp without time zone  NULL,
	finish_date	timestamp without time zone  NULL,
	is_enabled	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'property', false);
ALTER TABLE property
	ALTER property_id
	SET DEFAULT nextval('property_property_id_seq'::regclass);
ALTER TABLE property
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;
INSERT INTO property (
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_collection_id,
	company_id,
	device_collection_id,
	dns_domain_collection_id,
	layer2_network_collection_id,
	layer3_network_collection_id,
	netblock_collection_id,
	network_range_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	x509_signed_certificate_id,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_collection_id,
	company_id,
	device_collection_id,
	dns_domain_collection_id,
	layer2_network_collection_id,
	layer3_network_collection_id,
	netblock_collection_id,
	network_range_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	x509_signed_certificate_id,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM property_v79;

INSERT INTO audit.property (
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_collection_id,
	company_id,
	device_collection_id,
	dns_domain_collection_id,
	layer2_network_collection_id,
	layer3_network_collection_id,
	netblock_collection_id,
	network_range_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	x509_signed_certificate_id,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
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
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_collection_id,
	company_id,
	device_collection_id,
	dns_domain_collection_id,
	layer2_network_collection_id,
	layer3_network_collection_id,
	netblock_collection_id,
	network_range_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	x509_signed_certificate_id,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
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
FROM audit.property_v79;

ALTER TABLE property
	ALTER property_id
	SET DEFAULT nextval('property_property_id_seq'::regclass);
ALTER TABLE property
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE property ADD CONSTRAINT pk_property PRIMARY KEY (property_id);

-- Table/Column Comments
COMMENT ON TABLE property IS 'generic mechanism to create arbitrary associations between lhs database objects and assign them to zero or one other database objects/strings/lists/etc.  They are trigger enforced based on characteristics in val_property and val_property_value where foreign key enforcement does not work.';
COMMENT ON COLUMN property.property_id IS 'primary key for table to uniquely identify rows.';
COMMENT ON COLUMN property.account_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.account_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.account_realm_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.company_id IS 'LHS settable based on val_property.  THIS COLUMN IS DEPRECATED AND WILL BE REMOVED >= 0.66';
COMMENT ON COLUMN property.device_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.dns_domain_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.netblock_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.operating_system_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.operating_system_snapshot_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.person_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.property_collection_id IS 'LHS settable based on val_property.  NOTE, this is actually collections of property_name,property_type';
COMMENT ON COLUMN property.service_env_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.site_code IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.x509_signed_certificate_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN property.property_name IS 'textual name of a property';
COMMENT ON COLUMN property.property_type IS 'textual type of a department';
COMMENT ON COLUMN property.property_value IS 'RHS - general purpose column for value of property not defined by other types.  This may be enforced by fk (trigger) if val_property.property_data_type is list (fk is to val_property_value).   permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_timestamp IS 'RHS - value is a timestamp , permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_company_id IS 'RHS - fk to company_id,  permitted based on val_property.property_data_type.  THIS COLUMN IS DEPRECATED AND WILL BE REMOVED >= 0.66';
COMMENT ON COLUMN property.property_value_account_coll_id IS 'RHS, fk to account_collection,    permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_device_coll_id IS 'RHS - fk to device_collection.    permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_nblk_coll_id IS 'RHS - fk to network_collection.    permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_password_type IS 'RHS - fk to val_password_type.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_person_id IS 'RHS - fk to person.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_sw_package_id IS 'RHS - fk to sw_package.  possibly will be deprecated.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_token_col_id IS 'RHS - fk to token_collection_id.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_rank IS 'for multivalues, specifies the order.  If set, this basically becomes part of the "ak" for the lhs.';
COMMENT ON COLUMN property.start_date IS 'date/time that the assignment takes effect or NULL.  .  The view v_property filters this out.';
COMMENT ON COLUMN property.finish_date IS 'date/time that the assignment ceases taking effect or NULL.  .  The view v_property filters this out.';
COMMENT ON COLUMN property.is_enabled IS 'indiciates if the property is temporarily disabled or not.  The view v_property filters this out.';
-- INDEXES
CREATE INDEX xif30property ON property USING btree (layer2_network_collection_id);
CREATE INDEX xif31property ON property USING btree (layer3_network_collection_id);
CREATE INDEX xif32property ON property USING btree (network_range_id);
CREATE INDEX xif33property ON property USING btree (x509_signed_certificate_id);
CREATE INDEX xif_prop_compcoll_id ON property USING btree (company_collection_id);
CREATE INDEX xif_prop_os_snapshot ON property USING btree (operating_system_snapshot_id);
CREATE INDEX xif_prop_pv_devcolid ON property USING btree (property_value_device_coll_id);
CREATE INDEX xif_prop_svc_env_coll_id ON property USING btree (service_env_collection_id);
CREATE INDEX xif_property_acctrealmid ON property USING btree (account_realm_id);
CREATE INDEX xif_property_dns_dom_collect ON property USING btree (dns_domain_collection_id);
CREATE INDEX xif_property_nblk_coll_id ON property USING btree (netblock_collection_id);
CREATE INDEX xif_property_person_id ON property USING btree (person_id);
CREATE INDEX xif_property_prop_coll_id ON property USING btree (property_collection_id);
CREATE INDEX xif_property_pv_nblkcol_id ON property USING btree (property_value_nblk_coll_id);
CREATE INDEX xif_property_val_prsnid ON property USING btree (property_value_person_id);
CREATE INDEX xifprop_account_id ON property USING btree (account_id);
CREATE INDEX xifprop_acctcol_id ON property USING btree (account_collection_id);
CREATE INDEX xifprop_compid ON property USING btree (company_id);
CREATE INDEX xifprop_devcolid ON property USING btree (device_collection_id);
CREATE INDEX xifprop_nmtyp ON property USING btree (property_name, property_type);
CREATE INDEX xifprop_osid ON property USING btree (operating_system_id);
CREATE INDEX xifprop_pval_acct_colid ON property USING btree (property_value_account_coll_id);
CREATE INDEX xifprop_pval_compid ON property USING btree (property_value_company_id);
CREATE INDEX xifprop_pval_pwdtyp ON property USING btree (property_value_password_type);
CREATE INDEX xifprop_pval_swpkgid ON property USING btree (property_value_sw_package_id);
CREATE INDEX xifprop_pval_tokcolid ON property USING btree (property_value_token_col_id);
CREATE INDEX xifprop_site_code ON property USING btree (site_code);

-- CHECK CONSTRAINTS
ALTER TABLE property ADD CONSTRAINT ckc_prop_isenbld
	CHECK (is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK property and company_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_compcoll_id
	FOREIGN KEY (company_collection_id) REFERENCES company_collection(company_collection_id);
-- consider FK property and layer2_network_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l2_netcollid
	FOREIGN KEY (layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id);
-- consider FK property and layer3_network_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l3_netcoll_id
	FOREIGN KEY (layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id);
-- consider FK property and network_range
ALTER TABLE property
	ADD CONSTRAINT fk_prop_net_range_id
	FOREIGN KEY (network_range_id) REFERENCES network_range(network_range_id);
-- consider FK property and operating_system_snapshot
ALTER TABLE property
	ADD CONSTRAINT fk_prop_os_snapshot
	FOREIGN KEY (operating_system_snapshot_id) REFERENCES operating_system_snapshot(operating_system_snapshot_id);
-- consider FK property and device_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_pv_devcolid
	FOREIGN KEY (property_value_device_coll_id) REFERENCES device_collection(device_collection_id);
-- consider FK property and service_environment_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_svc_env_coll_id
	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);
-- consider FK property and x509_signed_certificate
ALTER TABLE property
	ADD CONSTRAINT fk_prop_x509_crt_id
	FOREIGN KEY (x509_signed_certificate_id) REFERENCES x509_signed_certificate(x509_signed_certificate_id);
-- consider FK property and account_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_acct_col
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK property and account
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctid
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK property and account_realm
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctrealmid
	FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id);
-- consider FK property and company
ALTER TABLE property
	ADD CONSTRAINT fk_property_compid
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK property and device_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_devcolid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
-- consider FK property and dns_domain_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_dns_dom_collect
	FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);
-- consider FK property and netblock_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_nblk_coll_id
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK property and val_property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK property and operating_system
ALTER TABLE property
	ADD CONSTRAINT fk_property_osid
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
-- consider FK property and person
ALTER TABLE property
	ADD CONSTRAINT fk_property_person_id
	FOREIGN KEY (person_id) REFERENCES person(person_id);
-- consider FK property and property_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_prop_coll_id
	FOREIGN KEY (property_collection_id) REFERENCES property_collection(property_collection_id);
-- consider FK property and netblock_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pv_nblkcol_id
	FOREIGN KEY (property_value_nblk_coll_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK property and account_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_acct_colid
	FOREIGN KEY (property_value_account_coll_id) REFERENCES account_collection(account_collection_id);
-- consider FK property and company
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_compid
	FOREIGN KEY (property_value_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK property and val_password_type
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_pwdtyp
	FOREIGN KEY (property_value_password_type) REFERENCES val_password_type(password_type);
-- consider FK property and sw_package
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_swpkgid
	FOREIGN KEY (property_value_sw_package_id) REFERENCES sw_package(sw_package_id);
-- consider FK property and token_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_tokcolid
	FOREIGN KEY (property_value_token_col_id) REFERENCES token_collection(token_collection_id);
-- consider FK property and site
ALTER TABLE property
	ADD CONSTRAINT fk_property_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);
-- consider FK property and person
ALTER TABLE property
	ADD CONSTRAINT fk_property_val_prsnid
	FOREIGN KEY (property_value_person_id) REFERENCES person(person_id);

-- TRIGGERS
-- consider NEW jazzhands.validate_property
CREATE OR REPLACE FUNCTION jazzhands.validate_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
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
	v_property_collection		property_collection%ROWTYPE;
	v_service_env_collection	service_environment_collection%ROWTYPE;
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
				'Property name or type does not exist'
				USING ERRCODE = 'foreign_key_violation';
			RETURN NULL;
	END;

	-- Check to see if the property itself is multivalue.  That is, if only
	-- one value can be set for this property for a specific property LHS
	IF (v_prop.is_multivalue = 'N') THEN
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
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code
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
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code AND
			property_value IS NOT DISTINCT FROM NEW.property_value AND
			property_value_timestamp IS NOT DISTINCT FROM
				NEW.property_value_timestamp AND
			property_value_company_id IS NOT DISTINCT FROM
				NEW.property_value_company_id AND
			property_value_account_coll_id IS NOT DISTINCT FROM
				NEW.property_value_account_coll_id AND
			property_value_device_coll_id IS NOT DISTINCT FROM
				NEW.property_value_device_coll_id AND
			property_value_nblk_coll_id IS NOT DISTINCT FROM
				NEW.property_value_nblk_coll_id AND
			property_value_password_type IS NOT DISTINCT FROM
				NEW.property_value_password_type AND
			property_value_person_id IS NOT DISTINCT FROM
				NEW.property_value_person_id AND
			property_value_sw_package_id IS NOT DISTINCT FROM
				NEW.property_value_sw_package_id AND
			property_value_token_col_id IS NOT DISTINCT FROM
				NEW.property_value_token_col_id AND
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

	-- Check to see if the property type is multivalue.  That is, if only
	-- one property and value can be set for any properties with this type
	-- for a specific property LHS

	IF (v_proptype.is_multivalue = 'N') THEN
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
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code
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
	IF NEW.Property_Value_Company_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'company_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Company_Id' USING
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
	IF NEW.Property_Value_Token_Col_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'token_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Token_Collection_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_SW_Package_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'sw_package_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be SW_Package_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Account_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'account_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be account_collection_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_nblk_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'netblock_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be nblk_collection_id' USING
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
	IF NEW.Property_Value_Person_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'person_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Person_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Device_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'device_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Device_Collection_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	-- at this point, tally will be set to 1 if one of the other property
	-- values is set to something valid.  Now, check the various options for
	-- PROPERTY_VALUE itself.  If a new type is added to the val table, this
	-- trigger needs to be updated or it will be considered invalid.  If a
	-- new PROPERTY_VALUE_* column is added, then it will pass through without
	-- trigger modification.  This should be considered bad.

	IF NEW.Property_Value IS NOT NULL THEN
		tally := tally + 1;
		IF v_prop.Property_Data_Type = 'boolean' THEN
			IF NEW.Property_Value != 'Y' AND NEW.Property_Value != 'N' THEN
				RAISE 'Boolean Property_Value must be Y or N' USING
					ERRCODE = 'invalid_parameter_value';
			END IF;
		ELSIF v_prop.Property_Data_Type = 'number' THEN
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
		ELSIF v_prop.Property_Data_Type != 'string' THEN
			RAISE 'Property_Data_Type is not a known type' USING
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

	-- If the LHS contains a property_collection_ID, check to see if it must be a
	-- specific type (e.g. per-property), and verify that if so
	IF NEW.property_collection_id IS NOT NULL THEN
		IF v_prop.property_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_property_collection
					FROM property_collection WHERE
					property_collection_Id = NEW.property_collection_id;
				IF v_property_collection.property_collection_Type != v_prop.property_collection_type
				THEN
					RAISE 'property_collection_id must be of type %',
					v_prop.property_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a service_env_collection_ID, check to see if it must be a
	-- specific type (e.g. per-service_env), and verify that if so
	IF NEW.service_env_collection_id IS NOT NULL THEN
		IF v_prop.service_env_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_service_env_collection
					FROM service_env_collection WHERE
					service_env_collection_Id = NEW.service_env_collection_id;
				IF v_service_env_collection.service_env_collection_Type != v_prop.service_env_collection_type
				THEN
					RAISE 'service_env_collection_id must be of type %',
					v_prop.service_env_collection_type
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
	IF NEW.Property_Value_Account_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection
					FROM account_collection WHERE
					account_collection_Id = NEW.Property_Value_Account_Coll_Id;
				IF v_account_collection.account_collection_Type != v_prop.prop_val_acct_coll_type_rstrct
				THEN
					RAISE 'Property_Value_Account_Coll_Id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
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
	IF NEW.Property_Value_nblk_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_netblock_collection
					FROM netblock_collection WHERE
					netblock_collection_Id = NEW.Property_Value_nblk_Coll_Id;
				IF v_netblock_collection.netblock_collection_Type != v_prop.prop_val_acct_coll_type_rstrct
				THEN
					RAISE 'Property_Value_nblk_Coll_Id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
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
	IF NEW.Property_Value_Device_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_dev_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_device_collection
					FROM device_collection WHERE
					device_collection_id = NEW.Property_Value_Device_Coll_Id;
				IF v_device_collection.device_collection_type !=
					v_prop.prop_val_dev_coll_type_rstrct
				THEN
					RAISE 'Property_Value_Device_Coll_Id must be of type %',
					v_prop.prop_val_dev_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- At this point, the RHS has been checked, so now we verify data
	-- set on the LHS

	-- There needs to be a stanza here for every "lhs".  If a new column is
	-- added to the property table, a new stanza needs to be added here,
	-- otherwise it will not be validated.  This should be considered bad.

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

	IF v_prop.permit_service_env_collection = 'REQUIRED' THEN
			IF NEW.service_env_collection_id IS NULL THEN
				RAISE 'service_env_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_service_env_collection = 'PROHIBITED' THEN
			IF NEW.service_env_collection_id IS NOT NULL THEN
				RAISE 'service_environment is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
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

	IF v_prop.permit_os_snapshot_id = 'REQUIRED' THEN
			IF NEW.operating_system_snapshot_id IS NULL THEN
				RAISE 'operating_system_snapshot_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_os_snapshot_id = 'PROHIBITED' THEN
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

	IF v_prop.permit_layer2_network_coll_id = 'REQUIRED' THEN
			IF NEW.layer2_network_collection_id IS NULL THEN
				RAISE 'layer2_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer2_network_coll_id = 'PROHIBITED' THEN
			IF NEW.layer2_network_collection_id IS NOT NULL THEN
				RAISE 'layer2_network_collection_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_layer3_network_coll_id = 'REQUIRED' THEN
			IF NEW.layer3_network_collection_id IS NULL THEN
				RAISE 'layer3_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer3_network_coll_id = 'PROHIBITED' THEN
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

	IF v_prop.Permit_property_collection_Id = 'REQUIRED' THEN
			IF NEW.property_collection_Id IS NULL THEN
				RAISE 'property_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_property_collection_Id = 'PROHIBITED' THEN
			IF NEW.property_collection_Id IS NOT NULL THEN
				RAISE 'property_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Person_Id = 'REQUIRED' THEN
			IF NEW.Person_Id IS NULL THEN
				RAISE 'Person_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Person_Id = 'PROHIBITED' THEN
			IF NEW.Person_Id IS NOT NULL THEN
				RAISE 'Person_Id is prohibited.'
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
CREATE TRIGGER trigger_validate_property BEFORE INSERT OR UPDATE ON property FOR EACH ROW EXECUTE PROCEDURE validate_property();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'property');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'property');
ALTER SEQUENCE property_property_id_seq
	 OWNED BY property.property_id;
DROP TABLE IF EXISTS property_v79;
DROP TABLE IF EXISTS audit.property_v79;
-- DONE DEALING WITH TABLE property
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE service_environment
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment', 'service_environment');

-- FOREIGN KEYS FROM
ALTER TABLE appaal_instance DROP CONSTRAINT IF EXISTS fk_appaal_i_fk_applic_svcenv;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_dev_v_svcenv;
ALTER TABLE network_service DROP CONSTRAINT IF EXISTS fk_netsvc_csvcenv;
ALTER TABLE svc_environment_coll_svc_env DROP CONSTRAINT IF EXISTS fk_svc_env_col_svc_env;
ALTER TABLE sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_vsvcenv;
ALTER TABLE voe DROP CONSTRAINT IF EXISTS fk_voe_ref_v_svcenv;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.service_environment DROP CONSTRAINT IF EXISTS fk_val_svcenv_prodstate;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'service_environment');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.service_environment DROP CONSTRAINT IF EXISTS pk_service_environment;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1service_environment";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_service_environment ON jazzhands.service_environment;
DROP TRIGGER IF EXISTS trigger_audit_service_environment ON jazzhands.service_environment;
DROP TRIGGER IF EXISTS trigger_delete_per_svc_env_svc_env_collection ON jazzhands.service_environment;
DROP TRIGGER IF EXISTS trigger_update_per_svc_env_svc_env_collection ON jazzhands.service_environment;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'service_environment');
---- BEGIN audit.service_environment TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'service_environment', 'service_environment');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'service_environment');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.service_environment DROP CONSTRAINT IF EXISTS service_environment_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_service_environment_pk_service_environment";
DROP INDEX IF EXISTS "audit"."service_environment_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.service_environment TEARDOWN


ALTER TABLE service_environment RENAME TO service_environment_v79;
ALTER TABLE audit.service_environment RENAME TO service_environment_v79;

CREATE TABLE service_environment
(
	service_environment_id	integer NOT NULL,
	service_environment_name	varchar(50) NOT NULL,
	production_state	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	external_id	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'service_environment', false);
ALTER TABLE service_environment
	ALTER service_environment_id
	SET DEFAULT nextval('service_environment_service_environment_id_seq'::regclass);
INSERT INTO service_environment (
	service_environment_id,
	service_environment_name,
	production_state,
	description,
	external_id,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	service_environment_id,
	service_environment_name,
	production_state,
	description,
	NULL,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM service_environment_v79;

INSERT INTO audit.service_environment (
	service_environment_id,
	service_environment_name,
	production_state,
	description,
	external_id,		-- new column (external_id)
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
	service_environment_id,
	service_environment_name,
	production_state,
	description,
	NULL,		-- new column (external_id)
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
FROM audit.service_environment_v79;

ALTER TABLE service_environment
	ALTER service_environment_id
	SET DEFAULT nextval('service_environment_service_environment_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE service_environment ADD CONSTRAINT pk_service_environment PRIMARY KEY (service_environment_id);

-- Table/Column Comments
COMMENT ON COLUMN service_environment.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX xif1service_environment ON service_environment USING btree (production_state);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between service_environment and appaal_instance
ALTER TABLE appaal_instance
	ADD CONSTRAINT fk_appaal_i_fk_applic_svcenv
	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);
-- consider FK between service_environment and device
ALTER TABLE device
	ADD CONSTRAINT fk_device_dev_v_svcenv
	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);
-- consider FK between service_environment and network_service
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_csvcenv
	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);
-- consider FK between service_environment and svc_environment_coll_svc_env
ALTER TABLE svc_environment_coll_svc_env
	ADD CONSTRAINT fk_svc_env_col_svc_env
	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);

-- FOREIGN KEYS TO
-- consider FK service_environment and val_production_state
ALTER TABLE service_environment
	ADD CONSTRAINT fk_val_svcenv_prodstate
	FOREIGN KEY (production_state) REFERENCES val_production_state(production_state);

-- TRIGGERS
-- consider NEW jazzhands.delete_per_svc_env_svc_env_collection
CREATE OR REPLACE FUNCTION jazzhands.delete_per_svc_env_svc_env_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	secid	service_environment_collection.service_env_collection_id%TYPE;
BEGIN
	SELECT	service_env_collection_id
	  FROM  service_environment_collection
	  INTO	secid
	 WHERE	service_env_collection_type = 'per-environment'
	   AND	service_env_collection_id in
		(select service_env_collection_id
		 from svc_environment_coll_svc_env
		where service_environment_id = OLD.service_environment_id
		)
	ORDER BY service_env_collection_id
	LIMIT 1;

	IF secid IS NOT NULL THEN
		DELETE FROM svc_environment_coll_svc_env
		WHERE service_env_collection_id = secid;

		DELETE from service_environment_collection
		WHERE service_env_collection_id = secid;
	END IF;

	RETURN OLD;
END;
$function$
;
CREATE TRIGGER trigger_delete_per_svc_env_svc_env_collection BEFORE DELETE ON service_environment FOR EACH ROW EXECUTE PROCEDURE delete_per_svc_env_svc_env_collection();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.update_per_svc_env_svc_env_collection
CREATE OR REPLACE FUNCTION jazzhands.update_per_svc_env_svc_env_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	secid		service_environment_collection.service_env_collection_id%TYPE;
BEGIN
	IF TG_OP = 'INSERT' THEN
		insert into service_environment_collection
			(service_env_collection_name, service_env_collection_type)
		values
			(NEW.service_environment_name, 'per-environment')
		RETURNING service_env_collection_id INTO secid;
		insert into svc_environment_coll_svc_env
			(service_env_collection_id, service_environment_id)
		VALUES
			(secid, NEW.service_environment_id);
	ELSIF TG_OP = 'UPDATE'  AND OLD.service_environment_id != NEW.service_environment_id THEN
		UPDATE	service_environment_collection
		   SET	service_env_collection_name = NEW.service_environment_name
		 WHERE	service_env_collection_name != NEW.service_environment_name
		   AND	service_env_collection_type = 'per-environment'
		   AND	service_environment_id in (
			SELECT	service_environment_id
			  FROM	svc_environment_coll_svc_env
			 WHERE	service_environment_id =
				NEW.service_environment_id
			);
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_update_per_svc_env_svc_env_collection AFTER INSERT OR UPDATE ON service_environment FOR EACH ROW EXECUTE PROCEDURE update_per_svc_env_svc_env_collection();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'service_environment');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'service_environment');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'service_environment');
ALTER SEQUENCE service_environment_service_environment_id_seq
	 OWNED BY service_environment.service_environment_id;
DROP TABLE IF EXISTS service_environment_v79;
DROP TABLE IF EXISTS audit.service_environment_v79;
-- DONE DEALING WITH TABLE service_environment
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE service_environment_collection
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_collection', 'service_environment_collection');

-- FOREIGN KEYS FROM
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_prop_svc_env_coll_id;
ALTER TABLE svc_environment_coll_svc_env DROP CONSTRAINT IF EXISTS fk_svc_env_coll_svc_coll_id;
ALTER TABLE service_environment_coll_hier DROP CONSTRAINT IF EXISTS fk_svc_env_hier_svc_env_coll_i;
ALTER TABLE service_environment_coll_hier DROP CONSTRAINT IF EXISTS fk_svcenv_coll_child_svccollid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.service_environment_collection DROP CONSTRAINT IF EXISTS fk_svc_env_col_v_svc_env_type;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'service_environment_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.service_environment_collection DROP CONSTRAINT IF EXISTS ak_val_svc_env_name_type;
ALTER TABLE jazzhands.service_environment_collection DROP CONSTRAINT IF EXISTS pk_service_environment_collect;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1service_environment_collec";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_service_environment_collection ON jazzhands.service_environment_collection;
DROP TRIGGER IF EXISTS trigger_audit_service_environment_collection ON jazzhands.service_environment_collection;
DROP TRIGGER IF EXISTS trigger_validate_service_env_collection_type_change ON jazzhands.service_environment_collection;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'service_environment_collection');
---- BEGIN audit.service_environment_collection TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'service_environment_collection', 'service_environment_collection');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'service_environment_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.service_environment_collection DROP CONSTRAINT IF EXISTS service_environment_collection_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_0service_environment_collection_pk_service_environment_coll";
DROP INDEX IF EXISTS "audit"."aud_service_environment_collection_ak_val_svc_env_name_type";
DROP INDEX IF EXISTS "audit"."service_environment_collection_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.service_environment_collection TEARDOWN


ALTER TABLE service_environment_collection RENAME TO service_environment_collection_v79;
ALTER TABLE audit.service_environment_collection RENAME TO service_environment_collection_v79;

CREATE TABLE service_environment_collection
(
	service_env_collection_id	integer NOT NULL,
	service_env_collection_name	varchar(50) NOT NULL,
	service_env_collection_type	varchar(50)  NULL,
	description	varchar(4000)  NULL,
	external_id	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'service_environment_collection', false);
ALTER TABLE service_environment_collection
	ALTER service_env_collection_id
	SET DEFAULT nextval('service_environment_collection_service_env_collection_id_seq'::regclass);
INSERT INTO service_environment_collection (
	service_env_collection_id,
	service_env_collection_name,
	service_env_collection_type,
	description,
	external_id,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	service_env_collection_id,
	service_env_collection_name,
	service_env_collection_type,
	description,
	NULL,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM service_environment_collection_v79;

INSERT INTO audit.service_environment_collection (
	service_env_collection_id,
	service_env_collection_name,
	service_env_collection_type,
	description,
	external_id,		-- new column (external_id)
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
	service_env_collection_id,
	service_env_collection_name,
	service_env_collection_type,
	description,
	NULL,		-- new column (external_id)
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
FROM audit.service_environment_collection_v79;

ALTER TABLE service_environment_collection
	ALTER service_env_collection_id
	SET DEFAULT nextval('service_environment_collection_service_env_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE service_environment_collection ADD CONSTRAINT ak_val_svc_env_name_type UNIQUE (service_env_collection_name, service_env_collection_type);
ALTER TABLE service_environment_collection ADD CONSTRAINT pk_service_environment_collect PRIMARY KEY (service_env_collection_id);

-- Table/Column Comments
COMMENT ON COLUMN service_environment_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES
CREATE INDEX xif1service_environment_collec ON service_environment_collection USING btree (service_env_collection_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between service_environment_collection and property
ALTER TABLE property
	ADD CONSTRAINT fk_prop_svc_env_coll_id
	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);
-- consider FK between service_environment_collection and svc_environment_coll_svc_env
ALTER TABLE svc_environment_coll_svc_env
	ADD CONSTRAINT fk_svc_env_coll_svc_coll_id
	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);
-- consider FK between service_environment_collection and service_environment_coll_hier
ALTER TABLE service_environment_coll_hier
	ADD CONSTRAINT fk_svc_env_hier_svc_env_coll_i
	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);
-- consider FK between service_environment_collection and service_environment_coll_hier
ALTER TABLE service_environment_coll_hier
	ADD CONSTRAINT fk_svcenv_coll_child_svccollid
	FOREIGN KEY (child_service_env_coll_id) REFERENCES service_environment_collection(service_env_collection_id);

-- FOREIGN KEYS TO
-- consider FK service_environment_collection and val_service_env_coll_type
ALTER TABLE service_environment_collection
	ADD CONSTRAINT fk_svc_env_col_v_svc_env_type
	FOREIGN KEY (service_env_collection_type) REFERENCES val_service_env_coll_type(service_env_collection_type);

-- TRIGGERS
-- consider NEW jazzhands.validate_service_env_collection_type_change
CREATE OR REPLACE FUNCTION jazzhands.validate_service_env_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.service_env_collection_type != NEW.service_env_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.service_env_collection_type = OLD.service_env_collection_type
		AND	p.service_env_collection_id = NEW.service_env_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'service_env_collection % of type % is used by % restricted properties.',
				NEW.service_env_collection_id, NEW.service_env_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_validate_service_env_collection_type_change BEFORE UPDATE OF service_env_collection_type ON service_environment_collection FOR EACH ROW EXECUTE PROCEDURE validate_service_env_collection_type_change();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'service_environment_collection');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'service_environment_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'service_environment_collection');
ALTER SEQUENCE service_environment_collection_service_env_collection_id_seq
	 OWNED BY service_environment_collection.service_env_collection_id;
DROP TABLE IF EXISTS service_environment_collection_v79;
DROP TABLE IF EXISTS audit.service_environment_collection_v79;
-- DONE DEALING WITH TABLE service_environment_collection
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE sw_package_relation

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.sw_package_relation DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_vpkgreltype;
ALTER TABLE jazzhands.sw_package_relation DROP CONSTRAINT IF EXISTS fk_sw_pkgrel_ref_sw_pkg;
ALTER TABLE jazzhands.sw_package_relation DROP CONSTRAINT IF EXISTS fk_swpkgrltn_ref_swpkgrel;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'sw_package_relation');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.sw_package_relation DROP CONSTRAINT IF EXISTS pk_sw_package_relation;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_sw_pkg_rltn_rel_sw_pkg_id";
DROP INDEX IF EXISTS "jazzhands"."idx_sw_pkg_rltn_sw_pkg_rel_id";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.sw_package_relation DROP CONSTRAINT IF EXISTS ckc_relation_restrict_sw_packa;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_sw_package_relation ON jazzhands.sw_package_relation;
DROP TRIGGER IF EXISTS trigger_audit_sw_package_relation ON jazzhands.sw_package_relation;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'sw_package_relation');
---- BEGIN audit.sw_package_relation TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'sw_package_relation');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.sw_package_relation DROP CONSTRAINT IF EXISTS sw_package_relation_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_sw_package_relation_pk_sw_package_relation";
DROP INDEX IF EXISTS "audit"."sw_package_relation_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.sw_package_relation TEARDOWN


ALTER TABLE sw_package_relation RENAME TO sw_package_relation_v79;
ALTER TABLE audit.sw_package_relation RENAME TO sw_package_relation_v79;

DROP TABLE IF EXISTS sw_package_relation_v79;
DROP TABLE IF EXISTS audit.sw_package_relation_v79;
-- DONE DEALING WITH OLD TABLE sw_package_relation
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE sw_package_release

-- FOREIGN KEYS FROM
-- Skipping this FK since table been dropped
--ALTER TABLE sw_package_relation DROP CONSTRAINT IF EXISTS fk_swpkgrltn_ref_swpkgrel;

ALTER TABLE voe_sw_package DROP CONSTRAINT IF EXISTS fk_voe_swpkg_ref_swpkg_rel;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_package_type;
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_ref_sw_pkg_rel;
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_sw_pkg_rep;
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_sys_user;
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_vdevarch;
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_vsvcenv;
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_vswpkgfmt;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'sw_package_release');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS ak_uq_sw_pkg_rel_comb_sw_packa;
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS pk_sw_package_release;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_sw_pkg_rel_sw_pkg_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_sw_package_release ON jazzhands.sw_package_release;
DROP TRIGGER IF EXISTS trigger_audit_sw_package_release ON jazzhands.sw_package_release;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'sw_package_release');
---- BEGIN audit.sw_package_release TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'sw_package_release');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.sw_package_release DROP CONSTRAINT IF EXISTS sw_package_release_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_sw_package_release_ak_uq_sw_pkg_rel_comb_sw_packa";
DROP INDEX IF EXISTS "audit"."aud_sw_package_release_pk_sw_package_release";
DROP INDEX IF EXISTS "audit"."sw_package_release_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.sw_package_release TEARDOWN


ALTER TABLE sw_package_release RENAME TO sw_package_release_v79;
ALTER TABLE audit.sw_package_release RENAME TO sw_package_release_v79;

DROP TABLE IF EXISTS sw_package_release_v79;
DROP TABLE IF EXISTS audit.sw_package_release_v79;
-- DONE DEALING WITH OLD TABLE sw_package_release
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE sw_package_repository

-- FOREIGN KEYS FROM
ALTER TABLE operating_system DROP CONSTRAINT IF EXISTS fk_os_ref_swpkgrepos;
-- Skipping this FK since table been dropped
--ALTER TABLE sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_sw_pkg_rep;

ALTER TABLE voe_symbolic_track DROP CONSTRAINT IF EXISTS fk_voesymbtrk_ref_swpkgrpos;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'sw_package_repository');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.sw_package_repository DROP CONSTRAINT IF EXISTS ak_uq_sw_pkg_rep_apt_sw_packa;
ALTER TABLE jazzhands.sw_package_repository DROP CONSTRAINT IF EXISTS ak_uq_sw_pkg_rep_sw_r_sw_packa;
ALTER TABLE jazzhands.sw_package_repository DROP CONSTRAINT IF EXISTS pk_sw_package_repository;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_sw_package_repository ON jazzhands.sw_package_repository;
DROP TRIGGER IF EXISTS trigger_audit_sw_package_repository ON jazzhands.sw_package_repository;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'sw_package_repository');
---- BEGIN audit.sw_package_repository TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'sw_package_repository');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.sw_package_repository DROP CONSTRAINT IF EXISTS sw_package_repository_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_sw_package_repository_ak_uq_sw_pkg_rep_apt_sw_packa";
DROP INDEX IF EXISTS "audit"."aud_sw_package_repository_ak_uq_sw_pkg_rep_sw_r_sw_packa";
DROP INDEX IF EXISTS "audit"."aud_sw_package_repository_pk_sw_package_repository";
DROP INDEX IF EXISTS "audit"."sw_package_repository_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.sw_package_repository TEARDOWN


ALTER TABLE sw_package_repository RENAME TO sw_package_repository_v79;
ALTER TABLE audit.sw_package_repository RENAME TO sw_package_repository_v79;

DROP TABLE IF EXISTS sw_package_repository_v79;
DROP TABLE IF EXISTS audit.sw_package_repository_v79;
-- DONE DEALING WITH OLD TABLE sw_package_repository
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE token
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'token', 'token');

-- FOREIGN KEYS FROM
ALTER TABLE account_token DROP CONSTRAINT IF EXISTS fk_acct_token_ref_token;
ALTER TABLE token_collection_token DROP CONSTRAINT IF EXISTS fk_tok_col_tok_token_id;
ALTER TABLE token_sequence DROP CONSTRAINT IF EXISTS fk_token_seq_ref_token;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS fk_token_enc_id_id;
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS fk_token_ref_v_token_status;
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS fk_token_ref_v_token_type;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'token');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS ak_token_token_key;
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS pk_token;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_token_tokenstatus";
DROP INDEX IF EXISTS "jazzhands"."idx_token_tokentype";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS check_yes_no_tkn_islckd;
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS sys_c0020104;
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS sys_c0020105;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_token ON jazzhands.token;
DROP TRIGGER IF EXISTS trigger_audit_token ON jazzhands.token;
DROP TRIGGER IF EXISTS trigger_pgnotify_token_change ON jazzhands.token;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'token');
---- BEGIN audit.token TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'token', 'token');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'token');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.token DROP CONSTRAINT IF EXISTS token_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_token_ak_token_token_key";
DROP INDEX IF EXISTS "audit"."aud_token_pk_token";
DROP INDEX IF EXISTS "audit"."token_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.token TEARDOWN


ALTER TABLE token RENAME TO token_v79;
ALTER TABLE audit.token RENAME TO token_v79;

CREATE TABLE token
(
	token_id	integer NOT NULL,
	token_type	varchar(50) NOT NULL,
	token_status	varchar(50)  NULL,
	description	varchar(255)  NULL,
	external_id	varchar(255)  NULL,
	token_serial	varchar(20)  NULL,
	zero_time	timestamp with time zone  NULL,
	time_modulo	integer  NULL,
	time_skew	integer  NULL,
	token_key	varchar(512)  NULL,
	encryption_key_id	integer  NULL,
	token_password	varchar(128)  NULL,
	expire_time	timestamp with time zone  NULL,
	is_token_locked	character(1) NOT NULL,
	token_unlock_time	timestamp with time zone  NULL,
	bad_logins	integer  NULL,
	last_updated	timestamp with time zone NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'token', false);
ALTER TABLE token
	ALTER token_id
	SET DEFAULT nextval('token_token_id_seq'::regclass);
ALTER TABLE token
	ALTER is_token_locked
	SET DEFAULT 'N'::bpchar;
INSERT INTO token (
	token_id,
	token_type,
	token_status,
	description,
	external_id,		-- new column (external_id)
	token_serial,
	zero_time,
	time_modulo,
	time_skew,
	token_key,
	encryption_key_id,
	token_password,
	expire_time,
	is_token_locked,
	token_unlock_time,
	bad_logins,
	last_updated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	token_id,
	token_type,
	token_status,
	description,
	NULL,		-- new column (external_id)
	token_serial,
	zero_time,
	time_modulo,
	time_skew,
	token_key,
	encryption_key_id,
	token_password,
	expire_time,
	is_token_locked,
	token_unlock_time,
	bad_logins,
	last_updated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM token_v79;

INSERT INTO audit.token (
	token_id,
	token_type,
	token_status,
	description,
	external_id,		-- new column (external_id)
	token_serial,
	zero_time,
	time_modulo,
	time_skew,
	token_key,
	encryption_key_id,
	token_password,
	expire_time,
	is_token_locked,
	token_unlock_time,
	bad_logins,
	last_updated,
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
	token_id,
	token_type,
	token_status,
	description,
	NULL,		-- new column (external_id)
	token_serial,
	zero_time,
	time_modulo,
	time_skew,
	token_key,
	encryption_key_id,
	token_password,
	expire_time,
	is_token_locked,
	token_unlock_time,
	bad_logins,
	last_updated,
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
FROM audit.token_v79;

ALTER TABLE token
	ALTER token_id
	SET DEFAULT nextval('token_token_id_seq'::regclass);
ALTER TABLE token
	ALTER is_token_locked
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE token ADD CONSTRAINT ak_token_token_key UNIQUE (token_key);
ALTER TABLE token ADD CONSTRAINT pk_token PRIMARY KEY (token_id);

-- Table/Column Comments
COMMENT ON COLUMN token.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
COMMENT ON COLUMN token.encryption_key_id IS 'encryption information for token_key, if used';
-- INDEXES
CREATE INDEX idx_token_tokenstatus ON token USING btree (token_status);
CREATE INDEX idx_token_tokentype ON token USING btree (token_type);

-- CHECK CONSTRAINTS
ALTER TABLE token ADD CONSTRAINT check_yes_no_tkn_islckd
	CHECK (is_token_locked = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE token ADD CONSTRAINT sys_c0020104
	CHECK (token_type IS NOT NULL);
ALTER TABLE token ADD CONSTRAINT sys_c0020105
	CHECK (last_updated IS NOT NULL);

-- FOREIGN KEYS FROM
-- consider FK between token and account_token
ALTER TABLE account_token
	ADD CONSTRAINT fk_acct_token_ref_token
	FOREIGN KEY (token_id) REFERENCES token(token_id);
-- consider FK between token and token_collection_token
ALTER TABLE token_collection_token
	ADD CONSTRAINT fk_tok_col_tok_token_id
	FOREIGN KEY (token_id) REFERENCES token(token_id);
-- consider FK between token and token_sequence
ALTER TABLE token_sequence
	ADD CONSTRAINT fk_token_seq_ref_token
	FOREIGN KEY (token_id) REFERENCES token(token_id);

-- FOREIGN KEYS TO
-- consider FK token and encryption_key
ALTER TABLE token
	ADD CONSTRAINT fk_token_enc_id_id
	FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id);
-- consider FK token and val_token_status
ALTER TABLE token
	ADD CONSTRAINT fk_token_ref_v_token_status
	FOREIGN KEY (token_status) REFERENCES val_token_status(token_status);
-- consider FK token and val_token_type
ALTER TABLE token
	ADD CONSTRAINT fk_token_ref_v_token_type
	FOREIGN KEY (token_type) REFERENCES val_token_type(token_type);

-- TRIGGERS
-- consider NEW jazzhands.pgnotify_token_change
CREATE OR REPLACE FUNCTION jazzhands.pgnotify_token_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM pg_notify ('token_change', 'token_id=' || NEW.token_id);
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_pgnotify_token_change AFTER INSERT OR UPDATE ON token FOR EACH ROW EXECUTE PROCEDURE pgnotify_token_change();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'token');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'token');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'token');
ALTER SEQUENCE token_token_id_seq
	 OWNED BY token.token_id;
DROP TABLE IF EXISTS token_v79;
DROP TABLE IF EXISTS audit.token_v79;
-- DONE DEALING WITH TABLE token
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE token_collection
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'token_collection', 'token_collection');

-- FOREIGN KEYS FROM
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_pval_tokcolid;
ALTER TABLE token_collection_hier DROP CONSTRAINT IF EXISTS fk_tok_col_hier_ch_tok_colid;
ALTER TABLE token_collection_hier DROP CONSTRAINT IF EXISTS fk_tok_col_hier_tok_colid;
ALTER TABLE token_collection_token DROP CONSTRAINT IF EXISTS fk_tok_col_tok_token_col_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.token_collection DROP CONSTRAINT IF EXISTS fk_tok_col_mem_token_col_type;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'token_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.token_collection DROP CONSTRAINT IF EXISTS pk_token_collection;
ALTER TABLE jazzhands.token_collection DROP CONSTRAINT IF EXISTS uq_token_coll_name_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_token_collection ON jazzhands.token_collection;
DROP TRIGGER IF EXISTS trigger_audit_token_collection ON jazzhands.token_collection;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'token_collection');
---- BEGIN audit.token_collection TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'token_collection', 'token_collection');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'token_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.token_collection DROP CONSTRAINT IF EXISTS token_collection_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_token_collection_pk_token_collection";
DROP INDEX IF EXISTS "audit"."aud_token_collection_uq_token_coll_name_type";
DROP INDEX IF EXISTS "audit"."token_collection_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.token_collection TEARDOWN


ALTER TABLE token_collection RENAME TO token_collection_v79;
ALTER TABLE audit.token_collection RENAME TO token_collection_v79;

CREATE TABLE token_collection
(
	token_collection_id	integer NOT NULL,
	token_collection_name	varchar(50) NOT NULL,
	token_collection_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	external_id	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'token_collection', false);
ALTER TABLE token_collection
	ALTER token_collection_id
	SET DEFAULT nextval('token_collection_token_collection_id_seq'::regclass);
INSERT INTO token_collection (
	token_collection_id,
	token_collection_name,
	token_collection_type,
	description,
	external_id,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	token_collection_id,
	token_collection_name,
	token_collection_type,
	description,
	NULL,		-- new column (external_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM token_collection_v79;

INSERT INTO audit.token_collection (
	token_collection_id,
	token_collection_name,
	token_collection_type,
	description,
	external_id,		-- new column (external_id)
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
	token_collection_id,
	token_collection_name,
	token_collection_type,
	description,
	NULL,		-- new column (external_id)
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
FROM audit.token_collection_v79;

ALTER TABLE token_collection
	ALTER token_collection_id
	SET DEFAULT nextval('token_collection_token_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE token_collection ADD CONSTRAINT pk_token_collection PRIMARY KEY (token_collection_id);
ALTER TABLE token_collection ADD CONSTRAINT uq_token_coll_name_type UNIQUE (token_collection_name, token_collection_type);

-- Table/Column Comments
COMMENT ON TABLE token_collection IS 'Group tokens together in arbitrary ways.';
COMMENT ON COLUMN token_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between token_collection and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_tokcolid
	FOREIGN KEY (property_value_token_col_id) REFERENCES token_collection(token_collection_id);
-- consider FK between token_collection and token_collection_hier
ALTER TABLE token_collection_hier
	ADD CONSTRAINT fk_tok_col_hier_ch_tok_colid
	FOREIGN KEY (token_collection_id) REFERENCES token_collection(token_collection_id);
-- consider FK between token_collection and token_collection_hier
ALTER TABLE token_collection_hier
	ADD CONSTRAINT fk_tok_col_hier_tok_colid
	FOREIGN KEY (child_token_collection_id) REFERENCES token_collection(token_collection_id);
-- consider FK between token_collection and token_collection_token
ALTER TABLE token_collection_token
	ADD CONSTRAINT fk_tok_col_tok_token_col_id
	FOREIGN KEY (token_collection_id) REFERENCES token_collection(token_collection_id);

-- FOREIGN KEYS TO
-- consider FK token_collection and val_token_collection_type
ALTER TABLE token_collection
	ADD CONSTRAINT fk_tok_col_mem_token_col_type
	FOREIGN KEY (token_collection_type) REFERENCES val_token_collection_type(token_collection_type);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'token_collection');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'token_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'token_collection');
ALTER SEQUENCE token_collection_token_collection_id_seq
	 OWNED BY token_collection.token_collection_id;
DROP TABLE IF EXISTS token_collection_v79;
DROP TABLE IF EXISTS audit.token_collection_v79;
-- DONE DEALING WITH TABLE token_collection
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE voe

-- FOREIGN KEYS FROM
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_fk_voe;
ALTER TABLE voe_relation DROP CONSTRAINT IF EXISTS fk_voe_ref_voe_rel_rltdvoe;
ALTER TABLE voe_relation DROP CONSTRAINT IF EXISTS fk_voe_ref_voe_rel_voe;
ALTER TABLE voe_sw_package DROP CONSTRAINT IF EXISTS fk_voe_swpkg_ref_voe;
ALTER TABLE voe_symbolic_track DROP CONSTRAINT IF EXISTS fk_voe_symbtrk_ref_actvvoe;
ALTER TABLE voe_symbolic_track DROP CONSTRAINT IF EXISTS fk_voe_symbtrk_ref_pendvoe;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.voe DROP CONSTRAINT IF EXISTS fk_voe_ref_v_svcenv;
ALTER TABLE jazzhands.voe DROP CONSTRAINT IF EXISTS fk_voe_ref_vvoestate;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'voe');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.voe DROP CONSTRAINT IF EXISTS ak_uq_voe_voe_name_sw_vonage_o;
ALTER TABLE jazzhands.voe DROP CONSTRAINT IF EXISTS pk_vonage_operating_env;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.voe DROP CONSTRAINT IF EXISTS sys_c0033904;
ALTER TABLE jazzhands.voe DROP CONSTRAINT IF EXISTS sys_c0033905;
ALTER TABLE jazzhands.voe DROP CONSTRAINT IF EXISTS sys_c0033906;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_voe ON jazzhands.voe;
DROP TRIGGER IF EXISTS trigger_audit_voe ON jazzhands.voe;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'voe');
---- BEGIN audit.voe TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'voe');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.voe DROP CONSTRAINT IF EXISTS voe_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_voe_ak_uq_voe_voe_name_sw_vonage_o";
DROP INDEX IF EXISTS "audit"."aud_voe_pk_vonage_operating_env";
DROP INDEX IF EXISTS "audit"."voe_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.voe TEARDOWN


ALTER TABLE voe RENAME TO voe_v79;
ALTER TABLE audit.voe RENAME TO voe_v79;

DROP TABLE IF EXISTS voe_v79;
DROP TABLE IF EXISTS audit.voe_v79;
-- DONE DEALING WITH OLD TABLE voe
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE voe_relation

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.voe_relation DROP CONSTRAINT IF EXISTS fk_voe_ref_voe_rel_rltdvoe;
ALTER TABLE jazzhands.voe_relation DROP CONSTRAINT IF EXISTS fk_voe_ref_voe_rel_voe;
ALTER TABLE jazzhands.voe_relation DROP CONSTRAINT IF EXISTS fk_voe_rltn_ref_vupgsev;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'voe_relation');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.voe_relation DROP CONSTRAINT IF EXISTS pk_voe_relation;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."bmap_voe_rel_is_active";
DROP INDEX IF EXISTS "jazzhands"."bmap_voe_rel_upg_sev";
DROP INDEX IF EXISTS "jazzhands"."idx_voe_rel_rel_voe_id";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.voe_relation DROP CONSTRAINT IF EXISTS ckc_is_active_voe_rela;
ALTER TABLE jazzhands.voe_relation DROP CONSTRAINT IF EXISTS sys_c0033916;
ALTER TABLE jazzhands.voe_relation DROP CONSTRAINT IF EXISTS sys_c0033917;
ALTER TABLE jazzhands.voe_relation DROP CONSTRAINT IF EXISTS sys_c0033918;
ALTER TABLE jazzhands.voe_relation DROP CONSTRAINT IF EXISTS sys_c0033919;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_voe_relation ON jazzhands.voe_relation;
DROP TRIGGER IF EXISTS trigger_audit_voe_relation ON jazzhands.voe_relation;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'voe_relation');
---- BEGIN audit.voe_relation TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'voe_relation');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.voe_relation DROP CONSTRAINT IF EXISTS voe_relation_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_voe_relation_pk_voe_relation";
DROP INDEX IF EXISTS "audit"."voe_relation_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.voe_relation TEARDOWN


ALTER TABLE voe_relation RENAME TO voe_relation_v79;
ALTER TABLE audit.voe_relation RENAME TO voe_relation_v79;

DROP TABLE IF EXISTS voe_relation_v79;
DROP TABLE IF EXISTS audit.voe_relation_v79;
-- DONE DEALING WITH OLD TABLE voe_relation
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE voe_sw_package

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.voe_sw_package DROP CONSTRAINT IF EXISTS fk_voe_swpkg_ref_swpkg_rel;
ALTER TABLE jazzhands.voe_sw_package DROP CONSTRAINT IF EXISTS fk_voe_swpkg_ref_voe;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'voe_sw_package');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.voe_sw_package DROP CONSTRAINT IF EXISTS pk_voe_sw_package;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.voe_sw_package DROP CONSTRAINT IF EXISTS sys_c0033927;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_voe_sw_package ON jazzhands.voe_sw_package;
DROP TRIGGER IF EXISTS trigger_audit_voe_sw_package ON jazzhands.voe_sw_package;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'voe_sw_package');
---- BEGIN audit.voe_sw_package TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'voe_sw_package');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.voe_sw_package DROP CONSTRAINT IF EXISTS voe_sw_package_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_voe_sw_package_pk_voe_sw_package";
DROP INDEX IF EXISTS "audit"."voe_sw_package_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.voe_sw_package TEARDOWN


ALTER TABLE voe_sw_package RENAME TO voe_sw_package_v79;
ALTER TABLE audit.voe_sw_package RENAME TO voe_sw_package_v79;

DROP TABLE IF EXISTS voe_sw_package_v79;
DROP TABLE IF EXISTS audit.voe_sw_package_v79;
-- DONE DEALING WITH OLD TABLE voe_sw_package
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE voe_symbolic_track

-- FOREIGN KEYS FROM
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_ref_voesymbtrk;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.voe_symbolic_track DROP CONSTRAINT IF EXISTS fk_voe_symbtrk_ref_actvvoe;
ALTER TABLE jazzhands.voe_symbolic_track DROP CONSTRAINT IF EXISTS fk_voe_symbtrk_ref_pendvoe;
ALTER TABLE jazzhands.voe_symbolic_track DROP CONSTRAINT IF EXISTS fk_voesymbtrk_ref_swpkgrpos;
ALTER TABLE jazzhands.voe_symbolic_track DROP CONSTRAINT IF EXISTS fk_voesymbtrk_ref_vupgsev;
ALTER TABLE jazzhands.voe_symbolic_track DROP CONSTRAINT IF EXISTS fk_vsymbtrk_ref_vvsymbtrnm;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'voe_symbolic_track');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.voe_symbolic_track DROP CONSTRAINT IF EXISTS ak_uq_vsymbtrk_trk_sw_voe_symb;
ALTER TABLE jazzhands.voe_symbolic_track DROP CONSTRAINT IF EXISTS pk_voe_symbolic_track;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_voe_symbolic_track ON jazzhands.voe_symbolic_track;
DROP TRIGGER IF EXISTS trigger_audit_voe_symbolic_track ON jazzhands.voe_symbolic_track;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'voe_symbolic_track');
---- BEGIN audit.voe_symbolic_track TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'voe_symbolic_track');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.voe_symbolic_track DROP CONSTRAINT IF EXISTS voe_symbolic_track_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_voe_symbolic_track_ak_uq_vsymbtrk_trk_sw_voe_symb";
DROP INDEX IF EXISTS "audit"."aud_voe_symbolic_track_pk_voe_symbolic_track";
DROP INDEX IF EXISTS "audit"."voe_symbolic_track_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.voe_symbolic_track TEARDOWN


ALTER TABLE voe_symbolic_track RENAME TO voe_symbolic_track_v79;
ALTER TABLE audit.voe_symbolic_track RENAME TO voe_symbolic_track_v79;

DROP TABLE IF EXISTS voe_symbolic_track_v79;
DROP TABLE IF EXISTS audit.voe_symbolic_track_v79;
-- DONE DEALING WITH OLD TABLE voe_symbolic_track
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_dns_changes_pending
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_changes_pending', 'v_dns_changes_pending');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dns_changes_pending');
DROP VIEW IF EXISTS jazzhands.v_dns_changes_pending;
CREATE VIEW jazzhands.v_dns_changes_pending AS
 WITH chg AS (
         SELECT dns_change_record.dns_change_record_id,
            dns_change_record.dns_domain_id,
                CASE
                    WHEN family(dns_change_record.ip_address) = 4 THEN set_masklen(dns_change_record.ip_address, 24)
                    ELSE set_masklen(dns_change_record.ip_address, 64)
                END AS ip_address,
            dns_utils.get_domain_from_cidr(dns_change_record.ip_address) AS cidrdns
           FROM dns_change_record
          WHERE dns_change_record.ip_address IS NOT NULL
        )
 SELECT DISTINCT x.dns_change_record_id,
    x.dns_domain_id,
    x.should_generate,
    x.last_generated,
    x.soa_name,
    x.ip_address
   FROM ( SELECT chg.dns_change_record_id,
            n.dns_domain_id,
            du.should_generate,
            du.last_generated,
            n.soa_name,
            chg.ip_address
           FROM chg
             JOIN dns_domain n ON chg.cidrdns = n.soa_name::text
             JOIN dns_domain_ip_universe du ON du.dns_domain_id = n.dns_domain_id
        UNION ALL
         SELECT chg.dns_change_record_id,
            d.dns_domain_id,
            du.should_generate,
            du.last_generated,
            d.soa_name,
            NULL::inet
           FROM dns_change_record chg
             JOIN dns_domain d USING (dns_domain_id)
             JOIN dns_domain_ip_universe du USING (dns_domain_id)
          WHERE chg.dns_domain_id IS NOT NULL) x;

-- just in case
-- SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_dns_changes_pending';
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dns_changes_pending
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_dns_domain_nouniverse
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_domain_nouniverse', 'v_dns_domain_nouniverse');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dns_domain_nouniverse');
DROP VIEW IF EXISTS jazzhands.v_dns_domain_nouniverse;
CREATE VIEW jazzhands.v_dns_domain_nouniverse AS
 SELECT d.dns_domain_id,
    d.dns_domain_name AS soa_name,
    du.soa_class,
    du.soa_ttl,
    du.soa_serial,
    du.soa_refresh,
    du.soa_retry,
    du.soa_expire,
    du.soa_minimum,
    du.soa_mname,
    du.soa_rname,
    d.parent_dns_domain_id,
    du.should_generate,
    du.last_generated,
    d.dns_domain_type,
    COALESCE(d.data_ins_user, du.data_ins_user) AS data_ins_user,
    COALESCE(d.data_ins_date, du.data_ins_date) AS data_ins_date,
    COALESCE(du.data_upd_user, d.data_upd_user) AS data_upd_user,
    COALESCE(du.data_upd_date, d.data_upd_date) AS data_upd_date
   FROM dns_domain d
     JOIN dns_domain_ip_universe du USING (dns_domain_id)
  WHERE du.ip_universe_id = 0;

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_dns_domain_nouniverse';
SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dns_domain_nouniverse
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_dns_fwd
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_fwd', 'v_dns_fwd');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dns_fwd');
DROP VIEW IF EXISTS jazzhands.v_dns_fwd;
CREATE VIEW jazzhands.v_dns_fwd AS
 SELECT u.dns_record_id,
    u.network_range_id,
    u.dns_domain_id,
    u.dns_name,
    u.dns_ttl,
    u.dns_class,
    u.dns_type,
    u.dns_value,
    u.dns_priority,
    u.ip,
    u.netblock_id,
    u.ip_universe_id,
    u.ref_record_id,
    u.dns_srv_service,
    u.dns_srv_protocol,
    u.dns_srv_weight,
    u.dns_srv_port,
    u.is_enabled,
    u.should_generate_ptr,
    u.dns_value_record_id
   FROM ( SELECT d.dns_record_id,
            NULL::integer AS network_range_id,
            d.dns_domain_id,
            COALESCE(rdns.dns_name, d.dns_name) AS dns_name,
            d.dns_ttl,
            d.dns_class,
            d.dns_type,
                CASE
                    WHEN d.dns_value IS NOT NULL THEN d.dns_value::text
                    WHEN (d.dns_type::text = ANY (ARRAY['A'::character varying, 'AAAA'::character varying]::text[])) AND d.netblock_id IS NULL AND d.dns_value_record_id IS NOT NULL THEN NULL::text
                    WHEN d.dns_value_record_id IS NULL THEN d.dns_value::text
                    WHEN dv.dns_domain_id = d.dns_domain_id THEN dv.dns_name::text
                    ELSE concat(dv.dns_name, '.', dv.soa_name, '.')
                END AS dns_value,
            d.dns_priority,
                CASE
                    WHEN d.dns_value_record_id IS NOT NULL AND (d.dns_type::text = ANY (ARRAY['A'::character varying, 'AAAA'::character varying]::text[])) THEN dv.ip_address
                    ELSE ni.ip_address
                END AS ip,
                CASE
                    WHEN d.dns_value_record_id IS NOT NULL AND (d.dns_type::text = ANY (ARRAY['A'::character varying, 'AAAA'::character varying]::text[])) THEN dv.netblock_id
                    ELSE ni.netblock_id
                END AS netblock_id,
            d.ip_universe_id,
            rdns.reference_dns_record_id AS ref_record_id,
            d.dns_srv_service,
            d.dns_srv_protocol,
            d.dns_srv_weight,
            d.dns_srv_port,
            d.is_enabled,
            d.should_generate_ptr,
            d.dns_value_record_id
           FROM dns_record d
             LEFT JOIN netblock ni USING (netblock_id)
             LEFT JOIN ( SELECT dns_record.dns_record_id AS reference_dns_record_id,
                    dns_record.dns_name,
                    dns_record.netblock_id,
                    netblock.ip_address
                   FROM dns_record
                     LEFT JOIN netblock USING (netblock_id)) rdns USING (reference_dns_record_id)
             LEFT JOIN ( SELECT dr.dns_record_id,
                    dr.dns_name,
                    dom.dns_domain_id,
                    dom.soa_name,
                    dr.dns_value,
                    dnb.ip_address AS ip,
                    dnb.ip_address,
                    dnb.netblock_id
                   FROM dns_record dr
                     JOIN dns_domain dom USING (dns_domain_id)
                     LEFT JOIN netblock dnb USING (netblock_id)) dv ON d.dns_value_record_id = dv.dns_record_id
        UNION ALL
         SELECT NULL::integer AS dns_record_id,
            range.network_range_id,
            range.dns_domain_id,
            concat(COALESCE(range.dns_prefix, 'pool'::character varying), '-', replace(host(range.ip), '.'::text, '-'::text)) AS dns_name,
            NULL::integer AS dns_ttl,
            'IN'::character varying AS dns_class,
                CASE
                    WHEN family(range.ip) = 4 THEN 'A'::text
                    ELSE 'AAAA'::text
                END AS dns_type,
            NULL::text AS dns_value,
            NULL::integer AS dns_prority,
            range.ip,
            NULL::integer AS netblock_id,
            range.ip_universe_id,
            NULL::integer AS ref_dns_record_id,
            NULL::character varying AS dns_srv_service,
            NULL::character varying AS dns_srv_protocol,
            NULL::integer AS dns_srv_weight,
            NULL::integer AS dns_srv_port,
            'Y'::bpchar AS is_enabled,
            'N'::character(1) AS should_generate_ptr,
            NULL::integer AS dns_value_record_id
           FROM ( SELECT dr.network_range_id,
                    dr.dns_domain_id,
                    nbstart.ip_universe_id,
                    dr.dns_prefix,
                    nbstart.ip_address + generate_series(0::bigint, nbstop.ip_address - nbstart.ip_address) AS ip
                   FROM network_range dr
                     JOIN netblock nbstart ON dr.start_netblock_id = nbstart.netblock_id
                     JOIN netblock nbstop ON dr.stop_netblock_id = nbstop.netblock_id) range) u
  WHERE u.dns_type::text <> 'REVERSE_ZONE_BLOCK_PTR'::text
UNION ALL
 SELECT NULL::integer AS dns_record_id,
    NULL::integer AS network_range_id,
    dns_domain.parent_dns_domain_id AS dns_domain_id,
    regexp_replace(dns_domain.soa_name::text, ('\.'::text || pdom.parent_soa_name::text) || '$'::text, ''::text) AS dns_name,
    dns_record.dns_ttl,
    dns_record.dns_class,
    dns_record.dns_type,
        CASE
            WHEN dns_record.dns_value::text ~ '\.$'::text THEN dns_record.dns_value::text
            ELSE concat(dns_record.dns_value, '.', dns_domain.soa_name, '.')
        END AS dns_value,
    dns_record.dns_priority,
    NULL::inet AS ip,
    NULL::integer AS netblock_id,
    dns_record.ip_universe_id,
    NULL::integer AS ref_record_id,
    NULL::text AS dns_srv_service,
    NULL::text AS dns_srv_protocol,
    NULL::integer AS dns_srv_weight,
    NULL::integer AS dns_srv_port,
    dns_record.is_enabled,
    'N'::character(1) AS should_generate_ptr,
    NULL::integer AS dns_value_record_id
   FROM dns_record
     JOIN dns_domain USING (dns_domain_id)
     JOIN ( SELECT dns_domain_1.dns_domain_id AS parent_dns_domain_id,
            dns_domain_1.soa_name AS parent_soa_name
           FROM dns_domain dns_domain_1) pdom USING (parent_dns_domain_id)
  WHERE dns_record.dns_class::text = 'IN'::text AND dns_record.dns_type::text = 'NS'::text AND dns_record.dns_name IS NULL AND dns_domain.parent_dns_domain_id IS NOT NULL;

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_dns_fwd';
SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dns_fwd
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_dns_rvs
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_rvs', 'v_dns_rvs');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dns_rvs');
DROP VIEW IF EXISTS jazzhands.v_dns_rvs;
CREATE VIEW jazzhands.v_dns_rvs AS
 SELECT NULL::integer AS dns_record_id,
    combo.network_range_id,
    rootd.dns_domain_id,
        CASE
            WHEN family(combo.ip) = 4 THEN regexp_replace(host(combo.ip), '^.*[.](\d+)$'::text, '\1'::text, 'i'::text)
            ELSE regexp_replace(dns_utils.v6_inaddr(combo.ip), ('.'::text || replace(dd.soa_name::text, '.ip6.arpa'::text, ''::text)) || '$'::text, ''::text, 'i'::text)
        END AS dns_name,
    combo.dns_ttl,
    'IN'::text AS dns_class,
    'PTR'::text AS dns_type,
        CASE
            WHEN combo.dns_name IS NULL THEN concat(combo.soa_name, '.')
            ELSE concat(combo.dns_name, '.', combo.soa_name, '.')
        END AS dns_value,
    NULL::integer AS dns_priority,
    combo.ip,
    combo.netblock_id,
    combo.ip_universe_id,
    NULL::integer AS rdns_record_id,
    NULL::text AS dns_srv_service,
    NULL::text AS dns_srv_protocol,
    NULL::integer AS dns_srv_weight,
    NULL::integer AS dns_srv_srv_port,
    combo.is_enabled,
    'N'::character(1) AS should_generate_ptr,
    NULL::integer AS dns_value_record_id
   FROM ( SELECT host(nb.ip_address)::inet AS ip,
            NULL::integer AS network_range_id,
            COALESCE(rdns.dns_name, dns.dns_name) AS dns_name,
            dom.soa_name,
            dns.dns_ttl,
            network(nb.ip_address) AS ip_base,
            nb.ip_universe_id,
            dns.is_enabled,
            'N'::character(1) AS should_generate_ptr,
            nb.netblock_id
           FROM netblock nb
             JOIN dns_record dns ON nb.netblock_id = dns.netblock_id
             JOIN dns_domain dom ON dns.dns_domain_id = dom.dns_domain_id
             LEFT JOIN dns_record rdns ON rdns.dns_record_id = dns.reference_dns_record_id
          WHERE dns.should_generate_ptr = 'Y'::bpchar AND dns.dns_class::text = 'IN'::text AND (dns.dns_type::text = 'A'::text OR dns.dns_type::text = 'AAAA'::text) AND nb.is_single_address = 'Y'::bpchar
        UNION ALL
         SELECT host(range.ip)::inet AS ip,
            range.network_range_id,
            concat(COALESCE(range.dns_prefix, 'pool'::character varying), '-', replace(host(range.ip), '.'::text, '-'::text)) AS dns_name,
            dom.soa_name,
            NULL::integer AS dns_ttl,
            network(range.ip) AS ip_base,
            range.ip_universe_id,
            'Y'::bpchar AS is_enabled,
            'N'::character(1) AS should_generate_ptr,
            NULL::integer AS netblock_id
           FROM ( SELECT dr.network_range_id,
                    nbstart.ip_universe_id,
                    dr.dns_domain_id,
                    dr.dns_prefix,
                    nbstart.ip_address + generate_series(0::bigint, nbstop.ip_address - nbstart.ip_address) AS ip
                   FROM network_range dr
                     JOIN netblock nbstart ON dr.start_netblock_id = nbstart.netblock_id
                     JOIN netblock nbstop ON dr.stop_netblock_id = nbstop.netblock_id) range
             JOIN dns_domain dom ON range.dns_domain_id = dom.dns_domain_id) combo,
    netblock root
     JOIN dns_record rootd ON rootd.netblock_id = root.netblock_id AND rootd.dns_type::text = 'REVERSE_ZONE_BLOCK_PTR'::text
     JOIN dns_domain dd USING (dns_domain_id)
  WHERE family(root.ip_address) = family(combo.ip) AND set_masklen(combo.ip, masklen(root.ip_address)) <<= root.ip_address;

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_dns_rvs';
SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dns_rvs
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_property
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_property', 'v_property');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_property');
DROP VIEW IF EXISTS jazzhands.v_property;
CREATE VIEW jazzhands.v_property AS
 SELECT property.property_id,
    property.account_collection_id,
    property.account_id,
    property.account_realm_id,
    property.company_collection_id,
    property.company_id,
    property.device_collection_id,
    property.dns_domain_collection_id,
    property.layer2_network_collection_id,
    property.layer3_network_collection_id,
    property.netblock_collection_id,
    property.network_range_id,
    property.operating_system_id,
    property.operating_system_snapshot_id,
    property.person_id,
    property.property_collection_id,
    property.service_env_collection_id,
    property.site_code,
    property.x509_signed_certificate_id,
    property.property_name,
    property.property_type,
    property.property_value,
    property.property_value_timestamp,
    property.property_value_company_id,
    property.property_value_account_coll_id,
    property.property_value_device_coll_id,
    property.property_value_nblk_coll_id,
    property.property_value_password_type,
    property.property_value_person_id,
    property.property_value_sw_package_id,
    property.property_value_token_col_id,
    property.property_rank,
    property.start_date,
    property.finish_date,
    property.is_enabled,
    property.data_ins_user,
    property.data_ins_date,
    property.data_upd_user,
    property.data_upd_date
   FROM property
  WHERE property.is_enabled = 'Y'::bpchar AND (property.start_date IS NULL AND property.finish_date IS NULL OR property.start_date IS NULL AND now() <= property.finish_date OR property.start_date <= now() AND property.finish_date IS NULL OR property.start_date <= now() AND now() <= property.finish_date);

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_property';
SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_property
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_dns
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns', 'v_dns');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dns');
DROP VIEW IF EXISTS jazzhands.v_dns;
CREATE VIEW jazzhands.v_dns AS
 SELECT d.dns_record_id,
    d.network_range_id,
    d.dns_domain_id,
    d.dns_name,
    d.dns_ttl,
    d.dns_class,
    d.dns_type,
    d.dns_value,
    d.dns_priority,
    d.ip,
    d.netblock_id,
    d.real_ip_universe_id AS ip_universe_id,
    d.ref_record_id,
    d.dns_srv_service,
    d.dns_srv_protocol,
    d.dns_srv_weight,
    d.dns_srv_port,
    d.is_enabled,
    d.should_generate_ptr,
    d.dns_value_record_id
   FROM ( SELECT f.ip_universe_id AS real_ip_universe_id,
            f.dns_record_id,
            f.network_range_id,
            f.dns_domain_id,
            f.dns_name,
            f.dns_ttl,
            f.dns_class,
            f.dns_type,
            f.dns_value,
            f.dns_priority,
            f.ip,
            f.netblock_id,
            f.ip_universe_id,
            f.ref_record_id,
            f.dns_srv_service,
            f.dns_srv_protocol,
            f.dns_srv_weight,
            f.dns_srv_port,
            f.is_enabled,
            f.should_generate_ptr,
            f.dns_value_record_id
           FROM v_dns_fwd f
        UNION
         SELECT x.ip_universe_id AS real_ip_universe_id,
            f.dns_record_id,
            f.network_range_id,
            f.dns_domain_id,
            f.dns_name,
            f.dns_ttl,
            f.dns_class,
            f.dns_type,
            f.dns_value,
            f.dns_priority,
            f.ip,
            f.netblock_id,
            f.ip_universe_id,
            f.ref_record_id,
            f.dns_srv_service,
            f.dns_srv_protocol,
            f.dns_srv_weight,
            f.dns_srv_port,
            f.is_enabled,
            f.should_generate_ptr,
            f.dns_value_record_id
           FROM ip_universe_visibility x,
            v_dns_fwd f
          WHERE x.visible_ip_universe_id = f.ip_universe_id OR f.ip_universe_id IS NULL
        UNION
         SELECT f.ip_universe_id AS real_ip_universe_id,
            f.dns_record_id,
            f.network_range_id,
            f.dns_domain_id,
            f.dns_name,
            f.dns_ttl,
            f.dns_class,
            f.dns_type,
            f.dns_value,
            f.dns_priority,
            f.ip,
            f.netblock_id,
            f.ip_universe_id,
            f.rdns_record_id,
            f.dns_srv_service,
            f.dns_srv_protocol,
            f.dns_srv_weight,
            f.dns_srv_srv_port,
            f.is_enabled,
            f.should_generate_ptr,
            f.dns_value_record_id
           FROM v_dns_rvs f
        UNION
         SELECT x.ip_universe_id AS real_ip_universe_id,
            f.dns_record_id,
            f.network_range_id,
            f.dns_domain_id,
            f.dns_name,
            f.dns_ttl,
            f.dns_class,
            f.dns_type,
            f.dns_value,
            f.dns_priority,
            f.ip,
            f.netblock_id,
            f.ip_universe_id,
            f.rdns_record_id,
            f.dns_srv_service,
            f.dns_srv_protocol,
            f.dns_srv_weight,
            f.dns_srv_srv_port,
            f.is_enabled,
            f.should_generate_ptr,
            f.dns_value_record_id
           FROM ip_universe_visibility x,
            v_dns_rvs f
          WHERE x.visible_ip_universe_id = f.ip_universe_id OR f.ip_universe_id IS NULL) d;

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_dns';
SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_dns
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_unix_passwd_mappings
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_passwd_mappings', 'v_unix_passwd_mappings');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_unix_passwd_mappings');
DROP VIEW IF EXISTS jazzhands.v_unix_passwd_mappings;
CREATE VIEW jazzhands.v_unix_passwd_mappings AS
 WITH passtype AS (
         SELECT ap.account_id,
            ap.password,
            ap.expire_time,
            ap.change_time,
            subq.device_collection_id,
            subq.password_type,
            subq.ord
           FROM ( SELECT dchd.device_collection_id,
                    p.property_value_password_type AS password_type,
                    row_number() OVER (PARTITION BY dchd.device_collection_id) AS ord
                   FROM v_property p
                     JOIN v_device_coll_hier_detail dchd ON dchd.parent_device_collection_id = p.device_collection_id
                  WHERE p.property_name::text = 'UnixPwType'::text AND p.property_type::text = 'MclassUnixProp'::text) subq
             JOIN account_password ap USING (password_type)
             JOIN account_unix_info a USING (account_id)
          WHERE subq.ord = 1
        )
 SELECT s.device_collection_id,
    s.account_id,
    s.login,
    s.crypt,
    s.unix_uid,
    s.unix_group_name,
    regexp_replace(s.gecos, ' +'::text, ' '::text, 'g'::text) AS gecos,
    regexp_replace(
        CASE
            WHEN s.forcehome IS NOT NULL AND s.forcehome::text ~ '/$'::text THEN concat(s.forcehome, s.login)
            WHEN s.home IS NOT NULL AND s.home::text ~ '^/'::text THEN s.home::text
            WHEN s.hometype::text = 'generic'::text THEN concat(COALESCE(s.homeplace, '/home'::character varying), '/', 'generic')
            WHEN s.home IS NOT NULL AND s.home::text ~ '/$'::text THEN concat(s.home, '/', s.login)
            WHEN s.homeplace IS NOT NULL AND s.homeplace::text ~ '/$'::text THEN concat(s.homeplace, '/', s.login)
            ELSE concat(COALESCE(s.homeplace, '/home'::character varying), '/', s.login)
        END, '/+'::text, '/'::text, 'g'::text) AS home,
    s.shell,
    s.ssh_public_key,
    s.setting,
    s.mclass_setting,
    s.group_names AS extra_groups
   FROM ( SELECT o.device_collection_id,
            a.account_id,
            a.login,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceCrypt'::text)]::text,
                CASE
                    WHEN pwt.expire_time IS NOT NULL AND now() < pwt.expire_time OR (now() - pwt.change_time) < concat(COALESCE((( SELECT v_property.property_value
                       FROM v_property
                      WHERE v_property.property_type::text = 'Defaults'::text AND v_property.property_name::text = '_maxpasswdlife'::text))::text, 90::text), 'days')::interval THEN pwt.password
                    ELSE NULL::character varying
                END::text, '*'::text) AS crypt,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceUserUID'::text)]::integer, a.unix_uid) AS unix_uid,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceUserGroup'::text)]::character varying(255), ugac.account_collection_name) AS unix_group_name,
                CASE
                    WHEN a.description IS NOT NULL THEN a.description::text
                    ELSE concat(COALESCE(p.preferred_first_name, p.first_name), ' ',
                    CASE
                        WHEN p.middle_name IS NOT NULL AND length(p.middle_name::text) = 1 THEN concat(p.middle_name, '.')::character varying
                        ELSE p.middle_name
                    END, ' ', COALESCE(p.preferred_last_name, p.last_name))
                END AS gecos,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceHome'::text)], a.default_home) AS home,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceShell'::text)], a.shell) AS shell,
            o.setting,
            mcs.mclass_setting,
            o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceHome'::text)] AS forcehome,
            mcs.mclass_setting[( SELECT i.i + 1
                   FROM generate_subscripts(mcs.mclass_setting, 1) i(i)
                  WHERE mcs.mclass_setting[i.i]::text = 'HomePlace'::text)] AS homeplace,
            mcs.mclass_setting[( SELECT i.i + 1
                   FROM generate_subscripts(mcs.mclass_setting, 1) i(i)
                  WHERE mcs.mclass_setting[i.i]::text = 'UnixHomeType'::text)] AS hometype,
            ssh.ssh_public_key,
            extra_groups.group_names
           FROM ( SELECT a_1.account_id,
                    a_1.login,
                    a_1.person_id,
                    a_1.company_id,
                    a_1.is_enabled,
                    a_1.account_realm_id,
                    a_1.account_status,
                    a_1.account_role,
                    a_1.account_type,
                    a_1.description,
                    a_1.external_id,
                    a_1.data_ins_user,
                    a_1.data_ins_date,
                    a_1.data_upd_user,
                    a_1.data_upd_date,
                    aui.unix_uid,
                    aui.unix_group_acct_collection_id,
                    aui.shell,
                    aui.default_home
                   FROM account a_1
                     JOIN account_unix_info aui USING (account_id)
                  WHERE a_1.is_enabled = 'Y'::bpchar) a
             JOIN v_device_col_account_cart o USING (account_id)
             JOIN device_collection dc USING (device_collection_id)
             JOIN person p USING (person_id)
             JOIN unix_group ug ON a.unix_group_acct_collection_id = ug.account_collection_id
             JOIN account_collection ugac ON ugac.account_collection_id = ug.account_collection_id
             LEFT JOIN ( SELECT p_1.device_collection_id,
                    acae.account_id,
                    array_agg(ac.account_collection_name) AS group_names
                   FROM v_property p_1
                     JOIN device_collection dc_1 USING (device_collection_id)
                     JOIN account_collection ac USING (account_collection_id)
                     JOIN account_collection pac ON pac.account_collection_id = p_1.property_value_account_coll_id
                     JOIN v_acct_coll_acct_expanded acae ON pac.account_collection_id = acae.account_collection_id
                  WHERE p_1.property_type::text = 'MclassUnixProp'::text AND p_1.property_name::text = 'UnixGroupMemberOverride'::text AND dc_1.device_collection_type::text <> 'mclass'::text
                  GROUP BY p_1.device_collection_id, acae.account_id) extra_groups USING (device_collection_id, account_id)
             LEFT JOIN v_device_collection_account_ssh_key ssh ON a.account_id = ssh.account_id AND (ssh.device_collection_id IS NULL OR ssh.device_collection_id = o.device_collection_id)
             LEFT JOIN v_unix_mclass_settings mcs ON mcs.device_collection_id = dc.device_collection_id
             LEFT JOIN passtype pwt ON o.device_collection_id = pwt.device_collection_id AND a.account_id = pwt.account_id) s
  ORDER BY s.device_collection_id, s.account_id;

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_unix_passwd_mappings';
SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_unix_passwd_mappings
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_unix_group_mappings
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_group_mappings', 'v_unix_group_mappings');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_unix_group_mappings');
DROP VIEW IF EXISTS jazzhands.v_unix_group_mappings;
CREATE VIEW jazzhands.v_unix_group_mappings AS
 SELECT dc.device_collection_id,
    ac.account_collection_id,
    ac.account_collection_name AS group_name,
    COALESCE(o.setting[( SELECT i.i + 1
           FROM generate_subscripts(o.setting, 1) i(i)
          WHERE o.setting[i.i]::text = 'ForceGroupGID'::text)]::integer, unix_group.unix_gid) AS unix_gid,
    unix_group.group_password,
    o.setting,
    mcs.mclass_setting,
    array_agg(DISTINCT a.login ORDER BY a.login) AS members
   FROM device_collection dc
     JOIN ( SELECT dch.device_collection_id,
            vace.account_collection_id
           FROM v_property p
             JOIN v_device_coll_hier_detail dch ON p.device_collection_id = dch.parent_device_collection_id
             JOIN v_account_collection_expanded vace ON vace.root_account_collection_id = p.account_collection_id
          WHERE p.property_name::text = 'UnixGroup'::text AND p.property_type::text = 'MclassUnixProp'::text
        UNION ALL
         SELECT dch.device_collection_id,
            uag.account_collection_id
           FROM v_property p
             JOIN v_device_coll_hier_detail dch ON p.device_collection_id = dch.parent_device_collection_id
             JOIN v_acct_coll_acct_expanded vace USING (account_collection_id)
             JOIN ( SELECT a_2.account_id,
                    a_2.login,
                    a_2.person_id,
                    a_2.company_id,
                    a_2.is_enabled,
                    a_2.account_realm_id,
                    a_2.account_status,
                    a_2.account_role,
                    a_2.account_type,
                    a_2.description,
                    a_2.external_id,
                    a_2.data_ins_user,
                    a_2.data_ins_date,
                    a_2.data_upd_user,
                    a_2.data_upd_date
                   FROM account a_2
                     JOIN account_unix_info USING (account_id)
                  WHERE a_2.is_enabled = 'Y'::bpchar) a_1 ON vace.account_id = a_1.account_id
             JOIN account_unix_info aui ON a_1.account_id = aui.account_id
             JOIN unix_group ug ON ug.account_collection_id = aui.unix_group_acct_collection_id
             JOIN account_collection uag ON ug.account_collection_id = uag.account_collection_id
          WHERE p.property_name::text = 'UnixLogin'::text AND p.property_type::text = 'MclassUnixProp'::text) ugmap USING (device_collection_id)
     JOIN account_collection ac USING (account_collection_id)
     JOIN unix_group USING (account_collection_id)
     LEFT JOIN v_device_col_account_col_cart o USING (device_collection_id, account_collection_id)
     LEFT JOIN ( SELECT g.account_id,
            g.device_collection_id,
            g.account_collection_id,
            g.unix_uid,
            g.unix_group_acct_collection_id,
            g.shell,
            g.default_home,
            g.data_ins_user,
            g.data_ins_date,
            g.data_upd_user,
            g.data_upd_date,
            g.login,
            g.person_id,
            g.company_id,
            g.is_enabled,
            g.account_realm_id,
            g.account_status,
            g.account_role,
            g.account_type,
            g.description,
            g.external_id,
            g.data_ins_user_1 AS data_ins_user,
            g.data_ins_date_1 AS data_ins_date,
            g.data_upd_user_1 AS data_upd_user,
            g.data_upd_date_1 AS data_upd_date
           FROM ( SELECT actoa.account_id,
                    actoa.device_collection_id,
                    actoa.account_collection_id,
                    ui.unix_uid,
                    ui.unix_group_acct_collection_id,
                    ui.shell,
                    ui.default_home,
                    ui.data_ins_user,
                    ui.data_ins_date,
                    ui.data_upd_user,
                    ui.data_upd_date,
                    a_1.login,
                    a_1.person_id,
                    a_1.company_id,
                    a_1.is_enabled,
                    a_1.account_realm_id,
                    a_1.account_status,
                    a_1.account_role,
                    a_1.account_type,
                    a_1.description,
                    a_1.external_id,
                    a_1.data_ins_user,
                    a_1.data_ins_date,
                    a_1.data_upd_user,
                    a_1.data_upd_date
                   FROM ( SELECT dc_1.device_collection_id,
                            ae.account_collection_id,
                            ae.account_id
                           FROM device_collection dc_1,
                            v_acct_coll_acct_expanded ae
                             JOIN unix_group unix_group_1 USING (account_collection_id)
                             JOIN account_collection inac USING (account_collection_id)
                          WHERE dc_1.device_collection_type::text = 'mclass'::text
                        UNION ALL
                         SELECT dcugm.device_collection_id,
                            dcugm.account_collection_id,
                            dcugm.account_id
                           FROM ( SELECT dch.device_collection_id,
                                    p.account_collection_id,
                                    aca.account_id
                                   FROM v_property p
                                     JOIN unix_group ug USING (account_collection_id)
                                     JOIN v_device_coll_hier_detail dch ON p.device_collection_id = dch.parent_device_collection_id
                                     JOIN v_acct_coll_acct_expanded aca ON p.property_value_account_coll_id = aca.account_collection_id
                                  WHERE p.property_name::text = 'UnixGroupMemberOverride'::text AND p.property_type::text = 'MclassUnixProp'::text) dcugm) actoa
                     JOIN account_unix_info ui USING (account_id)
                     JOIN ( SELECT a_2.account_id,
                            a_2.login,
                            a_2.person_id,
                            a_2.company_id,
                            a_2.is_enabled,
                            a_2.account_realm_id,
                            a_2.account_status,
                            a_2.account_role,
                            a_2.account_type,
                            a_2.description,
                            a_2.external_id,
                            a_2.data_ins_user,
                            a_2.data_ins_date,
                            a_2.data_upd_user,
                            a_2.data_upd_date
                           FROM account a_2
                             JOIN account_unix_info USING (account_id)
                          WHERE a_2.is_enabled = 'Y'::bpchar) a_1 USING (account_id)) g(account_id, device_collection_id, account_collection_id, unix_uid, unix_group_acct_collection_id, shell, default_home, data_ins_user, data_ins_date, data_upd_user, data_upd_date, login, person_id, company_id, is_enabled, account_realm_id, account_status, account_role, account_type, description, external_id, data_ins_user_1, data_ins_date_1, data_upd_user_1, data_upd_date_1)
             JOIN ( SELECT a_1.account_id,
                    a_1.login,
                    a_1.person_id,
                    a_1.company_id,
                    a_1.is_enabled,
                    a_1.account_realm_id,
                    a_1.account_status,
                    a_1.account_role,
                    a_1.account_type,
                    a_1.description,
                    a_1.external_id,
                    a_1.data_ins_user,
                    a_1.data_ins_date,
                    a_1.data_upd_user,
                    a_1.data_upd_date
                   FROM account a_1
                     JOIN account_unix_info USING (account_id)
                  WHERE a_1.is_enabled = 'Y'::bpchar) accts USING (account_id)
             JOIN v_unix_passwd_mappings USING (device_collection_id, account_id)) a(account_id, device_collection_id, account_collection_id, unix_uid, unix_group_acct_collection_id, shell, default_home, data_ins_user, data_ins_date, data_upd_user, data_upd_date, login, person_id, company_id, is_enabled, account_realm_id, account_status, account_role, account_type, description, external_id, data_ins_user_1, data_ins_date_1, data_upd_user_1, data_upd_date_1) USING (device_collection_id, account_collection_id)
     LEFT JOIN v_unix_mclass_settings mcs ON mcs.device_collection_id = dc.device_collection_id
  GROUP BY dc.device_collection_id, ac.account_collection_id, ac.account_collection_name, unix_group.unix_gid, unix_group.group_password, o.setting, mcs.mclass_setting
  ORDER BY dc.device_collection_id, ac.account_collection_id;

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_unix_group_mappings';
SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_unix_group_mappings
--------------------------------------------------------------------
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
--
-- Process drops in jazzhands
--
DROP TRIGGER IF EXISTS aaa_trigger_asset_component_id_fix ON jazzhands.asset;
DROP FUNCTION IF EXISTS jazzhands.asset_component_id_fix (  );
DROP TRIGGER IF EXISTS aaa_trigger_device_asset_id_fix ON jazzhands.device;
DROP FUNCTION IF EXISTS jazzhands.device_asset_id_fix (  );
DROP TRIGGER IF EXISTS trigger_verify_device_voe ON jazzhands.device;
DROP FUNCTION IF EXISTS jazzhands.verify_device_voe (  );
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_trigger_change');
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_trigger_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	PERFORM *
	FROM dns_domain_ip_universe
	WHERE dns_domain_id = NEW.dns_domain_id
	AND SHOULD_GENERATE = 'Y';
	IF FOUND THEN
		insert into DNS_CHANGE_RECORD
			(dns_domain_id) VALUES (NEW.dns_domain_id);
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_rec_prevent_dups');
CREATE OR REPLACE FUNCTION jazzhands.dns_rec_prevent_dups()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	-- should not be able to insert the same record(s) twice
	WITH newref AS (
		SELECT * FROM dns_record
			WHERE NEW.reference_dns_record_id IS NOT NULL
			AND NEW.reference_dns_record_id = dns_record_id
			ORDER BY dns_record_id LIMIT 1
	), dns AS ( SELECT
			db.dns_record_id,
			coalesce(ref.dns_name, db.dns_name) as dns_name,
			db.dns_domain_id, db.dns_ttl,
			db.dns_class, db.dns_type,
			coalesce(val.dns_value, db.dns_value) AS dns_value,
			db.dns_priority, db.dns_srv_service, db.dns_srv_protocol,
			db.dns_srv_weight, db.dns_srv_port, db.ip_universe_id,
			coalesce(val.netblock_id, db.netblock_id) AS netblock_id,
			db.reference_dns_record_id, db.dns_value_record_id,
			db.should_generate_ptr, db.is_enabled
		FROM dns_record db
			LEFT JOIN dns_record ref
				ON ( db.reference_dns_record_id = ref.dns_record_id)
			LEFT JOIN dns_record val
				ON ( db.dns_value_record_id = val.dns_record_id )
			LEFT JOIN newref
				ON newref.dns_record_id = NEW.reference_dns_record_id
		WHERE db.dns_record_id != NEW.dns_record_id
		AND (lower(coalesce(ref.dns_name, db.dns_name))
					IS NOT DISTINCT FROM
				lower(coalesce(newref.dns_name, NEW.dns_name)) )
		AND ( db.dns_domain_id = NEW.dns_domain_id )
		AND ( db.dns_class = NEW.dns_class )
		AND ( db.dns_type = NEW.dns_type )
    	AND db.dns_record_id != NEW.dns_record_id
		AND db.dns_srv_service IS NOT DISTINCT FROM NEW.dns_srv_service
		AND db.dns_srv_protocol IS NOT DISTINCT FROM NEW.dns_srv_protocol
		AND db.dns_srv_port IS NOT DISTINCT FROM NEW.dns_srv_port
		AND db.ip_universe_id IS NOT DISTINCT FROM NEW.ip_universe_id
		AND db.is_enabled = 'Y'
	) SELECT	count(*)
		INTO	_tally
		FROM dns
			LEFT JOIN dns_record val
				ON ( NEW.dns_value_record_id = val.dns_record_id )
		WHERE
			dns.dns_value IS NOT DISTINCT FROM
				coalesce(val.dns_value, NEW.dns_value)
		AND
			dns.netblock_id IS NOT DISTINCT FROM
				coalesce(val.netblock_id, NEW.netblock_id)
	;

	IF _tally != 0 THEN
		RAISE EXCEPTION 'Attempt to insert the same dns record - % %', _tally,
			NEW USING ERRCODE = 'unique_violation';
	END IF;

	IF NEW.DNS_TYPE = 'A' OR NEW.DNS_TYPE = 'AAAA' THEN
		IF NEW.SHOULD_GENERATE_PTR = 'Y' THEN
			SELECT	count(*)
			 INTO	_tally
			 FROM	dns_record
			WHERE dns_class = 'IN'
			AND dns_type = 'A'
			AND should_generate_ptr = 'Y'
			AND is_enabled = 'Y'
			AND netblock_id = NEW.NETBLOCK_ID
			AND dns_record_id != NEW.DNS_RECORD_ID;

			IF _tally != 0 THEN
				RAISE EXCEPTION 'May not have more than one SHOULD_GENERATE_PTR record on the same IP on netblock_id %', NEW.netblock_id
					USING ERRCODE = 'JH201';
			END IF;
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record_cname_checker');
CREATE OR REPLACE FUNCTION jazzhands.dns_record_cname_checker()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_dom	TEXT;
BEGIN
	--- XXX - need to seriously think about ip_universes here.
	_tally := 0;
	IF TG_OP = 'INSERT' OR NEW.DNS_TYPE != OLD.DNS_TYPE THEN
		IF NEW.DNS_TYPE = 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
			SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE
						NEW.dns_domain_id = x.dns_domain_id
				 AND	NEW.ip_universe_id IS NOT DISTINCT FROM x.ip_universe_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			ELSE
				-- only difference between above and this is the use of OLD
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE
						NEW.dns_domain_id = x.dns_domain_id
				 AND	NEW.ip_universe_id IS NOT DISTINCT FROM x.ip_universe_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		-- this clause is basically the same as above except = 'CANME'
		ELSIF NEW.DNS_TYPE != 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	NEW.ip_universe_id IS NOT DISTINCT FROM x.ip_universe_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			ELSE
				-- only difference between above and this is the use of OLD
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	NEW.ip_universe_id IS NOT DISTINCT FROM x.ip_universe_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		END IF;
	END IF;

	IF _tally > 0 THEN
		SELECT soa_name INTO _dom FROM dns_domain
		WHERE dns_domain_id = NEW.dns_domain_id ;

		if NEW.dns_name IS NULL THEN
			RAISE EXCEPTION '% may not have CNAME and other records (%)',
				_dom, _tally
				USING ERRCODE = 'unique_violation';
		ELSE
			RAISE EXCEPTION '%.% may not have CNAME and other records (%)',
				NEW.dns_name, _dom, _tally
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock');
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	nbtype				RECORD;
	v_netblock_id		netblock.netblock_id%TYPE;
	parent_netblock		RECORD;
	universes			integer[];
	netmask_bits		integer;
	tally				integer;
BEGIN
	IF NEW.ip_address IS NULL THEN
		RAISE EXCEPTION 'Column ip_address may not be null'
			USING ERRCODE = 'not_null_violation';
	END IF;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	IF NEW.is_single_address = 'Y' THEN
		IF nbtype.db_forced_hierarchy = 'Y' THEN
			RAISE DEBUG 'Calculating netmask for new netblock';

			v_netblock_id := netblock_utils.find_best_parent_id(
				NEW.ip_address,
				NULL,
				NEW.netblock_type,
				NEW.ip_universe_id,
				NEW.is_single_address,
				NEW.netblock_id
				);

			IF v_netblock_id IS NULL THEN
				RAISE EXCEPTION 'A single address (%) must be the child of a parent netblock, which must have can_subnet=N', NEW.ip_address
					USING ERRCODE = 'JH105';
			END IF;

			SELECT masklen(ip_address) INTO netmask_bits FROM
				netblock WHERE netblock_id = v_netblock_id;

			NEW.ip_address := set_masklen(NEW.ip_address, netmask_bits);
		END IF;
	END IF;

	/* Done with handling of netmasks */

	IF NEW.can_subnet = 'Y' AND NEW.is_single_address = 'Y' THEN
		RAISE EXCEPTION 'Single addresses may not be subnettable'
			USING ERRCODE = 'JH106';
	END IF;

	IF NEW.is_single_address = 'N' AND (NEW.ip_address != cidr(NEW.ip_address))
			THEN
		RAISE EXCEPTION
			'Non-network bits must be zero if is_single_address is N for %',
			NEW.ip_address
			USING ERRCODE = 'JH103';
	END IF;

	/*
	 * This used to only happen for not-rfc1918 space, but that sort of
	 * uniqueness enforcement is done through ip universes now.
	 */
	PERFORM netblock_id
	   FROM netblock
	  WHERE ip_address = NEW.ip_address AND
			ip_universe_id = NEW.ip_universe_id AND
			netblock_type = NEW.netblock_type AND
			is_single_address = NEW.is_single_address;
	IF (TG_OP = 'INSERT' AND FOUND) THEN
		RAISE EXCEPTION 'Unique Constraint Violated on IP Address: %',
			NEW.ip_address
			USING ERRCODE= 'unique_violation';
	END IF;
	IF (TG_OP = 'UPDATE') THEN
		IF (NEW.ip_address != OLD.ip_address AND FOUND) THEN
			RAISE EXCEPTION
				'Unique Constraint Violated on IP Address: %',
				NEW.ip_address
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	/*
	 * for networks, check for uniqueness across ip universe and ip visibility
	 */
	IF NEW.is_single_address = 'N' THEN
		WITH x AS (
				SELECT	ip_universe_id
				FROM	ip_universe
				WHERE	ip_namespace IN (
							SELECT ip_namespace FROM ip_universe
							WHERE ip_universe_id = NEW.ip_universe_id
						)
				AND		ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	visible_ip_universe_id
				FROM	ip_universe_visibility
				WHERE	ip_universe_id = NEW.ip_universe_id
				AND		ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	ip_universe_id
				FROM	ip_universe_visibility
				WHERE	visible_ip_universe_id = NEW.ip_universe_id
				AND		visible_ip_universe_id != NEW.ip_universe_id
		) SELECT count(*) INTO tally
		FROM netblock
		WHERE ip_address = NEW.ip_address AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id IN (select ip_universe_id FROM x) AND
			is_single_address = 'N' AND
			netblock_id != NEW.netblock_id
		;

		IF tally >  0 THEN
			RAISE EXCEPTION
				'IP Universe Constraint Violated on IP Address: % Universe: %',
				NEW.ip_address, NEW.ip_universe_id
				USING ERRCODE= 'unique_violation';
		END IF;

		IF NEW.can_subnet = 'N' THEN
			WITH x AS (
				SELECT	ip_universe_id
				FROM	ip_universe
				WHERE	ip_namespace IN (
							SELECT ip_namespace FROM ip_universe
							WHERE ip_universe_id = NEW.ip_universe_id
						)
				AND		ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	visible_ip_universe_id
				FROM	ip_universe_visibility
				WHERE	ip_universe_id = NEW.ip_universe_id
				AND		visible_ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	ip_universe_id
				FROM	ip_universe_visibility
				WHERE	visible_ip_universe_id = NEW.ip_universe_id
				AND		ip_universe_id != NEW.ip_universe_id
			) SELECT count(*) INTO tally
			FROM netblock
			WHERE
				ip_universe_id IN (select ip_universe_id FROM x) AND
				(
					ip_address <<= NEW.ip_address OR
					ip_address >>= NEW.ip_address
				) AND
				netblock_type = NEW.netblock_type AND
				is_single_address = 'N' AND
				can_subnet = 'N' AND
				netblock_id != NEW.netblock_id
			;

			IF tally >  0 THEN
				RAISE EXCEPTION
					'Can Subnet = N IP Universe Constraint Violated on IP Address: % Universe: %',
					NEW.ip_address, NEW.ip_universe_id
					USING ERRCODE= 'unique_violation';
			END IF;
		END IF;
	END IF;

	/*
	 * Parent validation is performed in the deferred after trigger
	 */

	 RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_property');
CREATE OR REPLACE FUNCTION jazzhands.validate_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
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
	v_property_collection		property_collection%ROWTYPE;
	v_service_env_collection	service_environment_collection%ROWTYPE;
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
				'Property name or type does not exist'
				USING ERRCODE = 'foreign_key_violation';
			RETURN NULL;
	END;

	-- Check to see if the property itself is multivalue.  That is, if only
	-- one value can be set for this property for a specific property LHS
	IF (v_prop.is_multivalue = 'N') THEN
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
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code
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
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code AND
			property_value IS NOT DISTINCT FROM NEW.property_value AND
			property_value_timestamp IS NOT DISTINCT FROM
				NEW.property_value_timestamp AND
			property_value_company_id IS NOT DISTINCT FROM
				NEW.property_value_company_id AND
			property_value_account_coll_id IS NOT DISTINCT FROM
				NEW.property_value_account_coll_id AND
			property_value_device_coll_id IS NOT DISTINCT FROM
				NEW.property_value_device_coll_id AND
			property_value_nblk_coll_id IS NOT DISTINCT FROM
				NEW.property_value_nblk_coll_id AND
			property_value_password_type IS NOT DISTINCT FROM
				NEW.property_value_password_type AND
			property_value_person_id IS NOT DISTINCT FROM
				NEW.property_value_person_id AND
			property_value_sw_package_id IS NOT DISTINCT FROM
				NEW.property_value_sw_package_id AND
			property_value_token_col_id IS NOT DISTINCT FROM
				NEW.property_value_token_col_id AND
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

	-- Check to see if the property type is multivalue.  That is, if only
	-- one property and value can be set for any properties with this type
	-- for a specific property LHS

	IF (v_proptype.is_multivalue = 'N') THEN
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
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code
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
	IF NEW.Property_Value_Company_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'company_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Company_Id' USING
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
	IF NEW.Property_Value_Token_Col_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'token_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Token_Collection_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_SW_Package_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'sw_package_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be SW_Package_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Account_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'account_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be account_collection_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_nblk_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'netblock_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be nblk_collection_id' USING
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
	IF NEW.Property_Value_Person_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'person_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Person_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Device_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'device_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Device_Collection_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	-- at this point, tally will be set to 1 if one of the other property
	-- values is set to something valid.  Now, check the various options for
	-- PROPERTY_VALUE itself.  If a new type is added to the val table, this
	-- trigger needs to be updated or it will be considered invalid.  If a
	-- new PROPERTY_VALUE_* column is added, then it will pass through without
	-- trigger modification.  This should be considered bad.

	IF NEW.Property_Value IS NOT NULL THEN
		tally := tally + 1;
		IF v_prop.Property_Data_Type = 'boolean' THEN
			IF NEW.Property_Value != 'Y' AND NEW.Property_Value != 'N' THEN
				RAISE 'Boolean Property_Value must be Y or N' USING
					ERRCODE = 'invalid_parameter_value';
			END IF;
		ELSIF v_prop.Property_Data_Type = 'number' THEN
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
		ELSIF v_prop.Property_Data_Type != 'string' THEN
			RAISE 'Property_Data_Type is not a known type' USING
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

	-- If the LHS contains a property_collection_ID, check to see if it must be a
	-- specific type (e.g. per-property), and verify that if so
	IF NEW.property_collection_id IS NOT NULL THEN
		IF v_prop.property_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_property_collection
					FROM property_collection WHERE
					property_collection_Id = NEW.property_collection_id;
				IF v_property_collection.property_collection_Type != v_prop.property_collection_type
				THEN
					RAISE 'property_collection_id must be of type %',
					v_prop.property_collection_type
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a service_env_collection_ID, check to see if it must be a
	-- specific type (e.g. per-service_env), and verify that if so
	IF NEW.service_env_collection_id IS NOT NULL THEN
		IF v_prop.service_env_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_service_env_collection
					FROM service_env_collection WHERE
					service_env_collection_Id = NEW.service_env_collection_id;
				IF v_service_env_collection.service_env_collection_Type != v_prop.service_env_collection_type
				THEN
					RAISE 'service_env_collection_id must be of type %',
					v_prop.service_env_collection_type
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
	IF NEW.Property_Value_Account_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection
					FROM account_collection WHERE
					account_collection_Id = NEW.Property_Value_Account_Coll_Id;
				IF v_account_collection.account_collection_Type != v_prop.prop_val_acct_coll_type_rstrct
				THEN
					RAISE 'Property_Value_Account_Coll_Id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
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
	IF NEW.Property_Value_nblk_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_netblock_collection
					FROM netblock_collection WHERE
					netblock_collection_Id = NEW.Property_Value_nblk_Coll_Id;
				IF v_netblock_collection.netblock_collection_Type != v_prop.prop_val_acct_coll_type_rstrct
				THEN
					RAISE 'Property_Value_nblk_Coll_Id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
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
	IF NEW.Property_Value_Device_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_dev_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_device_collection
					FROM device_collection WHERE
					device_collection_id = NEW.Property_Value_Device_Coll_Id;
				IF v_device_collection.device_collection_type !=
					v_prop.prop_val_dev_coll_type_rstrct
				THEN
					RAISE 'Property_Value_Device_Coll_Id must be of type %',
					v_prop.prop_val_dev_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- At this point, the RHS has been checked, so now we verify data
	-- set on the LHS

	-- There needs to be a stanza here for every "lhs".  If a new column is
	-- added to the property table, a new stanza needs to be added here,
	-- otherwise it will not be validated.  This should be considered bad.

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

	IF v_prop.permit_service_env_collection = 'REQUIRED' THEN
			IF NEW.service_env_collection_id IS NULL THEN
				RAISE 'service_env_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_service_env_collection = 'PROHIBITED' THEN
			IF NEW.service_env_collection_id IS NOT NULL THEN
				RAISE 'service_environment is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
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

	IF v_prop.permit_os_snapshot_id = 'REQUIRED' THEN
			IF NEW.operating_system_snapshot_id IS NULL THEN
				RAISE 'operating_system_snapshot_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_os_snapshot_id = 'PROHIBITED' THEN
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

	IF v_prop.permit_layer2_network_coll_id = 'REQUIRED' THEN
			IF NEW.layer2_network_collection_id IS NULL THEN
				RAISE 'layer2_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer2_network_coll_id = 'PROHIBITED' THEN
			IF NEW.layer2_network_collection_id IS NOT NULL THEN
				RAISE 'layer2_network_collection_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_layer3_network_coll_id = 'REQUIRED' THEN
			IF NEW.layer3_network_collection_id IS NULL THEN
				RAISE 'layer3_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer3_network_coll_id = 'PROHIBITED' THEN
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

	IF v_prop.Permit_property_collection_Id = 'REQUIRED' THEN
			IF NEW.property_collection_Id IS NULL THEN
				RAISE 'property_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_property_collection_Id = 'PROHIBITED' THEN
			IF NEW.property_collection_Id IS NOT NULL THEN
				RAISE 'property_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Person_Id = 'REQUIRED' THEN
			IF NEW.Person_Id IS NULL THEN
				RAISE 'Person_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Person_Id = 'PROHIBITED' THEN
			IF NEW.Person_Id IS NOT NULL THEN
				RAISE 'Person_Id is prohibited.'
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

-- New function
CREATE OR REPLACE FUNCTION jazzhands.account_status_after_hooks()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	BEGIN
		PERFORM local_hooks.account_status_after_hooks();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
	RETURN NULL;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_ip_universe_trigger_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF NEW.should_generate = 'Y' THEN
		insert into DNS_CHANGE_RECORD
			(dns_domain_id) VALUES (NEW.dns_domain_id);
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_nouniverse_del()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	DELETE FROM dns_domain_ip_universe
	WHERE ip_universe_id = 0
	AND dns_domain_id = NEW.dns_domain_id;

	DELETE FROM dns_domain
	WHERE ip_universe_id = 0
	AND dns_domain_id = NEW.dns_domain_id;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_nouniverse_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_d	dns_domain.dns_domain_id%TYPE;
BEGIN
	IF NEW.dns_domain_id IS NULL THEN
		INSERT INTO dns_domain (
			dns_domain_name, dns_domain_type, parent_dns_domain_id
		) VALUES (
			NEW.soa_name, NEW.dns_domain_type, NEW.parent_dns_domain_id
		) RETURNING dns_domain_id INTO _d;
	ELSE
		INSERT INTO dns_domain (
			dns_domain_id, dns_domain_name, dns_domain_type,
			parent_dns_domain_id
		) VALUES (
			NEW.dns_domain_id, NEW.soa_name, NEW.dns_domain_type,
			NEW.parent_dns_domain_id
		) RETURNING dns_domain_id INTO _d;
	END IF;

	INSERT INTO dns_domain_ip_universe (
		dns_domain_id, ip_universe_id,
		soa_class, soa_ttl, soa_serial, soa_refresh,
		soa_retry,
		soa_expire, soa_minimum, soa_mname, soa_rname,
		should_generate, last_generated
	) VALUES (
		_d, 0,
		NEW.soa_class, NEW.soa_ttl, NEW.soa_serial, NEW.soa_refresh,
		NEW.soa_retry,
		NEW.soa_expire, NEW.soa_minimum, NEW.soa_mname, NEW.soa_rname,
		NEW.should_generate, NEW.last_generated
	);
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_nouniverse_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	upd_query	TEXT[];
BEGIN
	IF OLD.dns_domain_id IS DISTINCT FROM NEW.dns_domain_id THEN
		RAISE EXCEPTION 'dns_domain_id can not be updated';
	END IF;

	upd_query := NULL;
	IF OLD.soa_name IS DISTINCT FROM NEW.soa_name THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.soa_name));
	END IF;
	IF OLD.parent_dns_domain_id IS DISTINCT FROM NEW.parent_dns_domain_id THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.parent_dns_domain_id));
	END IF;
	IF OLD.dns_domain_type IS DISTINCT FROM NEW.dns_domain_type THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.dns_domain_type));
	END IF;
	IF upd_query IS NOT NULL THEN
		EXECUTE 'UPDATE dns_domain SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE dns_domain_id = $1'
		USING
			NEW.dns_domain_id;
	END IF;

	upd_query := NULL;
	IF OLD.soa_class IS DISTINCT FROM NEW.soa_class THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.soa_class));
	END IF;

	upd_query := NULL;
	IF OLD.soa_ttl IS DISTINCT FROM NEW.soa_ttl THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.soa_ttl));
	END IF;

	upd_query := NULL;
	IF OLD.soa_serial IS DISTINCT FROM NEW.soa_serial THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.soa_serial));
	END IF;

	upd_query := NULL;
	IF OLD.soa_refresh IS DISTINCT FROM NEW.soa_refresh THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.soa_refresh));
	END IF;

	upd_query := NULL;
	IF OLD.soa_retry IS DISTINCT FROM NEW.soa_retry THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.soa_retry));
	END IF;

	upd_query := NULL;
	IF OLD.soa_expire IS DISTINCT FROM NEW.soa_expire THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.soa_expire));
	END IF;

	upd_query := NULL;
	IF OLD.soa_minimum IS DISTINCT FROM NEW.soa_minimum THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.soa_minimum));
	END IF;

	upd_query := NULL;
	IF OLD.soa_mname IS DISTINCT FROM NEW.soa_mname THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.soa_mname));
	END IF;

	upd_query := NULL;
	IF OLD.soa_rname IS DISTINCT FROM NEW.soa_rname THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.soa_rname));
	END IF;

	upd_query := NULL;
	IF OLD.should_generate IS DISTINCT FROM NEW.should_generate THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.should_generate));
	END IF;

	upd_query := NULL;
	IF OLD.last_generated IS DISTINCT FROM NEW.last_generated THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.last_generated));
	END IF;


	IF upd_query IS NOT NULL THEN
		EXECUTE 'UPDATE dns_domain_ip_universe SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE ip_universe_id = 0 AND dns_domain_id = $1'
		USING
			NEW.dns_domain_id;
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_soa_name_retire()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.dns_domain_name IS NOT NULL and NEW.soa_name IS NOT NULL THEN
			RAISE EXCEPTION 'Must only set dns_domain_name, not soa_name'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF NEW.soa_name IS NULL THEN
			NEW.soa_name = NEW.dns_domain_name;
		ELSIF NEW.dns_domain_name IS NULL THEN
			NEW.dns_domain_name = NEW.soa_name;
		ELSE
			RAISE EXCEPTION 'DNS DOMAIN NAME insert checker failed';
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.dns_domain_name IS DISTINCT FROM NEW.dns_domain_name AND
			OLD.soa_name IS DISTINCT FROM NEW.soa_name
		THEN
			RAISE EXCEPTION 'Must only change dns_domain_name, not soa_name'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF OLD.dns_domain_name IS DISTINCT FROM NEW.dns_domain_name THEN
			NEW.soa_name = NEW.dns_domain_name;
		ELSIF OLD.soa_name IS DISTINCT FROM NEW.soa_name THEN
			NEW.dns_domain_name = NEW.soa_name;
		END IF;
	END IF;

	-- RAISE EXCEPTION 'Need to write this trigger.';
	RETURN NEW;
END;
$function$
;

--
-- Process drops in net_manip
--
--
-- Process drops in network_strings
--
--
-- Process drops in time_util
--
--
-- Process drops in dns_utils
--
DROP FUNCTION IF EXISTS dns_utils.add_dns_domain ( soa_name character varying, dns_domain_type character varying, add_nameservers boolean );
-- New function
CREATE OR REPLACE FUNCTION dns_utils.add_dns_domain(soa_name character varying, dns_domain_type character varying DEFAULT NULL::character varying, ip_universes integer[] DEFAULT NULL::integer[], add_nameservers boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	elements		text[];
	parent_zone		text;
	parent_id		dns_domain.dns_domain_id%type;
	domain_id		dns_domain.dns_domain_id%type;
	elem			text;
	sofar			text;
	rvs_nblk_id		netblock.netblock_id%type;
	univ			ip_universe.ip_universe_id%type;
BEGIN
	IF soa_name IS NULL THEN
		RETURN NULL;
	END IF;
	elements := regexp_split_to_array(soa_name, '\.');
	sofar := '';
	FOREACH elem in ARRAY elements
	LOOP
		IF octet_length(sofar) > 0 THEN
			sofar := sofar || '.';
		END IF;
		sofar := sofar || elem;
		parent_zone := regexp_replace(soa_name, '^'||sofar||'.', '');
		EXECUTE 'SELECT dns_domain_id FROM dns_domain 
			WHERE soa_name = $1' INTO parent_id USING soa_name;
		IF parent_id IS NOT NULL THEN
			EXIT;
		END IF;
	END LOOP;

	IF ip_universes IS NULL THEN
		SELECT array_agg(ip_universe_id) 
		INTO	ip_universes
		FROM	ip_universe
		WHERE	ip_universe_name = 'default';
	END IF;

	IF dns_domain_type IS NULL THEN
		IF soa_name ~ '^.*(in-addr|ip6)\.arpa$' THEN
			dns_domain_type := 'reverse';
		END IF;
	END IF;

	IF dns_domain_type IS NULL THEN
		RAISE EXCEPTION 'Unable to guess dns_domain_type for %',
			soa_name USING ERRCODE = 'not_null_violation'; 
	END IF;

	EXECUTE '
		INSERT INTO dns_domain (
			soa_name,
			parent_dns_domain_id,
			dns_domain_type
		) VALUES (
			$1,
			$2,
			$3
		) RETURNING dns_domain_id' INTO domain_id 
		USING soa_name, 
			parent_id,
			dns_domain_type
	;

	FOREACH univ IN ARRAY ip_universes
	LOOP
		EXECUTE '
			INSERT INTO dns_domain_ip_universe (
				dns_domain_id,
				ip_universe_id,
				soa_class,
				soa_mname,
				soa_rname,
				should_generate
			) VALUES (
				$1,
				$2,
				$3,
				$4,
				$5,
				$6
			);'
			USING domain_id, univ,
				'IN',
				(select property_value from property 
					where property_type = 'Defaults'
					and property_name = '_dnsmname' ORDER BY property_id LIMIT 1),
				(select property_value from property 
					where property_type = 'Defaults'
					and property_name = '_dnsrname' ORDER BY property_id LIMIT 1),
				'Y'
		;
	END LOOP;

	IF dns_domain_type = 'reverse' THEN
		rvs_nblk_id := dns_utils.get_or_create_rvs_netblock_link(
			soa_name, domain_id);
	END IF;

	IF add_nameservers THEN
		PERFORM dns_utils.add_ns_records(domain_id);
	END IF;

	RETURN domain_id;
END;
$function$
;

--
-- Process drops in person_manip
--
--
-- Process drops in auto_ac_manip
--
--
-- Process drops in company_manip
--
--
-- Process drops in token_utils
--
--
-- Process drops in port_support
--
--
-- Process drops in port_utils
--
--
-- Process drops in device_utils
--
DROP FUNCTION IF EXISTS device_utils.monitoring_off_in_rack ( _in_rack_id integer );
-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'purge_l1_connection_from_port');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.purge_l1_connection_from_port ( _in_portid integer );
CREATE OR REPLACE FUNCTION device_utils.purge_l1_connection_from_port(_in_portid integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'purge_physical_path');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.purge_physical_path ( _in_l1c integer );
CREATE OR REPLACE FUNCTION device_utils.purge_physical_path(_in_l1c integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'purge_physical_ports');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.purge_physical_ports ( _in_devid integer );
CREATE OR REPLACE FUNCTION device_utils.purge_physical_ports(_in_devid integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'retire_device');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.retire_device ( in_device_id integer, retire_modules boolean );
CREATE OR REPLACE FUNCTION device_utils.retire_device(in_device_id integer, retire_modules boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

DROP FUNCTION IF EXISTS device_utils.retire_rack ( _in_rack_id integer );
-- New function
CREATE OR REPLACE FUNCTION device_utils.monitoring_off_in_rack(rack_id integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION device_utils.remove_network_interface(network_interface_id integer DEFAULT NULL::integer, device_id integer DEFAULT NULL::integer, network_interface_name character varying DEFAULT NULL::character varying)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION device_utils.remove_network_interfaces(network_interface_id_list integer[])
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION device_utils.retire_devices(device_id_list integer[])
 RETURNS TABLE(device_id integer, success boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
					voe_symbolic_track_id = NULL,
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION device_utils.retire_rack(rack_id integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM device_utils.retire_racks(
		rack_id_list := ARRAY[ rack_id ]
	);
	RETURN true;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION device_utils.retire_racks(rack_id_list integer[])
 RETURNS TABLE(rack_id integer, success boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

--
-- Process drops in netblock_utils
--
--
-- Process drops in netblock_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock ( parent_netblock_id integer, netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying );
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS SETOF netblock
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	netblock_rec	RECORD;
BEGIN
	RETURN QUERY
		SELECT * into netblock_rec FROM netblock_manip.allocate_netblock(
		parent_netblock_list := ARRAY[parent_netblock_id],
		netmask_bits := netmask_bits,
		address_type := address_type,
		can_subnet := can_subnet,
		description := description,
		allocation_method := allocation_method,
		ip_address := ip_address,
		rnd_masklen_threshold := rnd_masklen_threshold,
		rnd_max_count := rnd_max_count,
		netblock_status := netblock_status
	);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock ( parent_netblock_list integer[], netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying );
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS SETOF netblock
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	parent_rec		RECORD;
	netblock_rec	RECORD;
	inet_rec		RECORD;
	loopback_bits	integer;
	inet_family		integer;
	ip_addr			ALIAS FOR ip_address;
BEGIN
	IF parent_netblock_list IS NULL THEN
		RAISE 'parent_netblock_list must be specified'
		USING ERRCODE = 'null_value_not_allowed';
	END IF;

	IF address_type NOT IN ('netblock', 'single', 'loopback') THEN
		RAISE 'address_type must be one of netblock, single, or loopback'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF netmask_bits IS NULL AND address_type = 'netblock' THEN
		RAISE EXCEPTION
			'You must specify a netmask when address_type is netblock'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF ip_address IS NOT NULL THEN
		SELECT
			array_agg(netblock_id)
		INTO
			parent_netblock_list
		FROM
			netblock n
		WHERE
			ip_addr <<= n.ip_address AND
			netblock_id = ANY(parent_netblock_list);

		IF parent_netblock_list IS NULL THEN
			RETURN;
		END IF;
	END IF;

	-- Lock the parent row, which should keep parallel processes from
	-- trying to obtain the same address

	FOR parent_rec IN SELECT * FROM jazzhands.netblock WHERE netblock_id =
			ANY(allocate_netblock.parent_netblock_list) ORDER BY netblock_id
			FOR UPDATE LOOP

		IF parent_rec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'parent_netblock_id refers to a single_address netblock'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF inet_family IS NULL THEN
			inet_family := family(parent_rec.ip_address);
		ELSIF inet_family != family(parent_rec.ip_address)
				AND ip_address IS NULL THEN
			RAISE EXCEPTION 'Allocation may not mix IPv4 and IPv6 addresses'
			USING ERRCODE = 'JH10F';
		END IF;

		IF address_type = 'loopback' THEN
			loopback_bits :=
				CASE WHEN
					family(parent_rec.ip_address) = 4 THEN 32 ELSE 128 END;

			IF parent_rec.can_subnet = 'N' THEN
				RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
					USING ERRCODE = 'JH10B';
			END IF;
		ELSIF address_type = 'single' THEN
			IF parent_rec.can_subnet = 'Y' THEN
				RAISE EXCEPTION
					'parent subnet for single address must have can_subnet set to N'
					USING ERRCODE = 'JH10B';
			END IF;
		ELSIF address_type = 'netblock' THEN
			IF parent_rec.can_subnet = 'N' THEN
				RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
					USING ERRCODE = 'JH10B';
			END IF;
		END IF;
	END LOOP;

 	IF NOT FOUND THEN
 		RETURN;
 	END IF;

	IF address_type = 'loopback' THEN
		-- If we're allocating a loopback address, then we need to create
		-- a new parent to hold the single loopback address

		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := loopback_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN;
		END IF;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'N',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO parent_rec;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			parent_rec.netblock_type,
			'Y',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN NEXT netblock_rec;
		RETURN;
	END IF;

	IF address_type = 'single' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			single_address := true,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			rnd_masklen_threshold := rnd_masklen_threshold,
			rnd_max_count := rnd_max_count,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN;
		END IF;

		RAISE DEBUG 'ip_address is %', inet_rec.ip_address;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'Y',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		RETURN NEXT netblock_rec;
		RETURN;
	END IF;
	IF address_type = 'netblock' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := netmask_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1);

		IF NOT FOUND THEN
			RETURN;
		END IF;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'N',
			CASE WHEN can_subnet THEN 'Y' ELSE 'N' END,
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		RAISE DEBUG 'Allocated netblock_id % for %',
			netblock_rec.netblock_id,
			netblock_rec.ip_address;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN NEXT netblock_rec;
		RETURN;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'create_network_range');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.create_network_range ( start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer, description character varying, allow_assigned boolean );
CREATE OR REPLACE FUNCTION netblock_manip.create_network_range(start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer DEFAULT NULL::integer, description character varying DEFAULT NULL::character varying, allow_assigned boolean DEFAULT false)
 RETURNS network_range
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	par_netblock	RECORD;
	start_netblock	RECORD;
	stop_netblock	RECORD;
	netrange		RECORD;
	nrtype			ALIAS FOR network_range_type;
	pnbid			ALIAS FOR parent_netblock_id;
BEGIN
	--
	-- If the network range already exists, then just return it
	--
	SELECT
		nr.* INTO netrange
	FROM
		jazzhands.network_range nr JOIN
		jazzhands.netblock startnb ON (nr.start_netblock_id =
			startnb.netblock_id) JOIN
		jazzhands.netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND
		host(startnb.ip_address) = host(start_ip_address) AND
		host(stopnb.ip_address) = host(stop_ip_address) AND
		CASE WHEN pnbid IS NOT NULL THEN
			(pnbid = nr.parent_netblock_id)
		ELSE
			true
		END;

	IF FOUND THEN
		RETURN netrange;
	END IF;

	--
	-- If any other network ranges exist that overlap this, then error
	--
	PERFORM
		*
	FROM
		jazzhands.network_range nr JOIN
		jazzhands.netblock startnb ON
			(nr.start_netblock_id = startnb.netblock_id) JOIN
		jazzhands.netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND ((
			host(startnb.ip_address)::inet <= host(start_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(start_ip_address)::inet
		) OR (
			host(startnb.ip_address)::inet <= host(stop_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(stop_ip_address)::inet
		));

	IF FOUND THEN
		RAISE 'create_network_range: a network_range of type % already exists that has addresses between % and %',
			nrtype, start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	IF parent_netblock_id IS NOT NULL THEN
		SELECT * INTO par_netblock FROM jazzhands.netblock WHERE
			netblock_id = pnbid;
		IF NOT FOUND THEN
			RAISE 'create_network_range: parent_netblock_id % does not exist',
				parent_netblock_id USING ERRCODE = 'foreign_key_violation';
		END IF;
	ELSE
		SELECT * INTO par_netblock FROM jazzhands.netblock WHERE netblock_id = (
			SELECT
				*
			FROM
				netblock_utils.find_best_parent_id(
					in_ipaddress := start_ip_address,
					in_is_single_address := 'Y'
				)
		);

		IF NOT FOUND THEN
			RAISE 'create_network_range: valid parent netblock for start_ip_address % does not exist',
				start_ip_address USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	IF par_netblock.can_subnet != 'N' OR
			par_netblock.is_single_address != 'N' THEN
		RAISE 'create_network_range: parent netblock % must not be subnettable or a single address',
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not contained by parent netblock % (%)',
			start_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (stop_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: stop_ip_address % is not contained by parent netblock % (%)',
			stop_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <= stop_ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not lower than stop_ip_address %',
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	--
	-- Validate that there are not currently any addresses assigned in the
	-- range, unless allow_assigned is set
	--
	IF NOT allow_assigned THEN
		PERFORM
			*
		FROM
			jazzhands.netblock n
		WHERE
			n.parent_netblock_id = par_netblock.netblock_id AND
			host(n.ip_address)::inet > host(start_ip_address)::inet AND
			host(n.ip_address)::inet < host(stop_ip_address)::inet;

		IF FOUND THEN
			RAISE 'create_network_range: netblocks are already present for parent netblock % betweeen % and %',
			par_netblock.netblock_id,
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	--
	-- Ok, well, we should be able to insert things now
	--

	SELECT
		*
	FROM
		jazzhands.netblock n
	INTO
		start_netblock
	WHERE
		host(n.ip_address)::inet = start_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(start_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO start_netblock;
	END IF;

	SELECT
		*
	FROM
		jazzhands.netblock n
	INTO
		stop_netblock
	WHERE
		host(n.ip_address)::inet = stop_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(stop_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO stop_netblock;
	END IF;

	INSERT INTO network_range (
		network_range_type,
		description,
		parent_netblock_id,
		start_netblock_id,
		stop_netblock_id
	) VALUES (
		nrtype,
		description,
		par_netblock.netblock_id,
		start_netblock.netblock_id,
		stop_netblock.netblock_id
	) RETURNING * INTO netrange;

	RETURN netrange;

	RETURN NULL;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'delete_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.delete_netblock ( in_netblock_id integer );
CREATE OR REPLACE FUNCTION netblock_manip.delete_netblock(in_netblock_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	/*
	 * Update netblocks that use this as a parent to point to my parent
	 */
	SELECT
		netblock_id INTO par_nbid
	FROM
		jazzhands.netblock
	WHERE
		netblock_id = in_netblock_id;

	UPDATE
		jazzhands.netblock
	SET
		parent_netblock_id = par_nbid
	WHERE
		parent_netblock_id = in_netblock_id;

	/*
	 * Now delete the record
	 */
	DELETE FROM jazzhands.netblock WHERE netblock_id = in_netblock_id;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'recalculate_parentage');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.recalculate_parentage ( in_netblock_id integer );
CREATE OR REPLACE FUNCTION netblock_manip.recalculate_parentage(in_netblock_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	nbrec		RECORD;
	childrec	RECORD;
	nbid		jazzhands.netblock.netblock_id%type;
	ipaddr		inet;

BEGIN
	SELECT * INTO nbrec FROM jazzhands.netblock WHERE
		netblock_id = in_netblock_id;

	nbid := netblock_utils.find_best_parent_id(in_netblock_id);

	UPDATE jazzhands.netblock SET parent_netblock_id = nbid
		WHERE netblock_id = in_netblock_id;

	FOR childrec IN SELECT * FROM jazzhands.netblock WHERE
		parent_netblock_id = nbid
		AND netblock_id != in_netblock_id
	LOOP
		IF (childrec.ip_address <<= nbrec.ip_address) THEN
			UPDATE jazzhands.netblock SET parent_netblock_id = in_netblock_id
				WHERE netblock_id = childrec.netblock_id;
		END IF;
	END LOOP;
	RETURN nbid;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION netblock_manip.set_interface_addresses(network_interface_id integer DEFAULT NULL::integer, device_id integer DEFAULT NULL::integer, network_interface_name text DEFAULT NULL::text, network_interface_type text DEFAULT 'broadcast'::text, ip_address_hash jsonb DEFAULT NULL::jsonb, create_layer3_networks boolean DEFAULT false, move_addresses text DEFAULT 'if_same_device'::text, address_errors text DEFAULT 'error'::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
--
-- ip_address_hash consists of the following elements
--
--		"ip_addresses" : [ (inet | netblock) ... ]
--		"shared_ip_addresses" : [ (inet | netblock) ... ]
--
-- where inet is a text string that can be legally converted to type inet
-- and netblock is a JSON object with fields:
--		"ip_address" : inet
--		"ip_universe_id" : integer (default 0)
--		"netblock_type" : text (default 'default')
--		"protocol" : text (default 'VRRP')
--
-- If either "ip_addresses" or "shared_ip_addresses" does not exist, it
-- will not be processed.  If the key is present and is an empty array or
-- null, then all IP addresses of those types will be removed from the
-- interface
--
-- 'protocol' is only valid for shared addresses, which is how the address
-- is shared.  Valid values can be found in the val_shared_netblock_protocol
-- table
--
DECLARE
	ni_id			ALIAS FOR network_interface_id;
	dev_id			ALIAS FOR device_id;
	ni_name			ALIAS FOR network_interface_name;
	ni_type			ALIAS FOR network_interface_type;

	addrs_ary		jsonb;
	ipaddr			inet;
	universe		integer;
	nb_type			text;
	protocol		text;

	c				integer;
	i				integer;

	nb_rec			RECORD;
	pnb_rec			RECORD;
	layer3_rec		RECORD;
	sn_rec			RECORD;
	ni_rec			RECORD;
	nin_rec			RECORD;
	nb_id			jazzhands.netblock.netblock_id%TYPE;
	nb_id_ary		integer[];
	ni_id_ary		integer[];
	del_list		integer[];
BEGIN
	--
	-- Validate that we got enough information passed to do things
	--

	IF ip_address_hash IS NULL OR NOT
		(jsonb_typeof(ip_address_hash) = 'object')
	THEN
		RAISE 'Must pass ip_addresses to netblock_manip.set_interface_addresses';
	END IF;

	IF network_interface_id IS NULL THEN
		IF device_id IS NULL OR network_interface_name IS NULL THEN
			RAISE 'netblock_manip.assign_shared_netblock: must pass either network_interface_id or device_id and network_interface_name'
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
			INSERT INTO network_interface(
				device_id,
				network_interface_name,
				network_interface_type,
				should_monitor
			) VALUES (
				dev_id,
				ni_name,
				ni_type,
				'N'
			) RETURNING network_interface.network_interface_id INTO ni_id;
		END IF;
	END IF;

	SELECT * INTO ni_rec FROM network_interface ni WHERE 
		ni.network_interface_id = ni_id;

	--
	-- First, loop through ip_addresses passed and process those
	--

	IF ip_address_hash ? 'ip_addresses' AND
		jsonb_typeof(ip_address_hash->'ip_addresses') = 'array'
	THEN
		RAISE DEBUG 'Processing ip_addresses...';
		--
		-- Loop through each member of the ip_addresses array
		-- and process each address
		--
		addrs_ary := ip_address_hash->'ip_addresses';
		c := jsonb_array_length(addrs_ary);
		i := 0;
		nb_id_ary := NULL;
		WHILE (i < c) LOOP
			IF jsonb_typeof(addrs_ary->i) = 'string' THEN
				--
				-- If this is a string, use it as an inet with default
				-- universe and netblock_type
				--
				ipaddr := addrs_ary->>i;
				universe := 0;
				nb_type := 'default';
			ELSIF jsonb_typeof(addrs_ary->i) = 'object' THEN
				--
				-- If this is an object, require 'ip_address' key
				-- optionally use 'ip_universe_id' and 'netblock_type' keys
				-- to override the defaults
				--
				IF NOT addrs_ary->i ? 'ip_address' THEN
					RAISE E'Object in array element % of ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses does not contain ip_address key:\n%',
						i, jsonb_pretty(addrs_ary->i);
				END IF;
				ipaddr := addrs_ary->i->>'ip_address';

				IF addrs_ary->i ? 'ip_universe_id' THEN
					universe := addrs_ary->i->'ip_universe_id';
				ELSE
					universe := 0;
				END IF;

				IF addrs_ary->i ? 'netblock_type' THEN
					nb_type := addrs_ary->i->>'netblock_type';
				ELSE
					nb_type := 'default';
				END IF;
			ELSE
				RAISE 'Invalid type in array element % of ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses (%)',
					i, jsonb_typeof(addrs_ary->i);
			END IF;
			--
			-- We're done with the array, so increment the counter so
			-- we don't have to deal with it later
			--
			i := i + 1;

			RAISE DEBUG 'Address is %, universe is %, nb type is %',
				ipaddr, universe, nb_type;

			--
			-- This is a hack, because Juniper is really annoying about this.
			-- If masklen < 8, then ignore this netblock (we specifically
			-- want /8, because of 127/8 and 10/8, which someone could
			-- maybe want to not subnet.
			--
			-- This should probably be a configuration parameter, but it's not.
			--
			CONTINUE WHEN masklen(ipaddr) < 8;

			--
			-- Check to see if this is a netblock that we have been
			-- told to explicitly ignore
			--
			PERFORM
				ip_address
			FROM
				netblock n JOIN
				netblock_collection_netblock ncn USING (netblock_id) JOIN
				v_netblock_coll_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_nblk_coll_id =
						nce.root_netblock_collection_id
				)
			WHERE
				ipaddr <<= n.ip_address AND
				n.ip_universe_id = universe AND
				n.netblock_type = nb_type;

			--
			-- If we found this netblock in the ignore list, then just
			-- skip it
			--
			IF FOUND THEN
				RAISE DEBUG 'Skipping ignored address %', ipaddr;
				CONTINUE;
			END IF;

			--
			-- Look for an is_single_address='Y', can_subnet='N' netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = 'Y' AND
				can_subnet = 'N' AND
				netblock_type = nb_type AND
				ip_universe_id = universe AND
				host(ip_address) = host(ipaddr);

			IF FOUND THEN
				RAISE DEBUG E'Located netblock:\n%',
					jsonb_pretty(to_jsonb(nb_rec));

				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);

				--
				-- Look to see if there's a layer3_network for the
				-- parent netblock
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.netblock_id = nb_rec.parent_netblock_id;

				IF FOUND THEN
					RAISE DEBUG E'Located layer3_network:\n%',
						jsonb_pretty(to_jsonb(layer3_rec));
				ELSE
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
			ELSE
				--
				-- If the parent netblock does not exist, then create it
				-- if we were passed the option to
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.ip_universe_id = universe AND
					n.netblock_type = nb_type AND
					is_single_address = 'N' AND
					can_subnet = 'N' AND
					n.ip_address >>= ipaddr;

				IF NOT FOUND THEN
					RAISE DEBUG 'Parent netblock with ip_address %, netblock_type %, ip_universe_id % not found',
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					--
					-- Check to see if the netblock exists, but is
					-- marked can_subnet='Y'.  If so, fix it
					--
					SELECT 
						* INTO pnb_rec
					FROM
						netblock n
					WHERE
						n.ip_universe_id = universe AND
						n.netblock_type = nb_type AND
						n.is_single_address = 'N' AND
						n.can_subnet = 'Y' AND
						n.ip_address = network(ipaddr);

					IF FOUND THEN
						UPDATE netblock n SET
							can_subnet = 'N'
						WHERE
							n.netblock_id = pnb_rec.netblock_id;
						pnb_rec.can_subnet = 'N';
					ELSE
						INSERT INTO netblock (
							ip_address,
							netblock_type,
							is_single_address,
							can_subnet,
							ip_universe_id,
							netblock_status
						) VALUES (
							network(ipaddr),
							nb_type,
							'N',
							'N',
							universe,
							'Allocated'
						) RETURNING * INTO pnb_rec;
					END IF;

					WITH l3_ins AS (
						INSERT INTO layer3_network(
							netblock_id
						) VALUES (
							pnb_rec.netblock_id
						) RETURNING *
					)
					SELECT
						pnb_rec.netblock_id,
						pnb_rec.ip_address,
						l3_ins.layer3_network_id,
						NULL::inet
					INTO layer3_rec
					FROM
						l3_ins;
				ELSIF layer3_rec.layer3_network_id IS NULL THEN
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--

					RAISE DEBUG 'layer3_network for parent netblock % not found (ip_address %, netblock_type %, ip_universe_id %)',
						layer3_rec.netblock_id,
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
				RAISE DEBUG E'Located layer3_network:\n%',
					jsonb_pretty(to_jsonb(layer3_rec));
				--
				-- Parents should be all set up now.  Insert the netblock
				--
				INSERT INTO netblock (
					ip_address,
					netblock_type,
					ip_universe_id,
					is_single_address,
					can_subnet,
					netblock_status
				) VALUES (
					ipaddr,
					nb_type,
					universe,
					'Y',
					'N',
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;
			--
			-- Now that we have the netblock and everything, check to see
			-- if this netblock is already assigned to this network_interface
			--
			PERFORM * FROM
				network_interface_netblock nin
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id = ni_id;

			IF FOUND THEN
				RAISE DEBUG 'Netblock % already found on network_interface',
					nb_rec.netblock_id;
				CONTINUE;
			END IF;

			--
			-- See if this netblock is on something else, and delete it
			-- if move_addresses is set, otherwise skip it
			--
			SELECT 
				ni.network_interface_id,
				nin.netblock_id,
				ni.device_id
			INTO nin_rec
			FROM
				network_interface_netblock nin JOIN
				network_interface ni USING (network_interface_id)
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id != ni_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND 
					nin_rec.device_id = ni_rec.device_id
				)
				THEN
					DELETE FROM
						network_interface_netblock
					WHERE
						netblock_id = nb_rec.netblock_id;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSE
						RAISE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;
					END IF;
				END IF;
			END IF;

			--
			-- See if this netblock is on a shared_address somewhere, and
			-- move it only if move_addresses is 'always'
			--
			SELECT * FROM
				shared_netblock sn
			INTO sn_rec
			WHERE
				sn.netblock_id = nb_rec.netblock_id;

			IF FOUND THEN
				IF move_addresses IS NULL OR move_addresses != 'always' THEN
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, sn.shared_netblock_id;
						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, sn.shared_netblock_id;
						CONTINUE;
					ELSE
						RAISE 'Netblock % is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, sn.shared_netblock_id;
						CONTINUE;
					END IF;
				END IF;

				DELETE FROM
					shared_netblock_network_int snni
				WHERE
					snni.shared_netblock_id = sn_rec.shared_netblock_id;

				DELETE FROM
					shared_network sn
				WHERE
					sn.netblock_id = sn_rec.shared_netblock_id;
			END IF;

			--
			-- Insert the netblock onto the interface using the next
			-- rank
			--
			INSERT INTO network_interface_netblock (
				network_interface_id,
				netblock_id,
				network_interface_rank
			) SELECT
				ni_id,
				nb_rec.netblock_id,
				COALESCE(MAX(network_interface_rank) + 1, 0)
			FROM
				network_interface_netblock nin
			WHERE
				nin.network_interface_id = ni_id
			RETURNING * INTO nin_rec;

			RAISE DEBUG E'Inserted into:\n%',
				jsonb_pretty(to_jsonb(nin_rec));
		END LOOP;
		--
		-- Remove any netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR nin_rec IN
			DELETE FROM
				network_interface_netblock nin
			WHERE
				(nin.network_interface_id, nin.netblock_id) IN (
				SELECT
					nin2.network_interface_id,
					nin2.netblock_id
				FROM
					network_interface_netblock nin2 JOIN
					netblock n USING (netblock_id)
				WHERE
					nin2.network_interface_id = ni_id AND NOT (
						nin.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_coll_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_nblk_coll_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed netblock % from network_interface %',
				nin_rec.netblock_id,
				nin_rec.network_interface_id;
			--
			-- Remove any DNS records and/or netblocks that aren't used
			--
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = nin_rec.netblock_id;
				DELETE FROM netblock_collection_netblock WHERE
					netblock_id = nin_rec.netblock_id;
				DELETE FROM netblock WHERE netblock_id =
					nin_rec.netblock_id;
			EXCEPTION
				WHEN foreign_key_violation THEN NULL;
			END;
		END LOOP;
	END IF;

	--
	-- Loop through shared_ip_addresses passed and process those
	--

	IF ip_address_hash ? 'shared_ip_addresses' AND
		jsonb_typeof(ip_address_hash->'shared_ip_addresses') = 'array'
	THEN
		RAISE DEBUG 'Processing shared_ip_addresses...';
		--
		-- Loop through each member of the shared_ip_addresses array
		-- and process each address
		--
		addrs_ary := ip_address_hash->'shared_ip_addresses';
		c := jsonb_array_length(addrs_ary);
		i := 0;
		nb_id_ary := NULL;
		WHILE (i < c) LOOP
			IF jsonb_typeof(addrs_ary->i) = 'string' THEN
				--
				-- If this is a string, use it as an inet with default
				-- universe and netblock_type
				--
				ipaddr := addrs_ary->>i;
				universe := 0;
				nb_type := 'default';
				protocol := 'VRRP';
			ELSIF jsonb_typeof(addrs_ary->i) = 'object' THEN
				--
				-- If this is an object, require 'ip_address' key
				-- optionally use 'ip_universe_id' and 'netblock_type' keys
				-- to override the defaults
				--
				IF NOT addrs_ary->i ? 'ip_address' THEN
					RAISE E'Object in array element % of shared_ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses does not contain ip_address key:\n%',
						i, jsonb_pretty(addrs_ary->i);
				END IF;
				ipaddr := addrs_ary->i->>'ip_address';

				IF addrs_ary->i ? 'ip_universe_id' THEN
					universe := addrs_ary->i->'ip_universe_id';
				ELSE
					universe := 0;
				END IF;

				IF addrs_ary->i ? 'netblock_type' THEN
					nb_type := addrs_ary->i->>'netblock_type';
				ELSE
					nb_type := 'default';
				END IF;

				IF addrs_ary->i ? 'shared_netblock_protocol' THEN
					protocol := addrs_ary->i->>'shared_netblock_protocol';
				ELSIF addrs_ary->i ? 'protocol' THEN
					protocol := addrs_ary->i->>'protocol';
				ELSE
					protocol := 'VRRP';
				END IF;
			ELSE
				RAISE 'Invalid type in array element % of shared_ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses (%)',
					i, jsonb_typeof(addrs_ary->i);
			END IF;
			--
			-- We're done with the array, so increment the counter so
			-- we don't have to deal with it later
			--
			i := i + 1;

			RAISE DEBUG 'Address is %, universe is %, nb type is %',
				ipaddr, universe, nb_type;

			--
			-- Check to see if this is a netblock that we have been
			-- told to explicitly ignore
			--
			PERFORM
				ip_address
			FROM
				netblock n JOIN
				netblock_collection_netblock ncn USING (netblock_id) JOIN
				v_netblock_coll_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_nblk_coll_id =
						nce.root_netblock_collection_id
				)
			WHERE
				ipaddr <<= n.ip_address AND
				n.ip_universe_id = universe AND
				n.netblock_type = nb_type;

			--
			-- If we found this netblock in the ignore list, then just
			-- skip it
			--
			IF FOUND THEN
				RAISE DEBUG 'Skipping ignored address %', ipaddr;
				CONTINUE;
			END IF;

			--
			-- Look for an is_single_address='Y', can_subnet='N' netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = 'Y' AND
				can_subnet = 'N' AND
				netblock_type = nb_type AND
				ip_universe_id = universe AND
				host(ip_address) = host(ipaddr);

			IF FOUND THEN
				RAISE DEBUG E'Located netblock:\n%',
					jsonb_pretty(to_jsonb(nb_rec));

				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);

				--
				-- Look to see if there's a layer3_network for the
				-- parent netblock
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.netblock_id = nb_rec.parent_netblock_id;

				IF FOUND THEN
					RAISE DEBUG E'Located layer3_network:\n%',
						jsonb_pretty(to_jsonb(layer3_rec));
				ELSE
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
			ELSE
				--
				-- If the parent netblock does not exist, then create it
				-- if we were passed the option to
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.ip_universe_id = universe AND
					n.netblock_type = nb_type AND
					is_single_address = 'N' AND
					can_subnet = 'N' AND
					n.ip_address >>= ipaddr;

				IF NOT FOUND THEN
					RAISE DEBUG 'Parent netblock with ip_address %, netblock_type %, ip_universe_id % not found',
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					WITH nb_ins AS (
						INSERT INTO netblock (
							ip_address,
							netblock_type,
							is_single_address,
							can_subnet,
							ip_universe_id,
							netblock_status
						) VALUES (
							network(ipaddr),
							nb_type,
							'N',
							'N',
							universe,
							'Allocated'
						) RETURNING *
					), l3_ins AS (
						INSERT INTO layer3_network(
							netblock_id
						)
						SELECT
							netblock_id
						FROM
							nb_ins
						RETURNING *
					)
					SELECT
						nb_ins.netblock_id,
						nb_ins.ip_address,
						l3_ins.layer3_network_id,
						NULL
					INTO layer3_rec
					FROM
						nb_ins,
						l3_ins;
				ELSIF layer3_rec.layer3_network_id IS NULL THEN
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--

					RAISE DEBUG 'layer3_network for parent netblock % not found (ip_address %, netblock_type %, ip_universe_id %)',
						layer3_rec.netblock_id,
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
				RAISE DEBUG E'Located layer3_network:\n%',
					jsonb_pretty(to_jsonb(layer3_rec));
				--
				-- Parents should be all set up now.  Insert the netblock
				--
				INSERT INTO netblock (
					ip_address,
					netblock_type,
					ip_universe_id,
					is_single_address,
					can_subnet,
					netblock_status
				) VALUES (
					ipaddr,
					nb_type,
					universe,
					'Y',
					'N',
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;

			--
			-- See if this netblock is directly on any network_interface, and
			-- delete it if force is set, otherwise skip it
			--
			ni_id_ary := ARRAY[]::integer[];

			SELECT 
				ni.network_interface_id,
				nin.netblock_id,
				ni.device_id
			INTO nin_rec
			FROM
				network_interface_netblock nin JOIN
				network_interface ni USING (network_interface_id)
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id != ni_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND 
					nin_rec.device_id = ni_rec.device_id
				)
				THEN
					--
					-- Remove the netblocks from the network_interfaces,
					-- but save them for later so that we can migrate them
					-- after we make sure the shared_netblock exists.
					--
					-- Also, append the network_inteface_id that we
					-- specifically care about, and we'll add them all
					-- below
					--
					WITH z AS (
						DELETE FROM
							network_interface_netblock
						WHERE
							netblock_id = nb_rec.netblock_id
						RETURNING network_interface_id
					)
					SELECT array_agg(network_interface_id) FROM
						(SELECT network_interface_id FROM z) v
					INTO ni_id_ary;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSE
						RAISE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;
					END IF;
				END IF;

			END IF;

			IF NOT(ni_id = ANY(ni_id_ary)) THEN
				ni_id_ary := array_append(ni_id_ary, ni_id);
			END IF;

			--
			-- See if this netblock already belongs to a shared_network
			--
			SELECT * FROM
				shared_netblock sn
			INTO sn_rec
			WHERE
				sn.netblock_id = nb_rec.netblock_id;

			IF FOUND THEN
				IF sn_rec.shared_netblock_protocol != protocol THEN
					RAISE 'Netblock % (%) is assigned to shared_network %, but the shared_network_protocol does not match (% vs. %)',
						nb_rec.netblock_id,
						nb_rec.ip_address,
						sn_rec.shared_netblock_id,
						sn_rec.shared_netblock_protocol,
						protocol;
				END IF;
			ELSE
				INSERT INTO shared_netblock (
					shared_netblock_protocol,
					netblock_id
				) VALUES (
					protocol,
					nb_rec.netblock_id
				) RETURNING * INTO sn_rec;
			END IF;

			--
			-- Add this to any interfaces that we found above that
			-- need this
			--

			INSERT INTO shared_netblock_network_int (
				shared_netblock_id,
				network_interface_id,
				priority
			) SELECT
				sn_rec.shared_netblock_id,
				x.network_interface_id,
				0
			FROM
				unnest(ni_id_ary) x(network_interface_id)
			ON CONFLICT ON CONSTRAINT pk_ip_group_network_interface DO NOTHING;

			RAISE DEBUG E'Inserted shared_netblock % onto interfaces:\n%',
				sn_rec.shared_netblock_id, jsonb_pretty(to_jsonb(ni_id_ary));
		END LOOP;
		--
		-- Remove any shared_netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR nin_rec IN
			DELETE FROM
				shared_netblock_network_int snni
			WHERE
				(snni.network_interface_id, snni.shared_netblock_id) IN (
				SELECT
					snni2.network_interface_id,
					snni2.shared_netblock_id
				FROM
					shared_netblock_network_int snni2 JOIN
					shared_netblock sn USING (shared_netblock_id) JOIN
					netblock n USING (netblock_id)
				WHERE
					snni2.network_interface_id = ni_id AND NOT (
						sn.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_coll_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_nblk_coll_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed shared_netblock % from network_interface %',
				nin_rec.shared_netblock_id,
				nin_rec.network_interface_id;

			--
			-- Remove any DNS records, netblocks and shared_netblocks
			-- that aren't used
			--
			SELECT netblock_id INTO nb_id FROM shared_netblock sn WHERE
				sn.shared_netblock_id = nin_rec.shared_netblock_id;
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = nb_id;
				DELETE FROM netblock_collection_netblock ncn WHERE
					ncn.netblock_id = nb_id;
				DELETE FROM shared_netblock WHERE netblock_id = nb_id;
				DELETE FROM netblock WHERE netblock_id = nb_id;
			EXCEPTION
				WHEN foreign_key_violation THEN NULL;
			END;
		END LOOP;
	END IF;
	RETURN true;
END;
$function$
;

--
-- Process drops in physical_address_utils
--
--
-- Process drops in component_utils
--
--
-- Process drops in snapshot_manip
--
--
-- Process drops in lv_manip
--
--
-- Process drops in approval_utils
--
--
-- Process drops in account_collection_manip
--
--
-- Process drops in script_hooks
--
--
-- Process drops in backend_utils
--
--
-- Process drops in rack_utils
--
--
-- Process drops in schema_support
--
--
-- Process drops in layerx_network_manip
--
-- New function
CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer2_network(layer2_network_id integer, purge_network_interfaces boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
	PERFORM * FROM layerx_network_manip.delete_layer2_networks(
		layer2_network_id_list := ARRAY[ layer2_network_id ],
		purge_network_interfaces := purge_network_interfaces
	);
END $function$
;

-- New function
CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer2_networks(layer2_network_id_list integer[], purge_network_interfaces boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	netblock_id_list	integer[];
BEGIN
	BEGIN
		PERFORM local_hooks.delete_layer2_networks_before_hooks(
			layer2_network_id_list := layer2_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	IF (purge_network_interfaces) THEN
		SELECT ARRAY(
			SELECT
				n.netblock_id AS netblock_id
			FROM
				jazzhands.layer2_network l2 JOIN
				jazzhands.layer3_network l3 USING (layer2_network_id) JOIN
				jazzhands.netblock p USING (netblock_id) JOIN
				jazzhands.netblock n ON (p.netblock_id = n.parent_netblock_id)
			WHERE
				l2.layer2_network_id = ANY(layer2_network_id_list)
		) INTO netblock_id_list;

		WITH nin_del AS (
			DELETE FROM
				jazzhands.network_interface_netblock 
			WHERE
				netblock_id = ANY(netblock_id_list)
			RETURNING network_interface_id
		), snni_del AS (
			DELETE FROM
				jazzhands.shared_netblock_network_int
			WHERE
				shared_netblock_id IN (
					SELECT shared_netblock_id FROM jazzhands.shared_netblock
					WHERE netblock_id = ANY(netblock_id_list)
				)
			RETURNING network_interface_id
		)
		DELETE FROM jazzhands.network_interface
		WHERE
			network_interface_id IN (
				SELECT network_interface_id FROM nin_del
				UNION
				SELECT network_interface_id FROM snni_del
			);
	END IF;


	WITH x AS (
		SELECT
			p.netblock_id AS netblock_id,
			l2.layer2_network_id AS layer2_network_id,
			l3.layer3_network_id AS layer3_network_id
		FROM
			jazzhands.layer2_network l2 JOIN
			jazzhands.layer3_network l3 USING (layer2_network_id) JOIN
			jazzhands.netblock p USING (netblock_id)
		WHERE
			l2.layer2_network_id = ANY(layer2_network_id_list)
	), l3_coll_del AS (
		DELETE FROM
			jazzhands.l3_network_coll_l3_network
		WHERE
			layer3_network_id IN (SELECT layer3_network_id FROM x)
	), l3_del AS (
		DELETE FROM
			jazzhands.layer3_network
		WHERE
			layer3_network_id in (SELECT layer3_network_id FROM x)
	), l2_coll_del AS (
		DELETE FROM
			jazzhands.l2_network_coll_l2_network
		WHERE
			layer2_network_id IN (SELECT layer2_network_id FROM x)
	), l2_del AS (
		DELETE FROM
			jazzhands.layer2_network
		WHERE
			layer2_network_id IN (SELECT layer2_network_id FROM x)
	), nb_sel AS (
		SELECT
			n.netblock_id
		FROM
			jazzhands.netblock n JOIN
			x ON (n.parent_netblock_id = x.netblock_id)
	), dns_del AS (
		DELETE FROM
			jazzhands.dns_record
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	), nb_del as (
		DELETE FROM
			jazzhands.netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	), sn_del as (
		DELETE FROM
			jazzhands.shared_netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	)
	DELETE FROM
		jazzhands.netblock
	WHERE
		netblock_id IN (SELECT netblock_id FROM x);

	BEGIN
		PERFORM local_hooks.delete_layer2_networks_after_hooks(
			layer2_network_id_list := layer2_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

END $function$
;

-- Dropping obsoleted sequences....
DROP SEQUENCE IF EXISTS sw_package_relation_sw_package_relation_id_seq;
DROP SEQUENCE IF EXISTS sw_package_release_sw_package_release_id_seq;
DROP SEQUENCE IF EXISTS sw_package_repository_sw_package_repository_id_seq;
DROP SEQUENCE IF EXISTS voe_voe_id_seq;


-- Dropping obsoleted audit sequences....
DROP SEQUENCE IF EXISTS audit.sw_package_relation_seq;
DROP SEQUENCE IF EXISTS audit.sw_package_release_seq;
DROP SEQUENCE IF EXISTS audit.sw_package_repository_seq;
DROP SEQUENCE IF EXISTS audit.val_sw_package_format_seq;
DROP SEQUENCE IF EXISTS audit.val_symbolic_track_name_seq;
DROP SEQUENCE IF EXISTS audit.val_upgrade_severity_seq;
DROP SEQUENCE IF EXISTS audit.val_voe_state_seq;
DROP SEQUENCE IF EXISTS audit.voe_relation_seq;
DROP SEQUENCE IF EXISTS audit.voe_seq;
DROP SEQUENCE IF EXISTS audit.voe_sw_package_seq;
DROP SEQUENCE IF EXISTS audit.voe_symbolic_track_seq;


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- index
DROP INDEX "jazzhands"."xif2shared_netblock";
-- triggers
DROP TRIGGER IF EXISTS aaa_trigger_asset_component_id_fix ON asset;


-- BEGIN Misc that does not apply to above
DROP FUNCTION IF EXISTS perform_audit_sw_package_relation();
DROP FUNCTION IF EXISTS perform_audit_sw_package_release();
DROP FUNCTION IF EXISTS perform_audit_sw_package_repository();
DROP FUNCTION IF EXISTS perform_audit_val_sw_package_format();
DROP FUNCTION IF EXISTS perform_audit_val_symbolic_track_name();
DROP FUNCTION IF EXISTS perform_audit_val_upgrade_severity();
DROP FUNCTION IF EXISTS perform_audit_val_voe_state();
DROP FUNCTION IF EXISTS perform_audit_voe();
DROP FUNCTION IF EXISTS perform_audit_voe_relation();
DROP FUNCTION IF EXISTS perform_audit_voe_sw_package();
DROP FUNCTION IF EXISTS perform_audit_voe_symbolic_track();

-- drop and recreated if needed
ALTER TABLE dns_domain_ip_universe 
	DROP CONSTRAINT IF EXISTS fk_dnsdom_ipu_dnsdomid;
ALTER TABLE ONLY dns_domain_ip_universe
    ADD CONSTRAINT fk_dnsdom_ipu_dnsdomid FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);

CREATE TRIGGER trigger_dns_domain_nouniverse_del 
	INSTEAD OF DELETE ON v_dns_domain_nouniverse 
	FOR EACH ROW EXECUTE PROCEDURE dns_domain_nouniverse_del();

CREATE TRIGGER trigger_dns_domain_nouniverse_ins 
	INSTEAD OF INSERT ON v_dns_domain_nouniverse 
	FOR EACH ROW EXECUTE PROCEDURE dns_domain_nouniverse_ins();

CREATE TRIGGER trigger_dns_domain_nouniverse_upd 
	INSTEAD OF UPDATE ON v_dns_domain_nouniverse 
	FOR EACH ROW EXECUTE PROCEDURE dns_domain_nouniverse_upd();

COMMENT ON SCHEMA layerx_network_manip IS 'part of jazzhands';

CREATE UNIQUE INDEX mv_dev_col_root_leaf_id_idx ON mv_dev_col_root USING btree (leaf_id);
CREATE INDEX mv_dev_col_root_leaf_type_idx ON mv_dev_col_root USING btree (leaf_type);
CREATE INDEX mv_dev_col_root_root_id_idx ON mv_dev_col_root USING btree (root_id);
CREATE INDEX mv_dev_col_root_root_type_idx ON mv_dev_col_root USING btree (root_type);



-- END Misc that does not apply to above


-- Clean Up
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
GRANT select on all tables in schema audit to ro_role;
GRANT select on all sequences in schema audit to ro_role;
SELECT schema_support.end_maintenance();
select timeofday(), now();
