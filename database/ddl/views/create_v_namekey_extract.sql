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


--select 'SYSTEM_USER_ID|LOGIN|SYSTEM_USER_STATUS|SYSTEM_USER_TYPE|HIRE_DATE|TERMINATION_DATE|DEPT_NAME|MANAGER_SYSTEM_USER_ID|'||
--'MANAGER_FULL_NAME|FIRST_NAME|MIDDLE_NAME|LAST_NAME|NAME_SUFFIX|COMPANY_ID|COMPANY_NAME|ACCOUNT_PREFIX|OFFICE_SITE|HAS_REPORTS|HAS_CCA_ACCESS|HAS_RT_ACCESS'
--from dual;


create or replace  view v_namekey_extract
as
select su.system_user_id,
        su.login,
        su.system_user_status,
        su.system_user_type,
        su.hire_date,
        su.termination_date,
	d.dept_id,
	d.dept_code,
	d.cost_center,
	d.dept_company_id,
        d.name dept_name,
        su.manager_system_user_id,
       NVL(m.PREFERRED_FIRST_NAME,m.FIRST_NAME)||decode(m.middle_name,NULL,' ',' '||m.middle_name||' ')||
       NVL(m.PREFERRED_LAST_NAME,m.LAST_NAME)||decode (m.name_suffix,NULL,NULL,' '||m.name_suffix)
MANAGER_FULL_NAME,
       NVL(su.PREFERRED_FIRST_NAME,su.FIRST_NAME) FIRST_NAME,
        su.middle_name,
       NVL(su.PREFERRED_LAST_NAME,su.LAST_NAME) LAST_NAME,
        su.name_suffix,
        su.company_id,
        c.company_name,
        c.account_prefix,
        sul.office_site,
        (CASE
                WHEN empcount.tally <= 0 or empcount.tally is NULL THEN 'N'
                ELSE 'Y'
         END) HAS_REPORTS,
        decode(cca_access.system_user_id,NULL,'N','Y') HAS_CCA_ACCESS,
        decode(rt_access.system_user_id,NULL,'N','Y') HAS_RT_ACCESS,
        su.employee_id
from system_user su,
	val_system_user_type vsu,
        system_user m,
          ( select dm.system_user_id,dm.reporting_type,dm.dept_id, d.dept_code,d.cost_center, d.company_id dept_company_id,
                c2.company_code dept_company_code, c2.company_name  dept_company_name,
                d.name,dm.start_date dept_start_date, dm.finish_date dept_finish_date
                from dept_member dm, dept d, company c2
                where dm.dept_id=d.dept_id
                and d.company_id=c2.company_id
                and dm.reporting_type='direct'
           ) d,
        company c,
        (select system_user_id,office_site from
        system_user_location
        where system_user_location_type='office' )sul,
           ( select manager_system_user_id as system_user_id, count(*) as tally
               from system_user
             where manager_system_user_id is not NULL
             and system_user_type in ('employee','contractor','vendor','outsourcer')
             group by manager_system_user_id
           ) empcount,
        (
        select distinct(su2.system_user_id)
        FROM    company c,
                uclass u,
               V_UCLASS_USER_EXPANDED VUUE,
               UCLASS_PROPERTY_OVERRIDE UPO,
                val_system_user_type vsut,
                system_user su2
        WHERE
               su2.SYSTEM_USER_ID = VUUE.SYSTEM_USER_ID
               AND VUUE.UCLASS_ID = UPO.UCLASS_ID
                and vuue.uclass_id=u.uclass_id
                and su2.company_id=c.company_id
                and su2.system_user_type=vsut.system_user_type
               AND UPO.UCLASS_PROPERTY_TYPE = 'CCARight'
                and (  SU2.SYSTEM_USER_TYPE IN ('employee',
                                               'outsourcer')
                        or
                        exists (select 1
                                from
                                        V_UCLASS_USER_EXPANDED VUUE2,
                                        UCLASS_PROPERTY_OVERRIDE UPO2
                                where VUUE2.SYSTEM_USER_ID = SU2.SYSTEM_USER_ID
                                and VUUE2.uclass_id=UPO2.uclass_id
                                AND UPO2.UCLASS_PROPERTY_NAME = 'ForceAccount'
                                and UPO2.UCLASS_PROPERTY_TYPE = 'CCAForceCreation')
                        )
                and vsut.is_person='Y'
                ) cca_access,
        (        select distinct s.system_user_id
        from system_user s, v_uclass_user_expanded v, uclass u, company c
        where s.system_user_id = v.system_user_id
        and v.uclass_id = u.uclass_id
        and s.company_id = c.company_id
        and s.system_user_type in
        ('employee', 'contractor', 'vendor', 'outsourcer')
        and u.uclass_type = 'rt-group'
        and u.name = 'Privileged'
        ) RT_ACCESS
where su.system_user_id=d.system_user_id(+)
and su.system_user_type=vsu.system_user_type
and vsu.is_person='Y'
and su.company_id = c.company_id (+)
and su.system_user_id=cca_access.system_user_id (+)
and su.system_user_id=rt_access.system_user_id (+)
and su.manager_system_user_id=m.system_user_id (+)
and su.system_user_id=sul.system_user_id (+)
and su.system_user_id=empcount.system_user_id (+);



