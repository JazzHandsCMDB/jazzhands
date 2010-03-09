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
-- These views are on the audit tables, transforming the time series data into time span records.
--



CREATE OR REPLACE VIEW v_aud$dept AS 
SELECT  a.dept_id to_dept_id,
	a.name to_name,
	a.parent_dept_id to_parent_dept_id,
	a.manager_system_user_id to_manager_system_user_id,
	a.company_id to_company_id,
	a.default_badge_type_id to_default_badge_type_id,
	a.dept_ou to_dept_ou,
	a.is_active to_is_active,
	a.dept_code to_dept_code,
	a.cost_center to_cost_center,
	a.aud#timestamp to_aud#timestamp,
	b.dept_id from_dept_id,
	b.name from_name,
	b.parent_dept_id from_parent_dept_id,
	b.manager_system_user_id from_manager_system_user_id,
	b.company_id from_company_id,
	b.default_badge_type_id from_default_badge_type_id,
	b.dept_ou from_dept_ou,
	b.is_active from_is_active,
	b.dept_code from_dept_code,
	b.cost_center from_cost_center,
	b.aud#timestamp from_aud#timestamp
FROM aud$dept a, aud$dept b
WHERE 
    a.dept_id=b.dept_id
AND a.aud#timestamp > b.aud#timestamp
AND not exists (select 1 from aud$dept c
		where c.dept_id=a.dept_id 
		and c.rowid != a.rowid
		and c.aud#timestamp > b.aud#timestamp
		and c.aud#timestamp <= a.aud#timestamp )
UNION
SELECT 
	NULL to_dept_id,
        NULL to_name,
        NULL to_parent_dept_id,
        NULL to_manager_system_user_id,
        NULL to_company_id,
        NULL to_default_badge_type_id,
        NULL to_dept_ou,
        NULL to_is_active,
        NULL to_dept_code,
        NULL to_cost_center,
        NULL to_aud#timestamp,
	d.dept_id from_dept_id,
	d.name from_name,
	d.parent_dept_id from_parent_dept_id,
	d.manager_system_user_id from_manager_system_user_id,
	d.company_id from_company_id,
	d.default_badge_type_id from_default_badge_type_id,
	d.dept_ou from_dept_ou,
	d.is_active from_is_active,
	d.dept_code from_dept_code,
	d.cost_center from_cost_center,
        d.aud#timestamp from_aud#timestamp
FROM aud$dept d
WHERE not exists (select 1 from aud$dept e
		where e.dept_id=d.dept_id
		and e.aud#timestamp > d.aud#timestamp);






CREATE OR REPLACE VIEW v_aud$uclass AS 
SELECT  a.uclass_id to_uclass_id,
	a.uclass_type to_uclass_type,
	a.name to_name,
	a.description to_description,
	a.aud#timestamp to_aud#timestamp,
	b.uclass_id from_uclass_id,
	b.uclass_type from_uclass_type,
	b.name from_name,
	b.description from_description,
	b.aud#timestamp from_aud#timestamp
FROM aud$uclass a, aud$uclass b
WHERE 
    a.uclass_id=b.uclass_id
AND a.aud#timestamp > b.aud#timestamp
AND not exists (select 1 from aud$uclass c
		where c.uclass_id=a.uclass_id 
		and c.rowid != a.rowid
		and c.aud#timestamp > b.aud#timestamp
		and c.aud#timestamp <= a.aud#timestamp )
UNION
SELECT  NULL to_uclass_id,
	NULL to_uclass_type,
	NULL to_name,
	NULL to_description,
	NULL to_aud#timestamp,
	d.uclass_id from_uclass_id,
	d.uclass_type from_uclass_type,
	d.name from_name,
	d.description from_description,
	d.aud#timestamp from_aud#timestamp
FROM aud$uclass d
WHERE not exists (select 1 from aud$uclass e
		where e.uclass_id=d.uclass_id
		and e.aud#timestamp > d.aud#timestamp);



-- This is problematic..

CREATE OR REPLACE VIEW v_aud$uclass_dept AS 
SELECT  a.uclass_id to_uclass_id,
	a.dept_id to_dept_id,
	a.aud#timestamp to_aud#timestamp,
	b.uclass_id from_uclass_id,
	b.dept_id from_dept_id,
	b.aud#timestamp from_aud#timestamp
FROM aud$uclass_dept a, aud$uclass_dept b
WHERE 
    a.uclass_id=b.uclass_id
AND a.dept_id=b.dept_id
AND a.aud#timestamp > b.aud#timestamp
AND not exists (select 1 from aud$uclass_dept c
		where c.uclass_id=a.uclass_id 
		and c.dept_id=a.dept_id 
		and c.rowid != a.rowid
		and c.aud#timestamp > b.aud#timestamp
		and c.aud#timestamp <= a.aud#timestamp )
UNION
SELECT  NULL to_uclass_id,
        NULL to_dept_id,
        NULL to_aud#timestamp,
        d.uclass_id from_uclass_id,
        d.dept_id from_dept_id,
        d.aud#timestamp from_aud#timestamp
FROM aud$uclass_dept d
WHERE not exists (select 1 from aud$uclass_dept e
		where e.uclass_id=d.uclass_id
		and e.dept_id=d.dept_id
		and e.aud#timestamp > d.aud#timestamp);











CREATE OR REPLACE VIEW v_aud$device AS 
SELECT  
a.DEVICE_ID     to_DEVICE_ID,
a.DEVICE_TYPE_ID        to_DEVICE_TYPE_ID,
a.DEVICE_NAME   to_DEVICE_NAME,
a.IDENTIFYING_DNS_RECORD_ID     to_IDENTIFYING_DNS_RECORD_ID,
a.SERIAL_NUMBER to_SERIAL_NUMBER,
a.ASSET_TAG     to_ASSET_TAG,
a.LOCATION_ID   to_LOCATION_ID,
a.DESCRIPTION   to_DESCRIPTION,
a.STATUS        to_STATUS,
a.PRODUCTION_STATE      to_PRODUCTION_STATE,
a.OPERATING_SYSTEM_ID   to_OPERATING_SYSTEM_ID,
a.OWNERSHIP_STATUS      to_OWNERSHIP_STATUS,
a.IS_MONITORED  to_IS_MONITORED,
a.IS_LOCALLY_MANAGED     to_IS_LOCALLY_MANAGED,
a.IS_BASELINED     to_IS_BASELINED,
a.DATE_IN_SERVICE       to_DATE_IN_SERVICE,
a.DATA_INS_USER to_DATA_INS_USER,
a.DATA_INS_DATE to_DATA_INS_DATE,
a.DATA_UPD_USER to_DATA_UPD_USER,
a.DATA_UPD_DATE to_DATA_UPD_DATE,
a.SHOULD_FETCH_CONFIG   to_SHOULD_FETCH_CONFIG,
a.PARENT_DEVICE_ID      to_PARENT_DEVICE_ID,
a.IS_VIRTUAL_DEVICE     to_IS_VIRTUAL_DEVICE,
a.AUTO_MGMT_PROTOCOL    to_AUTO_MGMT_PROTOCOL,
a.VOE_ID        to_VOE_ID,
a.VOE_SYMBOLIC_TRACK_ID to_VOE_SYMBOLIC_TRACK_ID,
a.HOST_ID       to_HOST_ID,
a.PHYSICAL_LABEL        to_PHYSICAL_LABEL,
a.AUD#ACTION    to_AUD#ACTION,
a.AUD#TIMESTAMP to_AUD#TIMESTAMP,
a.AUD#USER      to_AUD#USER,
b.DEVICE_ID     from_DEVICE_ID,
b.DEVICE_TYPE_ID        from_DEVICE_TYPE_ID,
b.DEVICE_NAME   from_DEVICE_NAME,
b.IDENTIFYING_DNS_RECORD_ID     from_IDENTIFYING_DNS_RECORD_ID,
b.SERIAL_NUMBER from_SERIAL_NUMBER,
b.ASSET_TAG     from_ASSET_TAG,
b.LOCATION_ID   from_LOCATION_ID,
b.DESCRIPTION   from_DESCRIPTION,
b.STATUS        from_STATUS,
b.PRODUCTION_STATE      from_PRODUCTION_STATE,
b.OPERATING_SYSTEM_ID   from_OPERATING_SYSTEM_ID,
b.OWNERSHIP_STATUS      from_OWNERSHIP_STATUS,
b.IS_MONITORED  from_IS_MONITORED,
b.IS_LOCALLY_MANAGED     from_IS_LOCALLY_MANAGED,
b.IS_BASELINED     from_IS_BASELINED,
b.DATE_IN_SERVICE       from_DATE_IN_SERVICE,
b.DATA_INS_USER from_DATA_INS_USER,
b.DATA_INS_DATE from_DATA_INS_DATE,
b.DATA_UPD_USER from_DATA_UPD_USER,
b.DATA_UPD_DATE from_DATA_UPD_DATE,
b.SHOULD_FETCH_CONFIG   from_SHOULD_FETCH_CONFIG,
b.PARENT_DEVICE_ID      from_PARENT_DEVICE_ID,
b.IS_VIRTUAL_DEVICE     from_IS_VIRTUAL_DEVICE,
b.AUTO_MGMT_PROTOCOL    from_AUTO_MGMT_PROTOCOL,
b.VOE_ID        from_VOE_ID,
b.VOE_SYMBOLIC_TRACK_ID from_VOE_SYMBOLIC_TRACK_ID,
b.HOST_ID       from_HOST_ID,
b.PHYSICAL_LABEL        from_PHYSICAL_LABEL,
b.AUD#ACTION    from_AUD#ACTION,
b.AUD#TIMESTAMP from_AUD#TIMESTAMP,
b.AUD#USER      from_AUD#USER
FROM aud$device a, aud$device b
WHERE 
    a.device_id=b.device_id
AND a.aud#timestamp > b.aud#timestamp
AND not exists (select 1 from aud$device c
		where c.device_id=a.device_id 
		and c.rowid != a.rowid
		and c.aud#timestamp > b.aud#timestamp
		and c.aud#timestamp <= a.aud#timestamp )
UNION
SELECT  
        NULL    to_DEVICE_ID,
        NULL    to_DEVICE_TYPE_ID,
        NULL    to_DEVICE_NAME,
        NULL    to_IDENTIFYING_DNS_RECORD_ID,
        NULL    to_SERIAL_NUMBER,
        NULL    to_ASSET_TAG,
        NULL    to_LOCATION_ID,
        NULL    to_DESCRIPTION,
        NULL    to_STATUS,
        NULL    to_PRODUCTION_STATE,
        NULL    to_OPERATING_SYSTEM_ID,
        NULL    to_OWNERSHIP_STATUS,
        NULL    to_IS_MONITORED,
        NULL    to_IS_LOCALLY_MANAGED,
        NULL    to_IS_BASELINED,
        NULL    to_DATE_IN_SERVICE,
        NULL    to_DATA_INS_USER,
        NULL    to_DATA_INS_DATE,
        NULL    to_DATA_UPD_USER,
        NULL    to_DATA_UPD_DATE,
        NULL    to_SHOULD_FETCH_CONFIG,
        NULL    to_PARENT_DEVICE_ID,
        NULL    to_IS_VIRTUAL_DEVICE,
        NULL    to_AUTO_MGMT_PROTOCOL,
        NULL    to_VOE_ID,
        NULL    to_VOE_SYMBOLIC_TRACK_ID,
        NULL    to_HOST_ID,
        NULL    to_PHYSICAL_LABEL,
        NULL    to_AUD#ACTION,
        NULL    to_AUD#TIMESTAMP,
        NULL    to_AUD#USER,
d.DEVICE_ID     from_DEVICE_ID,
d.DEVICE_TYPE_ID        from_DEVICE_TYPE_ID,
d.DEVICE_NAME   from_DEVICE_NAME,
d.IDENTIFYING_DNS_RECORD_ID     from_IDENTIFYING_DNS_RECORD_ID,
d.SERIAL_NUMBER from_SERIAL_NUMBER,
d.ASSET_TAG     from_ASSET_TAG,
d.LOCATION_ID   from_LOCATION_ID,
d.DESCRIPTION   from_DESCRIPTION,
d.STATUS        from_STATUS,
d.PRODUCTION_STATE      from_PRODUCTION_STATE,
d.OPERATING_SYSTEM_ID   from_OPERATING_SYSTEM_ID,
d.OWNERSHIP_STATUS      from_OWNERSHIP_STATUS,
d.IS_MONITORED  from_IS_MONITORED,
d.IS_LOCALLY_MANAGED     from_IS_LOCALLY_MANAGED,
d.IS_BASELINED     from_IS_BASELINED,
d.DATE_IN_SERVICE       from_DATE_IN_SERVICE,
d.DATA_INS_USER from_DATA_INS_USER,
d.DATA_INS_DATE from_DATA_INS_DATE,
d.DATA_UPD_USER from_DATA_UPD_USER,
d.DATA_UPD_DATE from_DATA_UPD_DATE,
d.SHOULD_FETCH_CONFIG   from_SHOULD_FETCH_CONFIG,
d.PARENT_DEVICE_ID      from_PARENT_DEVICE_ID,
d.IS_VIRTUAL_DEVICE     from_IS_VIRTUAL_DEVICE,
d.AUTO_MGMT_PROTOCOL    from_AUTO_MGMT_PROTOCOL,
d.VOE_ID        from_VOE_ID,
d.VOE_SYMBOLIC_TRACK_ID from_VOE_SYMBOLIC_TRACK_ID,
d.HOST_ID       from_HOST_ID,
d.PHYSICAL_LABEL        from_PHYSICAL_LABEL,
d.AUD#ACTION    from_AUD#ACTION,
d.AUD#TIMESTAMP from_AUD#TIMESTAMP,
d.AUD#USER      from_AUD#USER
FROM aud$device d
WHERE not exists (select 1 from aud$device e
		where e.device_id=d.device_id
		and e.aud#timestamp > d.aud#timestamp);




CREATE OR REPLACE VIEW v_aud$system_user AS
SELECT 
a. SYSTEM_USER_ID     to_SYSTEM_USER_ID,
a. LOGIN     to_LOGIN,
a. FIRST_NAME     to_FIRST_NAME,
a. MIDDLE_NAME     to_MIDDLE_NAME,
a. LAST_NAME     to_LAST_NAME,
a. NAME_SUFFIX     to_NAME_SUFFIX,
a. SYSTEM_USER_STATUS     to_SYSTEM_USER_STATUS,
a. SYSTEM_USER_TYPE     to_SYSTEM_USER_TYPE,
a. EMPLOYEE_ID     to_EMPLOYEE_ID,
a. POSITION_TITLE     to_POSITION_TITLE,
a. COMPANY_ID     to_COMPANY_ID,
a. BADGE_ID     to_BADGE_ID,
a. GENDER     to_GENDER,
a. PREFERRED_FIRST_NAME     to_PREFERRED_FIRST_NAME,
a. PREFERRED_LAST_NAME     to_PREFERRED_LAST_NAME,
a. HIRE_DATE     to_HIRE_DATE,
a. TERMINATION_DATE     to_TERMINATION_DATE,
a. SHIRT_SIZE     to_SHIRT_SIZE,
a. PANT_SIZE     to_PANT_SIZE,
a. HAT_SIZE     to_HAT_SIZE,
a. DATA_INS_USER     to_DATA_INS_USER,
a. DATA_INS_DATE     to_DATA_INS_DATE,
a. DATA_UPD_USER     to_DATA_UPD_USER,
a. DATA_UPD_DATE     to_DATA_UPD_DATE,
a. DN_NAME     to_DN_NAME,
a. MANAGER_SYSTEM_USER_ID     to_MANAGER_SYSTEM_USER_ID,
a.SUPERVISOR_SYSTEM_USER_ID 	to_SUPERVISOR_SYSTEM_USER_ID,
a.PARENT_ACCOUNT_SYSTEM_USER_ID 	to_PARENT_ACCOUNT_SUID,
a.cms_id 	to_cms_id,
a. DESCRIPTION     to_DESCRIPTION,
        a.aud#timestamp to_aud#timestamp,
b. SYSTEM_USER_ID     from_SYSTEM_USER_ID,
b. LOGIN     from_LOGIN,
b. FIRST_NAME     from_FIRST_NAME,
b. MIDDLE_NAME     from_MIDDLE_NAME,
b. LAST_NAME     from_LAST_NAME,
b. NAME_SUFFIX     from_NAME_SUFFIX,
b. SYSTEM_USER_STATUS     from_SYSTEM_USER_STATUS,
b. SYSTEM_USER_TYPE     from_SYSTEM_USER_TYPE,
b. EMPLOYEE_ID     from_EMPLOYEE_ID,
b. POSITION_TITLE     from_POSITION_TITLE,
b. COMPANY_ID     from_COMPANY_ID,
b. BADGE_ID     from_BADGE_ID,
b. GENDER     from_GENDER,
b. PREFERRED_FIRST_NAME     from_PREFERRED_FIRST_NAME,
b. PREFERRED_LAST_NAME     from_PREFERRED_LAST_NAME,
b. HIRE_DATE     from_HIRE_DATE,
b. TERMINATION_DATE     from_TERMINATION_DATE,
b. SHIRT_SIZE     from_SHIRT_SIZE,
b. PANT_SIZE     from_PANT_SIZE,
b. HAT_SIZE     from_HAT_SIZE,
b. DATA_INS_USER     from_DATA_INS_USER,
b. DATA_INS_DATE     from_DATA_INS_DATE,
b. DATA_UPD_USER     from_DATA_UPD_USER,
b. DATA_UPD_DATE     from_DATA_UPD_DATE,
b. DN_NAME     from_DN_NAME,
b. MANAGER_SYSTEM_USER_ID     from_MANAGER_SYSTEM_USER_ID,
b.SUPERVISOR_SYSTEM_USER_ID 	from_SUPERVISOR_SYSTEM_USER_ID,
b.PARENT_ACCOUNT_SYSTEM_USER_ID 	from_PARENT_ACCOUNT_SUID,
b.cms_id 	from_cms_id,
b. DESCRIPTION     from_DESCRIPTION,
        b.aud#timestamp from_aud#timestamp
FROM aud$system_user a, aud$system_user b
WHERE
    a.system_user_id=b.system_user_id
AND a.aud#timestamp > b.aud#timestamp
AND not exists (select 1 from aud$system_user c
                where c.system_user_id=a.system_user_id
                and c.rowid != a.rowid
                and c.aud#timestamp > b.aud#timestamp
                and c.aud#timestamp <= a.aud#timestamp )
UNION
SELECT
NULL     to_SYSTEM_USER_ID,
NULL     to_LOGIN,
NULL     to_FIRST_NAME,
NULL     to_MIDDLE_NAME,
NULL     to_LAST_NAME,
NULL     to_NAME_SUFFIX,
NULL     to_SYSTEM_USER_STATUS,
NULL     to_SYSTEM_USER_TYPE,
NULL     to_EMPLOYEE_ID,
NULL     to_POSITION_TITLE,
NULL     to_COMPANY_ID,
NULL     to_BADGE_ID,
NULL     to_GENDER,
NULL     to_PREFERRED_FIRST_NAME,
NULL     to_PREFERRED_LAST_NAME,
NULL     to_HIRE_DATE,
NULL     to_TERMINATION_DATE,
NULL     to_SHIRT_SIZE,
NULL     to_PANT_SIZE,
NULL     to_HAT_SIZE,
NULL     to_DATA_INS_USER,
NULL     to_DATA_INS_DATE,
NULL     to_DATA_UPD_USER,
NULL     to_DATA_UPD_DATE,
NULL     to_DN_NAME,
NULL     to_MANAGER_SYSTEM_USER_ID,
NULL	to_SUPERVISOR_SYSTEM_USER_ID,
NULL	to_PARENT_ACCOUNT_SUID,
NULL	to_CMS_ID,
NULL     to_DESCRIPTION,
        NULL to_aud#timestamp,
d. SYSTEM_USER_ID     from_SYSTEM_USER_ID,
d. LOGIN     from_LOGIN,
d. FIRST_NAME     from_FIRST_NAME,
d. MIDDLE_NAME     from_MIDDLE_NAME,
d. LAST_NAME     from_LAST_NAME,
d. NAME_SUFFIX     from_NAME_SUFFIX,
d. SYSTEM_USER_STATUS     from_SYSTEM_USER_STATUS,
d. SYSTEM_USER_TYPE     from_SYSTEM_USER_TYPE,
d. EMPLOYEE_ID     from_EMPLOYEE_ID,
d. POSITION_TITLE     from_POSITION_TITLE,
d. COMPANY_ID     from_COMPANY_ID,
d. BADGE_ID     from_BADGE_ID,
d. GENDER     from_GENDER,
d. PREFERRED_FIRST_NAME     from_PREFERRED_FIRST_NAME,
d. PREFERRED_LAST_NAME     from_PREFERRED_LAST_NAME,
d. HIRE_DATE     from_HIRE_DATE,
d. TERMINATION_DATE     from_TERMINATION_DATE,
d. SHIRT_SIZE     from_SHIRT_SIZE,
d. PANT_SIZE     from_PANT_SIZE,
d. HAT_SIZE     from_HAT_SIZE,
d. DATA_INS_USER     from_DATA_INS_USER,
d. DATA_INS_DATE     from_DATA_INS_DATE,
d. DATA_UPD_USER     from_DATA_UPD_USER,
d. DATA_UPD_DATE     from_DATA_UPD_DATE,
d. DN_NAME     from_DN_NAME,
d. MANAGER_SYSTEM_USER_ID     from_MANAGER_SYSTEM_USER_ID,
d. SUPERVISOR_SYSTEM_USER_ID     from_SUPERVISOR_SYSTEM_USER_ID,
d. PARENT_ACCOUNT_SYSTEM_USER_ID     from_PARENT_ACCOUNT_SUID,
d. CMS_ID     from_CMS_ID,
d. DESCRIPTION     from_DESCRIPTION,
        d.aud#timestamp from_aud#timestamp
FROM aud$system_user d
WHERE not exists (select 1 from aud$system_user e
                where e.system_user_id=d.system_user_id
                and e.aud#timestamp > d.aud#timestamp);












