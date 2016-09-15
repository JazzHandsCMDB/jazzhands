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
	stid	integer[];
	d		text[];
	s		text;
BEGIN
	SELECT company_id INTO cid FROM company WHERE company_name = 'Arista';
	IF NOT FOUND THEN
		SELECT company_manip.add_company(
			_company_name := 'Arista',
			_company_types := ARRAY['hardware provider']
		) INTO cid;
	END IF;

--
-- Arista 7500 Chassis
--

	PERFORM * FROM val_slot_physical_interface WHERE
		slot_physical_interface_type = 'Arista 75XX Supervisor' AND
		slot_function = 'chassis_slot';
	
	IF NOT FOUND THEN
		INSERT INTO val_slot_physical_interface
			(slot_physical_interface_type, slot_function)
		VALUES
			('Arista 75XX Supervisor', 'chassis_slot'),
			('Arista 75XX Linecard', 'chassis_slot');

		WITH z AS (
			INSERT INTO slot_type 
				(slot_type, slot_physical_interface_type, slot_function,
				 description, remote_slot_permitted)
			VALUES
				('Arista 75XX Supervisor', 'Arista 75XX Supervisor',
				 'chassis_slot', 'Arista 75XX Supervisor', 'N'),
				('Arista 75XX Linecard', 'Arista 75XX Linecard',
				 'chassis_slot', 'Arista 75XX Linecard', 'N')
			RETURNING slot_type_id 
		) SELECT array_agg(slot_type_id) FROM z INTO stid;

		INSERT INTO slot_type_prmt_comp_slot_type (
			slot_type_id,
			component_slot_type_id
		) SELECT
			x.stid,
			x.stid
		FROM
			unnest(stid) AS x(stid);
		
		FOREACH d SLICE 1 IN ARRAY ARRAY[
				['7504E', '4'],
				['7508E', '8']
				] LOOP
			INSERT INTO component_type (
				description,
				slot_type_id,
				model,
				company_id,
				asset_permitted,
				is_rack_mountable,
				size_units
			) VALUES (
				'Arista DCS-' || d[1],
				NULL,
				'DCS-' || d[1],
				cid,
				'Y',
				'Y',
				3 + d[2]::integer
			) RETURNING component_type_id INTO ctid;

			--
			-- Supervisor slots
			--

			INSERT INTO component_type_slot_tmplt (
				component_type_id,
				slot_type_id,
				slot_name_template,
				slot_index,
				slot_y_offset,
				slot_x_offset,
				slot_side
			) SELECT
				ctid,
				stid[1],
				'Supervisor' || x.idx,
				x.idx,
				0,
				x.idx,
				'FRONT'
			FROM
				generate_series(1,2) x(idx);

			--
			-- Linecard slots
			--

			INSERT INTO component_type_slot_tmplt (
				component_type_id,
				slot_type_id,
				slot_name_template,
				slot_index,
				slot_y_offset,
				slot_x_offset,
				slot_side
			) SELECT
				ctid,
				stid[2],
				'Linecard' || x.idx,
				x.idx,
				0,
				x.idx,
				'FRONT'
			FROM
				generate_series(3, 2 + d[2]::integer) x(idx);
		END LOOP;
		
		--
		-- Supervisor modules
		--

		INSERT INTO component_type (
			description,
			slot_type_id,
			model,
			company_id,
			asset_permitted,
			is_rack_mountable
		) VALUES (
			'Arista DCS-7500E-SUP',
			NULL,
			'DCS-7500E-SUP',
			cid,
			'Y',
			'N'
		) RETURNING component_type_id INTO ctid;

		--
		-- Console ports
		--

		INSERT INTO component_type_slot_tmplt (
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
			'|O|O|',
			0,
			0,
			'FRONT'
		FROM
			slot_type st
		WHERE
			slot_type = 'RJ45 serial' and slot_function = 'serial';

		--
		-- Management ports
		--
		INSERT INTO component_type_slot_tmplt (
			component_type_id,
			slot_type_id,
			slot_name_template,
			physical_label,
			slot_y_offset,
			slot_x_offset,
			slot_index,
			slot_side
		) SELECT
			ctid,
			slot_type_id,
			'Management%{parent_slot_index}/' || x.idx,
			'<•••> ' || x.idx,
			0,
			x.idx,
			x.idx,
			'FRONT'
		FROM
			slot_type st,
			generate_series(1,2) as x(idx)
		WHERE
			slot_type = '1000BaseTEthernet' and slot_function = 'network';


		--
		-- Line cards
		--

		--
		-- 7500E-48S
		--

		INSERT INTO component_type (
			description,
			slot_type_id,
			model,
			company_id,
			asset_permitted,
			is_rack_mountable
		) VALUES (
			'Arista 7500E-48S',
			NULL,
			'7500E-48S-LC',
			cid,
			'Y',
			'N'
		) RETURNING component_type_id INTO ctid;

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
			'Ethernet%{parent_slot_index}/' || x.idx,
			x.idx + 1,
			x.idx + 1,
			(x.idx / 2),
			(x.idx % 2),
			'FRONT'
		FROM
			slot_type st,
			generate_series(0,47) as x(idx)
		WHERE
			slot_type = '10GSFP+Ethernet' and slot_function = 'network';

		--
		-- 7500E-36Q
		--

		INSERT INTO component_type (
			description,
			slot_type_id,
			model,
			company_id,
			asset_permitted,
			is_rack_mountable
		) VALUES (
			'Arista 7500E-36Q',
			NULL,
			'7500E-36Q-LC',
			cid,
			'Y',
			'N'
		) RETURNING component_type_id INTO ctid;

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
			'Ethernet%{parent_slot_index}/' || x.idx || '/1',
			x.idx + 1,
			x.idx + 1,
			(x.idx / 2),
			(x.idx % 2),
			'FRONT'
		FROM
			slot_type st,
			generate_series(0,35) as x(idx)
		WHERE
			slot_type = '40GQSFP+Ethernet' and slot_function = 'network';

	END IF;
END;
$$ LANGUAGE plpgsql;
