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

--
-- Juniper EX2200
--
DO $$
#variable_conflict use_variable
DECLARE
	cid		integer;
	ctid	integer;
	stid	integer;
	m		text[];
BEGIN

	SELECT company_id INTO cid FROM jazzhands.company WHERE
		company_name = 'Juniper';

	IF NOT FOUND THEN
		INSERT INTO company (
			company_name
		) VALUES (
			'Juniper'
		) RETURNING company_id INTO cid;
	END IF;

	FOREACH m SLICE 1 IN ARRAY ARRAY [
			['T', '750-026325'],
			['P', '750-026331']
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
			'Juniper EX2200-48' || m[1] || '-4G',
			stid,
			'EX2200-48' || m[1] ||'-4G',
			m[2],
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
			physical_label,
			slot_index,
			slot_x_offset,
			slot_side
		) SELECT
			ctid,
			slot_type_id,
			'console',
			'CON',
			0,
			0,
			'BACK'
		FROM
			slot_type st
		WHERE
			slot_type = 'RJ45 serial' and slot_function = 'serial';

		--
		-- Network ports
		--
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
			'ge-%{parent_slot_index}/0/' || x.idx,
			x.idx,
			x.idx,
			(x.idx / 2),
			(x.idx % 2),
			'FRONT'
		FROM
			slot_type st,
			generate_series(0,47) x(idx)
		WHERE
			slot_type = '1000BaseTEthernet' and slot_function = 'network';

		INSERT INTO component_type_slot_tmplt (
			component_type_id,
			slot_type_id,
			slot_name_template,
			physical_label,
			slot_index,
			slot_x_offset,
			slot_side
		) SELECT
			ctid,
			slot_type_id,
			'ge-%{parent_slot_index}/1/' || x.idx,
			x.idx,
			x.idx,
			x.idx,
			'FRONT'
		FROM
			slot_type st,
			generate_series(0,3) x(idx)
		WHERE
			slot_type = '1GSFPEthernet' and slot_function = 'network';

		--
		-- Management port
		--
		INSERT INTO component_type_slot_tmplt (
			component_type_id,
			slot_type_id,
			slot_name_template,
			physical_label,
			slot_x_offset,
			slot_side
		) SELECT
			ctid,
			slot_type_id,
			'vme',
			'MGMT',
			1,
			'BACK'
		FROM
			slot_type st
		WHERE
			slot_type = '1000BaseTEthernet' and slot_function = 'network';
	END LOOP;
END;
$$ LANGUAGE plpgsql;
