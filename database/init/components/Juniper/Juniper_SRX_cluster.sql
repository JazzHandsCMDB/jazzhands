--
-- Copyright (c) 2023 Matthew Ragan
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
-- EX4x00 stack
--
DO $$
#variable_conflict use_variable
DECLARE
	cid				integer;
	model_name		text;
	cluster_type	text;
	cluster_stid	integer;
	ctid			integer;
	stid			integer;
	comp			record;
BEGIN
	SELECT company_id INTO cid FROM jazzhands.company WHERE
		company_name = 'Juniper Networks';

	IF NOT FOUND THEN
		SELECT company_manip.add_company(
			company_name := 'Juniper Networks',
			company_types := ARRAY['hardware provider']
		) INTO cid;
	END IF;

	--
	-- Go through each of the SRX types and create virtual chassis entries
	--
	FOREACH model_name IN ARRAY ARRAY [
		'SRX100',
		'SRX210',
		'SRX220',
		'SRX240',
		'SRX240H',
		'SRX240H2',
		'SRX300',
		'SRX320',
		'SRX340',
		'SRX345',
		'SRX380',
		'SRX550M',
		'SRX650',
		'SRX1400',
		'SRX1500',
		'SRX4100',
		'SRX4200',
		'SRX4600',
		'SRX5400',
		'SRX5600',
		'SRX5800'
	] LOOP
		cluster_type := model_name || ' cluster';

		PERFORM * FROM val_slot_physical_interface WHERE
			slot_physical_interface_type = cluster_type AND
			slot_function = 'chassis_slot';

		IF NOT FOUND THEN
			INSERT INTO val_slot_physical_interface
				(slot_physical_interface_type, slot_function)
			VALUES
				(cluster_type, 'chassis_slot');
		END IF;

		SELECT
			slot_type_id INTO cluster_stid
		FROM
			slot_type st
		WHERE
			st.slot_type = cluster_type;

		IF NOT FOUND THEN
			INSERT INTO slot_type 
				(slot_type, slot_physical_interface_type, slot_function,
				 description, remote_slot_permitted)
			VALUES
				(cluster_type, cluster_type, 'chassis_slot',
				 cluster_type, false)
			RETURNING
				slot_type_id INTO cluster_stid;

			INSERT INTO slot_type_permitted_component_slot_type (
				slot_type_id,
				component_slot_type_id
			) VALUES
				(cluster_stid, cluster_stid);
		END IF;

		SELECT
			component_type_id INTO ctid
		FROM
			component_type ct
		WHERE
			ct.model = cluster_type;

		IF NOT FOUND THEN
			INSERT INTO component_type (
				description,
				slot_type_id,
				model,
				company_id,
				asset_permitted,
				is_virtual_component,
				is_rack_mountable
			) VALUES (
				'Juniper ' || cluster_type,
				NULL,
				cluster_type,
				cid,
				false,
				true,
				false
			) RETURNING component_type_id INTO ctid;

			INSERT INTO component_type_component_function (
				component_type_id,
				component_function
			) VALUES (
				ctid,
				'chassis'
			);

			INSERT INTO component_type_slot_template (
				component_type_id,
				slot_type_id,
				slot_name_template,
				slot_index
			) SELECT
				ctid,
				cluster_stid,
				'node' || x.idx,
				x.idx
			FROM
				generate_series(0,1) x(idx);
		END IF;

		SELECT
			* INTO comp
		FROM
			component_type
		WHERE
			company_id = cid AND
			model = model_name;

		IF NOT FOUND THEN
			INSERT INTO component_type (
				description,
				slot_type_id,
				model,
				company_id,
				asset_permitted,
				is_virtual_component,
				is_rack_mountable
			) VALUES (
				'Juniper ' || model_name,
				cluster_stid,
				model_name,
				cid,
				true,
				false,
				true
			) RETURNING * INTO comp;
		ELSE
			IF comp.slot_type_id IS DISTINCT FROM cluster_stid THEN
				UPDATE
					component_type ct
				SET
					slot_type_id = cluster_stid
				WHERE
					ct.component_type_id = comp.component_type_id;
			END IF;
		END IF;
	END LOOP;
END;
$$ LANGUAGE plpgsql;
