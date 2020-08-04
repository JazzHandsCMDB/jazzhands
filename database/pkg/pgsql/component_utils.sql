--
-- Copyright (c) 2015, 2016, 2018, 2019 Matthew Ragan
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
--

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'component_utils';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS component_utils;
                CREATE SCHEMA component_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA component_utils IS 'part of jazzhands';
        END IF;
END;
$$;

CREATE OR REPLACE FUNCTION component_utils.create_component_template_slots(
	component_id	jazzhands.component.component_id%TYPE
) RETURNS SETOF jazzhands.slot
AS $$
DECLARE
	ctid	jazzhands.component_type.component_type_id%TYPE;
	s		jazzhands.slot%ROWTYPE;
	cid 	ALIAS FOR component_id;
BEGIN
	FOR s IN
		INSERT INTO jazzhands.slot (
			component_id,
			slot_name,
			slot_type_id,
			slot_index,
			component_type_slot_template_id,
			physical_label,
			slot_x_offset,
			slot_y_offset,
			slot_z_offset,
			slot_side
		) SELECT
			cid,
			ctst.slot_name_template,
			ctst.slot_type_id,
			ctst.slot_index,
			ctst.component_type_slot_template_id,
			ctst.physical_label,
			ctst.slot_x_offset,
			ctst.slot_y_offset,
			ctst.slot_z_offset,
			ctst.slot_side
		FROM
			component_type_slot_template ctst JOIN
			component c USING (component_type_id) LEFT JOIN
			slot ON (slot.component_id = cid AND
				slot.component_type_slot_template_id =
				ctst.component_type_slot_template_id
			)
		WHERE
			c.component_id = cid AND
			slot.component_type_slot_template_id IS NULL
		ORDER BY ctst.component_type_slot_template_id
		RETURNING *
	LOOP
		RAISE DEBUG 'Creating slot for component % from template %',
			cid, s.component_type_slot_template_id;
		RETURN NEXT s;
	END LOOP;
END;
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_utils.migrate_component_template_slots(
	component_id			jazzhands.component.component_id%TYPE
) RETURNS SETOF jazzhands.slot
AS $$
DECLARE
	cid 	ALIAS FOR component_id;
BEGIN
	-- Ensure all of the new slots have appropriate names

	PERFORM component_utils.set_slot_names(
		slot_id_list := ARRAY(
				SELECT s.slot_id FROM slot s WHERE s.component_id = cid
			)
	);

	-- Move everything from the old slot to the new slot if the slot name
	-- and component functions match up, then delete the old slot

	RETURN QUERY
	WITH old_slot AS (
		SELECT
			s.slot_id,
			s.slot_name,
			s.slot_type_id,
			st.slot_function,
			ctst.component_type_slot_template_id
		FROM
			slot s JOIN 
			slot_type st USING (slot_type_id) JOIN
			component c USING (component_id) LEFT JOIN
			component_type_slot_template ctst USING (component_type_slot_template_id)
		WHERE
			s.component_id = cid AND
			ctst.component_type_id IS DISTINCT FROM c.component_type_id
	), new_slot AS (
		SELECT
			s.slot_id,
			s.slot_name,
			s.slot_type_id,
			st.slot_function
		FROM
			slot s JOIN 
			slot_type st USING (slot_type_id) JOIN
			component c USING (component_id) LEFT JOIN
			component_type_slot_template ctst USING (component_type_slot_template_id)
		WHERE
			s.component_id = cid AND
			ctst.component_type_id IS NOT DISTINCT FROM c.component_type_id
	), slot_map AS (
		SELECT
			o.slot_id AS old_slot_id,
			n.slot_id AS new_slot_id
		FROM
			old_slot o JOIN
			new_slot n ON (
				o.slot_name = n.slot_name AND o.slot_function = n.slot_function)
	), slot_1_upd AS (
		UPDATE
			inter_component_connection ic
		SET
			slot1_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			slot1_id = slot_map.old_slot_id
		RETURNING *
	), slot_2_upd AS (
		UPDATE
			inter_component_connection ic
		SET
			slot2_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			slot2_id = slot_map.old_slot_id
		RETURNING *
	), prop_upd AS (
		UPDATE
			component_property cp
		SET
			slot_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			slot_id = slot_map.old_slot_id
		RETURNING *
	), comp_upd AS (
		UPDATE
			component c
		SET
			parent_slot_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			parent_slot_id = slot_map.old_slot_id
		RETURNING *
	), ni_upd AS (
		UPDATE
			network_interface ni
		SET
			slot_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			physical_port_id = slot_map.old_slot_id OR
			slot_id = slot_map.new_slot_id
		RETURNING *
	), delete_migraged_slots AS (
		DELETE FROM
			slot
		WHERE
			slot_id IN (SELECT old_slot_id FROM slot_map)
		RETURNING *
	), delete_empty_slots AS (
		DELETE FROM
			slot s
		WHERE
			slot_id IN (
				SELECT os.slot_id FROM
					old_slot os LEFT JOIN
					component_property cp ON (os.slot_id = cp.slot_id) LEFT JOIN
					network_interface ni ON (
						ni.slot_id = os.slot_id OR
						ni.physical_port_id = os.slot_id) LEFT JOIN
					inter_component_connection ic ON (
						slot1_id = os.slot_id OR
						slot2_id = os.slot_id) LEFT JOIN
					component c ON (c.parent_slot_id = os.slot_id)
				WHERE
					ic.inter_component_connection_id IS NULL AND
					c.component_id IS NULL AND
					ni.network_interface_id IS NULL AND
					cp.component_property_id IS NULL AND
					os.component_type_slot_template_id IS NOT NULL
			)
	) SELECT s.* FROM slot s JOIN slot_map sm ON s.slot_id = sm.new_slot_id;

	RETURN;
END;
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_utils.set_slot_names(
	slot_id_list	integer[] DEFAULT NULL
) RETURNS VOID
AS $$
DECLARE
	slot_rec	RECORD;
	sn			text;
BEGIN
	-- Get a list of all slots that have replacement values

	FOR slot_rec IN
		SELECT 
			s.slot_id,
			COALESCE(pst.child_slot_name_template, st.slot_name_template)
				AS slot_name_template,
			st.slot_index as slot_index,
			pst.slot_index as parent_slot_index,
			pst.child_slot_offset as child_slot_offset
		FROM
			slot s JOIN
			component_type_slot_template st ON (s.component_type_slot_template_id =
				st.component_type_slot_template_id) JOIN
			component c ON (s.component_id = c.component_id) LEFT JOIN
			slot ps ON (c.parent_slot_id = ps.slot_id) LEFT JOIN
			component_type_slot_template pst ON (ps.component_type_slot_template_id =
				pst.component_type_slot_template_id)
		WHERE
			s.slot_id = ANY(slot_id_list) AND
			(
				st.slot_name_template ~ '%{' OR
				pst.child_slot_name_template ~ '%{'
			)
	LOOP
		sn := slot_rec.slot_name_template;
		IF (slot_rec.slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{slot_index\}', slot_rec.slot_index::text,
				'g');
		END IF;
		IF (slot_rec.parent_slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{parent_slot_index\}', slot_rec.parent_slot_index::text,
				'g');
		END IF;
		IF (slot_rec.parent_slot_index IS NOT NULL AND
			slot_rec.slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{relative_slot_index\}', 
				(slot_rec.parent_slot_index + slot_rec.slot_index)::text,
				'g');
		END IF;
		RAISE DEBUG 'Setting name of slot % to %',
			slot_rec.slot_id,
			sn;
		UPDATE slot SET slot_name = sn WHERE slot_id = slot_rec.slot_id;
	END LOOP;
END;
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_utils.remove_component_hier(
	component_id	jazzhands.component.component_id%TYPE,
	really_delete	boolean DEFAULT FALSE
) RETURNS BOOLEAN
AS $$
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
		component c
	WHERE
		c.component_id = ANY (delete_list);

	RETURN true;
END;
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

--
-- These need to all call a generic component/component_type insertion
-- function, rather than all of the specific types, but that's thinking
--

CREATE OR REPLACE FUNCTION component_utils.insert_pci_component(
	pci_vendor_id	integer,
	pci_device_id	integer,
	pci_sub_vendor_id	integer DEFAULT NULL,
	pci_subsystem_id	integer DEFAULT NULL,
	pci_vendor_name		text DEFAULT NULL,
	pci_device_name		text DEFAULT NULL,
	pci_sub_vendor_name		text DEFAULT NULL,
	pci_sub_device_name		text DEFAULT NULL,
	component_function_list	text[] DEFAULT NULL,
	slot_type			text DEFAULT 'unknown',
	serial_number		text DEFAULT NULL
) RETURNS jazzhands.component
AS $$
DECLARE
	sn			ALIAS FOR serial_number;
	ctid		integer;
	comp_id		integer;
	sub_comp_id	integer;
	stid		integer;
	vendor_name	text;
	sub_vendor_name	text;
	model_name	text;
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
		vid.component_type_id INTO ctid
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
			sid.component_type_id = did.component_type_id )
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
					_company_name := pci_vendor_name,
					_company_types := ARRAY['hardware provider'],
					 _description := 'PCI vendor auto-insert'
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
		IF pci_sub_device_name IS NOT NULL AND pci_sub_device_name != 'Device' THEN
			model_name = concat_ws(' ', 
				sub_vendor_name, pci_sub_device_name,
				'(' || vendor_name, pci_device_name || ')');
		ELSIF pci_sub_device_name = 'Device' THEN
			model_name = concat_ws(' ', 
				vendor_name, '(' || sub_vendor_name || ')', pci_device_name);
		ELSE
			model_name = concat_ws(' ', vendor_name, pci_device_name);
		END IF;
		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			CASE WHEN 
				sub_comp_id IS NULL OR
				pci_sub_device_name IS NULL OR
				pci_sub_device_name = 'Device'
			THEN
				comp_id
			ELSE
				sub_comp_id
			END,
			CASE WHEN
				pci_sub_device_name IS NULL OR
				pci_sub_device_name = 'Device'
			THEN
				pci_device_name
			ELSE
				pci_sub_device_name
			END,
			stid,
			true,
			model_name
		) RETURNING component_type_id INTO ctid;
		--
		-- Insert properties for the PCI vendor/device IDs
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('PCIVendorID', 'PCI', ctid, pci_vendor_id),
			('PCIDeviceID', 'PCI', ctid, pci_device_id);
		
		IF (pci_subsystem_id IS NOT NULL) THEN
			INSERT INTO component_property (
				component_property_name,
				component_property_type,
				component_type_id,
				property_value
			) VALUES 
				('PCISubsystemVendorID', 'PCI', ctid, pci_sub_vendor_id),
				('PCISubsystemID', 'PCI', ctid, pci_subsystem_id);
		END IF;
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(array_append(component_function_list, 'PCI')) x(cf);
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
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

--
-- These need to all call a generic component/component_type insertion
-- function, rather than all of the specific types, but that's thinking
--

CREATE OR REPLACE FUNCTION component_utils.insert_disk_component(
	model				text,
	bytes				bigint,
	vendor_name			text DEFAULT NULL,
	protocol			text DEFAULT 'SATA',
	media_type			text DEFAULT 'Rotational',
	serial_number		text DEFAULT NULL
) RETURNS jazzhands.component
AS $$
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
			company_id INTO cid
		FROM
			company c LEFT JOIN
			property p USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'VendorDiskProbeString' AND
			property_value = vendor_name;
	END IF;

	--
	-- See if we have this component type in the database already.
	--
	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_type_component_func ctcf USING (component_type_id)
	WHERE
		component_function = 'disk' AND
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
			st.slot_type = protocol AND
			slot_function = 'disk';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type % with function disk not found adding component_type',
				protocol
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
			('DiskSize', 'disk', ctid, bytes),
			('DiskProtocol', 'disk', ctid, protocol),
			('MediaType', 'disk', ctid, media_type);
		
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
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
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_utils.insert_memory_component(
	model				text,
	memory_size			bigint,
	memory_speed		bigint,
	memory_type			text DEFAULT 'DDR3',
	vendor_name			text DEFAULT NULL,
	serial_number		text DEFAULT NULL
) RETURNS jazzhands.component
AS $$
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
			company_id INTO cid
		FROM
			company c LEFT JOIN
			property p USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'VendorMemoryProbeString' AND
			property_value = vendor_name;
	END IF;

	--
	-- See if we have this component type in the database already.
	--
	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_type_component_func ctcf USING (component_type_id)
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
			('MemorySize', 'memory', ctid, memory_size),
			('MemorySpeed', 'memory', ctid, memory_speed);
		
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
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
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION component_utils.insert_cpu_component(
	model				text,
	processor_speed		bigint,
	processor_cores		bigint,
	socket_type			text,
	vendor_name			text DEFAULT NULL,
	serial_number		text DEFAULT NULL
) RETURNS jazzhands.component
AS $$
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
			company_id INTO cid
		FROM
			company c LEFT JOIN
			property p USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'VendorCPUProbeString' AND
			property_value = vendor_name;
	END IF;

	--
	-- See if we have this component type in the database already.
	--
	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_type_component_func ctcf USING (component_type_id)
	WHERE
		component_function = 'CPU' AND
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
			description
		) VALUES (
			cid,
			model,
			stid,
			true,
			model
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

		INSERT INTO component_type_component_func (
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
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_utils.insert_component_into_parent_slot(
	parent_component_id	integer,
	component_id	integer,
	slot_name		text,
	slot_function	text,
	slot_type		text DEFAULT 'unknown',
	slot_index		integer DEFAULT NULL,
	physical_label	text DEFAULT NULL
) RETURNS jazzhands.slot
AS $$
DECLARE
	pcid 	ALIAS FOR parent_component_id;
	cid		ALIAS FOR component_id;
	sf		ALIAS FOR slot_function;
	sn		ALIAS FOR slot_name;
	st		ALIAS FOR slot_type;
	s		RECORD;
	stid	integer;
BEGIN
	--
	-- Look for this slot assigned to the component
	--
	SELECT
		slot.* INTO s
	FROM
		slot JOIN
		slot_type USING (slot_type_id)
	WHERE
		slot.component_id = pcid AND
		slot_type.slot_type = st AND
		slot_type.slot_function = sf AND
		slot.slot_name = sn;

	IF NOT FOUND THEN
		RAISE DEBUG 'Auto-creating slot for component assignment';
		SELECT
			slot_type_id INTO stid
		FROM
			slot_type
		WHERE
			slot_type.slot_type = st AND
			slot_type.slot_function = sf;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type %, function % not found adding component_type',
				st,
				sf
				USING ERRCODE = 'JH501';
		END IF;

		INSERT INTO slot (
			component_id,
			slot_name,
			slot_index,
			slot_type_id,
			physical_label,
			description
		) VALUES (
			pcid,
			sn,
			slot_index,
			stid,
			physical_label,
			'autocreated component slot'
		) RETURNING * INTO s;
	END IF;

	RAISE DEBUG 'Assigning component with component_id % to slot %',
		cid, s.slot_id;

	UPDATE 
		component c
	SET
		parent_slot_id = s.slot_id
	WHERE
		c.component_id = cid;

	RETURN s;
END;
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

--
-- Replace a given simple component with another one.  This isn't very smart,
-- in that it doesn't touch component_property in any way, although perhaps
-- there should be a flag on val_component_property indicating which
-- properties are asset-related, and which are function-related to flag
-- which should be copied
--
-- Note: this does not move any sub-components that are attached to slots,
-- either
--
CREATE OR REPLACE FUNCTION component_utils.replace_component(
	old_component_id	integer,
	new_component_id	integer
) RETURNS VOID
AS $$
DECLARE
	oc	RECORD;
BEGIN
	SELECT
		* INTO oc
	FROM
		component
	WHERE
		component_id = old_component_id;

	UPDATE
		component
	SET
		parent_slot_id = NULL
	WHERE
		component_id = old_component_id;

	UPDATE 
		component
	SET
		parent_slot_id = oc.parent_slot_id
	WHERE
		component_id = new_component_id;

	UPDATE
		device
	SET
		component_id = new_component_id
	WHERE
		component_id = old_component_id;
	
	UPDATE
		physicalish_volume
	SET
		component_id = new_component_id
	WHERE
		component_id = old_component_id;

	RETURN;
END;
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION component_utils.fetch_component(
	component_type_id	jazzhands.component_type.component_type_id%TYPE,
	serial_number		text,
	no_create			boolean DEFAULT false,
	ownership_status	text DEFAULT 'unknown',
	parent_slot_id		jazzhands.slot.slot_id%TYPE DEFAULT NULL
) RETURNS jazzhands.component
AS $$
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
			IF c.parent_slot_id IS NULL THEN
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
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA component_utils TO iud_role;
