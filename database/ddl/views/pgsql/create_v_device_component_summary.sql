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

CREATE OR REPLACE VIEW jazzhands.v_device_component_summary AS
WITH cs AS (
	SELECT
		dc.device_id,
		COUNT(*) FILTER (WHERE 
			cp.component_property_type::text = 'CPU'::text
			AND cp.component_property_name::text = 'ProcessorCores'::text
		) AS cpu_count,
		SUM(cp.property_value::bigint) FILTER (WHERE
			cp.component_property_type::text = 'CPU'::text
			AND cp.component_property_name::text = 'ProcessorCores'::text
		) AS core_count,
		COUNT(*) FILTER (WHERE
			cp.component_property_type::text = 'memory'::text
			AND cp.component_property_name::text = 'MemorySize'::text
		) AS memory_count,
		SUM(cp.property_value::bigint) FILTER (WHERE
			cp.component_property_type::text = 'memory'::text
			AND cp.component_property_name::text = 'MemorySize'::text
		) AS total_memory,
		COUNT(*) FILTER (WHERE
			cp.component_property_type::text = 'disk'::text
			AND cp.component_property_name::text = 'DiskSize'::text
		) AS disk_count,
		CEIL(SUM(cp.property_value::bigint) FILTER (
			WHERE cp.component_property_type::text = 'disk'::text
			AND cp.component_property_name::text = 'DiskSize'::text
		) / 1073741824::numeric) || 'G'::text AS total_disk
	FROM
		jazzhands.v_device_components dc
		JOIN jazzhands.component c USING (component_id)
		JOIN jazzhands.component_property cp USING (component_type_id)
	GROUP BY dc.device_id
), cm AS (
	SELECT DISTINCT
		dc.device_id,
		ct.model AS cpu_model
	FROM
		jazzhands.v_device_components dc
		JOIN jazzhands.component c USING (component_id)
		JOIN jazzhands.component_type ct USING (component_type_id)
		JOIN jazzhands.component_type_component_function ctcf USING (component_type_id)
	WHERE
		ctcf.component_function::text = 'CPU'::text
)
SELECT
	cs.device_id,
	cm.cpu_model,
	cs.cpu_count,
	cs.core_count,
	cs.memory_count,
	cs.total_memory,
	cs.disk_count,
	cs.total_disk
FROM
	cm
	JOIN cs USING (device_id);
