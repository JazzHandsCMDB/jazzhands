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
	cid		integer;
	stid	integer;
	d		text[];
	s		integer;
BEGIN

	SELECT company_id INTO cid FROM company WHERE company_name = 'Dell';
	IF NOT FOUND THEN
		INSERT INTO company (company_name) VALUEs ('Dell')
			RETURNING company_id INTO cid;
	END IF;

	--
	-- Insert the chassis slot type
	--
	INSERT INTO slot_type
		(slot_type, slot_physical_interface_type, slot_function, description,
		 remote_slot_permitted)
	VALUES
		 ('FX2node', 'sled', 'chassis_slot', 'FX2node', 'N')
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
		'Dell FX2 chassis',
		NULL,
		'PowerEdge FX2 chassis',
		cid,
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

	--
	-- Create the chassis slot template
	--
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
		'FRONT'
	FROM
		generate_series(0,7) x(idx);

	FOREACH d SLICE 1 IN ARRAY ARRAY[
			['PowerEdge FC630', '0JXJPT', '12'],
			['PowerEdge FC420', '05FTR3', '3']
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
			stid,
			d[1],
			d[2],
			(SELECT company_id FROM jazzhands.company WHERE company_name = 'Dell'),
			'Y',
			'N',
			2
		) RETURNING component_type_id INTO ctid;

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) VALUES (
			ctid,
			'device'
		);

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
			slot_type = 'Socket LGA2011-3' and slot_function = 'CPU';

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
			'DIMM_' || x.slot || y.slot,
			row_number() over (order by x.slot, y.slot)
		FROM
			slot_type st,
			unnest(ARRAY[
				'A',
				'B'
			]) x(slot),
			generate_series(1,d[3]::integer) y(slot)
		WHERE
			slot_type = 'DDR3 RDIMM' and slot_function = 'memory';

	END LOOP;
END;
$$ LANGUAGE plpgsql;

--
-- Dell integrated Ethernet
--
-- DO $$
-- #variable_conflict use_variable
-- DECLARE
-- 	ctid	integer;
-- 	stid	integer;
-- BEGIN
-- 	INSERT INTO slot_type
-- 		(slot_type, slot_physical_interface_type, slot_function, description,
-- 			remote_slot_permitted)
-- 	VALUES
-- 		('R720NetworkDaughterConnector', 'R720NetworkDaughterConnector',
-- 		 'PCI', 'R720 network daughter card connector', 'N')
-- 	RETURNING
-- 		slot_type_id INTO stid;
-- 
-- 	PERFORM *
-- 	FROM
-- 		component_type ct JOIN
-- 		component_type_component_func cf USING (component_type_id) JOIN
-- 		component_property vid USING (component_type_id) JOIN
-- 		component_property sid USING (component_type_id)
-- 	WHERE
-- 		cf.component_function = 'PCI' AND
-- 		vid.component_property_type = 'PCI' AND
-- 		vid.component_property_name = 'PCISubsystemVendorID' AND
-- 		vid.property_value = (x'1028'::integer)::text AND
-- 		sid.component_property_type = 'PCI' AND
-- 		sid.component_property_name = 'PCISubsystemID' AND
-- 		sid.property_value = (x'1f61'::integer)::text;
-- 
-- 	IF NOT FOUND THEN
-- 		INSERT INTO component_type (
-- 			description,
-- 			slot_type_id,
-- 			company_id,
-- 			asset_permitted,
-- 			is_rack_mountable
-- 		) VALUES (
-- 			'Ethernet 10G 4P X540/I350 rNDC',
-- 			stid,
-- 			(SELECT company_id FROM jazzhands.company WHERE company_name = 'Dell'),
-- 			'N',
-- 			'N'
-- 		) RETURNING component_type_id INTO ctid;
-- 
-- 		INSERT INTO component_type_component_func (
-- 			component_type_id,
-- 			component_function
-- 		) SELECT
-- 			ctid,
-- 			x.func
-- 		FROM unnest(ARRAY[
-- 			'PCI',
-- 			'network_adapter'
-- 		]) x(func);
-- 
-- 		INSERT INTO component_property (
-- 			component_property_name,
-- 			component_property_type,
-- 			component_type_id,
-- 			property_value
-- 		) VALUES
-- 			('PCIVendorID', 'PCI', ctid, x'14e4'::integer),
-- 			('PCIDeviceID', 'PCI', ctid, x'16e8'::integer),
-- 			('PCISubsystemVendorID', 'PCI', ctid, x'1028'::integer),
-- 			('PCISubsystemID', 'PCI', ctid, x'1f5f'::integer);
-- 
-- 		--
-- 		-- Network ports
-- 		--
-- 		INSERT INTO component_type_slot_tmplt (
-- 			component_type_id,
-- 			slot_type_id,
-- 			slot_name_template,
-- 			slot_index,
-- 			slot_x_offset,
-- 			slot_side
-- 		) SELECT
-- 			ctid,
-- 			slot_type_id,
-- 			'bnx2x' || x.idx,
-- 			x.idx,
-- 			x.idx + 1,
-- 			'BACK'
-- 		FROM
-- 			slot_type st,
-- 			generate_series(0,1) x(idx)
-- 		WHERE
-- 			slot_type = '10GSFP+Ethernet' and slot_function = 'network';
-- 	END IF;
-- END;
-- $$ LANGUAGE plpgsql;
