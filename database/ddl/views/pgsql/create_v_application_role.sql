-- Copyright (c) 2011-2014, Todd M. Kover
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
-- $Id$
--

CREATE OR REPLACE VIEW v_application_role AS
WITH RECURSIVE var_recurse(
	role_level,
	role_id,
	parent_role_id,
	root_role_id,
	root_role_name,
	role_name,
	role_path,
	role_is_leaf,
	array_path,
	cycle
) as (
	SELECT	
		0					as role_level,
		device_collection_id			as role_id,
		cast(NULL AS integer)			as parent_role_id,
		device_collection_id			as root_role_id,
		device_collection_name			as root_role_name,
		device_collection_name			as role_name,
		'/'||device_collection_name		as role_path,
		'N'								as role_is_leaf,
		ARRAY[device_collection_id]		as array_path,
		false							as cycle
	FROM
		device_collection
	WHERE
		device_collection_type = 'appgroup'
	AND	device_collection_id not in
		(select device_collection_id from device_collection_hier)
UNION ALL
	SELECT	x.role_level + 1				as role_level,
		dch.device_collection_id 			as role_id,
		dch.parent_device_collection_id 		as parent_role_id,
		x.root_role_id 					as root_role_id,
		x.root_role_name 				as root_role_name,
		dc.device_collection_name			as role_name,
		cast(x.role_path || '/' || dc.device_collection_name 
					as varchar(255))	as role_path,
		case WHEN lchk.parent_device_collection_id IS NULL
			THEN 'Y'
			ELSE 'N'
			END 					as role_is_leaf,
		dch.parent_device_collection_id || x.array_path	as array_path,
		dch.parent_device_collection_id = ANY(x.array_path)	as cycle
	FROM	var_recurse x
		inner join device_collection_hier dch
			on x.role_id = dch.parent_device_collection_id
		inner join device_collection dc
			on dch.device_collection_id = dc.device_collection_id
		left join device_collection_hier lchk
			on dch.device_collection_id 
				= lchk.parent_device_collection_id
	WHERE NOT x.cycle
) SELECT distinct * FROM var_recurse;

-- consider adding order by root_role_id, role_level, length(role_path)
-- or leave that to things calling it (probably smarter)

-- XXX v_application_role_member this should probably be pulled out to common
-- XXX need to decide how to deal with oracle's WITH READ ONLY

CREATE OR REPLACE VIEW v_application_role_member AS
	select	device_id,
		device_collection_id as role_id,
		DATA_INS_USER,
		DATA_INS_DATE,
		DATA_UPD_USER,
		DATA_UPD_DATE
	from	device_collection_device
	where	device_collection_id in
		(select device_collection_id from device_collection
			where device_collection_type = 'appgroup'
		)
;


