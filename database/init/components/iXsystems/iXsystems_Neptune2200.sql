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
			'iXsystems iX2224-BACR920LPB/2.5',
			NULL,
			'iX2224-BACR920LPB/2.5',
			'085915D9',
			(SELECT company_id FROM jazzhands.company WHERE company_name = 'iXsystems'),
			true,
			true,
			2
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
			x.slot,
			row_number() over (order by x.slot)
		FROM
			slot_type st,
			unnest(ARRAY[
				'P1_DIMMA1',
				'P1_DIMMA2',
				'P1_DIMMB1',
				'P1_DIMMB2',
				'P1_DIMMC1',
				'P1_DIMMC2',
				'P1_DIMMD1',
				'P1_DIMMD2',
				'P2_DIMME1',
				'P2_DIMME2',
				'P2_DIMMF1',
				'P2_DIMMF2',
				'P2_DIMMG1',
				'P2_DIMMG2',
				'P2_DIMMH1',
				'P2_DIMMH2'
			]) x(slot)
		WHERE
			slot_type = 'DDR3 RDIMM' and slot_function = 'memory';

END;
$$ LANGUAGE plpgsql;

