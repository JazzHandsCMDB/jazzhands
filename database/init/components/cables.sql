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
	s		text;
BEGIN
	SELECT company_id INTO cid FROM company WHERE company_name = 'unknown';
	IF NOT FOUND THEN
		SELECT company_manip.add_company(
			_company_name := 'unknown',
			_company_types := ARRAY['hardware provider']
		) INTO cid;
	END IF;

	SELECT component_type_id INTO ctid
	FROM
		component_type
	WHERE
		company_id = cid AND
		model = 'QSFP28-4xSFP28';
	
	IF NOT FOUND THEN

		SELECT slot_type_id INTO stid
		FROM
			slot_type
		WHERE
			slot_function = 'network' AND
			slot_type = '100GQSFP28Ethernet';
		
		IF NOT FOUND THEN
			INSERT INTO slot_type (
				slot_type,
				slot_function,
				slot_physical_interface_type,
				description,
				remote_slot_permitted
			) VALUES (
				'100GQSFP28Ethernet',
				'network',
				'QSFP28',
				'100Gbps QSFP28 Ethernet',
				true
			) RETURNING slot_type_id INTO stid;
		END IF;

		INSERT INTO component_type (
			description,
			slot_type_id,
			model,
			company_id,
			asset_permitted,
			is_rack_mountable
		) VALUES (
			'QSFP28 100GBASE-CR4 to 4xSFP28 25GBASE-CR TwinAx',
			stid,
			'QSFP28-4xSFP28',
			cid,
			true,
			false
		) RETURNING component_type_id INTO ctid;

		PERFORM * FROM val_component_function
		WHERE component_function = 'network_transceiver';

		IF NOT FOUND THEN
			INSERT INTO val_component_function (
				component_function,
				description
			) VALUES (
				'network_transceiver',
				'Network "optic" transceiver'
			);
		END IF;

		INSERT INTO component_type_component_function (
			component_type_id,
			component_function
		) VALUES (
			ctid,
			'network_transceiver'
		);
	END IF;

	--
	-- 100GE ports
	--
	INSERT INTO component_type_slot_template (
		component_type_id,
		slot_type_id,
		slot_name_template,
		slot_index
	) SELECT
		ctid,
		slot_type_id,
		1 + x.idx,
		1 + x.idx
	FROM
		slot_type st,
		generate_series(0,3) x(idx)
	WHERE
		slot_type = '25GSFP28Ethernet' and slot_function = 'network';
END;
$$ LANGUAGE plpgsql;
