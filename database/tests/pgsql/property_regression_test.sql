-- Copyright (c) 2014-2021 Todd Kover
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

\set ON_ERROR_STOP

\t on

-- tests this, but does not work just yet because it assumes global test
-- data is there; need to do that before rewritten to use proper savepoints.

SAVEPOINT property_trigger_test;
-- Tests things in here
-- \ir ../../pkg/pgsql/property_utils.sql
-- \ir ../../ddl/schema/pgsql/create_property_triggers.sql

CREATE FUNCTION validate_property_triggers() RETURNS BOOLEAN AS $$
DECLARE
	v_property_id			Property.property_id%TYPE;
	v_company_collection_id		Property.company_collection_id%TYPE;
	v_device_collection_id	Property.device_collection_id%TYPE;
	v_operating_system_id	Property.operating_system_id%TYPE;
	v_svc_environment_id			Property.service_environment_collection_id%TYPE;
	v_prop_collection_id			Property.property_name_collection_id%TYPE;
	v_site_code				Property.site_code%TYPE;
	v_account_id			Property.account_id%TYPE;
	v_account_realm_id		account_realm.account_realm_id%TYPE;
	v_account_collection_id				Property.account_collection_id%TYPE;
	v_account_collection_id2			Property.account_collection_id%TYPE;
	v_net_collection_Id			Property.property_value_netblock_collection_id%TYPE;
	v_dev_collection_Id			Property.property_value_netblock_collection_id%TYPE;
	v_password_type			Property.Property_Value_Password_Type%TYPE;
	v_token_collection_id	Property.Property_Value_Token_collection_ID%TYPE;
	v_private_key_id		property.property_value_private_key_id%TYPE;
	v_encryption_key_id		property.property_value_private_key_id%TYPE;
	_r	RECORD;
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

	DELETE FROM property_name_collection where
		property_name_collection_type like 'JHTEST%';
	DELETE FROM val_property_name_collection_type where
		property_name_collection_type like 'JHTEST%';

--
-- Set up VAL_Property_Data_Type for test data
--

	INSERT INTO VAL_Property_Type ( Property_Type, Is_Multivalue ) VALUES
		('test', true);
	INSERT INTO VAL_Property_Type ( Property_Type, Is_Multivalue ) VALUES
		('multivaluetest', false);

--
-- Set up VAL_Property_Data_Type for test data
--

	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		Property_Data_Type,
		Permit_Company_Id,
		Permit_Company_Collection_Id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		Permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		Permit_Account_Collection_Id
	) VALUES (
		'Prohibited',
		'test',
		false,
		'string',
		'PROHIBITED',
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
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		Permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'Multivalue',
		'test',
		true,
		'string',
		'ALLOWED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'Singlevalue',
		'test',
		false,
		NULL,
		'string',
		'ALLOWED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'Multivalue',
		'multivaluetest',
		false,
		NULL,
		'string',
		'ALLOWED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'AnotherProperty',
		'multivaluetest',
		false,
		NULL,
		'string',
		'ALLOWED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'Allowed',
		'test',
		false,
		NULL,
		'string',
		'ALLOWED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'Required',
		'test',
		false,
		NULL,
		'string',
		'REQUIRED',
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
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'RestrictAccount_Collection',
		'test',
		false,
		'string',
		'PROHIBITED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'boolean',
		'test',
		false,
		NULL,
		'boolean',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED',
		'PROHIBITED'
	);

/*
    INSERT INTO VAL_Property (
	     Property_Name,
	     Property_Type,
	     Is_Multivalue,
	     property_value_account_collection_Type_restriction,
	     Property_Data_Type,
	     Permit_Company_Collection_id,
	     Permit_Device_Collection_Id,
	     Permit_Operating_System_Id,
	     permit_service_environment_collection_id,
	     permit_property_name_collection_id,
	     Permit_Site_Code,
	     Permit_Account_Id,
	     permit_account_realm_id,
	     Permit_Account_Collection_Id
     ) VALUES (
	     'company_collection_id',
	     'test',
	     false,
	     NULL,
	     'none',
	     'PROHIBITED',
	     'PROHIBITED',
	     'PROHIBITED',
	     'PROHIBITED',
	     'PROHIBITED',
	     'PROHIBITED',
	     'PROHIBITED',
	     'PROHIBITED',
	     'PROHIBITED'
     );
*/

	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'netblock_collection_id',
		'test',
		false,
		NULL,
		'netblock_collection_id',
		'PROHIBITED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'device_collection_id',
		'test',
		false,
		NULL,
		'device_collection_id',
		'PROHIBITED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'none',
		'test',
		false,
		NULL,
		'none',
		'PROHIBITED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'number',
		'test',
		false,
		NULL,
		'string',
		'PROHIBITED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'password_type',
		'test',
		false,
		NULL,
		'password_type',
		'PROHIBITED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'string',
		'test',
		false,
		NULL,
		'string',
		'PROHIBITED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'timestamp',
		'test',
		false,
		NULL,
		'timestamp',
		'PROHIBITED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'token_collection_id',
		'test',
		false,
		NULL,
		'token_collection_id',
		'PROHIBITED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_Id
	) VALUES (
		'account_collection_id',
		'test',
		false,
		NULL,
		'account_collection_id',
		'PROHIBITED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_id
	) VALUES (
		'list',
		'test',
		false,
		NULL,
		'list',
		'PROHIBITED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_id
	) VALUES (
		'encryption_key_id',
		'test',
		false,
		NULL,
		'encryption_key_id',
		'PROHIBITED',
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
		property_value_account_collection_Type_restriction,
		Property_Data_Type,
		permit_company_collection_id,
		Permit_Device_Collection_Id,
		Permit_Operating_System_Id,
		permit_service_environment_collection_id,
		permit_property_name_collection_id,
		Permit_Site_Code,
		Permit_Account_Id,
		permit_account_realm_id,
		Permit_Account_Collection_id
	) VALUES (
		'private_key_id',
		'test',
		false,
		NULL,
		'private_key_id',
		'PROHIBITED',
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

	INSERT INTO val_property_name_collection_type (
		property_name_collection_type ) values ( 'JHTEST-PCT');
	INSERT INTO property_name_collection (
		property_name_collection_name, property_name_collection_type )
		values ('JHTEST', 'JHTEST-PCT');

	--
	-- Get some valid data to work with.  Some of these are inserted, some are
	-- picked from what's already in the db.  They should all be inserted here
	-- but, time.
	--

	PERFORM company_manip.add_company(_company_name := 'JHTEST');
	SELECT company_collection_id INTO v_company_collection_id
	FROM company_collection LIMIT 1;

	SELECT Device_Collection_ID INTO v_device_collection_id FROM
		Device_Collection LIMIT 1;
	SELECT Operating_System_ID INTO v_operating_system_id FROM Operating_System
		LIMIT 1;
	SELECT service_environment_collection_id INTO v_svc_environment_id FROM service_environment_collection
		LIMIT 1;
	SELECT property_name_collection_id INTO v_prop_collection_id
		FROM property_name_collection
		LIMIT 1;

	INSERT INTO site (site_code,site_status) VALUES ('MOON0', 'ACTIVE')
		RETURNING site_code INTO v_site_code;

	SELECT Account_Id INTO v_account_Id FROM account
		LIMIT 1;
	SELECT Account_Collection_Id INTO v_account_collection_id FROM Account_Collection
		WHERE Account_Collection_Type = 'per-account' LIMIT 1;
	SELECT Account_Realm_Id INTO v_account_realm_id FROM Account_realm
		LIMIT 1;
	SELECT Account_Collection_Id INTO v_account_collection_id2 FROM Account_Collection
		WHERE Account_Collection_Type <> 'per-account' LIMIT 1;
	SELECT Netblock_Collection_id INTO v_net_collection_Id FROM Netblock_Collection
		LIMIT 1;
	SELECT Password_Type INTO v_password_type FROM VAL_Password_Type
		LIMIT 1;

	WITH t AS (
		INSERT INTO val_token_collection_type (token_collection_type)
			VALUES ('JHTEST') RETURNING *
	), tc AS ( INSERT INTO token_collection (
		token_collection_name, token_collection_type
		) SELECT token_collection_type, token_collection_type FROM t
		RETURNING *
	) SELECT token_collection_id INTO v_token_collection_id FROM tc LIMIT 1;

	WITH pkh AS (
		INSERT INTO public_key_hash (description) values (null)
		RETURNING *
	), pkhh AS (
		INSERT INTO public_key_hash_hash (
			public_key_hash_id, x509_fingerprint_hash_algorighm, calculated_hash
		) VALUES
			((SELECT public_key_hash_id FROM pkh), 'sha1', '907a7748e7952124e38b68a0f65e92fcb05e2155'),
			((SELECT public_key_hash_id FROM pkh), 'sha256', '95b1668634903fb069e4da54bb16de17b81b09572a4bc599d72fa845540f619f')
		RETURNING *
	) INSERT INTO private_key (
		private_key_encryption_type, public_key_hash_id, private_key
	) SELECT DISTINCT
		'rsa', public_key_hash_id,
'-----BEGIN RSA PRIVATE KEY-----
MIIFvwIBAAKCAUALSbsxTO0wLSXjSVAhEqnj1ujImqbXeFw6xEkWm6ssBv8se1VD
fMBIW4i12t5TbRiXBf1F47LCzmemqDJw870gJGprVRWwczjHltNoRc6rmv5LcQ/g
85zFQrw3UqIFzL6Lm1Rnuam/j0cxgQM8IkmVqEPx6kNVcvBVZmYe1mfgDurcQZ1T
kGwG6Rwiy+oHAvtrDlrdHdmfKFj4OjKZtl2rPEtR1chg4T6iHHu3vFn2SkpIogh6
9cSQJH8PmnPh/vqphSjCug4yeaR/kWiIlzhqy/wjJ7UwVyckBKsYy3e/RRLClFJt
DqYtRpPpYhPIrP5rJetkXE0BL0k2TqYfvKHb44r7EmjMFEDfnC8FZrBrWFhUxBbu
eFGdBSgboW+KMUtpT77pA4vO+Tq7+y0XEVAENL+YV8ulljI4CCUFaQdaKQIDAQAB
AoIBQAiwdEHqNrecOYsx91XOOStjVwR9UCuTwmOWj7Cwml6k8C88rZDq6lWI6L8c
wYI0+/XdrW7sbcJaAx4eYd3jMtYYUjdXYv/WYoH5z7l36zTcdh565T9EKI0M5zgr
CwAt8QwkwR+ro0kLsUEhT+0tc7mZstv5emW/udPzpG7em022DgMJG2OlTBMxxO/g
SsGlAQcTIM0P2mMTOxGyMxtyb747LhCkC+SQGslynuHUp+SgGjBE5xoRgn05sWj1
M1Oxlz4CoNBRwiiN70y5HzSt7xBMMWoprKK0vZ5HK1CZ4+dbzMf6PI+4/cs4RGCs
LLJ+XoVWKTbdnU8JDxvR/+6eORyLjDaSL6e0N/jNEd68PbHtJRF0ilvj8wHEf7Tb
XTCgtJcO2nO/wCe0ZAZ6iLmHZoTuYBuU5AVhZGBsWKheqzIVAoGgODzb4mZ8ap57
dd/09Xix+5bv9chaTmlydKFpk3BUcZsP21KTUfR+etOlK7KJmejcMeRIQoSkSML2
TTuTlyrPmm24PXdzbtoxBntxF2tIF7kYRSmafB02iP9vvLzKt6p502TXnm5/OyNf
Cz/wkEqO5H+Zo7MZeWX4YPLZpUfj3bARf+owyPPHOV6IhT7yDLjnPYY8y3pwtrWu
cdVGGztorwKBoDNiW3OTNns/IpwIGk2SbdTelruRfbseNXrlSttoaGXNqBNR3Afk
TvAGTHvOK/F0ABxPRBurdUKMvQjoXnw/ku7PDsyzhDrAipuw7SnDjPl5u+UaXNZT
gI0ETBKYYGaLQM/jOfddIBO4tB9F/LKmwyRe8laceHt1K/vusiuPWx0oNJKe3JTB
wUh6/vFJ5SPuAtfUDpRCvjconhBbM6N+8KcCgaAFTulKY3YW8kKhC7Spfuz93G9l
+bVcdWOSUrIOcqnl10cV4qN5NuTBXzzV9RI77tjp9KxFaxO+snhhLeBugmH6J6Ue
WCoTKpE6FWjFVyEE7Dm4PYcRdAhzwfigDgnscDDznS8lCzUDNgGApFZmqEL4mnq8
EumypcdeD04v5atCf54HPum/7hK9/YhRW3GpdcKN8h/G7RW6iUegAwuNAnyNAoGg
Cwyyl8bnZ1drTNxdM6MyZR08krc1r2BOpc/a6hWopYO1CfqHc1cANpNULSdnwbNt
NqlA/yY+wAHdwKWfc96D7UCvcQuFetDevZ4tUdbQYPFxm1Gw9xHbyfdLmJAV4tc9
J7c4Rt5KwJLugO8e6Rf9TLvyJvfc3MeUnsd0nvNj54A21fS9gGut8bUpT5/RW4ma
KOlb/TvhBaGBZAkIsLbibwKBoBTgSKTdeHayQttvSOJbB0+pgofENI/smQG+wHeF
ZT/ZUzw5bdiV1p1UfU0bY0wHBwVIIajv19zavoLFwy9MtWNEL5y4vPD9uSNcLrfO
lnkQSN5uP0nexuZ6XVvVb+8vrixvnRTZw3QBvQgqVlOHPO5y2MO8/hBcyC+c1VIM
Wx8Cnfff014Sk0b/BSBxSP9PQWjkh8PEQRiGajDRd93FJ2w=
-----END RSA PRIVATE KEY-----'
	FROM pkh
	RETURNING private_key_id INTO v_private_key_id;

	INSERT INTO val_encryption_method (encryption_method, cipher, key_size, cipher_chain_mode, cipher_padding, passphrase_cryptographic_hash_algorithm ) VALUES ('JHTEST', 'none', 0, 'none', 'none', 'none');
	INSERT INTO val_encryption_key_purpose (encryption_key_purpose, encryption_key_purpose_version) VALUES ('JHTEST', 1);

	INSERT INTO encryption_key (
		encryption_key_db_value,
		encryption_key_purpose, encryption_key_purpose_version,
		encryption_method
	) VALUES (
		'',
		'JHTEST', 1,
		'JHTEST'
	) RETURNING encryption_key_id INTO v_encryption_key_id;

	RAISE NOTICE 'v_company_collection_id is %', v_company_collection_id;
	RAISE NOTICE 'v_device_collection_id is %', v_device_collection_id;
	RAISE NOTICE 'v_operating_system_id is %', v_operating_system_id;
	RAISE NOTICE 'v_svc_environment_id is %', v_svc_environment_id;
	RAISE NOTICE 'v_prop_collection_id is %', v_prop_collection_id;
	RAISE NOTICE 'v_site_code is %', v_site_code;
	RAISE NOTICE 'v_account_Id is %', v_account_Id;
	RAISE NOTICE 'v_account_realm_id is %', v_account_realm_id;
	RAISE NOTICE 'v_account_collection_id is %', v_account_collection_id;
	RAISE NOTICE 'v_account_collection_id2 is %', v_account_collection_id2;
	RAISE NOTICE 'v_net_collection_Id is %', v_net_collection_Id;
	RAISE NOTICE 'v_password_type is %', v_password_type;
	RAISE NOTICE 'v_token_collection_id is %', v_token_collection_id;
	RAISE NOTICE 'v_private_key_id is %', v_private_key_id;
	RAISE NOTICE 'v_encryption_key_id is %', v_encryption_key_id;

	INSERT INTO VAL_Property (
		Property_Name,
		Property_Type,
		Is_Multivalue,
		account_collection_type,
		Property_Data_Type,
		Permit_Account_Collection_id
	) VALUES (
		'actype',
		'test',
		true,
		(select account_collection_type from account_collection
			where account_collection_id = v_account_collection_id),
		'string',
		'REQUIRED'
	);

	--
	-- Check for multivalue stuff
	--

	--
	-- Insert two of the same property for something that is not multivalue
	-- The first should work, the second should fail
	--
	RAISE NOTICE 'Inserting non-multivalue property';
	INSERT INTO Property (Property_Name, Property_Type,
		company_collection_id, Account_Collection_Id, Property_Value
		) VALUES (
		'Singlevalue', 'test', v_company_collection_id, v_account_collection_id, 'test'
		);

	RAISE NOTICE 'Inserting duplicate non-multivalue property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			company_collection_id, Account_Collection_Id, Property_Value
			) VALUES (
			'Singlevalue', 'test', v_company_collection_id, v_account_collection_id, 'test2'
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
			company_collection_id, Account_Collection_Id, Property_Value
			) VALUES (
			'Singlevalue', 'test', v_company_collection_id, v_account_collection_id2, 'test'
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
		company_collection_id, Account_Collection_Id, Property_Value
		) VALUES (
		'Multivalue', 'test', v_company_collection_id, v_account_collection_id, 'test'
		);

	RAISE NOTICE 'Inserting into the same multi-valued property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			company_collection_id, Account_Collection_Id, Property_Value
			) VALUES (
			'Multivalue', 'test', v_company_collection_id, v_account_collection_id, 'test2'
			);
		RAISE NOTICE '... Succeeded';
	EXCEPTION
		WHEN unique_violation THEN
			RAISE NOTICE '... Failed.  THIS IS A PROBLEM';
			raise error_in_assignment;
	END;

	RAISE NOTICE 'Inserting an identical multi-valued property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			company_collection_id, Account_Collection_Id, Property_Value
			) VALUES (
			'Multivalue', 'test', v_company_collection_id, v_account_collection_id, 'test'
			);
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN unique_violation THEN
			RAISE NOTICE '... Failed correctly';
	END;


	--
	-- Insert two different properties for a property type that is
	-- not multivalue.  The second should fail
	--
	RAISE NOTICE 'Inserting a non-multi-valued-type property';
	INSERT INTO Property (Property_Name, Property_Type,
		company_collection_id, Account_Collection_Id, Property_Value
		) VALUES (
		'Multivalue', 'multivaluetest', v_company_collection_id, v_account_collection_id, 'test'
		);

	RAISE NOTICE 'Inserting a different non-multivalue-type property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			company_collection_id, Account_Collection_id, Property_Value
			) VALUES (
			'AnotherProperty', 'multivaluetest', v_company_collection_id, v_account_collection_id,
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
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			property_name_collection_id,
			Site_Code,
			Account_Id,
			Account_Realm_Id,
			Account_Collection_id
			) VALUES (
			'Allowed', 'test', 'test',
			v_company_collection_id,
			v_device_collection_id,
			v_operating_system_id,
			v_svc_environment_id,
			v_prop_collection_id,
			v_site_code,
			v_account_id,
			v_account_realm_id,
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
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			property_name_collection_id,
			Site_Code,
			Account_Id,
			account_realm_id,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			v_company_collection_id,
			v_device_collection_id,
			v_operating_system_id,
			v_svc_environment_id,
			v_prop_collection_id,
			v_site_code,
			v_account_id,
			v_account_realm_id,
			v_account_collection_id
			);
		RAISE NOTICE '... Succeeded';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed.  THIS IS A PROBLEM (%)', SQLERRM;
			raise error_in_assignment;
	END;

	RAISE NOTICE 'Omitting company_collection_id from property with REQUIRED company_collection_id lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			property_name_collection_id,
			Site_Code,
			account_id,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			NULL,
			v_device_collection_id,
			v_operating_system_id,
			v_svc_environment_id,
			v_prop_collection_id,
			v_site_code,
			v_account_id,
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
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			property_name_collection_id,
			Site_Code,
			account_id,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			v_company_collection_id,
			NULL,
			v_operating_system_id,
			v_svc_environment_id,
			v_prop_collection_id,
			v_site_code,
			v_account_id,
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
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			property_name_collection_id,
			Site_Code,
			account_id,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			v_company_collection_id,
			v_device_collection_id,
			NULL,
			v_svc_environment_id,
			v_prop_collection_id,
			v_site_code,
			v_account_id,
			v_account_collection_id
			);
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Omitting service_environment_collection_id from property with REQUIRED service_environment_collection_id lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			Site_Code,
			account_id,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			v_company_collection_id,
			v_device_collection_id,
			v_operating_system_id,
			NULL,
			v_site_code,
			v_account_id,
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
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			property_name_collection_id,
			Site_Code,
			account_id,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			v_company_collection_id,
			v_device_collection_id,
			v_operating_system_id,
			v_svc_environment_id,
			v_prop_collection_id,
			NULL,
			v_account_id,
			v_account_collection_id
			);
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Omitting account_id from property with REQUIRED account_id lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			property_name_collection_id,
			Site_Code,
			account_id,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			v_company_collection_id,
			v_device_collection_id,
			v_operating_system_id,
			v_svc_environment_id,
			v_prop_collection_id,
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
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			property_name_collection_id,
			Site_Code,
			account_id,
			Account_Collection_id
			) VALUES (
			'Required', 'test', 'test',
			v_company_collection_id,
			v_device_collection_id,
			v_operating_system_id,
			v_svc_environment_id,
			v_prop_collection_id,
			v_site_code,
			v_account_id,
			NULL
			);
		RAISE NOTICE '... Succeeded.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Omitting Account_Realm_Id from property with REQUIRED Account_Realm_Id lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			company_collection_id,
			Device_Collection_ID,
			Account_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			property_name_collection_id,
			Site_Code,
			account_id,
			Account_Realm_Id
			) VALUES (
			'Required', 'test', 'test',
			v_company_collection_id,
			v_device_collection_id,
			v_account_collection_id,
			v_operating_system_id,
			v_svc_environment_id,
			v_prop_collection_id,
			v_site_code,
			v_account_id,
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
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			Site_Code,
			account_id,
			Account_Collection_id
			) VALUES (
			'Prohibited', 'test', 'test',
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

	RAISE NOTICE 'Adding company_collection_id to property with PROHIBITED company_collection_id lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			Site_Code,
			account_id,
			Account_Collection_id
			) VALUES (
			'Prohibited', 'test', 'test',
			v_company_collection_id,
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
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			Site_Code,
			account_id,
			Account_Collection_id
			) VALUES (
			'Prohibited', 'test', 'test',
			NULL,
			v_device_collection_id,
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
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			Site_Code,
			account_id,
			Account_Collection_id
			) VALUES (
			'Prohibited', 'test', 'test',
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

	RAISE NOTICE 'Adding service_environment_collection_id to property with PROHIBITED service_environment_collection_id lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			property_name_collection_id,
			Site_Code,
			account_id,
			Account_Collection_id
			) VALUES (
			'Prohibited', 'test', 'test',
			NULL,
			NULL,
			NULL,
			v_svc_environment_id,
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

	RAISE NOTICE 'Adding property_name_collection_id to property with PROHIBITED property_name_collection_id lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			property_name_collection_id,
			Site_Code,
			account_id,
			Account_Collection_id
			) VALUES (
			'Prohibited', 'test', 'test',
			NULL,
			NULL,
			NULL,
			NULL,
			v_prop_collection_id,
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
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			property_name_collection_id,
			Site_Code,
			account_id,
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

	RAISE NOTICE 'Adding account_id to property with PROHIBITED account_id lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			Site_Code,
			account_id,
			Account_Collection_id
			) VALUES (
			'Prohibited', 'test', 'test',
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			v_account_id,
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
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			Site_Code,
			account_id,
			Account_Collection_id
			) VALUES (
			'Prohibited', 'test', 'test',
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

	RAISE NOTICE 'Adding account_realm_id to property with PROHIBITED account_realm_id lhs field';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value,
			company_collection_id,
			Device_Collection_ID,
			Operating_System_ID,
			service_environment_collection_id,
			Site_Code,
			account_id,
			account_realm_id
			) VALUES (
			'Prohibited', 'test', 'test',
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			v_account_realm_id
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

	RAISE NOTICE 'Inserting Netblock_collection_Id value into string property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			property_value_netblock_collection_id
			) VALUES (
			'string', 'test',
			v_net_collection_Id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Device_collection_Id value into string property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			property_value_device_collection_id
			) VALUES (
			'string', 'test',
			v_device_collection_id
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

	RAISE NOTICE 'Inserting Token_Collection_ID value into string property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_collection_ID
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
			property_value_account_collection_id
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

	RAISE NOTICE 'Inserting Netblock_Collection_id value into timestamp property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			property_value_netblock_collection_id
			) VALUES (
			'timestamp', 'test',
			v_net_collection_Id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Device_Collection_id value into timestamp property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			property_value_device_collection_id
			) VALUES (
			'timestamp', 'test',
			v_device_collection_id
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

	RAISE NOTICE 'Inserting Token_Collection_ID value into timestamp property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_collection_ID
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
			property_value_account_collection_id
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
	-- Netblock_Collection_Id
	--

	RAISE NOTICE 'Inserting string value into Netblock_Collection_Id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'netblock_collection_id', 'test',
			'test'
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting timestamp value into Netblock_Collection_Id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Timestamp
			) VALUES (
			'netblock_collection_id', 'test',
			now()
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Netblock_Collection_Id value into Netblock_Collection_Id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			property_value_netblock_collection_id
			) VALUES (
			'netblock_collection_id', 'test',
			v_net_collection_Id
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed';
			raise error_in_assignment;
	END;
	DELETE FROM Property where Property_ID = v_property_id;

	RAISE NOTICE 'Inserting Device_Collection_Id value into Netblock_Collection_Id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_device_collection_id
			) VALUES (
			'netblock_collection_id', 'test',
			v_device_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Password_Type value into Netblock_Collection_Id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Password_Type
			) VALUES (
			'netblock_collection_id', 'test',
			v_password_type
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Token_Collection_ID value into Netblock_Collection_Id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_collection_ID
			) VALUES (
			'netblock_collection_id', 'test',
			v_token_collection_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Account_Collection_id value into Netblock_Collection_Id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			property_value_account_collection_id
			) VALUES (
			'netblock_collection_id', 'test',
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

	RAISE NOTICE 'Inserting Netblock_Collection_Id value into password_type property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			property_value_netblock_collection_id
			) VALUES (
			'password_type', 'test',
			v_net_collection_Id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Device_Collection_Id value into password_type property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			property_value_device_collection_id
			) VALUES (
			'password_type', 'test',
			v_device_collection_id
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

	RAISE NOTICE 'Inserting Token_Collection_ID value into password_type property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_collection_ID
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
			property_value_account_collection_id
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

	RAISE NOTICE 'Inserting Netblock_Collection_Id value into token_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			property_value_netblock_collection_id
			) VALUES (
			'token_collection_id', 'test',
			v_net_collection_Id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Device_Collection_Id value into token_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			property_value_device_collection_id
			) VALUES (
			'token_collection_id', 'test',
			v_device_collection_id
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

	RAISE NOTICE 'Inserting Token_Collection_ID value into token_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_collection_ID
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
			property_value_account_collection_id
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

	RAISE NOTICE 'Inserting Netblock_Collection_Id value into account_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			property_value_netblock_collection_id
			) VALUES (
			'account_collection_id', 'test',
			v_net_collection_Id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Device_Collection_Id value into account_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			property_value_device_collection_id
			) VALUES (
			'account_collection_id', 'test',
			v_device_collection_id
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

	RAISE NOTICE 'Inserting Token_Collection_ID value into account_collection_id property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_collection_ID
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
			property_value_account_collection_id
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

	RAISE NOTICE 'Inserting encryption_key_id value into none property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_encryption_key_id
			) VALUES (
			'none', 'test',
			v_encryption_key_id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting private_key_id value into none property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value
			) VALUES (
			'none', 'test',
			v_private_key_id
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

	RAISE NOTICE 'Inserting Netblock_Collection_Id value into none property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			property_value_netblock_collection_id
			) VALUES (
			'none', 'test',
			v_net_collection_Id
			);
		RAISE NOTICE '... Insert successful.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Inserting Device_Collection_Id value into none property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			property_value_device_collection_id
			) VALUES (
			'none', 'test',
			v_device_collection_id
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

	RAISE NOTICE 'Inserting Token_Collection_ID value into none property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_Token_collection_ID
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
			property_value_account_collection_id
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

	RAISE NOTICE 'Inserting true value into boolean property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_boolean
			) VALUES (
			'boolean', 'test',
			true
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed';
			raise error_in_assignment;
	END;
	DELETE FROM Property WHERE Property_ID = v_property_id;

	RAISE NOTICE 'Inserting false value into boolean property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_boolean
			) VALUES (
			'boolean', 'test',
			false
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
	-- encryption_key_id
	--
	RAISE NOTICE 'Inserting encryption_key_id INTO property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_encryption_key_id
			) VALUES (
			'encryption_key_id', 'test',
			v_encryption_key_id
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed';
			raise error_in_assignment;
	END;
	DELETE FROM Property WHERE Property_ID = v_property_id;

	--
	-- private_key_id
	--
	RAISE NOTICE 'Inserting private_key_id INTO property';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value_private_key_id
			) VALUES (
			'private_key_id', 'test',
			v_private_key_id
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success';
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed';
			raise error_in_assignment;
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

	RAISE NOTICE 'Trying to see if in-use list item removal fails... ';
	BEGIN
		BEGIN
			DELETE FROM val_property_value
			WHERE property_type = 'test'
			AND property_name = 'list'
			AND valid_property_value  = 'value';
		EXCEPTION WHEN foreign_key_violation THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;

		RAISE EXCEPTION '.. It did not % ', to_json(_r);
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
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

	RAISE NOTICE 'Checking for account_collection_type mismatch';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value, account_collection_id
			) VALUES (
			'actype', 'test',
			'Vv', v_account_collection_id2
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success.  THIS IS A PROBLEM % %',
			v_account_collection_id, v_account_collection_id2;
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;
	DELETE FROM Property WHERE Property_ID = v_property_id;

	RAISE NOTICE 'Checking for account_collection_type match';
	BEGIN
		INSERT INTO Property (Property_Name, Property_Type,
			Property_Value, account_collection_id
			) VALUES (
			'actype', 'test',
			'Vv', v_account_collection_id2
			) RETURNING Property_ID INTO v_property_id;
		RAISE NOTICE '... Success.  THIS IS A PROBLEM';
		raise error_in_assignment;
	EXCEPTION
		WHEN invalid_parameter_value THEN
			RAISE NOTICE '... Failed correctly';
	END;
	DELETE FROM Property WHERE Property_ID = v_property_id;

	RAISE NOTICE 'Checking if json schema must be set on json';
	BEGIN
		INSERT INTO val_property (
			property_name, property_type, property_data_type
		) VALUES (
			'testjson', 'test', 'json'
		);
		RAISE EXCEPTION 'It did not!';
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Checking if json schema must not be set on not json';
	BEGIN
		INSERT INTO val_property (
			property_name, property_type, property_data_type,
			property_value_json_schema
		) VALUES (
			'testjson', 'test', 'string',
			'{"type": "boolean", "required": ["type"]}'
		);
		RAISE EXCEPTION 'It did not!';
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Checking if json schema can be set';
	BEGIN
		INSERT INTO val_property (
			property_name, property_type, property_data_type,
			property_value_json_schema
		) VALUES (
			'testjson', 'test', 'json',
			'{"type": "boolean", "required": ["type"]}'
		);

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Checking bogus JSON Schema validation';
	BEGIN
		INSERT INTO val_property (
			property_name, property_type, property_data_type,
			property_value_json_schema
		) VALUES (
			'testjson', 'test', 'json',
			'{"type": "object", "required": ["is"], "properties": { "is": { "type": "boolean" }}   }'
		);
		INSERT INTO property (
			property_name, property_type,
			property_value_json
		) VALUES (
			'testjson', 'test',
			'{ "is": "foo" }'
		);
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '... Failed correctly';
	END;

	RAISE NOTICE 'Checking successful JSON Schema validation';
	BEGIN
		INSERT INTO val_property (
			property_name, property_type, property_data_type,
			property_value_json_schema
		) VALUES (
			'testjson', 'test', 'json',
			'{"type": "object", "required": ["is"], "properties": { "is": { "type": "boolean" }}   }'
		);
		INSERT INTO property (
			property_name, property_type,
			property_value_json
		) VALUES (
			'testjson', 'test',
			'{ "is": false }'
		);
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	/********** temporary, until company_id is dropped.... *****************/

	RAISE NOTICE 'Checking to see if allowing company_id fails...';
	BEGIN
		INSERT INTO val_property (
			property_name, property_type, property_data_type,
			permit_company_id
		) VALUES (
			'testone', 'test', 'none',
			'ALLOWED'
		);
		RAISE EXCEPTION 'It DID NOT!';
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '.... it failed corretly!';
	END;


	RAISE NOTICE 'Checking to see if allowing company_id fails...';
	BEGIN
		INSERT INTO val_property (
			property_name, property_type, property_data_type,
			permit_company_id
		) VALUES (
			'testone', 'test', 'none',
			'REQUIRED'
		);
		RAISE EXCEPTION 'It DID NOT!';
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '.... it failed corretly!';
	END;

	RAISE NOTICE 'Checking to see if updating company_id REQUIRED fails...';
	BEGIN
		INSERT INTO val_property (
			property_name, property_type, property_data_type
		) VALUES (
			'testing', 'test', 'none'
		);
		UPDATE val_property set permit_company_id = 'REQUIRED'
		WHERE property_name = 'testing' AND property_type = 'test';
		RAISE EXCEPTION 'It DID NOT!';
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '.... it failed corretly!';
	END;

	RAISE NOTICE 'Checking to see if updating company_id ALLOWED fails...';
	BEGIN
		INSERT INTO val_property (
			property_name, property_type, property_data_type
		) VALUES (
			'testing', 'test', 'none'
		);
		UPDATE val_property set permit_company_id = 'ALLOWED'
		WHERE property_name = 'testing' AND property_type = 'test';
		RAISE EXCEPTION 'It DID NOT!';
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '.... it failed corretly!';
	END;

	--
	-- Should do more of these checks.
	--

	RAISE NOTICE 'Checking if changing property requirements works as expected..';
	BEGIN
		INSERT INTO VAL_Property (
			Property_Name, Property_Type,
			Property_Data_Type, Permit_Account_Collection_id
		) VALUES (
			'ac', 'test',
			'none', 'REQUIRED'
		);

		INSERT INTO property (
			property_name, property_type, account_collection_id
		) VALUES (
			'ac', 'test', v_account_collection_id
		);


		BEGIN
			UPDATE val_property set Permit_Account_Collection_id = 'PROHIBITED'
			WHERE property_type = 'test' AND property_name = 'ac';
		EXCEPTION WHEN SQLSTATE 'JH200' THEN
			RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION '.... it did not! (BAD!)';
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '.... it did!';
	END;

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

	DELETE FROM property_name_collection where
		property_name_collection_type like 'JHTEST%';
	DELETE FROM val_property_name_collection_type where
		property_name_collection_type like 'JHTEST%';


	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT validate_property_triggers();
DROP FUNCTION validate_property_triggers();

ROLLBACK TO property_trigger_test;

\t off
