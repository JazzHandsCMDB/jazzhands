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


create or replace view v_account
as
select
a.account_id,
ps.external_hr_id,
ps.payroll_id,
login,
first_name,
middle_name,
last_name,
name_suffix,
preferred_first_name,
preferred_last_name,
account_status,
account_type,
employee_id,
position_title,
a.company_id person_company_id,
c.company_code person_company_code,
c.company_name person_company_name,
badge_id,
gender,
hire_date,
pc.termination_date,
dmd.dept_id,
dmd.dept_code,
dmd.cost_center,
dmd.dept_company_id,
dmd.dept_company_code,
dmd.dept_company_name,
dmd.reporting_type,
dmd.name dept_name,
dmd.dept_start_date,
dmd.dept_finish_date,
a.dn_name,
a.manager_account_id
FROM
  account a
  left join person_company pc
	on a.person_id = pc.person_id
  left join company c
	on pc.company_id = c.company_id
  left join
  ( select dm.account_id,dm.reporting_type,dm.dept_id, d.dept_code,d.cost_center, d.company_id dept_company_id,
	c2.company_code dept_company_code, c2.company_name  dept_company_name,
	d.name,dm.start_date dept_start_date, dm.finish_date dept_finish_date
	from Account_Collection_account uu, department d, 
		Account_Collection u, company c2
	where dm.dept_id=d.dept_id
	and d.company_id=c2.company_id
	and dm.reporting_type='direct'
   ) dmd
	on s.account_id= dmd.account_id 
;

