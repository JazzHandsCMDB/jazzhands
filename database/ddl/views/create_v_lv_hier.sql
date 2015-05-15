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
CREATE OR REPLACE VIEW jazzhands.v_lv_hier (
	physicalish_volume_id,
	volume_group_id,
	logical_volume_id,
	child_pv_id,
	child_vg_id,
	child_lv_id,
	pv_path,
	vg_path,
	lv_path
 	) AS
WITH RECURSIVE lv_hier (
	physicalish_volume_id,
	pv_logical_volume_id,
	volume_group_id,
	logical_volume_id,
	pv_path,
	vg_path,
	lv_path
) AS (
	SELECT
		pv.physicalish_volume_id,
		pv.logical_volume_id,
		vg.volume_group_id,
		lv.logical_volume_id,
		ARRAY[pv.physicalish_volume_id]::integer[],
		ARRAY[vg.volume_group_id]::integer[],
		ARRAY[lv.logical_volume_id]::integer[]
	FROM
		physicalish_volume pv LEFT JOIN
		volume_group_physicalish_vol USING (physicalish_volume_id) FULL JOIN
		volume_group vg USING (volume_group_id) LEFT JOIN
		logical_volume lv USING (volume_group_id)
	WHERE
		lv.logical_volume_id IS NULL OR
		lv.logical_volume_id NOT IN (
			SELECT logical_volume_id
			FROM physicalish_volume
			WHERE logical_volume_id IS NOT NULL
		)
	UNION
	SELECT
		pv.physicalish_volume_id,
		pv.logical_volume_id,
		vg.volume_group_id,
		lv.logical_volume_id,
		array_prepend(pv.physicalish_volume_id, lh.pv_path),
		array_prepend(vg.volume_group_id, lh.vg_path),
		array_prepend(lv.logical_volume_id, lh.lv_path)
	FROM
		physicalish_volume pv LEFT JOIN
		volume_group_physicalish_vol USING (physicalish_volume_id) FULL JOIN
		volume_group vg USING (volume_group_id) LEFT JOIN
		logical_volume lv USING (volume_group_id) JOIN
		lv_hier lh ON (lv.logical_volume_id = lh.pv_logical_volume_id)
)
SELECT DISTINCT
	physicalish_volume_id,
	volume_group_id,
	logical_volume_id,
	unnest(pv_path),
	unnest(vg_path),
	unnest(lv_path),
	pv_path,
	vg_path,
	lv_path
FROM lv_hier;
