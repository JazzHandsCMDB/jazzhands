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
-- $Id$

-- drop materialized view log on uclass_hier;
-- drop materialized view mv_uclass_user_expanded_detail;

-- create materialized view log on uclass_hier
-- 	with rowid (uclass_id, child_uclass_id) including new values;
-- create materialized view log on uclass_dept
-- 	with rowid (uclass_id, dept_id) including new values;
-- create materialized view log on dept
-- 	with rowid (dept_id, parent_dept_id) including new values;
-- create materialized view log on uclass_user
-- 	with rowid (uclass_id, system_user_id) including new values;

drop materialized view mv_uclass_user_expanded_detail;

create materialized view mv_uclass_user_expanded_detail
build immediate
refresh complete
start with sysdate
next sysdate + 1/8
with primary key
	AS (
	SELECT uclass_id,system_user_id,
		decode (uclass_is_leaf,1,decode(dept_is_leaf,0,'UclassAssignedToParentDept',1,'UclassAssignedToDept','UclassAssignedToPerson'),
					0,decode(dept_is_leaf,0,'ParentUclassOfUclassAssignedToParentDept',1,'ParentUclassOfUclassAssignedToDept','ParentUclassOfUclassAssignedToPerson'),
			'unknown'
			) assign_method,
		uclass_is_leaf,
		uclass_inherit_path,
		dept_is_leaf,
		dept_inherit_path,
		dept_level,
		uclass_level
	FROM (
	SELECT dum.uclass_id,
		dm.system_user_id, 
		uclass_is_leaf,
		uclass_inherit_path,
		dept_is_leaf,
		dept_inherit_path,
		dept_level,
		uclass_level
	FROM
	(
		SELECT dhe.child_dept_id AS dept_id, uhe.uclass_id, uhe.uclass_is_leaf, uhe.uclass_inherit_path, dhe.dept_is_leaf,
			dhe.dept_inherit_path, dhe.dept_level, uhe.uclass_level
		FROM
			(
				SELECT uclass_id, child_uclass_id, uclass_is_leaf,uclass_inherit_path,uclass_level FROM
			(
				SELECT uclass_id, uclass_id AS child_uclass_id, 1 uclass_is_leaf, to_char(uclass_id ) uclass_inherit_path, 0 uclass_level FROM uclass
					UNION
					SELECT CONNECT_BY_ROOT uclass_id AS uclass_id,
						child_uclass_id,
						0 uclass_is_leaf,
						SYS_CONNECT_BY_PATH(uclass_id,'/')||'/'||child_uclass_id uclass_inherit_path,
						LEVEL uclass_level
					FROM  uclass_hier
					CONNECT BY PRIOR child_uclass_id = uclass_id
				)
			) uhe
		INNER JOIN uclass_dept ud ON ud.uclass_id = uhe.child_uclass_id
		INNER JOIN
		(
			SELECT dept_id AS dept_id, dept_id AS child_dept_id , 1 dept_is_leaf, dept_code dept_inherit_path, 0 dept_level FROM dept
			UNION
			SELECT CONNECT_BY_ROOT d1.parent_dept_id AS dept_id,
					d1.dept_id AS child_dept_id,
			-- CONNECT_BY_ISLEAF generates 0600 error
			0 dept_is_leaf, --CONNECT_BY_ISLEAF dept_is_leaf, 
			SYS_CONNECT_BY_PATH(d2.dept_code,'/')||'/'||d1.dept_code dept_inherit_path,
			LEVEL dept_level
			FROM  (SELECT * FROM dept WHERE parent_dept_id IS NOT NULL) d1,
			dept d2
		where d1.parent_dept_id=d2.dept_id
			CONNECT BY PRIOR d1.dept_id = d1.parent_dept_id
		) dhe
			ON ud.dept_id = dhe.dept_id
	) dum
	INNER JOIN dept_member dm 
	ON (
		dum.dept_id = dm.dept_id
		AND (dm.finish_date IS NULL OR dm.finish_date >= sysdate)
		AND  (dm.start_date IS NULL OR dm.start_date <= sysdate)
	)
	UNION
	-- Add Uclasses assigned via Uclass User and inherited via Uclass User
	SELECT uch.uclass_id,
		uu.system_user_id,
		uclass_is_leaf,
		uclass_inherit_path,
		dept_is_leaf,
		dept_inherit_path,
		dept_level,
		uclass_level
	FROM
		(
			SELECT CONNECT_BY_ROOT uclass_id AS uclass_id,
				child_uclass_id,
				-- CONNECT_BY_ISLEAF generates 0600 error
				0 uclass_is_leaf,  --CONNECT_BY_ISLEAF uclass_is_leaf,
				SYS_CONNECT_BY_PATH(uclass_id,'/')||'/'||child_uclass_id uclass_inherit_path,
				(-1) dept_is_leaf,
				NULL dept_inherit_path,
				0 dept_level,
				LEVEL uclass_level
			FROM uclass_hier
			CONNECT BY PRIOR child_uclass_id = uclass_id
		) uch
	INNER JOIN uclass_user uu ON uch.child_uclass_id = uu.uclass_id
	UNION
	SELECT uu.uclass_id,
		uu.system_user_id,
		1 uclass_is_leaf,
		to_char(uclass_id) uclass_inherit_path,
		(-1) dept_is_leaf,
		NULL dept_inherit_path,
		0 dept_level,
		0 uclass_level
	FROM uclass_user uu
	)
);

CREATE INDEX IDX_MV_UC_Us_Exp_D_SysUID ON MV_UClass_User_Expanded_Detail (
	System_User_ID
) TABLESPACE INDEX01;

CREATE INDEX IDX_MV_UC_Us_Exp_D_UCID ON MV_UClass_User_Expanded_Detail (
	UClass_ID
) TABLESPACE INDEX01;

CREATE INDEX IDX_MV_UC_Us_Exp_D_SysUID_UCID ON MV_UClass_User_Expanded_Detail (
	System_User_ID,
	UClass_ID
) TABLESPACE INDEX01;

--  EXECUTE DBMS_MVIEW.REFRESH('mv_uclass_user_expanded_detail');
