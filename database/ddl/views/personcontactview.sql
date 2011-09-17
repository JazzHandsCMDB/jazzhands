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


create or replace view v_peson_phone
as
select
	a.account_id,
	pc.external_hr_id,
	pc.payroll_id,
	login,
	first_name,
	middle_name,
	last_name,
	p.account_phone_id,
	p.iso_country_code,
	p.phone_number,
	p.phone_number_type,
	p.phone_type_order,
	name_suffix,
	preferred_first_name,
	preferred_last_name,
	account_status,
	account_type,
	position_title,
	a.company_id person_company_id,
	c.company_code person_company_code,
	c.company_name person_company_name,
	gender,
	dmd.dept_id,
	dmd.name dept_name,
	dmd.dept_code,
	dmd.dept_company_id,
	dmd.dept_company_code,
	dmd.dept_company_name,
	dmd.reporting_type,
	a.dn_name
FROM
  account a
  left join person_company pc
	on a.person_id = pc.person_id
  left join person_contact p
	on a.person_id=p.account_id
  left join company c
	on pc.company_id=c.company_id
  left join ( select dm.account_id,dm.reporting_type,dm.dept_id, 
	d.dept_code, d.company_id dept_company_id,
	c2.company_code dept_company_code, c2.company_name  dept_company_name,
	d.name,dm.start_date dept_start_date, dm.finish_date dept_finish_date
	from dept_member dm, dept d, company c2
	where dm.dept_id=d.dept_id
	and d.company_id=c2.company_id
	and dm.reporting_type='direct'
   ) dmd
	on a.account_id= dmd.account_id
;

