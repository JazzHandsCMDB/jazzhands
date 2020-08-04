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
#variable_conflict use_variable
DECLARE
	ctid	integer;
	stid	integer;
	d		text[];
	s		integer;
BEGIN
	--
	-- Insert the chassis slot type
	--
	INSERT INTO slot_type
		(slot_type, slot_physical_interface_type, slot_function, description,
		 remote_slot_permitted)
	VALUES
		 ('C6320node', 'sled', 'chassis_slot', 'C6320 node', false)
	RETURNING
		slot_type_id INTO stid;

	--
	-- Insert the chassis component type
	--
	INSERT INTO component_type (
		description,
		slot_type_id,
		model,
		company_id,
		asset_permitted,
		is_rack_mountable,
		size_units
	) VALUES (
		'Dell C6320 chassis',
		NULL,
		'PowerEdge C6320 chassis',
		(SELECT company_id FROM jazzhands.company WHERE company_name = 'Dell'),
		true,
		true,
		2
	) RETURNING component_type_id INTO ctid;

	INSERT INTO component_type_component_function (
		component_type_id,
		component_function
	) VALUES (
		ctid,
		'chassis'
	);

	--
	-- Create the chassis slot template
	--
	INSERT INTO component_type_slot_template (
		component_type_id,
		slot_type_id,
		slot_name_template,
		slot_index,
		slot_x_offset,
		slot_y_offset,
		slot_side
	) SELECT
		ctid,
		stid,
		'node' || x.idx + 1,
		x.idx + 1,
		(x.idx / 2),
		(x.idx % 2),
		'BACK'
	FROM
		generate_series(0,3) x(idx);

	--
	-- There's no real difference that we care about between the C6320 and the
	-- C6320 II, except that they probe differently.  Insert a 1U and a 2U
	-- version
	--
	FOREACH d SLICE 1 IN ARRAY ARRAY[
			['PowerEdge C6320', '0TTH1R']
			] LOOP
		INSERT INTO component_type (
				description,
				slot_type_id,
				model,
				part_number,
				company_id,
				asset_permitted,
				is_rack_mountable,
				size_units
			) VALUES (
				d[1],
				stid,
				d[1],
				d[2],
				(SELECT company_id FROM jazzhands.company WHERE company_name = 'Dell'),
				true,
				false,
				1
			) RETURNING component_type_id INTO ctid;

			INSERT INTO component_type_component_function (
				component_type_id,
				component_function
			) VALUES (
				ctid,
				'device'
			);
	END LOOP;
END;
$$ LANGUAGE plpgsql;
