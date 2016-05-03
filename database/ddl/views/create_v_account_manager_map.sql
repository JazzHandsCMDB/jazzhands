-- Copyright (c) 2015-2016, Todd M. Kover
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

CREATE OR REPLACE VIEW v_account_manager_map AS
WITH dude_base AS (
	SELECT a.login, a.account_id, person_id, a.company_id,
		a.account_realm_id,
	    coalesce(p.preferred_first_name, p.first_name) as first_name,
	    coalesce(p.preferred_last_name, p.last_name) as last_name,
	    p.middle_name,
	    pc.manager_person_id, pc.employee_id
	FROM    account a
		INNER JOIN person_company pc USING (company_id,person_id)
		INNER JOIN person p USING (person_id)
	WHERE   a.is_enabled = 'Y'
	AND		pc.person_company_relation = 'employee'
	AND     a.account_role = 'primary' and a.account_type = 'person'
), dude AS (
	SELECT *,
		concat(first_name, ' ', last_name, ' (', login, ')') as human_readable
	FROM dude_base
) SELECT a.*, mp.account_id as manager_account_id, mp.login as manager_login,
	concat(mp.first_name, ' ', mp.last_name, ' (', mp.login, ')') as manager_human_readable,
	mp.last_name as manager_last_name,
	mp.middle_name as manager_middle_name,
	mp.first_name as manger_first_name,
	mp.employee_id as manager_employee_id,
	mp.company_id as manager_company_id
FROM dude a
	INNER JOIN dude mp ON mp.person_id = a.manager_person_id
		and mp.account_realm_id = a.account_realm_id
;
