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
CREATE OR REPLACE VIEW jazzhands.v_component_hier (
	component_id,
	child_component_id,
	component_path,
	level
	) AS
WITH RECURSIVE component_hier (
		component_id,
		child_component_id,
		slot_id,
		component_path
) AS (
	SELECT
		c.component_id, 
		c.component_id, 
		s.slot_id,
		ARRAY[c.component_id]::integer[]
	FROM
		component c LEFT JOIN
		slot s USING (component_id)
	UNION
	SELECT
		p.component_id,
		c.component_id,
		s.slot_id,
		array_prepend(c.component_id, p.component_path)
	FROM
		component_hier p JOIN
		component c ON (p.slot_id = c.parent_slot_id) LEFT JOIN
		slot s ON (s.component_id = c.component_id)
)
SELECT DISTINCT component_id, child_component_id, component_path, array_length(component_path, 1) FROM component_hier;

