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
	PERFORM * FROM val_component_function WHERE component_function = 'disk';

	IF NOT FOUND THEN
		INSERT INTO val_component_function (component_function, description)
			VALUES
			('disk', 'disk-type storage'),
			('rotational_disk', 'rotational disk'),
			('SSD', 'solid-state disk');

		INSERT INTO val_component_property_type (
			component_property_type, description, is_multivalue
		) VALUES
			('disk', 'disk properties', true);

		--
		-- Insert some component function properties
		--
		INSERT INTO val_component_property (
			component_property_name, component_property_type, is_multivalue,
			description, property_data_type,
			permit_component_id, required_component_function
		) VALUES (
			'SCSI_Id', 'disk', false,
			'Virtual Disk SCSI Id', 'number',
			'REQUIRED', 'storage'
		);

		INSERT INTO val_component_property (
			component_property_name,
			component_property_type,
			description,
			is_multivalue,
			property_data_type,
			required_component_function,
			permit_component_type_id
		) VALUES
			('DiskSize', 'disk', 'Disk Size (sectors)', false, 'number',
				'disk', 'REQUIRED'),
			('RotationalRate', 'disk',
				'Disk Rotational Rate (for rotational media)', false, 'number',
				'disk', 'REQUIRED');

		INSERT INTO val_component_property (
			component_property_name,
			component_property_type,
			description,
			is_multivalue,
			property_data_type,
			required_component_function,
			permit_component_type_id
		) VALUES
			('MediaType', 'disk', 'Disk Media Type', false, 'list',
				'disk', 'REQUIRED');

		INSERT INTO val_component_property_value (
			component_property_name,
			component_property_type,
			valid_property_value,
			description
		) VALUES
			('MediaType', 'disk', 'Rotational', 'Rotational hard disk drive'),
			('MediaType', 'disk', 'Solid State', 'Solid state disk drive');

		INSERT INTO val_component_property (
			component_property_name,
			component_property_type,
			description,
			is_multivalue,
			property_data_type,
			required_component_function,
			permit_component_type_id
		) VALUES
			('DiskProtocol', 'disk', 'Disk Protocol', false, 'list',
				'disk', 'REQUIRED');

		INSERT INTO val_component_property_value (
			component_property_name,
			component_property_type,
			valid_property_value,
			description
		) VALUES
			('DiskProtocol', 'disk', 'SATA', 'Serial ATA'),
			('DiskProtocol', 'disk', 'SAS', 'Serial Attached SCSI'),
			('DiskProtocol', 'disk', 'SAS (SPL-3)', 'Serial Attached SCSI Protocol Layer 3'),
			('DiskProtocol', 'disk', 'SCSI', 'SCSI'),
			('DiskProtocol', 'disk', 'NVMe', 'NEMe');

		--
		-- Slot functions are also somewhat arbitrary, and exist for associating
		-- valid component_properties, for displaying UI components, and for
		-- validating inter_component_connection links
		--
		INSERT INTO val_slot_function (slot_function, description) VALUES
			('disk', 'disk slot');

		--
		-- Slot types are not arbitrary.  In order for a component to attach to a
		-- slot, a specific linkage must exist in either
		-- slot_type_permitted_component_type for internal connections (i.e. the
		-- component becomes a logical sub-component of the parent) or in
		-- slot_type_permitted_remote_slot_type for an external connection (i.e.
		-- a connection to a separate component entirely, such as a network or
		-- power connection)
		--

		--
		-- Disk slots
		--

		INSERT INTO val_slot_physical_interface
			(slot_physical_interface_type, slot_function)
		SELECT
			unnest(ARRAY[
				'SATA',
				'SAS'
			]),
			'disk'
		;


		INSERT INTO slot_type
			(slot_type, slot_physical_interface_type, slot_function,
			 description, remote_slot_permitted)
		VALUES
			('SATA', 'SATA', 'disk', 'SATA connection', false),
			('SAS', 'SAS', 'disk', 'SAS connection', false);

		--
		-- Insert the permitted disk connections.  SATA can go into SAS;
		-- The reverse is not true
		--

		INSERT INTO slot_type_permitted_component_slot_type (
			slot_type_id,
			component_slot_type_id
		) SELECT
			st.slot_type_id,
			st.slot_type_id
		FROM
			slot_type st
		WHERE
			st.slot_function = 'disk';

		INSERT INTO slot_type_permitted_component_slot_type (
			slot_type_id,
			component_slot_type_id
		) SELECT
			st.slot_type_id,
			cst.slot_type_id
		FROM
			slot_type st,
			slot_type cst
		WHERE
			st.slot_function = 'disk' AND
			st.slot_type = 'SAS' AND
			cst.slot_function = 'disk' AND
			cst.slot_type = 'SATA';

	END IF;
END; $$ language plpgsql;

INSERT INTO component_type (
	model, is_virtual_component
) VALUES (
	'Virtual Disk', true
);
\ir ST9500530NS.sql
