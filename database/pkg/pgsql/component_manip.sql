--
-- Copyright (c) 2015-2020 Matthew Ragan
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
        where nspname = 'component_manip';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS component_manip;
                CREATE SCHEMA component_manip AUTHORIZATION jazzhands;
		REVOKE ALL ON SCHEMA component_manip FROM public;
		COMMENT ON SCHEMA component_manip IS 'part of jazzhands';
        END IF;
END;
$$;

CREATE OR REPLACE FUNCTION component_manip.create_component_template_slots(
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

CREATE OR REPLACE FUNCTION component_manip.migrate_component_template_slots(
	component_id			jazzhands.component.component_id%TYPE
) RETURNS SETOF jazzhands.slot
AS $$
DECLARE
	cid 	ALIAS FOR component_id;
BEGIN
	-- Ensure all of the new slots have appropriate names

	PERFORM component_manip.set_slot_names(
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
	), l3i_upd AS (
		UPDATE
			layer3_interface l3i
		SET
			slot_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			l3i.slot_id = slot_map.old_slot_id
		RETURNING *
	), delete_migrated_slots AS (
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
					layer3_interface l3i ON (
						l3i.slot_id = os.slot_id OR
						l3i.slot_id = os.slot_id) LEFT JOIN
					inter_component_connection ic ON (
						slot1_id = os.slot_id OR
						slot2_id = os.slot_id) LEFT JOIN
					component c ON (c.parent_slot_id = os.slot_id)
				WHERE
					ic.inter_component_connection_id IS NULL AND
					c.component_id IS NULL AND
					l3i.layer3_interface_id IS NULL AND
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

CREATE OR REPLACE FUNCTION component_manip.set_slot_names(
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
			ps.slot_name as parent_slot_name,
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
		IF slot_rec.parent_slot_name IS NOT NULL THEN
			sn := regexp_replace(sn,
				'%\{parent_slot_name\}',
				slot_rec.parent_slot_name,
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

CREATE OR REPLACE FUNCTION component_manip.remove_component_hier(
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
		asset a
	WHERE
		a.component_id = ANY (delete_list);

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

CREATE OR REPLACE FUNCTION component_manip.insert_pci_component(
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
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_manip.update_pci_component_type_model(
	component_type_id		jazzhands.component_type.component_type_id%TYPE,
	pci_device_name			text,
	pci_sub_device_name		text DEFAULT NULL,
	pci_vendor_name			text DEFAULT NULL,
	pci_sub_vendor_name		text DEFAULT NULL
) RETURNS jazzhands.component_type
AS $$
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
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

--
-- These should call a generic component/component_type insertion
-- function, rather than all of the specific types, but there are
-- stupid complications, because vendors suck.
--

CREATE OR REPLACE FUNCTION component_manip.insert_disk_component(
	model				text,
	bytes				bigint DEFAULT NULL,
	vendor_name			text DEFAULT NULL,
	protocol			text DEFAULT NULL,
	media_type			text DEFAULT NULL,
	serial_number		text DEFAULT NULL,
	rotational_rate		integer DEFAULT NULL
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
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_manip.insert_memory_component(
	model				text,
	memory_size			bigint,
	memory_speed		bigint DEFAULT NULL,
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
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION component_manip.insert_cpu_component(
	model				text,
	processor_speed		bigint,
	processor_cores		bigint,
	socket_type			text,
	vendor_name			text DEFAULT NULL,
	serial_number		text DEFAULT NULL,
	virtual_component	boolean DEFAULT false
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
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_manip.insert_component_into_parent_slot(
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
CREATE OR REPLACE FUNCTION component_manip.replace_component(
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

CREATE OR REPLACE FUNCTION component_manip.fetch_component(
	component_type_id	jazzhands.component_type.component_type_id%TYPE,
	serial_number		text,
	no_create			boolean DEFAULT false,
	ownership_status	text DEFAULT 'unknown',
	parent_slot_id		jazzhands.slot.slot_id%TYPE DEFAULT NULL,
	force_parent		boolean DEFAULT false
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
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_manip.set_component_property(
	component_property_name	jazzhands.component_property.component_property_name%TYPE,
	component_property_type	jazzhands.component_property.component_property_type%TYPE,
	property_value			jazzhands.component_property.property_value%TYPE,
	component_id			jazzhands.component.component_id%TYPE DEFAULT NULL,
	component_type_id		jazzhands.component.component_type_id%TYPE DEFAULT NULL
) RETURNS boolean
AS $$
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
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_manip.set_component_network_interface(
	component_id        jazzhands.component.component_id%TYPE,
	network_interface   jsonb
) RETURNS jazzhands.slot
AS $$
DECLARE
	cid		ALIAS FOR component_id;
	ni		ALIAS FOR network_interface;
	cs		RECORD;
	lldp	jsonb;
	stid	jazzhands.slot_type.slot_type_id%TYPE;
BEGIN
	IF component_id IS NULL OR network_interface IS NULL THEN
	    RETURN NULL;
	END IF;

	--
	-- If there isn't an interface name passed, then just give up
	--

	IF NOT (ni ? 'interface_name') OR (ni->>'interface_name' IS NULL) OR
			(ni->>'interface_name' = '') THEN
		RETURN NULL;
	END IF;

	--
	-- Attempt to find the slot already inserted, in this order
	--  - slot with this permanent_mac, if permanent_mac is passed
	--  - slot with this component_id and given interface_name
	--  - slot with this component_id where the remote LLDP connection matches
	--

	IF ni ? 'permanent_mac' THEN
		--
		-- First look to see if there's a slot with this MAC already
		--
		RAISE DEBUG 'Looking for slot with mac_address %',
			ni->>'permanent_mac';

		SELECT
			* INTO cs
		FROM
			slot
		WHERE
			mac_address = (ni->>'permanent_mac')::macaddr;
	END IF;

	IF cs IS NULL AND ni ? 'interface_name' THEN
		RAISE DEBUG 'Looking for slot for component % with name %',
			cid,
			ni->>'interface_name';

		SELECT
			s.* INTO cs
		FROM
			slot s JOIN
			slot_type st USING (slot_type_id)
		WHERE
			s.component_id = cid AND
			st.slot_function = 'network' AND
			s.slot_name = ni->>'interface_name';
	END IF;

	IF cs IS NULL AND ni ? 'lldp' THEN
		lldp := ni->'lldp';

		RAISE DEBUG 'Looking for slot for component % connected to %/% port %',
			cid,
			lldp->>'device_name',
			lldp->>'chassis_id',
			lldp->>'interface';

		SELECT
			s.* INTO cs
		FROM
			slot s JOIN
			v_device_slot_connections dsc USING (slot_id) JOIN
			device d ON (dsc.remote_device_id = d.device_id)
		WHERE
			s.component_id = cid AND (
				d.host_id = lldp->>'chassis_id' OR
				(
					d.device_name = lldp->>'device_name' AND
					d.host_id IS NULL
				)
			) AND
			dsc.remote_slot_name = lldp->>'interface'
		ORDER BY
			d.host_id NULLS LAST
		LIMiT 1;
	END IF;

	--
	-- Figure out which slot_type we're supposed to use.  If we don't know,
	-- then c'est la vie.
	--

	IF ni ? 'capabilities' THEN
		SELECT
			slot_type_id INTO stid
		FROM
			device_provisioning.ethtool_xcvr_to_slot_type et
		WHERE
			ni->'capabilities' ? et.capability AND
			ni->'transceiver'->>'port_type' = et.port_type AND
			ni->'transceiver'->>'media_type' = et.media_type
		ORDER BY
			raw_speed DESC
		LIMIT 1;

		IF FOUND THEN
			RAISE DEBUG 'slot_type_id for slot should be %', stid;
		ELSE
			RAISE DEBUG 'slot_type_id for slot could not be determined';
		END IF;
	END IF;

	--
	-- This is needed because Ubuntu 16.04 is broken detecting 25G.  We
	-- only want this to happen if the above fails.
	--
	IF stid IS NULL THEN
		SELECT
			slot_type_id INTO stid
		FROM
			device_provisioning.ethtool_xcvr_to_slot_type et
		WHERE
			ni->'transceiver'->>'speed' = et.speed AND
			ni->'transceiver'->>'port_type' = et.port_type AND
			ni->'transceiver'->>'media_type' = et.media_type;

		IF FOUND THEN
			RAISE DEBUG 'slot_type_id for slot should be %', stid;
		ELSE
			RAISE DEBUG 'slot_type_id for slot could not be determined';
		END IF;
	END IF;

	IF cs IS NULL AND stid IS NOT NULL THEN
		INSERT INTO slot (
			component_id,
			slot_name,
			slot_type_id,
			mac_address
		) VALUES (
			cid,
			ni->>'interface_name',
			stid,
			(ni->>'permanent_mac')::macaddr
		) RETURNING * INTO cs;
	END IF;

	--
	-- Fix the slot name if it doesn't match the current Linux name
	--
	IF cs.slot_name != ni->>'interface_name' THEN
		UPDATE
			slot
		SET
			slot_name = ni->>'interface_name'
		WHERE
			slot_id = cs.slot_id;

		cs.slot_name := ni->>'interface_name';
	END IF;

	--
	-- Update the mac_address if it needs to be
	--
	IF cs.mac_address IS DISTINCT FROM (ni->>'permanent_mac')::macaddr THEN
		UPDATE
			slot
		SET
			mac_address = (ni->>'permanent_mac')::macaddr
		WHERE
			slot_id = cs.slot_id;

		cs.mac_address := (ni->>'permanent_mac')::macaddr;
	END IF;

	--
	-- Fix the slot type if it isn't correct
	--
	IF cs.slot_type_id != stid THEN
		UPDATE
			slot
		SET
			slot_type_id = stid
		WHERE
			slot_id = cs.slot_id;

		cs.slot_type_id := stid;
	END IF;

	RETURN cs;
END;
$$
set search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

<<<<<<< HEAD
=======
DROP FUNCTION IF EXISTS component_manip.insert_arista_switch_type(text, jsonb, text, integer);

>>>>>>> 9085778a (Reworked most of the bits to populate Arista hardware)
CREATE OR REPLACE FUNCTION component_manip.insert_arista_switch_type(
	model			text,
	ports			jsonb,
	description		text DEFAULT NULL,
	size_units		integer DEFAULT 1
) RETURNS jazzhands.component_type AS $$
#variable_conflict use_variable
DECLARE
	m				ALIAS FOR model;
	ctrec			RECORD;
	cid				jazzhands.company.company_id%TYPE;
	ctid			jazzhands.component_type.component_type_id%TYPE;
	p				jsonb;
	port_offset		integer;
	x_offset		integer;
BEGIN
	SELECT company_id INTO cid FROM company WHERE company_name = 'Arista Networks';
	IF NOT FOUND THEN
		SELECT company_manip.add_company(
			company_name := 'Arista Networks',
			company_types := ARRAY['hardware provider']
		) INTO cid;
		INSERT INTO property (
			property_name,
			property_type,
			company_collection_id,
			property_value
		)
		SELECT
			'DeviceVendorProbeString',
			'DeviceProvisioning',
			company_collection_id,
			'Arista'
		FROM
			company_collection cc JOIN
			company_collection_company ccc USING (company_collection_id) JOIN
			company c USING (company_id)
		WHERE
			company_collection_type = 'per-company' AND
			company_name = 'Arista Networks';
	END IF;

	SELECT * INTO ctrec FROM component_type ct WHERE
		company_id = cid AND
<<<<<<< HEAD
		ct.model = m;

	IF FOUND THEN
		RAISE 'switch model % already exists as component_type_id %',
=======
		ct.model = 'DCS-' || m;

	IF FOUND THEN
		RAISE 'Switch type for model % already exists as component_type_id %',
>>>>>>> 9085778a (Reworked most of the bits to populate Arista hardware)
			m,
			ctrec.ctid
		USING ERRCODE = 'unique_violation';
	END IF;

	INSERT INTO component_type (
		description,
		slot_type_id,
		model,
		company_id,
		asset_permitted,
		is_rack_mountable,
		size_units
	) VALUES (
		description,
		NULL,
<<<<<<< HEAD
		model,
=======
		'DCS-' || model,
>>>>>>> 9085778a (Reworked most of the bits to populate Arista hardware)
		cid,
		true,
		true,
		size_units
	) RETURNING * INTO ctrec;

	ctid = ctrec.component_type_id;

	INSERT INTO component_type_component_function (
		component_type_id,
		component_function
	) VALUES (
		ctid,
		'device'
	);

	INSERT INTO device_type (
		component_type_id,
		device_type_name,
		description,
		company_id,
		config_fetch_type,
		rack_units
	) VALUES (
		ctid,
<<<<<<< HEAD
		model,
=======
		'DCS-' || model,
>>>>>>> 9085778a (Reworked most of the bits to populate Arista hardware)
		description,
		cid,
		'arista',
		size_units
	);

	--
	-- Console port
	--

	INSERT INTO component_type_slot_template (
		component_type_id,
		slot_type_id,
		slot_name_template,
		slot_index,
		slot_y_offset,
		slot_side
	) SELECT
		ctid,
		slot_type_id,
		'console',
		0,
		0,
		'FRONT'
	FROM
		slot_type st
	WHERE
		slot_type = 'RJ45 serial' and slot_function = 'serial';

	--
	-- Management port
	--
	INSERT INTO component_type_slot_template (
		component_type_id,
		slot_type_id,
		slot_name_template,
		slot_y_offset,
		slot_side
	) SELECT
		ctid,
		slot_type_id,
		'Management1',
		1,
		'FRONT'
	FROM
		slot_type st
	WHERE
		slot_type = '1000BaseTEthernet' and slot_function = 'network';

	--
	-- Switch ports
	--
	port_offset = 0;
	x_offset = 0;

	FOR p IN SELECT jsonb_array_elements(ports) LOOP
<<<<<<< HEAD
=======
		RAISE INFO '%', jsonb_pretty(jsonb_build_object(
			'port_offset', port_offset,
			'x_offset', x_offset,
			'size_units', size_units,
			'port', p
		));
>>>>>>> 9085778a (Reworked most of the bits to populate Arista hardware)
		INSERT INTO component_type_slot_template (
			component_type_id,
			slot_type_id,
			slot_name_template,
<<<<<<< HEAD
			child_slot_name_template,
=======
>>>>>>> 9085778a (Reworked most of the bits to populate Arista hardware)
			physical_label,
			slot_index,
			slot_x_offset,
			slot_y_offset,
			slot_side
		) SELECT
			ctid,
			slot_type_id,
<<<<<<< HEAD
			'Ethernet' || (port_offset + x.idx + 1),
=======
>>>>>>> 9085778a (Reworked most of the bits to populate Arista hardware)
			CASE
			WHEN slot_physical_interface_type IN (
				'QSFP', 'QSFP+', 'QSFP28', 'QSFP-DD', 'OSFP'
			) THEN
				'Ethernet' || (port_offset + x.idx + 1) ||
				'/%{slot_index}'
			ELSE
				'Ethernet' || (port_offset + x.idx + 1)
			END,
			'Ethernet' || (port_offset + x.idx + 1),
			port_offset + x.idx + 1,
			x_offset + (
				(x.idx / 2) % (
					GREATEST((p->>'count')::integer, 2 * size_units) /
					(2 * size_units)
				)
			),
			(x.idx % 2) + 2 * (
				x.idx / ((p->>'count')::integer / size_units)
			),
			'FRONT'
		FROM
			slot_type st,
			generate_series(0,(p->>'count')::integer - 1) x(idx)
		WHERE
			slot_type = p->>'slot_type' and slot_function = 'network';

		port_offset = port_offset + (p->>'count')::integer;
		x_offset = x_offset +
			(p->>'count')::integer / (2 * size_units);
	END LOOP;
	RETURN ctrec;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
<<<<<<< HEAD

CREATE OR REPLACE FUNCTION component_manip.insert_arista_optic_type(
	model			text,
	slot_type		text,
	count			integer,
	media			text,
	description		text DEFAULT NULL
) RETURNS jazzhands.component_type AS $$
#variable_conflict use_variable
DECLARE
	cid			jazzhands.company.company_id%TYPE;
	ctrec		RECORD;
	m			ALIAS FOR model;
	slt			ALIAS FOR slot_type;
	ctid		jazzhands.component_type.component_type_id%TYPE;
	cnt			ALIAS FOR count;
BEGIN
	SELECT company_id INTO cid FROM company WHERE company_name = 'Arista Networks';
	IF NOT FOUND THEN
		SELECT company_manip.add_company(
			company_name := 'Arista Networks',
			company_types := ARRAY['hardware provider']
		) INTO cid;
		INSERT INTO property (
			property_name,
			property_type,
			company_collection_id,
			property_value
		)
		SELECT
			'DeviceVendorProbeString',
			'DeviceProvisioning',
			company_collection_id,
			'Arista'
		FROM
			company_collection cc JOIN
			company_collection_company ccc USING (company_collection_id) JOIN
			company c USING (company_id)
		WHERE
			company_collection_type = 'per-company' AND
			company_name = 'Arista Networks';
	END IF;

	SELECT * INTO ctrec FROM component_type ct WHERE
		company_id = cid AND
		ct.model = m;

	IF FOUND THEN
		RAISE 'optic % already exists as component_type_id %',
			m,
			ctrec.ctid
		USING ERRCODE = 'unique_violation';
	END IF;

	INSERT INTO component_type (
		description,
		slot_type_id,
		model,
		company_id,
		asset_permitted,
		is_rack_mountable
	) SELECT
		description,
		st.slot_type_id,
		model,
		cid,
		true,
		false
	FROM
		slot_type st
	WHERE
		st.slot_type = slt and slot_function = 'network'
	RETURNING * INTO ctrec;

	ctid = ctrec.component_type_id;

	INSERT INTO component_type_component_function (
		component_type_id,
		component_function
	) VALUES (
		ctid,
		'network_transceiver'
	);
	--
	-- ports
	--
	INSERT INTO component_type_slot_template (
		component_type_id,
		slot_type_id,
		slot_name_template,
		slot_index
	) SELECT
		ctid,
		slot_type_id,
		'%{parent_slot_name}/' || x.idx + 1,
		x.idx + 1
	FROM
		slot_type st,
		generate_series(0,cnt - 1) x(idx)
	WHERE
		st.slot_type = media and slot_function = 'network';

	RETURN ctrec;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
=======
>>>>>>> 9085778a (Reworked most of the bits to populate Arista hardware)

REVOKE ALL ON SCHEMA component_manip FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA component_manip FROM public;

GRANT USAGE ON SCHEMA component_manip TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA component_manip TO iud_role;
