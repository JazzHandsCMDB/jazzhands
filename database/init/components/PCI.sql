--
-- Copyright (c) 2015 Matthew Ragan
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
BEGIN
	PERFORM * FROM val_component_function WHERE component_function = 'PCI';
	IF NOT FOUND THEN
		INSERT INTO val_component_function (component_function, description) VALUES
			('PCI', 'PCI Card');

		INSERT INTO val_component_property_type (
			component_property_type, description, is_multivalue
		) VALUES 
			('PCI', 'PCI properties', 'Y');

		--
		-- Insert a sampling of component function properties
		--
		INSERT INTO val_component_property (
			component_property_name,
			component_property_type,
			description,
			is_multivalue,
			property_data_type,
			required_component_function,
			permit_component_type_id
		) VALUES 
			('PCIVendorID', 'PCI', 'PCI Vendor ID', 'N', 'number',
				'PCI', 'REQUIRED'),
			('PCIDeviceID', 'PCI', 'PCI Device ID', 'N', 'number',
				'PCI', 'REQUIRED'),
			('PCISubsystemVendorID', 'PCI', 'PCI Vendor ID', 'N', 'number',
				'PCI', 'REQUIRED'),
			('PCISubsystemID', 'PCI', 'PCI Device ID', 'N', 'number',
				'PCI', 'REQUIRED');

		--
		-- Slot functions are also somewhat arbitrary, and exist for associating
		-- valid component_properties, for displaying UI components, and for
		-- validating inter_component_connection links
		--
		INSERT INTO val_slot_function (slot_function, description) VALUES
			('PCI', 'PCI');

		--
		-- Slot types are not arbitrary.  In order for a component to attach to
		-- a slot, a specific linkage must exist in either
		-- slot_type_permitted_component_type for internal connections (i.e.
		-- the component becomes a logical sub-component of the parent) or in
		-- slot_type_prmt_rem_slot_type for an external connection (i.e.
		-- a connection to a separate component entirely, such as a network or
		-- power connection)
		--

		--
		-- PCI slots
		--

		INSERT INTO val_slot_physical_interface
			(slot_physical_interface_type, slot_function)
		SELECT
			unnest(ARRAY[
				'unknown',
				'PCIEx1',
				'PCIEx2',
				'PCIEx4',
				'PCIEx8',
				'PCIEx16'
			]),
			'PCI'
		;


		INSERT INTO slot_type 
			(slot_type, slot_physical_interface_type, slot_function, description,
			 remote_slot_permitted)
		VALUES
			('unknown', 'unknown', 'PCI', 'Unknown PCI type', 'N'),
			('PCIEx1', 'PCIEx1', 'PCI', 'PCI-E x1', 'N'),
			('PCIEx1half', 'PCIEx1', 'PCI', 'PCI-E x1 half-length', 'N'),
			('PCIEx2', 'PCIEx2', 'PCI', 'PCI-E x2', 'N'),
			('PCIEx2half', 'PCIEx2', 'PCI', 'PCI-E x2 half-length', 'N'),
			('PCIEx4', 'PCIEx4', 'PCI', 'PCI-E x4', 'N'),
			('PCIEx4half', 'PCIEx4', 'PCI', 'PCI-E x4 half-length', 'N'),
			('PCIEx8', 'PCIEx8', 'PCI', 'PCI-E x8', 'N'),
			('PCIEx8half', 'PCIEx8', 'PCI', 'PCI-E x8 half-length', 'N'),
			('PCIEx16', 'PCIEx16', 'PCI', 'PCI-E x16', 'N'),
			('PCIEx16half', 'PCIEx16', 'PCI', 'PCI-E x16 half-length', 'N');

		--
		-- Insert the permitted PCI connections.  Components can connect to
		-- anything as wide or wider, and half-length cards can only go into
		-- half-length slots.  May need to do half-height slots as well.
		-- 

		INSERT INTO slot_type_prmt_comp_slot_type (
			slot_type_id,
			component_slot_type_id
		) SELECT
			st.slot_type_id,
			cst.slot_type_id
		FROM
			slot_type st,
			slot_type cst
		WHERE
			st.slot_function = 'PCI' AND cst.slot_function = 'PCI' AND (
			(st.slot_type = 'PCIEx1' AND
				cst.slot_physical_interface_type IN ('PCIEx1','unknown')) OR
			(st.slot_type = 'PCIEx2' AND
				cst.slot_physical_interface_type IN ('PCIEx1','PCIEx2','unknown')) OR
			(st.slot_type = 'PCIEx4' AND
				cst.slot_physical_interface_type IN
				('PCIEx1','PCIEx2','PCIEx4','unknown')) OR
			(st.slot_type = 'PCIEx8' AND
				cst.slot_physical_interface_type IN
				('PCIEx1','PCIEx2','PCIEx4','PCIEx8','unknown')) OR
			(st.slot_type = 'PCIEx16' AND
				cst.slot_physical_interface_type IN
				('PCIEx1','PCIEx2','PCIEx4','PCIEx8','PCIEx16','unknown')) OR
			(st.slot_type = 'unknown' AND
				cst.slot_physical_interface_type IN
				('PCIEx1','PCIEx2','PCIEx4','PCIEx8','PCIEx16','unknown')) OR
			(st.slot_type = 'PCIEx1half' AND
				cst.slot_type IN ('PCIEx1half','unknown')) OR
			(st.slot_type = 'PCIEx2half' AND
				cst.slot_type IN ('PCIEx1half','PCIEx2half','unknown')) OR
			(st.slot_type = 'PCIEx4half' AND
				cst.slot_type IN ('PCIEx1half','PCIEx2half','PCIEx4half','unknown')) OR
			(st.slot_type = 'PCIEx8half' AND
				cst.slot_type IN
				('PCIEx1half','PCIEx2half','PCIEx4half','PCIEx8half','unknown')) OR
			(st.slot_type = 'PCIEx16half' AND
				cst.slot_type IN ('PCIEx1half','PCIEx2half',
				'PCIEx4half','PCIEx8half','PCIEx16half','unknown'))
			);
	END IF;
END; $$ language plpgsql;
