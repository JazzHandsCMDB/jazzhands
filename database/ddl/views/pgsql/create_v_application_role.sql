-- Copyright (c) 2011, Todd M. Kover
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
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
	role_is_leaf
) as (
	SELECT	
		0					as role_level,
		device_collection_id			as role_id,
		NULL					as parent_role_id,
		device_collection_id			as root_role_id,
		device_collection_name			as root_role_name,
		device_collection_name			as role_name,
		'/'||device_collection_name		as role_path,
		'N'					as role_is_leaf
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
			END 					as role_is_leaf
	FROM	var_recurse x
		inner join device_collection_hier dch
			on x.role_id = dch.parent_device_collection_id
		inner join device_collection dc
			on dch.device_collection_id = dc.device_collection_id
		left join device_collection_hier lchk
			on dch.device_collection_id 
				= lchk.parent_device_collection_id
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
	from	device_collection_member
	where	device_collection_id in
		(select device_collection_id from device_collection
			where device_collection_type = 'appgroup'
		)
;


