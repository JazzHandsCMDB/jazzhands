--
-- Copyright (c) 2025 Matthew Ragan
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
	m		RECORD;
BEGIN
	SELECT company_id INTO cid FROM company WHERE company_name = 'Vertiv';
	IF NOT FOUND THEN
		SELECT company_manip.add_company(
			_company_name := 'Vertiv',
			_company_types := ARRAY['hardware provider']
		) INTO cid;
	END IF;

	FOR m IN
		SELECT model, ports FROM (VALUES
			('ACS8008SAC-400', 8),
			('ACS8008MDAC-400', 8),
			('ACS8016SAC-400', 16),
			('ACS8016DAC-400', 16),
			('ACS8016MDAC-400', 16),
			('ACS8032SAC-400', 32),
			('ACS8032MDAC-400', 32),
			('ACS8048SAC-400', 48),
			('ACS8048DAC-400', 48),
			('ACS8048MDAC-400', 48),
			('ACS8008-LN-DAC-400', 8),
			('ACS8016-LN-DAC-400', 16),
			('ACS8032-LN-DAC-400', 32),
			('ACS8048-LN-DAC-400', 48),
			('ACS8008-NA-DAC-400', 8),
			('ACS8016-NA-DAC-400', 16),
			('ACS8032-NA-DAC-400', 32),
			('ACS8048-NA-DAC-400', 48)
		) AS x(model, ports)
	LOOP
		SELECT component_type_id INTO ctid FROM
			component_type
		WHERE
			company_id = cid AND
			model = m.model;

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
				'Avocent ' || m.model,
				NULL,
				m.model,
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
		END IF;

		--
		-- Console port
		--

		INSERT INTO component_type_slot_template (
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
			slot_type = 'RJ45 serial' and slot_function = 'serial'
		EXCEPT SELECT
			component_type_id,
			slot_type_id,
			slot_name_template,
			slot_index,
			slot_y_offset,
			slot_side
		FROM component_type_slot_template WHERE component_type_id = ctid;

		--
		-- Serial ports
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
			'ttyS' || x.idx + 1,
			(x.idx + 1)::varchar,
			x.idx + 1,
			(x.idx / 2),
			(x.idx % 2),
			'FRONT'
		FROM
			slot_type st,
			generate_series(0,m.ports - 1) x(idx)
		WHERE
			slot_type = 'RJ45 serial' and slot_function = 'serial'
		EXCEPT SELECT
			component_type_id,
			slot_type_id,
			slot_name_template,
			physical_label,
			slot_index,
			slot_x_offset,
			slot_y_offset,
			slot_side
		FROM component_type_slot_template WHERE component_type_id = ctid;


		--
		-- Management ports
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
			'eth0',
			'eth0',
			0,
			'FRONT'
		FROM
			slot_type st
		WHERE
			slot_type = '1000BaseTEthernet' and slot_function = 'network'
		EXCEPT SELECT
			component_type_id,
			slot_type_id,
			slot_name_template,
			physical_label,
			slot_x_offset,
			slot_side
		FROM component_type_slot_template WHERE component_type_id = ctid;

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
			'eth1',
			'eth1',
			0,
			'FRONT'
		FROM
			slot_type st
		WHERE
			slot_type = '1000BaseTEthernet' and slot_function = 'network'
		EXCEPT SELECT
			component_type_id,
			slot_type_id,
			slot_name_template,
			physical_label,
			slot_x_offset,
			slot_side
		FROM component_type_slot_template WHERE component_type_id = ctid;

	END LOOP;
END;
$$ LANGUAGE plpgsql;
