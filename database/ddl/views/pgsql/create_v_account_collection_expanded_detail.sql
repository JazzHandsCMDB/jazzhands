-- Copyright (c) 2013 Matthew Ragan
-- Copyright (c) 2019 Todd Kover
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

CREATE OR REPLACE VIEW v_account_collection_expanded_detail AS
WITH RECURSIVE var_recurse (
	root_account_collection_id,
	account_collection_id,
	account_collection_level,
	department_level,
	assignment_method,
	array_path,
	cycle
	) AS (
		SELECT
			ac.account_collection_id as account_collection_id,
			ac.account_collection_id as root_account_collection_id,
			CASE ac.account_collection_type
				WHEN 'department' THEN 0 
				ELSE 1
			END as account_collection_level,
			CASE ac.account_collection_type
				WHEN 'department' THEN 1
				ELSE 0
			END as department_level,
			CASE ac.account_collection_type
				WHEN 'department' THEN 'DirectDepartmentAssignment'
				ELSE 'DirectAccountCollectionAssignment'
			END as assignment_method,
			ARRAY[ac.account_collection_id] as array_path,
			false
		FROM
			account_collection ac
	UNION ALL
		SELECT
			x.root_account_collection_id as root_account_collection_id,
			ach.account_collection_id as account_collection_id,
			CASE ac.account_collection_type
				WHEN 'department' THEN x.department_level
				ELSE x.account_collection_level + 1
			END as account_collection_level,
			CASE ac.account_collection_type
				WHEN 'department' THEN x.department_level + 1
				ELSE x.department_level
			END as department_level,
			CASE
				WHEN ac.account_collection_type = 'department' 
					THEN 'AccountAssignedToChildDepartment'
				WHEN x.department_level > 1 AND x.account_collection_level > 0
					THEN 'ChildDepartmentAssignedToChildAccountCollection'
				WHEN x.department_level > 1
					THEN 'ChildDepartmentAssignedToAccountCollection'
				WHEN x.department_level = 1 and x.account_collection_level > 0
					THEN 'DepartmentAssignedToChildAccountCollection'
				WHEN x.department_level = 1
					THEN 'DepartmentAssignedToAccountCollection'
				ELSE 'AccountAssignedToChildAccountCollection'
				END as assignment_method,
			x.array_path || ach.account_collection_id as array_path,
			ach.account_collection_id = ANY(array_path)
		FROM
			var_recurse x JOIN account_collection_hier ach ON
				x.account_collection_id = ach.child_account_collection_id JOIN
			account_collection ac ON 
				ach.account_collection_id = ac.account_collection_id
		WHERE
			NOT cycle
) SELECT
		account_collection_id,
		root_account_collection_id,
		account_collection_level as account_collection_level,
		department_level department_level,
		assignment_method,
		array_to_string(array_path, '/') as text_path,
		array_path
	FROM var_recurse;
