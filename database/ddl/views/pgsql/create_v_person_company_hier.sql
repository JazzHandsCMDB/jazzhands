-- Copyright (c) 2015, Todd M. Kover
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

CREATE OR REPLACE VIEW v_person_company_hier AS
WITH RECURSIVE pc_recurse (
	level,
	person_id,
	subordinate_person_id,
	intermediate_person_id,
	person_company_relation,
	array_path,
	rvs_array_path,
	cycle
) AS (
		SELECT DISTINCT
			0 							as level,
			manager_person_id			as person_id,
			person_id					as subordinate_person_id,
			manager_person_id			as intermediate_person_id,
			person_company_relation		as person_company_relation,
			ARRAY[manager_person_id] 	as array_path,
			ARRAY[manager_person_id] 	as rvs_array_path,
			false
		FROM
			person_company pc
			JOIN val_person_status vps  on
				pc.person_company_status = vps.person_status
		WHERE	is_enabled = 'Y'
	UNION ALL
		SELECT 
			x.level + 1 				as level,
			x.person_id					as person_id,
			pc.person_id				as subordinate_person_id,
			pc.manager_person_id		as intermediate_person_id,
			pc.person_company_relation	as person_company_relation,
			x.array_path || pc.person_id as array_path,
			pc.person_id || x.rvs_array_path 
				as rvs_array_path,
			pc.person_id = ANY(array_path) as cycle
		FROM
			pc_recurse x 
			JOIN person_company pc ON
				x.subordinate_person_id = pc.manager_person_id
			JOIN val_person_status vps  on
				pc.person_company_status = vps.person_status
		WHERE
			is_enabled = 'Y'
		AND
			NOT cycle 
) SELECT
	level,
	person_id,
	subordinate_person_id,
	intermediate_person_id,
	person_company_relation,
	array_path,
	rvs_array_path,
	cycle
	FROM
		pc_recurse
