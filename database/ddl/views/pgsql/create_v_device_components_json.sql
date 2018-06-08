-- Copyright (c) 2018, Matthew Ragan
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

CREATE OR REPLACE VIEW jazzhands.v_device_component_expanded AS 
WITH ctf AS (
	SELECT 
		ctcf.component_type_id,
		array_agg(ctcf.component_function ORDER BY ctcf.component_function) 
			AS functions
	FROM
		jazzhands.component_type_component_func ctcf
	GROUP BY
		ctcf.component_type_id
), cs AS (
	SELECT
		cp.component_type_id,
		cp.property_value::bigint AS size
	FROM
		jazzhands.component_property cp
	WHERE
		(cp.component_property_name,cp.component_property_type) IN
			(('DiskSize', 'disk'),
			 ('MemorySize', 'memory'))
), comp_json AS (
	SELECT
		c.component_id,
		jsonb_build_object(
			'component_id', c.component_id,
			'model', ct.model,
			'serial_number', a.serial_number,
			'functions', ctf.functions,
			'slot_name', s.slot_name,
			'size', cs.size
		) as json_component
	FROM
		jazzhands.component c LEFT JOIN
		jazzhands.component_type ct USING (component_type_id) JOIN
		ctf USING (component_type_id) JOIN
		jazzhands.asset a ON c.component_id = a.component_id LEFT JOIN
		cs USING (component_type_id) LEFT JOIN
		jazzhands.slot s ON c.parent_slot_id = s.slot_id
)
SELECT
	dc.device_id,
	jsonb_agg(comp_json.json_component) as device_components
FROM
	jazzhands.v_device_components dc JOIN
	comp_json USING (component_id) 
GROUP BY
	device_id;
