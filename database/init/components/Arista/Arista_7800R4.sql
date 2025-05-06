--
-- Copyright (c) 2020 Matthew Ragan
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
	card	RECORD;
	ct		RECORD;
	cid		integer;
	ctid	integer;
	stid	integer[];
	d		text[];
	s		text;
BEGIN
	SELECT company_id INTO cid FROM company WHERE company_name = 'Arista Networks';
	IF NOT FOUND THEN
		SELECT company_manip.add_company(
			_company_name := 'Arista Networks',
			_company_types := ARRAY['hardware provider']
		) INTO cid;
	END IF;

--
-- Arista 7800 Chassis
--

	INSERT INTO val_slot_physical_interface
		(slot_physical_interface_type, slot_function)
	VALUES
		('Arista 78XXR4 Supervisor', 'chassis_slot'),
		('Arista 78XXR4 Linecard', 'chassis_slot')
	EXCEPT
	SELECT slot_physical_interface_type, slot_function
	FROM val_slot_physical_interface;	

	WITH z AS (
		INSERT INTO slot_type 
			(slot_type, slot_physical_interface_type, slot_function,
			 description, remote_slot_permitted)
		VALUES
			('Arista 78XXR4 Supervisor', 'Arista 78XXR4 Supervisor',
			 'chassis_slot', 'Arista 78XXR4 Supervisor', false),
			('Arista 78XXR4 Linecard', 'Arista 78XXR4 Linecard',
			 'chassis_slot', 'Arista 78XXR4 Linecard', false)
		EXCEPT SELECT
			slot_type, slot_physical_interface_type, slot_function,
			 description, remote_slot_permitted
		FROM slot_type
		RETURNING slot_type_id 
	) SELECT array_agg(slot_type_id) FROM z INTO stid;

	INSERT INTO slot_type_permitted_component_slot_type (
		slot_type_id,
		component_slot_type_id
	) SELECT
		x.stid,
		x.stid
	FROM
		unnest(stid) AS x(stid)
	ON CONFLICT DO NOTHING;
	
	FOREACH d SLICE 1 IN ARRAY ARRAY[
			['7816LR4', '16'],
			['7812R4', '12'],
			['7808R4', '8'],
			['7804R4', '4']
			]
	LOOP
		PERFORM * FROM component_type
		WHERE
			model = d[1] AND
			company_id = cid;
		
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
				'Arista ' || d[1],
				NULL,
				d[1],
				cid,
				'Y',
				'Y',
				3 + d[2]::integer
			) RETURNING component_type_id INTO ctid;

			--
			-- Supervisor slots
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
				'Supervisor' || x.idx,
				x.idx,
				0,
				x.idx,
				'FRONT'
			FROM
				slot_type st,
				generate_series(1,2) x(idx)
			WHERE
				slot_type = 'Arista 78XXR4 Supervisor' AND
				slot_function = 'chassis_slot';

			--
			-- Linecard slots
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
				stid[2],
				'Linecard' || x.idx,
				x.idx,
				0,
				x.idx,
				'FRONT'
			FROM
				generate_series(3, 2 + d[2]::integer) x(idx);
		END IF;
	END LOOP;
		
	--
	-- Supervisor modules
	--

	PERFORM * FROM component_type WHERE
		model = 'DCS-7800-SUP1S' AND
		company_id = cid;
	
	IF NOT FOUND THEN
		INSERT INTO component_type (
			description,
			slot_type_id,
			model,
			company_id,
			asset_permitted,
			is_rack_mountable
		) SELECT
			'Arista DCS-7800-SUP1S',
			slot_type_id,
			'DCS-7800-SUP1S',
			cid,
			'Y',
			'N'
		  FROM
		  	slot_type
		  WHERE
		    slot_type = 'Arista 78XXR4 Supervisor' AND
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
	END IF;

	--
	-- Line cards
	--

	FOR card IN SELECT * FROM (VALUES
		(
	        '7800R4C-36PE-LC', 'Arista 7800R4C-36PE-LC, 36x800G OSFP linecard',
        	'[
				{ "slot_type": "800GOSFPEthernet", "count": 36 }
			]'::jsonb
	    )
    ) AS s(model, description, ports) LOOP
        RAISE INFO 'Model is %', card.model;
        BEGIN
            SELECT * INTO ct FROM component_manip.insert_arista_linecard_type(
                model := card.model,
                description := card.description,
				linecard_type := 'Arista 78XXR4 Linecard',
                ports := card.ports
            );
        EXCEPTION
            WHEN unique_violation THEN
                RAISE NOTICE 'linecard model % already inserted',
                    card.model;
                CONTINUE;
        END;
        RAISE INFO '  component_type_id is %', ct.component_type_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
