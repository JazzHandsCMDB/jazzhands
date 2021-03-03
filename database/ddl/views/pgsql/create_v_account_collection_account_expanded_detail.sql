-- Copyright (c) 2013, Matthew Ragan
-- Copyright (c) 2019, Todd Kover
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


-- NOTE: direct_account_collection_parent_id is a better name for
-- root_account_collection_id
--
-- account_collection_id ends up being the one that is the ultimate parent
-- and what someone just looking at the view may think of the root ("all the
-- accounts that are part of this account collection")
--
-- the nomenclature probably comes from oracle's connect by root
CREATE OR REPLACE VIEW v_account_collection_account_expanded_detail AS
WITH RECURSIVE var_recurse(
	account_collection_id,
	root_account_collection_id,
	account_id,
	acct_coll_level,
	dept_level,
	assign_method,
	array_path,
	cycle
) AS (
	SELECT 
		aca.account_collection_id,
		aca.account_collection_id,
		aca.account_id, 
		CASE ac.account_collection_type
			WHEN 'department'::text THEN 0
			ELSE 1
		END,
		CASE ac.account_collection_type
			WHEN 'department'::text THEN 1
			ELSE 0
		END,
		CASE ac.account_collection_type
			WHEN 'department'::text THEN 'DirectDepartmentAssignment'::text
			ELSE 'DirectAccountCollectionAssignment'::text
		END,
		ARRAY[aca.account_collection_id],
		false
	FROM
		account_collection ac JOIN
		v_account_collection_account aca USING (account_collection_id)
	UNION ALL 
	SELECT
		ach.account_collection_id,
		x.root_account_collection_id,
		x.account_id, 
		CASE ac.account_collection_type
			WHEN 'department'::text THEN x.dept_level
			ELSE x.acct_coll_level + 1
		END,
		CASE ac.account_collection_type
			WHEN 'department'::text THEN x.dept_level + 1
			ELSE x.dept_level
		END,
		CASE
			WHEN ac.account_collection_type::text = 'department'::text 
				THEN 'AccountAssignedToChildDepartment'::text
			WHEN x.dept_level > 1 AND x.acct_coll_level > 0 
				THEN 'ParentDepartmentAssignedToParentAccountCollection'::text
			WHEN x.dept_level > 1 
				THEN 'ParentDepartmentAssignedToAccountCollection'::text
			WHEN x.dept_level = 1 AND x.acct_coll_level > 0 
				THEN 'DepartmentAssignedToParentAccountCollection'::text
			WHEN x.dept_level = 1 
				THEN 'DepartmentAssignedToAccountCollection'::text
			ELSE 'AccountAssignedToParentAccountCollection'::text
		END AS assign_method, 
		x.array_path || ach.account_collection_id AS array_path, 
		ach.account_collection_id = ANY (x.array_path)
	FROM
		var_recurse x 
		JOIN account_collection_hier ach 
			ON x.account_collection_id = ach.child_account_collection_id JOIN
		account_collection ac 
			ON ach.account_collection_id = ac.account_collection_id
	WHERE
		NOT x.cycle
) SELECT 
	account_collection_id,
	root_account_collection_id,
	account_id,
	acct_coll_level,
	dept_level,
	assign_method,
	array_to_string(var_recurse.array_path, '/'::text) AS text_path,
	array_path
FROM
	var_recurse;

