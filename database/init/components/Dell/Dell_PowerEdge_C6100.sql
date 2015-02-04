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
	s		integer;
BEGIN
	SELECT company_id INTO cid FROM company WHERE company_name = 'Dell';
	IF NOT FOUND THEN
		INSERT INTO company (company_name) VALUEs ('Dell')
			RETURNING company_id INTO cid;
	END IF;

	INSERT INTO slot_type
		(slot_type, slot_physical_interface_type, slot_function, description,
		 remote_slot_permitted)
	 VALUES
		 ('C6100node', 'sled', 'chassis_slot', 'C6100 node', 'N')
	 RETURNING slot_type_id INTO stid;

	INSERT INTO component_type (
		description,
		slot_type_id,
		model,
		company_id,
		asset_permitted,
		is_rack_mountable,
		size_units
	) VALUES (
		'Dell C6100 chassis',
		NULL,
		'PowerEdge C6100 chassis',
		(SELECT company_id FROM jazzhands.company WHERE company_name = 'Dell'),
		'Y',
		'Y',
		2
	) RETURNING component_type_id INTO ctid;

	INSERT INTO component_type_component_func (
		component_type_id,
		component_function
	) VALUES (
		ctid,
		'chassis'
	);

	INSERT INTO component_type_slot_tmplt (
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

	INSERT INTO component_type (
		description,
		slot_type_id,
		model,
		company_id,
		asset_permitted,
		is_rack_mountable,
		size_units
	) VALUES (
		'PowerEdge C6100',
		stid,
		'C6100',
		cid,
		'Y',
		'N',
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
	-- Network ports
	--
	INSERT INTO component_type_slot_tmplt (
		component_type_id,
		slot_type_id,
		slot_name_template,
		slot_index,
		slot_x_offset
	) SELECT
		ctid,
		slot_type_id,
		'igb' || x.idx,
		x.idx,
		x.idx + 1
	FROM
		slot_type st,
		generate_series(0,1) x(idx)
	WHERE
		slot_type = '1000BaseTEthernet' and slot_function = 'network';

	--
	-- CPU sockets
	--
	INSERT INTO component_type_slot_tmplt (
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
		slot_type = 'Socket LGA1366' and slot_function = 'CPU';

	--
	-- memory slots
	--
	INSERT INTO component_type_slot_tmplt (
		component_type_id,
		slot_type_id,
		slot_name_template,
		slot_index
	) SELECT
		ctid,
		slot_type_id,
		'DIMM' || to_char(x.slot, 'FM09'),
		x.slot
	FROM
		slot_type st,
		generate_series(1,12) x(slot)
	WHERE
		slot_type = 'DDR3 RDIMM' and slot_function = 'memory';

	--
	-- PCI slots
	--
	INSERT INTO component_type_slot_tmplt (
		component_type_id,
		slot_type_id,
		slot_name_template,
		slot_index
	) SELECT
		ctid,
		slot_type_id,
		'PCI-E x16 slot 1',
		4
	FROM
		slot_type st
	WHERE
		slot_type = 'PCIEx16' and slot_function = 'PCI';

-- 	INSERT INTO component_type_slot_tmplt (
-- 		component_type_id,
-- 		slot_type_id,
-- 		slot_name_template,
-- 		slot_index
-- 	) SELECT
-- 		ctid,
-- 		slot_type_id,
-- 		'PCI-E x8 mezzanine',
-- 		x'82'::int
-- 	FROM
-- 		slot_type st
-- 	WHERE
-- 		slot_type = 'PCIEx8half' and slot_function = 'PCI';
END;
$$ LANGUAGE plpgsql;
