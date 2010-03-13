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
CREATE OR REPLACE
PACKAGE system_user_util
 IS

------------------------------------------------------------------------------------------------------------------
--DESCRIPTION:  This package is used to insert and manipulate system user data and related data (vehicles,etc.)
-------------------------------------------------------------------------------------------------------------------
--$Id$



-- TYPE Definitions -------------------------
---------------------------------------------


--  Array types
---------------------------------------------


-- Reference Cursor


-- Global Variables -------------------------
---------------------------------------------

-- This holds the ID tag of this header file.  Can be used for debug purposes
GC_spec_id_tag	     CONSTANT global_types.id_tag_var_type := '$Id$';



-- Function Specs  -------------------------
--------------------------------------------

-- id_tag is a function to obtain the version information of the package
FUNCTION id_tag 	RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;

FUNCTION choose_login
(
    p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_first			IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last			IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_company_id	IN	SYSTEM_USER.COMPANY_ID % TYPE,
	p_system_user_type	IN	SYSTEM_USER.SYSTEM_USER_TYPE % TYPE,
	p_iteration		IN	INTEGER
) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;



-- Below reference replaced by DETERMINISTIC and PARALLEL_ENABLE
-- PRAGMA RESTRICT_REFERENCES (id_tag, WNDS, RNDS, WNPS, RNPS);


-- Procedure Specs  -------------------------
---------------------------------------------

PROCEDURE user_add
(
	p_system_user_id		OUT	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_employee_id			IN OUT	SYSTEM_USER.EMPLOYEE_ID % TYPE,
	p_login				IN	SYSTEM_USER.LOGIN % TYPE,
	p_first_name			IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name			IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name			IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_name_suffix			IN	SYSTEM_USER.NAME_SUFFIX % TYPE,
	p_system_user_status		IN	SYSTEM_USER.SYSTEM_USER_STATUS % TYPE,
	p_system_user_type		IN	SYSTEM_USER.SYSTEM_USER_TYPE % TYPE,
	p_position_title		IN	SYSTEM_USER.POSITION_TITLE % TYPE,
	p_company_id			IN	SYSTEM_USER.COMPANY_ID % TYPE,
	p_gender			IN	SYSTEM_USER.GENDER % TYPE,
	p_preferred_first_name		IN	SYSTEM_USER.PREFERRED_FIRST_NAME % TYPE,
	p_preferred_last_name		IN	SYSTEM_USER.PREFERRED_LAST_NAME % TYPE,
	p_hire_date			IN	SYSTEM_USER.HIRE_DATE % TYPE,
	p_shirt_size			IN	SYSTEM_USER.SHIRT_SIZE % TYPE,
	p_pant_size			IN	SYSTEM_USER.PANT_SIZE % TYPE,
	p_hat_size			IN	SYSTEM_USER.HAT_SIZE % TYPE
);

PROCEDURE user_add2
(
	p_system_user_id		OUT	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_employee_id			IN OUT	SYSTEM_USER.EMPLOYEE_ID % TYPE,
	p_manager_id			IN	SYSTEM_USER.MANAGER_SYSTEM_USER_ID % TYPE,
	p_badge_id			IN	SYSTEM_USER.BADGE_ID % TYPE,
	p_login				IN OUT	SYSTEM_USER.LOGIN % TYPE,
	p_first_name			IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name			IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name			IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_name_suffix			IN	SYSTEM_USER.NAME_SUFFIX % TYPE,
	p_system_user_status		IN	SYSTEM_USER.SYSTEM_USER_STATUS % TYPE,
	p_system_user_type		IN	SYSTEM_USER.SYSTEM_USER_TYPE % TYPE,
	p_position_title		IN	SYSTEM_USER.POSITION_TITLE % TYPE,
	p_company_id			IN	SYSTEM_USER.COMPANY_ID % TYPE,
	p_gender			IN	SYSTEM_USER.GENDER % TYPE,
	p_preferred_first_name		IN	SYSTEM_USER.PREFERRED_FIRST_NAME % TYPE,
	p_preferred_last_name		IN	SYSTEM_USER.PREFERRED_LAST_NAME % TYPE,
	p_hire_date			IN	SYSTEM_USER.HIRE_DATE % TYPE,
	p_termination_date		IN	SYSTEM_USER.TERMINATION_DATE % TYPE,
	p_shirt_size			IN	SYSTEM_USER.SHIRT_SIZE % TYPE,
	p_pant_size			IN	SYSTEM_USER.PANT_SIZE % TYPE,
	p_hat_size			IN	SYSTEM_USER.HAT_SIZE % TYPE
);

PROCEDURE user_update
(
	p_system_user_id		IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_employee_id			IN	SYSTEM_USER.EMPLOYEE_ID % TYPE,
	p_manager_id			IN	SYSTEM_USER.MANAGER_SYSTEM_USER_ID % TYPE,
	p_badge_id			IN	SYSTEM_USER.BADGE_ID % TYPE,
	p_login				IN	SYSTEM_USER.LOGIN % TYPE,
	p_first_name			IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name			IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name			IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_name_suffix			IN	SYSTEM_USER.NAME_SUFFIX % TYPE,
	p_system_user_status		IN	SYSTEM_USER.SYSTEM_USER_STATUS % TYPE,
	p_system_user_type		IN	SYSTEM_USER.SYSTEM_USER_TYPE % TYPE,
	p_position_title		IN	SYSTEM_USER.POSITION_TITLE % TYPE,
	p_company_id			IN	SYSTEM_USER.COMPANY_ID % TYPE,
	p_gender			IN	SYSTEM_USER.GENDER % TYPE,
	p_preferred_first_name		IN	SYSTEM_USER.PREFERRED_FIRST_NAME % TYPE,
	p_preferred_last_name		IN	SYSTEM_USER.PREFERRED_LAST_NAME % TYPE,
	p_hire_date			IN	SYSTEM_USER.HIRE_DATE % TYPE,
	p_termination_date		IN	SYSTEM_USER.TERMINATION_DATE % TYPE,
	p_shirt_size			IN	SYSTEM_USER.SHIRT_SIZE % TYPE,
	p_pant_size			IN	SYSTEM_USER.PANT_SIZE % TYPE,
	p_hat_size			IN	SYSTEM_USER.HAT_SIZE % TYPE
);

PROCEDURE user_search
(
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_employee_id		IN	SYSTEM_USER.EMPLOYEE_ID % TYPE,
	p_manager_id		IN	SYSTEM_USER.MANAGER_SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_legal_only		IN	VARCHAR2,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_gender		IN	SYSTEM_USER.GENDER % TYPE,
	p_title			IN	SYSTEM_USER.POSITION_TITLE % TYPE,
	p_badge			IN	SYSTEM_USER.BADGE_ID % TYPE,
	p_company_id		IN	SYSTEM_USER.COMPANY_ID % TYPE,
	p_use_dept_company	IN	VARCHAR2,
	p_status		IN	SYSTEM_USER.SYSTEM_USER_STATUS % TYPE,
	p_type			IN	SYSTEM_USER.SYSTEM_USER_TYPE % TYPE,
	p_dept_code		IN	DEPT.DEPT_CODE % TYPE,
	p_dept_id		IN	DEPT.DEPT_ID % TYPE,
	p_phone_number		IN	VARCHAR2,
	p_phone_number_type	IN	SYSTEM_USER_PHONE.PHONE_NUMBER_TYPE % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE user_delete
(
	p_system_user_id		IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE
);

PROCEDURE self_update
(
	p_system_user_id		IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_name_suffix			IN	SYSTEM_USER.NAME_SUFFIX % TYPE,
	p_preferred_first_name		IN	SYSTEM_USER.PREFERRED_FIRST_NAME % TYPE,
	p_preferred_last_name		IN	SYSTEM_USER.PREFERRED_LAST_NAME % TYPE,
	p_shirt_size			IN	SYSTEM_USER.SHIRT_SIZE % TYPE,
	p_pant_size			IN	SYSTEM_USER.PANT_SIZE % TYPE,
	p_hat_size			IN	SYSTEM_USER.HAT_SIZE % TYPE
);

PROCEDURE seating_search
(
	p_first_name			IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name			IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name			IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login				IN	SYSTEM_USER.LOGIN % TYPE,
	p_employee_id			IN	SYSTEM_USER.EMPLOYEE_ID % TYPE,
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE seating_update
(
	p_system_user_location_id	IN	SYSTEM_USER_LOCATION.SYSTEM_USER_LOCATION_ID % TYPE,
	p_building			IN	SYSTEM_USER_LOCATION.BUILDING % TYPE,
	p_floor				IN	SYSTEM_USER_LOCATION.FLOOR % TYPE,
	p_section			IN	SYSTEM_USER_LOCATION.SECTION % TYPE,
	p_seat_number			IN	SYSTEM_USER_LOCATION.SEAT_NUMBER % TYPE
);

PROCEDURE location_add
(
	p_system_user_location_id	OUT	SYSTEM_USER_LOCATION.SYSTEM_USER_LOCATION_ID % TYPE,
	p_system_user_id		IN	SYSTEM_USER_LOCATION.SYSTEM_USER_ID % TYPE,
	p_system_user_location_type	IN	SYSTEM_USER_LOCATION.SYSTEM_USER_LOCATION_TYPE % TYPE,
	p_office_site			IN	SYSTEM_USER_LOCATION.OFFICE_SITE % TYPE,
	p_address_1			IN	SYSTEM_USER_LOCATION.ADDRESS_1 % TYPE,
	p_address_2			IN	SYSTEM_USER_LOCATION.ADDRESS_2 % TYPE,
	p_city				IN	SYSTEM_USER_LOCATION.CITY % TYPE,
	p_state				IN	SYSTEM_USER_LOCATION.STATE % TYPE,
	p_postal_code			IN	SYSTEM_USER_LOCATION.POSTAL_CODE % TYPE,
	p_country			IN	SYSTEM_USER_LOCATION.COUNTRY % TYPE,
	p_building			IN	SYSTEM_USER_LOCATION.BUILDING % TYPE,
	p_floor				IN	SYSTEM_USER_LOCATION.FLOOR % TYPE,
	p_section			IN	SYSTEM_USER_LOCATION.SECTION % TYPE,
	p_seat_number			IN	SYSTEM_USER_LOCATION.SEAT_NUMBER % TYPE
);

PROCEDURE location_update
(
	p_system_user_location_id	IN	SYSTEM_USER_LOCATION.SYSTEM_USER_LOCATION_ID % TYPE,
	p_system_user_location_type	IN	SYSTEM_USER_LOCATION.SYSTEM_USER_LOCATION_TYPE % TYPE,
	p_office_site			IN	SYSTEM_USER_LOCATION.OFFICE_SITE % TYPE,
	p_address_1			IN	SYSTEM_USER_LOCATION.ADDRESS_1 % TYPE,
	p_address_2			IN	SYSTEM_USER_LOCATION.ADDRESS_2 % TYPE,
	p_city				IN	SYSTEM_USER_LOCATION.CITY % TYPE,
	p_state				IN	SYSTEM_USER_LOCATION.STATE % TYPE,
	p_postal_code			IN	SYSTEM_USER_LOCATION.POSTAL_CODE % TYPE,
	p_country			IN	SYSTEM_USER_LOCATION.COUNTRY % TYPE,
	p_building			IN	SYSTEM_USER_LOCATION.BUILDING % TYPE,
	p_floor				IN	SYSTEM_USER_LOCATION.FLOOR % TYPE,
	p_section			IN	SYSTEM_USER_LOCATION.SECTION % TYPE,
	p_seat_number			IN	SYSTEM_USER_LOCATION.SEAT_NUMBER % TYPE
);

PROCEDURE location_delete
(
	p_system_user_location_id	IN	SYSTEM_USER_LOCATION.SYSTEM_USER_LOCATION_ID % TYPE
);

PROCEDURE vehicle_add
(
	p_system_user_vehicle_id	OUT	SYSTEM_USER_VEHICLE.SYSTEM_USER_VEHICLE_ID % TYPE,
	p_system_user_id		IN	SYSTEM_USER_VEHICLE.SYSTEM_USER_ID % TYPE,
	p_vehicle_make			IN	SYSTEM_USER_VEHICLE.VEHICLE_MAKE % TYPE,
	p_vehicle_model			IN	SYSTEM_USER_VEHICLE.VEHICLE_MODEL % TYPE,
	p_vehicle_year			IN	SYSTEM_USER_VEHICLE.VEHICLE_YEAR % TYPE,
	p_vehicle_color			IN	SYSTEM_USER_VEHICLE.VEHICLE_COLOR % TYPE,
	p_vehicle_license_plate		IN	SYSTEM_USER_VEHICLE.VEHICLE_LICENSE_PLATE % TYPE,
	p_vehicle_license_state		IN	SYSTEM_USER_VEHICLE.VEHICLE_LICENSE_STATE % TYPE
);

PROCEDURE vehicle_update
(
	p_system_user_vehicle_id	IN	SYSTEM_USER_VEHICLE.SYSTEM_USER_VEHICLE_ID % TYPE,
	p_vehicle_make			IN	SYSTEM_USER_VEHICLE.VEHICLE_MAKE % TYPE,
	p_vehicle_model			IN	SYSTEM_USER_VEHICLE.VEHICLE_MODEL % TYPE,
	p_vehicle_year			IN	SYSTEM_USER_VEHICLE.VEHICLE_YEAR % TYPE,
	p_vehicle_color			IN	SYSTEM_USER_VEHICLE.VEHICLE_COLOR % TYPE,
	p_vehicle_license_plate		IN	SYSTEM_USER_VEHICLE.VEHICLE_LICENSE_PLATE % TYPE,
	p_vehicle_license_state		IN	SYSTEM_USER_VEHICLE.VEHICLE_LICENSE_STATE % TYPE
);

PROCEDURE vehicle_delete
(
	p_system_user_vehicle_id	IN	SYSTEM_USER_VEHICLE.SYSTEM_USER_VEHICLE_ID % TYPE
);

PROCEDURE phone_add
(
	p_system_user_phone_id		OUT	SYSTEM_USER_PHONE.SYSTEM_USER_PHONE_ID % TYPE,
	p_system_user_id		IN	SYSTEM_USER_PHONE.SYSTEM_USER_ID % TYPE,
	p_phone_type_order		IN	SYSTEM_USER_PHONE.PHONE_TYPE_ORDER % TYPE,
	p_phone_number_type		IN	SYSTEM_USER_PHONE.PHONE_NUMBER_TYPE % TYPE,
	p_iso_country_code		IN	SYSTEM_USER_PHONE.ISO_COUNTRY_CODE % TYPE,
	p_phone_number			IN	SYSTEM_USER_PHONE.PHONE_NUMBER % TYPE,
	p_phone_extension		IN	SYSTEM_USER_PHONE.PHONE_EXTENSION % TYPE,
	p_contact_notes			IN	SYSTEM_USER_PHONE.CONTACT_NOTES % TYPE
);

PROCEDURE phone_search
(
	p_system_user_id		IN	SYSTEM_USER_PHONE.SYSTEM_USER_ID % TYPE,
	p_system_user_phone_id		IN	SYSTEM_USER_PHONE.SYSTEM_USER_PHONE_ID % TYPE,
	p_phone_number_type		IN	SYSTEM_USER_PHONE.PHONE_NUMBER_TYPE % TYPE,
	p_iso_country_code		IN	SYSTEM_USER_PHONE.ISO_COUNTRY_CODE % TYPE,
	p_phone_number			IN	varchar2,
	p_phone_extension		IN	varchar2,
	p_contact_notes			IN	SYSTEM_USER_PHONE.CONTACT_NOTES % TYPE,
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE phone_update
(
	p_system_user_phone_id		IN	SYSTEM_USER_PHONE.SYSTEM_USER_PHONE_ID % TYPE,
	p_phone_type_order		IN	SYSTEM_USER_PHONE.PHONE_TYPE_ORDER % TYPE,
	p_phone_number_type		IN	SYSTEM_USER_PHONE.PHONE_NUMBER_TYPE % TYPE,
	p_iso_country_code		IN	SYSTEM_USER_PHONE.ISO_COUNTRY_CODE % TYPE,
	p_phone_number			IN	SYSTEM_USER_PHONE.PHONE_NUMBER % TYPE,
	p_phone_extension		IN	SYSTEM_USER_PHONE.PHONE_EXTENSION % TYPE,
	p_contact_notes			IN	SYSTEM_USER_PHONE.CONTACT_NOTES % TYPE
);

PROCEDURE phone_delete
(
	p_system_user_phone_id		IN	SYSTEM_USER_PHONE.SYSTEM_USER_PHONE_ID % TYPE
);

PROCEDURE phone_delete_type
(
	p_system_user_id		IN	SYSTEM_USER_PHONE.SYSTEM_USER_ID % TYPE,
	p_phone_number_type		IN	SYSTEM_USER_PHONE.PHONE_NUMBER_TYPE % TYPE
);

PROCEDURE dept_add
(
	p_dept_id			IN	DEPT_MEMBER.DEPT_ID % TYPE,
	p_system_user_id		IN	DEPT_MEMBER.SYSTEM_USER_ID % TYPE,
	p_reporting_type		IN	DEPT_MEMBER.REPORTING_TYPE % TYPE,
	p_start_date			IN	DEPT_MEMBER.START_DATE % TYPE,
	p_finish_date			IN	DEPT_MEMBER.FINISH_DATE % TYPE
);

PROCEDURE dept_update
(
	p_prev_id			IN	DEPT_MEMBER.DEPT_ID % TYPE,
	p_system_user_id		IN	DEPT_MEMBER.SYSTEM_USER_ID % TYPE,
	p_dept_id			IN	DEPT_MEMBER.DEPT_ID % TYPE,
	p_reporting_type		IN	DEPT_MEMBER.REPORTING_TYPE % TYPE,
	p_start_date			IN	DEPT_MEMBER.START_DATE % TYPE,
	p_finish_date			IN	DEPT_MEMBER.FINISH_DATE % TYPE
);

PROCEDURE dept_delete
(
	p_system_user_id		IN	DEPT_MEMBER.SYSTEM_USER_ID % TYPE,
	p_dept_id			IN	DEPT_MEMBER.DEPT_ID % TYPE
);

PROCEDURE dept_delete_type
(
	p_system_user_id		IN	DEPT_MEMBER.SYSTEM_USER_ID % TYPE,
	p_reporting_type		IN	DEPT_MEMBER.REPORTING_TYPE % TYPE
);

PROCEDURE company_insert
(
	p_company_id			OUT	COMPANY.COMPANY_ID % TYPE,
	p_company_name			IN	COMPANY.COMPANY_NAME % TYPE,
	p_company_code			IN	COMPANY.COMPANY_CODE % TYPE,
	p_description			IN	COMPANY.DESCRIPTION % TYPE,
	p_is_corporate_family		IN	COMPANY.IS_CORPORATE_FAMILY % TYPE
);

PROCEDURE company_update
(
	p_company_id			IN	COMPANY.COMPANY_ID % TYPE,
	p_company_name			IN	COMPANY.COMPANY_NAME % TYPE,
	p_company_code			IN	COMPANY.COMPANY_CODE % TYPE,
	p_description			IN	COMPANY.DESCRIPTION % TYPE,
	p_is_corporate_family		IN	COMPANY.IS_CORPORATE_FAMILY % TYPE
);

PROCEDURE department_insert
(
	p_dept_id			OUT	DEPT.DEPT_ID % TYPE,
	p_dept_name			IN	DEPT.NAME % TYPE,
	p_dept_code			IN	DEPT.DEPT_CODE % TYPE,
	p_manager_id			IN	DEPT.MANAGER_SYSTEM_USER_ID % TYPE,
	p_cost_center			IN	DEPT.COST_CENTER % TYPE,
	p_parent			IN	DEPT.PARENT_DEPT_ID % TYPE,
	p_company_id			IN	DEPT.COMPANY_ID % TYPE,
	p_badge_type_id			IN	DEPT.DEFAULT_BADGE_TYPE_ID % TYPE,
	p_dept_ou			IN	DEPT.DEPT_OU % TYPE,
	p_active			IN	DEPT.IS_ACTIVE % TYPE
);

PROCEDURE department_update
(
	p_dept_id			IN	DEPT.DEPT_ID % TYPE,
	p_dept_name			IN	DEPT.NAME % TYPE,
	p_dept_code			IN	DEPT.DEPT_CODE % TYPE,
	p_manager_id			IN	DEPT.MANAGER_SYSTEM_USER_ID % TYPE,
	p_cost_center			IN	DEPT.COST_CENTER % TYPE,
	p_parent			IN	DEPT.PARENT_DEPT_ID % TYPE,
	p_company_id			IN	DEPT.COMPANY_ID % TYPE,
	p_badge_type_id			IN	DEPT.DEFAULT_BADGE_TYPE_ID % TYPE,
	p_dept_ou			IN	DEPT.DEPT_OU % TYPE,
	p_active			IN	DEPT.IS_ACTIVE % TYPE
);

PROCEDURE info_company
(
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE info_reporting
(
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE info_countrycode
(
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE info_dept
(
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE info_site
(
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE info_types
(
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE info_status
(
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE info_location_type
(
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE info_xref
(
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE info_phone
(
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE info_location
(
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE info_vehicle
(
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE info_member
(
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE xref_add
(
	p_system_user_id		IN	SYSTEM_USER_XREF.SYSTEM_USER_ID % TYPE,
	p_external_hr_id			IN	SYSTEM_USER_XREF.EXTERNAL_HR_ID % TYPE,
	p_payroll_id			IN	SYSTEM_USER_XREF.PAYROLL_ID % TYPE
);

PROCEDURE xref_update
(
	p_system_user_id		IN	SYSTEM_USER_XREF.SYSTEM_USER_ID % TYPE,
	p_external_hr_id			IN	SYSTEM_USER_XREF.EXTERNAL_HR_ID % TYPE,
	p_payroll_id			IN	SYSTEM_USER_XREF.PAYROLL_ID % TYPE
);

PROCEDURE matching_location
(
	p_system_user_id		IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE matching_dept
(
	p_system_user_id		IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE matching_phone
(
	p_system_user_id		IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE matching_vehicle
(
	p_system_user_id		IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE report_change_user
(
	p_reference_date	IN	SYSTEM_USER.DATA_INS_DATE % TYPE,
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE report_change_location
(
	p_reference_date	IN	SYSTEM_USER.DATA_INS_DATE % TYPE,
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE report_change_vehicle
(
	p_reference_date	IN	SYSTEM_USER.DATA_INS_DATE % TYPE,
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE report_change_phone
(
	p_reference_date	IN	SYSTEM_USER.DATA_INS_DATE % TYPE,
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE report_change_dept
(
	p_reference_date	IN	SYSTEM_USER.DATA_INS_DATE % TYPE,
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE report_change_member
(
	p_reference_date	IN	SYSTEM_USER.DATA_INS_DATE % TYPE,
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE system_user_history
(
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE image_byid
(
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

PROCEDURE image_inorup
(
	p_system_user_image_id	IN OUT	SYSTEM_USER_IMAGE.SYSTEM_USER_IMAGE_ID % TYPE,
	p_system_user_id	IN	SYSTEM_USER_IMAGE.SYSTEM_USER_ID % TYPE,
	p_image_type		IN	SYSTEM_USER_IMAGE.IMAGE_TYPE % TYPE,
	p_image_blob		IN OUT	SYSTEM_USER_IMAGE.IMAGE_BLOB % TYPE
);

PROCEDURE image_search
(
	p_system_user_image_id	IN	SYSTEM_USER_IMAGE.SYSTEM_USER_IMAGE_ID % TYPE,
	p_system_user_id	IN	SYSTEM_USER_IMAGE.SYSTEM_USER_ID % TYPE,
	p_image_type		IN	SYSTEM_USER_IMAGE.IMAGE_TYPE % TYPE,
	p_badge_id		IN	SYSTEM_USER.BADGE_ID % TYPE,
	p_manager_id		IN	SYSTEM_USER.MANAGER_SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_gender		IN	SYSTEM_USER.GENDER % TYPE,
	p_title			IN	SYSTEM_USER.POSITION_TITLE % TYPE,
	p_company_id		IN	SYSTEM_USER.COMPANY_ID % TYPE,
	p_dept_code		IN	DEPT.DEPT_CODE % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
);

END;
/
