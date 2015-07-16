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
	cid		integer;
	ctid	integer;
	stid	integer;
	s		text;
BEGIN
	SELECT company_id INTO cid FROM company WHERE company_name = 'Arista';
	IF NOT FOUND THEN
		INSERT INTO company (company_name) VALUES ('Arista') RETURNING
			company_id INTO cid;
	END IF;
	FOREACH s IN ARRAY ARRAY['F','R'] LOOP
		INSERT INTO component_type (
			description,
			slot_type_id,
			model,
			company_id,
			asset_permitted,
			is_rack_mountable,
			size_units
		) VALUES (
			'Arista DCS-7050Q-16-' || s,
			NULL,
			'DCS-7050Q-16-' || s,
			cid,
			'Y',
			'Y',
			1
		) RETURNING component_type_id INTO ctid;

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) VALUES (
			ctid,
			'device'
		);

		--
		-- Console port
		--

		INSERT INTO component_type_slot_tmplt (
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

		INSERT INTO component_type_slot_tmplt (
			component_type_id,
			slot_type_id,
			slot_name_template,
			physical_label,
			slot_index,
			slot_x_offset,
			slot_y_offset,
			slot_side
		) SELECT
			ctid,
			slot_type_id,
			'Ethernet' || (x.idx + 1) || '/1',
			49 + x.idx,
			49 + x.idx,
			(x.idx / 2),
			(x.idx % 2),
			'FRONT'
		FROM
			slot_type st,
			generate_series(0,15) x(idx)
		WHERE
			slot_type = '40GQSFP+Ethernet' and slot_function = 'network';

		INSERT INTO component_type_slot_tmplt (
			component_type_id,
			slot_type_id,
			slot_name_template,
			physical_label,
			slot_index,
			slot_x_offset,
			slot_y_offset,
			slot_side
		) SELECT
			ctid,
			slot_type_id,
			'Ethernet' || x.idx + 17,
			x.idx + 17,
			x.idx + 17,
			(x.idx / 2),
			(x.idx % 2),
			'FRONT'
		FROM
			slot_type st,
			generate_series(0,7) x(idx)
		WHERE
			slot_type = '10GSFP+Ethernet' and slot_function = 'network';

		--
		-- Management port
		--
		INSERT INTO component_type_slot_tmplt (
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
	END LOOP;
END;
$$ LANGUAGE plpgsql;
