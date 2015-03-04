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
	d		text[];
	s		text;
BEGIN
	SELECT company_id INTO cid FROM company WHERE company_name = 'OpenGear';
	IF NOT FOUND THEN
		INSERT INTO company (company_name) VALUES ('OpenGear') RETURNING
			company_id INTO cid;
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
		'OpenGear IMX4248',
		NULL,
		'IMX4248',
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
		slot_type = 'DB9-M serial' and slot_function = 'serial';

	--
	-- Serial ports
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
		'port' || x.idx + 1,
		x.idx + 1,
		x.idx + 1,
		(x.idx / 2),
		(x.idx % 2),
		'FRONT'
	FROM
		slot_type st,
		generate_series(0,47) x(idx)
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
			'Ethernet' || (x.idx + 49) || '/1',
			49 + x.idx,
			49 + x.idx,
			(x.idx / 2),
			(x.idx % 2),
			'FRONT'
		FROM
			slot_type st,
			generate_series(0,3) x(idx)
		WHERE
			slot_type = '40GQSFP+Ethernet' and slot_function = 'network';

	--
	-- Management ports
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
		'wan',
		'Network1',
		0,
		'FRONT'
	FROM
		slot_type st
	WHERE
		slot_type = '100BaseTEthernet' and slot_function = 'network';

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
		'lan',
		'Network2',
		0,
		'FRONT'
	FROM
		slot_type st
	WHERE
		slot_type = '100BaseTEthernet' and slot_function = 'network';
END;
$$ LANGUAGE plpgsql;
