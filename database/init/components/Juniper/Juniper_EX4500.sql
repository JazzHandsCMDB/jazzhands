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
-- EX4200 stack
--
DO $$
#variable_conflict use_variable
DECLARE
	cid			integer;
	vcp_stid	integer;
	stack_stid	integer;
	ctid		integer;
	stid		integer;
BEGIN
	SELECT company_id INTO cid FROM jazzhands.company WHERE
		company_name = 'Juniper Networks';

	IF NOT FOUND THEN
		SELECT company_manip.add_company(
			company_name := 'Junipero Networks',
			company_types := ARRAY['hardware provider']
		) INTO cid;
	END IF;

	SELECT slot_type_id INTO vcp_stid FROM slot_type WHERE
		slot_type = 'Juniper EX VCP' AND
		slot_function = 'inter_component_link';

	SELECT  slot_type_id INTO stack_stid FROM slot_type WHERE
		slot_type = 'JuniperEXStack' AND
		slot_function = 'chassis_slot';

	INSERT INTO component_type (
		description,
		slot_type_id,
		model,
		company_id,
		asset_permitted,
		is_rack_mountable,
		size_units
	) VALUES (
		'Juniper EX4500-40F',
		stack_stid,
		'EX4500-40F',
		cid,
		true,
		true,
		1
	) RETURNING component_type_id INTO ctid;

	INSERT INTO component_type_component_function (
		component_type_id,
		component_function
	) VALUES (
		ctid,
		'device'
	);

	--
	-- Console port
	--

	INSERT INTO component_type_slot_template (
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
	INSERT INTO component_type_slot_template (
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
		generate_series(0,39) x(idx)
	WHERE
		slot_type = '10GSFP+Ethernet' and slot_function = 'network';

	--
	-- Management port
	--
	INSERT INTO component_type_slot_template (
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
		'FRONT'
	FROM
		slot_type st
	WHERE
		slot_type = '1000BaseTEthernet' and slot_function = 'network';

	--
	-- Management port
	--
	INSERT INTO component_type_slot_template (
		component_type_id,
		slot_type_id,
		slot_name_template,
		physical_label,
		slot_x_offset,
		slot_side
	) SELECT 
		ctid,
		vcp_stid,
		'VCP-' || x.idx,
		'VCP-' || x.idx,
		x.idx,
		'FRONT'
	FROM
		generate_series(0,1) x(idx);

END;
$$ LANGUAGE plpgsql;
