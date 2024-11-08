-- Copyright (c) 2024, Matthew Ragan
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

DO $$
#variable_conflict use_variable
DECLARE
	cid			integer;
	ctid		integer;
	ctrec		RECORD;
	stid		integer[];
	d			text[];
	s			text;
	card		RECORD;
	chassisdef	jsonb;
	p			jsonb;
    port_offset	integer;
    x_offset	integer;
BEGIN
	SELECT company_id INTO cid FROM company WHERE company_name = 'Arista Networks';
	IF NOT FOUND THEN
		SELECT company_manip.add_company(
			company_name := 'Arista Networks',
			company_types := ARRAY['hardware provider']
		) INTO cid;
	END IF;

--
-- Arista 7500 Chassis
--

	WITH x AS (
		INSERT INTO val_slot_physical_interface
			(slot_physical_interface_type, slot_function)
		SELECT
			spit, 'chassis_slot'
		FROM
			unnest(ARRAY['Arista 7500E Supervisor', 'Arista 7500E Linecard'])
			AS x(spit)
		EXCEPT SELECT
			slot_physical_interface_type,
			slot_function
		FROM
			val_slot_physical_interface
		RETURNING
			slot_physical_interface_type
	), y AS (
		INSERT INTO slot_type (
			slot_type,
			slot_physical_interface_type,
			slot_function,
			description,
			remote_slot_permitted
		) SELECT
			slot_physical_interface_type,
			slot_physical_interface_type,
			'chassis_slot',
			slot_physical_interface_type,
			false
		FROM
			x
		RETURNING slot_type_id
	) INSERT INTO slot_type_permitted_component_slot_type (
		slot_type_id,
		component_slot_type_id
	) SELECT
		y.slot_type_id,
		y.slot_type_id
	FROM
		y;
		
	FOREACH chassisdef IN ARRAY ARRAY[
		'{ "model": "DCS-7504", "slots": 4, "rack_units": 7 }',
		'{ "model": "DCS-7508", "slots": 8, "rack_units": 10 }'
	]::jsonb[] LOOP
		RAISE NOTICE 'model: %, slots: %, rack_units: %',
			chassisdef->>'model',
			chassisdef->>'slots',
			chassisdef->>'rack_units';
		
		INSERT INTO component_type (
			description,
			slot_type_id,
			model,
			company_id,
			asset_permitted,
			is_rack_mountable,
			size_units
		) VALUES (
			'Arista ' || (chassisdef->>'model'),
			NULL,
			chassisdef->>'model',
			cid,
			true,
			true,
			(chassisdef->>'rack_units')::integer
		) RETURNING component_type_id INTO ctid;

		INSERT INTO component_type_component_function (
			component_type_id,
			component_function
		) VALUES (
			ctid,
			'device'
		);

		--
		-- Insert device type
		--
		INSERT INTO device_type (
			component_type_id,
			device_type_name,
			description,
			company_id,
			config_fetch_type,
			rack_units
		) VALUES (
			ctid,
			chassisdef->>'model',
			'Arista ' || (chassisdef->>'model'),
			cid,
			'arista',
			(chassisdef->>'rack_units')::integer
		);

		--
		-- Supervisor slot
		--

		INSERT INTO component_type_slot_template (
			component_type_id,
			slot_type_id,
			slot_name_template,
			slot_index,
			slot_y_offset,
			slot_x_offset,
			slot_side
		) SELECT
			ctid,
			slot_type_id,
			'Supervisor' || x.idx + 1,
			x.idx + 1,
			0,
			x.idx + 1,
			'FRONT'
		FROM
			slot_type st,
			generate_series(0, 1) AS x(idx)
		WHERE
			slot_type = 'Arista 7500E Supervisor' AND
			slot_function = 'chassis_slot';

		--
		-- Linecard slots
		--

		INSERT INTO component_type_slot_template (
			component_type_id,
			slot_type_id,
			slot_name_template,
			child_slot_name_template,
			slot_index,
			slot_y_offset,
			slot_x_offset,
			slot_side
		) SELECT
			ctid,
			slot_type_id,
			'Linecard' || x.idx,
			'Ethernet' || x.idx || '/%{slot_index}',
			x.idx,
			0,
			x.idx,
			'FRONT'
		FROM
			slot_type st,
			generate_series(3, 2 + (chassisdef->>'slots')::integer) x(idx)
		WHERE
			slot_type = 'Arista 7500E Linecard' AND
            slot_function = 'chassis_slot';
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
	) SELECT
		'Arista DCS-7500E-SUP',
		slot_type_id,
		'DCS-7500E-SUP',
		cid,
		true,
		false
	FROM
		slot_type
	WHERE
		slot_type = 'Arista 7500E Supervisor' AND
		slot_function = 'chassis_slot'
	RETURNING component_type_id INTO ctid;

	--
	-- Console ports
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
		'console%{parent_slot_index}',
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
	INSERT INTO component_type_slot_template (
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
		'Management%{parent_slot_index}',
		'<•••>',
		0,
		1,
		1,
		'FRONT'
	FROM
		slot_type st
	WHERE
		slot_type = '1000BaseTEthernet' and slot_function = 'network';

	--
	-- Line cards
	--

	FOR card IN SELECT * FROM (VALUES
		(
			'7500E-48S-LC',
			'7500E-48S-LC 48xSFP+',
			'[
				{ "slot_type": "10GSFP+Ethernet", "count": 48, "rows": 2 }
			]'::jsonb
		),

		(
			'7500E-72S-LC',
			'7500E-72S-LC 48xSFP+ 2xMXP',
			'[
				{ "slot_type": "10GSFP+Ethernet", "count": 48, "rows": 2 },
				{ "slot_type": "100GMXPEthernet", "count": 2, "rows": 1 }
			]'::jsonb
		),
		(
			'7500E-36Q-LC',
			'7500E-36Q-LC 36xQSFP+',
			'[
				{ "slot_type": "40GQSFP+Ethernet", "count": 36, "rows": 2 }
			]'::jsonb
		),
		(
			'7500E-12CM-LC',
			'7500E-12CM-LC 12xMXP',
			'[
				{ "slot_type": "100GMXPEthernet", "count": 12, "rows": 1 }
			]'::jsonb
		),
		(
			'7500E-6C2-LC',
			'7500E-6C2-LC 6xCFP2',
			'[
				{ "slot_type": "100GCFP2Ethernet", "count": 6, "rows": 1 }
			]'::jsonb
		),
		(
			'7500E-12CQ-LC',
			'7500E-12CQ-LC 6xCFP2',
			'[
				{ "slot_type": "100GQSFP28Ethernet", "count": 12, "rows": 1 }
			]'::jsonb
		),
		(
			'7500E-48T-LC',
			'7500E-48T-LC 48xSFP+',
			'[
				{ "slot_type": "10GSFP+Ethernet", "count": 48, "rows": 2 }
			]'::jsonb
		)
	)
	AS s(model, description, ports)
	LOOP
	    SELECT * INTO ctrec FROM component_type ct WHERE
        company_id = cid AND
        ct.model = card.model;

		IF FOUND THEN
			RAISE NOTICE 'Card type for model % already exists as component_type_id %',
				card.model,
				ctrec.component_type_id
			CONTINUE;
		END IF;

		INSERT INTO component_type (
			description,
			slot_type_id,
			model,
			company_id,
			asset_permitted,
			is_rack_mountable,
			size_units
		) SELECT
			card.description,
			slot_type_id,
			card.model,
			cid,
			true,
			false,
			0
		FROM
			slot_type
		WHERE
			slot_type = 'Arista 7500E Linecard' AND
			slot_function = 'chassis_slot'
		RETURNING * INTO ctrec;

		ctid = ctrec.component_type_id;

		INSERT INTO component_type_component_function (
			component_type_id,
			component_function
		) VALUES (
			ctid,
			'module'
		);
		--
		-- Switch ports
		--
		port_offset = 0;
		x_offset = 0;

		FOR p IN SELECT jsonb_array_elements(card.ports) LOOP
			INSERT INTO component_type_slot_template (
				component_type_id,
				slot_type_id,
				slot_name_template,
				physical_label,
				slot_index,
				slot_x_offset,
				slot_y_offset
			) SELECT
				ctid,
				slot_type_id,
				'Ethernet${parent_slot_index}/' || (port_offset + x.idx + 1),
				port_offset + x.idx + 1,
				port_offset + x.idx + 1,
				x_offset + (
					(x.idx / 2) % (
						GREATEST((p->>'count')::integer,
							2 * (p->>'rows')::integer) /
						(p->>'rows')::integer
					)
				),
				(x.idx % 2) + 2 * (
					x.idx / ((p->>'count')::integer / (p->>'rows')::integer)
				)
			FROM
				slot_type st,
				generate_series(0,(p->>'count')::integer - 1) x(idx)
			WHERE
				slot_type = p->>'slot_type' and slot_function = 'network';

			port_offset = port_offset + (p->>'count')::integer;
			x_offset = x_offset +
				(p->>'count')::integer / (p->>'rows')::integer;
		END LOOP;	
	END LOOP;

	--
	-- Arista 7500N Chassis
	--

	WITH x AS (
		INSERT INTO val_slot_physical_interface
			(slot_physical_interface_type, slot_function)
		SELECT
			spit, 'chassis_slot'
		FROM
			unnest(ARRAY['Arista 7500R Supervisor', 'Arista 7500R Linecard'])
			AS x(spit)
		EXCEPT SELECT
			slot_physical_interface_type,
			slot_function
		FROM
			val_slot_physical_interface
		RETURNING
			slot_physical_interface_type
	), y AS (
		INSERT INTO slot_type (
			slot_type,
			slot_physical_interface_type,
			slot_function,
			description,
			remote_slot_permitted
		) SELECT
			slot_physical_interface_type,
			slot_physical_interface_type,
			'chassis_slot',
			slot_physical_interface_type,
			false
		FROM
			x
		RETURNING slot_type_id
	) INSERT INTO slot_type_permitted_component_slot_type (
		slot_type_id,
		component_slot_type_id
	) SELECT
		y.slot_type_id,
		y.slot_type_id
	FROM
		y;
		
	INSERT INTO slot_type_permitted_component_slot_type (
		slot_type_id,
		component_slot_type_id
	) SELECT
		s1.slot_type_id,
		s2.slot_type_id
	FROM
		slot_type s1,
		slot_type s2
	WHERE
		s1.slot_type = 'Arista 7500R Linecard' AND
		s1.slot_function = 'chassis_slot' AND
		s2.slot_type = 'Arista 7500E Linecard' AND
		s2.slot_function = 'chassis_slot'
	EXCEPT SELECT
		slot_type_id,
		component_slot_type_id
	FROM
		slot_type_permitted_component_slot_type;
		
	FOREACH chassisdef IN ARRAY ARRAY[
		'{ "model": "DCS-7504N", "slots": 4, "rack_units": 7 }',
		'{ "model": "DCS-7508N", "slots": 8, "rack_units": 13 }',
		'{ "model": "DCS-7512N", "slots": 12, "rack_units": 18 }',
		'{ "model": "DCS-7516N", "slots": 16, "rack_units": 29 }'
	]::jsonb[] LOOP
		RAISE NOTICE 'model: %, slots: %, rack_units: %',
			chassisdef->>'model',
			chassisdef->>'slots',
			chassisdef->>'rack_units';
		
		INSERT INTO component_type (
			description,
			slot_type_id,
			model,
			company_id,
			asset_permitted,
			is_rack_mountable,
			size_units
		) VALUES (
			'Arista ' || (chassisdef->>'model'),
			NULL,
			chassisdef->>'model',
			cid,
			true,
			true,
			(chassisdef->>'rack_units')::integer
		) RETURNING component_type_id INTO ctid;

		INSERT INTO component_type_component_function (
			component_type_id,
			component_function
		) VALUES (
			ctid,
			'device'
		);

		--
		-- Insert device type
		--
		INSERT INTO device_type (
			component_type_id,
			device_type_name,
			description,
			company_id,
			config_fetch_type,
			rack_units
		) VALUES (
			ctid,
			chassisdef->>'model',
			'Arista ' || (chassisdef->>'model'),
			cid,
			'arista',
			(chassisdef->>'rack_units')::integer
		);

		--
		-- Supervisor slot
		--

		INSERT INTO component_type_slot_template (
			component_type_id,
			slot_type_id,
			slot_name_template,
			slot_index,
			slot_y_offset,
			slot_x_offset,
			slot_side
		) SELECT
			ctid,
			slot_type_id,
			'Supervisor' || x.idx + 1,
			x.idx + 1,
			0,
			x.idx + 1,
			'FRONT'
		FROM
			slot_type st,
			generate_series(0, 1) AS x(idx)
		WHERE
			slot_type = 'Arista 7500R Supervisor' AND
			slot_function = 'chassis_slot';

		--
		-- Linecard slots
		--

		INSERT INTO component_type_slot_template (
			component_type_id,
			slot_type_id,
			slot_name_template,
			child_slot_name_template,
			slot_index,
			slot_y_offset,
			slot_x_offset,
			slot_side
		) SELECT
			ctid,
			slot_type_id,
			'Linecard' || x.idx,
			'Ethernet' || x.idx || '/%{slot_index}',
			x.idx,
			0,
			x.idx,
			'FRONT'
		FROM
			slot_type st,
			generate_series(3, 2 + (chassisdef->>'slots')::integer) x(idx)
		WHERE
			slot_type = 'Arista 7500R Linecard' AND
            slot_function = 'chassis_slot';
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
	) SELECT
		'Arista DCS-7500-SUP2',
		slot_type_id,
		'DCS-7500-SUP2',
		cid,
		true,
		false
	FROM
		slot_type
	WHERE
		slot_type = 'Arista 7500R Supervisor' AND
		slot_function = 'chassis_slot'
	RETURNING component_type_id INTO ctid;

	--
	-- Console ports
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
		'console%{parent_slot_index}',
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
	INSERT INTO component_type_slot_template (
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
		'Management%{parent_slot_index}',
		'<•••>',
		0,
		1,
		1,
		'FRONT'
	FROM
		slot_type st
	WHERE
		slot_type = '1000BaseTEthernet' and slot_function = 'network';

	--
	-- Line cards
	--

	FOR card IN SELECT * FROM (VALUES
		(
			'7500R-48S2CQ-LC',
			'7500R-48S2CQ-LC 48xSFP+ 2xQSFP28',
			'[
				{ "slot_type": "10GSFP+Ethernet", "count": 24, "rows": 2 },
				{ "slot_type": "100GQSFP28Ethernet", "count": 2, "rows": 2 },
				{ "slot_type": "10GSFP+Ethernet", "count": 24, "rows": 2 }
			]'::jsonb
		),

		(
			'7500R-36CQ-LC',
			'7500R-36CQ-LC 36xQSFP28',
			'[
				{ "slot_type": "100GQSFP28Ethernet", "count": 36, "rows": 2 }
			]'::jsonb
		),
		(
			'7500R-36Q-LC',
			'7500R-36Q-LC 36xQSFP+',
			'[
				{ "slot_type": "40GQSFP+Ethernet", "count": 36, "rows": 2 }
			]'::jsonb
		),
		(
			'7500RM-36CQ-LC',
			'7500RM-36CQ-LC 36xQSFP28 + MACsec',
			'[
				{ "slot_type": "100GQSFP28Ethernet", "count": 36, "rows": 2 }
			]'::jsonb
		),
		(
			'7500R2-18CQ-LC',
			'7500R2-18CQ-LC 18xQSFP28',
			'[
				{ "slot_type": "100GQSFP28Ethernet", "count": 18, "rows": 2 }
			]'::jsonb
		),
		(
			'7500R2-36CQ-LC',
			'7500R2-36CQ-LC 36xQSFP28',
			'[
				{ "slot_type": "100GQSFP28Ethernet", "count": 36, "rows": 2 }
			]'::jsonb
		),
		(
			'7500R2A-36CQ-LC',
			'7500R2A-36CQ-LC 36xQSFP28',
			'[
				{ "slot_type": "100GQSFP28Ethernet", "count": 36, "rows": 2 }
			]'::jsonb
		),
		(
			'7500R2M-36CQ-LC',
			'7500R2M-36CQ-LC 36xQSFP28',
			'[
				{ "slot_type": "100GQSFP28Ethernet", "count": 36, "rows": 2 }
			]'::jsonb
		),
		(
			'7500R2AM-36CQ-LC',
			'7500R2AM-36CQ-LC 36xQSFP28',
			'[
				{ "slot_type": "100GQSFP28Ethernet", "count": 36, "rows": 2 }
			]'::jsonb
		),
		(
			'7500R2AK-36CQ-LC',
			'7500R2AK-36CQ-LC 36xQSFP28',
			'[
				{ "slot_type": "100GQSFP28Ethernet", "count": 36, "rows": 2 }
			]'::jsonb
		),
		(
			'7500R-8CFPX-LC',
			'7500R-8CFPX-LC 8xCFP2',
			'[
				{ "slot_type": "100GCFP2Ethernet", "count": 8, "rows": 1 }
			]'::jsonb
		),

		(
			'7500R3-36CQ-LC',
			'7500R3-36CQ-LC 36xQSFP28',
			'[
				{ "slot_type": "100GQSFP28Ethernet", "count": 36, "rows": 2 }
			]'::jsonb
		),

		(
			'7500R3-24P-LC',
			'7500R3-24P-LC 24xOSFP',
			'[
				{ "slot_type": "400GOSFPEthernet", "count": 24, "rows": 2 }
			]'::jsonb
		),
		(
			'7500R2AK-48YCQ-LC',
			'7500R2AK-48YCQ-LC 36xQSFP28',
			'[
				{ "slot_type": "25GSFP28Ethernet", "count": 24, "rows": 2 },
				{ "slot_type": "100GQSFP28Ethernet", "count": 2, "rows": 2 },
				{ "slot_type": "25GSFP28Ethernet", "count": 24, "rows": 2 }
			]'::jsonb
		)
	)
	AS s(model, description, ports)
	LOOP
	    SELECT * INTO ctrec FROM component_type ct WHERE
        company_id = cid AND
        ct.model = card.model;

		IF FOUND THEN
			RAISE NOTICE 'Card type for model % already exists as component_type_id %',
				card.model,
				ctrec.component_type_id
			CONTINUE;
		END IF;

		INSERT INTO component_type (
			description,
			slot_type_id,
			model,
			company_id,
			asset_permitted,
			is_rack_mountable,
			size_units
		) SELECT
			card.description,
			slot_type_id,
			card.model,
			cid,
			true,
			false,
			0
		FROM
			slot_type
		WHERE
			slot_type = 'Arista 7500R Linecard' AND
			slot_function = 'chassis_slot'
		RETURNING * INTO ctrec;

		ctid = ctrec.component_type_id;

		INSERT INTO component_type_component_function (
			component_type_id,
			component_function
		) VALUES (
			ctid,
			'module'
		);

		--
		-- Switch ports
		--
		port_offset = 0;
		x_offset = 0;

		FOR p IN SELECT jsonb_array_elements(card.ports) LOOP
			INSERT INTO component_type_slot_template (
				component_type_id,
				slot_type_id,
				slot_name_template,
				physical_label,
				slot_index,
				slot_x_offset,
				slot_y_offset
			) SELECT
				ctid,
				slot_type_id,
				'Ethernet${parent_slot_index}/' || (port_offset + x.idx + 1),
				port_offset + x.idx + 1,
				port_offset + x.idx + 1,
				x_offset + (
					(x.idx / 2) % (
						GREATEST((p->>'count')::integer,
							2 * (p->>'rows')::integer) /
						(p->>'rows')::integer
					)
				),
				(x.idx % 2) + 2 * (
					x.idx / ((p->>'count')::integer / (p->>'rows')::integer)
				)
			FROM
				slot_type st,
				generate_series(0,(p->>'count')::integer - 1) x(idx)
			WHERE
				slot_type = p->>'slot_type' and slot_function = 'network';

			port_offset = port_offset + (p->>'count')::integer;
			x_offset = x_offset +
				(p->>'count')::integer / (p->>'rows')::integer;
		END LOOP;	
	END LOOP;

END;
$$ LANGUAGE plpgsql;
