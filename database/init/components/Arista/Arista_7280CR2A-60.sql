--
-- Copyright (c) 2020 Matthew Ragan
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
	SELECT company_id INTO cid FROM company WHERE company_name = 'Arista Networks';
	IF NOT FOUND THEN
		SELECT company_manip.add_company(
			_company_name := 'Arista Networks',
			_company_types := ARRAY['hardware provider']
		) INTO cid;
	END IF;

	SELECT component_type_id INTO ctid
	FROM
		component_type
	WHERE
		company_id = cid AND
		model = 'DCS-7280CR2A-60';
	
	IF NOT FOUND THEN
		INSERT INTO component_type (
			description,
			slot_type_id,
			model,
			company_id,
			asset_permitted,
			is_rack_mountable,
			size_units
		) VALUES (
			'Arista DCS-7280CR2A-60',
			NULL,
			'DCS-7280CR2A-60',
			cid,
			'Y',
			'Y',
			1
		) RETURNING component_type_id INTO ctid;

		INSERT INTO component_type_component_function (
			component_type_id,
			component_function
		) VALUES (
			ctid,
			'device'
		);
	END IF;

	--
	-- 100GE ports
	--
	INSERT INTO component_type_slot_template (
		component_type_id,
		slot_type_id,
		slot_name_template,
		child_slot_name_template,
		physical_label,
		slot_index,
		slot_x_offset,
		slot_y_offset,
		slot_side
	) SELECT
		ctid,
		slot_type_id,
		'Ethernet' || (x.idx + 1),
		'Ethernet' || (x.idx + 1) || '/%{slot_index}',
		1 + x.idx,
		1 + x.idx,
		(x.idx / 2),
		(x.idx % 2),
		'FRONT'
	FROM
		slot_type st,
		generate_series(0,59) x(idx)
	WHERE
		slot_type = '100GQSFP28Ethernet' and slot_function = 'network';

	--
	-- Management port
	--
	INSERT INTO component_type_slot_template (
		component_type_id,
		slot_type_id,
		slot_name_template,
		physical_label,
		slot_y_offset,
		slot_side
	) SELECT
		ctid,
		slot_type_id,
		'Management1',
		'<●●●>',
		1,
		'FRONT'
	FROM
		slot_type st
	WHERE
		slot_type = '1000BaseTEthernet' and slot_function = 'network';

	--
	-- Console port
	--

	INSERT INTO component_type_slot_template (
		component_type_id,
		slot_type_id,
		slot_name_template,
		physical_label,
		slot_index,
		slot_y_offset,
		slot_side
	) SELECT
		ctid,
		slot_type_id,
		'console',
		'|○|○|',
		0,
		0,
		'FRONT'
	FROM
		slot_type st
	WHERE
		slot_type = 'RJ45 serial' and slot_function = 'serial';

END;
$$ LANGUAGE plpgsql;
