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
			['PowerEdge R730', NULL],
			['PowerEdge R730xd', NULL]
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
			'Y',
			'Y',
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
				'B12'
			]) x(slot)
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
			'PCI-E x8 slot ' || x.idx,
			x.idx
		FROM
			slot_type st,
			generate_series(1,3) x(idx)
		WHERE
			slot_type = 'PCIEx8half' and slot_function = 'PCI';

		INSERT INTO component_type_slot_tmplt (
			component_type_id,
			slot_type_id,
			slot_name_template,
			slot_index
		) SELECT
			ctid,
			slot_type_id,
			'PCI-E x16 slot 4',
			4
		FROM
			slot_type st
		WHERE
			slot_type = 'PCIEx16' and slot_function = 'PCI';

		INSERT INTO component_type_slot_tmplt (
			component_type_id,
			slot_type_id,
			slot_name_template,
			slot_index
		) SELECT
			ctid,
			slot_type_id,
			'PCI-E x8 slot 5',
			5
		FROM
			slot_type st
		WHERE
			slot_type = 'PCIEx8' and slot_function = 'PCI';

		IF (d[1] = 'PowerEdge R720') THEN
			INSERT INTO component_type_slot_tmplt (
				component_type_id,
				slot_type_id,
				slot_name_template,
				slot_index
			) SELECT
				ctid,
				slot_type_id,
				'PCI-E x8 slot ' || x.idx,
				x.idx
			FROM
				slot_type st,
				generate_series(6,7) x(idx)
			WHERE
				slot_type = 'PCIEx8' and slot_function = 'PCI';
		END IF;
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
-- 	INSERT INTO val_slot_physical_interface
-- 		(slot_physical_interface_type, slot_function)
-- 	VALUES ('R720NetworkDaughterConnector', 'PCI');
-- 
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
-- 			('PCIVendorID', 'PCI', ctid, x'8086'::integer),
-- 			('PCIDeviceID', 'PCI', ctid, x'1528'::integer),
-- 			('PCISubsystemVendorID', 'PCI', ctid, x'1028'::integer),
-- 			('PCISubsystemID', 'PCI', ctid, x'1f61'::integer);
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
-- 			'ixgbe' || x.idx,
-- 			x.idx,
-- 			x.idx + 1,
-- 			'BACK'
-- 		FROM
-- 			slot_type st,
-- 			generate_series(0,1) x(idx)
-- 		WHERE
-- 			slot_type = '10GBaseTEthernet' and slot_function = 'network';
-- 
-- --		--
-- --		-- I350 side of the card
-- --		--
-- --		INSERT INTO component_type (
-- --			description,
-- --			slot_type_id,
-- --			company_id,
-- --			asset_permitted,
-- --			is_rack_mountable
-- --		) VALUES (
-- --			'Ethernet 10G 4P X540/I350 rNDC (I350)',
-- --			stid,
-- --			(SELECT company_id FROM jazzhands.company WHERE company_name = 'Dell'),
-- --			'N',
-- --			'N'
-- --		) RETURNING component_type_id INTO ctid;
-- --
-- --		INSERT INTO component_type_component_func (
-- --			component_type_id,
-- --			component_function
-- --		) SELECT
-- --			ctid,
-- --			x.func
-- --		FROM unnest(ARRAY[
-- --			'PCI',
-- --			'network_adapter'
-- --		]) x(func);
-- --
-- --		INSERT INTO component_property (
-- --			component_property_name,
-- --			component_property_type,
-- --			component_type_id,
-- --			property_value
-- --		) VALUES
-- --			('PCIVendorID', 'PCI', ctid, x'8086'::integer),
-- --			('PCIDeviceID', 'PCI', ctid, x'1521'::integer),
-- --			('PCISubsystemVendorID', 'PCI', ctid, x'1028'::integer),
-- --			('PCISubsystemID', 'PCI', ctid, x'1f62'::integer);
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
-- 			'igb' || x.idx,
-- 			x.idx,
-- 			x.idx + 3,
-- 			'BACK'
-- 		FROM
-- 			slot_type st,
-- 			generate_series(0,1) x(idx)
-- 		WHERE
-- 			slot_type = '1000BaseTEthernet' and slot_function = 'network';
-- 	END IF;
-- END;
-- $$ LANGUAGE plpgsql;
