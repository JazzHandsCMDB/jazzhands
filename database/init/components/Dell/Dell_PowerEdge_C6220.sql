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
	INSERT INTO slot_type
		(slot_type, slot_physical_interface_type, slot_function, description,
		 remote_slot_permitted)
	 VALUES
		 ('C6220node', 'sled', 'chassis_slot', 'C6220 node', 'N');

	INSERT INTO component_type (
		description,
		slot_type_id,
		model,
		company_id,
		asset_permitted,
		is_rack_mountable,
		size_units
	) VALUES (
		'Dell C6220 chassis',
		NULL,
		'PowerEdge C6220 chassis',
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

	SELECT slot_type_id INTO stid FROM slot_type WHERE
		slot_type = 'C6220node' and slot_function = 'chassis_slot';

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

	FOREACH d SLICE 1 IN ARRAY ARRAY[
			['PowerEdge C6220', '0TTH1R'],
			['PowerEdge C6220 II', '09N44V']
			] LOOP
		FOREACH s IN ARRAY ARRAY[1, 2] LOOP
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
				d[1] || ' ' || s || 'U',
				stid,
				d[1] || ' ' || s || 'U',
				d[2],
				(SELECT company_id FROM jazzhands.company WHERE company_name = 'Dell'),
				'Y',
				'N',
				s	
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
				slot_type = 'Socket LGA2011' and slot_function = 'CPU';

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
					'B1',
					'B2',
					'B3',
					'B4',
					'B5',
					'B6',
					'B7',
					'B8'
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
				'PCI-E x16 slot ' || x.idx,
				x.idx + 2
			FROM
				slot_type st,
				generate_series(1,s) x(idx)
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
				'PCI-E x8 slot 3',
				x'82'::int
			FROM
				slot_type st
			WHERE
				slot_type = 'PCIEx8half' and slot_function = 'PCI';
		END LOOP;
	END LOOP;
END;
$$ LANGUAGE plpgsql;

--
-- Inventec 10GE mezzanine card
--
DO $$
#variable_conflict use_variable
DECLARE
	ctid	integer;
	stid	integer;
BEGIN
	PERFORM *
	FROM
		component_type ct JOIN
		component_type_component_func cf USING (component_type_id) JOIN
		component_property vid USING (component_type_id) JOIN
		component_property sid USING (component_type_id)
	WHERE
		cf.component_function = 'PCI' AND
		vid.component_property_type = 'PCI' AND
		vid.component_property_name = 'PCISubsystemVendorID' AND
		vid.property_value = (x'1170'::integer)::text AND
		sid.component_property_type = 'PCI' AND
		sid.component_property_name = 'PCISubsystemID' AND
		sid.property_value = (x'004c'::integer)::text;

	IF NOT FOUND THEN
		SELECT slot_type_id INTO stid FROM slot_type WHERE
			slot_type = 'PCI8xhalf' and slot_function = 'PCI';

		INSERT INTO component_type (
			description,
			slot_type_id,
			company_id,
			asset_permitted,
			is_rack_mountable
		) VALUES (
			'Inventec Intel 82599ES 10-Gigabit SFI/SFP+ Network Connection',
			stid,
			(SELECT company_id FROM jazzhands.company WHERE company_name = 'Inventec Corp'),
			'Y',
			'N'
		) RETURNING component_type_id INTO ctid;

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT
			ctid,
			x.func
		FROM unnest(ARRAY[
			'PCI',
			'network_adapter'
		]) x(func);

		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES
			('PCIVendorID', 'PCI', ctid, x'8086'::integer),
			('PCIDeviceID', 'PCI', ctid, x'10fb'::integer),
			('PCISubsystemVendorID', 'PCI', ctid, x'1170'::integer),
			('PCISubsystemID', 'PCI', ctid, x'004c'::integer);

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
			'ixgbe' || x.idx,
			x.idx,
			x.idx + 1
		FROM
			slot_type st,
			generate_series(0,1) x(idx)
		WHERE
			slot_type = '10GSFP+Ethernet' and slot_function = 'network';

	END IF;
END;
$$ LANGUAGE plpgsql;
