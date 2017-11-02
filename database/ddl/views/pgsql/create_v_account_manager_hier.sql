-- Copyright (c) 2017, Todd M. Kover
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
-- arguably this should use v_person_company_hier but work needs to be
-- done to reconcile that against this, since that is used to walk "down"
-- from the manager to employees and not up from the employees.
--
CREATE OR REPLACE VIEW v_account_manager_hier AS
WITH RECURSIVE phier (
	level, person_id, company_id, intermediate_manager_person_id, manager_person_id
) AS (
		SELECT	0 as level,
			person_id, 
			company_id,
			manager_person_id as intermediate_manager_person_id,
			manager_person_id,
			ARRAY[person_id] as array_path,
			false as cycle
		FROM	v_person_company
	UNION
		SELECT	x.level + 1 as level,
			x.person_id, 
			x.company_id, 
			m.manager_person_id AS intermediate_manager_person_id,
			m.manager_person_id,
			x.array_path || m.manager_person_id as array_path,
			m.manager_person_id = ANY(array_path) as cycle
		FROM	v_person_company m
			JOIN phier x ON x.intermediate_manager_person_id = m.person_id
		WHERE	not cycle
		AND m.manager_person_id is not NULL
) SELECT
	level,
	account_id,
	person_id,
	company_id,
	login,
	concat(p.first_name, ' ', p.last_name, ' (', a.login, ')') 
		AS human_readable,
	account_realm_id,
	manager_account_id,
	manager_login,
	manager_person_id,
	manager_company_id,
	manager_human_readable,
	array_path
FROM	account a
	JOIN phier h USING (person_id, company_id)
	JOIN v_person p USING (person_id)
	-- possible for someone not to have a manager, like the CEO...
	LEFT JOIN (
		SELECT	person_id as manager_person_id,
			a.account_id as manager_account_id,
			concat(p.first_name, ' ', p.last_name, ' (', a.login, ')') 
				AS manager_human_readable,
			p.first_name as manager_first_name,
			p.last_name as manager_last_name,
			a.account_role,
			a.company_id as manager_company_id,
			a.account_realm_id,
			a.login as manager_login
		FROM	account a
			JOIN v_person p USING (person_id)
		WHERE account_role = 'primary' and a.account_type = 'person'
	) m USING (manager_person_id, account_realm_id, account_role)
WHERE account_role = 'primary' and a.account_type = 'person'
;
