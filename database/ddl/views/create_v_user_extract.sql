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
--
-- $Id$
--


create or replace view v_user_extract
as
select
	s.system_user_id,
	x.external_hr_id,
	s.login,
	coalesce(s.preferred_first_name,s.first_name) first_name,
	s.middle_name,
	coalesce(s.preferred_last_name,s.last_name) last_name,
	(s.login||'@example.com') EMAIL_ADDRESS,
	s.name_suffix,
	s.system_user_status,
	s.system_user_type,
	s.employee_id,
	s.position_title,
	s.company_id person_company_id,
	c.company_name person_company_name,
	s.hire_date,
	s.termination_date,
	s.manager_system_user_id,
	s2.login manager_login,
	dmd.dept_code,
	dmd.dept_name,
	dmd.dept_company_id,
	dmd.dept_company_name,
	sul.office_site,
	sul.city,
	sul.state,
	sul.country,
	(CASE
		WHEN empcount.tally <= 0 or empcount.tally is NULL THEN 'N'
		ELSE 'Y'
 	END) as has_reports
FROM
  system_user s
  left join system_user_xref x
	on s.system_user_id = x.system_user_id
  left join system_user s2
	on s.manager_system_user_id = s2.system_user_id
  left join ( select sl.system_user_id,sl.office_site,sl.city,
		sl.state,sl.country
    from system_user_location sl
    where sl.system_user_location_type='office'
  ) sul
	on s.system_user_id= sul.system_user_id
  left join company c
	on s.company_id=c.company_id
  left join ( select dm.system_user_id,dm.reporting_type,dm.dept_id, 
		d.dept_code, d.company_id dept_company_id,
	c2.company_code dept_company_code, c2.company_name  dept_company_name,
	d.name dept_name
	from dept_member dm, dept d, company c2
	where dm.dept_id=d.dept_id
	and d.company_id=c2.company_id
	and dm.reporting_type='direct'
   ) dmd
	on s.system_user_id= dmd.system_user_id
   left join ( select manager_system_user_id as system_user_id, 
		count(*) as tally
       from system_user
     where manager_system_user_id is not NULL
     and system_user_type in ('employee','contractor','vendor')
     group by manager_system_user_id
   ) empcount
	on s.system_user_id = empcount.system_user_id
where
	s.system_user_type in ('employee','contractor','vendor')
;

