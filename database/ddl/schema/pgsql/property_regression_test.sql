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
-- $Id$
--
--
-- Test property trigger
--
\t on

CREATE FUNCTION validate_property_triggers() RETURNS BOOLEAN AS $$
DECLARE
	v_property_id			Property.property_id%TYPE;
	v_company_id			Property.company_id%TYPE;
	v_device_collection_id	Property.device_collection_id%TYPE;
	v_dns_domain_id			Property.dns_domain_id%TYPE;
	v_operating_system_id	Property.operating_system_id%TYPE;
	v_service_environment		Property.service_environment%TYPE;
	v_site_code				Property.site_code%TYPE;
	v_system_user_id		Property.system_user_id%TYPE;
	v_account_collection_id				Property.account_collection_id%TYPE;
	v_account_collection_id2			Property.account_collection_id%TYPE;
	v_netblock_id			Property.Property_Value_Netblock_ID%TYPE;
	v_password_type			Property.Property_Value_Password_Type%TYPE;
	v_sw_package_id			Property.Property_Value_SW_Package_ID%TYPE;
	v_token_collection_id	Property.Property_Value_Token_Col_ID%TYPE;

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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
	) VALUES (
		'RestrictAccount_Collectiong',
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_Id
	) VALUES (
		'account_collection_id',
		'test',
		'N',
		NULL,
		'account_collection_id',
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
		Prop_Val_Acct_Coll_Type_Rstrct,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Device_Collection_Id,
		Permit_DNS_Domain_Id,
		Permit_Operating_System_Id,
		Permit_service_environment,
		Permit_Site_Code,
		Permit_System_User_Id,
		Permit_Account_Collection_id
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
		LIMIT 1;
	SELECT Device_Collection_ID INTO v_device_collection_id FROM 
		Device_Collection LIMIT 1;
	SELECT DNS_Domain_ID INTO v_dns_domain_id FROM DNS_Domain 
		LIMIT 1;
	SELECT Operating_System_ID INTO v_operating_system_id FROM Operating_System 
		LIMIT 1;
	SELECT service_environment INTO v_service_environment FROM VAL_service_environment 
		LIMIT 1;
	SELECT Site_Code INTO v_site_code FROM Site 
		LIMIT 1;
	SELECT System_User_ID INTO v_system_user_id FROM System_User 
		LIMIT 1;
	SELECT Account_Collection_Id INTO v_account_collection_id FROM Account_Collection 
		WHERE Account_Collectiong_Type = 'per-user' LIMIT 1;
	SELECT Account_Collection_Id INTO v_account_collection_id2 FROM Account_Collectiong 
		WHERE Account_Collectiong_Type <> 'per-user' LIMIT 1; 
	SELECT Netblock_ID INTO v_netblock_id FROM Netblock 
		LIMIT 1;
	SELECT Password_Type INTO v_password_type FROM VAL_Password_Type 
		LIMIT 1;
--	SELECT SW_Package_ID INTO v_sw_package_id FROM SW_Package
--		LIMIT 1;
	SELECT Token_Collection_ID INTO v_token_collection_id FROM Token_Collection
		LIMIT 1;

	RAISE NOTICE 'v_company_id is %', v_company_id;
	RAISE NOTICE 'v_device_collection_id is %', v_device_collection_id;
	RAISE NOTICE 'v_dns_domain_id is %', v_dns_domain_id;
	RAISE NOTICE 'v_operating_system_id is %', v_operating_system_id;
	RAISE NOTICE 'v_service_environment is %', v_service_environment;
	RAISE NOTICE 'v_site_code is %', v_site_code;
	RAISE NOTICE 'v_system_user_id is %', v_system_user_id;
	RAISE NOTICE 'v_account_collection_id is %', v_account_collection_id;
	RAISE NOTICE 'v_account_collection_id2 is %', v_account_collection_id2;
	RAISE NOTICE 'v_netblock_id is %', v_netblock_id;
	RAISE NOTICE 'v_password_type is %', v_password_type;
	RAISE NOTICE 'v_token_collection_id is %', v_token_collection_id;

	--
	-- Check for multivalue stuff
	--

	--
	-- Insert two of the same property for something that is not multivalue
	-- The first should work, the second should fail
	--
	RAISE NOTICE 'Inserting non-multivalue property';
	INSERT INTO Property (Property_Name, Property_Type,
		Company_Id, Account_Collection_Id, Property_Value
		) VALUES (
		'Singlevalue', 'test', v_company_id, v_account_collection_id, 'test'
		);

	RAISE NOTICE 'Inserting duplicate non-multivalue property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Company_Id, Account_Collection_Id, Property_Value
			) VALUES (
			'Singlevalue', 'test', v_company_id, v_account_collection_id, 'test2'
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN unique_violation THEN
			RAISE NOTICE '... Failed correctly';
	END;

	--
	-- Insert a second property of the same type with a different account_collection_id.
	-- This should succeed.
	--
	RAISE NOTICE 'Inserting same property with different lhs into non-multi-valued property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Company_Id, Account_Collection_Id, Property_Value
			) VALUES (
			'Singlevalue', 'test', v_company_id, v_account_collection_id2, 'test'
			);
		RAISE NOTICE '... Succeeded';
	EXCEPTION
		WHEN unique_violation THEN
			RAISE NOTICE '... Failed.  THIS IS A PROBLEM';
			raise error_in_assignment;
	END;

	--
	-- Insert two of the same property for something that is multivalue
	-- Both should succeed.
	--
	RAISE NOTICE 'Inserting multi-valued property';
	INSERT INTO Property (Property_Name, Property_Type,
		Company_Id, Account_Collection_Id, Property_Value
		) VALUES (
		'Multivalue', 'test', v_company_id, v_account_collection_id, 'test'
		);

	RAISE NOTICE 'Inserting into the same multi-valued property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Company_Id, Account_Collection_Id, Property_Value
			) VALUES (
			'Multivalue', 'test', v_company_id, v_account_collection_id, 'test2'
			);
		RAISE NOTICE '... Succeeded';
	EXCEPTION
		WHEN unique_violation THEN
			RAISE NOTICE '... Failed.  THIS IS A PROBLEM';
			raise error_in_assignment;
	END;

	--
	-- Insert two different properties for a property type that is 
	-- not multivalue.  The second should fail
	--
	RAISE NOTICE 'Inserting a non-multi-valued-type property';
	INSERT INTO Property (Property_Name, Property_Type,
		Company_Id, Account_Collection_Id, Property_Value
		) VALUES (
		'Multivalue', 'multivaluetest', v_company_id, v_account_collection_id, 'test'
		);

	RAISE NOTICE 'Inserting a different non-multivalue-type property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Company_Id, Account_Collection_id, Property_Value
			) VALUES (
			'AnotherProperty', 'multivaluetest', v_company_id, v_account_collection_id, 
				'test2'
			);
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN unique_violation THEN
			RAISE NOTICE '... Failed correctly';
	END;


	--
	-- Check LHS attributes
	--

	RAISE NOTICE 'Inserting no values into property with all ALLOWED lhs fields';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'Allowed', 'test', 'test'
			);
		RAISE NOTICE '... Succeeded';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed.  THIS IS A PROBLEM';
			raise error_in_assignment;
	END;

	RAISE NOTICE 'Inserting all values into property with all ALLOWED lhs fields';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
			) VALUES (
			'Allowed', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			v_dns_domain_id,
			v_operating_system_id,
			v_service_environment,
			v_site_code,
			v_system_user_id,
			v_account_collection_id
			);
		RAISE NOTICE '... Succeeded';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed.  THIS IS A PROBLEM';
			raise error_in_assignment;
	END;

	RAISE NOTICE 'Inserting all values into property with all REQUIRED lhs fields';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			v_dns_domain_id,
			v_operating_system_id,
			v_service_environment,
			v_site_code,
			v_system_user_id,
			v_account_collection_id
			);
		RAISE NOTICE '... Succeeded';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed.  THIS IS A PROBLEM';
			raise error_in_assignment;
	END;

	RAISE NOTICE 'Omitting Company_ID from property with REQUIRED Company_ID lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			NULL,
			v_device_collection_id,
			v_dns_domain_id,
			v_operating_system_id,
			v_service_environment,
			v_site_code,
			v_system_user_id,
			v_account_collection_id
			);
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Omitting Device_Collection_ID from property with REQUIRED Device_Collection_ID lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			NULL,
			v_dns_domain_id,
			v_operating_system_id,
			v_service_environment,
			v_site_code,
			v_system_user_id,
			v_account_collection_id
			);
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Omitting DNS_Domain_ID from property with REQUIRED DNS_Domain_ID lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			NULL,
			v_operating_system_id,
			v_service_environment,
			v_site_code,
			v_system_user_id,
			v_account_collection_id
			);
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Omitting Operating_System_ID from property with REQUIRED Operating_System_ID lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			v_dns_domain_id,
			NULL,
			v_service_environment,
			v_site_code,
			v_system_user_id,
			v_account_collection_id
			);
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Omitting service_environment from property with REQUIRED service_environment lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			v_dns_domain_id,
			v_operating_system_id,
			NULL,
			v_site_code,
			v_system_user_id,
			v_account_collection_id
			);
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Omitting Site_Code from property with REQUIRED Site_Code lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			v_dns_domain_id,
			v_operating_system_id,
			v_service_environment,
			NULL,
			v_system_user_id,
			v_account_collection_id
			);
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Omitting System_User_ID from property with REQUIRED System_User_ID lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			v_dns_domain_id,
			v_operating_system_id,
			v_service_environment,
			v_site_code,
			NULL,
			v_account_collection_id
			);
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Omitting Account_Collection_Id from property with REQUIRED Account_Collection_Id lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			v_company_id,
			v_device_collection_id,
			v_dns_domain_id,
			v_operating_system_id,
			v_service_environment,
			v_site_code,
			v_system_user_id,
			NULL
			);
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting no values into property with all PROHIBITED lhs fields';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
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
		RAISE NOTICE '... Succeeded';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed.  THIS IS A PROBLEM';
			raise error_in_assignment;
	END;

	RAISE NOTICE 'Adding Company_ID to property with PROHIBITED Company_ID lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
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
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;
	
	RAISE NOTICE 'Adding Device_Collection_ID to property with PROHIBITED Device_Collection_ID lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
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
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Adding DNS_Domain_ID to property with PROHIBITED DNS_Domain_ID lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
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
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Adding Operating_System_ID to property with PROHIBITED Operating_System_ID lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
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
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Adding service_environment to property with PROHIBITED service_environment lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
			) VALUES (
			'Prohibited', 'test', 'test',
			NULL,
			NULL,
			NULL,
			NULL,
			v_service_environment,
			NULL,
			NULL,
			NULL
			);
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Adding Site_Code to property with PROHIBITED Site_Code lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
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
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Adding System_User_ID to property with PROHIBITED System_User_ID lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
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
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Adding Account_Collection_Id to property with PROHIBITED Account_Collection_Id lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			Company_ID,
			Device_Collection_ID,
			DNS_Domain_ID,
			Operating_System_ID,
			service_environment,
			Site_Code,
			System_User_ID,
			Account_Collection_id
			) VALUES (
			'Prohibited', 'test', 'test',
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			v_account_collection_id
			);
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;



  --
	-- Now test setting RHS values
	--

	--
	-- string
	--

	RAISE NOTICE 'Inserting timestamp value into string property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'string', 'test',
			now()
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Company_ID value into string property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'string', 'test',
			v_company_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting DNS_Domain_ID value into string property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'string', 'test',
			v_dns_domain_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Netblock_ID value into string property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'string', 'test',
			v_netblock_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Password_Type value into string property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'string', 'test',
			v_password_type
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting SW_Package_ID value into string property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'string', 'test',
			v_sw_package_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Token_Collection_ID value into string property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'string', 'test',
			v_token_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Account_Collection_id value into string property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Account_Collection_id
			) VALUES (
			'string', 'test',
			v_account_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	--
	-- Timestamp
	--

	RAISE NOTICE 'Inserting string value into timestamp property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'timestamp', 'test',
			'test'
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting timestamp value into timestamp property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'timestamp', 'test',
			now()
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed';
			raise error_in_assignment;
	END;
	DELETE FROM Property where Property_ID = v_property_id;

	RAISE NOTICE 'Inserting Company_ID value into timestamp property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'timestamp', 'test',
			v_company_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting DNS_Domain_ID value into timestamp property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'timestamp', 'test',
			v_dns_domain_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Netblock_ID value into timestamp property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'timestamp', 'test',
			v_netblock_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Password_Type value into timestamp property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'timestamp', 'test',
			v_password_type
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting SW_Package_ID value into timestamp property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'timestamp', 'test',
			v_sw_package_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Token_Collection_ID value into timestamp property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'timestamp', 'test',
			v_token_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Account_Collection_id value into timestamp property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Account_Collection_id
			) VALUES (
			'timestamp', 'test',
			v_account_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	--
	-- Company_ID
	--

	RAISE NOTICE 'Inserting string value into company_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'company_id', 'test',
			'test'
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting timestamp value into company_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'company_id', 'test',
			now()
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Company_ID value into company_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'company_id', 'test',
			v_company_id
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed';
			raise error_in_assignment;
	END;
	DELETE FROM Property where Property_ID = v_property_id;

	RAISE NOTICE 'Inserting DNS_Domain_ID value into company_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'company_id', 'test',
			v_dns_domain_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Netblock_ID value into company_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'company_id', 'test',
			v_netblock_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Password_Type value into company_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'company_id', 'test',
			v_password_type
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting SW_Package_ID value into company_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'company_id', 'test',
			v_sw_package_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Token_Collection_ID value into company_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'company_id', 'test',
			v_token_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Account_Collection_id value into company_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Account_Collection_id
			) VALUES (
			'company_id', 'test',
			v_account_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;


	--
	-- DNS_Domain_ID
	--

	RAISE NOTICE 'Inserting string value into dns_domain_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'dns_domain_id', 'test',
			'test'
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting timestamp value into dns_domain_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'dns_domain_id', 'test',
			now()
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Company_ID value into dns_domain_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'dns_domain_id', 'test',
			v_company_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting dns_domain_id value into dns_domain_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_dns_domain_id
			) VALUES (
			'dns_domain_id', 'test',
			v_dns_domain_id
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed';
			raise error_in_assignment;
	END;
	DELETE FROM Property where Property_ID = v_property_id;

	RAISE NOTICE 'Inserting Netblock_ID value into dns_domain_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'dns_domain_id', 'test',
			v_netblock_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Password_Type value into dns_domain_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'dns_domain_id', 'test',
			v_password_type
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting SW_Package_ID value into dns_domain_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'dns_domain_id', 'test',
			v_sw_package_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Token_Collection_ID value into dns_domain_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'dns_domain_id', 'test',
			v_token_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Account_Collection_id value into dns_domain_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Account_Collection_id
			) VALUES (
			'dns_domain_id', 'test',
			v_account_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	--
	-- Netblock_ID
	--

	RAISE NOTICE 'Inserting string value into netblock_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'netblock_id', 'test',
			'test'
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting timestamp value into netblock_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'netblock_id', 'test',
			now()
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Company_ID value into netblock_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'netblock_id', 'test',
			v_company_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting DNS_Domain_ID value into netblock_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'netblock_id', 'test',
			v_dns_domain_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Netblock_ID value into netblock_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'netblock_id', 'test',
			v_netblock_id
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed';
			raise error_in_assignment;
	END;
	DELETE FROM Property where Property_ID = v_property_id;

	RAISE NOTICE 'Inserting Password_Type value into netblock_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'netblock_id', 'test',
			v_password_type
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting SW_Package_ID value into netblock_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'netblock_id', 'test',
			v_sw_package_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Token_Collection_ID value into netblock_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'netblock_id', 'test',
			v_token_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Account_Collection_id value into netblock_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Account_Collection_id
			) VALUES (
			'netblock_id', 'test',
			v_account_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	--
	-- Password_Type
	--

	RAISE NOTICE 'Inserting string value into password_type property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'password_type', 'test',
			'test'
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting timestamp value into password_type property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'password_type', 'test',
			now()
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Company_ID value into password_type property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'password_type', 'test',
			v_company_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting DNS_Domain_ID value into password_type property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'password_type', 'test',
			v_dns_domain_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Netblock_ID value into password_type property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'password_type', 'test',
			v_netblock_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Password_Type value into password_type property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'password_type', 'test',
			v_password_type
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed';
			raise error_in_assignment;
	END;
	DELETE FROM Property where Property_ID = v_property_id;

	RAISE NOTICE 'Inserting SW_Package_ID value into password_type property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'password_type', 'test',
			v_sw_package_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Token_Collection_ID value into password_type property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'password_type', 'test',
			v_token_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Account_Collection_id value into password_type property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Account_Collection_id
			) VALUES (
			'password_type', 'test',
			v_account_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	--
	-- SW_Package_ID
	--

	RAISE NOTICE 'Inserting string value into sw_package_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'sw_package_id', 'test',
			'test'
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting timestamp value into sw_package_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'sw_package_id', 'test',
			now()
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Company_ID value into sw_package_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'sw_package_id', 'test',
			v_company_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting DNS_Domain_ID value into sw_package_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'sw_package_id', 'test',
			v_dns_domain_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Netblock_ID value into sw_package_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'sw_package_id', 'test',
			v_netblock_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Password_Type value into sw_package_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'sw_package_id', 'test',
			v_password_type
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Skipping test for inserting SW_Package_ID value into sw_package_id property';
--	RAISE NOTICE 'Inserting SW_Package_ID value into sw_package_id property';
--	BEGIN
--		INSERT INTO Property (Property_Name, Property_Type,
--			Property_Value_SW_Package_ID
--			) VALUES (
--			'sw_package_id', 'test',
--			v_sw_package_id
--			) RETURNING Property_ID INTO v_property_id;
--		RAISE NOTICE '... Success';
--	EXCEPTION
--		WHEN invalid_parameter_value THEN
--			RAISE NOTICE '... Failed';
--			raise error_in_assignment;
--	END;
--	DELETE FROM Property where Property_ID = v_property_id;

	RAISE NOTICE 'Inserting Token_Collection_ID value into sw_package_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'sw_package_id', 'test',
			v_token_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Account_Collection_id value into sw_package_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Account_Collection_id
			) VALUES (
			'sw_package_id', 'test',
			v_account_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	--
	-- Token_Collection_ID
	--

	RAISE NOTICE 'Inserting string value into token_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'token_collection_id', 'test',
			'test'
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting timestamp value into token_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'token_collection_id', 'test',
			now()
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Company_ID value into token_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'token_collection_id', 'test',
			v_company_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting DNS_Domain_ID value into token_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'token_collection_id', 'test',
			v_dns_domain_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Netblock_ID value into token_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'token_collection_id', 'test',
			v_netblock_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Password_Type value into token_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'token_collection_id', 'test',
			v_password_type
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting SW_Package_ID value into token_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'token_collection_id', 'test',
			v_sw_package_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Token_Collection_ID value into token_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'token_collection_id', 'test',
			v_token_collection_id
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed';
			raise error_in_assignment;
	END;
	DELETE FROM Property where Property_ID = v_property_id;

	RAISE NOTICE 'Inserting Account_Collection_id value into token_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Account_Collection_id
			) VALUES (
			'token_collection_id', 'test',
			v_account_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	--
	-- Account_Collection_Id
	--

	RAISE NOTICE 'Inserting string value into account_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'account_collection_id', 'test',
			'test'
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting timestamp value into account_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'account_collection_id', 'test',
			now()
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Company_ID value into account_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'account_collection_id', 'test',
			v_company_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting DNS_Domain_ID value into account_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'account_collection_id', 'test',
			v_dns_domain_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Netblock_ID value into account_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'account_collection_id', 'test',
			v_netblock_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Password_Type value into account_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'account_collection_id', 'test',
			v_password_type
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting SW_Package_ID value into account_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_SW_Package_ID
			) VALUES (
			'account_collection_id', 'test',
			v_sw_package_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Token_Collection_ID value into account_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'account_collection_id', 'test',
			v_token_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Account_Collection_id value into account_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Account_Collection_id
			) VALUES (
			'account_collection_id', 'test',
			v_account_collection_id
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed';
			raise error_in_assignment;
	END;
	DELETE FROM Property where Property_ID = v_property_id;

	--
	-- none
	--

	RAISE NOTICE 'Inserting string value into none property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'none', 'test',
			'test'
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting timestamp value into none property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'none', 'test',
			now()
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Company_ID value into none property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Company_ID
			) VALUES (
			'none', 'test',
			v_company_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting DNS_Domain_ID value into none property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_DNS_Domain_ID
			) VALUES (
			'none', 'test',
			v_dns_domain_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Netblock_ID value into none property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Netblock_ID
			) VALUES (
			'none', 'test',
			v_netblock_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Password_Type value into none property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'none', 'test',
			v_password_type
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Skipping test inserting SW_Package_ID value into none property';
--	RAISE NOTICE 'Inserting SW_Package_ID value into none property';
--	BEGIN
--		INSERT INTO Property (Property_Name, Property_Type,
--			Property_Value_SW_Package_ID
--			) VALUES (
--			'none', 'test',
--			v_sw_package_id
--			);
--		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
--		raise error_in_assignment;
--	EXCEPTION
--		WHEN invalid_parameter_value THEN
--			RAISE NOTICE '... Failed correctly';
--	END;

	RAISE NOTICE 'Inserting Token_Collection_ID value into none property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_Col_ID
			) VALUES (
			'none', 'test',
			v_token_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting account_collection_id value into none property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Account_Collection_id
			) VALUES (
			'none', 'test',
			v_account_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	--
	-- Boolean
	--

	RAISE NOTICE 'Inserting Y value into boolean property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'boolean', 'test',
			'Y'
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed';
			raise error_in_assignment;
	END;
	DELETE FROM Property WHERE Property_ID = v_property_id;

	RAISE NOTICE 'Inserting N value into boolean property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'boolean', 'test',
			'N'
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed';
			raise error_in_assignment;
	END;
	DELETE FROM Property WHERE Property_ID = v_property_id;

	RAISE NOTICE 'Inserting non-boolean value into boolean property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'boolean', 'test',
			'Vv'
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;
	DELETE FROM Property WHERE Property_ID = v_property_id;

	--
	-- List
	--

	RAISE NOTICE 'Inserting valid value into list property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'list', 'test',
			'value'
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed';
			raise error_in_assignment;
	END;
	DELETE FROM Property WHERE Property_ID = v_property_id;


	RAISE NOTICE 'Inserting invalid value into list property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'list', 'test',
			'Vv'
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;
	DELETE FROM Property WHERE Property_ID = v_property_id;

	RAISE NOTICE 'ALL TESTS PASSED';
	--
	-- Clean up
	--

	DELETE FROM Property WHERE Property_Type IN 
		('test', 'multivaluetest');
	DELETE FROM VAL_Property_Value WHERE Property_Type IN 
		('test', 'multivaluetest');
	DELETE FROM VAL_Property WHERE Property_Type IN
		('test', 'multivaluetest');
	DELETE FROM VAL_Property_Type WHERE Property_Type IN
		('test', 'multivaluetest');

	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT validate_property_triggers();
DROP FUNCTION validate_property_triggers();

\t off
