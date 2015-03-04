--
-- Copyright (c) 2015 Matthew Ragan
-- All rights reserved.
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--	  http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
DO $$
DECLARE
	cid		integer;
	ctid	integer;
	stid	integer;
BEGIN
	SELECT company_id INTO cid FROM company WHERE company_name = 'Seagate';
	IF NOT FOUND THEN
		INSERT INTO company (company_name) VALUEs ('Seagate')
			RETURNING company_id INTO cid;
	END IF;

	PERFORM * FROM component_type WHERE company_id = cid AND 
		model = 'ST9500530NS';

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
			'Seagate ST9500530NS 500GB 2.5" SATA disk',
			(SELECT slot_type_id FROM slot_type WHERE
				slot_type = 'SATA' AND
				slot_physical_interface_type = 'SATA' AND
				slot_function = 'disk'
			),
			'ST9500530NS',
			cid,
			'Y',
			'N',
			2
		) RETURNING component_type_id INTO ctid;

		INSERT INTO component_type_component_func 
			(component_type_id, component_function)
		VALUES 
			(ctid, 'disk'),
			(ctid, 'rotational_disk');

		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES
			('DiskSize', 'disk', ctid, x'3a280000'::integer);

	END IF;
END; $$ language plpgsql;
