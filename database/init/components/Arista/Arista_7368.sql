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
	sup_ctid	integer;
	stid		integer[];
	d			text[];
	s			text;
	card		RECORD;
	p			integer;
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

	PERFORM * FROM val_slot_physical_interface WHERE
		slot_physical_interface_type = 'Arista 7368 Supervisor' AND
		slot_function = 'chassis_slot';
	
	IF NOT FOUND THEN
		INSERT INTO val_slot_physical_interface
			(slot_physical_interface_type, slot_function)
		VALUES
			('Arista 7368 Supervisor', 'chassis_slot'),
			('Arista 7368 Linecard', 'chassis_slot');

		WITH z AS (
			INSERT INTO slot_type 
				(slot_type, slot_physical_interface_type, slot_function,
				 description, remote_slot_permitted)
			VALUES
				('Arista 7368 Supervisor', 'Arista 7368 Supervisor',
				 'chassis_slot', 'Arista 7368 Supervisor', 'N'),
				('Arista 7368 Linecard', 'Arista 7368 Linecard',
				 'chassis_slot', 'Arista 7368 Linecard', 'N')
			RETURNING slot_type_id 
		) SELECT array_agg(slot_type_id) FROM z INTO stid;

		INSERT INTO slot_type_permitted_component_slot_type (
			slot_type_id,
			component_slot_type_id
		) SELECT
			x.stid,
			x.stid
		FROM
			unnest(stid) AS x(stid);
		
		INSERT INTO component_type (
			description,
			slot_type_id,
			model,
			company_id,
			asset_permitted,
			is_rack_mountable,
			size_units
		) VALUES (
			'Arista DCS-7368',
			NULL,
			'7368',
			cid,
			'Y',
			'Y',
			4
		) RETURNING component_type_id INTO ctid;

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
			stid[1],
			'Supervisor1',
			1,
			0,
			1,
			'FRONT';

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
			stid[2],
			'Linecard' || x.idx,
			'Ethernet' || x.idx || '/%{slot_index}',
			x.idx,
			0,
			x.idx,
			'FRONT'
		FROM
			generate_series(2, 9) x(idx);
	
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
			'Arista DCS-7368-SUP',
			stid[1],
			'7368-SUP',
			cid,
			'Y',
			'N'
		) RETURNING component_type_id INTO sup_ctid;

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
			sup_ctid,
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
			sup_ctid,
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

	END IF;

	--
	-- Line cards
	--

	FOR card IN SELECT * FROM (VALUES
		(
			'DCS-7368-4P',
			'DCS-7368-4P 4x400G OSFP',
			4,
			'400GOSFPEthernet'
		),
		(
			'DCS-7368-4D',
			'DCS-7368-4D 4x400G QSFP-DD',
			4,
			'400GOSFPEthernet'
		),
		(
			'DCS-7368-16C',
			'DCS-7368-16C 16x100G QSFP28',
			16,
			'100GQSFP28Ethernet'
		),
		(
			'DCS-7368-16S',
			'DCS-7368-16S 16x25G SFP28',
			16,
			'25GSFP28Ethernet'
		)
	)
	AS s(model, description, count, slot_type)
	LOOP
	    SELECT * INTO ctrec FROM component_type ct WHERE
        company_id = cid AND
        ct.model = card.model;

		IF FOUND THEN
			RAISE NOTICE 'Switch type for model % already exists as component_type_id %',
				card.model,
				ctrec.component_type_id
			USING ERRCODE = 'unique_violation';
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
		) VALUES (
			card.description,
			stid[2],
			card.model,
			cid,
			true,
			false,
			0
		) RETURNING * INTO ctrec;

		ctid = ctrec.component_type_id;

		INSERT INTO component_type_component_function (
			component_type_id,
			component_function
		) VALUES (
			ctid,
			'module'
		);

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
            'Ethernet%{parent_slot_index}/' || (x.idx + 1),
            x.idx + 1,
            x.idx + 1,
            (x.idx / 2),
            (x.idx % 2),
            'FRONT'
        FROM
            slot_type st,
            generate_series(0,card.count - 1) x(idx)
        WHERE
            st.slot_type = card.slot_type and slot_function = 'network';

    END LOOP;	
	
END;
$$ LANGUAGE plpgsql;
