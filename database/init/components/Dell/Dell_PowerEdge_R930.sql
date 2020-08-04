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
	FOREACH d SLICE 1 IN ARRAY ARRAY[
			['PowerEdge R930', NULL]
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
			'Dell ' || d[1],
			NULL,
			d[1],
			d[2],
			(SELECT company_id FROM jazzhands.company WHERE company_name = 'Dell'),
			true,
			true,
			4
		) RETURNING component_type_id INTO ctid;

		INSERT INTO component_type_component_function (
			component_type_id,
			component_function
		) VALUES (
			ctid,
			'device'
		);

		--
		-- CPU sockets
		--
		INSERT INTO component_type_slot_template (
			component_type_id,
			slot_type_id,
			slot_name_template,
			slot_index
		) SELECT
			ctid,
			slot_type_id,
			'CPU' || x.idx,
			x.idx
		FROM
			slot_type st,
			generate_series(1,2) x(idx)
		WHERE
			slot_type = 'Socket LGA2011-3' and slot_function = 'CPU';

		--
		-- memory slots
		--
		INSERT INTO component_type_slot_template (
			component_type_id,
			slot_type_id,
			slot_name_template,
			slot_index
		) SELECT
			ctid,
			slot_type_id,
			'DIMM_' || x.slot,
			row_number() over (order by x.slot)
		FROM
			slot_type st,
			unnest(ARRAY[
				'A1',
				'A2',
				'A3',
				'A4',
				'A5',
				'A6',
				'A7',
				'A8',
				'A9',
				'A10',
				'A11',
				'A12',
				'B1',
				'B2',
				'B3',
				'B4',
				'B5',
				'B6',
				'B7',
				'B8',
				'B9',
				'B10',
				'B11',
				'B12',
				'C1',
				'C2',
				'C3',
				'C4',
				'C5',
				'C6',
				'C7',
				'C8',
				'C9',
				'C10',
				'C11',
				'C12',
				'D1',
				'D2',
				'D3',
				'D4',
				'D5',
				'D6',
				'D7',
				'D8',
				'D9',
				'D10',
				'D11',
				'D12'
			]) x(slot)
		WHERE
			slot_type = 'DDR3 RDIMM' and slot_function = 'memory';
	END LOOP;
END;
$$ LANGUAGE plpgsql;

