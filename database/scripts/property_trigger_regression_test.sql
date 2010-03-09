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
-- Test property trigger
--

DECLARE
	v_property_id			Property.property_id%TYPE;
	v_company_id			Property.company_id%TYPE;
	v_device_collection_id	Property.device_collection_id%TYPE;
	v_dns_domain_id			Property.dns_domain_id%TYPE;
	v_operating_system_id	Property.operating_system_id%TYPE;
	v_production_state		Property.production_state%TYPE;
	v_site_code				Property.site_code%TYPE;
	v_system_user_id		Property.system_user_id%TYPE;
	v_uclass_id				Property.uclass_id%TYPE;
	v_uclass_id2			Property.uclass_id%TYPE;
	v_netblock_id			Property.Property_Value_Netblock_ID%TYPE;
	v_password_type			Property.Property_Value_Password_Type%TYPE;
	v_sw_package_id			Property.Property_Value_SW_Package_ID%TYPE;
	v_token_collection_id	Property.Property_Value_Token_Col_ID%TYPE;

	integrity_error				EXCEPTION;
	bad_multivalue				EXCEPTION;
	PRAGMA EXCEPTION_INIT(bad_multivalue, -20500);
	bad_property_value			EXCEPTION;
	PRAGMA EXCEPTION_INIT(bad_property_value, -20900);
	property_value_present		EXCEPTION;
	PRAGMA EXCEPTION_INIT(property_value_present, -20901);
	multiple_property_values	EXCEPTION;
	PRAGMA EXCEPTION_INIT(multiple_property_values, -20902);
	required_lhs_unset			EXCEPTION;
	PRAGMA EXCEPTION_INIT(required_lhs_unset, -20903);
	prohibited_lhs_set			EXCEPTION;
	PRAGMA EXCEPTION_INIT(prohibited_lhs_set, -20904);
	invalid_uclass_type			EXCEPTION;
	PRAGMA EXCEPTION_INIT(invalid_uclass_type, -20905);
BEGIN

--
-- Clean up just in case
--

	DELETE FROM Property WHERE Property_Type IN 
		('test', 'multivaluetest');
	DELETE FROM VAL_Property_Value WHERE Property_Type IN 
		('test', 'multivaluetest');
	DELETE FROM VAL_Property WHERE Property_Type IN
		('test', 'multivaluetest');
	DELETE FROM VAL_Property_Type WHERE Property_Type IN
		('test', 'multivaluetest');

--
-- Set up VAL_Property_Data_Type for test data
--

	INSERT INTO VAL_Property_Type ( Property_Type, Is_Multivalue ) VALUES 
		('test', 'Y');
	INSERT INTO VAL_Property_Type ( Property_Type, Is_Multivalue ) VALUES 
		('multivaluetest', 'N');

--
-- Set up VAL_Property_Data_Type for test data
--

	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'Prohibited',
		'test',
		'N',
		NULL,
		'string',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);

	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'Multivalue',
		'test',
		'Y',
		NULL,
		'string',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED'
	);

	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'Singlevalue',
		'test',
		'N',
		NULL,
		'string',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED'
	);

	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'Multivalue',
		'multivaluetest',
		'N',
		NULL,
		'string',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED'
	);

	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'AnotherProperty',
		'multivaluetest',
		'N',
		NULL,
		'string',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED'
	);

	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'Allowed',
		'test',
		'N',
		NULL,
		'string',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED',
		'ALLOWED'
	);

	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'Required',
		'test',
		'N',
		NULL,
		'string',
		'REQUIRED',
		'REQUIRED',
		'REQUIRED',
		'REQUIRED',
		'REQUIRED',
		'REQUIRED',
		'REQUIRED',
		'REQUIRED'
	);

	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'RestrictUclass',
		'test',
		'N',
		'per-user',
		'string',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);


	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'boolean',
		'test',
		'N',
		NULL,
		'boolean',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);


	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'company_id',
		'test',
		'N',
		NULL,
		'company_id',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);


	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'dns_domain_id',
		'test',
		'N',
		NULL,
		'dns_domain_id',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);


	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'netblock_id',
		'test',
		'N',
		NULL,
		'netblock_id',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);

	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'sw_package_id',
		'test',
		'N',
		NULL,
		'sw_package_id',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);


	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'none',
		'test',
		'N',
		NULL,
		'none',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);


	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'number',
		'test',
		'N',
		NULL,
		'string',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);


	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'password_type',
		'test',
		'N',
		NULL,
		'password_type',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);


	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'string',
		'test',
		'N',
		NULL,
		'string',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);


	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'timestamp',
		'test',
		'N',
		NULL,
		'timestamp',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);


	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'token_collection_id',
		'test',
		'N',
		NULL,
		'token_collection_id',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);


	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'uclass_id',
		'test',
		'N',
		NULL,
		'uclass_id',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);


	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Prop_Val_Uclass_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_Production_State,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Uclass_Id
	) VALUES (
		'list',
		'test',
		'N',
		NULL,
		'list',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);

	INSERT INTO VAL_Property_Value (
		Property_Name,
		Property_Type,
		Valid_Property_Value
	) VALUES (
		'list',
		'test',
		'value'
	);

	--
	-- Get some valid data to work with
	--

	SELECT Company_ID INTO v_company_id FROM Company 
		WHERE ROWNUM = 1;
	SELECT Device_Collection_ID INTO v_device_collection_id FROM 
		Device_Collection WHERE ROWNUM = 1;
	SELECT DNS_Domain_ID INTO v_dns_domain_id FROM DNS_Domain 
		WHERE ROWNUM = 1;
	SELECT Operating_System_ID INTO v_operating_system_id FROM Operating_System 
		WHERE ROWNUM = 1;
	SELECT Production_State INTO v_production_state FROM VAL_Production_State 
		WHERE ROWNUM = 1;
	SELECT Site_Code INTO v_site_code FROM Site 
		WHERE ROWNUM = 1;
	SELECT System_User_ID INTO v_system_user_id FROM System_User 
		WHERE ROWNUM = 1;
	SELECT Uclass_ID INTO v_uclass_id FROM Uclass 
		WHERE UClass_Type = 'per-user' AND ROWNUM = 1;
	SELECT Uclass_ID INTO v_uclass_id2 FROM Uclass 
		WHERE UClass_Type <> 'per-user' AND ROWNUM = 1;
	SELECT Netblock_ID INTO v_netblock_id FROM Netblock 
		WHERE ROWNUM = 1;
	SELECT Password_Type INTO v_password_type FROM VAL_Password_Type 
		WHERE ROWNUM = 1;
	SELECT SW_Package_ID INTO v_sw_package_id FROM SW_Package
		WHERE ROWNUM = 1;
	SELECT Token_Collection_ID INTO v_token_collection_id FROM Token_Collection
		WHERE ROWNUM = 1;

--	DBMS_OUTPUT.PUT_LINE('v_company_id is ' || v_company_id);
--	DBMS_OUTPUT.PUT_LINE('v_device_collection_id is ' 
--		|| v_device_collection_id);
--	DBMS_OUTPUT.PUT_LINE('v_dns_domain_id is ' || v_dns_domain_id);
--	DBMS_OUTPUT.PUT_LINE('v_operating_system_id is ' || v_operating_system_id);
--	DBMS_OUTPUT.PUT_LINE('v_production_state is ' || v_production_state);
--	DBMS_OUTPUT.PUT_LINE('v_site_code is ' || v_site_code);
--	DBMS_OUTPUT.PUT_LINE('v_system_user_id is ' || v_system_user_id);
--	DBMS_OUTPUT.PUT_LINE('v_uclass_id is ' || v_uclass_id);
--	DBMS_OUTPUT.PUT_LINE('v_uclass_id2 is ' || v_uclass_id2);

	--
	-- Check for multivalue stuff
	--

	--
	-- Insert two of the same property for something that is not multivalue
	-- The first should work, the second should fail
	--
	dbms_output.put_line('Inserting non-multivalue property');
	INSERT INTO Property (Property_Name, Property_Type,
		Company_Id, Uclass_ID, Property_Value
		) VALUES (
		'Singlevalue', 'test', v_company_id, v_uclass_id, 'test'
		);

	dbms_output.put_line('Inserting duplicate non-multivalue property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Company_Id, Uclass_ID, Property_Value
			) VALUES (
			'Singlevalue', 'test', v_company_id, v_uclass_id, 'test2'
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_multivalue THEN
			dbms_output.put_line('... Failed correctly');
	END;

	--
	-- Insert a second property of the same type with a different uclass_id.
	-- This should succeed.
	--
	dbms_output.put_line('Inserting same property with different lhs into non-multi-valued property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Company_Id, Uclass_ID, Property_Value
			) VALUES (
			'Singlevalue', 'test', v_company_id, v_uclass_id2, 'test'
			;
		dbms_output.put_line('... Succeeded');
	EXCEPTION
		WHEN bad_multivalue THEN
			dbms_output.put_line('... Failed.  THIS IS A PROBLEM');
			raise integrity_error;
	END;

	--
	-- Insert two of the same property for something that is multivalue
	-- Both should succeed.
	--
	dbms_output.put_line('Inserting multi-valued property');
	INSERT INTO Property (Property_Name, Property_Type,
		Company_Id, Uclass_ID, Property_Value
		) VALUES (
		'Multivalue', 'test', v_company_id, v_uclass_id, 'test'
		);

	dbms_output.put_line('Inserting into the same multi-valued property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Company_Id, Uclass_ID, Property_Value
			) VALUES (
			'Multivalue', 'test', v_company_id, v_uclass_id, 'test2'
			);
		dbms_output.put_line('... Succeeded');
	EXCEPTION
		WHEN bad_multivalue THEN
			dbms_output.put_line('... Failed.  THIS IS A PROBLEM');
			raise integrity_error;
	END;

	--
	-- Insert two different properties for a property type that is 
	-- not multivalue.  The second should fail
	--
	dbms_output.put_line('Inserting a non-multi-valued-type property');
	INSERT INTO Property (Property_Name, Property_Type,
		Company_Id, Uclass_ID, Property_Value
		) VALUES (
		'Multivalue', 'multivaluetest', v_company_id, v_uclass_id, 'test'
		);

	dbms_output.put_line('Inserting a different non-multivalue-type property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Company_Id, Uclass_ID, Property_Value
			) VALUES (
			'AnotherProperty', 'multivaluetest', v_company_id, v_uclass_id, 
				'test2'
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_multivalue THEN
			dbms_output.put_line('... Failed correctly');
	END;



	--
	-- Check LHS attributes
	--

	dbms_output.put_line('Inserting no values into property with all ALLOWED lhs fields');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'Allowed', 'test', 'test'
			);
		dbms_output.put_line('... Succeeded');
	EXCEPTION
		WHEN required_lhs_unset THEN
			dbms_output.put_line('... Failed.  THIS IS A PROBLEM');
			raise integrity_error;
	END;

	dbms_output.put_line('Inserting all values into property with all ALLOWED lhs fields');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Allowed', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			v_dns_domain_id,
			v_operating_system_id,
			v_production_state,
			v_site_code,
			v_system_user_id,
			v_uclass_id
			);
		dbms_output.put_line('... Succeeded');
	EXCEPTION
		WHEN required_lhs_unset THEN
			dbms_output.put_line('... Failed.  THIS IS A PROBLEM');
			raise integrity_error;
	END;

	dbms_output.put_line('Inserting all values into property with all REQUIRED lhs fields');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			v_dns_domain_id,
			v_operating_system_id,
			v_production_state,
			v_site_code,
			v_system_user_id,
			v_uclass_id
			);
		dbms_output.put_line('... Succeeded');
	EXCEPTION
		WHEN required_lhs_unset THEN
			dbms_output.put_line('... Failed.  THIS IS A PROBLEM');
			raise integrity_error;
	END;

	dbms_output.put_line('Omitting Company_ID from property with REQUIRED Company_ID lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Required', 'test', 'test',
			NULL,
			v_device_collection_id,
			v_dns_domain_id,
			v_operating_system_id,
			v_production_state,
			v_site_code,
			v_system_user_id,
			v_uclass_id
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN required_lhs_unset THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Omitting Device_Collection_ID from property with REQUIRED Device_Collection_ID lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			NULL,
			v_dns_domain_id,
			v_operating_system_id,
			v_production_state,
			v_site_code,
			v_system_user_id,
			v_uclass_id
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN required_lhs_unset THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Omitting DNS_Domain_ID from property with REQUIRED DNS_Domain_ID lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			NULL,
			v_operating_system_id,
			v_production_state,
			v_site_code,
			v_system_user_id,
			v_uclass_id
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN required_lhs_unset THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Omitting Operating_System_ID from property with REQUIRED Operating_System_ID lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			v_dns_domain_id,
			NULL,
			v_production_state,
			v_site_code,
			v_system_user_id,
			v_uclass_id
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN required_lhs_unset THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Omitting Production_State from property with REQUIRED Production_State lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			v_dns_domain_id,
			v_operating_system_id,
			NULL,
			v_site_code,
			v_system_user_id,
			v_uclass_id
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN required_lhs_unset THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Omitting Site_Code from property with REQUIRED Site_Code lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			v_dns_domain_id,
			v_operating_system_id,
			v_production_state,
			NULL,
			v_system_user_id,
			v_uclass_id
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN required_lhs_unset THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Omitting System_User_ID from property with REQUIRED System_User_ID lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			v_dns_domain_id,
			v_operating_system_id,
			v_production_state,
			v_site_code,
			NULL,
			v_uclass_id
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN required_lhs_unset THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Omitting UClass_ID from property with REQUIRED UClass_ID lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			v_dns_domain_id,
			v_operating_system_id,
			v_production_state,
			v_site_code,
			v_system_user_id,
			NULL
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN required_lhs_unset THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting no values into property with all PROHIBITED lhs fields');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Prohibited', 'test', 'test',
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL
			);
		dbms_output.put_line('... Succeeded');
	EXCEPTION
		WHEN required_lhs_unset THEN
			dbms_output.put_line('... Failed.  THIS IS A PROBLEM');
			raise integrity_error;
	END;

	dbms_output.put_line('Adding Company_ID to property with PROHIBITED Company_ID lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Prohibited', 'test', 'test',
			v_company_id,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN prohibited_lhs_set THEN
			dbms_output.put_line('... Failed correctly');
	END;
	
	dbms_output.put_line('Adding Device_Collection_ID to property with PROHIBITED Device_Collection_ID lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Prohibited', 'test', 'test',
			NULL,
			v_device_collection_id,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN prohibited_lhs_set THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Adding DNS_Domain_ID to property with PROHIBITED DNS_Domain_ID lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Prohibited', 'test', 'test',
			NULL,
			NULL,
			v_dns_domain_id,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN prohibited_lhs_set THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Adding Operating_System_ID to property with PROHIBITED Operating_System_ID lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Prohibited', 'test', 'test',
			NULL,
			NULL,
			NULL,
			v_operating_system_id,
			NULL,
			NULL,
			NULL,
			NULL
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN prohibited_lhs_set THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Adding Production_State to property with PROHIBITED Production_State lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Prohibited', 'test', 'test',
			NULL,
			NULL,
			NULL,
			NULL,
			v_production_state,
			NULL,
			NULL,
			NULL
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN prohibited_lhs_set THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Adding Site_Code to property with PROHIBITED Site_Code lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Prohibited', 'test', 'test',
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			v_site_code,
			NULL,
			NULL
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN prohibited_lhs_set THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Adding System_User_ID to property with PROHIBITED System_User_ID lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Prohibited', 'test', 'test',
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			v_system_user_id,
			NULL
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN prohibited_lhs_set THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Adding UClass_ID to property with PROHIBITED UClass_ID lhs field');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			Production_State,
			Site_Code,
			System_User_ID,
			Uclass_ID
			) VALUES (
			'Prohibited', 'test', 'test',
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			v_uclass_id
			);
		dbms_output.put_line('... Succeeded.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN prohibited_lhs_set THEN
			dbms_output.put_line('... Failed correctly');
	END;



    --
	-- Now test setting RHS values
	--

	--
	-- string
	--

	dbms_output.put_line('Inserting timestamp value into string property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'string', 'test',
			SYSDATE
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Company_ID value into string property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'string', 'test',
			v_company_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting DNS_Domain_ID value into string property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'string', 'test',
			v_dns_domain_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Netblock_ID value into string property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'string', 'test',
			v_netblock_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Password_Type value into string property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'string', 'test',
			v_password_type
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting SW_Package_ID value into string property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'string', 'test',
			v_sw_package_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Token_Collection_ID value into string property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'string', 'test',
			v_token_collection_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting UCLass_ID value into string property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_UCLass_ID
			) VALUES (
			'string', 'test',
			v_uclass_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	--
	-- Timestamp
	--

	dbms_output.put_line('Inserting string value into timestamp property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'timestamp', 'test',
			'test'
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting timestamp value into timestamp property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'timestamp', 'test',
			SYSDATE
			);
		dbms_output.put_line('... Success');
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed');
			raise integrity_error;
	END;

	dbms_output.put_line('Inserting Company_ID value into timestamp property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'timestamp', 'test',
			v_company_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting DNS_Domain_ID value into timestamp property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'timestamp', 'test',
			v_dns_domain_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Netblock_ID value into timestamp property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'timestamp', 'test',
			v_netblock_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Password_Type value into timestamp property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'timestamp', 'test',
			v_password_type
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting SW_Package_ID value into timestamp property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'timestamp', 'test',
			v_sw_package_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Token_Collection_ID value into timestamp property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'timestamp', 'test',
			v_token_collection_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting UCLass_ID value into timestamp property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_UCLass_ID
			) VALUES (
			'timestamp', 'test',
			v_uclass_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	--
	-- Company_ID
	--

	dbms_output.put_line('Inserting string value into company_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'company_id', 'test',
			'test'
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting timestamp value into company_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'company_id', 'test',
			SYSDATE
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Company_ID value into company_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'company_id', 'test',
			v_company_id
			);
		dbms_output.put_line('... Success');
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed');
			raise integrity_error;
	END;

	dbms_output.put_line('Inserting DNS_Domain_ID value into company_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'company_id', 'test',
			v_dns_domain_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Netblock_ID value into company_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'company_id', 'test',
			v_netblock_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Password_Type value into company_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'company_id', 'test',
			v_password_type
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting SW_Package_ID value into company_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'company_id', 'test',
			v_sw_package_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Token_Collection_ID value into company_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'company_id', 'test',
			v_token_collection_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting UCLass_ID value into company_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_UCLass_ID
			) VALUES (
			'company_id', 'test',
			v_uclass_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;


	--
	-- DNS_Domain_ID
	--

	dbms_output.put_line('Inserting string value into dns_domain_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'dns_domain_id', 'test',
			'test'
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting timestamp value into dns_domain_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'dns_domain_id', 'test',
			SYSDATE
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Company_ID value into dns_domain_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'dns_domain_id', 'test',
			v_company_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting dns_domain_id value into dns_domain_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_dns_domain_id
			) VALUES (
			'dns_domain_id', 'test',
			v_dns_domain_id
			);
		dbms_output.put_line('... Success');
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed');
			raise integrity_error;
	END;

	dbms_output.put_line('Inserting Netblock_ID value into dns_domain_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'dns_domain_id', 'test',
			v_netblock_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Password_Type value into dns_domain_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'dns_domain_id', 'test',
			v_password_type
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting SW_Package_ID value into dns_domain_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'dns_domain_id', 'test',
			v_sw_package_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Token_Collection_ID value into dns_domain_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'dns_domain_id', 'test',
			v_token_collection_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting UCLass_ID value into dns_domain_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_UCLass_ID
			) VALUES (
			'dns_domain_id', 'test',
			v_uclass_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	--
	-- Netblock_ID
	--

	dbms_output.put_line('Inserting string value into netblock_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'netblock_id', 'test',
			'test'
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting timestamp value into netblock_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'netblock_id', 'test',
			SYSDATE
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Company_ID value into netblock_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'netblock_id', 'test',
			v_company_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting DNS_Domain_ID value into netblock_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'netblock_id', 'test',
			v_dns_domain_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Netblock_ID value into netblock_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'netblock_id', 'test',
			v_netblock_id
			);
		dbms_output.put_line('... Success');
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed');
			raise integrity_error;
	END;

	dbms_output.put_line('Inserting Password_Type value into netblock_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'netblock_id', 'test',
			v_password_type
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting SW_Package_ID value into netblock_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'netblock_id', 'test',
			v_sw_package_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Token_Collection_ID value into netblock_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'netblock_id', 'test',
			v_token_collection_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting UCLass_ID value into netblock_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_UCLass_ID
			) VALUES (
			'netblock_id', 'test',
			v_uclass_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	--
	-- Password_Type
	--

	dbms_output.put_line('Inserting string value into password_type property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'password_type', 'test',
			'test'
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting timestamp value into password_type property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'password_type', 'test',
			SYSDATE
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Company_ID value into password_type property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'password_type', 'test',
			v_company_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting DNS_Domain_ID value into password_type property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'password_type', 'test',
			v_dns_domain_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Netblock_ID value into password_type property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'password_type', 'test',
			v_netblock_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Password_Type value into password_type property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'password_type', 'test',
			v_password_type
			);
		dbms_output.put_line('... Success');
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed');
			raise integrity_error;
	END;

	dbms_output.put_line('Inserting SW_Package_ID value into password_type property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'password_type', 'test',
			v_sw_package_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Token_Collection_ID value into password_type property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'password_type', 'test',
			v_token_collection_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting UCLass_ID value into password_type property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_UCLass_ID
			) VALUES (
			'password_type', 'test',
			v_uclass_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	--
	-- SW_Package_ID
	--

	dbms_output.put_line('Inserting string value into sw_package_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'sw_package_id', 'test',
			'test'
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting timestamp value into sw_package_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'sw_package_id', 'test',
			SYSDATE
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Company_ID value into sw_package_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'sw_package_id', 'test',
			v_company_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting DNS_Domain_ID value into sw_package_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'sw_package_id', 'test',
			v_dns_domain_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Netblock_ID value into sw_package_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'sw_package_id', 'test',
			v_netblock_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Password_Type value into sw_package_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'sw_package_id', 'test',
			v_password_type
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting SW_Package_ID value into sw_package_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'sw_package_id', 'test',
			v_sw_package_id
			);
		dbms_output.put_line('... Success');
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed');
			raise integrity_error;
	END;

	dbms_output.put_line('Inserting Token_Collection_ID value into sw_package_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'sw_package_id', 'test',
			v_token_collection_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting UCLass_ID value into sw_package_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_UCLass_ID
			) VALUES (
			'sw_package_id', 'test',
			v_uclass_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	--
	-- Token_Collection_ID
	--

	dbms_output.put_line('Inserting string value into token_collection_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'token_collection_id', 'test',
			'test'
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting timestamp value into token_collection_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'token_collection_id', 'test',
			SYSDATE
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Company_ID value into token_collection_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'token_collection_id', 'test',
			v_company_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting DNS_Domain_ID value into token_collection_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'token_collection_id', 'test',
			v_dns_domain_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Netblock_ID value into token_collection_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'token_collection_id', 'test',
			v_netblock_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Password_Type value into token_collection_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'token_collection_id', 'test',
			v_password_type
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting SW_Package_ID value into token_collection_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'token_collection_id', 'test',
			v_sw_package_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Token_Collection_ID value into token_collection_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'token_collection_id', 'test',
			v_token_collection_id
			);
		dbms_output.put_line('... Success');
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed');
			raise integrity_error;
	END;

	dbms_output.put_line('Inserting UCLass_ID value into token_collection_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_UCLass_ID
			) VALUES (
			'token_collection_id', 'test',
			v_uclass_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	--
	-- UClass_ID
	--

	dbms_output.put_line('Inserting string value into uclass_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'uclass_id', 'test',
			'test'
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting timestamp value into uclass_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'uclass_id', 'test',
			SYSDATE
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Company_ID value into uclass_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'uclass_id', 'test',
			v_company_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting DNS_Domain_ID value into uclass_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'uclass_id', 'test',
			v_dns_domain_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Netblock_ID value into uclass_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'uclass_id', 'test',
			v_netblock_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Password_Type value into uclass_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'uclass_id', 'test',
			v_password_type
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting SW_Package_ID value into uclass_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'uclass_id', 'test',
			v_sw_package_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Token_Collection_ID value into uclass_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'uclass_id', 'test',
			v_token_collection_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting UCLass_ID value into uclass_id property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_UCLass_ID
			) VALUES (
			'uclass_id', 'test',
			v_uclass_id
			);
		dbms_output.put_line('... Success');
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed');
			raise integrity_error;
	END;

	--
	-- none
	--

	dbms_output.put_line('Inserting string value into none property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'none', 'test',
			'test'
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting timestamp value into none property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'none', 'test',
			SYSDATE
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Company_ID value into none property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'none', 'test',
			v_company_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting DNS_Domain_ID value into none property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'none', 'test',
			v_dns_domain_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Netblock_ID value into none property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'none', 'test',
			v_netblock_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Password_Type value into none property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'none', 'test',
			v_password_type
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting SW_Package_ID value into none property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'none', 'test',
			v_sw_package_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting Token_Collection_ID value into none property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'none', 'test',
			v_token_collection_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	dbms_output.put_line('Inserting uclass_id value into none property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Uclass_ID
			) VALUES (
			'none', 'test',
			v_uclass_id
			);
		dbms_output.put_line('... Insert successful.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;

	--
	-- Boolean
	--

	dbms_output.put_line('Inserting Y value into boolean property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'boolean', 'test',
			'Y'
			) RETURNING Property_ID INTO v_property_id;
		dbms_output.put_line('... Success');
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed');
			raise integrity_error;
	END;
	DELETE FROM Property WHERE Property_ID = v_property_id;

	dbms_output.put_line('Inserting N value into boolean property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'boolean', 'test',
			'N'
			) RETURNING Property_ID INTO v_property_id;
		dbms_output.put_line('... Success');
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed');
			raise integrity_error;
	END;
	DELETE FROM Property WHERE Property_ID = v_property_id;

	dbms_output.put_line('Inserting non-boolean value into boolean property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'boolean', 'test',
			'Vv'
			) RETURNING Property_ID INTO v_property_id;
		dbms_output.put_line('... Success.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;
	DELETE FROM Property WHERE Property_ID = v_property_id;

	--
	-- List
	--

	dbms_output.put_line('Inserting valid value into list property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'list', 'test',
			'value'
			) RETURNING Property_ID INTO v_property_id;
		dbms_output.put_line('... Success');
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed');
			raise integrity_error;
	END;
	DELETE FROM Property WHERE Property_ID = v_property_id;


	dbms_output.put_line('Inserting invalid value into list property');
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'list', 'test',
			'Vv'
			) RETURNING Property_ID INTO v_property_id;
		dbms_output.put_line('... Success.  THIS IS A PROBLEM');
		raise integrity_error;
	EXCEPTION
		WHEN bad_property_value THEN
			dbms_output.put_line('... Failed correctly');
	END;
	DELETE FROM Property WHERE Property_ID = v_property_id;

	--
	-- Clean up
	--

--	DELETE FROM Property WHERE Property_Type IN 
--		('test', 'multivaluetest');
--	DELETE FROM VAL_Property_Value WHERE Property_Type IN 
--		('test', 'multivaluetest');
--	DELETE FROM VAL_Property WHERE Property_Type IN
--		('test', 'multivaluetest');
--	DELETE FROM VAL_Property_Type WHERE Property_Type IN
--		('test', 'multivaluetest');
END;
/
