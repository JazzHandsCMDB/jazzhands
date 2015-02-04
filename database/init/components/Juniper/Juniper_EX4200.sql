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

--
-- EX4200 stack
--
DO $$
#variable_conflict use_variable
DECLARE
	cid			integer;
	vcp_stid	integer;
	stack_stid	integer;
	ctid		integer;
	stid		integer;
BEGIN
	SELECT company_id INTO cid FROM jazzhands.company WHERE
		company_name = 'Juniper';

	IF NOT FOUND THEN
		INSERT INTO company (company_name) VALUES ('Juniper')
			RETURNING company_id INTO cid;
	END IF;

--
-- Juniper EX VCP
--

	PERFORM * FROM val_slot_physical_interface WHERE
		slot_physical_interface_type = 'Juniper EX VCP' AND
		slot_function = 'inter_component_link';

	--
	-- Assume if the stuff above exists, that none of the rest of this needs
	-- to be done
	--
	IF NOT FOUND THEN
		INSERT INTO val_slot_physical_interface
			(slot_physical_interface_type, slot_function)
		VALUES
			( 'Juniper EX VCP', 'inter_component_link');

		INSERT INTO slot_type 
			(slot_type, slot_physical_interface_type, slot_function,
			 description, remote_slot_permitted)
		VALUES
			('Juniper EX VCP', 'Juniper EX VCP', 'inter_component_link',
			'Juniper Virtual Chassis port', 'Y')
		RETURNING
			slot_type_id INTO vcp_stid;

		--
		-- Insert the VCP-VCP connection
		-- 
		INSERT INTO slot_type_prmt_rem_slot_type (
			slot_type_id,
			remote_slot_type_id
		) VALUES 
			(vcp_stid, vcp_stid);

		--
		-- Chassis slot types
		--
		INSERT INTO val_slot_physical_interface
			(slot_physical_interface_type, slot_function)
		VALUES
			('JuniperEXStack', 'chassis_slot');

		INSERT INTO slot_type 
			(slot_type, slot_physical_interface_type, slot_function,
			 description, remote_slot_permitted)
		VALUES
			('JuniperEXStack', 'JuniperEXStack', 'chassis_slot',
			 'Juniper EX stack', 'N')
		RETURNING
			slot_type_id INTO stack_stid;

		INSERT INTO slot_type_prmt_comp_slot_type (
			slot_type_id,
			component_slot_type_id
		) VALUES
			(stack_stid, stack_stid);
	END IF;

	INSERT INTO component_type (
		description,
		slot_type_id,
		model,
		company_id,
		asset_permitted,
		is_rack_mountable
	) VALUES (
		'Juniper EX4xxx virtual chassis',
		NULL,
		'Juniper EX4xxx virtual chassis',
		cid,
		'Y',
		'N'
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
		slot_index
	) SELECT
		ctid,
		stack_stid,
		'VC' || x.idx,
		x.idx
	FROM
		generate_series(0,9) x(idx);

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
		'Juniper EX4200-48T',
		stid,
		'EX4200-48T',
		'750-033063',
		cid,
		'Y',
		'Y',
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
	-- Console port
	--

	INSERT INTO component_type_slot_tmplt (
		component_type_id,
		slot_type_id,
		slot_name_template,
		physical_label,
		slot_index,
		slot_x_offset,
		slot_side
	) SELECT
		ctid,
		slot_type_id,
		'console',
		'CON',
		0,
		0,
		'BACK'
	FROM
		slot_type st
	WHERE
		slot_type = 'RJ45 serial' and slot_function = 'serial';

	--
	-- Network ports
	--
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
		'ge-%{parent_slot_index}/0/' || x.idx,
		x.idx,
		x.idx,
		(x.idx / 2),
		(x.idx % 2),
		'FRONT'
	FROM
		slot_type st,
		generate_series(0,47) x(idx)
	WHERE
		slot_type = '1000BaseTEthernet' and slot_function = 'network';

	INSERT INTO component_type_slot_tmplt (
		component_type_id,
		slot_type_id,
		slot_name_template,
		physical_label,
		slot_index,
		slot_x_offset,
		slot_side
	) SELECT
		ctid,
		slot_type_id,
		'ge-%{parent_slot_index}/1/' || (x.idx * 2 + 1),
		(x.idx * 2 + 1),
		(x.idx * 2 + 1),
		(x.idx * 2 + 1),
		'FRONT'
	FROM
		slot_type st,
		generate_series(0,1) x(idx)
	WHERE
		slot_type = '1GSFPEthernet' and slot_function = 'network';

	INSERT INTO component_type_slot_tmplt (
		component_type_id,
		slot_type_id,
		slot_name_template,
		physical_label,
		slot_index,
		slot_x_offset,
		slot_side
	) SELECT
		ctid,
		slot_type_id,
		'xe-%{parent_slot_index}/1/' || (x.idx * 2),
		(x.idx * 2),
		(x.idx * 2),
		(x.idx * 2),
		'FRONT'
	FROM
		slot_type st,
		generate_series(0,1) x(idx)
	WHERE
		slot_type = '10GSFP+Ethernet' and slot_function = 'network';

	--
	-- Management port
	--
	INSERT INTO component_type_slot_tmplt (
		component_type_id,
		slot_type_id,
		slot_name_template,
		physical_label,
		slot_x_offset,
		slot_side
	) SELECT
		ctid,
		slot_type_id,
		'vme',
		'MGMT',
		1,
		'BACK'
	FROM
		slot_type st
	WHERE
		slot_type = '1000BaseTEthernet' and slot_function = 'network';

	--
	-- Management port
	--
	INSERT INTO component_type_slot_tmplt (
		component_type_id,
		slot_type_id,
		slot_name_template,
		physical_label,
		slot_x_offset,
		slot_side
	) SELECT 
		ctid,
		vcp_stid,
		'VCP-' || x.idx,
		'VCP-' || x.idx,
		x.idx,
		'BACK'
	FROM
		generate_series(0,1) x(idx);

END;
$$ LANGUAGE plpgsql;
