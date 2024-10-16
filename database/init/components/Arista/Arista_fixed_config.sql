--
-- Copyright (c) 2015,2021 Matthew Ragan
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
	cid				integer;
	ctid			integer;
	stid			integer;
	p				text[];
	switch_model	text;
	port_type		text;
	port_count		integer;
	uplink_type		text;
	uplink_count	integer;
	rack_units		integer;
BEGIN
	SELECT company_id INTO cid FROM company WHERE
		company_name = 'Arista Networks';

	IF NOT FOUND THEN
		SELECT company_manip.add_company(
			_company_name := 'Arista Networks',
			_company_types := ARRAY['hardware provider']
		) INTO cid;
	END IF;
	--
	-- Assume all of the switches are X number of ports of one type, and
	-- Y number of uplinks of a different type
	--
	FOREACH p SLICE 1 IN ARRAY ARRAY[

		--
		-- 7010
		--
		['DCS-7010T-48','1',
			'1000BaseTEthernet', '48',
			'10GSFP+Ethernet',	'2'
		],
		['DCS-7010TX-48','1',
			'1000BaseTEthernet', '48',
			'10GSFP+Ethernet',	'2'
		],

		--
		-- 7050
		--
		['DCS-7050SX-64','1',
			'10GSFP+Ethernet',	'48',
			'40GQSFP+Ethernet',	'4'
		],
		['DCS-7050SX-72','1',
			'10GSFP+Ethernet','48',
			'100GMXPEthernet','2'
		],
		['DCS-7050SX-96','1',
			'10GSFP+Ethernet','48',
			'100GMXPEthernet','4'
		],
		['DCS-7050SX-128','2',
			'10GSFP+Ethernet','96',
			'40GQSFP+Ethernet','8'
		],
		['DCS-7050TX-48','1',
			'10GBaseTEthernet','32',
			'40GQSFP+Ethernet','4'
		],
		['DCS-7050TX-64','1',
			'10GBaseTEthernet','48',
			'40GQSFP+Ethernet','4'
		],
		['DCS-7050TX-72','1',
			'10GBaseTEthernet','48',
			'100GMXPEthernet','2'
		],
		['DCS-7050TX-96','1',
			'10GBaseTEthernet','48',
			'100GMXPEthernet','4'
		],
		['DCS-7050TX-128','2',
			'10GBaseTEthernet','96',
			'40GQSFP+Ethernet','8'
		],
		['DCS-7050CX3-32S','1',
			'100GQSFP28Ethernet','32',
			'10GSFP+Ethernet','2'
		],
		['DCS-7050SX3-96YC8','2',
			'25GSFP28Ethernet','96',
			'100GQSFP28Ethernet','8'
		],
		['DCS-7050SX3-48YC12','1',
			'25GSFP28Ethernet','48',
			'100GQSFP28Ethernet','12'
		],
		['DCS-7050SX3-48YC8','1',
			'25GSFP28Ethernet','48',
			'100GQSFP28Ethernet','8'
		],
		['DCS-7050SX3-48C8','1',
			'10GSFP+Ethernet','48',
			'100GQSFP28Ethernet','8'
		],
		['DCS-7050TX3-48C8','1',
			'10GBaseTEthernet','48',
			'100GQSFP28Ethernet','8'
		],
		--
		-- 7160
		--
		['DCS-7160-32CQ','1',
			'100GQSFP28Ethernet','32',
			'100GQSFP28Ethernet','0'
		],
		['DCS-7160-48YC6','1',
			'25GSFP28Ethernet','48',
			'100GQSFP28Ethernet','6'
		],
		['DCS-7160-48TC6','1',
			'10GBaseTEthernet','48',
			'100GQSFP28Ethernet','6'
		]
	] LOOP
		switch_model	:= p[1];
		rack_units		:= p[2]::integer;
		port_type		:= p[3];
		port_count		:= p[4]::integer;
		uplink_type 	:= p[5];
		uplink_count	:= p[6]::integer;

		SELECT component_type_id INTO ctid FROM component_type WHERE
			company_id = cid AND
			model = switch_model;

		--
		-- If it's inserted already, assume it's correct
		--
		IF ctid IS NOT NULL THEN
			RAISE INFO
				'Switch type % already inserted with component_type_id %',
				switch_model, ctid;
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
			switch_model,
			NULL,
			switch_model,
			cid,
			true,
			true,
			rack_units
		) RETURNING component_type_id INTO ctid;

		RAISE INFO 'Adding switch type % with % % ports and % % uplinks as component_type_id %',
			switch_model,
			port_count,
			port_type,
			uplink_count,
			uplink_type,
			ctid;

		INSERT INTO component_type_component_function (
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
			switch_model,
			'Arista ' || switch_model,
			cid,
			'arista',
			rack_units
		);

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
			slot_type = 'RJ45 serial' and slot_function = 'serial';

		--
		-- Management port
		--
		INSERT INTO component_type_slot_template (
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

		--
		-- Insert all of the regular ports.  For switches that are multiple
		-- rack units, port offset is complicated.
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
			'Ethernet' || (x.idx + 1),
			x.idx + 1,
			x.idx + 1,
			(x.idx % (port_count / rack_units)) / 2,
			(x.idx % 2) + ((x.idx / rack_units) * 2),
			'FRONT'
		FROM
			slot_type st,
			generate_series(0,port_count - 1) x(idx)
		WHERE
			slot_type = port_type and slot_function = 'network';

		--
		-- Insert all of the uplink ports.  For switches that are multiple
		-- rack units, port offset is complicated.
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
			'Ethernet' || (x.idx + 1 ) + port_count || '/1',
			x.idx + 1 + port_count,
			x.idx + 1 + port_count,
			(x.idx % (uplink_count / rack_units)) / 2,
			(x.idx % 2) + ((x.idx / rack_units) * 2),
			'FRONT'
		FROM
			slot_type st,
			generate_series(0,(uplink_count - 1)) x(idx)
		WHERE
			slot_type = uplink_type and slot_function = 'network';
	END LOOP;
END;
$$ LANGUAGE plpgsql;

