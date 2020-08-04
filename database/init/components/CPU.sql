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
	PERFORM * FROM val_component_function WHERE
		component_function = 'CPU';

	IF NOT FOUND THEN
		INSERT INTO val_component_function (component_function, description) 
		VALUES
			('CPU', 'CPU');

		INSERT INTO val_component_property_type (
			component_property_type, description, is_multivalue
		) VALUES 
			('CPU', 'CPU properties', true);

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
			('ProcessorSpeed', 'CPU', 'CPU Speed (MHz)', false, 'number',
				'CPU', 'REQUIRED'),
			('ProcessorCores', 'CPU', 'Number of CPU cores', false, 'number',
				'CPU', 'REQUIRED'),
			('ProcessorGeneration', 'CPU', 'Generation/Family of Processor',
				false, 'string', 'CPU', 'REQUIRED');

		--
		-- Slot functions are also somewhat arbitrary, and exist for associating
		-- valid component_properties, for displaying UI components, and for
		-- validating inter_component_connection links
		--
		INSERT INTO val_slot_function (slot_function, description) VALUES
			('CPU', 'CPU slot');

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
		-- CPU slots
		--

		INSERT INTO val_slot_physical_interface
			(slot_physical_interface_type, slot_function)
		SELECT
			unnest(ARRAY[
				'Socket LGA1366',
				'Socket LGA2011',
				'Socket LGA2011-3'
			]),
			'CPU'
		;


		INSERT INTO slot_type 
			(slot_type, slot_physical_interface_type, slot_function, description,
			 remote_slot_permitted)
		VALUES
			('Socket LGA1366', 'Socket LGA1366', 'CPU',
				'LGA1366 CPU socket', false),
			('Socket LGA2011', 'Socket LGA2011', 'CPU',
				'LGA2011 CPU socket', false),
			('Socket LGA2011-3', 'Socket LGA2011-3', 'CPU',
				'LGA2011-v3 CPU socket', false);

		--
		-- Insert the permitted CPU connections.  CPUs can only go into a slot
		-- of the same type
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
			st.slot_function = 'CPU';
	END IF;
END $$ language plpgsql;
