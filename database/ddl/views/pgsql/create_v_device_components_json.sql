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

CREATE OR REPLACE VIEW jazzhands.v_device_components_json AS 
WITH ctf AS (
	SELECT 
		ctcf.component_type_id,
		array_agg(ctcf.component_function ORDER BY ctcf.component_function) 
			AS functions
	FROM
		jazzhands.component_type_component_function ctcf
	GROUP BY
		ctcf.component_type_id
), cpu_info AS (
	SELECT
		c.component_id,
		jsonb_build_object(
			'component_id', c.component_id,
			'component_type_id', c.component_type_id,
			'company_name', comp.company_name,
			'model', ct.model,
			'core_count', pc.property_value::bigint,
			'processor_speed', ps.property_value,
			'component_function', 'CPU'
		) as component_json
	FROM
		component c
		JOIN component_type ct USING (component_type_id)
		JOIN component_type_component_function ctcf USING (component_type_id)
		JOIN component_property pc ON (
			ct.component_type_id = pc.component_type_id
			AND (pc.component_property_name, pc.component_property_type) = 
				('ProcessorCores', 'CPU')
		)
		JOIN component_property ps ON (
			ct.component_type_id = ps.component_type_id
			AND (ps.component_property_name, ps.component_property_type) = 
				('ProcessorSpeed', 'CPU')
		)
		LEFT JOIN company comp USING (company_id)
	WHERE
		ctcf.component_function = 'CPU'
), disk_info AS (
	SELECT
		c.component_id,
		jsonb_build_object(
			'component_id', c.component_id,
			'component_type_id', c.component_type_id,
			'company_name', comp.company_name,
			'model', ct.model,
			'serial_number', a.serial_number,
			'size_bytes', ds.property_value::bigint,
			'size', CEIL(ds.property_value::bigint / 1073741824::numeric) ||
				'G'::text,
			'protocol', dp.property_value,
			'media_type', mt.property_value,
			'component_function', 'disk'
		) as component_json
	FROM
		component c
		JOIN component_type ct USING (component_type_id)
		JOIN component_type_component_function ctcf USING (component_type_id)
		LEFT JOIN asset a USING (component_id)
		JOIN component_property ds ON (
			ct.component_type_id = ds.component_type_id
			AND (ds.component_property_name, ds.component_property_type) = 
				('DiskSize', 'disk')
		)
		JOIN component_property dp ON (
			ct.component_type_id = dp.component_type_id
			AND (dp.component_property_name, dp.component_property_type) = 
				('DiskProtocol', 'disk')
		)
		JOIN component_property mt ON (
			ct.component_type_id = mt.component_type_id
			AND (mt.component_property_name, mt.component_property_type) = 
				('MediaType', 'disk')
		)
		LEFT JOIN company comp USING (company_id)
	WHERE
		ctcf.component_function = 'disk'
), memory_info AS (
	SELECT
		c.component_id,
		jsonb_build_object(
			'component_id', c.component_id,
			'component_type_id', c.component_type_id,
			'company_name', comp.company_name,
			'model', ct.model,
			'serial_number', a.serial_number,
			'size', msize.property_value::bigint,
			'speed', mspeed.property_value,
			'component_function', 'memory'
		) as component_json
	FROM
		component c
		JOIN component_type ct USING (component_type_id)
		JOIN component_type_component_function ctcf USING (component_type_id)
		LEFT JOIN asset a USING (component_id)
		JOIN component_property msize ON (
			ct.component_type_id = msize.component_type_id
			AND (msize.component_property_name, msize.component_property_type) = 
				('MemorySize', 'memory')
		)
		JOIN component_property mspeed ON (
			ct.component_type_id = mspeed.component_type_id
			AND (mspeed.component_property_name, mspeed.component_property_type) = 
				('MemorySpeed', 'memory')
		)
		LEFT JOIN company comp USING (company_id)
	WHERE
		ctcf.component_function = 'memory'
)
SELECT
	dc.device_id,
	jsonb_agg(x.component_json) AS components
FROM
	jazzhands.v_device_components dc JOIN
	(
		SELECT * FROM cpu_info UNION
		SELECT * FROM disk_info UNION
		SELECT * FROM memory_info
	) x USING (component_id)
GROUP BY
	dc.device_id;
