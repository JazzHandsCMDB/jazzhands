-- Copyright (c) 2012-2019, Todd M. Kover
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

CREATE OR REPLACE VIEW v_account_collection_property_expanded AS
	SELECT
		root_account_collection_id as account_collection_id,
		property_id,
		property_name,
		property_type,
		property_value,
		property_value_timestamp,
		property_value_account_collection_id,
		property_value_netblock_collection_id,
		property_value_password_type,
		property_value_person_id,
		property_value_token_collection_id,
		property_rank,
		CASE is_multivalue WHEN 'N' THEN false WHEN 'Y' THEN true END 
			is_multivalue,
		CASE ac.account_collection_type
			WHEN 'per-account' THEN 0
			ELSE CASE assignment_method
				WHEN 'DirectAccountCollectionAssignment' THEN 10
				WHEN 'DirectDepartmentAssignment' THEN 200
				WHEN 'DepartmentAssignedToAccountCollection' THEN 300
						+ department_level + account_collection_level
				WHEN 'AccountAssignedToChildDepartment' THEN 400
						+ department_level 
				WHEN 'AccountAssignedToChildAccountCollection' THEN 500
						+ account_collection_level
				WHEN 'DepartmentAssignedToChildAccountCollection' THEN 600
						+ department_level + account_collection_level
				WHEN 'ChildDepartmentAssignedToAccountCollection' THEN 700
						+ department_level + account_collection_level
				WHEN 'ChildDepartmentAssignedToChildAccountCollection' THEN 800
						+ department_level + account_collection_level
				ELSE 999
			END END as assignment_rank
	FROM
		v_account_collection_expanded_detail JOIN
		account_collection ac USING (account_collection_id) JOIN
		v_property USING (account_collection_id) JOIN
		val_property USING (property_name, property_type);
