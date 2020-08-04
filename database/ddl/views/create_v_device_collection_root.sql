-- Copyright (c) 2016, Kurt Adam
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

CREATE OR REPLACE VIEW v_device_collection_root AS
WITH x AS (
	SELECT
		c.device_collection_id AS leaf_id,
		c.device_collection_name AS leaf_name,
		c.device_collection_type AS leaf_type,
		p.device_collection_id AS root_id,
		p.device_collection_name AS root_name,
		p.device_collection_type AS root_type,
		dch.device_collection_level
	FROM jazzhands.device_collection c
	JOIN jazzhands.v_device_collection_hier_detail dch ON dch.device_collection_id = c.device_collection_id
	JOIN jazzhands.device_collection p ON dch.parent_device_collection_id = p.device_collection_id
		AND p.device_collection_type = c.device_collection_type
)
SELECT
	xx.root_id,
	xx.root_name,
	xx.root_type,
	xx.leaf_id,
	xx.leaf_name,
	xx.leaf_type
FROM (	SELECT
		x.root_id,
		x.root_name,
		x.root_type,
		x.leaf_id,
		x.leaf_name,
		x.leaf_type,
		x.device_collection_level,
		row_number() OVER (PARTITION BY x.leaf_id ORDER BY x.device_collection_level DESC) AS rn
	FROM x) xx
WHERE xx.rn = 1;
