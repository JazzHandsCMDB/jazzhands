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
	p		text[];
	s		text;
BEGIN
	SELECT company_id INTO cid FROM company WHERE company_name = 'Arista Networks';
	IF NOT FOUND THEN
		SELECT company_manip.add_company(
			_company_name := 'Arista Networks',
			_company_types := ARRAY['hardware provider']
		) INTO cid;
	END IF;
	FOREACH p SLICE 1 IN ARRAY ARRAY[['7050QX','32', '1'],['7250QX','64', '2']] LOOP
		INSERT INTO component_type (
			description,
			slot_type_id,
			model,
			company_id,
			asset_permitted,
			is_rack_mountable,
			size_units
		) VALUES (
			concat_ws('-', 'DCS', p[1], p[2]),
			NULL,
			concat_ws('-', 'DCS', p[1], p[2]),
			cid,
			'Y',
			'Y',
			p[3]
		) RETURNING component_type_id INTO ctid;

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) VALUES (
			ctid,
			'device'
		);

		INSERT INTO device_type (
			component_type_id,
			device_type_name,
			description, 
			company_id,
			config_fetch_type,
			rack_units)
		VALUES (
			ctid,
			concat_ws('-', 'DCS', p[1], p[2], s),
			'Arista ' || concat_ws('-', 'DCS', p[1], p[2], s),
			cid,
			'arista',
			p[3]::integer
		);

		--
		-- Console port
		--

		INSERT INTO component_type_slot_tmplt (
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
			slot_type = 'RJ45 serial' and slot_function = 'serial';

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
			'Ethernet' || (x.idx + 1) || '/1',
			49 + x.idx,
			49 + x.idx,
			(x.idx / 2),
			(x.idx % 2),
			'FRONT'
		FROM
			slot_type st,
			generate_series(0,p[2]::integer - 1) x(idx)
		WHERE
			slot_type = '40GQSFP+Ethernet' and slot_function = 'network';

-- 			INSERT INTO component_type_slot_tmplt (
-- 				component_type_id,
-- 				slot_type_id,
-- 				slot_name_template,
-- 				physical_label,
-- 				slot_index,
-- 				slot_x_offset,
-- 				slot_y_offset,
-- 				slot_side
-- 			) SELECT
-- 				ctid,
-- 				slot_type_id,
-- 				'Ethernet' || x.idx + 17,
-- 				x.idx + 17,
-- 				x.idx + 17,
-- 				(x.idx / 2),
-- 				(x.idx % 2),
-- 				'FRONT'
-- 			FROM
-- 				slot_type st,
-- 				generate_series(0,7) x(idx)
-- 			WHERE
-- 				slot_type = '10GSFP+Ethernet' and slot_function = 'network';

		--
		-- Management port
		--
		INSERT INTO component_type_slot_tmplt (
			component_type_id,
			slot_type_id,
			slot_name_template,
			slot_y_offset,
			slot_side
		) SELECT
			ctid,
			slot_type_id,
			'Management1',
			1,
			'FRONT'
		FROM
			slot_type st
		WHERE
			slot_type = '1000BaseTEthernet' and slot_function = 'network';
	END LOOP;
END;
$$ LANGUAGE plpgsql;

DO $$
#variable_conflict use_variable
DECLARE
	cid		integer;
	ctid	integer;
	stid	integer;
	p		text[];
	s		text;
	port_type	text;
	port_count	integer;
	qsfp_count	integer;
	mxp_count	integer;
	rack_units	integer;
BEGIN
	SELECT company_id INTO cid FROM company WHERE company_name = 'Arista';
	IF NOT FOUND THEN
		SELECT company_manip.add_company(
			_company_name := 'Arista',
			_company_types := ARRAY['hardware provider']
		) INTO cid;
	END IF;
	FOREACH p SLICE 1 IN ARRAY ARRAY[
		['7050SX-64','10GSFP+Ethernet','48','4','0','1'],
		['7050SX-72','10GSFP+Ethernet','48','0','2','1'],
		['7050SX-96','10GSFP+Ethernet','48','0','4','1'],
		['7050SX-128','10GSFP+Ethernet','96','8','0','2'],
		['7050TX-48','10GBaseTEthernet','32','4','0','1'],
		['7050TX-64','10GBaseTEthernet','48','4','0','1'],
		['7050TX-72','10GBaseTEthernet','48','0','2','1'],
		['7050TX-96','10GBaseTEthernet','48','0','4','1'],
		['7050TX-128','10GBaseTEthernet','96','8','0','2']
	] LOOP
		port_type	:= p[2];
		port_count	:= p[3]::integer;
		qsfp_count	:= p[4]::integer;
		mxp_count	:= p[5]::integer;
		rack_units	:= p[6]::integer;

		INSERT INTO component_type (
			description,
			slot_type_id,
			model,
			company_id,
			asset_permitted,
			is_rack_mountable,
			size_units
		) VALUES (
			concat_ws('-', 'DCS', p[1]),
			NULL,
			concat_ws('-', 'DCS', p[1]),
			cid,
			'Y',
			'Y',
			p[5]
		) RETURNING component_type_id INTO ctid;

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) VALUES (
			ctid,
			'device'
		);

		INSERT INTO device_type (
			component_type_id,
			device_type_name,
			description, 
			company_id,
			config_fetch_type,
			rack_units)
		VALUES (
			ctid,
			concat_ws('-', 'DCS', p[1], s),
			'Arista ' || concat_ws('-', 'DCS', p[1], s),
			cid,
			'arista',
			rack_units
		);

		--
		-- Console port
		--

		INSERT INTO component_type_slot_tmplt (
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
			slot_type = 'RJ45 serial' and slot_function = 'serial';

		--
		-- Management port
		--
		INSERT INTO component_type_slot_tmplt (
			component_type_id,
			slot_type_id,
			slot_name_template,
			slot_y_offset,
			slot_side
		) SELECT
			ctid,
			slot_type_id,
			'Management1',
			1,
			'FRONT'
		FROM
			slot_type st
		WHERE
			slot_type = port_type and slot_function = 'network';

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
			'Ethernet' || (x.idx + 1),
			x.idx + 1,
			x.idx + 1,
			(x.idx / 2),
			(x.idx % 2),
			'FRONT'
		FROM
			slot_type st,
			generate_series(0,port_count - 1) x(idx)
		WHERE
			slot_type = port_type and slot_function = 'network';

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
			'Ethernet' || (x.idx + 1 ) + port_count || '/1',
			x.idx + 1 + port_count,
			x.idx + 1 + port_count,
			(x.idx / 2),
			(x.idx % 2),
			'FRONT'
		FROM
			slot_type st,
			generate_series(0,(qsfp_count - 1)) x(idx)
		WHERE
			slot_type = '40GQSFP+Ethernet' and slot_function = 'network';

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
			'Ethernet' || (x.idx + 1 ) + port_count + qsfp_count || '/1',
			x.idx + 1 + port_count + qsfp_count,
			x.idx + 1 + port_count + qsfp_count,
			(x.idx / 2),
			(x.idx % 2),
			'FRONT'
		FROM
			slot_type st,
			generate_series(0,(mxp_count - 1)) x(idx)
		WHERE
			slot_type = '100GMXPEthernet' and slot_function = 'network';
	END LOOP;
END;
$$ LANGUAGE plpgsql;

