-- Copyright (c) 2016-2017, Todd M. Kover
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

CREATE OR REPLACE VIEW v_person_company AS
SELECT pc.company_id,
	pc.person_id,
	pc.person_company_status,
	pc.person_company_relation,
	pc.is_exempt,
	pc.is_management,
	pc.is_full_time,
	pc.description,
	empid.attribute_value AS employee_id,
	payid.attribute_value AS payroll_id,
	hrid.attribute_value AS external_hr_id,
	pc.position_title,
	badge.attribute_value AS badge_system_id,
	pc.hire_date,
	pc.termination_date,
	pc.manager_person_id,
	super.attribute_value_person_id AS supervisor_person_id,
	pc.nickname,
	pc.data_ins_user,
	pc.data_ins_date,
	pc.data_upd_user,
	pc.data_upd_date
FROM	person_company pc
	LEFT JOIN (SELECT *
		FROM person_company_attribute 
		WHERE person_company_attribute_name = 'employee_id'
		) empid USING (company_id, person_id)
	LEFT JOIN (SELECT *
		FROM person_company_attribute 
		WHERE person_company_attribute_name = 'payroll_id'
		) payid USING (company_id, person_id)
	LEFT JOIN (SELECT *
		FROM person_company_attribute 
		WHERE person_company_attribute_name = 'badge_system_id'
		) badge USING (company_id, person_id)
	LEFT JOIN (SELECT *
		FROM person_company_attribute 
		WHERE person_company_attribute_name = 'supervisor_id'
		) super USING (company_id, person_id)
	LEFT JOIN (SELECT *
		FROM person_company_attribute 
		WHERE person_company_attribute_name = 'external_hr_id'
		) hrid USING (company_id, person_id)
;

ALTER VIEW v_person_company alter column is_exempt set default true;
ALTER VIEW v_person_company alter column is_management set default false;
ALTER VIEW v_person_company alter column is_full_time set default true;
