-- Copyright (c) 2015-2016 Todd M. Kover
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

--
-- NOTE:  THis works like v_acct_coll_acct_expanded which pulls up, rather than
-- inherits, like mclasses do.  This could be confusing.
--

CREATE OR REPLACE VIEW v_device_coll_device_expanded as 
WITH RECURSIVE var_recurse (
	root_device_collection_id,
	device_collection_id,
	parent_device_collection_id,
	device_collection_level,
	array_path,
	cycle
) as (
	SELECT	device_collection_id	as root_device_collection_id,
		device_collection_id	as device_collection_id,
		device_collection_id	as parent_device_collection_id,
		0			as device_collection_level,
		ARRAY[device_collection_id],
		false
	FROM	device_collection
UNION  ALL
	SELECT	x.root_device_collection_id	as root_device_collection_id,
		dch.device_collection_id,
		dch.parent_device_collection_id,
		x.device_collection_level + 1 as device_collection_level,
		dch.parent_device_collection_id || x.array_path AS array_path,
		dch.parent_device_collection_id = ANY(x.array_path)
	 FROM	var_recurse x
		inner join v_device_collection_hier_trans dch
			on x.device_collection_id = 
				dch.parent_device_collection_id
	WHERE
		NOT x.cycle
) SELECT	DISTINCT root_device_collection_id as device_collection_id,
		device_id
	FROM	var_recurse
		INNER JOIN device_collection_device
			USING (device_collection_id)
;
