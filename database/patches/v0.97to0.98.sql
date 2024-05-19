--
-- Copyright (c) 2024 Todd Kover
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

	--suffix=v98
	--skip-cache
	--scan
	--post
	pre
	--post
	post
	--reinsert-dir=i
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance(false);
select clock_timestamp(), now(), clock_timestamp() - now() AS len;
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
-- Process middle (non-trigger) schema authorization_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_authorization_utils']);
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
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('component_manip', 'insert_cpu_component');
SELECT schema_support.save_grants_for_replay('component_manip', 'insert_cpu_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_manip.insert_cpu_component ( text,bigint,bigint,text,text,text,boolean );
CREATE OR REPLACE FUNCTION component_manip.insert_cpu_component(model text, processor_speed bigint, processor_cores bigint, socket_type text, vendor_name text DEFAULT NULL::text, serial_number text DEFAULT NULL::text, virtual_component boolean DEFAULT false)
 RETURNS jazzhands.component
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	m			ALIAS FOR model;
	sn			ALIAS FOR serial_number;
	ctid		integer;
	stid		integer;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF vendor_name IS NOT NULL THEN

		SELECT
			comp.company_id INTO cid
		FROM
			company comp JOIN
			company_collection_company ccc USING (company_id) JOIN
			property p USING (company_collection_id)
		WHERE
			p.property_type = 'DeviceProvisioning' AND
			p.property_name = 'CPUVendorProbeString' AND
			p.property_value = vendor_name
		ORDER BY
			p.property_id
		LIMIT 1;
	END IF;

	--
	-- See if we have this component type in the database already.
	--
	SELECT DISTINCT
		ct.component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_type_component_function ctcf USING (component_type_id) JOIN
		component_property cp ON (
			ct.component_type_id = cp.component_type_id AND
			cp.component_property_type = 'CPU' AND
			cp.component_property_name = 'ProcessorCores' AND
			cp.property_value::integer = processor_cores
		)
	WHERE
		ctcf.component_function = 'CPU' AND
		ct.model = m AND
		ct.is_virtual_component = virtual_component AND
		CASE WHEN cid IS NOT NULL THEN
			(company_id = cid)
		ELSE
			true
		END;

	--
	-- If the type isn't found, then we need to insert it
	--
	IF NOT FOUND THEN
		--
		-- Fetch the slot type
		--
		SELECT
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = socket_type AND
			slot_function = 'CPU';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type %, function % not found adding component_type',
				socket_type,
				'CPU'
				USING ERRCODE = 'JH501';
		END IF;

		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				company
			WHERE
				company_name = 'unknown';

			IF NOT FOUND THEN
				IF NOT FOUND THEN
					RAISE EXCEPTION 'company_id for unknown company not found adding component_type'
						USING ERRCODE = 'JH501';
				END IF;
			END IF;
		END IF;

		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description,
			is_virtual_component
		) VALUES (
			cid,
			model,
			stid,
			true,
			model,
			virtual_component
		) RETURNING component_type_id INTO ctid;

		--
		-- Insert component properties for the CPU
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES
			('ProcessorCores', 'CPU', ctid, processor_cores),
			('ProcessorSpeed', 'CPU', ctid, processor_speed);

		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_function (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(ARRAY['CPU']) x(cf);
	END IF;

	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'component_manip' AND type = 'function' AND object IN ('insert_cpu_component');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc insert_cpu_component failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('component_manip', 'insert_memory_component');
SELECT schema_support.save_grants_for_replay('component_manip', 'insert_memory_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_manip.insert_memory_component ( text,bigint,bigint,text,text,text );
CREATE OR REPLACE FUNCTION component_manip.insert_memory_component(model text, memory_size bigint, memory_speed bigint DEFAULT NULL::bigint, memory_type text DEFAULT 'DDR3'::text, vendor_name text DEFAULT NULL::text, serial_number text DEFAULT NULL::text)
 RETURNS jazzhands.component
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	m			ALIAS FOR model;
	sn			ALIAS FOR serial_number;
	ctid		integer;
	stid		integer;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF vendor_name IS NOT NULL THEN
		SELECT
			comp.company_id INTO cid
		FROM
			company comp JOIN
			company_collection_company ccc USING (company_id) JOIN
			property p USING (company_collection_id)
		WHERE
			p.property_type = 'DeviceProvisioning' AND
			p.property_name = 'MemoryVendorProbeString' AND
			p.property_value = vendor_name
		ORDER BY
			p.property_id
		LIMIT 1;
	END IF;

	--
	-- See if we have this component type in the database already.
	--
	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_type_component_function ctcf USING (component_type_id)
	WHERE
		component_function = 'memory' AND
		ct.model = m AND
		CASE WHEN cid IS NOT NULL THEN
			(company_id = cid)
		ELSE
			true
		END;

	--
	-- If the type isn't found, then we need to insert it
	--
	IF NOT FOUND THEN
		--
		-- Fetch the slot type
		--
		SELECT
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = memory_type AND
			slot_function = 'memory';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type % with function memory not found adding component_type',
				memory_type
				USING ERRCODE = 'JH501';
		END IF;

		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				company
			WHERE
				company_name = 'unknown';

			IF NOT FOUND THEN
				IF NOT FOUND THEN
					RAISE EXCEPTION 'company_id for unknown company not found adding component_type'
						USING ERRCODE = 'JH501';
				END IF;
			END IF;
		END IF;

		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			cid,
			model,
			stid,
			true,
			concat_ws(' ', vendor_name, model, (memory_size || 'MB'), 'memory')
		) RETURNING component_type_id INTO ctid;

		--
		-- Insert component properties for the memory
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES
			('MemorySize', 'memory', ctid, memory_size);

		--
		-- memory_speed may not be passed, so only insert it if we have it.
		--
		IF memory_speed IS NOT NULL THEN
			INSERT INTO component_property (
				component_property_name,
				component_property_type,
				component_type_id,
				property_value
			) VALUES
				('MemorySpeed', 'memory', ctid, memory_speed);
		END IF;

		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_function (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(ARRAY['memory']) x(cf);
	END IF;

	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'component_manip' AND type = 'function' AND object IN ('insert_memory_component');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc insert_memory_component failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_manip']);
--
-- Process middle (non-trigger) schema component_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_utils']);
--
-- Process middle (non-trigger) schema device_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_manip']);
--
-- Process middle (non-trigger) schema device_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_device_utils']);
--
-- Process middle (non-trigger) schema dns_manip
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('dns_manip', 'add_domain_from_cidr');
SELECT schema_support.save_grants_for_replay('dns_manip', 'add_domain_from_cidr');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS dns_manip.add_domain_from_cidr ( inet );
CREATE OR REPLACE FUNCTION dns_manip.add_domain_from_cidr(block inet)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	ipaddr		text;
	ipnodes		text[];
	domain		text;
	domain_id	dns_domain.dns_domain_id%TYPE;
	j			text;
BEGIN
	-- silently fail for ipv6
	IF family(block) != 4 THEN
		RETURN NULL;
	END IF;
	IF family(block) != 4 THEN
		j := '';
		-- this needs to be tweaked to expand ::, which postgresql does
		-- not easily do.  This requires more thinking than I was up for today.
		ipaddr := regexp_replace(host(block)::text, ':', '', 'g');
	ELSE
		j := '\.';
		ipaddr := host(block);
	END IF;

	EXECUTE 'select array_agg(member order by rn desc)
		from (
        select
			row_number() over () as rn, *
			from
			unnest(regexp_split_to_array($1, $2)) as member
		) x
	' INTO ipnodes USING ipaddr, j;

	IF family(block) = 4 THEN
		domain := array_to_string(ARRAY[ipnodes[2],ipnodes[3],ipnodes[4]], '.')
			|| '.in-addr.arpa';
	ELSE
		domain := array_to_string(ipnodes, '.')
			|| '.ip6.arpa';
	END IF;

	SELECT dns_domain_id INTO domain_id FROM dns_domain where dns_domain_name = domain;
	IF NOT FOUND THEN
		domain_id := dns_manip.add_dns_domain(domain);
	END IF;

	RETURN domain_id;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'dns_manip' AND type = 'function' AND object IN ('add_domain_from_cidr');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc add_domain_from_cidr failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('dns_manip', 'add_ns_records');
SELECT schema_support.save_grants_for_replay('dns_manip', 'add_ns_records');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS dns_manip.add_ns_records ( integer,boolean );
CREATE OR REPLACE FUNCTION dns_manip.add_ns_records(dns_domain_id integer, purge boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	IF purge THEN
		EXECUTE '
			DELETE FROM dns_record
			WHERE dns_domain_id = $1
			AND dns_name IS NULL
			AND dns_class = $2
			AND dns_type = $3
			AND dns_value NOT IN (
				SELECT property_value
				FROM property
				WHERE property_name = $4
				AND property_type = $5
			)
		' USING dns_domain_id, 'IN', 'NS', '_authdns', 'Defaults';
	END IF;
	EXECUTE '
		INSERT INTO dns_record (
			dns_domain_id, dns_class, dns_type, dns_value
		) select $1, $2, $3, property_value
		FROM property
		WHERE property_name = $4
		AND property_type = $5
		AND property_value NOT IN (
			SELECT dns_value
			FROM dns_record
			WHERE dns_domain_id = $1
			AND dns_class = $2
			AND dns_type = $3
			AND dns_name IS NULL
		)
	' USING dns_domain_id, 'IN', 'NS', '_authdns', 'Defaults';
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'dns_manip' AND type = 'function' AND object IN ('add_ns_records');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc add_ns_records failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('dns_manip', 'get_or_create_inaddr_domain_netblock_link');
SELECT schema_support.save_grants_for_replay('dns_manip', 'get_or_create_inaddr_domain_netblock_link');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS dns_manip.get_or_create_inaddr_domain_netblock_link ( character varying,integer );
CREATE OR REPLACE FUNCTION dns_manip.get_or_create_inaddr_domain_netblock_link(dns_domain_name character varying, dns_domain_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	nblk_id	netblock.netblock_id%type;
	blk text;
	root	text;
	brk	text[];
	ipmember text[];
	ip	inet;
	j text;
BEGIN
	brk := regexp_matches(dns_domain_name, '^(.+)\.(in-addr|ip6)\.arpa$');
	IF brk[2] = 'in-addr' THEN
		j := '.';
	ELSE
		j := ':';
	END IF;

	EXECUTE 'select array_agg(member order by rn desc), $2
		from (
        select
			row_number() over () as rn, *
			from
			unnest(regexp_split_to_array($1, $3)) as member
		) x
	' INTO ipmember USING brk[1], j, '\.';

	IF brk[2] = 'in-addr' THEN
		IF array_length(ipmember, 1) > 4 THEN
			RAISE EXCEPTION 'Unable to work with anything smaller than a /24';
		ELSIF array_length(ipmember, 1) != 3 THEN
			-- If this is not a /24, then do not add any rvs association
			RETURN NULL;
		END IF;
		WHILE array_length(ipmember, 1) < 4
		LOOP
			ipmember := array_append(ipmember, '0');
		END LOOP;
		ip := concat(array_to_string(ipmember, j),'/24')::inet;
	ELSE
		ip := concat(
			regexp_replace(
				array_to_string(ipmember, ''), '(....)', '\1:', 'g'),
			':/64')::inet;
	END IF;

	SELECT netblock_id
		INTO	nblk_id
		FROM	netblock
		WHERE	netblock_type = 'dns'
		AND		is_single_address = false
		AND		can_subnet = false
		AND		netblock_status = 'Allocated'
		AND		ip_universe_id = 0
		AND		ip_address = ip;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address, netblock_type, is_single_address,
			can_subnet, netblock_status, ip_universe_id
		) VALUES (
			ip, 'dns', false,
			false, 'Allocated', 0
		) RETURNING netblock_id INTO nblk_id;
	END IF;

	EXECUTE '
		INSERT INTO dns_record(
			dns_domain_id, dns_class, dns_type, netblock_id
		) values (
			$1, $2, $3, $4
		)
	' USING dns_domain_id, 'IN', 'REVERSE_ZONE_BLOCK_PTR', nblk_id;

	RETURN nblk_id;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'dns_manip' AND type = 'function' AND object IN ('get_or_create_inaddr_domain_netblock_link');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc get_or_create_inaddr_domain_netblock_link failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_manip']);
--
-- Process middle (non-trigger) schema dns_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_dns_utils']);
--
-- Process middle (non-trigger) schema jazzhands
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands']);
--
-- Process middle (non-trigger) schema jazzhands_legacy_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy_manip']);
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
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_property_utils']);
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
-- Process middle (non-trigger) schema x509_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_manip']);
--
-- Process middle (non-trigger) schema x509_plperl_cert_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_plperl_cert_utils']);
--
-- Process middle (non-trigger) schema audit
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_audit']);
--
-- Process middle (non-trigger) schema jazzhands_legacy
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy']);
-- Processing tables in main schema...
select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE service_endpoint_purpose

ALTER TABLE jazzhands.service_endpoint_purpose RENAME w TO service_endpoint_id;
ALTER TABLE jazzhands_audit.service_endpoint_purpose RENAME w TO service_endpoint_id;

-- DONE DEALING WITH TABLE service_endpoint_purpose (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('service_endpoint_purpose');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old service_endpoint_purpose failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('service_endpoint_purpose');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new service_endpoint_purpose failed but that is ok';
	NULL;
END;
$$;

-- Main loop processing views in account_collection_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in account_password_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in approval_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in authorization_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in auto_ac_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in backend_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in company_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in component_connection_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in component_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in component_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in device_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in device_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in dns_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in dns_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in jazzhands
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in jazzhands_legacy_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in layerx_network_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in logical_port_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in lv_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in net_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in netblock_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in netblock_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in network_strings
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in obfuscation_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in person_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in pgcrypto
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in physical_address_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in port_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in property_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in rack_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in schema_support
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in script_hooks
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in service_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in service_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in snapshot_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in time_util
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in token_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in versioning_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in x509_hash_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in x509_manip
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in x509_plperl_cert_utils
select clock_timestamp(), clock_timestamp() - now() AS len;
-- Main loop processing views in audit
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
-- Process all procs in authorization_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_authorization_utils']);
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
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands']);
--
-- Process all procs in jazzhands_legacy_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy_manip']);
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
-- Process all procs in x509_manip
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_manip']);
--
-- Process all procs in x509_plperl_cert_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_plperl_cert_utils']);
--
-- Process all procs in audit
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_audit']);
--
-- Recreate the saved views in the base schema
--
SELECT schema_support.replay_object_recreates(schema := 'jazzhands', type := 'view');


-- BEGIN Misc that does not apply to above
SET jazzhands.appuser = 'release-0.98';


-- END Misc that does not apply to above


-- BEGIN Misc that does not apply to above

-- END Misc that does not apply to above
--
-- BEGIN: process_ancillary_schema(jazzhands_legacy)
--
--- processing view v_dns_fwd in ancilary schema
---- BEGIN: DEALING WITH VIEW v_dns_fwd (definition change only)
CREATE OR REPLACE VIEW jazzhands_legacy.v_dns_fwd AS
 SELECT x.dns_record_id,
    x.network_range_id,
    x.dns_domain_id,
    x.dns_name,
    x.dns_ttl,
    x.dns_class,
    x.dns_type,
    x.dns_value,
    x.dns_priority,
    x.ip,
    x.netblock_id,
    x.ip_universe_id,
    x.ref_record_id,
    x.dns_srv_service,
    x.dns_srv_protocol,
    x.dns_srv_weight,
    x.dns_srv_port,
    x.is_enabled,
    x.should_generate_ptr,
    x.dns_value_record_id
   FROM ( SELECT u.dns_record_id,
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
                            ELSE concat(dv.dns_name, '.', dv.dns_domain_name, '.')
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
                        CASE
                            WHEN d.is_enabled THEN 'Y'::text
                            ELSE 'N'::text
                        END AS is_enabled,
                        CASE
                            WHEN d.should_generate_ptr THEN 'Y'::text
                            ELSE 'N'::text
                        END AS should_generate_ptr,
                    d.dns_value_record_id
                   FROM jazzhands.dns_record d
                     LEFT JOIN jazzhands.netblock ni USING (netblock_id)
                     LEFT JOIN ( SELECT dns_record.dns_record_id AS reference_dns_record_id,
                            dns_record.dns_name,
                            dns_record.netblock_id,
                            netblock.ip_address
                           FROM jazzhands.dns_record
                             LEFT JOIN jazzhands.netblock USING (netblock_id)) rdns USING (reference_dns_record_id)
                     LEFT JOIN ( SELECT dr.dns_record_id,
                            dr.dns_name,
                            dom.dns_domain_id,
                            dom.dns_domain_name,
                            dr.dns_value,
                            dnb.ip_address AS ip,
                            dnb.ip_address,
                            dnb.netblock_id
                           FROM jazzhands.dns_record dr
                             JOIN jazzhands.dns_domain dom USING (dns_domain_id)
                             LEFT JOIN jazzhands.netblock dnb USING (netblock_id)) dv ON d.dns_value_record_id = dv.dns_record_id
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
                    'Y'::text AS is_enabled,
                    'N'::text AS should_generate_ptr,
                    NULL::integer AS dns_value_record_id
                   FROM ( SELECT dr.network_range_id,
                            dr.dns_domain_id,
                            nbstart.ip_universe_id,
                            COALESCE(dr.dns_prefix, val_network_range_type.default_dns_prefix) AS dns_prefix,
                            nbstart.ip_address + generate_series(0::bigint, nbstop.ip_address - nbstart.ip_address) AS ip
                           FROM jazzhands.network_range dr
                             JOIN jazzhands.val_network_range_type USING (network_range_type)
                             JOIN jazzhands.netblock nbstart ON dr.start_netblock_id = nbstart.netblock_id
                             JOIN jazzhands.netblock nbstop ON dr.stop_netblock_id = nbstop.netblock_id
                          WHERE dr.dns_domain_id IS NOT NULL) range) u
          WHERE (u.dns_type::text IN ( SELECT val_dns_type.dns_type
                   FROM jazzhands.val_dns_type
                  WHERE val_dns_type.id_type::text = ANY (ARRAY['ID'::character varying, 'NON-ID'::character varying]::text[])))
        UNION ALL
         SELECT NULL::integer AS dns_record_id,
            NULL::integer AS network_range_id,
            dns_domain.parent_dns_domain_id AS dns_domain_id,
            regexp_replace(dns_domain.dns_domain_name::text, ('\.'::text || pdom.parent_dns_domain_name::text) || '$'::text, ''::text) AS dns_name,
            dns_record.dns_ttl,
            dns_record.dns_class,
            dns_record.dns_type,
                CASE
                    WHEN dns_record.dns_value::text ~ '\.$'::text THEN dns_record.dns_value::text
                    ELSE concat(dns_record.dns_value, '.', dns_domain.dns_domain_name, '.')
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
                CASE
                    WHEN dns_record.is_enabled THEN 'Y'::text
                    ELSE 'N'::text
                END AS is_enabled,
            'N'::text AS should_generate_ptr,
            NULL::integer AS dns_value_record_id
           FROM jazzhands.dns_record
             JOIN jazzhands.dns_domain USING (dns_domain_id)
             JOIN ( SELECT dns_domain_1.dns_domain_id AS parent_dns_domain_id,
                    dns_domain_1.dns_domain_name AS parent_dns_domain_name
                   FROM jazzhands.dns_domain dns_domain_1) pdom USING (parent_dns_domain_id)
          WHERE dns_record.dns_class::text = 'IN'::text AND dns_record.dns_type::text = 'NS'::text AND dns_record.dns_name IS NULL AND dns_domain.parent_dns_domain_id IS NOT NULL) x;

---- DONE: DEALING WITH VIEW v_dns_fwd

--- processing view v_acct_coll_acct_expanded in ancilary schema
---- BEGIN: DEALING WITH VIEW v_acct_coll_acct_expanded (definition change only)
CREATE OR REPLACE VIEW jazzhands_legacy.v_acct_coll_acct_expanded AS
 SELECT DISTINCT r.root_account_collection_id AS account_collection_id,
    aca.account_id
   FROM jazzhands_cache.ct_account_collection_hier_recurse r
     JOIN jazzhands.account_collection_account aca USING (account_collection_id);

---- DONE: DEALING WITH VIEW v_acct_coll_acct_expanded

--- processing view v_unix_mclass_settings in ancilary schema
---- BEGIN: DEALING WITH VIEW v_unix_mclass_settings (definition change only)
CREATE OR REPLACE VIEW jazzhands_legacy.v_unix_mclass_settings AS
 SELECT property_list.device_collection_id,
    array_agg(property_list.setting ORDER BY property_list.rn) AS mclass_setting
   FROM ( SELECT select_for_ordering.device_collection_id,
            select_for_ordering.setting,
            row_number() OVER () AS rn
           FROM ( SELECT dc.device_collection_id,
                    unnest(ARRAY[dc.property_name, dc.property_value]) AS setting
                   FROM ( SELECT dcd.device_collection_id,
                            p.property_name,
                            COALESCE(p.property_value, p.property_value_password_type) AS property_value,
                            row_number() OVER (PARTITION BY dcd.device_collection_id, p.property_name ORDER BY dcd.device_collection_level, p.property_id) AS ord
                           FROM ( SELECT v_device_collection_hier_ancestor.device_collection_id,
                                    v_device_collection_hier_ancestor.ancestor_device_collection_id AS parent_device_collection_id,
                                    v_device_collection_hier_ancestor.device_collection_level
                                   FROM jazzhands.v_device_collection_hier_ancestor) dcd
                             JOIN jazzhands_legacy.v_property p ON p.device_collection_id = dcd.parent_device_collection_id
                          WHERE p.property_type::text = 'MclassUnixProp'::text AND p.account_collection_id IS NULL) dc
                  WHERE dc.ord = 1) select_for_ordering) property_list
  GROUP BY property_list.device_collection_id;

---- DONE: DEALING WITH VIEW v_unix_mclass_settings

--- processing view v_hotpants_device_collection in ancilary schema
---- BEGIN: DEALING WITH VIEW v_hotpants_device_collection (definition change only)
CREATE OR REPLACE VIEW jazzhands_legacy.v_hotpants_device_collection AS
 SELECT rankbyhier.device_id,
    rankbyhier.device_name,
    rankbyhier.device_collection_id,
    rankbyhier.device_collection_name,
    rankbyhier.device_collection_type,
    host(rankbyhier.ip_address) AS ip_address
   FROM ( SELECT dcd.device_id,
            device.device_name,
            dc.device_collection_id,
            dc.device_collection_name,
            dc.device_collection_type,
            dcr.device_collection_level,
            nb.ip_address,
            rank() OVER (PARTITION BY dcd.device_id ORDER BY dcr.device_collection_level, (
                CASE
                    WHEN nb.ip_address IS NULL THEN 0
                    ELSE 1
                END), dc.device_collection_id) AS rank
           FROM jazzhands_legacy.device_collection dc
             LEFT JOIN jazzhands_legacy.v_device_coll_hier_detail dcr ON dc.device_collection_id = dcr.parent_device_collection_id
             LEFT JOIN jazzhands_legacy.device_collection_device dcd ON dcd.device_collection_id = dcr.device_collection_id
             LEFT JOIN jazzhands_legacy.device USING (device_id)
             LEFT JOIN jazzhands.layer3_interface_netblock ni USING (device_id)
             LEFT JOIN jazzhands_legacy.netblock nb USING (netblock_id)
          WHERE dc.device_collection_type::text = ANY (ARRAY['HOTPants'::character varying, 'HOTPants-app'::character varying]::text[])) rankbyhier
  WHERE rankbyhier.device_collection_type::text = 'HOTPants-app'::text OR rankbyhier.rank = 1 AND rankbyhier.ip_address IS NOT NULL;

---- DONE: DEALING WITH VIEW v_hotpants_device_collection

--- processing view v_device_col_account_cart in ancilary schema
---- BEGIN: DEALING WITH VIEW v_device_col_account_cart (definition change only)
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_col_account_cart AS
 SELECT l.device_collection_id,
    l.account_id,
    l.setting
   FROM ( SELECT xx.device_collection_id,
            xx.account_id,
            xx.setting
           FROM ( SELECT x.device_collection_id,
                    x.account_id,
                    x.setting,
                    row_number() OVER (PARTITION BY x.device_collection_id, x.account_id ORDER BY x.setting) AS rn
                   FROM ( SELECT v_unix_account_overrides.device_collection_id,
                            v_unix_account_overrides.account_id,
                            v_unix_account_overrides.setting
                           FROM jazzhands_legacy.v_unix_account_overrides
                             JOIN jazzhands_legacy.v_device_col_acct_col_unixlogin USING (device_collection_id, account_id)
                        UNION
                         SELECT v_device_col_acct_col_unixlogin.device_collection_id,
                            v_device_col_acct_col_unixlogin.account_id,
                            NULL::character varying[] AS setting
                           FROM jazzhands_legacy.v_device_col_acct_col_unixlogin) x) xx
          WHERE xx.rn = 1) l
     JOIN jazzhands_legacy.account_unix_info USING (account_id);

---- DONE: DEALING WITH VIEW v_device_col_account_cart

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy']);
-- DONE: process_ancillary_schema(jazzhands_legacy)
--
-- BEGIN: process_ancillary_schema(audit)
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_audit']);
-- DONE: process_ancillary_schema(audit)


-- Clean Up

ALTER TABLE jazzhands.service_endpoint_x509_certificate
	DROP CONSTRAINT ak_service_endpoint_x509_x509_id_rank ;
ALTER TABLE jazzhands.service_endpoint_x509_certificate
	ADD CONSTRAINT ak_service_endpoint_x509_x509_id_rank
	UNIQUE (service_endpoint_id, service_endpoint_x509_certificate_purpose, x509_certificate_rank);

DROP INDEX jazzhands_audit.aud_2service_endpoint_x509_certificate_ak_service_endpoint_x509;
CREATE INDEX aud_2service_endpoint_x509_certificate_ak_service_endpoint_x509 ON jazzhands_audit.service_endpoint_x509_certificate USING btree (service_endpoint_id, service_endpoint_x509_certificate_purpose, x509_certificate_rank);

-- Dropping obsoleted sequences....


-- Dropping obsoleted jazzhands_audit sequences....

-- BEGIN: Procesing things saved for end
--
SAVEPOINT beforerecreate;

--
-- END: Procesing things saved for end
--

SELECT schema_support.replay_object_recreates(beverbose := true);
SELECT schema_support.replay_saved_grants(beverbose := true);

--
-- END: Running final cache table sync
SAVEPOINT beforereset;
SELECT schema_support.reset_all_schema_table_sequences('jazzhands');
SELECT schema_support.reset_all_schema_table_sequences('jazzhands_audit');
SAVEPOINT beforegrant;
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
