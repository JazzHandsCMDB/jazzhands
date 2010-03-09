-- Copyright (c) 2005-2010, Vonage Holdings Corp.
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
--
-- $Id$
--

CREATE OR REPLACE VIEW v_application_role AS
	SELECT hier_q.* from ( 
		select  level as role_level,
		    dc.device_collection_id as role_id,
		    connect_by_root dcp.device_collection_id as root_role_id,
		    connect_by_root dcp.name as root_role_name,
		    SYS_CONNECT_BY_PATH(dcp.name, '/') || '/' || dc.name as role_path,
		    dc.name as role_name,
		    decode(connect_by_isleaf, 0, 'N', 'Y') as role_is_leaf
		  from  device_collection dc
		    inner join  device_collection_hier dch
			on dch.device_collection_id =
			    dc.device_collection_id
		    inner join device_collection dcp
			on dch.parent_device_collection_id =
			    dcp.device_collection_id
		where   dc.device_collection_type = 'appgroup'
		    connect by prior dch.device_collection_id
			= dch.parent_device_collection_id
	 ) HIER_Q
	 WHERE hier_q.root_role_id not in (
		    select device_collection_id from device_collection_hier
		)   
UNION
	select 0 as role_level, 
		dc.device_collection_id as role_id,
		dc.device_collection_id as root_id,
		dc.name as root_name,
		'/' || dc.name as  path,
		dc.name as role_name,
		'N' as is_leaf
	 from   device_collection dc
	where   
		device_collection_id not in (
		    select device_collection_id from device_collection_hier
		)
	AND
		dc.device_collection_type = 'appgroup'
WITH READ ONLY;

create or replace view v_application_role_member as
	select	device_id,
		device_collection_id as role_id,
		DATA_INS_USER,
		DATA_INS_DATE,
		DATA_UPD_USER,
		DATA_UPD_DATE,
		APPROVAL_TYPE,
		APPROVAL_REF_NUM
	from	device_collection_member
	where	device_collection_id in
		(select device_collection_id from device_collection
			where device_collection_type = 'appgroup'
		)
WITH READ ONLY;


