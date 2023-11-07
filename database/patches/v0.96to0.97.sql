--
-- Copyright (c) 2023 Todd Kover
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

	--suffix=v97
	--scan
	--final
	final
	--pre
	pre
	--post
	post
	--reinsert-dir=i
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance(false);
select clock_timestamp(), now(), clock_timestamp() - now() AS len;


-- BEGIN Misc that does not apply to above
SET jazzhands.appuser = 'release-0.97';

DROP FUNCTION IF EXISTS netblock_manip.set_layer3_interface_addresses ( 
	layer3_interface_id integer, 
	device_id integer, 
	layer3_interface_name text, 
	layer3_interface_type text, 
	ip_address_hash jsonb, 
	create_layer3_networks boolean, 
	move_addresses text, 
	address_errors text );


-- END Misc that does not apply to above
--
-- BEGIN: process_ancillary_schema(schema_support)
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_schema_support']);
-- DONE: process_ancillary_schema(schema_support)
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	_tal := 0;
	SELECT count(*) INTO _tal FROM pg_extension WHERE extname = 'plperl';

	-- certain schemas are optional and the first conditional
	-- is true if the schem is optional.
	IF false OR _tal = 1 THEN
		CREATE SCHEMA authorization_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA authorization_utils IS 'part of jazzhands';
	END IF;
EXCEPTION WHEN duplicate_schema THEN
	RAISE NOTICE 'Schema exists.  Skipping creation';
END;
			$$;--
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
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_manip'::text, object := 'fetch_component ( integer,text,boolean,text,integer )'::text, tags := ARRAY['process_all_procs_in_schema_component_manip'::text]);
DROP FUNCTION IF EXISTS component_manip.fetch_component ( integer,text,boolean,text,integer );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_manip'::text, object := 'insert_disk_component ( text,bigint,text,text,text,text )'::text, tags := ARRAY['process_all_procs_in_schema_component_manip'::text]);
DROP FUNCTION IF EXISTS component_manip.insert_disk_component ( text,bigint,text,text,text,text );
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('component_manip', 'insert_pci_component');
SELECT schema_support.save_grants_for_replay('component_manip', 'insert_pci_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_manip.insert_pci_component ( integer,integer,integer,integer,text,text,text,text,text[],text,text );
CREATE OR REPLACE FUNCTION component_manip.insert_pci_component(pci_vendor_id integer, pci_device_id integer, pci_sub_vendor_id integer DEFAULT NULL::integer, pci_subsystem_id integer DEFAULT NULL::integer, pci_vendor_name text DEFAULT NULL::text, pci_device_name text DEFAULT NULL::text, pci_sub_vendor_name text DEFAULT NULL::text, pci_sub_device_name text DEFAULT NULL::text, component_function_list text[] DEFAULT NULL::text[], slot_type text DEFAULT 'unknown'::text, serial_number text DEFAULT NULL::text)
 RETURNS jazzhands.component
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	sn			ALIAS FOR serial_number;
	ct			RECORD;
	comp_id		integer;
	sub_comp_id	integer;
	stid		integer;
	vendor_name	text;
	sub_vendor_name	text;
	model_name	text;
	descrip		text;
	c			RECORD;
BEGIN
	IF (pci_sub_vendor_id IS NULL AND pci_subsystem_id IS NOT NULL) OR
			(pci_sub_vendor_id IS NOT NULL AND pci_subsystem_id IS NULL) THEN
		RAISE EXCEPTION
			'pci_sub_vendor_id and pci_subsystem_id must be set together';
	END IF;

	--
	-- See if we have this component type in the database already
	--
	SELECT
		component_type.* INTO ct
	FROM
		component_property vid JOIN
		component_property did ON (
			vid.component_property_name = 'PCIVendorID' AND
			vid.component_property_type = 'PCI' AND
			did.component_property_name = 'PCIDeviceID' AND
			did.component_property_type = 'PCI' AND
			vid.component_type_id = did.component_type_id ) LEFT JOIN
		component_property svid ON (
			svid.component_property_name = 'PCISubsystemVendorID' AND
			svid.component_property_type = 'PCI' AND
			svid.component_type_id = did.component_type_id ) LEFT JOIN
		component_property sid ON (
			sid.component_property_name = 'PCISubsystemID' AND
			sid.component_property_type = 'PCI' AND
			sid.component_type_id = did.component_type_id ) JOIN
		component_type ON (
			did.component_type_id = component_type.component_type_id )
	WHERE
		vid.property_value = pci_vendor_id::varchar AND
		did.property_value = pci_device_id::varchar AND
		svid.property_value IS NOT DISTINCT FROM pci_sub_vendor_id::varchar AND
		sid.property_value IS NOT DISTINCT FROM pci_subsystem_id::varchar;

	--
	-- The device type doesn't exist, so attempt to insert it
	--

	IF NOT FOUND THEN
		IF pci_device_name IS NULL OR component_function_list IS NULL THEN
			RAISE EXCEPTION 'component_id not found and pci_device_name or component_function_list was not passed' USING ERRCODE = 'JH501';
		END IF;

		--
		-- Ensure that there's a company linkage for the PCI (subsystem)vendor
		--
		SELECT
			company_id, company_name INTO comp_id, vendor_name
		FROM
			property p JOIN
			company c USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'PCIVendorID' AND
			property_value = pci_vendor_id::text;

		IF NOT FOUND THEN
			IF pci_vendor_name IS NULL THEN
				RAISE EXCEPTION 'PCI vendor id mapping not found and pci_vendor_name was not passed' USING ERRCODE = 'JH501';
			END IF;
			SELECT company_id INTO comp_id FROM company
			WHERE company_name = pci_vendor_name;

			IF NOT FOUND THEN
				SELECT company_manip.add_company(
					company_name := pci_vendor_name,
					company_types := ARRAY['hardware provider'],
					description := 'PCI vendor auto-insert'
				) INTO comp_id;
			END IF;

			INSERT INTO property (
				property_name,
				property_type,
				property_value,
				company_id
			) VALUES (
				'PCIVendorID',
				'DeviceProvisioning',
				pci_vendor_id,
				comp_id
			);
			vendor_name := pci_vendor_name;
		END IF;

		SELECT
			company_id, company_name INTO sub_comp_id, sub_vendor_name
		FROM
			property JOIN
			company c USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'PCIVendorID' AND
			property_value = pci_sub_vendor_id::text;

		IF NOT FOUND THEN
			IF pci_sub_vendor_name IS NULL THEN
				RAISE EXCEPTION 'PCI subsystem vendor id mapping not found and pci_sub_vendor_name was not passed' USING ERRCODE = 'JH501';
			END IF;
			SELECT company_id INTO sub_comp_id FROM company
			WHERE company_name = pci_sub_vendor_name;

			IF NOT FOUND THEN
				SELECT company_manip.add_company(
					_company_name := pci_sub_vendor_name,
					_company_types := ARRAY['hardware provider'],
					 _description := 'PCI vendor auto-insert'
				) INTO sub_comp_id;
			END IF;

			INSERT INTO property (
				property_name,
				property_type,
				property_value,
				company_id
			) VALUES (
				'PCIVendorID',
				'DeviceProvisioning',
				pci_sub_vendor_id,
				sub_comp_id
			);
			sub_vendor_name := pci_sub_vendor_name;
		END IF;

		--
		-- Fetch the slot type
		--

		SELECT
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = insert_pci_component.slot_type AND
			slot_function = 'PCI';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type % with function PCI not found adding component_type',
				insert_pci_component.slot_type
				USING ERRCODE = 'JH501';
		END IF;

		--
		-- Figure out the best name/description to insert this component with
		--
		IF
			pci_sub_device_name IS NOT NULL AND
			pci_sub_device_name !~ '^Device'
		THEN
			model_name = pci_sub_device_name;
			descrip = concat_ws(' ',
				sub_vendor_name, pci_sub_device_name,
				'(' || vendor_name, pci_device_name || ')');
		ELSIF pci_sub_device_name ~ '^Device' THEN
			model_name = pci_device_name;
			descrip = concat_ws(
				' ',
				vendor_name,
				'(' || sub_vendor_name || ')',
				pci_device_name
			);
		ELSE
			model_name = pci_device_name;
			descrip = concat_ws(' ', vendor_name, pci_device_name);
		END IF;

		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			COALESCE(sub_comp_id, comp_id),
			model_name,
			stid,
			true,
			descrip
		) RETURNING * INTO ct;
		--
		-- Insert properties for the PCI vendor/device IDs
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES
			('PCIVendorID', 'PCI', ct.component_type_id, pci_vendor_id),
			('PCIDeviceID', 'PCI', ct.component_type_id, pci_device_id);

		IF (pci_subsystem_id IS NOT NULL) THEN
			INSERT INTO component_property (
				component_property_name,
				component_property_type,
				component_type_id,
				property_value
			) VALUES
				(
					'PCISubsystemVendorID',
					'PCI',
					ct.component_type_id,
					pci_sub_vendor_id
				),
				(
					'PCISubsystemID',
					'PCI',
					ct.component_type_id,
					pci_subsystem_id)
				;
		END IF;
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_function (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ct.component_type_id,
			cf
		FROM
			unnest(array_append(component_function_list, 'PCI')) x(cf);
	ELSE
		IF
			ct.model ~ '^Device [0-9a-f]{4}$'
		THEN
			IF
				pci_sub_device_name IS NOT NULL AND
				pci_sub_device_name !~ '^Device'
			THEN
				model_name = pci_sub_device_name;
				descrip = concat_ws(' ',
					sub_vendor_name, pci_sub_device_name,
					'(' || vendor_name, pci_device_name || ')');
			ELSIF pci_sub_device_name ~ '^Device' THEN
				model_name = pci_device_name;
				descrip = concat_ws(
					' ',
					vendor_name,
					'(' || sub_vendor_name || ')',
					pci_device_name
				);
			ELSE
				model_name = pci_device_name;
				descrip = concat_ws(' ', vendor_name, pci_device_name);
			END IF;

			IF model_name IS DISTINCT FROM ct.model THEN
				UPDATE
					component_type
				SET
					model = model_name,
					description = descrip
				WHERE
					component_type_id = ct.component_type_id;
			END IF;
		END IF;
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
			component_type_id = ct.component_type_id AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ct.component_type_id
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
	DELETE FROM __recreate WHERE schema = 'component_manip' AND type = 'function' AND object IN ('insert_pci_component');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc insert_pci_component failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('component_manip', 'remove_component_hier');
SELECT schema_support.save_grants_for_replay('component_manip', 'remove_component_hier');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_manip.remove_component_hier ( integer,boolean );
CREATE OR REPLACE FUNCTION component_manip.remove_component_hier(component_id integer, really_delete boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	slot_list		integer[];
	shelf_list		integer[];
	delete_list		integer[];
	cid				integer;
BEGIN
	cid := component_id;

	SELECT ARRAY(
		SELECT
			slot_id
		FROM
			v_component_hier h JOIN
			slot s ON (h.child_component_id = s.component_id)
		WHERE
			h.component_id = cid)
	INTO slot_list;

	IF really_delete THEN
		SELECT ARRAY(
			SELECT
				child_component_id
			FROM
				v_component_hier h
			WHERE
				h.component_id = cid)
		INTO delete_list;
	ELSE

		SELECT ARRAY(
			SELECT
				child_component_id
			FROM
				v_component_hier h LEFT JOIN
				asset a on (a.component_id = h.child_component_id)
			WHERE
				h.component_id = cid AND
				serial_number IS NOT NULL
		)
		INTO shelf_list;

		SELECT ARRAY(
			SELECT
				child_component_id
			FROM
				v_component_hier h LEFT JOIN
				asset a on (a.component_id = h.child_component_id)
			WHERE
				h.component_id = cid AND
				serial_number IS NULL
		)
		INTO delete_list;

	END IF;

	DELETE FROM
		inter_component_connection
	WHERE
		slot1_id = ANY (slot_list) OR
		slot2_id = ANY (slot_list);

	UPDATE
		component c
	SET
		parent_slot_id = NULL
	WHERE
		c.component_id = ANY (array_cat(delete_list, shelf_list)) AND
		parent_slot_id IS NOT NULL;

	DELETE FROM component_property cp WHERE
		cp.component_id = ANY (delete_list) OR
		slot_id = ANY (slot_list);

	DELETE FROM
		slot s
	WHERE
		slot_id = ANY (slot_list) AND
		s.component_id = ANY(delete_list);

	DELETE FROM
		asset a
	WHERE
		a.component_id = ANY (delete_list);

	DELETE FROM
		component c
	WHERE
		c.component_id = ANY (delete_list);

	RETURN true;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'component_manip' AND type = 'function' AND object IN ('remove_component_hier');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc remove_component_hier failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('component_manip', 'update_pci_component_type_model');
SELECT schema_support.save_grants_for_replay('component_manip', 'update_pci_component_type_model');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_manip.update_pci_component_type_model ( integer,text,text,text,text );
CREATE OR REPLACE FUNCTION component_manip.update_pci_component_type_model(component_type_id integer, pci_device_name text, pci_sub_device_name text DEFAULT NULL::text, pci_vendor_name text DEFAULT NULL::text, pci_sub_vendor_name text DEFAULT NULL::text)
 RETURNS jazzhands.component_type
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	ct			RECORD;
	model_name	text;
	descrip		text;
BEGIN
	SELECT
		* INTO ct
	FROM
		component_type comptype
	WHERE
		comptype.component_type_id =
			update_pci_component_type_model.component_type_id;

	IF NOT FOUND THEN
		RETURN NULL;
	END IF;

	IF pci_vendor_name IS NULL THEN
		SELECT
			company_name INTO pci_vendor_name
		FROM
			component_property cp JOIN
			property p ON (
				p.property_name = 'PCIVendorID' AND
				p.property_type = 'DeviceProvisioning' AND
				p.property_value = cp.property_value
			) JOIN
			company c ON (c.company_id = p.company_id)
		WHERE
			cp.component_property_name = 'PCIVendorID' AND
			cp.component_property_type = 'PCI' AND
			cp.component_type_id =
				update_pci_component_type_model.component_type_id;
	END IF;

	IF pci_sub_vendor_name IS NULL THEN
		SELECT
			company_name INTO pci_sub_vendor_name
		FROM
			component_property cp JOIN
			property p ON (
				p.property_name = 'PCIVendorID' AND
				p.property_type = 'DeviceProvisioning' AND
				p.property_value = cp.property_value
			) JOIN
			company c ON (c.company_id = p.company_id)
		WHERE
			cp.component_property_name = 'PCISubsystemVendorID' AND
			cp.component_property_type = 'PCI' AND
			cp.component_type_id =
				update_pci_component_type_model.component_type_id;
	END IF;

	IF
		pci_sub_device_name IS NOT NULL AND
		pci_sub_device_name !~ '^Device'
	THEN
		model_name = pci_sub_device_name;
		descrip = concat_ws(' ',
			pci_sub_vendor_name, pci_sub_device_name,
			'(' || coalesce(pci_vendor_name, 'Unknown'),
			pci_device_name || ')'
		);
	ELSIF pci_sub_device_name ~ '^Device' THEN
		model_name = pci_device_name;
		descrip = concat_ws(
			' ',
			pci_vendor_name,
			'(' || pci_sub_vendor_name || ')',
			pci_device_name
		);
	ELSE
		model_name = pci_device_name;
		descrip = concat_ws(' ', pci_vendor_name, pci_device_name);
	END IF;

	IF model_name IS DISTINCT FROM ct.model THEN
		UPDATE
			component_type comptype
		SET
			model = model_name,
			description = descrip
		WHERE
			comptype.component_type_id = ct.component_type_id
		RETURNING * INTO ct;
	END IF;

	RETURN ct;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'component_manip' AND type = 'function' AND object IN ('update_pci_component_type_model');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc update_pci_component_type_model failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_manip']);
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('component_manip', 'fetch_component');
DROP FUNCTION IF EXISTS component_manip.fetch_component ( integer,text,boolean,text,integer,boolean );
CREATE OR REPLACE FUNCTION component_manip.fetch_component(component_type_id integer, serial_number text, no_create boolean DEFAULT false, ownership_status text DEFAULT 'unknown'::text, parent_slot_id integer DEFAULT NULL::integer, force_parent boolean DEFAULT false)
 RETURNS jazzhands.component
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	ctid		ALIAS FOR component_type_id;
	sn			ALIAS FOR serial_number;
	psid		ALIAS FOR parent_slot_id;
	os			ALIAS FOR ownership_status;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF sn IS NOT NULL THEN
		SELECT
			comp.* INTO c
		FROM
			component comp JOIN
			asset a USING (component_id)
		WHERE
			comp.component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			--
			-- Only update the parent slot if it isn't set already
			--
			IF psid IS NOT NULL AND
				(c.parent_slot_id IS NULL OR force_parent)
			THEN
				UPDATE
					component comp
				SET
					parent_slot_id = psid
				WHERE
					comp.component_id = c.component_id;
			END IF;
			RETURN c;
		END IF;
	END IF;

	IF no_create THEN
		RETURN NULL;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id,
		parent_slot_id
	) VALUES (
		ctid,
		parent_slot_id
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			os
		);
	END IF;

	RETURN c;
END;
$function$
;

-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('component_manip', 'insert_disk_component');
DROP FUNCTION IF EXISTS component_manip.insert_disk_component ( text,bigint,text,text,text,text,integer );
CREATE OR REPLACE FUNCTION component_manip.insert_disk_component(model text, bytes bigint DEFAULT NULL::bigint, vendor_name text DEFAULT NULL::text, protocol text DEFAULT NULL::text, media_type text DEFAULT NULL::text, serial_number text DEFAULT NULL::text, rotational_rate integer DEFAULT NULL::integer)
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

	IF model IS NULL OR model ~ '^\s*$' THEN
		RAISE EXCEPTION 'model must be given to insert component'
			USING ERRCODE = 'JH501';
	END IF;

	IF vendor_name IS NOT NULL THEN
		--
		-- Try to find a vendor that matches.  Look up various properties
		-- for a probe string match, and then see if it matches the
		-- company name.
		--
		SELECT
			comp.company_id INTO cid
		FROM
			company comp JOIN
			company_collection_company ccc USING (company_id) JOIN
			property p USING (company_collection_id)
		WHERE
			p.property_type = 'DeviceProvisioning' AND
			p.property_name = 'DiskVendorProbeString' AND
			p.property_value = vendor_name
		ORDER BY
			p.property_id
		LIMIT 1;

		IF cid IS NULL THEN
			SELECT
				comp.company_id INTO cid
			FROM
				company comp JOIN
				company_collection_company ccc USING (company_id) JOIN
				property p USING (company_collection_id)
			WHERE
				p.property_type = 'DeviceProvisioning' AND
				p.property_name = 'DeviceVendorProbeString' AND
				p.property_value = vendor_name
			ORDER BY
				p.property_id
			LIMIT 1;
		END IF;

		--
		-- This is being deprecated in favor of the company_collection
		-- above
		--
		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				property p
			WHERE
				p.property_type = 'DeviceProvisioning' AND
				p.property_name = 'DeviceVendorProbeString' AND
				p.property_value = vendor_name;
		END IF;

		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				company comp
			WHERE
				comp.company_name = vendor_name;
		END IF;

		--
		-- Company was not found, so insert one
		--
		IF cid IS NULL THEN
			SELECT company_manip.add_company(
				company_name := vendor_name,
				company_types := ARRAY['hardware provider'],
				description := 'disk vendor auto-insert'
			) INTO cid;

			--
			-- Insert the probed string as a property so things can be
			-- easily changed to a different vendor later if this needs
			-- to be merged into something else.
			--
			INSERT INTO property (
				property_name,
				property_type,
				property_value,
				company_collection_id
			) VALUES (
				'DiskVendorProbeString',
				'DeviceProvisioning',
				vendor_name,
				(
					SELECT
						cc.company_collection_id
					FROM
						company_collection cc JOIN
						company_collection_company ccc USING (company_collection_id) JOIN
						company comp USING (company_id)
					WHERE
						cc.company_collection_type = 'per-device' AND
						comp.company_id = cid
				)
			);
		END IF;
	END IF;

	--
	-- Try to determine the component_type
	--
	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_property cp USING (component_type_id) JOIN
		component_type_component_function ctcf USING (component_type_id)
	WHERE
		ctcf.component_function = 'disk' AND
		cp.component_property_name = 'DiskModelProbeString' AND
		cp.component_property_type = 'disk' AND
		cp.property_value = m AND
		CASE WHEN cid IS NOT NULL THEN
			(company_id = cid)
		ELSE
			true
		END;

	IF ctid IS NULL THEN
		SELECT DISTINCT
			component_type_id INTO ctid
		FROM
			component_type ct JOIN
			component_type_component_function ctcf USING (component_type_id)
		WHERE
			component_function = 'disk' AND
			ct.model = m AND
			CASE WHEN cid IS NOT NULL THEN
				(company_id = cid)
			ELSE
				true
			END;
	END IF;

	--
	-- If the type isn't found, then we need to insert it
	--
	IF NOT FOUND THEN
		--
		-- Validate that we have all the parameters that we need to insert
		-- this component_type.
		--

		IF
			bytes IS NULL OR
			cid IS NULL OR
			protocol IS NULL OR
			media_type IS NULL
		THEN
			RAISE EXCEPTION 'component_type for %model % not found so vendor_name, bytes, protocol, and media_type must be given',
				CASE WHEN cid IS NOT NULL THEN 
					('vendor ' || vendor_name)
				ELSE
					''
				END,
				model;
		END IF;

		--
		-- Fetch the slot type
		--
		SELECT
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = protocol AND
			slot_function = 'disk';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type % with function disk not found adding component_type',
				protocol
				USING ERRCODE = 'JH501';
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
			concat_ws(' ', vendor_name, model, media_type, 'disk')
		) RETURNING component_type_id INTO ctid;

		--
		-- Insert component properties for the disk
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES
			('DiskModelProbeString', 'disk', ctid, model),
			('DiskSize', 'disk', ctid, bytes),
			('DiskProtocol', 'disk', ctid, protocol),
			('MediaType', 'disk', ctid, media_type);

		IF rotational_rate IS NOT NULL THEN
			INSERT INTO component_property (
				component_property_name,
				component_property_type,
				component_type_id,
				property_value
			) VALUES
				('RotationalRate', 'disk', ctid, rotational_rate);
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
			unnest(ARRAY['storage', 'disk']) x(cf);
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

-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('component_manip', 'set_component_property');
DROP FUNCTION IF EXISTS component_manip.set_component_property ( character varying,character varying,character varying,integer,integer );
CREATE OR REPLACE FUNCTION component_manip.set_component_property(component_property_name character varying, component_property_type character varying, property_value character varying, component_id integer DEFAULT NULL::integer, component_type_id integer DEFAULT NULL::integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	cpn		ALIAS FOR component_property_name;
	cpt		ALIAS FOR component_property_type;
	pv		ALIAS FOR property_value;
	cid		ALIAS FOR component_id;
	ct_id	ALIAS FOR component_type_id;
	cp		RECORD;
BEGIN
	IF cid IS NULL AND ct_id IS NULL THEN
		RAISE EXCEPTION
			'component_id or component_type_id must be passed to set_component_property';
		RETURN NULL;
	END IF;

	IF cpn IS NULL OR cpt IS NULL THEN
		RAISE EXCEPTION
			'component_property_name and component_property_type must be passed to set_component_property';
		RETURN NULL;
	END IF;

	IF property_value IS NULL THEN
		DELETE FROM
			component_property p
		WHERE
			p.component_property_name = cpn AND
			p.component_property_type = cpt AND
			( cid IS NULL OR p.component_id = cid ) AND
			( ct_id IS NULL OR p.component_type_id = ct_id );
		RETURN true;
	END IF;

	SELECT * FROM component_property p INTO cp WHERE
		p.component_property_name = cpn AND
		p.component_property_type = cpt AND
		( cid IS NULL OR p.component_id = cid ) AND
		( ct_id IS NULL OR p.component_type_id = ct_id );

	IF NOT FOUND THEN
		INSERT INTO component_property (
			component_id,
			component_type_id,
			component_property_name,
			component_property_type,
			property_value
		) VALUES (
			cid,
			ct_id,
			cpn,
			cpt,
			pv
		);
		RETURN true;
	END IF;

	IF cp.property_value IS DISTINCT FROM pv THEN
		UPDATE
			component_property p
		SET
			property_value = pv
		WHERE
			p.component_property_id = cp.component_property_id;
	END IF;

	RETURN true;
END;
$function$
;

--
-- Process middle (non-trigger) schema component_utils
--
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'create_component_template_slots ( integer )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.create_component_template_slots ( integer );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'fetch_component ( integer,text,boolean,text,integer )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.fetch_component ( integer,text,boolean,text,integer );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'insert_component_into_parent_slot ( integer,integer,text,text,text,integer,text )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.insert_component_into_parent_slot ( integer,integer,text,text,text,integer,text );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'insert_cpu_component ( text,bigint,bigint,text,text,text )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.insert_cpu_component ( text,bigint,bigint,text,text,text );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'insert_disk_component ( text,bigint,text,text,text,text )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.insert_disk_component ( text,bigint,text,text,text,text );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'insert_memory_component ( text,bigint,bigint,text,text,text )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.insert_memory_component ( text,bigint,bigint,text,text,text );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'insert_pci_component ( integer,integer,integer,integer,text,text,text,text,text[],text,text )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.insert_pci_component ( integer,integer,integer,integer,text,text,text,text,text[],text,text );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'migrate_component_template_slots ( integer )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.migrate_component_template_slots ( integer );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'remove_component_hier ( integer,boolean )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.remove_component_hier ( integer,boolean );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'replace_component ( integer,integer )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.replace_component ( integer,integer );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'set_slot_names ( integer[] )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.set_slot_names ( integer[] );
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_utils']);
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('component_utils', 'fetch_disk_component');
DROP FUNCTION IF EXISTS component_utils.fetch_disk_component ( text,text,text );
CREATE OR REPLACE FUNCTION component_utils.fetch_disk_component(model text, serial_number text, vendor_name text DEFAULT NULL::text)
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

	IF
		model IS NULL OR model ~ '^\s*$' OR
		serial_number IS NULL OR serial_number ~ '^\s*$'
	THEN
		RAISE EXCEPTION 'model and serial_number must be given to fetch_disk_component'
			USING ERRCODE = 'JH501';
	END IF;

	IF vendor_name IS NOT NULL THEN
		--
		-- Try to find a vendor that matches.  Look up various properties
		-- for a probe string match, and then see if it matches the
		-- company name.
		--
		SELECT
			comp.company_id INTO cid
		FROM
			company comp JOIN
			company_collection_company ccc USING (company_id) JOIN
			property p USING (company_collection_id)
		WHERE
			p.property_type = 'DeviceProvisioning' AND
			p.property_name = 'DiskVendorProbeString' AND
			p.property_value = vendor_name
		ORDER BY
			p.property_id
		LIMIT 1;

		IF cid IS NULL THEN
			SELECT
				comp.company_id INTO cid
			FROM
				company comp JOIN
				company_collection_company ccc USING (company_id) JOIN
				property p USING (company_collection_id)
			WHERE
				p.property_type = 'DeviceProvisioning' AND
				p.property_name = 'DeviceVendorProbeString' AND
				p.property_value = vendor_name
			ORDER BY
				p.property_id
			LIMIT 1;
		END IF;

		--
		-- This is being deprecated in favor of the company_collection
		-- above
		--
		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				property p
			WHERE
				p.property_type = 'DeviceProvisioning' AND
				p.property_name = 'DeviceVendorProbeString' AND
				p.property_value = vendor_name;
		END IF;

		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				company comp
			WHERE
				comp.company_name = vendor_name;
		END IF;

		IF cid IS NULL THEN
			RETURN NULL;
		END IF;
	END IF;

	--
	-- Try to determine the component_type
	--

	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_property cp USING (component_type_id) JOIN
		component_type_component_function ctcf USING (component_type_id)
	WHERE
		ctcf.component_function = 'disk' AND
		cp.component_property_name = 'DiskModelProbeString' AND
		cp.component_property_type = 'disk' AND
		cp.property_value = m AND
		CASE WHEN cid IS NOT NULL THEN
			(company_id = cid)
		ELSE
			true
		END;

	IF ctid IS NULL THEN
		SELECT DISTINCT
			component_type_id INTO ctid
		FROM
			component_type ct JOIN
			component_type_component_function ctcf USING (component_type_id)
		WHERE
			component_function = 'disk' AND
			ct.model = m AND
			CASE WHEN cid IS NOT NULL THEN
				(company_id = cid)
			ELSE
				true
			END;
	END IF;

	--
	-- Find a component of this type with the given serial_number
	--
	 SELECT
		component.* INTO c
	FROM
		component JOIN
		asset a USING (component_id)
	WHERE
		component_type_id = ctid AND
		a.serial_number = sn;

	RETURN c;
END;
$function$
;

--
-- Process middle (non-trigger) schema device_manip
--
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
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('device_manip', 'set_operating_system');
DROP FUNCTION IF EXISTS device_manip.set_operating_system ( integer,text,text,text,text,text );
CREATE OR REPLACE FUNCTION device_manip.set_operating_system(device_id integer, operating_system_name text, operating_system_version text, operating_system_major_version text DEFAULT NULL::text, operating_system_family text DEFAULT NULL::text, operating_system_company_name text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	did		ALIAS FOR device_id;
	osname	ALIAS FOR operating_system_name;
	osrec	RECORD;
	cid		jazzhands.company.company_id%TYPE;
BEGIN
	SELECT
		*
	FROM
		operating_system os
	INTO
		osrec
	WHERE
		os.operating_system_name = osname AND
		os.version = operating_system_version;

	IF NOT FOUND THEN
		--
		-- Don't care if this is NULL
		--
		SELECT
			company_id INTO cid
		FROM
			company
		WHERE
			company_name = operating_system_company_name;

		INSERT INTO operating_system (
			operating_system_name,
			company_id,
			major_version,
			version,
			operating_system_family
		) VALUES (
			osname,
			cid,
			operating_system_major_version,
			operating_system_version,
			operating_system_family
		) RETURNING * INTO osrec;
	END IF;

	UPDATE
		device d
	SET
		operating_system_id = osrec.operating_system_id
	WHERE
		d.device_id = did;

	RETURN osrec.operating_system_id;
END;
$function$
;

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
SELECT schema_support.save_dependent_objects_for_replay('dns_manip', 'set_dns_for_interface');
SELECT schema_support.save_grants_for_replay('dns_manip', 'set_dns_for_interface');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS dns_manip.set_dns_for_interface ( integer,text,integer,boolean );
CREATE OR REPLACE FUNCTION dns_manip.set_dns_for_interface(netblock_id integer, layer3_interface_name text, device_id integer, force boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
-- This tells it to favor columns over parameter when ambiguous
-- see https://www.postgresql.org/message-id/CAE3TBxyCn9dOF2273ki%3D4NFwsaJdYXiMQ6x2rydsWY_6p8z_zg%40mail.gmail.com
#variable_conflict use_column
DECLARE
	nid	ALIAS FOR netblock_id;
	l3n	ALIAS FOR layer3_interface_name;
	_devid	ALIAS FOR device_id;
	_devn	TEXT;
	_dns	JSONB;
	_dnsified	TEXT;
	_newr	dns_record.dns_record_id%TYPE;
	_newn	TEXT;
	_t	TEXT;
	_nb	netblock%ROWTYPE;
BEGIN
	SELECT device_name, dns_utils.find_dns_domain_from_fqdn(device_name)
	INTO _devn, _dns
	FROM device d
	WHERE d.device_id = _devid;

	IF _dns IS NULL OR _dns->>'dns_domain_id' IS NULL THEN
		RETURN '{}';
	END IF;

	SELECT * INTO _nb FROM netblock n WHERE n.netblock_id = nid;

	IF family(_nb.ip_address) = 6 THEN
		_t = 'AAAA';
	ELSIF family(_nb.ip_address) = 4 THEN
		_t = 'A';
	ELSE
		RAISE EXCEPTION 'Unkown family for %: %', nid, family(_nb.ip_address)
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Unknown device_id %', devid;
	END IF;

	SELECT string_agg(elem, '.')
	INTO _dnsified
	FROM (select regexp_replace(x, '[^a-z0-9]', '-', 'ig') AS elem,
		row_number() OVER()
		FROM unnest(regexp_split_to_array(layer3_interface_name, '\.')) AS x
			ORDER BY 2 DESC
		) z;

	_newn := concat_ws('.', _dnsified,_dns->>'dns_name');


	IF force THEN
		INSERT INTO dns_record AS d (
			dns_name, dns_type, dns_domain_id, netblock_id, should_generate_ptr
		) VALUES (
			_newn, _t, CAST(_dns->>'dns_domain_id' AS INTEGER), nid, true
		) ON CONFLICT (netblock_id, should_generate_ptr)
			WHERE should_generate_ptr AND dns_type IN ('A','AAAA')
				AND netblock_id IS NOT NULL
        DO UPDATE SET
			dns_name = _newn,  dns_domain_id =
				CAST(_dns->>'dns_domain_id' AS integer)
		RETURNING dns_record_id INTO _newr;

		RETURN jsonb_build_object(
			'dns_record_id', _newr,
			'dns_name',  _newn,
			'dns_domain_id', _dns->>'dns_domain_id'
		);

	ELSE
		INSERT INTO dns_record (
			dns_name, dns_type, dns_domain_id, netblock_id
		) VALUES (
			_newn, _t, CAST(_dns->>'dns_domain_id' AS INTEGER), nid
		) ON CONFLICT (netblock_id, should_generate_ptr)
        WHERE should_generate_ptr AND dns_type IN ('A','AAAA')
               AND netblock_id IS NOT NULL
        DO NOTHING;
	END IF;

	RETURN '{}';
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'dns_manip' AND type = 'function' AND object IN ('set_dns_for_interface');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc set_dns_for_interface failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('dns_manip', 'set_dns_for_shared_routing_addresses');
SELECT schema_support.save_grants_for_replay('dns_manip', 'set_dns_for_shared_routing_addresses');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS dns_manip.set_dns_for_shared_routing_addresses ( integer,boolean );
CREATE OR REPLACE FUNCTION dns_manip.set_dns_for_shared_routing_addresses(netblock_id integer, force boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
-- This tells it to favor columns over parameter when ambiguous
-- see https://www.postgresql.org/message-id/CAE3TBxyCn9dOF2273ki%3D4NFwsaJdYXiMQ6x2rydsWY_6p8z_zg%40mail.gmail.com
#variable_conflict use_column
DECLARE
	nid	ALIAS FOR netblock_id;
	_r		RECORD;
	_dns	JSONB;
	_newr	dns_record.dns_record_id%TYPE;
	_t		TEXT;
BEGIN
	SELECT layer3_network_id, sn.netblock_id, default_gateway_ip_address,
		shared_netblock_protocol, encapsulation_tag,
		encapsulation_domain,
		dns_utils.find_dns_domain_from_fqdn(
			lower(concat_ws('.', shared_netblock_protocol, encapsulation_tag,
				encapsulation_domain, device_name))::text
		) AS dns
	INTO _r
	FROM v_layerx_network_expanded lx
		JOIN shared_netblock sn ON
				sn.netblock_id = lx.default_gateway_netblock_id
		JOIN shared_netblock_layer3_interface USING (shared_netblock_id)
		JOIN layer3_interface USING (layer3_interface_id)
		JOIN device USING (device_id)
	WHERE sn.netblock_id = nid
	AND encapsulation_domain IS NOT NULL
	ORDER BY sn.netblock_id, layer3_interface_id
	LIMIT 1;

	IF _r IS NULL OR _r.dns IS NULL THEN
		RETURN NULL;
	END IF;

	_dns := _r.dns;

	IF family(_r.default_gateway_ip_address) = 6 THEN
		_t = 'AAAA';
	ELSIF family(_r.default_gateway_ip_address) = 4 THEN
		_t = 'A';
	ELSE
		RAISE EXCEPTION 'Unkown family for %: %', nid, family(_nb.ip_address)
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF force THEN
		INSERT INTO dns_record AS d (
			dns_name, dns_type, dns_domain_id, netblock_id, should_generate_ptr
		) VALUES (
			_dns->>'dns_name', _t, CAST(_dns->>'dns_domain_id' AS INTEGER),
			nid, true
		) ON CONFLICT (netblock_id, should_generate_ptr)
			WHERE should_generate_ptr AND dns_type IN ('A','AAAA')
				AND netblock_id IS NOT NULL
        DO UPDATE SET
			dns_name = _dns->>'dns_name',  dns_domain_id =
				CAST(_dns->>'dns_domain_id' AS integer)
		RETURNING dns_record_id INTO _newr;

		RETURN jsonb_build_object(
			'dns_record_id', _newr,
			'dns_name',  _dns->>'dns_name',
			'dns_domain_id', _dns->>'dns_domain_id'
		);

	ELSE
		INSERT INTO dns_record (
			dns_name, dns_type, dns_domain_id, netblock_id
		) VALUES (
			_dns->>'dns_name', _t, CAST(_dns->>'dns_domain_id' AS INTEGER),
				nid
		) ON CONFLICT (netblock_id, should_generate_ptr)
        WHERE should_generate_ptr AND dns_type IN ('A','AAAA')
               AND netblock_id IS NOT NULL
        DO NOTHING;
	END IF;

	RETURN '{}';
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'dns_manip' AND type = 'function' AND object IN ('set_dns_for_shared_routing_addresses');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc set_dns_for_shared_routing_addresses failed but that is ok';
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
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('layerx_network_manip', 'delete_layer2_networks');
SELECT schema_support.save_grants_for_replay('layerx_network_manip', 'delete_layer2_networks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS layerx_network_manip.delete_layer2_networks ( integer[],boolean );
CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer2_networks(layer2_network_id_list integer[], purge_network_interfaces boolean DEFAULT false)
 RETURNS SETOF jazzhands.layer2_network
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	netblock_id_list	integer[];
BEGIN
	IF array_length(layer2_network_id_list, 1) IS NULL THEN
		RETURN;
	END IF;

	BEGIN
		PERFORM local_hooks.delete_layer2_networks_before_hooks(
			layer2_network_id_list := layer2_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	PERFORM layerx_network_manip.delete_layer3_networks(
		layer3_network_id_list := ARRAY(
				SELECT layer3_network_id
				FROM layer3_network l3n
				WHERE layer2_network_id = ANY(layer2_network_id_list)
			),
		purge_network_interfaces :=
			delete_layer2_networks.purge_network_interfaces
	);

	DELETE FROM
		layer2_network_collection_layer2_network l2nc
	WHERE
		l2nc.layer2_network_id = ANY(layer2_network_id_list);

	RETURN QUERY DELETE FROM
		layer2_network l2n
	WHERE
		l2n.layer2_network_id = ANY(layer2_network_id_list)
	RETURNING *;

	BEGIN
		PERFORM local_hooks.delete_layer2_networks_after_hooks(
			layer2_network_id_list := layer2_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

END $function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'layerx_network_manip' AND type = 'function' AND object IN ('delete_layer2_networks');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc delete_layer2_networks failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_layerx_network_manip']);
--
-- Process middle (non-trigger) schema logical_port_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_logical_port_manip']);
--
-- Process middle (non-trigger) schema lv_manip
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('lv_manip', 'delete_lv');
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_lv');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_lv ( integer[],boolean );
CREATE OR REPLACE FUNCTION lv_manip.delete_lv(logical_volume_list integer[], purge_orphans boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	PERFORM lv_manip.delete_pv(
		physicalish_volume_list := (
			SELECT ARRAY (SELECT
				physicalish_volume_id
			FROM
				physicalish_volume pv
			WHERE
				pv.logical_volume_id = ANY(logical_volume_list)
		)),
		purge_orphans := purge_orphans
	);

	DELETE FROM
		logical_volume_property lvp
	WHERE
		lvp.logical_volume_id = ANY(logical_volume_list);
	
	DELETE FROM
		logical_volume_purpose lvp
	WHERE
		lvp.logical_volume_id = ANY(logical_volume_list);
	
	DELETE FROM
		block_storage_device bsd
	WHERE
		bsd.logical_volume_id = ANY(logical_volume_list);
	
	DELETE FROM
		logical_volume lv
	WHERE
		lv.logical_volume_id = ANY(logical_volume_list);
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'lv_manip' AND type = 'function' AND object IN ('delete_lv');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc delete_lv failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('lv_manip', 'delete_lv_hier');
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_lv_hier');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_lv_hier ( integer,integer,integer );
CREATE OR REPLACE FUNCTION lv_manip.delete_lv_hier(physicalish_volume_id integer DEFAULT NULL::integer, volume_group_id integer DEFAULT NULL::integer, logical_volume_id integer DEFAULT NULL::integer, OUT pv_list integer[], OUT vg_list integer[], OUT lv_list integer[])
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	pvid ALIAS FOR physicalish_volume_id;
	vgid ALIAS FOR volume_group_id;
	lvid ALIAS FOR logical_volume_id;
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_pv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_pv_id IS NOT NULL
	) INTO pv_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_vg_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_vg_id IS NOT NULL
	) INTO vg_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_lv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_lv_id IS NOT NULL
	) INTO lv_list;

	DELETE FROM block_storage_device WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume_property WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume_purpose WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM volume_group_purpose WHERE volume_group_id = ANY(vg_list);
	DELETE FROM volume_group WHERE volume_group_id = ANY(vg_list);
	DELETE FROM physicalish_volume WHERE physicalish_volume_id = ANY(pv_list);
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'lv_manip' AND type = 'function' AND object IN ('delete_lv_hier');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc delete_lv_hier failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('lv_manip', 'delete_vg');
SELECT schema_support.save_grants_for_replay('lv_manip', 'delete_vg');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS lv_manip.delete_vg ( integer[],boolean );
CREATE OR REPLACE FUNCTION lv_manip.delete_vg(volume_group_list integer[], purge_orphans boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	lvids	integer[];
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT
			logical_volume_id
		FROM
			logical_volume lv
		WHERE
			lv.volume_group_id = ANY(volume_group_list)
	) INTO lvids;

	PERFORM lv_manip.delete_pv(
		physicalish_volume_list := (
			SELECT ARRAY (SELECT
				physicalish_volume_id
			FROM
				physicalish_volume
			WHERE
				logical_volume_id = ANY(lvids)
		)),
		purge_orphans := purge_orphans
	);

	DELETE FROM
		volume_group_physicalish_volume vgpv
	WHERE
		vgpv.volume_group_id = ANY(volume_group_list);
	
	DELETE FROM
		volume_group_purpose vgp
	WHERE
		vgp.volume_group_id = ANY(volume_group_list);

	DELETE FROM
		logical_volume_property
	WHERE
		logical_volume_id = ANY(lvids);

	DELETE FROM
		logical_volume_purpose
	WHERE
		logical_volume_id = ANY(lvids);
	
	DELETE FROM
		block_storage_device
	WHERE
		logical_volume_id = ANY(lvids);
	
	DELETE FROM
		logical_volume
	WHERE
		logical_volume_id = ANY(lvids);
	
	DELETE FROM
		volume_group vg
	WHERE
		vg.volume_group_id = ANY(volume_group_list);
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'lv_manip' AND type = 'function' AND object IN ('delete_vg');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc delete_vg failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_lv_manip']);
--
-- Process middle (non-trigger) schema net_manip
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_net_manip']);
--
-- Process middle (non-trigger) schema netblock_manip
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('netblock_manip', 'set_layer3_interface_addresses');
SELECT schema_support.save_grants_for_replay('netblock_manip', 'set_layer3_interface_addresses');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.set_layer3_interface_addresses ( integer,integer,text,text,jsonb,boolean,integer,text,text );
CREATE OR REPLACE FUNCTION netblock_manip.set_layer3_interface_addresses(layer3_interface_id integer DEFAULT NULL::integer, device_id integer DEFAULT NULL::integer, layer3_interface_name text DEFAULT NULL::text, layer3_interface_type text DEFAULT 'broadcast'::text, ip_address_hash jsonb DEFAULT NULL::jsonb, create_layer3_networks boolean DEFAULT false, layer2_network_id integer DEFAULT NULL::integer, move_addresses text DEFAULT 'if_same_device'::text, address_errors text DEFAULT 'error'::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
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
	l3i_id			ALIAS FOR layer3_interface_id;
	dev_id			ALIAS FOR device_id;
	l3i_name		ALIAS FOR layer3_interface_name;
	l3i_type		ALIAS FOR layer3_interface_type;

	addrs_ary		jsonb;
	ipaddr			inet;
	universe		integer;
	nb_type			text;
	protocol		text;

	c				integer;
	i				integer;

	error_rec		RECORD;
	nb_rec			RECORD;
	pnb_rec			RECORD;
	layer3_rec		RECORD;
	sn_rec			RECORD;
	l3i_rec			RECORD;
	l3in_rec		RECORD;
	nb_id			jazzhands.netblock.netblock_id%TYPE;
	nb_id_ary		integer[];
	l3i_id_ary		integer[];
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

	IF layer3_interface_id IS NULL THEN
		IF device_id IS NULL OR layer3_interface_name IS NULL THEN
			RAISE 'netblock_manip.assign_shared_netblock: must pass either layer3_interface_id or device_id and layer3_interface_name'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;

		SELECT
			l3i.layer3_interface_id INTO l3i_id
		FROM
			layer3_interface l3i
		WHERE
			l3i.device_id = dev_id AND
			l3i.layer3_interface_name = l3i_name;

		IF NOT FOUND THEN
			INSERT INTO layer3_interface(
				device_id,
				layer3_interface_name,
				layer3_interface_type,
				should_monitor
			) VALUES (
				dev_id,
				l3i_name,
				l3i_type,
				false
			) RETURNING layer3_interface.layer3_interface_id INTO l3i_id;
		END IF;
	END IF;

	SELECT * INTO l3i_rec FROM layer3_interface l3i WHERE
		l3i.layer3_interface_id = l3i_id;

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
				universe := netblock_utils.find_best_ip_universe(ipaddr);
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
					universe := netblock_utils.find_best_ip_universe(ipaddr);
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
				v_netblock_collection_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_netblock_collection_id =
						nce.root_netblock_collection_id
				)
			WHERE
				ipaddr <<= n.ip_address AND
				n.ip_universe_id = universe
			;

			--
			-- If we found this netblock in the ignore list, then just
			-- skip it
			--
			IF FOUND THEN
				RAISE DEBUG 'Skipping ignored address %', ipaddr;
				CONTINUE;
			END IF;

			--
			-- Look for an is_single_address=true, can_subnet=false netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = true AND
				can_subnet = false AND
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
						netblock_id, layer2_network_id
					) VALUES (
						layer3_rec.netblock_id, layer2_network_id
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
					is_single_address = false AND
					can_subnet = false AND
					n.ip_address >>= ipaddr;

				IF NOT FOUND THEN
					RAISE DEBUG 'Parent netblock with ip_address %, netblock_type %, ip_universe_id % not found',
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					--
					-- Check to see if the netblock exists, but is
					-- marked can_subnet=true.  If so, fix it
					--
					SELECT
						* INTO pnb_rec
					FROM
						netblock n
					WHERE
						n.ip_universe_id = universe AND
						n.netblock_type = nb_type AND
						n.is_single_address = false AND
						n.can_subnet = true AND
						n.ip_address = network(ipaddr);

					IF FOUND THEN
						UPDATE netblock n SET
							can_subnet = false
						WHERE
							n.netblock_id = pnb_rec.netblock_id;
						pnb_rec.can_subnet = false;
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
							false,
							false,
							universe,
							'Allocated'
						) RETURNING * INTO pnb_rec;
					END IF;

					WITH l3_ins AS (
						INSERT INTO layer3_network(
							netblock_id, layer2_network_id
						) VALUES (
							pnb_rec.netblock_id, layer2_network_id
						) RETURNING *
					)
					SELECT
						pnb_rec.netblock_id,
						pnb_rec.ip_address,
						l3_ins.layer3_network_id,
						l3_ins.layer2_network_Id,
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
						netblock_id, layer2_network_id
					) VALUES (
						layer3_rec.netblock_id, layer2_network_id
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
					true,
					false,
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;
			--
			-- Now that we have the netblock and everything, check to see
			-- if this netblock is already assigned to this layer3_interface
			--
			PERFORM * FROM
				layer3_interface_netblock l3in
			WHERE
				l3in.netblock_id = nb_rec.netblock_id AND
				l3in.layer3_interface_id = l3i_id;

			IF FOUND THEN
				RAISE DEBUG 'Netblock % already found on layer3_interface',
					nb_rec.netblock_id;
				CONTINUE;
			END IF;

			--
			-- See if this netblock is on something else, and delete it
			-- if move_addresses is set, otherwise skip it
			--
			SELECT
				l3i.layer3_interface_id,
				l3i.layer3_interface_name,
				l3in.netblock_id,
				d.device_id,
				COALESCE(d.device_name, d.physical_label) AS device_name
			INTO l3in_rec
			FROM
				layer3_interface_netblock l3in JOIN
				layer3_interface l3i USING (layer3_interface_id) JOIN
				device d ON (l3in.device_id = d.device_id)
			WHERE
				l3in.netblock_id = nb_rec.netblock_id AND
				l3in.layer3_interface_id != l3i_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND
					l3in_rec.device_id = l3i_rec.device_id
				)
				THEN
					DELETE FROM
						layer3_interface_netblock
					WHERE
						netblock_id = nb_rec.netblock_id;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to layer3_interface %',
							nb_rec.netblock_id, l3in_rec.layer3_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % (%) is assigned to layer3_interface % (%) on device % (%)',
							nb_rec.netblock_id,
							nb_rec.ip_address,
							l3in_rec.layer3_interface_id,
							l3in_rec.layer3_interface_name,
							l3in_rec.device_id,
							l3in_rec.device_name;

						CONTINUE;
					ELSE
						RAISE 'Netblock % (%) is assigned to layer3_interface %(%) on device % (%)',
							nb_rec.netblock_id,
							nb_rec.ip_address,
							l3in_rec.layer3_interface_id,
							l3in_rec.layer3_interface_name,
							l3in_rec.device_id,
							l3in_rec.device_name;
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
						RAISE NOTICE 'Netblock % (%) is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, nb_rec.ip_address,
							sn.shared_netblock_id;
						CONTINUE;
					ELSE
						RAISE 'Netblock % (%) is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, nb_rec.ip_address,
							sn.shared_netblock_id;
						CONTINUE;
					END IF;
				END IF;

				DELETE FROM
					shared_netblock_layer3_interface snl3i
				WHERE
					snl3i.shared_netblock_id = sn_rec.shared_netblock_id;

				DELETE FROM
					shared_network sn
				WHERE
					sn.netblock_id = sn_rec.shared_netblock_id;
			END IF;

			--
			-- Insert the netblock onto the interface using the next
			-- rank
			--
			INSERT INTO layer3_interface_netblock (
				layer3_interface_id,
				netblock_id,
				layer3_interface_rank
			) SELECT
				l3i_id,
				nb_rec.netblock_id,
				COALESCE(MAX(layer3_interface_rank) + 1, 0)
			FROM
				layer3_interface_netblock l3in
			WHERE
				l3in.layer3_interface_id = l3i_id
			RETURNING * INTO l3in_rec;

			PERFORM dns_manip.set_dns_for_interface(
				netblock_id := nb_rec.netblock_id,
				layer3_interface_name := l3i_name,
				device_id := l3in_rec.device_id
			);

			RAISE DEBUG E'Inserted into:\n%',
				jsonb_pretty(to_jsonb(l3in_rec));
		END LOOP;
		--
		-- Remove any netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR l3in_rec IN
			DELETE FROM
				layer3_interface_netblock l3in
			WHERE
				(l3in.layer3_interface_id, l3in.netblock_id) IN (
				SELECT
					l3in2.layer3_interface_id,
					l3in2.netblock_id
				FROM
					layer3_interface_netblock l3in2 JOIN
					netblock n USING (netblock_id)
				WHERE
					l3in2.layer3_interface_id = l3i_id AND NOT (
						l3in.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_collection_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_netblock_collection_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed netblock % from layer3_interface %',
				l3in_rec.netblock_id,
				l3in_rec.layer3_interface_id;
			--
			-- Remove any DNS records and/or netblocks that aren't used
			--
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = l3in_rec.netblock_id;
				DELETE FROM netblock_collection_netblock WHERE
					netblock_id = l3in_rec.netblock_id;
				DELETE FROM netblock WHERE netblock_id =
					l3in_rec.netblock_id;
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
				universe := netblock_utils.find_best_ip_universe(ipaddr);
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
					universe := netblock_utils.find_best_ip_universe(ipaddr);
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
				v_netblock_collection_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_netblock_collection_id =
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
			-- Look for an is_single_address=true, can_subnet=false netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = true AND
				can_subnet = false AND
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
						netblock_id, layer2_network_id
					) VALUES (
						layer3_rec.netblock_id, layer2_network_id
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
					is_single_address = false AND
					can_subnet = false AND
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
							false,
							false,
							universe,
							'Allocated'
						) RETURNING *
					), l3_ins AS (
						INSERT INTO layer3_network(
							netblock_id, layer2_network_id
						)
						SELECT
							netblock_id, layer2_network_id
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
						netblock_id, layer2_network_id
					) VALUES (
						layer3_rec.netblock_id, layer2_network_id
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
					true,
					false,
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;

			--
			-- See if this netblock is directly on any layer3_interface, and
			-- delete it if force is set, otherwise skip it
			--
			l3i_id_ary := ARRAY[]::integer[];

			SELECT
				l3in.netblock_id,
				l3i.device_id
			INTO l3in_rec
			FROM
				layer3_interface_netblock l3in JOIN
				layer3_interface l3i USING (layer3_interface_id)
			WHERE
				l3in.netblock_id = nb_rec.netblock_id AND
				l3in.layer3_interface_id != l3i_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND
					l3in_rec.device_id = l3i_rec.device_id
				)
				THEN
					--
					-- Remove the netblocks from the layer3_interfaces,
					-- but save them for later so that we can migrate them
					-- after we make sure the shared_netblock exists.
					--
					-- Also, append the network_inteface_id that we
					-- specifically care about, and we'll add them all
					-- below
					--
					WITH z AS (
						DELETE FROM
							layer3_interface_netblock
						WHERE
							netblock_id = nb_rec.netblock_id
						RETURNING layer3_interface_id
					)
					SELECT array_agg(layer3_interface_id) FROM
						(SELECT layer3_interface_id FROM z) v
					INTO l3i_id_ary;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to layer3_interface %',
							nb_rec.netblock_id, l3in_rec.layer3_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % is assigned to layer3_interface %',
							nb_rec.netblock_id, l3in_rec.layer3_interface_id;

						CONTINUE;
					ELSE
						RAISE 'Netblock % is assigned to layer3_interface %',
							nb_rec.netblock_id, l3in_rec.layer3_interface_id;
					END IF;
				END IF;

			END IF;

			IF NOT(l3i_id = ANY(l3i_id_ary)) THEN
				l3i_id_ary := array_append(l3i_id_ary, l3i_id);
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

			INSERT INTO shared_netblock_layer3_interface (
				shared_netblock_id,
				layer3_interface_id,
				priority
			) SELECT
				sn_rec.shared_netblock_id,
				x.layer3_interface_id,
				0
			FROM
				unnest(l3i_id_ary) x(layer3_interface_id)
			ON CONFLICT ON CONSTRAINT pk_ip_group_network_interface DO NOTHING;

			RAISE DEBUG E'Inserted shared_netblock % onto interfaces:\n%',
				sn_rec.shared_netblock_id, jsonb_pretty(to_jsonb(l3i_id_ary));

			--
			-- If this shared netblock is VARP or VRRP, and we are to assume default gateway,
			-- update accordingly.
			--
			IF protocol IN ('VARP', 'VRRP') THEN
				UPDATE layer3_network
				SET default_gateway_netblock_id = sn_rec.netblock_id
				WHERE layer3_network_id = layer3_rec.layer3_network_id
				AND default_gateway_netblock_id IS DISTINCT FROM sn_rec.netblock_id;

				PERFORM dns_manip.set_dns_for_shared_routing_addresses(sn_rec.netblock_id);
			END IF;
		END LOOP;
		--
		-- Remove any shared_netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR l3in_rec IN
			DELETE FROM
				shared_netblock_layer3_interface snl3i
			WHERE
				(snl3i.layer3_interface_id, snl3i.shared_netblock_id) IN (
				SELECT
					snl3i2.layer3_interface_id,
					snl3i2.shared_netblock_id
				FROM
					shared_netblock_layer3_interface snl3i2 JOIN
					shared_netblock sn USING (shared_netblock_id) JOIN
					netblock n USING (netblock_id)
				WHERE
					snl3i2.layer3_interface_id = l3i_id AND NOT (
						sn.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_collection_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_netblock_collection_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed shared_netblock % from layer3_interface %',
				l3in_rec.shared_netblock_id,
				l3in_rec.layer3_interface_id;

			--
			-- Remove any DNS records, netblocks and shared_netblocks
			-- that aren't used
			--
			SELECT netblock_id INTO nb_id FROM shared_netblock sn WHERE
				sn.shared_netblock_id = l3in_rec.shared_netblock_id;
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

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'netblock_manip' AND type = 'function' AND object IN ('set_layer3_interface_addresses');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc set_layer3_interface_addresses failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.save_dependent_objects_for_replay(schema := 'netblock_manip'::text, object := 'set_layer3_interface_addresses ( integer,integer,text,text,jsonb,boolean,text,text )'::text, tags := ARRAY['process_all_procs_in_schema_netblock_manip'::text]);
DROP FUNCTION IF EXISTS netblock_manip.set_layer3_interface_addresses ( integer,integer,text,text,jsonb,boolean,text,text );
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
		IF v_prop.property_value_service_version_collection_type_restriction IS NOT NULL THEN
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

	IF v_prop.Permit_DNS_Domain_Collection_Id = 'REQUIRED' THEN
			IF NEW.DNS_Domain_Collection_Id IS NULL THEN
				RAISE 'DNS_Domain_Collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;

	ELSIF v_prop.Permit_DNS_Domain_Collection_Id = 'PROHIBITED' THEN
			IF NEW.DNS_Domain_Collection_Id IS NOT NULL THEN
				RAISE 'DNS_Domain_Collection_Id is prohibited.'
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
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('service_manip', 'direct_connect_endpoint_to_device');
SELECT schema_support.save_grants_for_replay('service_manip', 'direct_connect_endpoint_to_device');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS service_manip.direct_connect_endpoint_to_device ( integer,integer,integer,integer,integer,integer,integer,boolean );
CREATE OR REPLACE FUNCTION service_manip.direct_connect_endpoint_to_device(device_id integer, service_version_id integer, service_environment_id integer, service_endpoint_id integer DEFAULT NULL::integer, port_range_id integer DEFAULT NULL::integer, dns_record_id integer DEFAULT NULL::integer, service_sla_id integer DEFAULT NULL::integer, is_primary boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_in_device_id			ALIAS FOR device_id;
	_in_service_endpoint_id	ALIAS FOR service_endpoint_id;
	_in_service_version_id	ALIAS FOR service_version_id;
	_in_port_range_id		ALIAS FOR port_range_id;
	_in_dns_record_id		ALIAS FOR dns_record_id;
	_s			service%ROWTYPE;
	_sv			service_version%ROWTYPE;
	_si			service_instance%ROWTYPE;
	_send		service_endpoint%ROWTYPE;
	_senv		service_endpoint%ROWTYPE;
	_sep		service_endpoint_provider%ROWTYPE;
	_sepc		service_endpoint_provider_collection%ROWTYPE;
BEGIN
	SELECT * INTO _sv
	FROM service_version sv
	WHERE sv.service_version_id = _in_service_version_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Did not find service_version'
			USING ERRCODE = 'foreign_key_violation';
	END IF;
	SELECT * INTO _s
	FROM service s
	WHERE s.service_id = _sv.service_version_id;

	IF _in_service_endpoint_id IS NOT NULL THEN
		SELECT * INTO _send
		FROM service_endpoint se
		WHERE se.service_endpoint_id = _in_service_endpoint_id;


		IF NOT FOUND THEN
			RAISE EXCEPTION 'service_endpoint_id not found'
			USING ERRCODE = 'foreign_key_violation';
		END IF;

		IF _send.service_id != _sv.service_id THEN
			RAISE EXCEPTION 'service of service_endpoint and service_version do not match'
			USING ERRCODE = 'foreign_key_violation',
			HINT = format('%s v %s', _send.service_id, _sv.service_id);
		END IF;
	ELSE
		--- XXX probably need to revisit.
		IF _in_dns_record_id IS NULL THEN
			RAISE EXCEPTION 'Need to set dns_record_id and port_range_id. This may be revisited'
				USING ERRCODE = 'not_null_violation';
		END IF;
		IF _in_port_range_id IS NULL THEN
			RAISE EXCEPTION 'Need to set port_range_id and dns_record_id. This may be revisited'
				USING ERRCODE = 'not_null_violation';
		END IF;

		INSERT INTO service_endpoint (
			service_id, dns_record_id, port_range_id
		) SELECT
			_sv.service_id, dr.dns_record_id, pr.port_range_id
		FROM port_range pr, dns_record dr
		WHERE pr.port_range_id = _in_port_range_id
		AND dr.dns_record_id = _in_dns_record_id
		RETURNING * INTO _send;
	END IF;

	IF _send IS NULL THEN
		RAISE EXCEPTION '_send is NULL.  This should not happen.';
	END IF;

	INSERT INTO service_endpoint_provider (
		service_endpoint_provider_name, service_endpoint_provider_type,
        dns_record_id
	) SELECT concat(_s.service_name, concat_ws('.', dns_name, dns_domain_name), '-', port_range_name), 'direct',
		dr.dns_record_id
	FROM    dns_record dr JOIN dns_domain dd USING (dns_domain_id),
		port_range pr
	WHERE dr.dns_record_id = _send.dns_record_id
	AND pr.port_range_id = _send.port_range_id
	RETURNING * INTO _sep;

	IF _sep IS NULL THEN
		RAISE EXCEPTION 'Failed to insert into service_endpoint_provider.  This should not happen';
	END IF;

	INSERT INTO service_endpoint_provider_collection (
		service_endpoint_provider_collection_name,
		service_endpoint_provider_collection_type
	) SELECT
		_sep.service_endpoint_provider_name,
		'per-service-endpoint-provider'
	RETURNING * INTO _sepc;

	INSERT INTO service_endpoint_service_endpoint_provider_collection (
		service_endpoint_id, service_endpoint_provider_collection_id,
		service_endpoint_relation_type
	) VALUES (
		_send.service_endpoint_id, _sepc.service_endpoint_provider_collection_id,
		'direct'
	);

	INSERT INTO service_endpoint_provider_collection_service_endpoint_provider(
		service_endpoint_provider_collection_id,
		service_endpoint_provider_id
	) VALUES (
		_sepc.service_endpoint_provider_collection_id,
		_sep.service_endpoint_provider_id
	);

	INSERT INTO service_instance (
		device_id,
		service_version_id, service_environment_id, is_primary
	) VALUES (
		_in_device_id,
		_sv.service_version_id, service_environment_id, is_primary
	) RETURNING * INTO _si;

	INSERT INTO service_endpoint_provider_service_instance (
		service_endpoint_provider_id,
		service_instance_id,
		port_range_id
	) VALUES (
		_sep.service_endpoint_provider_id,
		_si.service_instance_id,
		_send.port_range_id
	);

	-- XXX need to handle if one is set and the other is not
	IF service_sla_id IS NOT NULL AND service_environment_id IS NOT NULL
	THEN
		INSERT INTO service_endpoint_service_sla (
			service_endpoint_id, service_sla_id,
			service_environment_id
		) VALUES (
			_send.service_endpoint_id, service_sla_id,
			service_environment_id
		);
	END IF;

	RETURN _si.service_instance_id;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'service_manip' AND type = 'function' AND object IN ('direct_connect_endpoint_to_device');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc direct_connect_endpoint_to_device failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_service_manip']);
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('service_manip', 'add_new_child_service_endpoint');
DROP FUNCTION IF EXISTS service_manip.add_new_child_service_endpoint ( integer,text,integer,integer,integer[] );
CREATE OR REPLACE FUNCTION service_manip.add_new_child_service_endpoint(service_endpoint_id integer, service_endpoint_uri_fragment text, service_version_id integer, service_environment_id integer, device_ids integer[] DEFAULT NULL::integer[])
 RETURNS integer[]
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_in_service_endpoint_id		ALIAS FOR service_endpoint_id;
	_in_service_version_id		ALIAS FOR service_version_id;
	_in_service_environment_id	ALIAS FOR service_environment_id;
	_in_url_frag				ALIAS FOR service_endpoint_uri_fragment;
	_se							service_endpoint;
	_rv							INTEGER[];
	_dvs						INTEGER[];
	_sepid						INTEGER;
	_prid						INTEGER;
BEGIN
	IF service_endpoint_uri_fragment IS NULL THEN
		RAISE EXCEPTION 'must provide service_endpoint_uri_fragment'
			USING ERRCODE = 'not_null_violation';
	END IF;

	SELECT se.* INTO _se
	FROM service_endpoint se
	WHERE se.service_endpoint_uri_fragment = _in_url_frag
	AND (se.service_endpoint_id, se.dns_record_id)
		IN (
			SELECT ise.service_endpoint_id, ise.dns_record_id
			FROM service_endpoint ise
			WHERE ise.service_endpoint_id = _in_service_endpoint_id
		);

	IF NOT FOUND THEN
		INSERT INTO service_endpoint (
			service_id, dns_record_id, port_range_id, service_endpoint_uri_fragment
		) SELECT sv.service_id, se.dns_record_id, se.port_range_id, _in_url_frag
		FROM service_version sv, service_endpoint se
		WHERE sv.service_version_Id = _in_service_version_id
		AND se.service_endpoint_id = _in_service_endpoint_id
		RETURNING * INTO _se;

		INSERT INTO service_endpoint_service_endpoint_provider_collection (
			service_endpoint_id, service_endpoint_provider_collection_id,
			service_endpoint_relation_type, service_endpoint_relation_key,
			weight, maximum_capacity, is_enabled
		) SELECT _se.service_endpoint_id, service_endpoint_provider_collection_id,
			service_endpoint_relation_type, service_endpoint_relation_key,
			weight, maximum_capacity, is_enabled
		FROM service_endpoint_service_endpoint_provider_collection o
		WHERE o.service_endpoint_id = _in_service_endpoint_id;

		RAISE NOTICE 'se is %', to_jsonb(_se);
	END IF;

	_dvs := device_ids;
	IF _dvs IS NULL THEN
		SELECT service_endpoint_provider_id, se.port_range_id,
			array_agg(device_id ORDER BY device_id)
			INTO _sepid, _prid, _dvs
			FROM service_endpoint se
				JOIN service_endpoint_service_endpoint_provider_collection
					USING (service_endpoint_id)
				JOIN service_endpoint_provider_collection_service_endpoint_provider
					USING (service_endpoint_provider_collection_id)
				JOIN service_endpoint_provider
					USING (service_endpoint_provider_id)
				JOIN service_endpoint_provider_service_instance
					USING (service_endpoint_provider_id)
				JOIN service_instance USING (service_instance_id)
				JOIN service_version USING (service_version_id, service_id)
			WHERE se.service_endpoint_id = _in_service_endpoint_id
			GROUP BY 1, 2;
	RAISE NOTICE '% %', _in_service_endpoint_id, _dvs;
	END IF;


	WITH si AS (
		INSERT INTO service_instance (
			device_id, service_version_id, service_environment_id, is_primary
		) VALUES (
			unnest(_dvs), _in_service_version_id, service_environment_id, false
		) RETURNING *
	), sepsi AS (
		INSERT INTO service_endpoint_provider_service_instance (
			service_endpoint_provider_id, service_instance_id, port_range_id
		) SELECT _sepid, service_instance_id, _prid
			FROM si
			RETURNING *
	) SELECT array_agg(service_instance_id) INTO _rv FROM sepsi;

	RETURN _rv;
END
$function$
;

-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('service_manip', 'remove_service_instance');
DROP FUNCTION IF EXISTS service_manip.remove_service_instance ( integer );
CREATE OR REPLACE FUNCTION service_manip.remove_service_instance(service_instance_id integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_in_si_id	ALIAS FOR service_instance_id;
	_r			RECORD;
	_sep		service_endpoint_provider;
	_sepcsep	service_endpoint_provider_collection_service_endpoint_provider;
	_sesepc		service_endpoint_service_endpoint_provider_collection;
BEGIN
	FOR _r IN SELECT * FROM service_endpoint_provider_service_instance sepsi
		WHERE sepsi.service_instance_id = _in_si_id
	LOOP
		SELECT * INTO _sep FROM service_endpoint_provider sep WHERE
			sep.service_endpoint_provider_id = _r.service_endpoint_provider_id;
		DELETE FROM service_endpoint_provider_service_instance
		WHERE service_endpoint_provider_service_instance_id =
			_r.service_endpoint_provider_service_instance_id;

		DELETE FROM service_endpoint_provider_collection_service_endpoint_provider sepcsep
		WHERE sepcsep.service_endpoint_provider_id =
			_r.service_endpoint_provider_id
			RETURNING * INTO _sepcsep;

		IF _sep.service_endpoint_provider_type = 'direct' THEN

			DELETE FROM service_endpoint_service_endpoint_provider_collection sesepc
			WHERE sesepc.service_endpoint_provider_collection_id =
				_sepcsep.service_endpoint_provider_collection_id
				RETURNING * INTO _sesepc;

			DELETE FROM service_endpoint_provider_collection
			WHERE service_endpoint_provider_collection_id =
				_sepcsep.service_endpoint_provider_collection_id;


			DELETE FROM service_endpoint_provider WHERE
				service_endpoint_provider_id = _sep.service_endpoint_provider_id;

			DELETE FROM service_endpoint_service_sla
			WHERE service_endpoint_id = _sesepc.service_endpoint_id;

			DELETE FROM service_endpoint
			WHERE service_endpoint_id = _sesepc.service_endpoint_id;

		ELSE
			DELETE FROM service_endpoint_provider_service_instance WHERE
				service_endpoint_provider_id = _sep.service_endpoint_provider_id;
			DELETE FROM service_endpoint_provider WHERE
				service_endpoint_provider_id = _sep.service_endpoint_provider_id;
		END IF;

	END LOOP;

	DELETE FROM service_instance si WHERE si.service_instance_id = _in_si_id;
	RETURN true;
END;
$function$
;

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
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('x509_manip', 'insert_csr');
SELECT schema_support.save_grants_for_replay('x509_manip', 'insert_csr');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS x509_manip.insert_csr ( text,jsonb,jsonb );
CREATE OR REPLACE FUNCTION x509_manip.insert_csr(csr text, parsed jsonb DEFAULT NULL::jsonb, public_key_hashes jsonb DEFAULT NULL::jsonb)
 RETURNS jazzhands.certificate_signing_request
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_csr			certificate_signing_request;
	_parsed			JSONB;
	_pubkeyhashes	JSONB;
	_pkid			private_key.private_key_id%TYPE;
	_ca				x509_signed_certificate.x509_signed_certificate_id%TYPE;
	_e				JSONB;
	field			TEXT;
BEGIN
	BEGIN
		_parsed := x509_plperl_cert_utils.parse_csr(
			certificate_signing_request := insert_csr.csr
		);

		_pubkeyhashes := x509_plperl_cert_utils.get_csr_hashes(
			insert_csr.csr
		);

		IF parsed IS NOT NULL OR public_key_hashes IS NOT NULL THEN
			RAISE EXCEPTION 'Database is configured to parse the CSR, so the second option is not permitted'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF _parsed IS NULL OR _pubkeyhashes IS NULL THEN
			RAISE EXCEPTION 'Certificate Signing Request is invalid or something fundemental was wrong with parsing' 
				USING ERRCODE = 'data_exception';
		END IF;
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		IF parsed IS NULL OR public_key_hashes IS NULL THEN
			RAISE EXCEPTION 'Must pass summary/fingerprint json about CSR because pl/perl module not setup.'
				USING ERRCODE = 'invalid_parameter_value',
				HINT = format('%s %s', SQLSTATE, SQLERRM);
		ELSE
			_parsed := parsed;
			_pubkeyhashes := public_key_hashes;
		END IF;
	END;

	FOREACH field IN ARRAY ARRAY[
		'subject',
		'friendly_name']
	LOOP
		IF NOT _parsed ? field THEN
			RAISE EXCEPTION 'Must include % parameter', field
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END LOOP;

	FOR _e IN SELECT jsonb_array_elements(_pubkeyhashes)
	LOOP
		SELECT pk.private_key_id
		INTO _pkid
		FROM	private_key pk
			JOIN public_key_hash USING (public_key_hash_id)
			JOIN public_key_hash_hash USING (public_key_hash_id)
			LEFT JOIN x509_signed_certificate x509 USING (public_key_hash_id)
		WHERE cryptographic_hash_algorithm = _e->>'algorithm'
		AND calculated_hash = _e->>'hash'
		ORDER BY 
			CASE WHEN x509.is_active THEN 0 ELSE 1 END,
			CASE WHEN x509.x509_signed_certificate_id IS NULL THEN 0 ELSE 1 END,
			pk.data_upd_date desc, pk.data_ins_date desc;
		IF FOUND THEN
			EXIT;
		END IF;
	END LOOP;

	INSERT INTO certificate_signing_request (
		friendly_name, subject, certificate_signing_request, private_key_id
	) VALUES (
		_parsed->>'friendly_name', _parsed->>'subject', csr, _pkid
	) RETURNING * INTO _csr;

	RETURN _csr;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'x509_manip' AND type = 'function' AND object IN ('insert_csr');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc insert_csr failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('x509_manip', 'insert_x509_certificate');
SELECT schema_support.save_grants_for_replay('x509_manip', 'insert_x509_certificate');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS x509_manip.insert_x509_certificate ( text,jsonb,jsonb );
CREATE OR REPLACE FUNCTION x509_manip.insert_x509_certificate(certificate text, parsed jsonb DEFAULT NULL::jsonb, public_key_hashes jsonb DEFAULT NULL::jsonb)
 RETURNS jazzhands.x509_signed_certificate
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_x509			x509_signed_certificate;
	_parsed			JSONB;
	_pubkeyhashes	JSONB;
	_pkid			private_key.private_key_id%TYPE;
	_csrid			private_key.private_key_id%TYPE;
	_ca				x509_signed_certificate.x509_signed_certificate_id%TYPE;
	_caserial		NUMERIC(1000);
	_e				JSONB;
	field			TEXT;
BEGIN
	BEGIN
		_parsed := x509_plperl_cert_utils.parse_x509_certificate(
			certificate := insert_x509_certificate.certificate
		);

		_pubkeyhashes := x509_plperl_cert_utils.get_public_key_hashes(
			insert_x509_certificate.certificate
		);

		IF parsed IS NOT NULL OR public_key_hashes IS NOT NULL THEN
			RAISE EXCEPTION 'Database is configured to parse the certificate, so the second option is not permitted'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF _parsed IS NULL OR _pubkeyhashes IS NULL THEN
			RAISE EXCEPTION 'X509 Certificate is invalid or something fundemental was wrong with parsing' 
				USING ERRCODE = 'data_exception';
		END IF;
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		IF parsed IS NULL OR public_key_hashes IS NULL THEN
			RAISE EXCEPTION 'Must pass summary/fingerprint json about certificate because pl/perl module not setup.'
				USING ERRCODE = 'invalid_parameter_value',
				HINT = format('%s %s', SQLSTATE, SQLERRM);
		ELSE
			_parsed := parsed;
			_pubkeyhashes := public_key_hashes;
		END IF;
	END;

	FOREACH field IN ARRAY ARRAY[
		'self_signed',
		'subject',
		'friendly_name',
		'subject_key_identifier',
		'is_ca',
		'valid_from', 
		'valid_to']
	LOOP
		IF NOT _parsed ? field THEN
			RAISE EXCEPTION 'Must include % parameter', field
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END LOOP;

	---
	--- arguably self signing certs should point to themselves...
	---
	IF _parsed->>'self_signed' IS NULL THEN
		IF NOT _parsed ? 'issuer' OR _parsed->>'issuer' IS NULL THEN
			RAISE EXCEPTION 'Must include issuer'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF NOT _parsed ? 'serial' OR _parsed->>'serial' IS NULL THEN
			RAISE EXCEPTION 'Must serial number'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		SELECT x509_signed_certificate_id
		INTO _ca
		FROM x509_signed_certificate
		WHERE subject = _parsed->>'issuer'
		AND subject_key_identifier = _parsed->>'authority_key_identifier'
		LIMIT 1;

		_caserial := hex_to_numeric(_parsed->>'serial');
	ELSE
		_ca := NULL;
		_caserial := NULL;
	END IF;
		

	FOR _e IN SELECT jsonb_array_elements(_pubkeyhashes)
	LOOP
		SELECT pk.private_key_id
		INTO _pkid
		FROM	private_key pk
			JOIN public_key_hash USING (public_key_hash_id)
			JOIN public_key_hash_hash USING (public_key_hash_id)
			LEFT JOIN x509_signed_certificate x509 USING (public_key_hash_id)
		WHERE cryptographic_hash_algorithm = _e->>'algorithm'
		AND calculated_hash = _e->>'hash'
		ORDER BY 
			CASE WHEN x509.is_active THEN 0 ELSE 1 END,
			CASE WHEN x509.x509_signed_certificate_id IS NULL THEN 0 ELSE 1 END,
			pk.data_upd_date desc, pk.data_ins_date desc;
		IF FOUND THEN
			EXIT;
		END IF;
	END LOOP;

	--- This is kind of gross because it just finds the newest one and
	---	associates it
	FOR _e IN SELECT jsonb_array_elements(_pubkeyhashes)
	LOOP
		SELECT csr.certificate_signing_request_id
		INTO _csrid
		FROM	certificate_signing_request csr
			JOIN public_key_hash USING (public_key_hash_id)
			JOIN public_key_hash_hash USING (public_key_hash_id)
			LEFT JOIN x509_signed_certificate x509 USING (public_key_hash_id)
		WHERE cryptographic_hash_algorithm = _e->>'algorithm'
		AND calculated_hash = _e->>'hash'
		ORDER BY 
			CASE WHEN x509.is_active THEN 0 ELSE 1 END,
			CASE WHEN x509.x509_signed_certificate_id IS NULL THEN 0 ELSE 1 END,
			csr.data_upd_date desc, csr.data_ins_date desc;

		IF FOUND THEN
			EXIT;
		END IF;
	END LOOP;

	INSERT INTO x509_signed_certificate (
		x509_certificate_type, subject, friendly_name, 
		subject_key_identifier,
		is_certificate_authority,
		signing_cert_id, x509_ca_cert_serial_number,
		public_key, certificate_signing_request_id, private_key_id,
		valid_from, valid_to
	) VALUES (
		'default', _parsed->>'subject', _parsed->>'friendly_name',
		_parsed->>'subject_key_identifier',
		CASE WHEN _parsed->>'is_ca' IS NULL THEN false ELSE true END,
		_ca, _caserial,
		insert_x509_certificate.certificate, _csrid, _pkid,
		CAST(_parsed->>'valid_from' AS TIMESTAMP),
		CAST(_parsed->>'valid_to' AS TIMESTAMP)
	) RETURNING * INTO _x509;

	FOR _e IN SELECT jsonb_array_elements(_parsed->'keyUsage')
	LOOP
			---
			--- This is a little wonky.
			---
		    INSERT INTO x509_key_usage_attribute (
			 	x509_signed_certificate_id, x509_key_usage, 
				x509_key_usgage_category
			) SELECT _x509.x509_signed_certificate_id, _e #>>'{}',
				x509_key_usage_category
			FROM x509_key_usage_categorization
			WHERE x509_key_usage_category =  _e #>>'{}'
			ORDER BY 
				CASE WHEN x509_key_usage_category = 'ca' THEN 1
					WHEN x509_key_usage_category = 'revocation' THEN 2
					WHEN x509_key_usage_category = 'application' THEN 3
					WHEN x509_key_usage_category = 'service' THEN 4
					ELSE 5 END,
				x509_key_usage_category
			LIMIT 1;
	END LOOP;

	RETURN _x509;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'x509_manip' AND type = 'function' AND object IN ('insert_x509_certificate');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc insert_x509_certificate failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_manip']);
--
-- Process middle (non-trigger) schema x509_plperl_cert_utils
--
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('x509_plperl_cert_utils', 'parse_csr');
SELECT schema_support.save_grants_for_replay('x509_plperl_cert_utils', 'parse_csr');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS x509_plperl_cert_utils.parse_csr ( text );
CREATE OR REPLACE FUNCTION x509_plperl_cert_utils.parse_csr(certificate_signing_request text)
 RETURNS jsonb
 LANGUAGE plperl
AS $function$
    my $csr_pem = shift || return undef;

    my $tmp = File::Temp->new();
    print $tmp $csr_pem;
    my $fname = $tmp->filename();
    $tmp->close;

    my $req = Crypt::OpenSSL::PKCS10->new_from_file($fname) || return undef;

    my $friendly = $req->subject;
    $friendly =~ s/^.*CN=(\s*[^,]*)(,.*)?$/$1/;

    my $rv = {
        friendly_name => $friendly,
        subject       => $req->subject(),
    };

    # this is naaaasty but I did not want to require the JSON pp module
    my $x = sprintf "{ %s }", join(
        ',',
        map {
            qq{"$_": }
              . (
                ( defined( $rv->{$_} ) )
                ? (
                    ( ref( $rv->{$_} ) eq 'ARRAY' )
                    ? '[ ' . join( ',', @{ $rv->{$_} } ) . ' ]'
                    : qq{"$rv->{$_}"}
                  )
                : 'null'
              )
        } keys %$rv
    );

    $x;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'x509_plperl_cert_utils' AND type = 'function' AND object IN ('parse_csr');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc parse_csr failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_x509_plperl_cert_utils']);
--
-- Process middle (non-trigger) schema audit
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_audit']);
--
-- Process middle (non-trigger) schema jazzhands_legacy
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy']);
--
-- Process middle (non-trigger) schema authorization_utils
--
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_authorization_utils']);
-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('authorization_utils', 'check_device_ip_address');
DROP FUNCTION IF EXISTS authorization_utils.check_device_ip_address ( inet,integer,character varying,boolean );
CREATE OR REPLACE FUNCTION authorization_utils.check_device_ip_address(ip_address inet, device_id integer DEFAULT NULL::integer, device_name character varying DEFAULT NULL::character varying, raise_exception boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_in_ip		ALIAS FOR ip_address;
	_in_dname	ALIAS FOR device_name;
	_did		device.device_id%TYPE;
BEGIN
	IF device_id IS NOT NULL AND device_name IS NOT NULL THEN
		RAISE EXCEPTION 'Must specify only either device_id or device-name'
			USING ERRCODE = 'invalid_parameter_value';
	ELSIF device_id IS NOT NULL THEN
		_did := device_Id;
	ELSIF device_name IS NOT NULL THEN
		SELECT	d.device_id
		INTO	_did
		FROM	device d
		WHERE	d.device_name IS NOT DISTINCT FROM _in_dname;

		IF NOT FOUND THEN
			IF raise_exception THEN
				RAISE EXCEPTION 'Unknown device %', _in_dname
					USING ERRCODE = 'foreign_key_violation';
			ELSE
				RETURN false;
			END IF;
		END IF;
	ELSE
		RAISE EXCEPTION 'Must specify either a device id or name'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	PERFORM * FROM (
		SELECT n.ip_address, lin.device_id
		FROM
			jazzhands.netblock n
			JOIN jazzhands.layer3_interface_netblock lin USING (netblock_id)
		UNION
		SELECT n.ip_address, l3i.device_id
		FROM jazzhands.netblock n
			JOIN jazzhands.shared_netblock USING (netblock_id)
			JOIN jazzhands.shared_netblock_layer3_interface
				USING (shared_netblock_id)
			JOIN jazzhands.layer3_interface l3i USING (layer3_interface_Id)
	) alltheips
	WHERE host(alltheips.ip_address) = host(_in_ip)
	AND alltheips.device_Id = _did;

	IF FOUND THEN
		RETURN true;
	END IF;

	RETURN false;
END;
$function$
;

-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('authorization_utils', 'check_dns_name_role');
DROP FUNCTION IF EXISTS authorization_utils.check_dns_name_role ( text,text,boolean );
CREATE OR REPLACE FUNCTION authorization_utils.check_dns_name_role(property_role text, fqdn text, raise_exception boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_j		JSONB;
	_did	INTEGER;
BEGIN
	SELECT dns_utils.find_dns_domain_from_fqdn(fqdn) INTO _j;

	IF _j IS NULL THEN
		IF raise_exception THEN
			RAISE EXCEPTION '% maps to an unknown dns domain', fqdn
				USING ERRCODE = 'foreign_key_violation';
		ELSE
			RETURN false;
		END IF;
	END IF;

	PERFORM *
	FROM jazzhands.property
		JOIN jazzhands.dns_domain_collection USING (dns_domain_collection_id)
		JOIN jazzhands.dns_domain_collection_dns_domain USING (dns_domain_collection_id)
	WHERE dns_domain_id = CAST(_j->>'dns_domain_id' AS integer)
		AND property_type = split_part(property_role, ':', 1)
		AND property_name = split_part(property_role, ':', 2);

	IF FOUND THEN
		RETURN true;
	END IF;

	RETURN false;
END;
$function$
;

-- New function; dropping in case it returned because of type change
SELECT schema_support.save_grants_for_replay('authorization_utils', 'check_property_account_authorization');
DROP FUNCTION IF EXISTS authorization_utils.check_property_account_authorization ( jsonb );
CREATE OR REPLACE FUNCTION authorization_utils.check_property_account_authorization(parameters jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_arid	account_realm.account_realm_id%type;
	_aid	account_realm.account_realm_id%type;
BEGIN
	IF parameters?'login' AND parameters?'account_id' THEN
		RAISE EXCEPTION 'Must specify either login or account_id, not both.'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	IF NOT parameters?'login' AND NOT parameters?'account_id' THEN
		RAISE EXCEPTION 'Must specify one of login or account_id, not both.'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	IF parameters?'device_id' OR parameters?'device_name' THEN
		RAISE EXCEPTION 'Device support not implemented yet, but should be.'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	IF NOT parameters?'property_role' THEN
		RAISE EXCEPTION 'Must specify property role'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF parameters?'account_realm_id' AND parameters?'account_realm_name' THEN
		RAISE EXCEPTION
			'Must specify either account_realm_id or account_realm_name'
			USING ERRCODE = 'invalid_parameter_value';
	ELSIF parameters?'account_realm_id' THEN
		_arid := parameters->>'account_realm_id';
	ELSIF parameters?'account_realm_name' THEN
		SELECT	account_realm_id
		INTO	_arid
		WHERE	account_realm_name IS NOT DISTINCT FROM
			parameters->>'account_realm_name';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'account_realm % not found',
				parameters->>'account_realm_name'
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	ELSE
		SELECT	account_realm_id
		INTO	_arid
		FROM	property
		WHERE	property_type = 'Defaults'
		AND		property_name = '_root_account_realm_id';
	END IF;

	IF parameters?'account_id' AND parameters?'login' THEN
		RAISE EXCEPTION
			'Must specify either account_id or login'
			USING ERRCODE = 'invalid_parameter_value';
	ELSIF parameters?'account_id' THEN
		_aid := parameters->>'account_id';
	ELSIF parameters?'login' THEN
		SELECT	account_id
		INTO	_aid
		FROM	account
		WHERE	login IS NOT DISTINCT FROM parameters->>'login'
		AND		account_realm_id = _arid;
	ELSE
		RAISE EXCEPTION 'must specify a user to check for'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	PERFORM *
	FROM (
		SELECT
			account_collection_id,
			property_type,
			property_name
		FROM
			jazzhands.property) p
		JOIN jazzhands.v_account_collection_account_expanded USING (account_collection_id)
		JOIN jazzhands.account_collection USING (account_collection_id)
		JOIN jazzhands.account USING (account_id)
	WHERE
		property_type = split_part(parameters->>'property_role', ':', 1)
		AND property_name = split_part(parameters->>'property_role', ':', 2)
		AND account_Id = _aid
		AND account_realm_Id = _arid;

	IF FOUND THEN
		RETURN true;
	END IF;

	RETURN false;
END;
$function$
;

-- Processing tables in main schema...
select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_service_version_collection_purpose (jazzhands)
CREATE TABLE jazzhands.val_service_version_collection_purpose
(
	service_version_collection_purpose	varchar(255) NOT NULL,
	description	varchar(4096)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'val_service_version_collection_purpose', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_service_version_collection_purpose ADD CONSTRAINT pk_val_service_version_collection_purpose PRIMARY KEY (service_version_collection_purpose);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_service_version_collection_purpose and jazzhands.service_version_collection_purpose
-- Skipping this FK since column does not exist yet
--ALTER TABLE jazzhands.jazzhands.service_version_collection_purpose
--	ADD CONSTRAINT fkl_service_version_collection_purpose_purpose
--	FOREIGN KEY (service_version_collection_purpose) REFERENCES jazzhands.val_service_version_collection_purpose(service_version_collection_purpose);


-- FOREIGN KEYS TO

-- TRIGGERS
DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('val_service_version_collection_purpose');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for val_service_version_collection_purpose  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_service_version_collection_purpose');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'val_service_version_collection_purpose');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'val_service_version_collection_purpose');
--
-- Copying initialization data
--

INSERT INTO val_service_version_collection_purpose (
service_version_collection_purpose,description
) VALUES
	('all','all services for a given service'),
	('current','current services for a given service; for when a release does an overhaul from the db perspective')
;
-- DONE DEALING WITH TABLE val_service_version_collection_purpose (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_service_version_collection_purpose');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old val_service_version_collection_purpose failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('val_service_version_collection_purpose');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new val_service_version_collection_purpose failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE device_layer2_network

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.device_layer2_network DROP CONSTRAINT IF EXISTS fk_device_l2_net_devid;
ALTER TABLE jazzhands.device_layer2_network DROP CONSTRAINT IF EXISTS fk_device_l2_net_l2netid;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands',  object := 'device_layer2_network');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.device_layer2_network DROP CONSTRAINT IF EXISTS pk_device_layer2_network;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_device_l2_net_devid";
DROP INDEX IF EXISTS "jazzhands"."xif_device_l2_net_l2netid";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_device_layer2_network ON jazzhands.device_layer2_network;
DROP TRIGGER IF EXISTS trigger_audit_device_layer2_network ON jazzhands.device_layer2_network;
DROP FUNCTION IF EXISTS perform_audit_device_layer2_network();
-- default sequences associations and sequences (values rebuilt at end, if needed)
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands', object := 'device_layer2_network', tags := ARRAY['table_device_layer2_network']);
---- BEGIN jazzhands_audit.device_layer2_network TEARDOWN
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_audit', object := 'device_layer2_network', tags := ARRAY['table_device_layer2_network']);

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay(schema := 'jazzhands_audit',  object := 'device_layer2_network');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands_audit.device_layer2_network DROP CONSTRAINT IF EXISTS device_layer2_network_pkey;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands_audit"."aud_device_layer2_network_pk_device_layer2_network";
DROP INDEX IF EXISTS "jazzhands_audit"."device_layer2_network_aud#realtime_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."device_layer2_network_aud#timestamp_idx";
DROP INDEX IF EXISTS "jazzhands_audit"."device_layer2_network_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
-- default sequences associations and sequences (values rebuilt at end, if needed)
-- The value of this sequence is restored based on the column at migration end
ALTER TABLE jazzhands_audit.device_layer2_network ALTER COLUMN "aud#seq" DROP IDENTITY;
---- DONE jazzhands_audit.device_layer2_network TEARDOWN


ALTER TABLE device_layer2_network RENAME TO device_layer2_network_v97;
ALTER TABLE jazzhands_audit.device_layer2_network RENAME TO device_layer2_network_v97;

DROP TABLE IF EXISTS device_layer2_network_v97;
DROP TABLE IF EXISTS jazzhands_audit.device_layer2_network_v97;
-- DONE DEALING WITH OLD TABLE device_layer2_network (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('device_layer2_network');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old device_layer2_network failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('device_layer2_network');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped device_layer2_network failed but that is ok';
	NULL;
END;
$$;

select clock_timestamp(), clock_timestamp() - now() AS len;
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE service_version_collection_purpose (jazzhands)
CREATE TABLE jazzhands.service_version_collection_purpose
(
	service_version_collection_id	integer NOT NULL,
	service_version_collection_purpose	varchar(255) NOT NULL,
	service_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('jazzhands_audit', 'jazzhands', 'service_version_collection_purpose', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.service_version_collection_purpose ADD CONSTRAINT ak_service_version_collection_purpose_service UNIQUE (service_version_collection_purpose, service_version_collection_id);
ALTER TABLE jazzhands.service_version_collection_purpose ADD CONSTRAINT pk_service_version_collection_purpose PRIMARY KEY (service_version_collection_id, service_version_collection_purpose);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifkl_service_version_collection_purpose_purpose ON jazzhands.service_version_collection_purpose USING btree (service_version_collection_purpose);
CREATE INDEX xifservice_version_collection_purpose_service ON jazzhands.service_version_collection_purpose USING btree (service_id);
CREATE INDEX xifservice_version_collection_purpose_service_version_collectio ON jazzhands.service_version_collection_purpose USING btree (service_version_collection_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK service_version_collection_purpose and service
ALTER TABLE jazzhands.service_version_collection_purpose
	ADD CONSTRAINT fk_service_version_collection_purpose_service
	FOREIGN KEY (service_id) REFERENCES jazzhands.service(service_id);
-- consider FK service_version_collection_purpose and service_version_collection
ALTER TABLE jazzhands.service_version_collection_purpose
	ADD CONSTRAINT fk_service_version_collection_purpose_service_version_collectio
	FOREIGN KEY (service_version_collection_id) REFERENCES jazzhands.service_version_collection(service_version_collection_id);
-- consider FK service_version_collection_purpose and val_service_version_collection_purpose
ALTER TABLE jazzhands.service_version_collection_purpose
	ADD CONSTRAINT fkl_service_version_collection_purpose_purpose
	FOREIGN KEY (service_version_collection_purpose) REFERENCES jazzhands.val_service_version_collection_purpose(service_version_collection_purpose);

-- TRIGGERS
-- considering NEW jazzhands.service_version_collection_purpose_enforce
CREATE OR REPLACE FUNCTION jazzhands.service_version_collection_purpose_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	PERFORM *
	FROM service_version sv
		JOIN service_version_collection_service_version
			USING (service_version_id)
		JOIN service_version_collection_purpose svcp
			USING (service_version_collection_Id)
	WHERE svcp.service_version_collection_purpose = 
		NEW.service_version_collection_purpose
	AND svcp.service_id != sv.service_id;

	IF FOUND THEN
		RAISE EXCEPTION 'Collections exist with a purpose associated with a difference service_id'
			USING ERRCODE = 'foreign_key_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION jazzhands.service_version_collection_purpose_enforce() FROM public;
CREATE CONSTRAINT TRIGGER trigger_service_version_collection_purpose_enforce AFTER INSERT OR UPDATE ON jazzhands.service_version_collection_purpose NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_version_collection_purpose_enforce();

DO $$
BEGIN
		DELETE FROM __recreate WHERE schema = 'jazzhands' AND object IN ('service_version_collection_purpose');
	EXCEPTION WHEN undefined_table THEN
		RAISE NOTICE 'Drop of triggers for service_version_collection_purpose  failed but that is ok';
		NULL;
END;
$$;

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'service_version_collection_purpose');
SELECT schema_support.build_audit_table_pkak_indexes('jazzhands_audit', 'jazzhands', 'service_version_collection_purpose');
SELECT schema_support.rebuild_audit_trigger('jazzhands_audit', 'jazzhands', 'service_version_collection_purpose');
-- DONE DEALING WITH TABLE service_version_collection_purpose (jazzhands)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('service_version_collection_purpose');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old service_version_collection_purpose failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands', 'jazzhands_audit') AND object IN ('service_version_collection_purpose');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of new service_version_collection_purpose failed but that is ok';
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
--- about to process device_layer2_network in set 1
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE device_layer2_network
SELECT schema_support.save_dependent_objects_for_replay(schema := 'audit', object := 'device_layer2_network', tags := ARRAY['view_device_layer2_network']);
DROP VIEW IF EXISTS audit.device_layer2_network;
-- DONE DEALING WITH OLD TABLE device_layer2_network (audit)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('device_layer2_network');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old device_layer2_network failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('device_layer2_network');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped device_layer2_network failed but that is ok';
	NULL;
END;
$$;

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
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_manip'::text, object := 'fetch_component ( integer,text,boolean,text,integer )'::text, tags := ARRAY['process_all_procs_in_schema_component_manip'::text]);
DROP FUNCTION IF EXISTS component_manip.fetch_component ( integer,text,boolean,text,integer );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_manip'::text, object := 'insert_disk_component ( text,bigint,text,text,text,text )'::text, tags := ARRAY['process_all_procs_in_schema_component_manip'::text]);
DROP FUNCTION IF EXISTS component_manip.insert_disk_component ( text,bigint,text,text,text,text );
SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_component_manip']);
--
-- Process all procs in component_utils
--
select clock_timestamp(), clock_timestamp() - now() AS len;
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'create_component_template_slots ( integer )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.create_component_template_slots ( integer );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'fetch_component ( integer,text,boolean,text,integer )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.fetch_component ( integer,text,boolean,text,integer );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'insert_component_into_parent_slot ( integer,integer,text,text,text,integer,text )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.insert_component_into_parent_slot ( integer,integer,text,text,text,integer,text );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'insert_cpu_component ( text,bigint,bigint,text,text,text )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.insert_cpu_component ( text,bigint,bigint,text,text,text );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'insert_disk_component ( text,bigint,text,text,text,text )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.insert_disk_component ( text,bigint,text,text,text,text );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'insert_memory_component ( text,bigint,bigint,text,text,text )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.insert_memory_component ( text,bigint,bigint,text,text,text );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'insert_pci_component ( integer,integer,integer,integer,text,text,text,text,text[],text,text )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.insert_pci_component ( integer,integer,integer,integer,text,text,text,text,text[],text,text );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'migrate_component_template_slots ( integer )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.migrate_component_template_slots ( integer );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'remove_component_hier ( integer,boolean )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.remove_component_hier ( integer,boolean );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'replace_component ( integer,integer )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.replace_component ( integer,integer );
SELECT schema_support.save_dependent_objects_for_replay(schema := 'component_utils'::text, object := 'set_slot_names ( integer[] )'::text, tags := ARRAY['process_all_procs_in_schema_component_utils'::text]);
DROP FUNCTION IF EXISTS component_utils.set_slot_names ( integer[] );
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
-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'create_all_services_collection');
SELECT schema_support.save_grants_for_replay('jazzhands', 'create_all_services_collection');
CREATE OR REPLACE FUNCTION jazzhands.create_all_services_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	IF TG_OP = 'INSERT' THEN
		WITH svc AS (
			INSERT INTO service_version_collection (
				service_version_collection_name, service_version_collection_type
			) VALUES
				(concat_ws(':', NEW.service_type,NEW.service_name),
					'all-services' )
			RETURNING *
		) INSERT INTO service_version_collection_purpose (
			service_version_collection_id, service_version_collection_purpose,
			service_id
		) SELECT service_version_collection_id, 'all', NEW.service_id
		FROM svc;

		WITH svc AS (
			INSERT INTO service_version_collection (
				service_version_collection_name, service_version_collection_type
			) VALUES
				(concat_ws(':', NEW.service_type,NEW.service_name),
					'current-services' )
			RETURNING *
		) INSERT INTO service_version_collection_purpose (
			service_version_collection_id, service_version_collection_purpose,
			service_id
		) SELECT service_version_collection_id, 'current', NEW.service_id
		FROM svc;
	ELSIF TG_OP = 'UPDATE' THEN
		UPDATE service_version_collection svc
			SET service_version_collection_name =
				concat_ws(':', NEW.service_type,NEW.service_name)
			FROM service_version_collection_purpose svcp
			WHERE svc.service_version_collection_id
					= svcp.service_version_collection_id
			AND service_collection_purpose IN ('all', 'current');
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM service_version_collection_purpose
		WHERE service_version_collection_purpose IN ('current', 'all')
		AND service_id = OLD.service_id;

		RETURN OLD;
	END IF;
	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('create_all_services_collection');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc create_all_services_collection failed but that is ok';
	NULL;
END;
$$;

-- Changed function
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'manip_all_svc_collection_members');
SELECT schema_support.save_grants_for_replay('jazzhands', 'manip_all_svc_collection_members');
CREATE OR REPLACE FUNCTION jazzhands.manip_all_svc_collection_members()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	IF TG_OP = 'INSERT' THEN
		INSERT INTO service_version_collection_service_version (
			service_version_collection_id, service_version_id
		) SELECT service_version_collection_id, NEW.service_version_id
		FROM service_version_collection
			JOIN service_version_collection_purpose
				USING (service_version_collection_id)
		WHERE service_version_collection_purpose IN ('all','current')
		AND service_id = NEW.service_id;
	ELSIF TG_OP = 'UPDATE' THEN
		UPDATE service_version_collection_service_version
		SET service_version_collection_id = (
			SELECT service_version_collection_id
			FROM service_version_collection_purpose
			WHERE service_id = NEW.service_id
			AND service_version_collection_purpose = 'current'
		) WHERE service_version_collection_id = (
			SELECT service_version_collection_id
			FROM service_version_collection_purpose
			WHERE service_id = OLD.service_id
			AND service_version_collection_purpose = 'current'
		);
		UPDATE service_version_collection_service_version
		SET service_version_collection_id = (
			SELECT service_version_collection_id
			FROM service_version_collection_purpose
			WHERE service_id = NEW.service_id
			AND service_version_collection_purpose = 'all'
		) WHERE service_version_collection_id = (
			SELECT service_version_collection_id
			FROM service_version_collection_purpose
			WHERE service_id = OLD.service_id
			AND service_version_collection_purpose = 'all'
		);
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM service_version_collection_service_version
		WHERE service_version_id = OLD.service_version_id
		AND service_version_collection_id IN (
			SELECT service_version_collection_id
			FROM service_version_collection
				JOIN service_version_collection_purpose
					USING (service_version_collection_id)
			WHERE service_id = OLD.service_id
			AND service_version_collection_purpose IN ( 'all', 'current' )
		);
		RETURN OLD;
	END IF;
	RETURN NEW;
END;
$function$
;

DO $$
-- not dropping regrants here.
BEGIN
	DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'function' AND object IN ('manip_all_svc_collection_members');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Drop of proc manip_all_svc_collection_members failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands']);
-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.service_version_collection_purpose_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	PERFORM *
	FROM service_version sv
		JOIN service_version_collection_service_version
			USING (service_version_id)
		JOIN service_version_collection_purpose svcp
			USING (service_version_collection_Id)
	WHERE svcp.service_version_collection_purpose = 
		NEW.service_version_collection_purpose
	AND svcp.service_id != sv.service_id;

	IF FOUND THEN
		RAISE EXCEPTION 'Collections exist with a purpose associated with a difference service_id'
			USING ERRCODE = 'foreign_key_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.service_version_collection_purpose_service_version_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	PERFORM *
	FROM service_version sv
		JOIN service_version_collection_service_version
			USING (service_version_id)
		JOIN service_version_collection_purpose svcp
			USING (service_version_collection_id)
	WHERE svcp.service_version_collection_id = NEW.service_version_collection_id	AND sv.service_Id != svcp.service_id;

	IF FOUND THEN
		RAISE EXCEPTION 'service mismatch'
			USING ERRCODE = 'foreign_key_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function; dropping in case it returned because of type change
CREATE OR REPLACE FUNCTION jazzhands.service_version_service_version_purpose_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	PERFORM *
	FROM service_version_collection_service_version
		JOIN service_version_collection_purpose svcp
			USING (service_version_collection_id)
		JOIN service_version_collection_service_version svcsv
			USING (service_version_collection_id)
	WHERE svcp.service_id != NEW.service_id
	AND svcsv.service_version_id = NEW.service_version_id;

	IF FOUND THEN
		RAISE EXCEPTION 'A service_version_collection_purpose for this service does not allow changing the service_id'
			USING ERRCODE = 'foreign_key_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

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
SELECT schema_support.save_dependent_objects_for_replay(schema := 'netblock_manip'::text, object := 'set_layer3_interface_addresses ( integer,integer,text,text,jsonb,boolean,text,text )'::text, tags := ARRAY['process_all_procs_in_schema_netblock_manip'::text]);
DROP FUNCTION IF EXISTS netblock_manip.set_layer3_interface_addresses ( integer,integer,text,text,jsonb,boolean,text,text );
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
---
--- make use of service_version_purpose
---
INSERT INTO service_version_collection_purpose (
	service_version_collection_id, service_version_collection_purpose, service_id
) SELECT service_version_collection_id, 'all', service_id
FROM service_version_collection svc
	JOIN service s ON svc.service_version_collection_name = s.service_name
WHERE service_version_collection_type = 'all-services';

INSERT INTO service_version_collection_purpose (
	service_version_collection_id, service_version_collection_purpose, service_id
) SELECT service_version_collection_id, 'current', service_id
FROM service_version_collection svc
	JOIN service s ON svc.service_version_collection_name = s.service_name
WHERE service_version_collection_type = 'current-services';

ALTER TABLE filesystem ALTER CONSTRAINT fk_filesystem_block_storage_device_id
	DEFERRABLE;

ALTER TABLE val_block_storage_device_type
	ADD CONSTRAINT check_prp_prmt_1312273807 
	CHECK (permit_component_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED')) ;

ALTER TABLE val_block_storage_device_type
	ADD CONSTRAINT check_prp_prmt_1709045498 
	CHECK (permit_logical_volume_id IN ('REQUIRED','PROHIBITED','ALLOWED'));

ALTER TABLE val_encryption_key_purpose
	ADD CONSTRAINT check_prp_prmt_790339211 
	CHECK (permit_encryption_key_db_value 
	IN ('REQUIRED','PROHIBITED','ALLOWED') ) ;

ALTER TABLE val_filesystem_type
	ADD CONSTRAINT check_prp_prmt_202454059 
	CHECK (permit_filesystem_label IN ('REQUIRED','PROHIBITED','ALLOWED') );

ALTER TABLE val_filesystem_type
	ADD CONSTRAINT check_prp_prmt_354720359 
	CHECK ( permit_mountpoint IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_filesystem_type
	ADD CONSTRAINT check_prp_prmt_388499636 
	CHECK (permit_filesystem_serial IN ('REQUIRED','PROHIBITED','ALLOWED'));


-- END Misc that does not apply to above
--
-- BEGIN: process_ancillary_schema(jazzhands_legacy)
--
--- processing view device_layer2_network in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE device_layer2_network
SELECT schema_support.save_dependent_objects_for_replay(schema := 'jazzhands_legacy', object := 'device_layer2_network', tags := ARRAY['view_device_layer2_network']);
DROP VIEW IF EXISTS jazzhands_legacy.device_layer2_network;
-- DONE DEALING WITH OLD TABLE device_layer2_network (jazzhands_legacy)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('device_layer2_network');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old device_layer2_network failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('jazzhands_legacy', 'jazzhands_audit') AND object IN ('device_layer2_network');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped device_layer2_network failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_jazzhands_legacy']);
-- DONE: process_ancillary_schema(jazzhands_legacy)
--
-- BEGIN: process_ancillary_schema(audit)
--
--- processing view device_layer2_network in ancilary schema
--------------------------------------------------------------------
-- BEGIN: DEALING WITH TABLE device_layer2_network
SELECT schema_support.save_dependent_objects_for_replay(schema := 'audit', object := 'device_layer2_network', tags := ARRAY['view_device_layer2_network']);
DROP VIEW IF EXISTS audit.device_layer2_network;
-- DONE DEALING WITH OLD TABLE device_layer2_network (audit)
--------------------------------------------------------------------
DO $$
BEGIN
	DELETE FROM __recreate WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('device_layer2_network');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of old device_layer2_network failed but that is ok';
	NULL;
END;
$$;

DO $$
BEGIN
	DELETE FROM __regrants WHERE schema IN ('audit', 'jazzhands_audit') AND object IN ('device_layer2_network');
EXCEPTION WHEN undefined_table THEN
	RAISE NOTICE 'Removal of grants on dropped device_layer2_network failed but that is ok';
	NULL;
END;
$$;

SELECT schema_support.replay_object_recreates(tags := ARRAY['process_all_procs_in_schema_audit']);
-- DONE: process_ancillary_schema(audit)
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
-- Dropping obsoleted sequences....


-- Dropping obsoleted jazzhands_audit sequences....
DROP SEQUENCE IF EXISTS jazzhands_audit.device_layer2_network_seq;


-- Processing tables with no structural changes
-- Some of these may be redundant
-- triggers
DROP TRIGGER IF EXISTS trig_account_change_realm_aca_realm ON account;
CREATE TRIGGER trig_account_change_realm_aca_realm BEFORE UPDATE OF account_realm_id ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_change_realm_aca_realm();
DROP TRIGGER IF EXISTS trig_add_account_automated_reporting_ac ON account;
CREATE TRIGGER trig_add_account_automated_reporting_ac AFTER INSERT OR UPDATE OF login, account_status ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_automated_reporting_ac();
DROP TRIGGER IF EXISTS trig_add_automated_ac_on_account ON account;
CREATE TRIGGER trig_add_automated_ac_on_account AFTER INSERT OR UPDATE OF account_type, account_role, account_status ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.automated_ac_on_account();
DROP TRIGGER IF EXISTS trig_rm_account_automated_reporting_ac ON account;
CREATE TRIGGER trig_rm_account_automated_reporting_ac BEFORE DELETE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_automated_reporting_ac();
DROP TRIGGER IF EXISTS trig_rm_automated_ac_on_account ON account;
CREATE TRIGGER trig_rm_automated_ac_on_account BEFORE DELETE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.automated_ac_on_account();
DROP TRIGGER IF EXISTS trig_userlog_account ON account;
CREATE TRIGGER trig_userlog_account BEFORE INSERT OR UPDATE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_account_enforce_is_enabled ON account;
CREATE TRIGGER trigger_account_enforce_is_enabled BEFORE INSERT OR UPDATE OF account_status, is_enabled ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_enforce_is_enabled();
DROP TRIGGER IF EXISTS trigger_account_status_per_row_after_hooks ON account;
CREATE TRIGGER trigger_account_status_per_row_after_hooks AFTER UPDATE OF account_status ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_status_per_row_after_hooks();
DROP TRIGGER IF EXISTS trigger_account_validate_login ON account;
CREATE TRIGGER trigger_account_validate_login BEFORE INSERT OR UPDATE OF login ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_validate_login();
DROP TRIGGER IF EXISTS trigger_audit_account ON account;
CREATE TRIGGER trigger_audit_account AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account();
DROP TRIGGER IF EXISTS trigger_create_new_unix_account ON account;
CREATE TRIGGER trigger_create_new_unix_account AFTER INSERT ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.create_new_unix_account();
DROP TRIGGER IF EXISTS trigger_delete_peraccount_account_collection ON account;
CREATE TRIGGER trigger_delete_peraccount_account_collection BEFORE DELETE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.delete_peraccount_account_collection();
DROP TRIGGER IF EXISTS trigger_update_peraccount_account_collection ON account;
CREATE TRIGGER trigger_update_peraccount_account_collection AFTER INSERT OR UPDATE ON jazzhands.account FOR EACH ROW EXECUTE FUNCTION jazzhands.update_peraccount_account_collection();
DROP TRIGGER IF EXISTS trig_userlog_account_assigned_certificate ON account_assigned_certificate;
CREATE TRIGGER trig_userlog_account_assigned_certificate BEFORE INSERT OR UPDATE ON jazzhands.account_assigned_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_assigned_certificate ON account_assigned_certificate;
CREATE TRIGGER trigger_audit_account_assigned_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_assigned_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_assigned_certificate();
DROP TRIGGER IF EXISTS aaa_account_collection_base_handler ON account_collection;
CREATE TRIGGER aaa_account_collection_base_handler AFTER INSERT OR DELETE OR UPDATE OF account_collection_id ON jazzhands.account_collection FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.account_collection_base_handler();
DROP TRIGGER IF EXISTS trig_account_collection_realm ON account_collection;
CREATE TRIGGER trig_account_collection_realm AFTER UPDATE OF account_collection_type ON jazzhands.account_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_collection ON account_collection;
CREATE TRIGGER trig_userlog_account_collection BEFORE INSERT OR UPDATE ON jazzhands.account_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_collection ON account_collection;
CREATE TRIGGER trigger_audit_account_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_collection();
DROP TRIGGER IF EXISTS trigger_validate_account_collection_type_change ON account_collection;
CREATE TRIGGER trigger_validate_account_collection_type_change BEFORE UPDATE OF account_collection_type ON jazzhands.account_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_account_collection_type_change();
DROP TRIGGER IF EXISTS trig_account_collection_account_realm ON account_collection_account;
CREATE TRIGGER trig_account_collection_account_realm AFTER INSERT OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_account_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_collection_account ON account_collection_account;
CREATE TRIGGER trig_userlog_account_collection_account BEFORE INSERT OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_account_coll_member_relation_enforce ON account_collection_account;
CREATE CONSTRAINT TRIGGER trigger_account_coll_member_relation_enforce AFTER INSERT OR UPDATE ON jazzhands.account_collection_account DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.account_coll_member_relation_enforce();
DROP TRIGGER IF EXISTS trigger_account_collection_member_enforce ON account_collection_account;
CREATE CONSTRAINT TRIGGER trigger_account_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.account_collection_account DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_audit_account_collection_account ON account_collection_account;
CREATE TRIGGER trigger_audit_account_collection_account AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_collection_account();
DROP TRIGGER IF EXISTS trigger_pgnotify_account_collection_account_token_changes ON account_collection_account;
CREATE TRIGGER trigger_pgnotify_account_collection_account_token_changes AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_account FOR EACH ROW EXECUTE FUNCTION jazzhands.pgnotify_account_collection_account_token_changes();
DROP TRIGGER IF EXISTS aaa_account_collection_root_handler ON account_collection_hier;
CREATE TRIGGER aaa_account_collection_root_handler AFTER INSERT OR DELETE OR UPDATE OF account_collection_id, child_account_collection_id ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.account_collection_root_handler();
DROP TRIGGER IF EXISTS trig_account_collection_hier_realm ON account_collection_hier;
CREATE TRIGGER trig_account_collection_hier_realm AFTER INSERT OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_hier_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_collection_hier ON account_collection_hier;
CREATE TRIGGER trig_userlog_account_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_account_collection_hier_enforce ON account_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_account_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.account_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_hier_enforce();
DROP TRIGGER IF EXISTS trigger_audit_account_collection_hier ON account_collection_hier;
CREATE TRIGGER trigger_audit_account_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_account_collection_hier_loop ON account_collection_hier;
CREATE TRIGGER trigger_check_account_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.account_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.check_account_colllection_hier_loop();
DROP TRIGGER IF EXISTS trig_userlog_account_collection_type_relation ON account_collection_type_relation;
CREATE TRIGGER trig_userlog_account_collection_type_relation BEFORE INSERT OR UPDATE ON jazzhands.account_collection_type_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_collection_type_relation ON account_collection_type_relation;
CREATE TRIGGER trigger_audit_account_collection_type_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_collection_type_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_collection_type_relation();
DROP TRIGGER IF EXISTS trig_userlog_account_password ON account_password;
CREATE TRIGGER trig_userlog_account_password BEFORE INSERT OR UPDATE ON jazzhands.account_password FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_password ON account_password;
CREATE TRIGGER trigger_audit_account_password AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_password FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_password();
DROP TRIGGER IF EXISTS trigger_pgnotify_account_password_changes ON account_password;
CREATE TRIGGER trigger_pgnotify_account_password_changes AFTER INSERT OR UPDATE ON jazzhands.account_password FOR EACH ROW EXECUTE FUNCTION jazzhands.pgnotify_account_password_changes();
DROP TRIGGER IF EXISTS trigger_pull_password_account_realm_from_account ON account_password;
CREATE TRIGGER trigger_pull_password_account_realm_from_account BEFORE INSERT OR UPDATE OF account_id ON jazzhands.account_password FOR EACH ROW EXECUTE FUNCTION jazzhands.pull_password_account_realm_from_account();
DROP TRIGGER IF EXISTS trigger_unrequire_password_change ON account_password;
CREATE TRIGGER trigger_unrequire_password_change BEFORE INSERT OR UPDATE OF password ON jazzhands.account_password FOR EACH ROW EXECUTE FUNCTION jazzhands.unrequire_password_change();
DROP TRIGGER IF EXISTS trig_userlog_account_realm ON account_realm;
CREATE TRIGGER trig_userlog_account_realm BEFORE INSERT OR UPDATE ON jazzhands.account_realm FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm ON account_realm;
CREATE TRIGGER trigger_audit_account_realm AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_realm();
DROP TRIGGER IF EXISTS trig_userlog_account_realm_account_collection_type ON account_realm_account_collection_type;
CREATE TRIGGER trig_userlog_account_realm_account_collection_type BEFORE INSERT OR UPDATE ON jazzhands.account_realm_account_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm_account_collection_type ON account_realm_account_collection_type;
CREATE TRIGGER trigger_audit_account_realm_account_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_realm_account_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_account_realm_company ON account_realm_company;
CREATE TRIGGER trig_userlog_account_realm_company BEFORE INSERT OR UPDATE ON jazzhands.account_realm_company FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm_company ON account_realm_company;
CREATE TRIGGER trigger_audit_account_realm_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm_company FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_realm_company();
DROP TRIGGER IF EXISTS trig_userlog_account_realm_password_type ON account_realm_password_type;
CREATE TRIGGER trig_userlog_account_realm_password_type BEFORE INSERT OR UPDATE ON jazzhands.account_realm_password_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_realm_password_type ON account_realm_password_type;
CREATE TRIGGER trigger_audit_account_realm_password_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_realm_password_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_realm_password_type();
DROP TRIGGER IF EXISTS trig_userlog_account_ssh_key ON account_ssh_key;
CREATE TRIGGER trig_userlog_account_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.account_ssh_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_ssh_key ON account_ssh_key;
CREATE TRIGGER trigger_audit_account_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_ssh_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_account_token ON account_token;
CREATE TRIGGER trig_userlog_account_token BEFORE INSERT OR UPDATE ON jazzhands.account_token FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_token ON account_token;
CREATE TRIGGER trigger_audit_account_token AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_token FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_token();
DROP TRIGGER IF EXISTS trigger_pgnotify_account_token_change ON account_token;
CREATE TRIGGER trigger_pgnotify_account_token_change AFTER INSERT OR UPDATE ON jazzhands.account_token FOR EACH ROW EXECUTE FUNCTION jazzhands.pgnotify_account_token_change();
DROP TRIGGER IF EXISTS trig_userlog_account_unix_info ON account_unix_info;
CREATE TRIGGER trig_userlog_account_unix_info BEFORE INSERT OR UPDATE ON jazzhands.account_unix_info FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_account_unix_info ON account_unix_info;
CREATE TRIGGER trigger_audit_account_unix_info AFTER INSERT OR DELETE OR UPDATE ON jazzhands.account_unix_info FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_account_unix_info();
DROP TRIGGER IF EXISTS trig_userlog_appaal ON appaal;
CREATE TRIGGER trig_userlog_appaal BEFORE INSERT OR UPDATE ON jazzhands.appaal FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal ON appaal;
CREATE TRIGGER trigger_audit_appaal AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_appaal();
DROP TRIGGER IF EXISTS trig_userlog_appaal_instance ON appaal_instance;
CREATE TRIGGER trig_userlog_appaal_instance BEFORE INSERT OR UPDATE ON jazzhands.appaal_instance FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal_instance ON appaal_instance;
CREATE TRIGGER trigger_audit_appaal_instance AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal_instance FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_appaal_instance();
DROP TRIGGER IF EXISTS trig_userlog_appaal_instance_device_collection ON appaal_instance_device_collection;
CREATE TRIGGER trig_userlog_appaal_instance_device_collection BEFORE INSERT OR UPDATE ON jazzhands.appaal_instance_device_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal_instance_device_collection ON appaal_instance_device_collection;
CREATE TRIGGER trigger_audit_appaal_instance_device_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal_instance_device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_appaal_instance_device_collection();
DROP TRIGGER IF EXISTS trig_userlog_appaal_instance_property ON appaal_instance_property;
CREATE TRIGGER trig_userlog_appaal_instance_property BEFORE INSERT OR UPDATE ON jazzhands.appaal_instance_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_appaal_instance_property ON appaal_instance_property;
CREATE TRIGGER trigger_audit_appaal_instance_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.appaal_instance_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_appaal_instance_property();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance ON approval_instance;
CREATE TRIGGER trig_userlog_approval_instance BEFORE INSERT OR UPDATE ON jazzhands.approval_instance FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance ON approval_instance;
CREATE TRIGGER trigger_audit_approval_instance AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_instance();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_item ON approval_instance_item;
CREATE TRIGGER trig_userlog_approval_instance_item BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_approval_instance_item_approval_notify ON approval_instance_item;
CREATE TRIGGER trigger_approval_instance_item_approval_notify AFTER INSERT OR UPDATE OF is_approved ON jazzhands.approval_instance_item FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.approval_instance_item_approval_notify();
DROP TRIGGER IF EXISTS trigger_approval_instance_item_approved_immutable ON approval_instance_item;
CREATE TRIGGER trigger_approval_instance_item_approved_immutable BEFORE UPDATE OF is_approved ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE FUNCTION jazzhands.approval_instance_item_approved_immutable();
DROP TRIGGER IF EXISTS trigger_approval_instance_step_auto_complete ON approval_instance_item;
CREATE TRIGGER trigger_approval_instance_step_auto_complete AFTER INSERT OR UPDATE OF is_approved ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE FUNCTION jazzhands.approval_instance_step_auto_complete();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_item ON approval_instance_item;
CREATE TRIGGER trigger_audit_approval_instance_item AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_item FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_instance_item();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_link ON approval_instance_link;
CREATE TRIGGER trig_userlog_approval_instance_link BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_link FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_link ON approval_instance_link;
CREATE TRIGGER trigger_audit_approval_instance_link AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_link FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_instance_link();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_step ON approval_instance_step;
CREATE TRIGGER trig_userlog_approval_instance_step BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_approval_instance_step_completed_immutable ON approval_instance_step;
CREATE TRIGGER trigger_approval_instance_step_completed_immutable BEFORE UPDATE OF is_completed ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE FUNCTION jazzhands.approval_instance_step_completed_immutable();
DROP TRIGGER IF EXISTS trigger_approval_instance_step_resolve_instance ON approval_instance_step;
CREATE TRIGGER trigger_approval_instance_step_resolve_instance AFTER UPDATE OF is_completed ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE FUNCTION jazzhands.approval_instance_step_resolve_instance();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_step ON approval_instance_step;
CREATE TRIGGER trigger_audit_approval_instance_step AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_step FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_instance_step();
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_step_notify ON approval_instance_step_notify;
CREATE TRIGGER trig_userlog_approval_instance_step_notify BEFORE INSERT OR UPDATE ON jazzhands.approval_instance_step_notify FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_step_notify ON approval_instance_step_notify;
CREATE TRIGGER trigger_audit_approval_instance_step_notify AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_instance_step_notify FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_instance_step_notify();
DROP TRIGGER IF EXISTS trigger_legacy_approval_instance_step_notify_account ON approval_instance_step_notify;
CREATE TRIGGER trigger_legacy_approval_instance_step_notify_account BEFORE INSERT OR UPDATE OF account_id ON jazzhands.approval_instance_step_notify FOR EACH ROW EXECUTE FUNCTION jazzhands.legacy_approval_instance_step_notify_account();
DROP TRIGGER IF EXISTS trig_userlog_approval_process ON approval_process;
CREATE TRIGGER trig_userlog_approval_process BEFORE INSERT OR UPDATE ON jazzhands.approval_process FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_process ON approval_process;
CREATE TRIGGER trigger_audit_approval_process AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_process FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_process();
DROP TRIGGER IF EXISTS trig_userlog_approval_process_chain ON approval_process_chain;
CREATE TRIGGER trig_userlog_approval_process_chain BEFORE INSERT OR UPDATE ON jazzhands.approval_process_chain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_approval_process_chain ON approval_process_chain;
CREATE TRIGGER trigger_audit_approval_process_chain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.approval_process_chain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_approval_process_chain();
DROP TRIGGER IF EXISTS trig_userlog_asset ON asset;
CREATE TRIGGER trig_userlog_asset BEFORE INSERT OR UPDATE ON jazzhands.asset FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_asset ON asset;
CREATE TRIGGER trigger_audit_asset AFTER INSERT OR DELETE OR UPDATE ON jazzhands.asset FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_asset();
DROP TRIGGER IF EXISTS trigger_validate_asset_component_assignment ON asset;
CREATE CONSTRAINT TRIGGER trigger_validate_asset_component_assignment AFTER INSERT OR UPDATE OF component_id ON jazzhands.asset DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_asset_component_assignment();
DROP TRIGGER IF EXISTS trig_userlog_badge ON badge;
CREATE TRIGGER trig_userlog_badge BEFORE INSERT OR UPDATE ON jazzhands.badge FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_badge ON badge;
CREATE TRIGGER trigger_audit_badge AFTER INSERT OR DELETE OR UPDATE ON jazzhands.badge FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_badge();
DROP TRIGGER IF EXISTS trig_userlog_badge_type ON badge_type;
CREATE TRIGGER trig_userlog_badge_type BEFORE INSERT OR UPDATE ON jazzhands.badge_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_badge_type ON badge_type;
CREATE TRIGGER trigger_audit_badge_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.badge_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_badge_type();
DROP TRIGGER IF EXISTS trig_userlog_block_storage_device ON block_storage_device;
CREATE TRIGGER trig_userlog_block_storage_device BEFORE INSERT OR UPDATE ON jazzhands.block_storage_device FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_block_storage_device ON block_storage_device;
CREATE TRIGGER trigger_audit_block_storage_device AFTER INSERT OR DELETE OR UPDATE ON jazzhands.block_storage_device FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_block_storage_device();
DROP TRIGGER IF EXISTS trigger_block_storage_device_checks ON block_storage_device;
CREATE CONSTRAINT TRIGGER trigger_block_storage_device_checks AFTER INSERT OR UPDATE ON jazzhands.block_storage_device DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.block_storage_device_checks();
DROP TRIGGER IF EXISTS trig_userlog_certificate_signing_request ON certificate_signing_request;
CREATE TRIGGER trig_userlog_certificate_signing_request BEFORE INSERT OR UPDATE ON jazzhands.certificate_signing_request FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_certificate_signing_request ON certificate_signing_request;
CREATE TRIGGER trigger_audit_certificate_signing_request AFTER INSERT OR DELETE OR UPDATE ON jazzhands.certificate_signing_request FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_certificate_signing_request();
DROP TRIGGER IF EXISTS trigger_csr_set_hashes ON certificate_signing_request;
CREATE TRIGGER trigger_csr_set_hashes BEFORE INSERT OR UPDATE OF certificate_signing_request, public_key_hash_id ON jazzhands.certificate_signing_request FOR EACH ROW EXECUTE FUNCTION jazzhands.set_csr_hashes();
DROP TRIGGER IF EXISTS trig_userlog_chassis_location ON chassis_location;
CREATE TRIGGER trig_userlog_chassis_location BEFORE INSERT OR UPDATE ON jazzhands.chassis_location FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_chassis_location ON chassis_location;
CREATE TRIGGER trigger_audit_chassis_location AFTER INSERT OR DELETE OR UPDATE ON jazzhands.chassis_location FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_chassis_location();
DROP TRIGGER IF EXISTS trig_userlog_circuit ON circuit;
CREATE TRIGGER trig_userlog_circuit BEFORE INSERT OR UPDATE ON jazzhands.circuit FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_circuit ON circuit;
CREATE TRIGGER trigger_audit_circuit AFTER INSERT OR DELETE OR UPDATE ON jazzhands.circuit FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_circuit();
DROP TRIGGER IF EXISTS trig_userlog_company ON company;
CREATE TRIGGER trig_userlog_company BEFORE INSERT OR UPDATE ON jazzhands.company FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company ON company;
CREATE TRIGGER trigger_audit_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_company();
DROP TRIGGER IF EXISTS trigger_company_insert_function_nudge ON company;
CREATE TRIGGER trigger_company_insert_function_nudge BEFORE INSERT ON jazzhands.company FOR EACH ROW EXECUTE FUNCTION jazzhands.company_insert_function_nudge();
DROP TRIGGER IF EXISTS trigger_delete_per_company_company_collection ON company;
CREATE TRIGGER trigger_delete_per_company_company_collection BEFORE DELETE ON jazzhands.company FOR EACH ROW EXECUTE FUNCTION jazzhands.delete_per_company_company_collection();
DROP TRIGGER IF EXISTS trigger_update_per_company_company_collection ON company;
CREATE TRIGGER trigger_update_per_company_company_collection AFTER INSERT OR UPDATE ON jazzhands.company FOR EACH ROW EXECUTE FUNCTION jazzhands.update_per_company_company_collection();
DROP TRIGGER IF EXISTS trig_userlog_company_collection ON company_collection;
CREATE TRIGGER trig_userlog_company_collection BEFORE INSERT OR UPDATE ON jazzhands.company_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_collection ON company_collection;
CREATE TRIGGER trigger_audit_company_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_company_collection();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_bytype_del ON company_collection;
CREATE TRIGGER trigger_manip_company_collection_bytype_del BEFORE DELETE ON jazzhands.company_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_company_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_bytype_insup ON company_collection;
CREATE TRIGGER trigger_manip_company_collection_bytype_insup AFTER INSERT OR UPDATE OF company_collection_type ON jazzhands.company_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_company_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_company_collection_type_change ON company_collection;
CREATE TRIGGER trigger_validate_company_collection_type_change BEFORE UPDATE OF company_collection_type ON jazzhands.company_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_company_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_company_collection_company ON company_collection_company;
CREATE TRIGGER trig_userlog_company_collection_company BEFORE INSERT OR UPDATE ON jazzhands.company_collection_company FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_collection_company ON company_collection_company;
CREATE TRIGGER trigger_audit_company_collection_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_collection_company FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_company_collection_company();
DROP TRIGGER IF EXISTS trigger_company_collection_member_enforce ON company_collection_company;
CREATE CONSTRAINT TRIGGER trigger_company_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.company_collection_company DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.company_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_company_collection_hier ON company_collection_hier;
CREATE TRIGGER trig_userlog_company_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.company_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_collection_hier ON company_collection_hier;
CREATE TRIGGER trigger_audit_company_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_company_collection_hier();
DROP TRIGGER IF EXISTS trigger_company_collection_hier_enforce ON company_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_company_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.company_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.company_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_company_type ON company_type;
CREATE TRIGGER trig_userlog_company_type BEFORE INSERT OR UPDATE ON jazzhands.company_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_company_type ON company_type;
CREATE TRIGGER trigger_audit_company_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.company_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_company_type();
DROP TRIGGER IF EXISTS aaa_tg_cache_component_parent_handler ON component;
CREATE TRIGGER aaa_tg_cache_component_parent_handler AFTER INSERT OR DELETE OR UPDATE OF parent_slot_id ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.cache_component_parent_handler();
DROP TRIGGER IF EXISTS aab_tg_cache_device_component_component_handler ON component;
CREATE TRIGGER aab_tg_cache_device_component_component_handler AFTER INSERT OR DELETE OR UPDATE OF parent_slot_id ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.cache_device_component_component_handler();
DROP TRIGGER IF EXISTS trig_userlog_component ON component;
CREATE TRIGGER trig_userlog_component BEFORE INSERT OR UPDATE ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component ON component;
CREATE TRIGGER trigger_audit_component AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component();
DROP TRIGGER IF EXISTS trigger_create_component_template_slots ON component;
CREATE TRIGGER trigger_create_component_template_slots AFTER INSERT OR UPDATE OF component_type_id ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands.create_component_slots_by_trigger();
DROP TRIGGER IF EXISTS trigger_sync_component_rack_location_id ON component;
CREATE TRIGGER trigger_sync_component_rack_location_id AFTER UPDATE OF rack_location_id ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands.sync_component_rack_location_id();
DROP TRIGGER IF EXISTS trigger_validate_component_parent_slot_id ON component;
CREATE CONSTRAINT TRIGGER trigger_validate_component_parent_slot_id AFTER INSERT OR UPDATE OF parent_slot_id, component_type_id ON jazzhands.component DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_component_parent_slot_id();
DROP TRIGGER IF EXISTS trigger_validate_component_rack_location ON component;
CREATE CONSTRAINT TRIGGER trigger_validate_component_rack_location AFTER INSERT OR UPDATE OF rack_location_id ON jazzhands.component DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_component_rack_location();
DROP TRIGGER IF EXISTS trigger_zzz_generate_slot_names ON component;
CREATE TRIGGER trigger_zzz_generate_slot_names AFTER INSERT OR UPDATE OF parent_slot_id ON jazzhands.component FOR EACH ROW EXECUTE FUNCTION jazzhands.set_slot_names_by_trigger();
DROP TRIGGER IF EXISTS trig_userlog_component_management_controller ON component_management_controller;
CREATE TRIGGER trig_userlog_component_management_controller BEFORE INSERT OR UPDATE ON jazzhands.component_management_controller FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_management_controller ON component_management_controller;
CREATE TRIGGER trigger_audit_component_management_controller AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_management_controller FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component_management_controller();
DROP TRIGGER IF EXISTS trig_userlog_component_property ON component_property;
CREATE TRIGGER trig_userlog_component_property BEFORE INSERT OR UPDATE ON jazzhands.component_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_property ON component_property;
CREATE TRIGGER trigger_audit_component_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component_property();
DROP TRIGGER IF EXISTS trigger_component_property_scsi_id_logical_volume_sync_del ON component_property;
CREATE TRIGGER trigger_component_property_scsi_id_logical_volume_sync_del AFTER DELETE ON jazzhands.component_property FOR EACH ROW EXECUTE FUNCTION jazzhands.component_property_scsi_id_logical_volume_sync();
DROP TRIGGER IF EXISTS trigger_component_property_scsi_id_logical_volume_sync_ins_upd ON component_property;
CREATE TRIGGER trigger_component_property_scsi_id_logical_volume_sync_ins_upd AFTER INSERT OR UPDATE OF component_id, property_value ON jazzhands.component_property FOR EACH ROW EXECUTE FUNCTION jazzhands.component_property_scsi_id_logical_volume_sync();
DROP TRIGGER IF EXISTS trigger_validate_component_property ON component_property;
CREATE CONSTRAINT TRIGGER trigger_validate_component_property AFTER INSERT OR UPDATE ON jazzhands.component_property DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_component_property();
DROP TRIGGER IF EXISTS trig_userlog_component_type ON component_type;
CREATE TRIGGER trig_userlog_component_type BEFORE INSERT OR UPDATE ON jazzhands.component_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_type ON component_type;
CREATE TRIGGER trigger_audit_component_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component_type();
DROP TRIGGER IF EXISTS trigger_check_component_type_device_virtual_match ON component_type;
CREATE CONSTRAINT TRIGGER trigger_check_component_type_device_virtual_match AFTER UPDATE OF is_virtual_component ON jazzhands.component_type NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_component_type_device_virtual_match();
DROP TRIGGER IF EXISTS trig_userlog_component_type_component_function ON component_type_component_function;
CREATE TRIGGER trig_userlog_component_type_component_function BEFORE INSERT OR UPDATE ON jazzhands.component_type_component_function FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_type_component_function ON component_type_component_function;
CREATE TRIGGER trigger_audit_component_type_component_function AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_type_component_function FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component_type_component_function();
DROP TRIGGER IF EXISTS trig_userlog_component_type_slot_template ON component_type_slot_template;
CREATE TRIGGER trig_userlog_component_type_slot_template BEFORE INSERT OR UPDATE ON jazzhands.component_type_slot_template FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_component_type_slot_template ON component_type_slot_template;
CREATE TRIGGER trigger_audit_component_type_slot_template AFTER INSERT OR DELETE OR UPDATE ON jazzhands.component_type_slot_template FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_component_type_slot_template();
DROP TRIGGER IF EXISTS trig_userlog_contract ON contract;
CREATE TRIGGER trig_userlog_contract BEFORE INSERT OR UPDATE ON jazzhands.contract FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_contract ON contract;
CREATE TRIGGER trigger_audit_contract AFTER INSERT OR DELETE OR UPDATE ON jazzhands.contract FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_contract();
DROP TRIGGER IF EXISTS trig_userlog_contract_type ON contract_type;
CREATE TRIGGER trig_userlog_contract_type BEFORE INSERT OR UPDATE ON jazzhands.contract_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_contract_type ON contract_type;
CREATE TRIGGER trigger_audit_contract_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.contract_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_contract_type();
DROP TRIGGER IF EXISTS trig_userlog_department ON department;
CREATE TRIGGER trig_userlog_department BEFORE INSERT OR UPDATE ON jazzhands.department FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_department ON department;
CREATE TRIGGER trigger_audit_department AFTER INSERT OR DELETE OR UPDATE ON jazzhands.department FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_department();
DROP TRIGGER IF EXISTS tg_cache_device_component_device_handler ON device;
CREATE TRIGGER tg_cache_device_component_device_handler AFTER INSERT OR DELETE OR UPDATE OF component_id ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.cache_device_component_device_handler();
DROP TRIGGER IF EXISTS trig_userlog_device ON device;
CREATE TRIGGER trig_userlog_device BEFORE INSERT OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device ON device;
CREATE TRIGGER trigger_audit_device AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device();
DROP TRIGGER IF EXISTS trigger_check_device_component_type_virtual_match ON device;
CREATE CONSTRAINT TRIGGER trigger_check_device_component_type_virtual_match AFTER INSERT OR UPDATE OF is_virtual_device ON jazzhands.device NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_device_component_type_virtual_match();
DROP TRIGGER IF EXISTS trigger_create_device_component ON device;
CREATE TRIGGER trigger_create_device_component BEFORE INSERT OR UPDATE OF device_type_id ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.create_device_component_by_trigger();
DROP TRIGGER IF EXISTS trigger_del_jazzhands_legacy_support ON device;
CREATE TRIGGER trigger_del_jazzhands_legacy_support BEFORE DELETE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.del_jazzhands_legacy_support();
DROP TRIGGER IF EXISTS trigger_delete_per_device_device_collection ON device;
CREATE TRIGGER trigger_delete_per_device_device_collection BEFORE DELETE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.delete_per_device_device_collection();
DROP TRIGGER IF EXISTS trigger_device_one_location_validate ON device;
CREATE TRIGGER trigger_device_one_location_validate BEFORE INSERT OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.device_one_location_validate();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_device_del ON device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_device_del BEFORE DELETE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_device_del();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_device_ins ON device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_device_ins AFTER INSERT ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_device_ins();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_device_upd ON device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_device_upd AFTER UPDATE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_device_upd();
DROP TRIGGER IF EXISTS trigger_sync_device_rack_location_id ON device;
CREATE TRIGGER trigger_sync_device_rack_location_id BEFORE INSERT OR UPDATE OF rack_location_id, component_id ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.sync_device_rack_location_id();
DROP TRIGGER IF EXISTS trigger_update_per_device_device_collection ON device;
CREATE TRIGGER trigger_update_per_device_device_collection AFTER INSERT OR UPDATE ON jazzhands.device FOR EACH ROW EXECUTE FUNCTION jazzhands.update_per_device_device_collection();
DROP TRIGGER IF EXISTS trigger_validate_device_component_assignment ON device;
CREATE CONSTRAINT TRIGGER trigger_validate_device_component_assignment AFTER INSERT OR UPDATE OF device_type_id, component_id ON jazzhands.device DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_device_component_assignment();
DROP TRIGGER IF EXISTS aaa_device_collection_base_handler ON device_collection;
CREATE TRIGGER aaa_device_collection_base_handler AFTER INSERT OR DELETE OR UPDATE OF device_collection_id ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.device_collection_base_handler();
DROP TRIGGER IF EXISTS trig_userlog_device_collection ON device_collection;
CREATE TRIGGER trig_userlog_device_collection BEFORE INSERT OR UPDATE ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection ON device_collection;
CREATE TRIGGER trigger_audit_device_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_collection();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_bytype_del ON device_collection;
CREATE TRIGGER trigger_manip_device_collection_bytype_del BEFORE DELETE ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_device_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_bytype_insup ON device_collection;
CREATE TRIGGER trigger_manip_device_collection_bytype_insup AFTER INSERT OR UPDATE OF device_collection_type ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_device_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_device_collection_type_change ON device_collection;
CREATE TRIGGER trigger_validate_device_collection_type_change BEFORE UPDATE OF device_collection_type ON jazzhands.device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_device_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_assigned_certificate ON device_collection_assigned_certificate;
CREATE TRIGGER trig_userlog_device_collection_assigned_certificate BEFORE INSERT OR UPDATE ON jazzhands.device_collection_assigned_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_assigned_certificate ON device_collection_assigned_certificate;
CREATE TRIGGER trigger_audit_device_collection_assigned_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_assigned_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_collection_assigned_certificate();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_device ON device_collection_device;
CREATE TRIGGER trig_userlog_device_collection_device BEFORE INSERT OR UPDATE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_device ON device_collection_device;
CREATE TRIGGER trigger_audit_device_collection_device AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_collection_device();
DROP TRIGGER IF EXISTS trigger_device_collection_member_enforce ON device_collection_device;
CREATE CONSTRAINT TRIGGER trigger_device_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.device_collection_device DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.device_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_dcd_del ON device_collection_device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_dcd_del BEFORE DELETE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_dcd_del();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_dcd_ins ON device_collection_device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_dcd_ins AFTER INSERT ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_dcd_ins();
DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_dcd_upd ON device_collection_device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_dcd_upd AFTER UPDATE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_dcd_upd();
DROP TRIGGER IF EXISTS trigger_member_device_collection_after_hooks ON device_collection_device;
CREATE TRIGGER trigger_member_device_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_device FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.device_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_member_device_collection_after_row_hooks ON device_collection_device;
CREATE TRIGGER trigger_member_device_collection_after_row_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_device FOR EACH ROW EXECUTE FUNCTION jazzhands.device_collection_device_after_row_hooks();
DROP TRIGGER IF EXISTS aaa_device_collection_root_handler ON device_collection_hier;
CREATE TRIGGER aaa_device_collection_root_handler AFTER INSERT OR DELETE OR UPDATE OF device_collection_id, child_device_collection_id ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.device_collection_root_handler();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_hier ON device_collection_hier;
CREATE TRIGGER trig_userlog_device_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_hier ON device_collection_hier;
CREATE TRIGGER trigger_audit_device_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_device_collection_hier_loop ON device_collection_hier;
CREATE TRIGGER trigger_check_device_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.check_device_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_device_collection_hier_enforce ON device_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_device_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.device_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.device_collection_hier_enforce();
DROP TRIGGER IF EXISTS trigger_hier_device_collection_after_hooks ON device_collection_hier;
CREATE TRIGGER trigger_hier_device_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_hier FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.device_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_hier_device_collection_after_row_hooks ON device_collection_hier;
CREATE TRIGGER trigger_hier_device_collection_after_row_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.device_collection_hier_after_row_hooks();
DROP TRIGGER IF EXISTS trig_userlog_device_collection_ssh_key ON device_collection_ssh_key;
CREATE TRIGGER trig_userlog_device_collection_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.device_collection_ssh_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_collection_ssh_key ON device_collection_ssh_key;
CREATE TRIGGER trigger_audit_device_collection_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_collection_ssh_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_collection_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_device_encapsulation_domain ON device_encapsulation_domain;
CREATE TRIGGER trig_userlog_device_encapsulation_domain BEFORE INSERT OR UPDATE ON jazzhands.device_encapsulation_domain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_encapsulation_domain ON device_encapsulation_domain;
CREATE TRIGGER trigger_audit_device_encapsulation_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_encapsulation_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_encapsulation_domain();
DROP TRIGGER IF EXISTS trig_userlog_device_note ON device_note;
CREATE TRIGGER trig_userlog_device_note BEFORE INSERT OR UPDATE ON jazzhands.device_note FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_note ON device_note;
CREATE TRIGGER trigger_audit_device_note AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_note FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_note();
DROP TRIGGER IF EXISTS trig_userlog_device_ssh_key ON device_ssh_key;
CREATE TRIGGER trig_userlog_device_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.device_ssh_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_ssh_key ON device_ssh_key;
CREATE TRIGGER trigger_audit_device_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_ssh_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_device_ticket ON device_ticket;
CREATE TRIGGER trig_userlog_device_ticket BEFORE INSERT OR UPDATE ON jazzhands.device_ticket FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_ticket ON device_ticket;
CREATE TRIGGER trigger_audit_device_ticket AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_ticket FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_ticket();
DROP TRIGGER IF EXISTS trig_userlog_device_type ON device_type;
CREATE TRIGGER trig_userlog_device_type BEFORE INSERT OR UPDATE ON jazzhands.device_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_type ON device_type;
CREATE TRIGGER trigger_audit_device_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_type();
DROP TRIGGER IF EXISTS trigger_device_type_chassis_check ON device_type;
CREATE TRIGGER trigger_device_type_chassis_check BEFORE UPDATE OF is_chassis ON jazzhands.device_type FOR EACH ROW EXECUTE FUNCTION jazzhands.device_type_chassis_check();
DROP TRIGGER IF EXISTS trigger_device_type_model_to_name ON device_type;
CREATE TRIGGER trigger_device_type_model_to_name BEFORE INSERT OR UPDATE OF device_type_name, model ON jazzhands.device_type FOR EACH ROW EXECUTE FUNCTION jazzhands.device_type_model_to_name();
DROP TRIGGER IF EXISTS trig_userlog_device_type_module ON device_type_module;
CREATE TRIGGER trig_userlog_device_type_module BEFORE INSERT OR UPDATE ON jazzhands.device_type_module FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_type_module ON device_type_module;
CREATE TRIGGER trigger_audit_device_type_module AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_type_module FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_type_module();
DROP TRIGGER IF EXISTS trigger_device_type_module_chassis_check ON device_type_module;
CREATE TRIGGER trigger_device_type_module_chassis_check BEFORE INSERT OR UPDATE OF device_type_id ON jazzhands.device_type_module FOR EACH ROW EXECUTE FUNCTION jazzhands.device_type_module_chassis_check();
DROP TRIGGER IF EXISTS trigger_device_type_module_sanity_set ON device_type_module;
CREATE TRIGGER trigger_device_type_module_sanity_set BEFORE INSERT OR UPDATE ON jazzhands.device_type_module FOR EACH ROW EXECUTE FUNCTION jazzhands.device_type_module_sanity_set();
DROP TRIGGER IF EXISTS trig_userlog_device_type_module_device_type ON device_type_module_device_type;
CREATE TRIGGER trig_userlog_device_type_module_device_type BEFORE INSERT OR UPDATE ON jazzhands.device_type_module_device_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_device_type_module_device_type ON device_type_module_device_type;
CREATE TRIGGER trigger_audit_device_type_module_device_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.device_type_module_device_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_device_type_module_device_type();
DROP TRIGGER IF EXISTS trig_userlog_dns_change_record ON dns_change_record;
CREATE TRIGGER trig_userlog_dns_change_record BEFORE INSERT OR UPDATE ON jazzhands.dns_change_record FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_change_record ON dns_change_record;
CREATE TRIGGER trigger_audit_dns_change_record AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_change_record FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_change_record();
DROP TRIGGER IF EXISTS trigger_dns_change_record_pgnotify ON dns_change_record;
CREATE TRIGGER trigger_dns_change_record_pgnotify AFTER INSERT OR UPDATE ON jazzhands.dns_change_record FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.dns_change_record_pgnotify();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain ON dns_domain;
CREATE TRIGGER trig_userlog_dns_domain BEFORE INSERT OR UPDATE ON jazzhands.dns_domain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain ON dns_domain;
CREATE TRIGGER trigger_audit_dns_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_domain();
DROP TRIGGER IF EXISTS trigger_dns_domain_collection_child_automation_del ON dns_domain;
CREATE TRIGGER trigger_dns_domain_collection_child_automation_del BEFORE DELETE ON jazzhands.dns_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_collection_child_automation();
DROP TRIGGER IF EXISTS trigger_dns_domain_collection_child_automation_ins ON dns_domain;
CREATE TRIGGER trigger_dns_domain_collection_child_automation_ins AFTER INSERT OR UPDATE OF parent_dns_domain_id ON jazzhands.dns_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_collection_child_automation();
DROP TRIGGER IF EXISTS trigger_dns_domain_trigger_change ON dns_domain;
CREATE TRIGGER trigger_dns_domain_trigger_change AFTER INSERT OR UPDATE OF dns_domain_name ON jazzhands.dns_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_trigger_change();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_collection ON dns_domain_collection;
CREATE TRIGGER trig_userlog_dns_domain_collection BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_collection ON dns_domain_collection;
CREATE TRIGGER trigger_audit_dns_domain_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_domain_collection();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_bytype_del ON dns_domain_collection;
CREATE TRIGGER trigger_manip_dns_domain_collection_bytype_del BEFORE DELETE ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_dns_domain_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_bytype_insup ON dns_domain_collection;
CREATE TRIGGER trigger_manip_dns_domain_collection_bytype_insup AFTER INSERT OR UPDATE OF dns_domain_collection_type ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_dns_domain_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_dns_domain_collection_type_change ON dns_domain_collection;
CREATE TRIGGER trigger_validate_dns_domain_collection_type_change BEFORE UPDATE OF dns_domain_collection_type ON jazzhands.dns_domain_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_dns_domain_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_collection_dns_domain ON dns_domain_collection_dns_domain;
CREATE TRIGGER trig_userlog_dns_domain_collection_dns_domain BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_collection_dns_domain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_collection_dns_domain ON dns_domain_collection_dns_domain;
CREATE TRIGGER trigger_audit_dns_domain_collection_dns_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_collection_dns_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_domain_collection_dns_domain();
DROP TRIGGER IF EXISTS trigger_dns_domain_collection_member_enforce ON dns_domain_collection_dns_domain;
CREATE CONSTRAINT TRIGGER trigger_dns_domain_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.dns_domain_collection_dns_domain DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_collection_hier ON dns_domain_collection_hier;
CREATE TRIGGER trig_userlog_dns_domain_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_collection_hier ON dns_domain_collection_hier;
CREATE TRIGGER trigger_audit_dns_domain_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_domain_collection_hier();
DROP TRIGGER IF EXISTS trigger_dns_domain_collection_hier_enforce ON dns_domain_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_dns_domain_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.dns_domain_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_dns_domain_ip_universe ON dns_domain_ip_universe;
CREATE TRIGGER trig_userlog_dns_domain_ip_universe BEFORE INSERT OR UPDATE ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_domain_ip_universe ON dns_domain_ip_universe;
CREATE TRIGGER trigger_audit_dns_domain_ip_universe AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_domain_ip_universe();
DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_can_generate ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_can_generate AFTER INSERT OR UPDATE OF should_generate ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_ip_universe_can_generate();
DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_trigger_change ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_trigger_change AFTER INSERT OR UPDATE OF soa_class, soa_ttl, soa_serial, soa_refresh, soa_retry, soa_expire, soa_minimum, soa_mname, soa_rname, should_generate ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_ip_universe_trigger_change();
DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_trigger_del ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_trigger_del BEFORE DELETE ON jazzhands.dns_domain_ip_universe FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_ip_universe_trigger_del();
DROP TRIGGER IF EXISTS trig_userlog_dns_record ON dns_record;
CREATE TRIGGER trig_userlog_dns_record BEFORE INSERT OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_record ON dns_record;
CREATE TRIGGER trigger_audit_dns_record AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_record();
DROP TRIGGER IF EXISTS trigger_check_ip_universe_dns_record ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_check_ip_universe_dns_record AFTER INSERT OR UPDATE OF dns_record_id, ip_universe_id ON jazzhands.dns_record DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_ip_universe_dns_record();
DROP TRIGGER IF EXISTS trigger_dns_a_rec_validation ON dns_record;
CREATE TRIGGER trigger_dns_a_rec_validation BEFORE INSERT OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_a_rec_validation();
DROP TRIGGER IF EXISTS trigger_dns_non_a_rec_validation ON dns_record;
CREATE TRIGGER trigger_dns_non_a_rec_validation BEFORE INSERT OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_non_a_rec_validation();
DROP TRIGGER IF EXISTS trigger_dns_rec_prevent_dups ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_dns_rec_prevent_dups AFTER INSERT OR UPDATE ON jazzhands.dns_record NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_rec_prevent_dups();
DROP TRIGGER IF EXISTS trigger_dns_record_check_name ON dns_record;
CREATE TRIGGER trigger_dns_record_check_name BEFORE INSERT OR UPDATE OF dns_name, should_generate_ptr ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_record_check_name();
DROP TRIGGER IF EXISTS trigger_dns_record_cname_checker ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_dns_record_cname_checker AFTER INSERT OR UPDATE OF dns_class, dns_type, dns_name, dns_domain_id, is_enabled ON jazzhands.dns_record NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_record_cname_checker();
DROP TRIGGER IF EXISTS trigger_dns_record_enabled_check ON dns_record;
CREATE TRIGGER trigger_dns_record_enabled_check BEFORE INSERT OR UPDATE OF is_enabled ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_record_enabled_check();
DROP TRIGGER IF EXISTS trigger_dns_record_update_nontime ON dns_record;
CREATE TRIGGER trigger_dns_record_update_nontime AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_record FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_record_update_nontime();
DROP TRIGGER IF EXISTS trig_userlog_dns_record_relation ON dns_record_relation;
CREATE TRIGGER trig_userlog_dns_record_relation BEFORE INSERT OR UPDATE ON jazzhands.dns_record_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_dns_record_relation ON dns_record_relation;
CREATE TRIGGER trigger_audit_dns_record_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.dns_record_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_dns_record_relation();
DROP TRIGGER IF EXISTS trig_userlog_encapsulation_domain ON encapsulation_domain;
CREATE TRIGGER trig_userlog_encapsulation_domain BEFORE INSERT OR UPDATE ON jazzhands.encapsulation_domain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_encapsulation_domain ON encapsulation_domain;
CREATE TRIGGER trigger_audit_encapsulation_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.encapsulation_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_encapsulation_domain();
DROP TRIGGER IF EXISTS trig_userlog_encapsulation_range ON encapsulation_range;
CREATE TRIGGER trig_userlog_encapsulation_range BEFORE INSERT OR UPDATE ON jazzhands.encapsulation_range FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_encapsulation_range ON encapsulation_range;
CREATE TRIGGER trigger_audit_encapsulation_range AFTER INSERT OR DELETE OR UPDATE ON jazzhands.encapsulation_range FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_encapsulation_range();
DROP TRIGGER IF EXISTS trig_userlog_encrypted_block_storage_device ON encrypted_block_storage_device;
CREATE TRIGGER trig_userlog_encrypted_block_storage_device BEFORE INSERT OR UPDATE ON jazzhands.encrypted_block_storage_device FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_encrypted_block_storage_device ON encrypted_block_storage_device;
CREATE TRIGGER trigger_audit_encrypted_block_storage_device AFTER INSERT OR DELETE OR UPDATE ON jazzhands.encrypted_block_storage_device FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_encrypted_block_storage_device();
DROP TRIGGER IF EXISTS trig_userlog_encryption_key ON encryption_key;
CREATE TRIGGER trig_userlog_encryption_key BEFORE INSERT OR UPDATE ON jazzhands.encryption_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_encryption_key ON encryption_key;
CREATE TRIGGER trigger_audit_encryption_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.encryption_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_encryption_key();
DROP TRIGGER IF EXISTS trigger_encryption_key_validation ON encryption_key;
CREATE CONSTRAINT TRIGGER trigger_encryption_key_validation AFTER INSERT OR UPDATE OF encryption_key_db_value ON jazzhands.encryption_key DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.encryption_key_validation();
DROP TRIGGER IF EXISTS trig_userlog_filesystem ON filesystem;
CREATE TRIGGER trig_userlog_filesystem BEFORE INSERT OR UPDATE ON jazzhands.filesystem FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_filesystem ON filesystem;
CREATE TRIGGER trigger_audit_filesystem AFTER INSERT OR DELETE OR UPDATE ON jazzhands.filesystem FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_filesystem();
DROP TRIGGER IF EXISTS trigger_filesystem_to_logical_volume_property_del ON filesystem;
CREATE TRIGGER trigger_filesystem_to_logical_volume_property_del BEFORE DELETE ON jazzhands.filesystem FOR EACH ROW EXECUTE FUNCTION jazzhands.filesystem_to_logical_volume_property_del();
DROP TRIGGER IF EXISTS trigger_filesystem_to_logical_volume_property_ins ON filesystem;
CREATE TRIGGER trigger_filesystem_to_logical_volume_property_ins AFTER INSERT ON jazzhands.filesystem FOR EACH ROW EXECUTE FUNCTION jazzhands.filesystem_to_logical_volume_property_ins();
DROP TRIGGER IF EXISTS trigger_filesystem_to_logical_volume_property_upd ON filesystem;
CREATE TRIGGER trigger_filesystem_to_logical_volume_property_upd AFTER UPDATE ON jazzhands.filesystem FOR EACH ROW EXECUTE FUNCTION jazzhands.filesystem_to_logical_volume_property_upd();
DROP TRIGGER IF EXISTS trigger_validate_filesystem ON filesystem;
CREATE CONSTRAINT TRIGGER trigger_validate_filesystem AFTER INSERT OR UPDATE OF filesystem_type, mountpoint, filesystem_label, filesystem_serial ON jazzhands.filesystem NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_filesystem();
DROP TRIGGER IF EXISTS trig_userlog_inter_component_connection ON inter_component_connection;
CREATE TRIGGER trig_userlog_inter_component_connection BEFORE INSERT OR UPDATE ON jazzhands.inter_component_connection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_inter_component_connection ON inter_component_connection;
CREATE TRIGGER trigger_audit_inter_component_connection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.inter_component_connection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_inter_component_connection();
DROP TRIGGER IF EXISTS trigger_validate_inter_component_connection ON inter_component_connection;
CREATE CONSTRAINT TRIGGER trigger_validate_inter_component_connection AFTER INSERT OR UPDATE ON jazzhands.inter_component_connection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_inter_component_connection();
DROP TRIGGER IF EXISTS trig_userlog_ip_universe ON ip_universe;
CREATE TRIGGER trig_userlog_ip_universe BEFORE INSERT OR UPDATE ON jazzhands.ip_universe FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ip_universe ON ip_universe;
CREATE TRIGGER trigger_audit_ip_universe AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ip_universe FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_ip_universe();
DROP TRIGGER IF EXISTS trig_userlog_ip_universe_visibility ON ip_universe_visibility;
CREATE TRIGGER trig_userlog_ip_universe_visibility BEFORE INSERT OR UPDATE ON jazzhands.ip_universe_visibility FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ip_universe_visibility ON ip_universe_visibility;
CREATE TRIGGER trigger_audit_ip_universe_visibility AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ip_universe_visibility FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_ip_universe_visibility();
DROP TRIGGER IF EXISTS trig_userlog_kerberos_realm ON kerberos_realm;
CREATE TRIGGER trig_userlog_kerberos_realm BEFORE INSERT OR UPDATE ON jazzhands.kerberos_realm FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_kerberos_realm ON kerberos_realm;
CREATE TRIGGER trigger_audit_kerberos_realm AFTER INSERT OR DELETE OR UPDATE ON jazzhands.kerberos_realm FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_kerberos_realm();
DROP TRIGGER IF EXISTS trig_userlog_klogin ON klogin;
CREATE TRIGGER trig_userlog_klogin BEFORE INSERT OR UPDATE ON jazzhands.klogin FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_klogin ON klogin;
CREATE TRIGGER trigger_audit_klogin AFTER INSERT OR DELETE OR UPDATE ON jazzhands.klogin FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_klogin();
DROP TRIGGER IF EXISTS trig_userlog_klogin_mclass ON klogin_mclass;
CREATE TRIGGER trig_userlog_klogin_mclass BEFORE INSERT OR UPDATE ON jazzhands.klogin_mclass FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_klogin_mclass ON klogin_mclass;
CREATE TRIGGER trigger_audit_klogin_mclass AFTER INSERT OR DELETE OR UPDATE ON jazzhands.klogin_mclass FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_klogin_mclass();
DROP TRIGGER IF EXISTS trig_userlog_layer2_connection ON layer2_connection;
CREATE TRIGGER trig_userlog_layer2_connection BEFORE INSERT OR UPDATE ON jazzhands.layer2_connection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_connection ON layer2_connection;
CREATE TRIGGER trigger_audit_layer2_connection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_connection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_connection();
DROP TRIGGER IF EXISTS trig_userlog_layer2_connection_layer2_network ON layer2_connection_layer2_network;
CREATE TRIGGER trig_userlog_layer2_connection_layer2_network BEFORE INSERT OR UPDATE ON jazzhands.layer2_connection_layer2_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_connection_layer2_network ON layer2_connection_layer2_network;
CREATE TRIGGER trigger_audit_layer2_connection_layer2_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_connection_layer2_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_connection_layer2_network();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network ON layer2_network;
CREATE TRIGGER trig_userlog_layer2_network BEFORE INSERT OR UPDATE ON jazzhands.layer2_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network ON layer2_network;
CREATE TRIGGER trigger_audit_layer2_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_network();
DROP TRIGGER IF EXISTS layer2_net_collection_member_enforce_on_type_change ON layer2_network_collection;
CREATE CONSTRAINT TRIGGER layer2_net_collection_member_enforce_on_type_change AFTER UPDATE OF layer2_network_collection_type ON jazzhands.layer2_network_collection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer2_net_collection_member_enforce_on_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network_collection ON layer2_network_collection;
CREATE TRIGGER trig_userlog_layer2_network_collection BEFORE INSERT OR UPDATE ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network_collection ON layer2_network_collection;
CREATE TRIGGER trigger_audit_layer2_network_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_network_collection();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_bytype_del ON layer2_network_collection;
CREATE TRIGGER trigger_manip_layer2_network_collection_bytype_del BEFORE DELETE ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer2_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_bytype_insup ON layer2_network_collection;
CREATE TRIGGER trigger_manip_layer2_network_collection_bytype_insup AFTER INSERT OR UPDATE OF layer2_network_collection_type ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer2_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_layer2_network_collection_type_change ON layer2_network_collection;
CREATE TRIGGER trigger_validate_layer2_network_collection_type_change BEFORE UPDATE OF layer2_network_collection_type ON jazzhands.layer2_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_layer2_network_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network_collection_hier ON layer2_network_collection_hier;
CREATE TRIGGER trig_userlog_layer2_network_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.layer2_network_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network_collection_hier ON layer2_network_collection_hier;
CREATE TRIGGER trigger_audit_layer2_network_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_network_collection_hier();
DROP TRIGGER IF EXISTS trigger_hier_layer2_network_collection_after_hooks ON layer2_network_collection_hier;
CREATE TRIGGER trigger_hier_layer2_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_hier FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.layer2_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_layer2_network_collection_hier_enforce ON layer2_network_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_layer2_network_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.layer2_network_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer2_network_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_layer2_network_collection_layer2_network ON layer2_network_collection_layer2_network;
CREATE TRIGGER trig_userlog_layer2_network_collection_layer2_network BEFORE INSERT OR UPDATE ON jazzhands.layer2_network_collection_layer2_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer2_network_collection_layer2_network ON layer2_network_collection_layer2_network;
CREATE TRIGGER trigger_audit_layer2_network_collection_layer2_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_layer2_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer2_network_collection_layer2_network();
DROP TRIGGER IF EXISTS trigger_layer2_network_collection_member_enforce ON layer2_network_collection_layer2_network;
CREATE CONSTRAINT TRIGGER trigger_layer2_network_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.layer2_network_collection_layer2_network DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer2_network_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_member_layer2_network_collection_after_hooks ON layer2_network_collection_layer2_network;
CREATE TRIGGER trigger_member_layer2_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer2_network_collection_layer2_network FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.layer2_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trig_userlog_layer3_acl_chain ON layer3_acl_chain;
CREATE TRIGGER trig_userlog_layer3_acl_chain BEFORE INSERT OR UPDATE ON jazzhands.layer3_acl_chain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_acl_chain ON layer3_acl_chain;
CREATE TRIGGER trigger_audit_layer3_acl_chain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_acl_chain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_acl_chain();
DROP TRIGGER IF EXISTS trig_userlog_layer3_acl_chain_layer3_interface ON layer3_acl_chain_layer3_interface;
CREATE TRIGGER trig_userlog_layer3_acl_chain_layer3_interface BEFORE INSERT OR UPDATE ON jazzhands.layer3_acl_chain_layer3_interface FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_acl_chain_layer3_interface ON layer3_acl_chain_layer3_interface;
CREATE TRIGGER trigger_audit_layer3_acl_chain_layer3_interface AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_acl_chain_layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_acl_chain_layer3_interface();
DROP TRIGGER IF EXISTS trig_userlog_layer3_acl_group ON layer3_acl_group;
CREATE TRIGGER trig_userlog_layer3_acl_group BEFORE INSERT OR UPDATE ON jazzhands.layer3_acl_group FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_acl_group ON layer3_acl_group;
CREATE TRIGGER trigger_audit_layer3_acl_group AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_acl_group FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_acl_group();
DROP TRIGGER IF EXISTS trig_userlog_layer3_acl_rule ON layer3_acl_rule;
CREATE TRIGGER trig_userlog_layer3_acl_rule BEFORE INSERT OR UPDATE ON jazzhands.layer3_acl_rule FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_acl_rule ON layer3_acl_rule;
CREATE TRIGGER trigger_audit_layer3_acl_rule AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_acl_rule FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_acl_rule();
DROP TRIGGER IF EXISTS trig_userlog_layer3_interface ON layer3_interface;
CREATE TRIGGER trig_userlog_layer3_interface BEFORE INSERT OR UPDATE ON jazzhands.layer3_interface FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_interface ON layer3_interface;
CREATE TRIGGER trigger_audit_layer3_interface AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_interface();
DROP TRIGGER IF EXISTS trigger_net_int_device_id_upd ON layer3_interface;
CREATE TRIGGER trigger_net_int_device_id_upd AFTER UPDATE OF device_id ON jazzhands.layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.net_int_device_id_upd();
DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins_before ON layer3_interface;
CREATE TRIGGER trigger_net_int_nb_device_id_ins_before BEFORE UPDATE OF device_id ON jazzhands.layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.net_int_nb_device_id_ins_before();
DROP TRIGGER IF EXISTS trig_userlog_layer3_interface_netblock ON layer3_interface_netblock;
CREATE TRIGGER trig_userlog_layer3_interface_netblock BEFORE INSERT OR UPDATE ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_interface_netblock ON layer3_interface_netblock;
CREATE TRIGGER trigger_audit_layer3_interface_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_interface_netblock();
DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins ON layer3_interface_netblock;
CREATE TRIGGER trigger_net_int_nb_device_id_ins BEFORE INSERT OR UPDATE OF layer3_interface_id ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.net_int_nb_device_id_ins();
DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins_after ON layer3_interface_netblock;
CREATE TRIGGER trigger_net_int_nb_device_id_ins_after AFTER INSERT OR UPDATE OF layer3_interface_id ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.net_int_nb_device_id_ins_after();
DROP TRIGGER IF EXISTS trigger_net_int_nb_single_address ON layer3_interface_netblock;
CREATE TRIGGER trigger_net_int_nb_single_address BEFORE INSERT OR UPDATE OF netblock_id ON jazzhands.layer3_interface_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.net_int_nb_single_address();
DROP TRIGGER IF EXISTS trig_userlog_layer3_interface_purpose ON layer3_interface_purpose;
CREATE TRIGGER trig_userlog_layer3_interface_purpose BEFORE INSERT OR UPDATE ON jazzhands.layer3_interface_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_interface_purpose ON layer3_interface_purpose;
CREATE TRIGGER trigger_audit_layer3_interface_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_interface_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_interface_purpose();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network ON layer3_network;
CREATE TRIGGER trig_userlog_layer3_network BEFORE INSERT OR UPDATE ON jazzhands.layer3_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network ON layer3_network;
CREATE TRIGGER trigger_audit_layer3_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_network();
DROP TRIGGER IF EXISTS trigger_layer3_network_validate_netblock ON layer3_network;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_validate_netblock AFTER INSERT OR UPDATE OF netblock_id ON jazzhands.layer3_network NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer3_network_validate_netblock();
DROP TRIGGER IF EXISTS layer3_net_collection_member_enforce_on_type_change ON layer3_network_collection;
CREATE CONSTRAINT TRIGGER layer3_net_collection_member_enforce_on_type_change AFTER UPDATE OF layer3_network_collection_type ON jazzhands.layer3_network_collection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer3_net_collection_member_enforce_on_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network_collection ON layer3_network_collection;
CREATE TRIGGER trig_userlog_layer3_network_collection BEFORE INSERT OR UPDATE ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network_collection ON layer3_network_collection;
CREATE TRIGGER trigger_audit_layer3_network_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_network_collection();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_bytype_del ON layer3_network_collection;
CREATE TRIGGER trigger_manip_layer3_network_collection_bytype_del BEFORE DELETE ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer3_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_bytype_insup ON layer3_network_collection;
CREATE TRIGGER trigger_manip_layer3_network_collection_bytype_insup AFTER INSERT OR UPDATE OF layer3_network_collection_type ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer3_network_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_layer3_network_collection_type_change ON layer3_network_collection;
CREATE TRIGGER trigger_validate_layer3_network_collection_type_change BEFORE UPDATE OF layer3_network_collection_type ON jazzhands.layer3_network_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_layer3_network_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network_collection_hier ON layer3_network_collection_hier;
CREATE TRIGGER trig_userlog_layer3_network_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.layer3_network_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network_collection_hier ON layer3_network_collection_hier;
CREATE TRIGGER trigger_audit_layer3_network_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_network_collection_hier();
DROP TRIGGER IF EXISTS trigger_hier_layer3_network_collection_after_hooks ON layer3_network_collection_hier;
CREATE TRIGGER trigger_hier_layer3_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_hier FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.layer3_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_layer3_network_collection_hier_enforce ON layer3_network_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.layer3_network_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer3_network_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_layer3_network_collection_layer3_network ON layer3_network_collection_layer3_network;
CREATE TRIGGER trig_userlog_layer3_network_collection_layer3_network BEFORE INSERT OR UPDATE ON jazzhands.layer3_network_collection_layer3_network FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_layer3_network_collection_layer3_network ON layer3_network_collection_layer3_network;
CREATE TRIGGER trigger_audit_layer3_network_collection_layer3_network AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_layer3_network FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_layer3_network_collection_layer3_network();
DROP TRIGGER IF EXISTS trigger_layer3_network_collection_member_enforce ON layer3_network_collection_layer3_network;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.layer3_network_collection_layer3_network DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.layer3_network_collection_member_enforce();
DROP TRIGGER IF EXISTS trigger_member_layer3_network_collection_after_hooks ON layer3_network_collection_layer3_network;
CREATE TRIGGER trigger_member_layer3_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.layer3_network_collection_layer3_network FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.layer3_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trig_userlog_logical_port ON logical_port;
CREATE TRIGGER trig_userlog_logical_port BEFORE INSERT OR UPDATE ON jazzhands.logical_port FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_port ON logical_port;
CREATE TRIGGER trigger_audit_logical_port AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_port FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_logical_port();
DROP TRIGGER IF EXISTS trig_userlog_logical_port_slot ON logical_port_slot;
CREATE TRIGGER trig_userlog_logical_port_slot BEFORE INSERT OR UPDATE ON jazzhands.logical_port_slot FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_port_slot ON logical_port_slot;
CREATE TRIGGER trigger_audit_logical_port_slot AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_port_slot FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_logical_port_slot();
DROP TRIGGER IF EXISTS trig_userlog_logical_volume ON logical_volume;
CREATE TRIGGER trig_userlog_logical_volume BEFORE INSERT OR UPDATE ON jazzhands.logical_volume FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_volume ON logical_volume;
CREATE TRIGGER trigger_audit_logical_volume AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_volume FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_logical_volume();
DROP TRIGGER IF EXISTS trig_userlog_logical_volume_property ON logical_volume_property;
CREATE TRIGGER trig_userlog_logical_volume_property BEFORE INSERT OR UPDATE ON jazzhands.logical_volume_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_volume_property ON logical_volume_property;
CREATE TRIGGER trigger_audit_logical_volume_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_volume_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_logical_volume_property();
DROP TRIGGER IF EXISTS trigger_logical_volume_property_scsi_id_sync_del ON logical_volume_property;
CREATE TRIGGER trigger_logical_volume_property_scsi_id_sync_del AFTER DELETE ON jazzhands.logical_volume_property FOR EACH ROW EXECUTE FUNCTION jazzhands.logical_volume_property_scsi_id_sync();
DROP TRIGGER IF EXISTS trigger_logical_volume_property_scsi_id_sync_ins_upd ON logical_volume_property;
CREATE TRIGGER trigger_logical_volume_property_scsi_id_sync_ins_upd AFTER INSERT OR UPDATE OF logical_volume_id, logical_volume_property_value ON jazzhands.logical_volume_property FOR EACH ROW EXECUTE FUNCTION jazzhands.logical_volume_property_scsi_id_sync();
DROP TRIGGER IF EXISTS trigger_logical_volume_property_to_filesystem_del ON logical_volume_property;
CREATE TRIGGER trigger_logical_volume_property_to_filesystem_del AFTER DELETE ON jazzhands.logical_volume_property FOR EACH ROW EXECUTE FUNCTION jazzhands.logical_volume_property_to_filesystem_del();
DROP TRIGGER IF EXISTS trigger_logical_volume_property_to_filesystem_insupd ON logical_volume_property;
CREATE TRIGGER trigger_logical_volume_property_to_filesystem_insupd AFTER INSERT OR UPDATE ON jazzhands.logical_volume_property FOR EACH ROW EXECUTE FUNCTION jazzhands.logical_volume_property_to_filesystem_insupd();
DROP TRIGGER IF EXISTS trig_userlog_logical_volume_purpose ON logical_volume_purpose;
CREATE TRIGGER trig_userlog_logical_volume_purpose BEFORE INSERT OR UPDATE ON jazzhands.logical_volume_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_logical_volume_purpose ON logical_volume_purpose;
CREATE TRIGGER trigger_audit_logical_volume_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.logical_volume_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_logical_volume_purpose();
DROP TRIGGER IF EXISTS trig_userlog_mlag_peering ON mlag_peering;
CREATE TRIGGER trig_userlog_mlag_peering BEFORE INSERT OR UPDATE ON jazzhands.mlag_peering FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_mlag_peering ON mlag_peering;
CREATE TRIGGER trigger_audit_mlag_peering AFTER INSERT OR DELETE OR UPDATE ON jazzhands.mlag_peering FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_mlag_peering();
DROP TRIGGER IF EXISTS aaa_ta_manipulate_netblock_parentage ON netblock;
CREATE CONSTRAINT TRIGGER aaa_ta_manipulate_netblock_parentage AFTER INSERT OR DELETE ON jazzhands.netblock NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.manipulate_netblock_parentage_after();
DROP TRIGGER IF EXISTS tb_a_validate_netblock ON netblock;
CREATE TRIGGER tb_a_validate_netblock BEFORE INSERT OR UPDATE OF netblock_id, ip_address, netblock_type, is_single_address, can_subnet, parent_netblock_id, ip_universe_id ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_netblock();
DROP TRIGGER IF EXISTS tb_manipulate_netblock_parentage ON netblock;
CREATE TRIGGER tb_manipulate_netblock_parentage BEFORE INSERT OR UPDATE OF ip_address, netblock_type, ip_universe_id, netblock_id, can_subnet, is_single_address ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.manipulate_netblock_parentage_before();
DROP TRIGGER IF EXISTS trig_userlog_netblock ON netblock;
CREATE TRIGGER trig_userlog_netblock BEFORE INSERT OR UPDATE ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock ON netblock;
CREATE TRIGGER trigger_audit_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_netblock();
DROP TRIGGER IF EXISTS trigger_cache_netblock_hier_truncate ON netblock;
CREATE TRIGGER trigger_cache_netblock_hier_truncate AFTER TRUNCATE ON jazzhands.netblock FOR EACH STATEMENT EXECUTE FUNCTION jazzhands_cache.cache_netblock_hier_truncate_handler();
DROP TRIGGER IF EXISTS trigger_check_ip_universe_netblock ON netblock;
CREATE CONSTRAINT TRIGGER trigger_check_ip_universe_netblock AFTER UPDATE OF netblock_id, ip_universe_id ON jazzhands.netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_ip_universe_netblock();
DROP TRIGGER IF EXISTS trigger_nb_dns_a_rec_validation ON netblock;
CREATE TRIGGER trigger_nb_dns_a_rec_validation BEFORE UPDATE OF ip_address, is_single_address ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.nb_dns_a_rec_validation();
DROP TRIGGER IF EXISTS trigger_netblock_single_address_ni ON netblock;
CREATE TRIGGER trigger_netblock_single_address_ni BEFORE UPDATE OF is_single_address, netblock_type ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.netblock_single_address_ni();
DROP TRIGGER IF EXISTS trigger_netblock_validate_layer3_network_netblock ON netblock;
CREATE CONSTRAINT TRIGGER trigger_netblock_validate_layer3_network_netblock AFTER UPDATE OF can_subnet, is_single_address ON jazzhands.netblock NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.netblock_validate_layer3_network_netblock();
DROP TRIGGER IF EXISTS trigger_validate_netblock_parentage ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_parentage AFTER INSERT OR UPDATE OF netblock_id, ip_address, netblock_type, is_single_address, can_subnet, parent_netblock_id, ip_universe_id ON jazzhands.netblock DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_netblock_parentage();
DROP TRIGGER IF EXISTS trigger_validate_netblock_to_range_changes ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_to_range_changes AFTER UPDATE OF ip_address, is_single_address, can_subnet, netblock_type ON jazzhands.netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_netblock_to_range_changes();
DROP TRIGGER IF EXISTS zaa_ta_cache_netblock_hier_handler ON netblock;
CREATE TRIGGER zaa_ta_cache_netblock_hier_handler AFTER INSERT OR DELETE OR UPDATE OF ip_address, parent_netblock_id ON jazzhands.netblock FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.cache_netblock_hier_handler();
DROP TRIGGER IF EXISTS aaa_netblock_collection_base_handler ON netblock_collection;
CREATE TRIGGER aaa_netblock_collection_base_handler AFTER INSERT OR DELETE OR UPDATE OF netblock_collection_id ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.netblock_collection_base_handler();
DROP TRIGGER IF EXISTS trig_userlog_netblock_collection ON netblock_collection;
CREATE TRIGGER trig_userlog_netblock_collection BEFORE INSERT OR UPDATE ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock_collection ON netblock_collection;
CREATE TRIGGER trigger_audit_netblock_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_netblock_collection();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_bytype_del ON netblock_collection;
CREATE TRIGGER trigger_manip_netblock_collection_bytype_del BEFORE DELETE ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_netblock_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_bytype_insup ON netblock_collection;
CREATE TRIGGER trigger_manip_netblock_collection_bytype_insup AFTER INSERT OR UPDATE OF netblock_collection_type ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_netblock_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_netblock_collection_type_change ON netblock_collection;
CREATE TRIGGER trigger_validate_netblock_collection_type_change BEFORE UPDATE OF netblock_collection_type ON jazzhands.netblock_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_netblock_collection_type_change();
DROP TRIGGER IF EXISTS aaa_netblock_collection_root_handler ON netblock_collection_hier;
CREATE TRIGGER aaa_netblock_collection_root_handler AFTER INSERT OR DELETE OR UPDATE OF netblock_collection_id, child_netblock_collection_id ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands_cache.netblock_collection_root_handler();
DROP TRIGGER IF EXISTS trig_userlog_netblock_collection_hier ON netblock_collection_hier;
CREATE TRIGGER trig_userlog_netblock_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock_collection_hier ON netblock_collection_hier;
CREATE TRIGGER trigger_audit_netblock_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_netblock_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_netblock_collection_hier_loop ON netblock_collection_hier;
CREATE TRIGGER trigger_check_netblock_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.netblock_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.check_netblock_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_netblock_collection_hier_enforce ON netblock_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_netblock_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.netblock_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.netblock_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_netblock_collection_netblock ON netblock_collection_netblock;
CREATE TRIGGER trig_userlog_netblock_collection_netblock BEFORE INSERT OR UPDATE ON jazzhands.netblock_collection_netblock FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_netblock_collection_netblock ON netblock_collection_netblock;
CREATE TRIGGER trigger_audit_netblock_collection_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.netblock_collection_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_netblock_collection_netblock();
DROP TRIGGER IF EXISTS trigger_netblock_collection_member_enforce ON netblock_collection_netblock;
CREATE CONSTRAINT TRIGGER trigger_netblock_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.netblock_collection_netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.netblock_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_network_range ON network_range;
CREATE TRIGGER trig_userlog_network_range BEFORE INSERT OR UPDATE ON jazzhands.network_range FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_network_range ON network_range;
CREATE TRIGGER trigger_audit_network_range AFTER INSERT OR DELETE OR UPDATE ON jazzhands.network_range FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_network_range();
DROP TRIGGER IF EXISTS trigger_validate_network_range_dns ON network_range;
CREATE CONSTRAINT TRIGGER trigger_validate_network_range_dns AFTER INSERT OR UPDATE OF dns_domain_id ON jazzhands.network_range DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_network_range_dns();
DROP TRIGGER IF EXISTS trigger_validate_network_range_ips ON network_range;
CREATE CONSTRAINT TRIGGER trigger_validate_network_range_ips AFTER INSERT OR UPDATE OF start_netblock_id, stop_netblock_id, parent_netblock_id, network_range_type ON jazzhands.network_range DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_network_range_ips();
DROP TRIGGER IF EXISTS trig_userlog_network_service ON network_service;
CREATE TRIGGER trig_userlog_network_service BEFORE INSERT OR UPDATE ON jazzhands.network_service FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_network_service ON network_service;
CREATE TRIGGER trigger_audit_network_service AFTER INSERT OR DELETE OR UPDATE ON jazzhands.network_service FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_network_service();
DROP TRIGGER IF EXISTS trig_userlog_operating_system ON operating_system;
CREATE TRIGGER trig_userlog_operating_system BEFORE INSERT OR UPDATE ON jazzhands.operating_system FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_operating_system ON operating_system;
CREATE TRIGGER trigger_audit_operating_system AFTER INSERT OR DELETE OR UPDATE ON jazzhands.operating_system FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_operating_system();
DROP TRIGGER IF EXISTS trig_userlog_operating_system_snapshot ON operating_system_snapshot;
CREATE TRIGGER trig_userlog_operating_system_snapshot BEFORE INSERT OR UPDATE ON jazzhands.operating_system_snapshot FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_operating_system_snapshot ON operating_system_snapshot;
CREATE TRIGGER trigger_audit_operating_system_snapshot AFTER INSERT OR DELETE OR UPDATE ON jazzhands.operating_system_snapshot FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_operating_system_snapshot();
DROP TRIGGER IF EXISTS trig_userlog_person ON person;
CREATE TRIGGER trig_userlog_person BEFORE INSERT OR UPDATE ON jazzhands.person FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person ON person;
CREATE TRIGGER trigger_audit_person AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person();
DROP TRIGGER IF EXISTS trig_userlog_person_account_realm_company ON person_account_realm_company;
CREATE TRIGGER trig_userlog_person_account_realm_company BEFORE INSERT OR UPDATE ON jazzhands.person_account_realm_company FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_account_realm_company ON person_account_realm_company;
CREATE TRIGGER trigger_audit_person_account_realm_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_account_realm_company FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_account_realm_company();
DROP TRIGGER IF EXISTS trig_userlog_person_authentication_question ON person_authentication_question;
CREATE TRIGGER trig_userlog_person_authentication_question BEFORE INSERT OR UPDATE ON jazzhands.person_authentication_question FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_authentication_question ON person_authentication_question;
CREATE TRIGGER trigger_audit_person_authentication_question AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_authentication_question FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_authentication_question();
DROP TRIGGER IF EXISTS trig_userlog_person_company ON person_company;
CREATE TRIGGER trig_userlog_person_company BEFORE INSERT OR UPDATE ON jazzhands.person_company FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_company ON person_company;
CREATE TRIGGER trigger_audit_person_company AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_company FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_company();
DROP TRIGGER IF EXISTS trigger_propagate_person_status_to_account ON person_company;
CREATE TRIGGER trigger_propagate_person_status_to_account AFTER UPDATE ON jazzhands.person_company FOR EACH ROW EXECUTE FUNCTION jazzhands.propagate_person_status_to_account();
DROP TRIGGER IF EXISTS trigger_z_automated_ac_on_person_company ON person_company;
CREATE TRIGGER trigger_z_automated_ac_on_person_company AFTER UPDATE OF is_management, is_exempt, is_full_time, person_id, company_id, manager_person_id ON jazzhands.person_company FOR EACH ROW EXECUTE FUNCTION jazzhands.automated_ac_on_person_company();
DROP TRIGGER IF EXISTS trig_userlog_person_company_attribute ON person_company_attribute;
CREATE TRIGGER trig_userlog_person_company_attribute BEFORE INSERT OR UPDATE ON jazzhands.person_company_attribute FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_company_attribute ON person_company_attribute;
CREATE TRIGGER trigger_audit_person_company_attribute AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_company_attribute FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_company_attribute();
DROP TRIGGER IF EXISTS trigger_validate_person_company_attribute ON person_company_attribute;
CREATE TRIGGER trigger_validate_person_company_attribute BEFORE INSERT OR UPDATE ON jazzhands.person_company_attribute FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_person_company_attribute();
DROP TRIGGER IF EXISTS trig_userlog_person_company_badge ON person_company_badge;
CREATE TRIGGER trig_userlog_person_company_badge BEFORE INSERT OR UPDATE ON jazzhands.person_company_badge FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_company_badge ON person_company_badge;
CREATE TRIGGER trigger_audit_person_company_badge AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_company_badge FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_company_badge();
DROP TRIGGER IF EXISTS trig_userlog_person_contact ON person_contact;
CREATE TRIGGER trig_userlog_person_contact BEFORE INSERT OR UPDATE ON jazzhands.person_contact FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_contact ON person_contact;
CREATE TRIGGER trigger_audit_person_contact AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_contact FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_contact();
DROP TRIGGER IF EXISTS trig_userlog_person_image ON person_image;
CREATE TRIGGER trig_userlog_person_image BEFORE INSERT OR UPDATE ON jazzhands.person_image FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_image ON person_image;
CREATE TRIGGER trigger_audit_person_image AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_image FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_image();
DROP TRIGGER IF EXISTS trigger_fix_person_image_oid_ownership ON person_image;
CREATE TRIGGER trigger_fix_person_image_oid_ownership BEFORE INSERT ON jazzhands.person_image FOR EACH ROW EXECUTE FUNCTION jazzhands.fix_person_image_oid_ownership();
DROP TRIGGER IF EXISTS trig_userlog_person_image_usage ON person_image_usage;
CREATE TRIGGER trig_userlog_person_image_usage BEFORE INSERT OR UPDATE ON jazzhands.person_image_usage FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_image_usage ON person_image_usage;
CREATE TRIGGER trigger_audit_person_image_usage AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_image_usage FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_image_usage();
DROP TRIGGER IF EXISTS trigger_check_person_image_usage_mv ON person_image_usage;
CREATE TRIGGER trigger_check_person_image_usage_mv AFTER INSERT OR UPDATE ON jazzhands.person_image_usage FOR EACH ROW EXECUTE FUNCTION jazzhands.check_person_image_usage_mv();
DROP TRIGGER IF EXISTS trig_automated_realm_site_ac_pl ON person_location;
CREATE TRIGGER trig_automated_realm_site_ac_pl AFTER INSERT OR DELETE OR UPDATE OF site_code, person_id ON jazzhands.person_location FOR EACH ROW EXECUTE FUNCTION jazzhands.automated_realm_site_ac_pl();
DROP TRIGGER IF EXISTS trig_userlog_person_location ON person_location;
CREATE TRIGGER trig_userlog_person_location BEFORE INSERT OR UPDATE ON jazzhands.person_location FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_location ON person_location;
CREATE TRIGGER trigger_audit_person_location AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_location FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_location();
DROP TRIGGER IF EXISTS trig_userlog_person_note ON person_note;
CREATE TRIGGER trig_userlog_person_note BEFORE INSERT OR UPDATE ON jazzhands.person_note FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_note ON person_note;
CREATE TRIGGER trigger_audit_person_note AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_note FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_note();
DROP TRIGGER IF EXISTS trig_userlog_person_parking_pass ON person_parking_pass;
CREATE TRIGGER trig_userlog_person_parking_pass BEFORE INSERT OR UPDATE ON jazzhands.person_parking_pass FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_parking_pass ON person_parking_pass;
CREATE TRIGGER trigger_audit_person_parking_pass AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_parking_pass FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_parking_pass();
DROP TRIGGER IF EXISTS trig_userlog_person_vehicle ON person_vehicle;
CREATE TRIGGER trig_userlog_person_vehicle BEFORE INSERT OR UPDATE ON jazzhands.person_vehicle FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_person_vehicle ON person_vehicle;
CREATE TRIGGER trigger_audit_person_vehicle AFTER INSERT OR DELETE OR UPDATE ON jazzhands.person_vehicle FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_person_vehicle();
DROP TRIGGER IF EXISTS trig_userlog_physical_address ON physical_address;
CREATE TRIGGER trig_userlog_physical_address BEFORE INSERT OR UPDATE ON jazzhands.physical_address FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_physical_address ON physical_address;
CREATE TRIGGER trigger_audit_physical_address AFTER INSERT OR DELETE OR UPDATE ON jazzhands.physical_address FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_physical_address();
DROP TRIGGER IF EXISTS trig_userlog_physical_connection ON physical_connection;
CREATE TRIGGER trig_userlog_physical_connection BEFORE INSERT OR UPDATE ON jazzhands.physical_connection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_physical_connection ON physical_connection;
CREATE TRIGGER trigger_audit_physical_connection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.physical_connection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_physical_connection();
DROP TRIGGER IF EXISTS trigger_verify_physical_connection ON physical_connection;
CREATE TRIGGER trigger_verify_physical_connection AFTER INSERT OR UPDATE ON jazzhands.physical_connection FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.verify_physical_connection();
DROP TRIGGER IF EXISTS trig_userlog_port_range ON port_range;
CREATE TRIGGER trig_userlog_port_range BEFORE INSERT OR UPDATE ON jazzhands.port_range FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_port_range ON port_range;
CREATE TRIGGER trigger_audit_port_range AFTER INSERT OR DELETE OR UPDATE ON jazzhands.port_range FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_port_range();
DROP TRIGGER IF EXISTS trigger_port_range_manage_singleton ON port_range;
CREATE TRIGGER trigger_port_range_manage_singleton BEFORE INSERT ON jazzhands.port_range FOR EACH ROW EXECUTE FUNCTION jazzhands.port_range_manage_singleton();
DROP TRIGGER IF EXISTS trigger_port_range_sanity_check ON port_range;
CREATE CONSTRAINT TRIGGER trigger_port_range_sanity_check AFTER INSERT OR UPDATE OF port_start, port_end, is_singleton ON jazzhands.port_range NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.port_range_sanity_check();
DROP TRIGGER IF EXISTS trig_userlog_private_key ON private_key;
CREATE TRIGGER trig_userlog_private_key BEFORE INSERT OR UPDATE ON jazzhands.private_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_private_key ON private_key;
CREATE TRIGGER trigger_audit_private_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.private_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_private_key();
DROP TRIGGER IF EXISTS trigger_private_key_delete_dangling_hashes ON private_key;
CREATE TRIGGER trigger_private_key_delete_dangling_hashes AFTER DELETE OR UPDATE OF public_key_hash_id ON jazzhands.private_key FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.delete_dangling_public_key_hashes();
DROP TRIGGER IF EXISTS trig_userlog_property ON property;
CREATE TRIGGER trig_userlog_property BEFORE INSERT OR UPDATE ON jazzhands.property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property ON property;
CREATE TRIGGER trigger_audit_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_property();
DROP TRIGGER IF EXISTS trigger_validate_property ON property;
CREATE CONSTRAINT TRIGGER trigger_validate_property AFTER INSERT OR UPDATE ON jazzhands.property NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_property();
DROP TRIGGER IF EXISTS trig_userlog_property_name_collection ON property_name_collection;
CREATE TRIGGER trig_userlog_property_name_collection BEFORE INSERT OR UPDATE ON jazzhands.property_name_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property_name_collection ON property_name_collection;
CREATE TRIGGER trigger_audit_property_name_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_property_name_collection();
DROP TRIGGER IF EXISTS trigger_validate_property_name_collection_type_change ON property_name_collection;
CREATE TRIGGER trigger_validate_property_name_collection_type_change BEFORE UPDATE OF property_name_collection_type ON jazzhands.property_name_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_property_name_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_property_name_collection_hier ON property_name_collection_hier;
CREATE TRIGGER trig_userlog_property_name_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.property_name_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property_name_collection_hier ON property_name_collection_hier;
CREATE TRIGGER trigger_audit_property_name_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_property_name_collection_hier();
DROP TRIGGER IF EXISTS trigger_hier_property_name_collection_after_hooks ON property_name_collection_hier;
CREATE TRIGGER trigger_hier_property_name_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_hier FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.property_name_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_property_name_collection_hier_enforce ON property_name_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_property_name_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.property_name_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.property_name_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_property_name_collection_property_name ON property_name_collection_property_name;
CREATE TRIGGER trig_userlog_property_name_collection_property_name BEFORE INSERT OR UPDATE ON jazzhands.property_name_collection_property_name FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_property_name_collection_property_name ON property_name_collection_property_name;
CREATE TRIGGER trigger_audit_property_name_collection_property_name AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_property_name FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_property_name_collection_property_name();
DROP TRIGGER IF EXISTS trigger_member_property_name_collection_after_hooks ON property_name_collection_property_name;
CREATE TRIGGER trigger_member_property_name_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON jazzhands.property_name_collection_property_name FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.property_name_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_property_name_collection_member_enforce ON property_name_collection_property_name;
CREATE CONSTRAINT TRIGGER trigger_property_name_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.property_name_collection_property_name DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.property_name_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_protocol ON protocol;
CREATE TRIGGER trig_userlog_protocol BEFORE INSERT OR UPDATE ON jazzhands.protocol FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_protocol ON protocol;
CREATE TRIGGER trigger_audit_protocol AFTER INSERT OR DELETE OR UPDATE ON jazzhands.protocol FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_protocol();
DROP TRIGGER IF EXISTS trig_userlog_pseudo_klogin ON pseudo_klogin;
CREATE TRIGGER trig_userlog_pseudo_klogin BEFORE INSERT OR UPDATE ON jazzhands.pseudo_klogin FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_pseudo_klogin ON pseudo_klogin;
CREATE TRIGGER trigger_audit_pseudo_klogin AFTER INSERT OR DELETE OR UPDATE ON jazzhands.pseudo_klogin FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_pseudo_klogin();
DROP TRIGGER IF EXISTS trig_userlog_public_key_hash ON public_key_hash;
CREATE TRIGGER trig_userlog_public_key_hash BEFORE INSERT OR UPDATE ON jazzhands.public_key_hash FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_public_key_hash ON public_key_hash;
CREATE TRIGGER trigger_audit_public_key_hash AFTER INSERT OR DELETE OR UPDATE ON jazzhands.public_key_hash FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_public_key_hash();
DROP TRIGGER IF EXISTS trig_userlog_public_key_hash_hash ON public_key_hash_hash;
CREATE TRIGGER trig_userlog_public_key_hash_hash BEFORE INSERT OR UPDATE ON jazzhands.public_key_hash_hash FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_public_key_hash_hash ON public_key_hash_hash;
CREATE TRIGGER trigger_audit_public_key_hash_hash AFTER INSERT OR DELETE OR UPDATE ON jazzhands.public_key_hash_hash FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_public_key_hash_hash();
DROP TRIGGER IF EXISTS trigger_fingerprint_hash_algorithm ON public_key_hash_hash;
CREATE TRIGGER trigger_fingerprint_hash_algorithm BEFORE INSERT OR UPDATE OF x509_fingerprint_hash_algorighm, cryptographic_hash_algorithm ON jazzhands.public_key_hash_hash FOR EACH ROW EXECUTE FUNCTION jazzhands.check_fingerprint_hash_algorithm();
DROP TRIGGER IF EXISTS trig_userlog_rack ON rack;
CREATE TRIGGER trig_userlog_rack BEFORE INSERT OR UPDATE ON jazzhands.rack FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_rack ON rack;
CREATE TRIGGER trigger_audit_rack AFTER INSERT OR DELETE OR UPDATE ON jazzhands.rack FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_rack();
DROP TRIGGER IF EXISTS trig_userlog_rack_location ON rack_location;
CREATE TRIGGER trig_userlog_rack_location BEFORE INSERT OR UPDATE ON jazzhands.rack_location FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_rack_location ON rack_location;
CREATE TRIGGER trigger_audit_rack_location AFTER INSERT OR DELETE OR UPDATE ON jazzhands.rack_location FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_rack_location();
DROP TRIGGER IF EXISTS trig_userlog_service ON service;
CREATE TRIGGER trig_userlog_service BEFORE INSERT OR UPDATE ON jazzhands.service FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service ON service;
CREATE TRIGGER trigger_audit_service AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service();
DROP TRIGGER IF EXISTS trigger_check_service_namespace ON service;
CREATE CONSTRAINT TRIGGER trigger_check_service_namespace AFTER INSERT OR UPDATE OF service_name, service_type ON jazzhands.service NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_service_namespace();
DROP TRIGGER IF EXISTS trigger_create_all_services_collection ON service;
CREATE TRIGGER trigger_create_all_services_collection AFTER INSERT OR UPDATE OF service_name, service_type ON jazzhands.service FOR EACH ROW EXECUTE FUNCTION jazzhands.create_all_services_collection();
DROP TRIGGER IF EXISTS trigger_create_all_services_collection_del ON service;
CREATE TRIGGER trigger_create_all_services_collection_del BEFORE DELETE ON jazzhands.service FOR EACH ROW EXECUTE FUNCTION jazzhands.create_all_services_collection();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint ON service_endpoint;
CREATE TRIGGER trig_userlog_service_endpoint BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint ON service_endpoint;
CREATE TRIGGER trigger_audit_service_endpoint AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint();
DROP TRIGGER IF EXISTS trigger_service_endpoint_direct_check ON service_endpoint;
CREATE CONSTRAINT TRIGGER trigger_service_endpoint_direct_check AFTER INSERT OR UPDATE OF dns_record_id, port_range_id ON jazzhands.service_endpoint DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_endpoint_direct_check();
DROP TRIGGER IF EXISTS trigger_validate_service_endpoint_fksets ON service_endpoint;
CREATE CONSTRAINT TRIGGER trigger_validate_service_endpoint_fksets AFTER INSERT OR UPDATE OF dns_record_id, port_range_id ON jazzhands.service_endpoint NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_service_endpoint_fksets();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_health_check ON service_endpoint_health_check;
CREATE TRIGGER trig_userlog_service_endpoint_health_check BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_health_check FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_health_check ON service_endpoint_health_check;
CREATE TRIGGER trigger_audit_service_endpoint_health_check AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_health_check FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_health_check();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_provider ON service_endpoint_provider;
CREATE TRIGGER trig_userlog_service_endpoint_provider BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_provider FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_provider ON service_endpoint_provider;
CREATE TRIGGER trigger_audit_service_endpoint_provider AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_provider FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_provider();
DROP TRIGGER IF EXISTS trigger_service_endpoint_provider_direct_check ON service_endpoint_provider;
CREATE CONSTRAINT TRIGGER trigger_service_endpoint_provider_direct_check AFTER INSERT OR UPDATE OF service_endpoint_provider_type, dns_record_id ON jazzhands.service_endpoint_provider DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_endpoint_provider_direct_check();
DROP TRIGGER IF EXISTS trigger_service_endpoint_provider_dns_netblock_check ON service_endpoint_provider;
CREATE CONSTRAINT TRIGGER trigger_service_endpoint_provider_dns_netblock_check AFTER INSERT OR UPDATE OF dns_record_id, netblock_id ON jazzhands.service_endpoint_provider NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_endpoint_provider_dns_netblock_check();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_provider_collection ON service_endpoint_provider_collection;
CREATE TRIGGER trig_userlog_service_endpoint_provider_collection BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_provider_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_provider_collection ON service_endpoint_provider_collection;
CREATE TRIGGER trigger_audit_service_endpoint_provider_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_provider_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_provider_collection();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_provider_collection_service_endpo ON service_endpoint_provider_collection_service_endpoint_provider;
CREATE TRIGGER trig_userlog_service_endpoint_provider_collection_service_endpo BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_provider_collection_service_endpoint_provider FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_provider_collection_service_endp ON service_endpoint_provider_collection_service_endpoint_provider;
CREATE TRIGGER trigger_audit_service_endpoint_provider_collection_service_endp AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_provider_collection_service_endpoint_provider FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_provider_collection_service_endp();
DROP TRIGGER IF EXISTS trigger_svc_ep_coll_sep_direct_check ON service_endpoint_provider_collection_service_endpoint_provider;
CREATE CONSTRAINT TRIGGER trigger_svc_ep_coll_sep_direct_check AFTER INSERT OR UPDATE OF service_endpoint_provider_collection_id, service_endpoint_provider_id ON jazzhands.service_endpoint_provider_collection_service_endpoint_provider DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.svc_ep_coll_sep_direct_check();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_provider_service_instance ON service_endpoint_provider_service_instance;
CREATE TRIGGER trig_userlog_service_endpoint_provider_service_instance BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_provider_service_instance FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_provider_service_instance ON service_endpoint_provider_service_instance;
CREATE TRIGGER trigger_audit_service_endpoint_provider_service_instance AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_provider_service_instance FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_provider_service_instance();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_provider_shared_netblock_layer3_i ON service_endpoint_provider_shared_netblock_layer3_interface;
CREATE TRIGGER trig_userlog_service_endpoint_provider_shared_netblock_layer3_i BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_provider_shared_netblock_layer3_interface FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_provider_shared_netblock_layer3_ ON service_endpoint_provider_shared_netblock_layer3_interface;
CREATE TRIGGER trigger_audit_service_endpoint_provider_shared_netblock_layer3_ AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_provider_shared_netblock_layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_provider_shared_netblock_layer3_();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_service_endpoint_provider_collect ON service_endpoint_service_endpoint_provider_collection;
CREATE TRIGGER trig_userlog_service_endpoint_service_endpoint_provider_collect BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_service_endpoint_provider_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_service_endpoint_provider_collec ON service_endpoint_service_endpoint_provider_collection;
CREATE TRIGGER trigger_audit_service_endpoint_service_endpoint_provider_collec AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_service_endpoint_provider_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_service_endpoint_provider_collec();
DROP TRIGGER IF EXISTS trigger_svc_end_prov_svc_end_col_direct_check ON service_endpoint_service_endpoint_provider_collection;
CREATE CONSTRAINT TRIGGER trigger_svc_end_prov_svc_end_col_direct_check AFTER INSERT OR UPDATE OF service_endpoint_provider_collection_id, service_endpoint_relation_type, service_endpoint_relation_key ON jazzhands.service_endpoint_service_endpoint_provider_collection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.svc_end_prov_svc_end_col_direct_check();
DROP TRIGGER IF EXISTS trigger_svc_ep_svc_epp_coll_direct ON service_endpoint_service_endpoint_provider_collection;
CREATE CONSTRAINT TRIGGER trigger_svc_ep_svc_epp_coll_direct AFTER INSERT OR UPDATE OF service_endpoint_relation_type, service_endpoint_relation_key ON jazzhands.service_endpoint_service_endpoint_provider_collection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.svc_ep_svc_epp_coll_direct();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_service_sla ON service_endpoint_service_sla;
CREATE TRIGGER trig_userlog_service_endpoint_service_sla BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_service_sla FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_service_sla ON service_endpoint_service_sla;
CREATE TRIGGER trigger_audit_service_endpoint_service_sla AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_service_sla FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_service_sla();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_service_sla_service_feature ON service_endpoint_service_sla_service_feature;
CREATE TRIGGER trig_userlog_service_endpoint_service_sla_service_feature BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_service_sla_service_feature FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_service_sla_service_feature ON service_endpoint_service_sla_service_feature;
CREATE TRIGGER trigger_audit_service_endpoint_service_sla_service_feature AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_service_sla_service_feature FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_service_sla_service_feature();
DROP TRIGGER IF EXISTS trig_userlog_service_endpoint_x509_certificate ON service_endpoint_x509_certificate;
CREATE TRIGGER trig_userlog_service_endpoint_x509_certificate BEFORE INSERT OR UPDATE ON jazzhands.service_endpoint_x509_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_endpoint_x509_certificate ON service_endpoint_x509_certificate;
CREATE TRIGGER trigger_audit_service_endpoint_x509_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_endpoint_x509_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_endpoint_x509_certificate();
DROP TRIGGER IF EXISTS trig_userlog_service_environment ON service_environment;
CREATE TRIGGER trig_userlog_service_environment BEFORE INSERT OR UPDATE ON jazzhands.service_environment FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment ON service_environment;
CREATE TRIGGER trigger_audit_service_environment AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_environment();
DROP TRIGGER IF EXISTS trigger_delete_per_service_environment_service_environment_coll ON service_environment;
CREATE TRIGGER trigger_delete_per_service_environment_service_environment_coll BEFORE DELETE ON jazzhands.service_environment FOR EACH ROW EXECUTE FUNCTION jazzhands.delete_per_service_environment_service_environment_collection();
DROP TRIGGER IF EXISTS trigger_update_per_service_environment_service_environment_coll ON service_environment;
CREATE TRIGGER trigger_update_per_service_environment_service_environment_coll AFTER INSERT OR UPDATE ON jazzhands.service_environment FOR EACH ROW EXECUTE FUNCTION jazzhands.update_per_service_environment_service_environment_collection();
DROP TRIGGER IF EXISTS trig_userlog_service_environment_collection ON service_environment_collection;
CREATE TRIGGER trig_userlog_service_environment_collection BEFORE INSERT OR UPDATE ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment_collection ON service_environment_collection;
CREATE TRIGGER trigger_audit_service_environment_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_environment_collection();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_bytype_del ON service_environment_collection;
CREATE TRIGGER trigger_manip_service_environment_collection_bytype_del BEFORE DELETE ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_service_environment_collection_bytype();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_bytype_insup ON service_environment_collection;
CREATE TRIGGER trigger_manip_service_environment_collection_bytype_insup AFTER INSERT OR UPDATE OF service_environment_collection_type ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_service_environment_collection_bytype();
DROP TRIGGER IF EXISTS trigger_validate_service_environment_collection_type_change ON service_environment_collection;
CREATE TRIGGER trigger_validate_service_environment_collection_type_change BEFORE UPDATE OF service_environment_collection_type ON jazzhands.service_environment_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_service_environment_collection_type_change();
DROP TRIGGER IF EXISTS trig_userlog_service_environment_collection_hier ON service_environment_collection_hier;
CREATE TRIGGER trig_userlog_service_environment_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.service_environment_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment_collection_hier ON service_environment_collection_hier;
CREATE TRIGGER trigger_audit_service_environment_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_environment_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_svcenv_collection_hier_loop ON service_environment_collection_hier;
CREATE TRIGGER trigger_check_svcenv_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.service_environment_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.check_svcenv_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_service_environment_collection_hier_enforce ON service_environment_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_service_environment_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.service_environment_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_environment_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_service_environment_collection_service_environment ON service_environment_collection_service_environment;
CREATE TRIGGER trig_userlog_service_environment_collection_service_environment BEFORE INSERT OR UPDATE ON jazzhands.service_environment_collection_service_environment FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_environment_collection_service_environmen ON service_environment_collection_service_environment;
CREATE TRIGGER trigger_audit_service_environment_collection_service_environmen AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_environment_collection_service_environment FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_environment_collection_service_environmen();
DROP TRIGGER IF EXISTS trigger_service_environment_collection_member_enforce ON service_environment_collection_service_environment;
CREATE CONSTRAINT TRIGGER trigger_service_environment_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.service_environment_collection_service_environment DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_environment_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_service_instance ON service_instance;
CREATE TRIGGER trig_userlog_service_instance BEFORE INSERT OR UPDATE ON jazzhands.service_instance FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_instance ON service_instance;
CREATE TRIGGER trigger_audit_service_instance AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_instance FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_instance();
DROP TRIGGER IF EXISTS trig_userlog_service_instance_provided_feature ON service_instance_provided_feature;
CREATE TRIGGER trig_userlog_service_instance_provided_feature BEFORE INSERT OR UPDATE ON jazzhands.service_instance_provided_feature FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_instance_provided_feature ON service_instance_provided_feature;
CREATE TRIGGER trigger_audit_service_instance_provided_feature AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_instance_provided_feature FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_instance_provided_feature();
DROP TRIGGER IF EXISTS trigger_service_instance_feature_check ON service_instance_provided_feature;
CREATE CONSTRAINT TRIGGER trigger_service_instance_feature_check AFTER INSERT ON jazzhands.service_instance_provided_feature NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_instance_feature_check();
DROP TRIGGER IF EXISTS trigger_service_instance_service_feature_rename ON service_instance_provided_feature;
CREATE CONSTRAINT TRIGGER trigger_service_instance_service_feature_rename AFTER UPDATE OF service_feature, service_instance_id ON jazzhands.service_instance_provided_feature NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_instance_service_feature_rename();
DROP TRIGGER IF EXISTS trig_userlog_service_layer3_acl ON service_layer3_acl;
CREATE TRIGGER trig_userlog_service_layer3_acl BEFORE INSERT OR UPDATE ON jazzhands.service_layer3_acl FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_layer3_acl ON service_layer3_acl;
CREATE TRIGGER trigger_audit_service_layer3_acl AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_layer3_acl FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_layer3_acl();
DROP TRIGGER IF EXISTS trig_userlog_service_relationship ON service_relationship;
CREATE TRIGGER trig_userlog_service_relationship BEFORE INSERT OR UPDATE ON jazzhands.service_relationship FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_relationship ON service_relationship;
CREATE TRIGGER trigger_audit_service_relationship AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_relationship FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_relationship();
DROP TRIGGER IF EXISTS trigger_check_service_relationship_rhs ON service_relationship;
CREATE CONSTRAINT TRIGGER trigger_check_service_relationship_rhs AFTER INSERT OR UPDATE OF related_service_version_id, service_version_restriction_service_id, service_version_restriction ON jazzhands.service_relationship NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_service_relationship_rhs();
DROP TRIGGER IF EXISTS trig_userlog_service_relationship_service_feature ON service_relationship_service_feature;
CREATE TRIGGER trig_userlog_service_relationship_service_feature BEFORE INSERT OR UPDATE ON jazzhands.service_relationship_service_feature FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_relationship_service_feature ON service_relationship_service_feature;
CREATE TRIGGER trigger_audit_service_relationship_service_feature AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_relationship_service_feature FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_relationship_service_feature();
DROP TRIGGER IF EXISTS trigger_service_relationship_feature_check ON service_relationship_service_feature;
CREATE CONSTRAINT TRIGGER trigger_service_relationship_feature_check AFTER INSERT OR UPDATE OF service_feature ON jazzhands.service_relationship_service_feature NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_relationship_feature_check();
DROP TRIGGER IF EXISTS trig_userlog_service_sla ON service_sla;
CREATE TRIGGER trig_userlog_service_sla BEFORE INSERT OR UPDATE ON jazzhands.service_sla FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_sla ON service_sla;
CREATE TRIGGER trigger_audit_service_sla AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_sla FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_sla();
DROP TRIGGER IF EXISTS trig_userlog_service_software_repository ON service_software_repository;
CREATE TRIGGER trig_userlog_service_software_repository BEFORE INSERT OR UPDATE ON jazzhands.service_software_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_software_repository ON service_software_repository;
CREATE TRIGGER trigger_audit_service_software_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_software_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_software_repository();
DROP TRIGGER IF EXISTS trig_userlog_service_source_repository ON service_source_repository;
CREATE TRIGGER trig_userlog_service_source_repository BEFORE INSERT OR UPDATE ON jazzhands.service_source_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_source_repository ON service_source_repository;
CREATE TRIGGER trigger_audit_service_source_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_source_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_source_repository();
DROP TRIGGER IF EXISTS trigger_service_source_repository_sanity ON service_source_repository;
CREATE CONSTRAINT TRIGGER trigger_service_source_repository_sanity AFTER INSERT OR UPDATE OF is_primary ON jazzhands.service_source_repository NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_source_repository_sanity();
DROP TRIGGER IF EXISTS trigger_service_source_repository_service_match_check ON service_source_repository;
CREATE CONSTRAINT TRIGGER trigger_service_source_repository_service_match_check AFTER UPDATE OF service_id, service_source_repository_id ON jazzhands.service_source_repository NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_source_repository_service_match_check();
DROP TRIGGER IF EXISTS trig_userlog_service_version ON service_version;
CREATE TRIGGER trig_userlog_service_version BEFORE INSERT OR UPDATE ON jazzhands.service_version FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version ON service_version;
CREATE TRIGGER trigger_audit_service_version AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version();
DROP TRIGGER IF EXISTS trigger_manip_all_svc_collection_members ON service_version;
CREATE TRIGGER trigger_manip_all_svc_collection_members AFTER INSERT OR UPDATE OF service_id ON jazzhands.service_version FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_all_svc_collection_members();
DROP TRIGGER IF EXISTS trigger_manip_all_svc_collection_members_del ON service_version;
CREATE TRIGGER trigger_manip_all_svc_collection_members_del BEFORE DELETE ON jazzhands.service_version FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_all_svc_collection_members();
DROP TRIGGER IF EXISTS trigger_propagate_service_type_to_version ON service_version;
CREATE TRIGGER trigger_propagate_service_type_to_version BEFORE INSERT ON jazzhands.service_version FOR EACH ROW EXECUTE FUNCTION jazzhands.propagate_service_type_to_version();
DROP TRIGGER IF EXISTS trigger_service_version_service_version_purpose_enforce ON service_version;
CREATE CONSTRAINT TRIGGER trigger_service_version_service_version_purpose_enforce AFTER UPDATE OF service_id ON jazzhands.service_version NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_version_service_version_purpose_enforce();
DROP TRIGGER IF EXISTS trig_userlog_service_version_artifact ON service_version_artifact;
CREATE TRIGGER trig_userlog_service_version_artifact BEFORE INSERT OR UPDATE ON jazzhands.service_version_artifact FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_artifact ON service_version_artifact;
CREATE TRIGGER trigger_audit_service_version_artifact AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_artifact FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_artifact();
DROP TRIGGER IF EXISTS trig_userlog_service_version_collection ON service_version_collection;
CREATE TRIGGER trig_userlog_service_version_collection BEFORE INSERT OR UPDATE ON jazzhands.service_version_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_collection ON service_version_collection;
CREATE TRIGGER trigger_audit_service_version_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_collection();
DROP TRIGGER IF EXISTS trig_userlog_service_version_collection_hier ON service_version_collection_hier;
CREATE TRIGGER trig_userlog_service_version_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.service_version_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_collection_hier ON service_version_collection_hier;
CREATE TRIGGER trigger_audit_service_version_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_collection_hier();
DROP TRIGGER IF EXISTS trig_userlog_service_version_collection_permitted_feature ON service_version_collection_permitted_feature;
CREATE TRIGGER trig_userlog_service_version_collection_permitted_feature BEFORE INSERT OR UPDATE ON jazzhands.service_version_collection_permitted_feature FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_collection_permitted_feature ON service_version_collection_permitted_feature;
CREATE TRIGGER trigger_audit_service_version_collection_permitted_feature AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_collection_permitted_feature FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_collection_permitted_feature();
DROP TRIGGER IF EXISTS trigger_service_version_feature_permitted_rename ON service_version_collection_permitted_feature;
CREATE CONSTRAINT TRIGGER trigger_service_version_feature_permitted_rename AFTER UPDATE OF service_feature ON jazzhands.service_version_collection_permitted_feature NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_version_feature_permitted_rename();
DROP TRIGGER IF EXISTS trig_userlog_service_version_collection_service_version ON service_version_collection_service_version;
CREATE TRIGGER trig_userlog_service_version_collection_service_version BEFORE INSERT OR UPDATE ON jazzhands.service_version_collection_service_version FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_collection_service_version ON service_version_collection_service_version;
CREATE TRIGGER trigger_audit_service_version_collection_service_version AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_collection_service_version FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_collection_service_version();
DROP TRIGGER IF EXISTS trigger_service_version_collection_purpose_service_version_enfo ON service_version_collection_service_version;
CREATE CONSTRAINT TRIGGER trigger_service_version_collection_purpose_service_version_enfo AFTER INSERT OR UPDATE OF service_version_collection_id, service_version_id ON jazzhands.service_version_collection_service_version NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_version_collection_purpose_service_version_enforce();
DROP TRIGGER IF EXISTS trig_userlog_service_version_software_artifact_repository ON service_version_software_artifact_repository;
CREATE TRIGGER trig_userlog_service_version_software_artifact_repository BEFORE INSERT OR UPDATE ON jazzhands.service_version_software_artifact_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_software_artifact_repository ON service_version_software_artifact_repository;
CREATE TRIGGER trigger_audit_service_version_software_artifact_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_software_artifact_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_software_artifact_repository();
DROP TRIGGER IF EXISTS trig_userlog_service_version_source_repository ON service_version_source_repository;
CREATE TRIGGER trig_userlog_service_version_source_repository BEFORE INSERT OR UPDATE ON jazzhands.service_version_source_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_service_version_source_repository ON service_version_source_repository;
CREATE TRIGGER trigger_audit_service_version_source_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.service_version_source_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_service_version_source_repository();
DROP TRIGGER IF EXISTS trigger_service_version_source_repository_service_match_check ON service_version_source_repository;
CREATE CONSTRAINT TRIGGER trigger_service_version_source_repository_service_match_check AFTER INSERT OR UPDATE OF service_version_id, service_source_repository_id ON jazzhands.service_version_source_repository NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.service_version_source_repository_service_match_check();
DROP TRIGGER IF EXISTS trig_userlog_shared_netblock ON shared_netblock;
CREATE TRIGGER trig_userlog_shared_netblock BEFORE INSERT OR UPDATE ON jazzhands.shared_netblock FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_shared_netblock ON shared_netblock;
CREATE TRIGGER trigger_audit_shared_netblock AFTER INSERT OR DELETE OR UPDATE ON jazzhands.shared_netblock FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_shared_netblock();
DROP TRIGGER IF EXISTS trig_userlog_shared_netblock_layer3_interface ON shared_netblock_layer3_interface;
CREATE TRIGGER trig_userlog_shared_netblock_layer3_interface BEFORE INSERT OR UPDATE ON jazzhands.shared_netblock_layer3_interface FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_shared_netblock_layer3_interface ON shared_netblock_layer3_interface;
CREATE TRIGGER trigger_audit_shared_netblock_layer3_interface AFTER INSERT OR DELETE OR UPDATE ON jazzhands.shared_netblock_layer3_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_shared_netblock_layer3_interface();
DROP TRIGGER IF EXISTS trig_userlog_site ON site;
CREATE TRIGGER trig_userlog_site BEFORE INSERT OR UPDATE ON jazzhands.site FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_site ON site;
CREATE TRIGGER trigger_audit_site AFTER INSERT OR DELETE OR UPDATE ON jazzhands.site FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_site();
DROP TRIGGER IF EXISTS trigger_del_site_netblock_collections ON site;
CREATE TRIGGER trigger_del_site_netblock_collections BEFORE DELETE ON jazzhands.site FOR EACH ROW EXECUTE FUNCTION jazzhands.del_site_netblock_collections();
DROP TRIGGER IF EXISTS trigger_ins_site_netblock_collections ON site;
CREATE TRIGGER trigger_ins_site_netblock_collections AFTER INSERT ON jazzhands.site FOR EACH ROW EXECUTE FUNCTION jazzhands.ins_site_netblock_collections();
DROP TRIGGER IF EXISTS trigger_upd_site_netblock_collections ON site;
CREATE TRIGGER trigger_upd_site_netblock_collections AFTER UPDATE ON jazzhands.site FOR EACH ROW EXECUTE FUNCTION jazzhands.upd_site_netblock_collections();
DROP TRIGGER IF EXISTS trig_userlog_site_encapsulation_domain ON site_encapsulation_domain;
CREATE TRIGGER trig_userlog_site_encapsulation_domain BEFORE INSERT OR UPDATE ON jazzhands.site_encapsulation_domain FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_site_encapsulation_domain ON site_encapsulation_domain;
CREATE TRIGGER trigger_audit_site_encapsulation_domain AFTER INSERT OR DELETE OR UPDATE ON jazzhands.site_encapsulation_domain FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_site_encapsulation_domain();
DROP TRIGGER IF EXISTS trig_userlog_slot ON slot;
CREATE TRIGGER trig_userlog_slot BEFORE INSERT OR UPDATE ON jazzhands.slot FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot ON slot;
CREATE TRIGGER trigger_audit_slot AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_slot();
DROP TRIGGER IF EXISTS trig_userlog_slot_type ON slot_type;
CREATE TRIGGER trig_userlog_slot_type BEFORE INSERT OR UPDATE ON jazzhands.slot_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot_type ON slot_type;
CREATE TRIGGER trigger_audit_slot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_slot_type();
DROP TRIGGER IF EXISTS trig_userlog_slot_type_permitted_component_slot_type ON slot_type_permitted_component_slot_type;
CREATE TRIGGER trig_userlog_slot_type_permitted_component_slot_type BEFORE INSERT OR UPDATE ON jazzhands.slot_type_permitted_component_slot_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot_type_permitted_component_slot_type ON slot_type_permitted_component_slot_type;
CREATE TRIGGER trigger_audit_slot_type_permitted_component_slot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot_type_permitted_component_slot_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_slot_type_permitted_component_slot_type();
DROP TRIGGER IF EXISTS trig_userlog_slot_type_permitted_remote_slot_type ON slot_type_permitted_remote_slot_type;
CREATE TRIGGER trig_userlog_slot_type_permitted_remote_slot_type BEFORE INSERT OR UPDATE ON jazzhands.slot_type_permitted_remote_slot_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_slot_type_permitted_remote_slot_type ON slot_type_permitted_remote_slot_type;
CREATE TRIGGER trigger_audit_slot_type_permitted_remote_slot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.slot_type_permitted_remote_slot_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_slot_type_permitted_remote_slot_type();
DROP TRIGGER IF EXISTS trig_userlog_software_artifact_name ON software_artifact_name;
CREATE TRIGGER trig_userlog_software_artifact_name BEFORE INSERT OR UPDATE ON jazzhands.software_artifact_name FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_software_artifact_name ON software_artifact_name;
CREATE TRIGGER trigger_audit_software_artifact_name AFTER INSERT OR DELETE OR UPDATE ON jazzhands.software_artifact_name FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_software_artifact_name();
DROP TRIGGER IF EXISTS trig_userlog_software_artifact_provider ON software_artifact_provider;
CREATE TRIGGER trig_userlog_software_artifact_provider BEFORE INSERT OR UPDATE ON jazzhands.software_artifact_provider FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_software_artifact_provider ON software_artifact_provider;
CREATE TRIGGER trigger_audit_software_artifact_provider AFTER INSERT OR DELETE OR UPDATE ON jazzhands.software_artifact_provider FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_software_artifact_provider();
DROP TRIGGER IF EXISTS trig_userlog_software_artifact_repository ON software_artifact_repository;
CREATE TRIGGER trig_userlog_software_artifact_repository BEFORE INSERT OR UPDATE ON jazzhands.software_artifact_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_software_artifact_repository ON software_artifact_repository;
CREATE TRIGGER trigger_audit_software_artifact_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.software_artifact_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_software_artifact_repository();
DROP TRIGGER IF EXISTS trig_userlog_software_artifact_repository_relation ON software_artifact_repository_relation;
CREATE TRIGGER trig_userlog_software_artifact_repository_relation BEFORE INSERT OR UPDATE ON jazzhands.software_artifact_repository_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_software_artifact_repository_relation ON software_artifact_repository_relation;
CREATE TRIGGER trigger_audit_software_artifact_repository_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.software_artifact_repository_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_software_artifact_repository_relation();
DROP TRIGGER IF EXISTS trig_userlog_software_artifact_repository_uri ON software_artifact_repository_uri;
CREATE TRIGGER trig_userlog_software_artifact_repository_uri BEFORE INSERT OR UPDATE ON jazzhands.software_artifact_repository_uri FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_software_artifact_repository_uri ON software_artifact_repository_uri;
CREATE TRIGGER trigger_audit_software_artifact_repository_uri AFTER INSERT OR DELETE OR UPDATE ON jazzhands.software_artifact_repository_uri FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_software_artifact_repository_uri();
DROP TRIGGER IF EXISTS trigger_software_artifact_repository_uri_endpoint_enforce ON software_artifact_repository_uri;
CREATE CONSTRAINT TRIGGER trigger_software_artifact_repository_uri_endpoint_enforce AFTER INSERT OR UPDATE OF software_artifact_repository_uri, service_endpoint_id ON jazzhands.software_artifact_repository_uri NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.software_artifact_repository_uri_endpoint_enforce();
DROP TRIGGER IF EXISTS trig_userlog_source_repository ON source_repository;
CREATE TRIGGER trig_userlog_source_repository BEFORE INSERT OR UPDATE ON jazzhands.source_repository FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_source_repository ON source_repository;
CREATE TRIGGER trigger_audit_source_repository AFTER INSERT OR DELETE OR UPDATE ON jazzhands.source_repository FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_source_repository();
DROP TRIGGER IF EXISTS trig_userlog_source_repository_commit ON source_repository_commit;
CREATE TRIGGER trig_userlog_source_repository_commit BEFORE INSERT OR UPDATE ON jazzhands.source_repository_commit FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_source_repository_commit ON source_repository_commit;
CREATE TRIGGER trigger_audit_source_repository_commit AFTER INSERT OR DELETE OR UPDATE ON jazzhands.source_repository_commit FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_source_repository_commit();
DROP TRIGGER IF EXISTS trig_userlog_source_repository_project ON source_repository_project;
CREATE TRIGGER trig_userlog_source_repository_project BEFORE INSERT OR UPDATE ON jazzhands.source_repository_project FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_source_repository_project ON source_repository_project;
CREATE TRIGGER trigger_audit_source_repository_project AFTER INSERT OR DELETE OR UPDATE ON jazzhands.source_repository_project FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_source_repository_project();
DROP TRIGGER IF EXISTS trig_userlog_source_repository_provider ON source_repository_provider;
CREATE TRIGGER trig_userlog_source_repository_provider BEFORE INSERT OR UPDATE ON jazzhands.source_repository_provider FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_source_repository_provider ON source_repository_provider;
CREATE TRIGGER trigger_audit_source_repository_provider AFTER INSERT OR DELETE OR UPDATE ON jazzhands.source_repository_provider FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_source_repository_provider();
DROP TRIGGER IF EXISTS trig_userlog_source_repository_provider_uri_template ON source_repository_provider_uri_template;
CREATE TRIGGER trig_userlog_source_repository_provider_uri_template BEFORE INSERT OR UPDATE ON jazzhands.source_repository_provider_uri_template FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_source_repository_provider_uri_template ON source_repository_provider_uri_template;
CREATE TRIGGER trigger_audit_source_repository_provider_uri_template AFTER INSERT OR DELETE OR UPDATE ON jazzhands.source_repository_provider_uri_template FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_source_repository_provider_uri_template();
DROP TRIGGER IF EXISTS trigger_source_repository_provider_uri_template_endpoint_enforc ON source_repository_provider_uri_template;
CREATE CONSTRAINT TRIGGER trigger_source_repository_provider_uri_template_endpoint_enforc AFTER INSERT OR UPDATE OF source_repository_uri, service_endpoint_id ON jazzhands.source_repository_provider_uri_template NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.source_repository_provider_uri_template_endpoint_enforce();
DROP TRIGGER IF EXISTS trig_userlog_ssh_key ON ssh_key;
CREATE TRIGGER trig_userlog_ssh_key BEFORE INSERT OR UPDATE ON jazzhands.ssh_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ssh_key ON ssh_key;
CREATE TRIGGER trigger_audit_ssh_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ssh_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_ssh_key();
DROP TRIGGER IF EXISTS trig_userlog_static_route ON static_route;
CREATE TRIGGER trig_userlog_static_route BEFORE INSERT OR UPDATE ON jazzhands.static_route FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_static_route ON static_route;
CREATE TRIGGER trigger_audit_static_route AFTER INSERT OR DELETE OR UPDATE ON jazzhands.static_route FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_static_route();
DROP TRIGGER IF EXISTS trig_userlog_static_route_template ON static_route_template;
CREATE TRIGGER trig_userlog_static_route_template BEFORE INSERT OR UPDATE ON jazzhands.static_route_template FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_static_route_template ON static_route_template;
CREATE TRIGGER trigger_audit_static_route_template AFTER INSERT OR DELETE OR UPDATE ON jazzhands.static_route_template FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_static_route_template();
DROP TRIGGER IF EXISTS trig_userlog_sudo_account_collection_device_collection ON sudo_account_collection_device_collection;
CREATE TRIGGER trig_userlog_sudo_account_collection_device_collection BEFORE INSERT OR UPDATE ON jazzhands.sudo_account_collection_device_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_sudo_account_collection_device_collection ON sudo_account_collection_device_collection;
CREATE TRIGGER trigger_audit_sudo_account_collection_device_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.sudo_account_collection_device_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_sudo_account_collection_device_collection();
DROP TRIGGER IF EXISTS trig_userlog_sudo_alias ON sudo_alias;
CREATE TRIGGER trig_userlog_sudo_alias BEFORE INSERT OR UPDATE ON jazzhands.sudo_alias FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_sudo_alias ON sudo_alias;
CREATE TRIGGER trigger_audit_sudo_alias AFTER INSERT OR DELETE OR UPDATE ON jazzhands.sudo_alias FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_sudo_alias();
DROP TRIGGER IF EXISTS trig_userlog_ticketing_system ON ticketing_system;
CREATE TRIGGER trig_userlog_ticketing_system BEFORE INSERT OR UPDATE ON jazzhands.ticketing_system FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_ticketing_system ON ticketing_system;
CREATE TRIGGER trigger_audit_ticketing_system AFTER INSERT OR DELETE OR UPDATE ON jazzhands.ticketing_system FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_ticketing_system();
DROP TRIGGER IF EXISTS trig_userlog_token ON token;
CREATE TRIGGER trig_userlog_token BEFORE INSERT OR UPDATE ON jazzhands.token FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token ON token;
CREATE TRIGGER trigger_audit_token AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_token();
DROP TRIGGER IF EXISTS trigger_pgnotify_token_change ON token;
CREATE TRIGGER trigger_pgnotify_token_change AFTER INSERT OR UPDATE ON jazzhands.token FOR EACH ROW EXECUTE FUNCTION jazzhands.pgnotify_token_change();
DROP TRIGGER IF EXISTS trig_userlog_token_collection ON token_collection;
CREATE TRIGGER trig_userlog_token_collection BEFORE INSERT OR UPDATE ON jazzhands.token_collection FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token_collection ON token_collection;
CREATE TRIGGER trigger_audit_token_collection AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token_collection FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_token_collection();
DROP TRIGGER IF EXISTS trig_userlog_token_collection_hier ON token_collection_hier;
CREATE TRIGGER trig_userlog_token_collection_hier BEFORE INSERT OR UPDATE ON jazzhands.token_collection_hier FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token_collection_hier ON token_collection_hier;
CREATE TRIGGER trigger_audit_token_collection_hier AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_token_collection_hier();
DROP TRIGGER IF EXISTS trigger_check_token_collection_hier_loop ON token_collection_hier;
CREATE TRIGGER trigger_check_token_collection_hier_loop AFTER INSERT OR UPDATE ON jazzhands.token_collection_hier FOR EACH ROW EXECUTE FUNCTION jazzhands.check_token_colllection_hier_loop();
DROP TRIGGER IF EXISTS trigger_token_collection_hier_enforce ON token_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_token_collection_hier_enforce AFTER INSERT OR UPDATE ON jazzhands.token_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.token_collection_hier_enforce();
DROP TRIGGER IF EXISTS trig_userlog_token_collection_token ON token_collection_token;
CREATE TRIGGER trig_userlog_token_collection_token BEFORE INSERT OR UPDATE ON jazzhands.token_collection_token FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_token_collection_token ON token_collection_token;
CREATE TRIGGER trigger_audit_token_collection_token AFTER INSERT OR DELETE OR UPDATE ON jazzhands.token_collection_token FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_token_collection_token();
DROP TRIGGER IF EXISTS trigger_token_collection_member_enforce ON token_collection_token;
CREATE CONSTRAINT TRIGGER trigger_token_collection_member_enforce AFTER INSERT OR UPDATE ON jazzhands.token_collection_token DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.token_collection_member_enforce();
DROP TRIGGER IF EXISTS trig_userlog_unix_group ON unix_group;
CREATE TRIGGER trig_userlog_unix_group BEFORE INSERT OR UPDATE ON jazzhands.unix_group FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_unix_group ON unix_group;
CREATE TRIGGER trigger_audit_unix_group AFTER INSERT OR DELETE OR UPDATE ON jazzhands.unix_group FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_unix_group();
DROP TRIGGER IF EXISTS trig_userlog_val_account_collection_relation ON val_account_collection_relation;
CREATE TRIGGER trig_userlog_val_account_collection_relation BEFORE INSERT OR UPDATE ON jazzhands.val_account_collection_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_acct_coll_preserve_direct ON val_account_collection_relation;
CREATE CONSTRAINT TRIGGER trigger_acct_coll_preserve_direct AFTER DELETE OR UPDATE ON jazzhands.val_account_collection_relation DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.acct_coll_preserve_direct();
DROP TRIGGER IF EXISTS trigger_audit_val_account_collection_relation ON val_account_collection_relation;
CREATE TRIGGER trigger_audit_val_account_collection_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_collection_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_account_collection_relation();
DROP TRIGGER IF EXISTS trig_account_collection_type_realm ON val_account_collection_type;
CREATE TRIGGER trig_account_collection_type_realm AFTER UPDATE OF account_realm_id ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.account_collection_type_realm();
DROP TRIGGER IF EXISTS trig_userlog_val_account_collection_type ON val_account_collection_type;
CREATE TRIGGER trig_userlog_val_account_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_acct_coll_insert_direct ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_insert_direct AFTER INSERT ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.acct_coll_insert_direct();
DROP TRIGGER IF EXISTS trigger_acct_coll_remove_direct ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_remove_direct BEFORE DELETE ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.acct_coll_remove_direct();
DROP TRIGGER IF EXISTS trigger_acct_coll_update_direct_before ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_update_direct_before AFTER UPDATE OF account_collection_type ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.acct_coll_update_direct_before();
DROP TRIGGER IF EXISTS trigger_audit_val_account_collection_type ON val_account_collection_type;
CREATE TRIGGER trigger_audit_val_account_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_account_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_account_role ON val_account_role;
CREATE TRIGGER trig_userlog_val_account_role BEFORE INSERT OR UPDATE ON jazzhands.val_account_role FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_account_role ON val_account_role;
CREATE TRIGGER trigger_audit_val_account_role AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_role FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_account_role();
DROP TRIGGER IF EXISTS trig_userlog_val_account_type ON val_account_type;
CREATE TRIGGER trig_userlog_val_account_type BEFORE INSERT OR UPDATE ON jazzhands.val_account_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_account_type ON val_account_type;
CREATE TRIGGER trigger_audit_val_account_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_account_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_account_type();
DROP TRIGGER IF EXISTS trig_userlog_val_appaal_group_name ON val_appaal_group_name;
CREATE TRIGGER trig_userlog_val_appaal_group_name BEFORE INSERT OR UPDATE ON jazzhands.val_appaal_group_name FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_appaal_group_name ON val_appaal_group_name;
CREATE TRIGGER trigger_audit_val_appaal_group_name AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_appaal_group_name FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_appaal_group_name();
DROP TRIGGER IF EXISTS trig_userlog_val_application_key ON val_application_key;
CREATE TRIGGER trig_userlog_val_application_key BEFORE INSERT OR UPDATE ON jazzhands.val_application_key FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_application_key ON val_application_key;
CREATE TRIGGER trigger_audit_val_application_key AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_application_key FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_application_key();
DROP TRIGGER IF EXISTS trig_userlog_val_application_key_values ON val_application_key_values;
CREATE TRIGGER trig_userlog_val_application_key_values BEFORE INSERT OR UPDATE ON jazzhands.val_application_key_values FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_application_key_values ON val_application_key_values;
CREATE TRIGGER trigger_audit_val_application_key_values AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_application_key_values FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_application_key_values();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_chain_response_period ON val_approval_chain_response_period;
CREATE TRIGGER trig_userlog_val_approval_chain_response_period BEFORE INSERT OR UPDATE ON jazzhands.val_approval_chain_response_period FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_chain_response_period ON val_approval_chain_response_period;
CREATE TRIGGER trigger_audit_val_approval_chain_response_period AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_chain_response_period FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_approval_chain_response_period();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_expiration_action ON val_approval_expiration_action;
CREATE TRIGGER trig_userlog_val_approval_expiration_action BEFORE INSERT OR UPDATE ON jazzhands.val_approval_expiration_action FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_expiration_action ON val_approval_expiration_action;
CREATE TRIGGER trigger_audit_val_approval_expiration_action AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_expiration_action FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_approval_expiration_action();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_notifty_type ON val_approval_notifty_type;
CREATE TRIGGER trig_userlog_val_approval_notifty_type BEFORE INSERT OR UPDATE ON jazzhands.val_approval_notifty_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_notifty_type ON val_approval_notifty_type;
CREATE TRIGGER trigger_audit_val_approval_notifty_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_notifty_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_approval_notifty_type();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_process_type ON val_approval_process_type;
CREATE TRIGGER trig_userlog_val_approval_process_type BEFORE INSERT OR UPDATE ON jazzhands.val_approval_process_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_process_type ON val_approval_process_type;
CREATE TRIGGER trigger_audit_val_approval_process_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_process_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_approval_process_type();
DROP TRIGGER IF EXISTS trig_userlog_val_approval_type ON val_approval_type;
CREATE TRIGGER trig_userlog_val_approval_type BEFORE INSERT OR UPDATE ON jazzhands.val_approval_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_approval_type ON val_approval_type;
CREATE TRIGGER trigger_audit_val_approval_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_approval_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_approval_type();
DROP TRIGGER IF EXISTS trig_userlog_val_attestation_frequency ON val_attestation_frequency;
CREATE TRIGGER trig_userlog_val_attestation_frequency BEFORE INSERT OR UPDATE ON jazzhands.val_attestation_frequency FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_attestation_frequency ON val_attestation_frequency;
CREATE TRIGGER trigger_audit_val_attestation_frequency AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_attestation_frequency FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_attestation_frequency();
DROP TRIGGER IF EXISTS trig_userlog_val_authentication_question ON val_authentication_question;
CREATE TRIGGER trig_userlog_val_authentication_question BEFORE INSERT OR UPDATE ON jazzhands.val_authentication_question FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_authentication_question ON val_authentication_question;
CREATE TRIGGER trigger_audit_val_authentication_question AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_authentication_question FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_authentication_question();
DROP TRIGGER IF EXISTS trig_userlog_val_authentication_resource ON val_authentication_resource;
CREATE TRIGGER trig_userlog_val_authentication_resource BEFORE INSERT OR UPDATE ON jazzhands.val_authentication_resource FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_authentication_resource ON val_authentication_resource;
CREATE TRIGGER trigger_audit_val_authentication_resource AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_authentication_resource FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_authentication_resource();
DROP TRIGGER IF EXISTS trig_userlog_val_badge_status ON val_badge_status;
CREATE TRIGGER trig_userlog_val_badge_status BEFORE INSERT OR UPDATE ON jazzhands.val_badge_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_badge_status ON val_badge_status;
CREATE TRIGGER trigger_audit_val_badge_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_badge_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_badge_status();
DROP TRIGGER IF EXISTS trig_userlog_val_block_storage_device_encryption_system ON val_block_storage_device_encryption_system;
CREATE TRIGGER trig_userlog_val_block_storage_device_encryption_system BEFORE INSERT OR UPDATE ON jazzhands.val_block_storage_device_encryption_system FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_block_storage_device_encryption_system ON val_block_storage_device_encryption_system;
CREATE TRIGGER trigger_audit_val_block_storage_device_encryption_system AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_block_storage_device_encryption_system FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_block_storage_device_encryption_system();
DROP TRIGGER IF EXISTS trig_userlog_val_block_storage_device_type ON val_block_storage_device_type;
CREATE TRIGGER trig_userlog_val_block_storage_device_type BEFORE INSERT OR UPDATE ON jazzhands.val_block_storage_device_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_block_storage_device_type ON val_block_storage_device_type;
CREATE TRIGGER trigger_audit_val_block_storage_device_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_block_storage_device_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_block_storage_device_type();
DROP TRIGGER IF EXISTS trigger_val_block_storage_device_type_checks ON val_block_storage_device_type;
CREATE CONSTRAINT TRIGGER trigger_val_block_storage_device_type_checks AFTER UPDATE ON jazzhands.val_block_storage_device_type DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.val_block_storage_device_type_checks();
DROP TRIGGER IF EXISTS trig_userlog_val_cable_type ON val_cable_type;
CREATE TRIGGER trig_userlog_val_cable_type BEFORE INSERT OR UPDATE ON jazzhands.val_cable_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_cable_type ON val_cable_type;
CREATE TRIGGER trigger_audit_val_cable_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_cable_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_cable_type();
DROP TRIGGER IF EXISTS trig_userlog_val_checksum_algorithm ON val_checksum_algorithm;
CREATE TRIGGER trig_userlog_val_checksum_algorithm BEFORE INSERT OR UPDATE ON jazzhands.val_checksum_algorithm FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_checksum_algorithm ON val_checksum_algorithm;
CREATE TRIGGER trigger_audit_val_checksum_algorithm AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_checksum_algorithm FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_checksum_algorithm();
DROP TRIGGER IF EXISTS trig_userlog_val_cipher ON val_cipher;
CREATE TRIGGER trig_userlog_val_cipher BEFORE INSERT OR UPDATE ON jazzhands.val_cipher FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_cipher ON val_cipher;
CREATE TRIGGER trigger_audit_val_cipher AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_cipher FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_cipher();
DROP TRIGGER IF EXISTS trig_userlog_val_cipher_chain_mode ON val_cipher_chain_mode;
CREATE TRIGGER trig_userlog_val_cipher_chain_mode BEFORE INSERT OR UPDATE ON jazzhands.val_cipher_chain_mode FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_cipher_chain_mode ON val_cipher_chain_mode;
CREATE TRIGGER trigger_audit_val_cipher_chain_mode AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_cipher_chain_mode FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_cipher_chain_mode();
DROP TRIGGER IF EXISTS trig_userlog_val_cipher_padding ON val_cipher_padding;
CREATE TRIGGER trig_userlog_val_cipher_padding BEFORE INSERT OR UPDATE ON jazzhands.val_cipher_padding FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_cipher_padding ON val_cipher_padding;
CREATE TRIGGER trigger_audit_val_cipher_padding AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_cipher_padding FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_cipher_padding();
DROP TRIGGER IF EXISTS trig_userlog_val_cipher_permitted_cipher_chain_mode ON val_cipher_permitted_cipher_chain_mode;
CREATE TRIGGER trig_userlog_val_cipher_permitted_cipher_chain_mode BEFORE INSERT OR UPDATE ON jazzhands.val_cipher_permitted_cipher_chain_mode FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_cipher_permitted_cipher_chain_mode ON val_cipher_permitted_cipher_chain_mode;
CREATE TRIGGER trigger_audit_val_cipher_permitted_cipher_chain_mode AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_cipher_permitted_cipher_chain_mode FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_cipher_permitted_cipher_chain_mode();
DROP TRIGGER IF EXISTS trig_userlog_val_cipher_permitted_cipher_padding ON val_cipher_permitted_cipher_padding;
CREATE TRIGGER trig_userlog_val_cipher_permitted_cipher_padding BEFORE INSERT OR UPDATE ON jazzhands.val_cipher_permitted_cipher_padding FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_cipher_permitted_cipher_padding ON val_cipher_permitted_cipher_padding;
CREATE TRIGGER trigger_audit_val_cipher_permitted_cipher_padding AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_cipher_permitted_cipher_padding FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_cipher_permitted_cipher_padding();
DROP TRIGGER IF EXISTS trig_userlog_val_cipher_permitted_key_size ON val_cipher_permitted_key_size;
CREATE TRIGGER trig_userlog_val_cipher_permitted_key_size BEFORE INSERT OR UPDATE ON jazzhands.val_cipher_permitted_key_size FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_cipher_permitted_key_size ON val_cipher_permitted_key_size;
CREATE TRIGGER trigger_audit_val_cipher_permitted_key_size AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_cipher_permitted_key_size FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_cipher_permitted_key_size();
DROP TRIGGER IF EXISTS trig_userlog_val_company_collection_type ON val_company_collection_type;
CREATE TRIGGER trig_userlog_val_company_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_company_collection_type ON val_company_collection_type;
CREATE TRIGGER trigger_audit_val_company_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_company_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_type_bytype_del ON val_company_collection_type;
CREATE TRIGGER trigger_manip_company_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_company_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_company_collection_type_bytype_insup ON val_company_collection_type;
CREATE TRIGGER trigger_manip_company_collection_type_bytype_insup AFTER INSERT OR UPDATE OF company_collection_type ON jazzhands.val_company_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_company_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_company_type ON val_company_type;
CREATE TRIGGER trig_userlog_val_company_type BEFORE INSERT OR UPDATE ON jazzhands.val_company_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_company_type ON val_company_type;
CREATE TRIGGER trigger_audit_val_company_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_company_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_company_type();
DROP TRIGGER IF EXISTS trig_userlog_val_company_type_purpose ON val_company_type_purpose;
CREATE TRIGGER trig_userlog_val_company_type_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_company_type_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_company_type_purpose ON val_company_type_purpose;
CREATE TRIGGER trigger_audit_val_company_type_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_company_type_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_company_type_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_component_function ON val_component_function;
CREATE TRIGGER trig_userlog_val_component_function BEFORE INSERT OR UPDATE ON jazzhands.val_component_function FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_function ON val_component_function;
CREATE TRIGGER trigger_audit_val_component_function AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_function FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_component_function();
DROP TRIGGER IF EXISTS trig_userlog_val_component_management_controller_type ON val_component_management_controller_type;
CREATE TRIGGER trig_userlog_val_component_management_controller_type BEFORE INSERT OR UPDATE ON jazzhands.val_component_management_controller_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_management_controller_type ON val_component_management_controller_type;
CREATE TRIGGER trigger_audit_val_component_management_controller_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_management_controller_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_component_management_controller_type();
DROP TRIGGER IF EXISTS trig_userlog_val_component_property ON val_component_property;
CREATE TRIGGER trig_userlog_val_component_property BEFORE INSERT OR UPDATE ON jazzhands.val_component_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_property ON val_component_property;
CREATE TRIGGER trigger_audit_val_component_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_component_property();
DROP TRIGGER IF EXISTS trig_userlog_val_component_property_type ON val_component_property_type;
CREATE TRIGGER trig_userlog_val_component_property_type BEFORE INSERT OR UPDATE ON jazzhands.val_component_property_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_property_type ON val_component_property_type;
CREATE TRIGGER trigger_audit_val_component_property_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_property_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_component_property_type();
DROP TRIGGER IF EXISTS trig_userlog_val_component_property_value ON val_component_property_value;
CREATE TRIGGER trig_userlog_val_component_property_value BEFORE INSERT OR UPDATE ON jazzhands.val_component_property_value FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_component_property_value ON val_component_property_value;
CREATE TRIGGER trigger_audit_val_component_property_value AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_component_property_value FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_component_property_value();
DROP TRIGGER IF EXISTS trig_userlog_val_contract_type ON val_contract_type;
CREATE TRIGGER trig_userlog_val_contract_type BEFORE INSERT OR UPDATE ON jazzhands.val_contract_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_contract_type ON val_contract_type;
CREATE TRIGGER trigger_audit_val_contract_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_contract_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_contract_type();
DROP TRIGGER IF EXISTS trig_userlog_val_country_code ON val_country_code;
CREATE TRIGGER trig_userlog_val_country_code BEFORE INSERT OR UPDATE ON jazzhands.val_country_code FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_country_code ON val_country_code;
CREATE TRIGGER trigger_audit_val_country_code AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_country_code FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_country_code();
DROP TRIGGER IF EXISTS trig_userlog_val_cryptographic_hash_algorithm ON val_cryptographic_hash_algorithm;
CREATE TRIGGER trig_userlog_val_cryptographic_hash_algorithm BEFORE INSERT OR UPDATE ON jazzhands.val_cryptographic_hash_algorithm FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_cryptographic_hash_algorithm ON val_cryptographic_hash_algorithm;
CREATE TRIGGER trigger_audit_val_cryptographic_hash_algorithm AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_cryptographic_hash_algorithm FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_cryptographic_hash_algorithm();
DROP TRIGGER IF EXISTS trig_userlog_val_device_collection_type ON val_device_collection_type;
CREATE TRIGGER trig_userlog_val_device_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_device_collection_type ON val_device_collection_type;
CREATE TRIGGER trigger_audit_val_device_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_device_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_type_bytype_del ON val_device_collection_type;
CREATE TRIGGER trigger_manip_device_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_device_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_device_collection_type_bytype_insup ON val_device_collection_type;
CREATE TRIGGER trigger_manip_device_collection_type_bytype_insup AFTER INSERT OR UPDATE OF device_collection_type ON jazzhands.val_device_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_device_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_device_status ON val_device_status;
CREATE TRIGGER trig_userlog_val_device_status BEFORE INSERT OR UPDATE ON jazzhands.val_device_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_device_status ON val_device_status;
CREATE TRIGGER trigger_audit_val_device_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_device_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_device_status();
DROP TRIGGER IF EXISTS trig_userlog_val_diet ON val_diet;
CREATE TRIGGER trig_userlog_val_diet BEFORE INSERT OR UPDATE ON jazzhands.val_diet FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_diet ON val_diet;
CREATE TRIGGER trigger_audit_val_diet AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_diet FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_diet();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_class ON val_dns_class;
CREATE TRIGGER trig_userlog_val_dns_class BEFORE INSERT OR UPDATE ON jazzhands.val_dns_class FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_class ON val_dns_class;
CREATE TRIGGER trigger_audit_val_dns_class AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_class FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_class();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_domain_collection_type ON val_dns_domain_collection_type;
CREATE TRIGGER trig_userlog_val_dns_domain_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_domain_collection_type ON val_dns_domain_collection_type;
CREATE TRIGGER trigger_audit_val_dns_domain_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_domain_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_type_bytype_del ON val_dns_domain_collection_type;
CREATE TRIGGER trigger_manip_dns_domain_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_dns_domain_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_type_bytype_insup ON val_dns_domain_collection_type;
CREATE TRIGGER trigger_manip_dns_domain_collection_type_bytype_insup AFTER INSERT OR UPDATE OF dns_domain_collection_type ON jazzhands.val_dns_domain_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_dns_domain_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_domain_type ON val_dns_domain_type;
CREATE TRIGGER trig_userlog_val_dns_domain_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_domain_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_domain_type ON val_dns_domain_type;
CREATE TRIGGER trigger_audit_val_dns_domain_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_domain_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_domain_type();
DROP TRIGGER IF EXISTS trigger_dns_domain_type_should_generate ON val_dns_domain_type;
CREATE TRIGGER trigger_dns_domain_type_should_generate AFTER UPDATE OF can_generate ON jazzhands.val_dns_domain_type FOR EACH ROW EXECUTE FUNCTION jazzhands.dns_domain_type_should_generate();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_record_relation_type ON val_dns_record_relation_type;
CREATE TRIGGER trig_userlog_val_dns_record_relation_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_record_relation_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_record_relation_type ON val_dns_record_relation_type;
CREATE TRIGGER trigger_audit_val_dns_record_relation_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_record_relation_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_record_relation_type();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_srv_service ON val_dns_srv_service;
CREATE TRIGGER trig_userlog_val_dns_srv_service BEFORE INSERT OR UPDATE ON jazzhands.val_dns_srv_service FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_srv_service ON val_dns_srv_service;
CREATE TRIGGER trigger_audit_val_dns_srv_service AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_srv_service FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_srv_service();
DROP TRIGGER IF EXISTS trig_userlog_val_dns_type ON val_dns_type;
CREATE TRIGGER trig_userlog_val_dns_type BEFORE INSERT OR UPDATE ON jazzhands.val_dns_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_dns_type ON val_dns_type;
CREATE TRIGGER trigger_audit_val_dns_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_dns_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_dns_type();
DROP TRIGGER IF EXISTS trig_userlog_val_encapsulation_mode ON val_encapsulation_mode;
CREATE TRIGGER trig_userlog_val_encapsulation_mode BEFORE INSERT OR UPDATE ON jazzhands.val_encapsulation_mode FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_encapsulation_mode ON val_encapsulation_mode;
CREATE TRIGGER trigger_audit_val_encapsulation_mode AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_encapsulation_mode FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_encapsulation_mode();
DROP TRIGGER IF EXISTS trig_userlog_val_encapsulation_type ON val_encapsulation_type;
CREATE TRIGGER trig_userlog_val_encapsulation_type BEFORE INSERT OR UPDATE ON jazzhands.val_encapsulation_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_encapsulation_type ON val_encapsulation_type;
CREATE TRIGGER trigger_audit_val_encapsulation_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_encapsulation_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_encapsulation_type();
DROP TRIGGER IF EXISTS trig_userlog_val_encryption_key_purpose ON val_encryption_key_purpose;
CREATE TRIGGER trig_userlog_val_encryption_key_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_encryption_key_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_encryption_key_purpose ON val_encryption_key_purpose;
CREATE TRIGGER trigger_audit_val_encryption_key_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_encryption_key_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_encryption_key_purpose();
DROP TRIGGER IF EXISTS trigger_val_encryption_key_purpose_validation ON val_encryption_key_purpose;
CREATE CONSTRAINT TRIGGER trigger_val_encryption_key_purpose_validation AFTER INSERT OR UPDATE OF permit_encryption_key_db_value ON jazzhands.val_encryption_key_purpose DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.val_encryption_key_purpose_validation();
DROP TRIGGER IF EXISTS trig_userlog_val_encryption_method ON val_encryption_method;
CREATE TRIGGER trig_userlog_val_encryption_method BEFORE INSERT OR UPDATE ON jazzhands.val_encryption_method FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_encryption_method ON val_encryption_method;
CREATE TRIGGER trigger_audit_val_encryption_method AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_encryption_method FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_encryption_method();
DROP TRIGGER IF EXISTS trig_userlog_val_filesystem_type ON val_filesystem_type;
CREATE TRIGGER trig_userlog_val_filesystem_type BEFORE INSERT OR UPDATE ON jazzhands.val_filesystem_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_filesystem_type ON val_filesystem_type;
CREATE TRIGGER trigger_audit_val_filesystem_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_filesystem_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_filesystem_type();
DROP TRIGGER IF EXISTS trigger_validate_filesystem_type ON val_filesystem_type;
CREATE CONSTRAINT TRIGGER trigger_validate_filesystem_type AFTER INSERT OR UPDATE OF filesystem_type, permit_mountpoint, permit_filesystem_label, permit_filesystem_serial ON jazzhands.val_filesystem_type NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_filesystem_type();
DROP TRIGGER IF EXISTS trig_userlog_val_gender ON val_gender;
CREATE TRIGGER trig_userlog_val_gender BEFORE INSERT OR UPDATE ON jazzhands.val_gender FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_gender ON val_gender;
CREATE TRIGGER trigger_audit_val_gender AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_gender FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_gender();
DROP TRIGGER IF EXISTS trig_userlog_val_image_type ON val_image_type;
CREATE TRIGGER trig_userlog_val_image_type BEFORE INSERT OR UPDATE ON jazzhands.val_image_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_image_type ON val_image_type;
CREATE TRIGGER trigger_audit_val_image_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_image_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_image_type();
DROP TRIGGER IF EXISTS trig_userlog_val_ip_namespace ON val_ip_namespace;
CREATE TRIGGER trig_userlog_val_ip_namespace BEFORE INSERT OR UPDATE ON jazzhands.val_ip_namespace FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_ip_namespace ON val_ip_namespace;
CREATE TRIGGER trigger_audit_val_ip_namespace AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_ip_namespace FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_ip_namespace();
DROP TRIGGER IF EXISTS trig_userlog_val_iso_currency_code ON val_iso_currency_code;
CREATE TRIGGER trig_userlog_val_iso_currency_code BEFORE INSERT OR UPDATE ON jazzhands.val_iso_currency_code FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_iso_currency_code ON val_iso_currency_code;
CREATE TRIGGER trigger_audit_val_iso_currency_code AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_iso_currency_code FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_iso_currency_code();
DROP TRIGGER IF EXISTS trig_userlog_val_key_usage_reason_for_assignment ON val_key_usage_reason_for_assignment;
CREATE TRIGGER trig_userlog_val_key_usage_reason_for_assignment BEFORE INSERT OR UPDATE ON jazzhands.val_key_usage_reason_for_assignment FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_key_usage_reason_for_assignment ON val_key_usage_reason_for_assignment;
CREATE TRIGGER trigger_audit_val_key_usage_reason_for_assignment AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_key_usage_reason_for_assignment FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_key_usage_reason_for_assignment();
DROP TRIGGER IF EXISTS trig_userlog_val_layer2_network_collection_type ON val_layer2_network_collection_type;
CREATE TRIGGER trig_userlog_val_layer2_network_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer2_network_collection_type ON val_layer2_network_collection_type;
CREATE TRIGGER trigger_audit_val_layer2_network_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_layer2_network_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_type_bytype_del ON val_layer2_network_collection_type;
CREATE TRIGGER trigger_manip_layer2_network_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer2_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_type_bytype_insup ON val_layer2_network_collection_type;
CREATE TRIGGER trigger_manip_layer2_network_collection_type_bytype_insup AFTER INSERT OR UPDATE OF layer2_network_collection_type ON jazzhands.val_layer2_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer2_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_acl_group_type ON val_layer3_acl_group_type;
CREATE TRIGGER trig_userlog_val_layer3_acl_group_type BEFORE INSERT OR UPDATE ON jazzhands.val_layer3_acl_group_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_acl_group_type ON val_layer3_acl_group_type;
CREATE TRIGGER trigger_audit_val_layer3_acl_group_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer3_acl_group_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_layer3_acl_group_type();
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_interface_purpose ON val_layer3_interface_purpose;
CREATE TRIGGER trig_userlog_val_layer3_interface_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_layer3_interface_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_interface_purpose ON val_layer3_interface_purpose;
CREATE TRIGGER trigger_audit_val_layer3_interface_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer3_interface_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_layer3_interface_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_interface_type ON val_layer3_interface_type;
CREATE TRIGGER trig_userlog_val_layer3_interface_type BEFORE INSERT OR UPDATE ON jazzhands.val_layer3_interface_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_interface_type ON val_layer3_interface_type;
CREATE TRIGGER trigger_audit_val_layer3_interface_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer3_interface_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_layer3_interface_type();
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_network_collection_type ON val_layer3_network_collection_type;
CREATE TRIGGER trig_userlog_val_layer3_network_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_network_collection_type ON val_layer3_network_collection_type;
CREATE TRIGGER trigger_audit_val_layer3_network_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_layer3_network_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_type_bytype_del ON val_layer3_network_collection_type;
CREATE TRIGGER trigger_manip_layer3_network_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer3_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_type_bytype_insup ON val_layer3_network_collection_type;
CREATE TRIGGER trigger_manip_layer3_network_collection_type_bytype_insup AFTER INSERT OR UPDATE OF layer3_network_collection_type ON jazzhands.val_layer3_network_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_layer3_network_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_port_type ON val_logical_port_type;
CREATE TRIGGER trig_userlog_val_logical_port_type BEFORE INSERT OR UPDATE ON jazzhands.val_logical_port_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_port_type ON val_logical_port_type;
CREATE TRIGGER trigger_audit_val_logical_port_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_port_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_logical_port_type();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_volume_property ON val_logical_volume_property;
CREATE TRIGGER trig_userlog_val_logical_volume_property BEFORE INSERT OR UPDATE ON jazzhands.val_logical_volume_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_volume_property ON val_logical_volume_property;
CREATE TRIGGER trigger_audit_val_logical_volume_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_volume_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_logical_volume_property();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_volume_purpose ON val_logical_volume_purpose;
CREATE TRIGGER trig_userlog_val_logical_volume_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_logical_volume_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_volume_purpose ON val_logical_volume_purpose;
CREATE TRIGGER trigger_audit_val_logical_volume_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_volume_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_logical_volume_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_logical_volume_type ON val_logical_volume_type;
CREATE TRIGGER trig_userlog_val_logical_volume_type BEFORE INSERT OR UPDATE ON jazzhands.val_logical_volume_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_logical_volume_type ON val_logical_volume_type;
CREATE TRIGGER trigger_audit_val_logical_volume_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_logical_volume_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_logical_volume_type();
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_collection_type ON val_netblock_collection_type;
CREATE TRIGGER trig_userlog_val_netblock_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_collection_type ON val_netblock_collection_type;
CREATE TRIGGER trigger_audit_val_netblock_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_netblock_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_type_bytype_del ON val_netblock_collection_type;
CREATE TRIGGER trigger_manip_netblock_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_netblock_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_type_bytype_insup ON val_netblock_collection_type;
CREATE TRIGGER trigger_manip_netblock_collection_type_bytype_insup AFTER INSERT OR UPDATE OF netblock_collection_type ON jazzhands.val_netblock_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_netblock_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_status ON val_netblock_status;
CREATE TRIGGER trig_userlog_val_netblock_status BEFORE INSERT OR UPDATE ON jazzhands.val_netblock_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_status ON val_netblock_status;
CREATE TRIGGER trigger_audit_val_netblock_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_netblock_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_netblock_status();
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_type ON val_netblock_type;
CREATE TRIGGER trig_userlog_val_netblock_type BEFORE INSERT OR UPDATE ON jazzhands.val_netblock_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_type ON val_netblock_type;
CREATE TRIGGER trigger_audit_val_netblock_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_netblock_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_netblock_type();
DROP TRIGGER IF EXISTS trig_userlog_val_network_range_type ON val_network_range_type;
CREATE TRIGGER trig_userlog_val_network_range_type BEFORE INSERT OR UPDATE ON jazzhands.val_network_range_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_network_range_type ON val_network_range_type;
CREATE TRIGGER trigger_audit_val_network_range_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_network_range_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_network_range_type();
DROP TRIGGER IF EXISTS trigger_validate_net_range_toggle_nonoverlap ON val_network_range_type;
CREATE CONSTRAINT TRIGGER trigger_validate_net_range_toggle_nonoverlap AFTER UPDATE OF can_overlap, require_cidr_boundary ON jazzhands.val_network_range_type DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_net_range_toggle_nonoverlap();
DROP TRIGGER IF EXISTS trigger_validate_val_network_range_type ON val_network_range_type;
CREATE CONSTRAINT TRIGGER trigger_validate_val_network_range_type AFTER UPDATE OF dns_domain_required, netblock_type ON jazzhands.val_network_range_type DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_val_network_range_type();
DROP TRIGGER IF EXISTS trig_userlog_val_network_service_type ON val_network_service_type;
CREATE TRIGGER trig_userlog_val_network_service_type BEFORE INSERT OR UPDATE ON jazzhands.val_network_service_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_network_service_type ON val_network_service_type;
CREATE TRIGGER trigger_audit_val_network_service_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_network_service_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_network_service_type();
DROP TRIGGER IF EXISTS trig_userlog_val_operating_system_family ON val_operating_system_family;
CREATE TRIGGER trig_userlog_val_operating_system_family BEFORE INSERT OR UPDATE ON jazzhands.val_operating_system_family FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_operating_system_family ON val_operating_system_family;
CREATE TRIGGER trigger_audit_val_operating_system_family AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_operating_system_family FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_operating_system_family();
DROP TRIGGER IF EXISTS trig_userlog_val_operating_system_snapshot_type ON val_operating_system_snapshot_type;
CREATE TRIGGER trig_userlog_val_operating_system_snapshot_type BEFORE INSERT OR UPDATE ON jazzhands.val_operating_system_snapshot_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_operating_system_snapshot_type ON val_operating_system_snapshot_type;
CREATE TRIGGER trigger_audit_val_operating_system_snapshot_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_operating_system_snapshot_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_operating_system_snapshot_type();
DROP TRIGGER IF EXISTS trig_userlog_val_ownership_status ON val_ownership_status;
CREATE TRIGGER trig_userlog_val_ownership_status BEFORE INSERT OR UPDATE ON jazzhands.val_ownership_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_ownership_status ON val_ownership_status;
CREATE TRIGGER trigger_audit_val_ownership_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_ownership_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_ownership_status();
DROP TRIGGER IF EXISTS trig_userlog_val_password_type ON val_password_type;
CREATE TRIGGER trig_userlog_val_password_type BEFORE INSERT OR UPDATE ON jazzhands.val_password_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_password_type ON val_password_type;
CREATE TRIGGER trigger_audit_val_password_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_password_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_password_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_attribute_data_type ON val_person_company_attribute_data_type;
CREATE TRIGGER trig_userlog_val_person_company_attribute_data_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_attribute_data_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_attribute_data_type ON val_person_company_attribute_data_type;
CREATE TRIGGER trigger_audit_val_person_company_attribute_data_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_attribute_data_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_company_attribute_data_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_attribute_name ON val_person_company_attribute_name;
CREATE TRIGGER trig_userlog_val_person_company_attribute_name BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_attribute_name FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_attribute_name ON val_person_company_attribute_name;
CREATE TRIGGER trigger_audit_val_person_company_attribute_name AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_attribute_name FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_company_attribute_name();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_attribute_value ON val_person_company_attribute_value;
CREATE TRIGGER trig_userlog_val_person_company_attribute_value BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_attribute_value ON val_person_company_attribute_value;
CREATE TRIGGER trigger_audit_val_person_company_attribute_value AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_company_attribute_value();
DROP TRIGGER IF EXISTS trigger_person_company_attribute_change_after_row_hooks ON val_person_company_attribute_value;
CREATE TRIGGER trigger_person_company_attribute_change_after_row_hooks AFTER INSERT OR UPDATE ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE FUNCTION jazzhands.person_company_attribute_change_after_row_hooks();
DROP TRIGGER IF EXISTS trigger_validate_pers_comp_attr_value ON val_person_company_attribute_value;
CREATE TRIGGER trigger_validate_pers_comp_attr_value BEFORE DELETE OR UPDATE OF person_company_attribute_name, person_company_attribute_value ON jazzhands.val_person_company_attribute_value FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_pers_comp_attr_value();
DROP TRIGGER IF EXISTS trig_userlog_val_person_company_relation ON val_person_company_relation;
CREATE TRIGGER trig_userlog_val_person_company_relation BEFORE INSERT OR UPDATE ON jazzhands.val_person_company_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_company_relation ON val_person_company_relation;
CREATE TRIGGER trigger_audit_val_person_company_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_company_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_company_relation();
DROP TRIGGER IF EXISTS trig_userlog_val_person_contact_location_type ON val_person_contact_location_type;
CREATE TRIGGER trig_userlog_val_person_contact_location_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_contact_location_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_contact_location_type ON val_person_contact_location_type;
CREATE TRIGGER trigger_audit_val_person_contact_location_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_contact_location_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_contact_location_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_contact_technology ON val_person_contact_technology;
CREATE TRIGGER trig_userlog_val_person_contact_technology BEFORE INSERT OR UPDATE ON jazzhands.val_person_contact_technology FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_contact_technology ON val_person_contact_technology;
CREATE TRIGGER trigger_audit_val_person_contact_technology AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_contact_technology FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_contact_technology();
DROP TRIGGER IF EXISTS trig_userlog_val_person_contact_type ON val_person_contact_type;
CREATE TRIGGER trig_userlog_val_person_contact_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_contact_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_contact_type ON val_person_contact_type;
CREATE TRIGGER trigger_audit_val_person_contact_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_contact_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_contact_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_image_usage ON val_person_image_usage;
CREATE TRIGGER trig_userlog_val_person_image_usage BEFORE INSERT OR UPDATE ON jazzhands.val_person_image_usage FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_image_usage ON val_person_image_usage;
CREATE TRIGGER trigger_audit_val_person_image_usage AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_image_usage FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_image_usage();
DROP TRIGGER IF EXISTS trig_userlog_val_person_location_type ON val_person_location_type;
CREATE TRIGGER trig_userlog_val_person_location_type BEFORE INSERT OR UPDATE ON jazzhands.val_person_location_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_location_type ON val_person_location_type;
CREATE TRIGGER trigger_audit_val_person_location_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_location_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_location_type();
DROP TRIGGER IF EXISTS trig_userlog_val_person_status ON val_person_status;
CREATE TRIGGER trig_userlog_val_person_status BEFORE INSERT OR UPDATE ON jazzhands.val_person_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_person_status ON val_person_status;
CREATE TRIGGER trigger_audit_val_person_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_person_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_person_status();
DROP TRIGGER IF EXISTS trig_userlog_val_physical_address_type ON val_physical_address_type;
CREATE TRIGGER trig_userlog_val_physical_address_type BEFORE INSERT OR UPDATE ON jazzhands.val_physical_address_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_physical_address_type ON val_physical_address_type;
CREATE TRIGGER trigger_audit_val_physical_address_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_physical_address_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_physical_address_type();
DROP TRIGGER IF EXISTS trig_userlog_val_port_range_type ON val_port_range_type;
CREATE TRIGGER trig_userlog_val_port_range_type BEFORE INSERT OR UPDATE ON jazzhands.val_port_range_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_port_range_type ON val_port_range_type;
CREATE TRIGGER trigger_audit_val_port_range_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_port_range_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_port_range_type();
DROP TRIGGER IF EXISTS trigger_val_port_range_sanity_check ON val_port_range_type;
CREATE CONSTRAINT TRIGGER trigger_val_port_range_sanity_check AFTER UPDATE OF range_permitted ON jazzhands.val_port_range_type NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.val_port_range_sanity_check();
DROP TRIGGER IF EXISTS trig_userlog_val_private_key_encryption_type ON val_private_key_encryption_type;
CREATE TRIGGER trig_userlog_val_private_key_encryption_type BEFORE INSERT OR UPDATE ON jazzhands.val_private_key_encryption_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_private_key_encryption_type ON val_private_key_encryption_type;
CREATE TRIGGER trigger_audit_val_private_key_encryption_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_private_key_encryption_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_private_key_encryption_type();
DROP TRIGGER IF EXISTS trig_userlog_val_processor_architecture ON val_processor_architecture;
CREATE TRIGGER trig_userlog_val_processor_architecture BEFORE INSERT OR UPDATE ON jazzhands.val_processor_architecture FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_processor_architecture ON val_processor_architecture;
CREATE TRIGGER trigger_audit_val_processor_architecture AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_processor_architecture FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_processor_architecture();
DROP TRIGGER IF EXISTS trig_userlog_val_production_state ON val_production_state;
CREATE TRIGGER trig_userlog_val_production_state BEFORE INSERT OR UPDATE ON jazzhands.val_production_state FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_production_state ON val_production_state;
CREATE TRIGGER trigger_audit_val_production_state AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_production_state FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_production_state();
DROP TRIGGER IF EXISTS trig_userlog_val_property ON val_property;
CREATE TRIGGER trig_userlog_val_property BEFORE INSERT OR UPDATE ON jazzhands.val_property FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property ON val_property;
CREATE TRIGGER trigger_audit_val_property AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_property();
DROP TRIGGER IF EXISTS trigger_validate_val_property ON val_property;
CREATE TRIGGER trigger_validate_val_property BEFORE INSERT OR UPDATE OF property_data_type, property_value_json_schema, permit_company_id ON jazzhands.val_property FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_val_property();
DROP TRIGGER IF EXISTS trigger_validate_val_property_after ON val_property;
CREATE CONSTRAINT TRIGGER trigger_validate_val_property_after AFTER UPDATE ON jazzhands.val_property DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.validate_val_property_after();
DROP TRIGGER IF EXISTS trig_userlog_val_property_data_type ON val_property_data_type;
CREATE TRIGGER trig_userlog_val_property_data_type BEFORE INSERT OR UPDATE ON jazzhands.val_property_data_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_data_type ON val_property_data_type;
CREATE TRIGGER trigger_audit_val_property_data_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_data_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_property_data_type();
DROP TRIGGER IF EXISTS trig_userlog_val_property_name_collection_type ON val_property_name_collection_type;
CREATE TRIGGER trig_userlog_val_property_name_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_property_name_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_name_collection_type ON val_property_name_collection_type;
CREATE TRIGGER trigger_audit_val_property_name_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_name_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_property_name_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_property_type ON val_property_type;
CREATE TRIGGER trig_userlog_val_property_type BEFORE INSERT OR UPDATE ON jazzhands.val_property_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_type ON val_property_type;
CREATE TRIGGER trigger_audit_val_property_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_property_type();
DROP TRIGGER IF EXISTS trig_userlog_val_property_value ON val_property_value;
CREATE TRIGGER trig_userlog_val_property_value BEFORE INSERT OR UPDATE ON jazzhands.val_property_value FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_property_value ON val_property_value;
CREATE TRIGGER trigger_audit_val_property_value AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_property_value FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_property_value();
DROP TRIGGER IF EXISTS trigger_val_property_value_del_check ON val_property_value;
CREATE CONSTRAINT TRIGGER trigger_val_property_value_del_check AFTER DELETE ON jazzhands.val_property_value DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.val_property_value_del_check();
DROP TRIGGER IF EXISTS trig_userlog_val_rack_type ON val_rack_type;
CREATE TRIGGER trig_userlog_val_rack_type BEFORE INSERT OR UPDATE ON jazzhands.val_rack_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_rack_type ON val_rack_type;
CREATE TRIGGER trigger_audit_val_rack_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_rack_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_rack_type();
DROP TRIGGER IF EXISTS trig_userlog_val_raid_type ON val_raid_type;
CREATE TRIGGER trig_userlog_val_raid_type BEFORE INSERT OR UPDATE ON jazzhands.val_raid_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_raid_type ON val_raid_type;
CREATE TRIGGER trigger_audit_val_raid_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_raid_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_raid_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_affinity ON val_service_affinity;
CREATE TRIGGER trig_userlog_val_service_affinity BEFORE INSERT OR UPDATE ON jazzhands.val_service_affinity FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_affinity ON val_service_affinity;
CREATE TRIGGER trigger_audit_val_service_affinity AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_affinity FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_affinity();
DROP TRIGGER IF EXISTS trig_userlog_val_service_endpoint_provider_collection_type ON val_service_endpoint_provider_collection_type;
CREATE TRIGGER trig_userlog_val_service_endpoint_provider_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_endpoint_provider_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_endpoint_provider_collection_type ON val_service_endpoint_provider_collection_type;
CREATE TRIGGER trigger_audit_val_service_endpoint_provider_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_endpoint_provider_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_endpoint_provider_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_endpoint_provider_type ON val_service_endpoint_provider_type;
CREATE TRIGGER trig_userlog_val_service_endpoint_provider_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_endpoint_provider_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_endpoint_provider_type ON val_service_endpoint_provider_type;
CREATE TRIGGER trigger_audit_val_service_endpoint_provider_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_endpoint_provider_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_endpoint_provider_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_environment_collection_type ON val_service_environment_collection_type;
CREATE TRIGGER trig_userlog_val_service_environment_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_environment_collection_type ON val_service_environment_collection_type;
CREATE TRIGGER trigger_audit_val_service_environment_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_environment_collection_type();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_type_bytype_del ON val_service_environment_collection_type;
CREATE TRIGGER trigger_manip_service_environment_collection_type_bytype_del BEFORE DELETE ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_service_environment_collection_type_bytype();
DROP TRIGGER IF EXISTS trigger_manip_service_environment_collection_type_bytype_insup ON val_service_environment_collection_type;
CREATE TRIGGER trigger_manip_service_environment_collection_type_bytype_insup AFTER INSERT OR UPDATE OF service_environment_collection_type ON jazzhands.val_service_environment_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.manip_service_environment_collection_type_bytype();
DROP TRIGGER IF EXISTS trig_userlog_val_service_environment_type ON val_service_environment_type;
CREATE TRIGGER trig_userlog_val_service_environment_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_environment_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_environment_type ON val_service_environment_type;
CREATE TRIGGER trigger_audit_val_service_environment_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_environment_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_environment_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_feature ON val_service_feature;
CREATE TRIGGER trig_userlog_val_service_feature BEFORE INSERT OR UPDATE ON jazzhands.val_service_feature FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_feature ON val_service_feature;
CREATE TRIGGER trigger_audit_val_service_feature AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_feature FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_feature();
DROP TRIGGER IF EXISTS trig_userlog_val_service_namespace ON val_service_namespace;
CREATE TRIGGER trig_userlog_val_service_namespace BEFORE INSERT OR UPDATE ON jazzhands.val_service_namespace FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_namespace ON val_service_namespace;
CREATE TRIGGER trigger_audit_val_service_namespace AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_namespace FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_namespace();
DROP TRIGGER IF EXISTS trig_userlog_val_service_relationship_type ON val_service_relationship_type;
CREATE TRIGGER trig_userlog_val_service_relationship_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_relationship_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_relationship_type ON val_service_relationship_type;
CREATE TRIGGER trigger_audit_val_service_relationship_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_relationship_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_relationship_type();
DROP TRIGGER IF EXISTS trig_userlog_val_service_source_control_purpose ON val_service_source_control_purpose;
CREATE TRIGGER trig_userlog_val_service_source_control_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_service_source_control_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_source_control_purpose ON val_service_source_control_purpose;
CREATE TRIGGER trigger_audit_val_service_source_control_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_source_control_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_source_control_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_service_type ON val_service_type;
CREATE TRIGGER trig_userlog_val_service_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_type ON val_service_type;
CREATE TRIGGER trigger_audit_val_service_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_type();
DROP TRIGGER IF EXISTS trigger_check_service_type_namespace ON val_service_type;
CREATE CONSTRAINT TRIGGER trigger_check_service_type_namespace AFTER UPDATE OF service_namespace ON jazzhands.val_service_type NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_service_type_namespace();
DROP TRIGGER IF EXISTS trigger_check_service_type_relation_regexp_change ON val_service_type;
CREATE CONSTRAINT TRIGGER trigger_check_service_type_relation_regexp_change AFTER UPDATE OF service_version_restriction_regular_expression ON jazzhands.val_service_type NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.check_service_type_relation_regexp_change();
DROP TRIGGER IF EXISTS trig_userlog_val_service_version_collection_type ON val_service_version_collection_type;
CREATE TRIGGER trig_userlog_val_service_version_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_service_version_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_service_version_collection_type ON val_service_version_collection_type;
CREATE TRIGGER trigger_audit_val_service_version_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_service_version_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_service_version_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_shared_netblock_protocol ON val_shared_netblock_protocol;
CREATE TRIGGER trig_userlog_val_shared_netblock_protocol BEFORE INSERT OR UPDATE ON jazzhands.val_shared_netblock_protocol FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_shared_netblock_protocol ON val_shared_netblock_protocol;
CREATE TRIGGER trigger_audit_val_shared_netblock_protocol AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_shared_netblock_protocol FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_shared_netblock_protocol();
DROP TRIGGER IF EXISTS trig_userlog_val_slot_function ON val_slot_function;
CREATE TRIGGER trig_userlog_val_slot_function BEFORE INSERT OR UPDATE ON jazzhands.val_slot_function FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_slot_function ON val_slot_function;
CREATE TRIGGER trigger_audit_val_slot_function AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_slot_function FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_slot_function();
DROP TRIGGER IF EXISTS trig_userlog_val_slot_physical_interface ON val_slot_physical_interface;
CREATE TRIGGER trig_userlog_val_slot_physical_interface BEFORE INSERT OR UPDATE ON jazzhands.val_slot_physical_interface FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_slot_physical_interface ON val_slot_physical_interface;
CREATE TRIGGER trigger_audit_val_slot_physical_interface AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_slot_physical_interface FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_slot_physical_interface();
DROP TRIGGER IF EXISTS trig_userlog_val_software_artifact_relationship ON val_software_artifact_relationship;
CREATE TRIGGER trig_userlog_val_software_artifact_relationship BEFORE INSERT OR UPDATE ON jazzhands.val_software_artifact_relationship FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_software_artifact_relationship ON val_software_artifact_relationship;
CREATE TRIGGER trigger_audit_val_software_artifact_relationship AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_software_artifact_relationship FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_software_artifact_relationship();
DROP TRIGGER IF EXISTS trig_userlog_val_software_artifact_repository_uri_type ON val_software_artifact_repository_uri_type;
CREATE TRIGGER trig_userlog_val_software_artifact_repository_uri_type BEFORE INSERT OR UPDATE ON jazzhands.val_software_artifact_repository_uri_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_software_artifact_repository_uri_type ON val_software_artifact_repository_uri_type;
CREATE TRIGGER trigger_audit_val_software_artifact_repository_uri_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_software_artifact_repository_uri_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_software_artifact_repository_uri_type();
DROP TRIGGER IF EXISTS trig_userlog_val_software_artifact_type ON val_software_artifact_type;
CREATE TRIGGER trig_userlog_val_software_artifact_type BEFORE INSERT OR UPDATE ON jazzhands.val_software_artifact_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_software_artifact_type ON val_software_artifact_type;
CREATE TRIGGER trigger_audit_val_software_artifact_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_software_artifact_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_software_artifact_type();
DROP TRIGGER IF EXISTS trig_userlog_val_source_repository_method ON val_source_repository_method;
CREATE TRIGGER trig_userlog_val_source_repository_method BEFORE INSERT OR UPDATE ON jazzhands.val_source_repository_method FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_source_repository_method ON val_source_repository_method;
CREATE TRIGGER trigger_audit_val_source_repository_method AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_source_repository_method FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_source_repository_method();
DROP TRIGGER IF EXISTS trig_userlog_val_source_repository_protocol ON val_source_repository_protocol;
CREATE TRIGGER trig_userlog_val_source_repository_protocol BEFORE INSERT OR UPDATE ON jazzhands.val_source_repository_protocol FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_source_repository_protocol ON val_source_repository_protocol;
CREATE TRIGGER trigger_audit_val_source_repository_protocol AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_source_repository_protocol FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_source_repository_protocol();
DROP TRIGGER IF EXISTS trig_userlog_val_source_repository_uri_purpose ON val_source_repository_uri_purpose;
CREATE TRIGGER trig_userlog_val_source_repository_uri_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_source_repository_uri_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_source_repository_uri_purpose ON val_source_repository_uri_purpose;
CREATE TRIGGER trigger_audit_val_source_repository_uri_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_source_repository_uri_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_source_repository_uri_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_ssh_key_type ON val_ssh_key_type;
CREATE TRIGGER trig_userlog_val_ssh_key_type BEFORE INSERT OR UPDATE ON jazzhands.val_ssh_key_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_ssh_key_type ON val_ssh_key_type;
CREATE TRIGGER trigger_audit_val_ssh_key_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_ssh_key_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_ssh_key_type();
DROP TRIGGER IF EXISTS trig_userlog_val_token_collection_type ON val_token_collection_type;
CREATE TRIGGER trig_userlog_val_token_collection_type BEFORE INSERT OR UPDATE ON jazzhands.val_token_collection_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_token_collection_type ON val_token_collection_type;
CREATE TRIGGER trigger_audit_val_token_collection_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_token_collection_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_token_collection_type();
DROP TRIGGER IF EXISTS trig_userlog_val_token_status ON val_token_status;
CREATE TRIGGER trig_userlog_val_token_status BEFORE INSERT OR UPDATE ON jazzhands.val_token_status FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_token_status ON val_token_status;
CREATE TRIGGER trigger_audit_val_token_status AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_token_status FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_token_status();
DROP TRIGGER IF EXISTS trig_userlog_val_token_type ON val_token_type;
CREATE TRIGGER trig_userlog_val_token_type BEFORE INSERT OR UPDATE ON jazzhands.val_token_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_token_type ON val_token_type;
CREATE TRIGGER trigger_audit_val_token_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_token_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_token_type();
DROP TRIGGER IF EXISTS trig_userlog_val_volume_group_purpose ON val_volume_group_purpose;
CREATE TRIGGER trig_userlog_val_volume_group_purpose BEFORE INSERT OR UPDATE ON jazzhands.val_volume_group_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_volume_group_purpose ON val_volume_group_purpose;
CREATE TRIGGER trigger_audit_val_volume_group_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_volume_group_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_volume_group_purpose();
DROP TRIGGER IF EXISTS trig_userlog_val_volume_group_relation ON val_volume_group_relation;
CREATE TRIGGER trig_userlog_val_volume_group_relation BEFORE INSERT OR UPDATE ON jazzhands.val_volume_group_relation FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_volume_group_relation ON val_volume_group_relation;
CREATE TRIGGER trigger_audit_val_volume_group_relation AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_volume_group_relation FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_volume_group_relation();
DROP TRIGGER IF EXISTS trig_userlog_val_volume_group_type ON val_volume_group_type;
CREATE TRIGGER trig_userlog_val_volume_group_type BEFORE INSERT OR UPDATE ON jazzhands.val_volume_group_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_volume_group_type ON val_volume_group_type;
CREATE TRIGGER trigger_audit_val_volume_group_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_volume_group_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_volume_group_type();
DROP TRIGGER IF EXISTS trigger_val_volume_group_type_enforcement ON val_volume_group_type;
CREATE CONSTRAINT TRIGGER trigger_val_volume_group_type_enforcement AFTER UPDATE OF allow_mulitiple_block_storage_devices ON jazzhands.val_volume_group_type DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.val_volume_group_type_enforcement();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_certificate_file_format ON val_x509_certificate_file_format;
CREATE TRIGGER trig_userlog_val_x509_certificate_file_format BEFORE INSERT OR UPDATE ON jazzhands.val_x509_certificate_file_format FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_certificate_file_format ON val_x509_certificate_file_format;
CREATE TRIGGER trigger_audit_val_x509_certificate_file_format AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_certificate_file_format FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_certificate_file_format();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_certificate_type ON val_x509_certificate_type;
CREATE TRIGGER trig_userlog_val_x509_certificate_type BEFORE INSERT OR UPDATE ON jazzhands.val_x509_certificate_type FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_certificate_type ON val_x509_certificate_type;
CREATE TRIGGER trigger_audit_val_x509_certificate_type AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_certificate_type FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_certificate_type();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_fingerprint_hash_algorithm ON val_x509_fingerprint_hash_algorithm;
CREATE TRIGGER trig_userlog_val_x509_fingerprint_hash_algorithm BEFORE INSERT OR UPDATE ON jazzhands.val_x509_fingerprint_hash_algorithm FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_fingerprint_hash_algorithm ON val_x509_fingerprint_hash_algorithm;
CREATE TRIGGER trigger_audit_val_x509_fingerprint_hash_algorithm AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_fingerprint_hash_algorithm FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_fingerprint_hash_algorithm();
DROP TRIGGER IF EXISTS trigger_fingerprint_hash_algorithm ON val_x509_fingerprint_hash_algorithm;
CREATE TRIGGER trigger_fingerprint_hash_algorithm BEFORE INSERT OR UPDATE OF x509_fingerprint_hash_algorighm, cryptographic_hash_algorithm ON jazzhands.val_x509_fingerprint_hash_algorithm FOR EACH ROW EXECUTE FUNCTION jazzhands.check_fingerprint_hash_algorithm();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_key_usage ON val_x509_key_usage;
CREATE TRIGGER trig_userlog_val_x509_key_usage BEFORE INSERT OR UPDATE ON jazzhands.val_x509_key_usage FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_key_usage ON val_x509_key_usage;
CREATE TRIGGER trigger_audit_val_x509_key_usage AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_key_usage FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_key_usage();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_key_usage_category ON val_x509_key_usage_category;
CREATE TRIGGER trig_userlog_val_x509_key_usage_category BEFORE INSERT OR UPDATE ON jazzhands.val_x509_key_usage_category FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_key_usage_category ON val_x509_key_usage_category;
CREATE TRIGGER trigger_audit_val_x509_key_usage_category AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_key_usage_category FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_key_usage_category();
DROP TRIGGER IF EXISTS trig_userlog_val_x509_revocation_reason ON val_x509_revocation_reason;
CREATE TRIGGER trig_userlog_val_x509_revocation_reason BEFORE INSERT OR UPDATE ON jazzhands.val_x509_revocation_reason FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_val_x509_revocation_reason ON val_x509_revocation_reason;
CREATE TRIGGER trigger_audit_val_x509_revocation_reason AFTER INSERT OR DELETE OR UPDATE ON jazzhands.val_x509_revocation_reason FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_val_x509_revocation_reason();
DROP TRIGGER IF EXISTS trig_userlog_virtual_component_logical_volume ON virtual_component_logical_volume;
CREATE TRIGGER trig_userlog_virtual_component_logical_volume BEFORE INSERT OR UPDATE ON jazzhands.virtual_component_logical_volume FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_virtual_component_logical_volume ON virtual_component_logical_volume;
CREATE TRIGGER trigger_audit_virtual_component_logical_volume AFTER INSERT OR DELETE OR UPDATE ON jazzhands.virtual_component_logical_volume FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_virtual_component_logical_volume();
DROP TRIGGER IF EXISTS trigger_virtual_component_logical_volume_legacy_sync_ins_upd ON virtual_component_logical_volume;
CREATE TRIGGER trigger_virtual_component_logical_volume_legacy_sync_ins_upd AFTER INSERT OR UPDATE OF logical_volume_id, component_id ON jazzhands.virtual_component_logical_volume FOR EACH ROW EXECUTE FUNCTION jazzhands.virtual_component_logical_volume_legacy_sync();
DROP TRIGGER IF EXISTS trig_userlog_volume_group ON volume_group;
CREATE TRIGGER trig_userlog_volume_group BEFORE INSERT OR UPDATE ON jazzhands.volume_group FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_volume_group ON volume_group;
CREATE TRIGGER trigger_audit_volume_group AFTER INSERT OR DELETE OR UPDATE ON jazzhands.volume_group FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_volume_group();
DROP TRIGGER IF EXISTS trig_userlog_volume_group_block_storage_device ON volume_group_block_storage_device;
CREATE TRIGGER trig_userlog_volume_group_block_storage_device BEFORE INSERT OR UPDATE ON jazzhands.volume_group_block_storage_device FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_volume_group_block_storage_device ON volume_group_block_storage_device;
CREATE TRIGGER trigger_audit_volume_group_block_storage_device AFTER INSERT OR DELETE OR UPDATE ON jazzhands.volume_group_block_storage_device FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_volume_group_block_storage_device();
DROP TRIGGER IF EXISTS trigger_volume_group_block_storage_device_enforcement ON volume_group_block_storage_device;
CREATE CONSTRAINT TRIGGER trigger_volume_group_block_storage_device_enforcement AFTER INSERT OR UPDATE OF volume_group_id, block_storage_device_id ON jazzhands.volume_group_block_storage_device DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION jazzhands.volume_group_block_storage_device_enforcement();
DROP TRIGGER IF EXISTS trig_userlog_volume_group_purpose ON volume_group_purpose;
CREATE TRIGGER trig_userlog_volume_group_purpose BEFORE INSERT OR UPDATE ON jazzhands.volume_group_purpose FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_volume_group_purpose ON volume_group_purpose;
CREATE TRIGGER trigger_audit_volume_group_purpose AFTER INSERT OR DELETE OR UPDATE ON jazzhands.volume_group_purpose FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_volume_group_purpose();
DROP TRIGGER IF EXISTS trig_userlog_x509_key_usage_attribute ON x509_key_usage_attribute;
CREATE TRIGGER trig_userlog_x509_key_usage_attribute BEFORE INSERT OR UPDATE ON jazzhands.x509_key_usage_attribute FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_key_usage_attribute ON x509_key_usage_attribute;
CREATE TRIGGER trigger_audit_x509_key_usage_attribute AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_key_usage_attribute FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_x509_key_usage_attribute();
DROP TRIGGER IF EXISTS trig_userlog_x509_key_usage_categorization ON x509_key_usage_categorization;
CREATE TRIGGER trig_userlog_x509_key_usage_categorization BEFORE INSERT OR UPDATE ON jazzhands.x509_key_usage_categorization FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_key_usage_categorization ON x509_key_usage_categorization;
CREATE TRIGGER trigger_audit_x509_key_usage_categorization AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_key_usage_categorization FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_x509_key_usage_categorization();
DROP TRIGGER IF EXISTS trig_userlog_x509_key_usage_default ON x509_key_usage_default;
CREATE TRIGGER trig_userlog_x509_key_usage_default BEFORE INSERT OR UPDATE ON jazzhands.x509_key_usage_default FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_key_usage_default ON x509_key_usage_default;
CREATE TRIGGER trigger_audit_x509_key_usage_default AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_key_usage_default FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_x509_key_usage_default();
DROP TRIGGER IF EXISTS trig_userlog_x509_signed_certificate ON x509_signed_certificate;
CREATE TRIGGER trig_userlog_x509_signed_certificate BEFORE INSERT OR UPDATE ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_signed_certificate ON x509_signed_certificate;
CREATE TRIGGER trigger_audit_x509_signed_certificate AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_x509_signed_certificate();
DROP TRIGGER IF EXISTS trigger_x509_signed_delete_dangling_hashes ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_delete_dangling_hashes AFTER DELETE OR UPDATE OF public_key_hash_id ON jazzhands.x509_signed_certificate FOR EACH STATEMENT EXECUTE FUNCTION jazzhands.delete_dangling_public_key_hashes();
DROP TRIGGER IF EXISTS trigger_x509_signed_set_fingerprints ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_set_fingerprints AFTER INSERT OR UPDATE OF public_key ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.set_x509_certificate_fingerprints();
DROP TRIGGER IF EXISTS trigger_x509_signed_set_private_key_id ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_set_private_key_id AFTER INSERT OR UPDATE OF public_key, public_key_hash_id ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.set_x509_certificate_private_key_id();
DROP TRIGGER IF EXISTS trigger_x509_signed_set_ski_and_hashes ON x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_set_ski_and_hashes BEFORE INSERT OR UPDATE OF public_key, public_key_hash_id, subject_key_identifier ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE FUNCTION jazzhands.set_x509_certificate_ski_and_hashes();
DROP TRIGGER IF EXISTS trig_userlog_x509_signed_certificate_fingerprint ON x509_signed_certificate_fingerprint;
CREATE TRIGGER trig_userlog_x509_signed_certificate_fingerprint BEFORE INSERT OR UPDATE ON jazzhands.x509_signed_certificate_fingerprint FOR EACH ROW EXECUTE FUNCTION schema_support.trigger_ins_upd_generic_func();
DROP TRIGGER IF EXISTS trigger_audit_x509_signed_certificate_fingerprint ON x509_signed_certificate_fingerprint;
CREATE TRIGGER trigger_audit_x509_signed_certificate_fingerprint AFTER INSERT OR DELETE OR UPDATE ON jazzhands.x509_signed_certificate_fingerprint FOR EACH ROW EXECUTE FUNCTION jazzhands.perform_audit_x509_signed_certificate_fingerprint();
DROP TRIGGER IF EXISTS trigger_fingerprint_hash_algorithm ON x509_signed_certificate_fingerprint;
CREATE TRIGGER trigger_fingerprint_hash_algorithm BEFORE INSERT OR UPDATE OF x509_fingerprint_hash_algorighm, cryptographic_hash_algorithm ON jazzhands.x509_signed_certificate_fingerprint FOR EACH ROW EXECUTE FUNCTION jazzhands.check_fingerprint_hash_algorithm();

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

DROP TRIGGER IF EXISTS trigger_audit_token_sequence ON token_sequence;

SELECT schema_support.set_schema_version(
        version := '0.97',
        schema := 'jazzhands'
);


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
