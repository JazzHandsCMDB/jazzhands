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
--
-- This was for gsievers, so he could query data directly, versus using web tools, due to vision issues/ease of use

CREATE OR REPLACE FORCE VIEW v_limited_users (system_user_id,
external_hr_id,
payroll_id,
login,
first_name,
middle_name,
last_name,
name_suffix,
preferred_first_name,
preferred_last_name,
system_user_status,
system_user_type,
employee_id,
position_title,
person_company_id,
person_company_code,
person_company_name,
badge_id,
gender,
hire_date,
termination_date,
dept_id,
dept_code,
cost_center,
dept_company_id,
dept_company_code,
dept_company_name,
reporting_type,
dept_name,
dept_start_date,
dept_finish_date,
dn_name,
manager_system_user_id
)
AS
   SELECT "SYSTEM_USER_ID", "EXTERNAL_HR_ID", "PAYROLL_ID", "LOGIN", 
	  "FIRST_NAME",
          "MIDDLE_NAME", "LAST_NAME", "NAME_SUFFIX", "PREFERRED_FIRST_NAME",
          "PREFERRED_LAST_NAME", "SYSTEM_USER_STATUS", "SYSTEM_USER_TYPE",
          "EMPLOYEE_ID", "POSITION_TITLE", "PERSON_COMPANY_ID",
          "PERSON_COMPANY_CODE", "PERSON_COMPANY_NAME", "BADGE_ID", "GENDER",
          "HIRE_DATE", "TERMINATION_DATE", "DEPT_ID", "DEPT_CODE",
          "COST_CENTER", "DEPT_COMPANY_ID", "DEPT_COMPANY_CODE",
          "DEPT_COMPANY_NAME", "REPORTING_TYPE", "DEPT_NAME",
          "DEPT_START_DATE", "DEPT_FINISH_DATE", "DN_NAME",
          "MANAGER_SYSTEM_USER_ID"
     FROM v_system_user
    WHERE system_user_type IN ('employee', 'contractor', 'vendor');



-- GRANT SELECT ON V_LIMITED_USERS TO RO_ROLE;

