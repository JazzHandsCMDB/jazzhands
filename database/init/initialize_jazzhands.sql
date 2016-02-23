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

-- Copyright (c) 2010-2015, Todd M. Kover
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


--
-- $Id$
--
-- Items that are essential.

INSERT INTO VAL_Account_Type(Account_Type, Is_Person, Uid_Gid_Forced, 
		Description)
	VALUES ('person', 'Y', 'Y', 'person_id is meaningful');
INSERT INTO VAL_Account_Type(Account_Type, Is_Person, Uid_Gid_Forced, 
		Description)
	VALUES ('pseudouser', 'N', 'N', 'person_id is not useful');
INSERT INTO VAL_Account_Type(Account_Type, Is_Person, Uid_Gid_Forced, 
	Description)
	VALUES ('blacklist', 'N', 'N', 'login name blacklist');

INSERT INTO VAL_Person_Status(Person_Status, Description,
		is_enabled, propagate_from_person)
	VALUES ('enabled', 'Enabled', 
		'Y', 'Y');
INSERT INTO VAL_Person_Status(Person_Status, Description,
		is_enabled, propagate_from_person)
	VALUES ('disabled', 'Disabled',
		'N', 'N');
INSERT INTO VAL_Person_Status(Person_Status, Description,
		is_enabled, propagate_from_person)
	VALUES ('forcedisabled', 'User Forced to Disabled status',
		'N', 'N');
INSERT INTO VAL_Person_Status(Person_Status, Description,
		is_enabled, propagate_from_person)
	VALUES ('terminated', 'User has been terminated',
		'N', 'N');
INSERT INTO VAL_Person_Status(Person_Status, Description,
		is_enabled, propagate_from_person)
	VALUES ('autoterminated', 'User has been terminated by auto process',
		'N', 'Y');
INSERT INTO VAL_Person_Status(Person_Status, Description,
		is_enabled, propagate_from_person)
	VALUES ('onleave', 'User is disabled due to being on leave',
		'N', 'Y');

INSERT INTO Val_Person_Company_Relation(Person_Company_Relation, Description)
	VALUES ('employee', 'Employee');
INSERT INTO Val_Person_Company_Relation(Person_Company_Relation, Description)
	VALUES ('consultant', 'Consultant');
INSERT INTO Val_Person_Company_Relation(Person_Company_Relation, Description)
	VALUES ('vendor', 'Vendor');
INSERT INTO Val_Person_Company_Relation(Person_Company_Relation, Description)
	VALUES ('n/a', 'Not a person');

INSERT INTO VAL_ACCOUNT_ROLE (Account_Role, Uid_Gid_Forced, Description)
	VALUES ('primary', 'N', 
		'Primary account for user in this Account Realm');
INSERT INTO VAL_ACCOUNT_ROLE (Account_Role, Uid_Gid_Forced, Description)
	VALUES ('administrator', 'N',
	'Administrative account for user in this Account Realm');
INSERT INTO VAL_ACCOUNT_ROLE (Account_Role, Uid_Gid_Forced, Description)
	VALUES ('test', 'N', 'Test Account for User');

INSERT INTO VAL_Image_Type(Image_Type) VALUES ('jpeg');
INSERT INTO VAL_Image_Type(Image_Type) VALUES ('png');
INSERT INTO VAL_Image_Type(Image_Type) VALUES ('tiff');
INSERT INTO VAL_Image_Type(Image_Type) VALUES ('pnm');

insert into val_account_collection_type 
	(account_collection_type, 
	description,
	max_num_members, can_have_hierarchy
	) 
values 
	('per-account', 
	 'Account_Collection that contain a single account for assigning individual accounts to objects that only accept Account_Collection assignments',
	1, 'N'
	);


INSERT INTO VAL_Account_Collection_Type (Account_Collection_Type, Description)
	VALUES ('systems', 'Account_Collection that can be assigned to system-type objects to control access to system and network resources');
INSERT INTO VAL_Account_Collection_Type (Account_Collection_Type, Description)
	VALUES ('unix-group', 'Account_Collection representing a Unix group');
INSERT INTO VAL_Account_Collection_Type (Account_Collection_Type, Description)
	VALUES ('doors', 'Account_Collection that can be assigned to door-type objects to control access to physical areas');
INSERT INTO VAL_Account_Collection_Type (Account_Collection_Type, Description)
	VALUES ('department', 'Account_Collection for Corporate Departments');
INSERT INTO VAL_Account_Collection_Type (Account_Collection_Type, Description)
	VALUES ('property', 'Account_Collection for storing global property values');
INSERT INTO VAL_Account_Collection_Type (Account_Collection_Type, Description)
	VALUES ('site', 'automatic Account_Collectiones defined by user site');
INSERT INTO VAL_Account_Collection_Type (Account_Collection_Type, Description)
	VALUES ('automated', 'automatic Account_Collectiones managed by trigger');

INSERT INTO VAL_Device_Status (Device_Status, Description)
	VALUES ('unknown', 'Unknown or incompletely entered');
INSERT INTO VAL_Device_Status (Device_Status, Description)
	VALUES ('up', 'Up/Normal');
INSERT INTO VAL_Device_Status (Device_Status, Description)
	VALUES ('down', 'Intentionally down or offline');
INSERT INTO VAL_Device_Status (Device_Status, Description)
	VALUES ('removed', 'System has been removed');

insert into val_production_state (production_state)
	values ('production');
insert into val_production_state (production_state)
	values ('development');
insert into val_production_state (production_state)
	values ('test');
insert into val_production_state (production_state)
	values ('unspecified');
insert into val_production_state (production_state)
	values ('unallocated');

insert into val_service_env_coll_type
	( service_env_collection_type ) values ('per-environment');

INSERT INTO service_environment (service_environment_name, production_state)
	VALUES ('unspecified', 'unspecified');
INSERT INTO service_environment (service_environment_name, production_state)
	VALUES ('unallocated', 'unallocated');
INSERT INTO service_environment (service_environment_name, production_state)
	VALUES ('production', 'production');
INSERT INTO service_environment (service_environment_name, production_state)
	VALUES ('development', 'development');
INSERT INTO service_environment (service_environment_name, production_state)
	VALUES ('qa', 'test');
INSERT INTO service_environment (service_environment_name, production_state)
	VALUES ('staging', 'test');
INSERT INTO service_environment (service_environment_name, production_state)
	VALUES ('test', 'test');

INSERT INTO VAL_Ownership_Status (Ownership_Status)
	VALUES ('owned');
INSERT INTO VAL_Ownership_Status (Ownership_Status)
	VALUES ('leased');
INSERT INTO VAL_Ownership_Status (Ownership_Status)
	VALUES ('onloan');
INSERT INTO VAL_Ownership_Status (Ownership_Status)
	VALUES ('unknown');

insert into Val_Person_Contact_Type(person_contact_type)
	values ('chat');
insert into Val_Person_Contact_Type(person_contact_type)
	values ('email');
insert into Val_Person_Contact_Type(person_contact_type)
	values ('phone');

INSERT INTO val_person_contact_Technology (Person_Contact_Technology,
	Person_Contact_Type)
	VALUES ('phone', 'phone');
INSERT INTO val_person_contact_Technology (Person_Contact_Technology,
	Person_Contact_Type)
	VALUES ('mobile', 'phone');
INSERT INTO val_person_contact_Technology (Person_Contact_Technology,
	Person_Contact_Type)
	VALUES ('fax', 'phone');
INSERT INTO val_person_contact_Technology (Person_Contact_Technology,
	Person_Contact_Type)
	VALUES ('voicemail', 'phone');
INSERT INTO val_person_contact_Technology (Person_Contact_Technology,
	Person_Contact_Type)
	VALUES ('conference', 'phone');

INSERT INTO val_person_contact_loc_type (Person_Contact_Location_Type)
	VALUES ('home');
INSERT INTO val_person_contact_loc_type (Person_Contact_Location_Type)
	VALUES ('personal');
INSERT INTO val_person_contact_loc_type (Person_Contact_Location_Type)
	VALUES ('office');

--INSERT INTO VAL_User_Location_Type (System_User_Location_Type)
--	VALUES ('office');
--INSERT INTO VAL_User_Location_Type (System_User_Location_Type)
--	VALUES ('home');

-- Database AppAuthAL methods

INSERT INTO val_appaal_group_name (appaal_group_name, description) VALUES
	('database', 'keys related to database connections');

insert into VAL_APP_KEY (APP_KEY, appaal_group_name, DESCRIPTION) values
	('DBType', 'database', 'Database Type');
insert into VAL_APP_KEY (APP_KEY, appaal_group_name, DESCRIPTION) values
	('Method', 'database', 'Method for Authentication');
insert into VAL_APP_KEY (APP_KEY, appaal_group_name, DESCRIPTION) values
	('Password', 'database', 'Password or equivalent');
insert into VAL_APP_KEY (APP_KEY, appaal_group_name, DESCRIPTION) values
	('ServiceName',  'database',
	'Service Name used for certain methods (DB methods, notably)');
insert into VAL_APP_KEY (APP_KEY, appaal_group_name, DESCRIPTION) values
	('Username', 'database', 'Username or equivalent');

INSERT INTO VAL_APP_KEY_VALUES (APP_KEY, appaal_group_name, APP_VALUE)
	VALUES ('Method', 'database', 'password');

INSERT INTO VAL_APP_KEY_VALUES (APP_KEY, appaal_group_name, APP_VALUE)
	VALUES ('DBType', 'database', 'mysql');
INSERT INTO VAL_APP_KEY_VALUES (APP_KEY, appaal_group_name, APP_VALUE)
	VALUES ('DBType', 'database', 'oracle');
INSERT INTO VAL_APP_KEY_VALUES (APP_KEY, appaal_group_name, APP_VALUE)
	VALUES ('DBType', 'database', 'postgres');
INSERT INTO VAL_APP_KEY_VALUES (APP_KEY, appaal_group_name, APP_VALUE)
	VALUES ('DBType', 'database', 'sqlrelay');
INSERT INTO VAL_APP_KEY_VALUES (APP_KEY, appaal_group_name, APP_VALUE)
	VALUES ('DBType', 'database', 'tds');

INSERT INTO VAL_Device_Collection_Type (Device_Collection_Type)
	VALUES ('mclass');
INSERT INTO VAL_Device_Collection_Type (Device_Collection_Type)
	VALUES ('adhoc');
INSERT INTO VAL_Device_Collection_Type (Device_Collection_Type)
	VALUES ('appgroup');
INSERT INTO VAL_Device_Collection_Type (Device_Collection_Type)
	VALUES ('applicense');
INSERT INTO VAL_Device_Collection_Type (Device_Collection_Type)
	VALUES ('undefined');

-- LDAP AppAuthAL

INSERT INTO val_appaal_group_name (appaal_group_name, description) VALUES
	('ldap', 'keys related to ldap connections');

insert into VAL_APP_KEY (APP_KEY, appaal_group_name, DESCRIPTION) values
	('ServerName', 'ldap', 'Server to Connect to');

insert into VAL_APP_KEY (APP_KEY, appaal_group_name, DESCRIPTION) values
	('Username', 'ldap', 'Username to connect as');
insert into VAL_APP_KEY (APP_KEY, appaal_group_name, DESCRIPTION) values
	('Password', 'ldap', 'Password to connect with');
insert into VAL_APP_KEY (APP_KEY, appaal_group_name, DESCRIPTION) values
	('Domain', 'ldap', 'Domain to connect as');

-- LDAP AppAuthAL

INSERT INTO val_appaal_group_name (appaal_group_name, description) VALUES
	('web', 'keys related to http(s) connections');

insert into VAL_APP_KEY (APP_KEY, appaal_group_name, DESCRIPTION) values
	('URL', 'web', 'URL to connect to');
insert into VAL_APP_KEY (APP_KEY, appaal_group_name, DESCRIPTION) values
	('Username', 'web', 'Username to connect as');
insert into VAL_APP_KEY (APP_KEY, appaal_group_name, DESCRIPTION) values
	('Password', 'web', 'Password to connect with');

--- password types

INSERT INTO val_password_type (password_type, description)
	VALUES 
		('star', 'No Password'),
		('des', 'Unix Style DES Crypt, deprecated'),
		('md5', 'Unix style MD5 Crypt'),
		('sha1', 'Unix style sha1 Crypt'),
		('blowfish', 'Unix style blowfish Ctypt'),
		('oath-only', 'OATH HOTP token sequence numner'),
		('oath+passwd', 'OATH HTOP per-token password+token sequence');

-- XXX VAL_MClass_Unix_Home_Type

INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('point-to-point');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('broadcast');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('loopback');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('virtual');

insert into val_netblock_status (NETBLOCK_STATUS) values ('Allocated');
insert into val_netblock_status (NETBLOCK_STATUS) values ('Deallocated');
insert into val_netblock_status (NETBLOCK_STATUS) values ('Legacy');
insert into val_netblock_status (NETBLOCK_STATUS) values ('ExternalOwned');
insert into val_netblock_status (NETBLOCK_STATUS) values ('Reserved');

INSERT INTO ip_universe (
	ip_universe_id, ip_universe_name, description
) VALUES (
	0, 'default', 'default IP universe'    
);

INSERT INTO val_netblock_type(
	netblock_type, description, db_forced_hierarchy, is_validated_hierarchy
) VALUES (
	'default', 'standard hierarchical netblock type', 'Y', 'Y'
);

INSERT INTO val_netblock_type(
	netblock_type, description, db_forced_hierarchy, is_validated_hierarchy
) VALUES (
	'adhoc', 'standard non-hierarchical netblock type', 'N', 'Y'
);

INSERT INTO val_netblock_type(
	netblock_type, description, db_forced_hierarchy, is_validated_hierarchy
) VALUES (
	'dns', 'organizational groupings used for assigning DNS', 'N', 'N'
);

insert into val_processor_architecture (PROCESSOR_ARCHITECTURE, KERNEL_BITS)
	values ('noarch', 0);
-- consider better how to deal with these
insert into val_processor_architecture (PROCESSOR_ARCHITECTURE, KERNEL_BITS)
	values ('amd64', 64);
insert into val_processor_architecture (PROCESSOR_ARCHITECTURE, KERNEL_BITS)
	values ('x86_64', 64);
insert into val_processor_architecture (PROCESSOR_ARCHITECTURE, KERNEL_BITS)
	values ('i386', 32);
insert into val_processor_architecture (PROCESSOR_ARCHITECTURE, KERNEL_BITS)
	values ('i686', 32);
insert into val_processor_architecture (PROCESSOR_ARCHITECTURE, KERNEL_BITS)
	values ('powerpc', 64);
insert into val_processor_architecture (PROCESSOR_ARCHITECTURE, KERNEL_BITS)
	values ('sparc', 64);

/*
insert into val_power_plug_style (power_plug_style) values ('DC');
insert into val_power_plug_style (power_plug_style) values ('Hubbell CS8365C');
insert into val_power_plug_style (power_plug_style) values ('IEC-60320-C13');
insert into val_power_plug_style (power_plug_style) values ('IEC-60320-C13/14');
insert into val_power_plug_style (power_plug_style) values ('IEC-60320-C19/20');
insert into val_power_plug_style (power_plug_style) values ('NEMA 5-15P');
insert into val_power_plug_style (power_plug_style) values ('NEMA 5-20P');
insert into val_power_plug_style (power_plug_style) values ('NEMA 5-30P');
insert into val_power_plug_style (power_plug_style) values ('NEMA 5-50P');
insert into val_power_plug_style (power_plug_style) values ('NEMA 6-15P');
insert into val_power_plug_style (power_plug_style) values ('NEMA 6-20P');
insert into val_power_plug_style (power_plug_style) values ('NEMA 6-30P');
insert into val_power_plug_style (power_plug_style) values ('NEMA 6-50P');
insert into val_power_plug_style (power_plug_style) values ('NEMA L14-30P');
insert into val_power_plug_style (power_plug_style) values ('NEMA L15-30P');
insert into val_power_plug_style (power_plug_style) values ('NEMA L21-30P');
insert into val_power_plug_style (power_plug_style) values ('NEMA L5-15P');
insert into val_power_plug_style (power_plug_style) values ('NEMA L5-20P');
insert into val_power_plug_style (power_plug_style) values ('NEMA L5-30P');
insert into val_power_plug_style (power_plug_style) values ('NEMA L6-15P');
insert into val_power_plug_style (power_plug_style) values ('NEMA L6-20P');
insert into val_power_plug_style (power_plug_style) values ('NEMA L6-30P');
 */

insert into VAL_DEVICE_AUTO_MGMT_PROTOCOL
	(AUTO_MGMT_PROTOCOL, CONNECTION_PORT, DESCRIPTION)
values
	('ssh', 22, 'standard ssh');

insert into VAL_DEVICE_AUTO_MGMT_PROTOCOL
	(AUTO_MGMT_PROTOCOL, CONNECTION_PORT, DESCRIPTION)
values
	('telnet', 23, 'standard telnet');

insert into val_CABLE_TYPE (CABLE_TYPE) values ('straight');
insert into val_CABLE_TYPE (CABLE_TYPE) values ('rollover');
insert into val_CABLE_TYPE (CABLE_TYPE) values ('crossover');

insert into val_dns_domain_type (DNS_DOMAIN_TYPE) values ('service');
insert into val_dns_domain_type (DNS_DOMAIN_TYPE) values ('retired');
insert into val_dns_domain_type (DNS_DOMAIN_TYPE) values ('vanity');

insert into val_dns_class (dns_class) values ('IN');
insert into val_dns_class (dns_class) values ('HESOID');
insert into val_dns_class (dns_class) values ('CH');

insert into val_dns_type (dns_type,id_type) values ('AAAA', 'ID');
insert into val_dns_type (dns_type,id_type) values ('AFSDB', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('A', 'ID');
insert into val_dns_type (dns_type,id_type) values ('CERT', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('CNAME', 'ID');
insert into val_dns_type (dns_type,id_type) values ('DNAME', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('GID', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('GPOS', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('HINFO', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('ISDN', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('KEY', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('KX', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('LOC', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('MB', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('MF', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('MINFO', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('MR', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('MX', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('NAPTR', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('NG', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('NSAP-PTR', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('NS', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('NXT', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('OPT', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('PTR', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('PX', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('RP', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('RT', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('SIG', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('SOA', 'LINK');
insert into val_dns_type (dns_type,id_type) values ('SPF', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('SRV', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('TXT', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('UID', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('UINFO', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('UNSPEC', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('WKS', 'NON-ID');
insert into val_dns_type (dns_type,id_type) values ('X25', 'NON-ID');

insert into val_dns_type (dns_type,id_type,description)
	values ('REVERSE_ZONE_BLOCK_PTR', 'LINK',
	'not really a type; in-addr backend link');

insert into val_network_interface_purpose
	(NETWORK_INTERFACE_PURPOSE,DESCRIPTION)
	values ('api', 'Interface used to manage device via API');
insert into val_network_interface_purpose
	(NETWORK_INTERFACE_PURPOSE,DESCRIPTION)
	values ('radius', 'Interface used for radius');
insert into val_network_interface_purpose
	(NETWORK_INTERFACE_PURPOSE)
	values ('login');

insert into val_property_data_type (PROPERTY_DATA_TYPE, DESCRIPTION)
	values ('none', 'No value should be set');
insert into val_property_data_type (PROPERTY_DATA_TYPE) values 
	('boolean'),
	('number'),
	('string'),
	('list'),
	('timestamp'),
	('company_id'),
	('dns_domain_id'),
	('device_collection_id'),
	('netblock_collection_id'),
	('password_type'),
	('person_id'),
	('token_collection_id'),
	('account_collection_id'),
	('sw_package_id');

insert into val_person_company_attr_dtype (person_company_attr_data_type) values 
	('boolean'),
	('number'),
	('string'),
	('list'),
	('timestamp'),
	('person_id');

insert into val_property_type (property_type, description,is_multivalue) 
	VALUES 
	('TokenMgmt', 'Allow administrators to manage OTP tokens', 'Y'),
	('UserMgmt', 'Allow administrators to manage users', 'Y'),
	('feed-attributes','configurable attributes on user feeds', 'Y'),
	('HOTPants','define HOTPants behavior', 'Y'),
	('RADIUS','RADIUS properties', 'Y'),
	('ConsoleACL','console access control properties', 'Y'),
	('UnixPasswdFileValue','override value set in the Unix passwd file','Y'),
	('wwwgroup','WWW Group properties','Y');

insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('AllMclasses',			'ConsoleACL',	   'console access control for all mclasses',				     'N',	    'string',	      'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('PerMclass',			'ConsoleACL',	   'per mclass console access control',					   'N',	    'string',	      'PROHIBITED',  'REQUIRED',    'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('SudoGrantsConsole',		'ConsoleACL',	   'sudo grants console Account_Collection attribute',					'N',	    'string',	      'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');

-- HOTPants related properties

insert into val_property (
	property_name, property_type, property_data_type,
	description,
	permit_account_collection_id, permit_device_collection_id
) VALUES (
	'GrantAccess', 'HOTPants', 'boolean',
	'Permit user access to device',
	'ALLOWED', 'REQUIRED'
);

INSERT INTO val_property (
	property_name, property_type, property_data_type,
	description,
	permit_account_collection_id, permit_device_collection_id,
	permit_property_rank
) VALUES (
	'PWType', 'HOTPants', 'password_type',
	'Set password verification type for this Device and maybe account collection',
	'ALLOWED',     'REQUIRED',
	'ALLOWED'
);

INSERT INTO val_property (
	property_name, property_type, 
	description, 
	property_data_type, permit_device_collection_id
) VALUES (
	'RadiusSharedSecret', 'HOTPants',
	'shared secret for device used for interacting with HOTPants module',
	'string', 'REQUIRED'
);

-- properties in radius dictionaries
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('Class',			'RADIUS',	       'Radius Class from RFC2138',						   'Y',	    'string',	      'PROHIBITED',  'ALLOWED',     'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('Foundry-Privilege-Level',	'RADIUS',	       'Privilege level on a Foundry device',					 'N',	    'string',	      'PROHIBITED',  'ALLOWED',     'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('Juniper-Allow-Commands',	'RADIUS',	       'Extended regex of additional operational commands to allow to be run',	'Y',	    'string',	      'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('Juniper-Allow-Configuration',	'RADIUS',	       'Extended regex of portions of the configuration to allow the user to modify', 'Y',	    'string',	      'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('Juniper-Deny-Commands',	'RADIUS',	       'Extended regex of operational commands to deny',			      'Y',	    'string',	      'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('Juniper-Deny-Configuration',	'RADIUS',	       'Extended regex of portions of the configuration to deny the user to modify',  'Y',	    'string',	      'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('Juniper-Local-User-Name',	'RADIUS',	       'Name of Juniper user template',					       'N',	    'string',	      'PROHIBITED',  'ALLOWED',     'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('NS-Admin-Privilege',		'RADIUS',	       'Netscreen Admin Level',						       'N',	    'string',	      'PROHIBITED',  'ALLOWED',     'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('NS-User-Group',		'RADIUS',	       'Netscreen User Group Name',						   'Y',	    'string',	      'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('Service-Type',		'RADIUS',	       'RADIUS Service-Type from RFC2138',					 'N',	    'string',	      'PROHIBITED',  'ALLOWED',     'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('cisco-avpair=shell:priv-lvl',	'RADIUS',	       'Enable level of user on a Cisco device',				      'N',	    'string',	      'PROHIBITED',  'ALLOWED',     'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');

INSERT INTO val_property (property_name, property_type,
        permit_device_collection_id,  permit_account_collection_id,
        property_data_type, description
) VALUES (
        'Group', 'RADIUS',
        'REQUIRED', 'REQUIRED',
        'string', 'group used by radius client'
);

insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('GlobalAdmin',			'TokenMgmt',	    'User can manage any token',						   'N',	    'boolean',	     'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('ManageTokenCollection',	'TokenMgmt',	    'User can manage any token in the token collection',			   'N',	    'token_collection_id', 'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');

insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('ForceCrypt',			'UnixPasswdFileValue',  'Sets the users Crypt to something other than the default (OS dependent)',     'N',	    'string',	      'PROHIBITED',  'ALLOWED',     'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('ForceHome',			'UnixPasswdFileValue',  'Sets the users Home directory to something other than the default',	   'N',	    'string',	      'PROHIBITED',  'ALLOWED',     'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('ForceShell',			'UnixPasswdFileValue',  'Sets the users Shell to something other than the default',		    'N',	    'string',	      'PROHIBITED',  'ALLOWED',     'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('ForceStdShell',		'UnixPasswdFileValue',  'Prevents the users shell from being set to anything but the default',	 'N',	    'boolean',	     'PROHIBITED',  'ALLOWED',     'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('ForceUserGroup',		'UnixPasswdFileValue',  'Sets the users GID to something other than the default',		      'N',	    'string',	      'PROHIBITED',  'ALLOWED',     'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('ForceUserUID',		'UnixPasswdFileValue',  'Sets the users UID to something other than the default',		      'N',	    'string',	      'PROHIBITED',  'ALLOWED',     'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');

insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('GlobalPasswordAdmin',		'UserMgmt',	     'User can reset passwords for any user',				       'N',	    'boolean',	     'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('GlobalTokenAdmin',		'UserMgmt',	     'User can manage token assignments for any user',			      'N',	    'boolean',	     'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('MasterPasswordAdmin',		'UserMgmt',	     'Admin can reset passwords without answering challenge questions',	     'N',	    'boolean',	     'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('PasswordAdminForAccount_Collection',	'UserMgmt',	     'User can reset passwords for the Account_Collection',				     'N',	    'boolean',	     'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('TokenAdminForAccount_Collection',		'UserMgmt',	     'User can manage token assignments for any user in the Account_Collection',		'N',	    'token_collection_id', 'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');

insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('prohibit-feed',		'feed-attributes',      'prevent feeding a user for a given feed',				     'Y',	    'string',	      'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID) values
('WWWGroupName',		'wwwgroup',	     'WWW Group name overrides',						    'N',	    'string',	      'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'REQUIRED', 'PROHIBITED');


-- properties to replace old columns
insert into val_property_type (
	property_type, description, is_multivalue
) values (
	'sudoers', 'customize sudoer behavior', 'Y');

insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID) values
('sudo-default','sudoers', 'sudo default values', 'N', 'number', 'REQUIRED');

insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID) values
('generate-sudoers','sudoers', 'indicates that sudoers should be generated for this collection', 'N', 'boolean', 'REQUIRED');


insert into val_property_type (
	PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE
) values (
	'MclassUnixProp', 'unix specific device collection types', 'Y'
);

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	PERMIT_DEVICE_COLLECTION_ID
) values (
	'UnixHomeType', 'MclassUnixProp', 'N', 'list', 'REQUIRED'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	PERMIT_DEVICE_COLLECTION_ID
) values (
	'UnixPwType', 'MclassUnixProp', 'N', 'password_type', 'REQUIRED'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	PERMIT_DEVICE_COLLECTION_ID
) values (
	'HomePlace', 'MclassUnixProp', 'N', 'string', 'REQUIRED'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) values (
	'UnixLogin', 'MclassUnixProp', 'N', 'none',
	'REQUIRED', 'REQUIRED'
);

-- this puts a group on a given mclass/device collection
insert into val_property 
	(property_name, property_type, is_multivalue, 
	permit_account_collection_id, permit_device_collection_id, 
	property_data_type
) values (
	'UnixGroup', 'MclassUnixProp', 'N', 
	'REQUIRED', 'REQUIRED', 
	'none'
);

-- this puts user(s) in a group on on a given device collection and only
-- on that device collection.  It does not imply that the group gets assigned
-- to the device collection however, although the wisdom of this can be
-- debated.
insert into val_property 
	(property_name, property_type, is_multivalue, 
	permit_account_collection_id, permit_device_collection_id, 
	property_data_type
) values (
	'UnixGroupMemberOverride', 'MclassUnixProp', 'Y', 
	'REQUIRED', 'REQUIRED', 
	'account_collection_id'
);

insert into val_property_value (
	property_name, property_type, valid_property_value, description
) values 
	('UnixHomeType','MclassUnixProp','standard','per-account home directories'); 

insert into val_property_value (
	property_name, property_type, valid_property_value, description
) values 
	('UnixHomeType','MclassUnixProp','generic','per-account home directories'); 

--- Various properities that define how account management works
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	DESCRIPTION,
	PERMIT_DEVICE_COLLECTION_ID
) values (
	'ShouldDeploy', 'MclassUnixProp', 'N', 'boolean',
	'If credentials managmeent should deploy files or not',
	'REQUIRED'
);

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	DESCRIPTION,
	PERMIT_DEVICE_COLLECTION_ID
) values (
	'PermitUIDOverride', 'MclassUnixProp', 'N', 'boolean',
	'Allow Credentials Mangement to override uids locally',
	'REQUIRED'
);

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	DESCRIPTION,
	PERMIT_DEVICE_COLLECTION_ID
) values (
	'PermitGIDOverride', 'MclassUnixProp', 'N', 'boolean',
	'Allow Credentials Mangement to override uids locally',
	'REQUIRED'
);

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	DESCRIPTION,
	PERMIT_DEVICE_COLLECTION_ID, PERMIT_ACCOUNT_COLLECTION_ID
) values (
	'PreferLocal', 'MclassUnixProp', 'N', 'boolean',
	'If credentials management client should prefer local uid,gid,shell',
	'REQUIRED', 'REQUIRED'
);

-- XXX Consider if type UnixGroupAssign should be folded into MclassUnixProp
insert into val_property_type (
	PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE
) values (
	'UnixGroupFileProperty', 'properties on unix group files', 'Y'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) values (
	'ForceGroupGID', 'UnixGroupFileProperty', 'N', 'none',
	'REQUIRED', 'REQUIRED'
);

-- system wide defaults concepts used by various tools
insert into val_property_type (property_type, description)
	values ( 'Defaults', 'System Wide Defaults');

insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_COMPANY_ID, PERMIT_DEVICE_COLLECTION_ID, PERMIT_DNS_DOMAIN_ID, PERMIT_SERVICE_ENV_COLLECTION, PERMIT_SITE_CODE, PERMIT_ACCOUNT_ID, PERMIT_Account_Collection_ID, PERMIT_OPERATING_SYSTEM_ID, PERMIT_NETBLOCK_COLLECTION_ID) 
values
('_rootcompanyid', 'Defaults', 'define the root corporate identity default for commands', 'N', 'company_id',	      'PROHIBITED',  'PROHIBITED',  'PROHIBITED',    'PROHIBITED',  'PROHIBITED',   'PROHIBITED',    'PROHIBITED', 'PROHIBITED', 'PROHIBITED');

insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_ACCOUNT_REALM_ID)
values
('_root_account_realm_id', 'Defaults', 'define the corporate root identity default', 'N', 'none', 'REQUIRED');

insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE)
values
('_defaultdomain', 'Defaults', 'defines domain used for defaultas where necessary', 'N', 'string');

insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE)
values
('_supportemail', 'Defaults', 'defines support email used by tools', 'N', 
'string');

INSERT INTO val_property (
	property_name, property_type, is_multivalue, property_data_type,
	description
) VALUES (
	'_max_default_login_length', 'Defaults', 'N', 'number',
	'Maximum length of generated login names, defaults to 15'
);

insert into val_property(
	property_name, property_type, description, is_multivalue,
	property_data_type, permit_account_collection_id,
	permit_device_collection_id)
VALUES (
	'RecurseMembership',
	'feed-attributes',
	'Expand account collection membership through children for this feed',
	'N',
	'boolean',
	'REQUIRED',
	'REQUIRED'
);

INSERT INTO val_property(
	property_name, property_type, description, is_multivalue,
	property_data_type, permit_account_collection_id,
	permit_device_collection_id)
VALUES (
	'FeedEmptyGroups',
	'feed-attributes',
	'Feed account collections even if empty',
	'N',
	'boolean',
	'REQUIRED',
	'REQUIRED'
);

INSERT INTO val_property(
	property_name, property_type, description, is_multivalue,
	property_data_type, permit_account_collection_id,
	permit_device_collection_id)
VALUES (
	'LDAPParentDN',
	'feed-attributes',
	'DN of LDAP parent (where to place group in LDAP structure)',
	'N',
	'string',
	'REQUIRED',
	'REQUIRED'
);

INSERT INTO val_property(
	property_name, property_type, description, is_multivalue,
	property_data_type, permit_account_collection_id,
	permit_device_collection_id)
VALUES (
	'FeedAccountCollection',
	'feed-attributes',
	'Synchronize this account collection to this feed',
	'N',
	'boolean',
	'REQUIRED',
	'REQUIRED'
);

insert into val_company_collection_type 
	(company_collection_type,
	max_num_members, can_have_hierarchy
	) 
values 
	('per-company', 
	1, 'N'
	);

-- XXX need to auto-create a Account_Collection all_company_XX
INSERT INTO Company(Company_ID, Company_Name)
	VALUES (0, 'none');

INSERT INTO Person(Person_Id, first_name, last_name)
	VALUES (0, 'Non', 'Person');

INSERT INTO Account_Realm(Account_Realm_Id, Account_Realm_Name)
	VALUES (0, 'Non Realm');

INSERT INTO PERSON_COMPANY (company_id, person_id, person_company_status,
	person_company_relation, is_exempt)
values (0, 0, 'enabled',
	'n/a', 'N');

INSERT INTO Account_Realm_Company(Account_Realm_Id, Company_Id)
	VALUES (0, 0);

insert into person_account_realm_company (
	person_id, company_id, account_realm_id)
values
	(0, 0, 0);

INSERT INTO Account (
	Login,
	Person_Id,
	Company_Id,
	Account_Realm_Id,
	Description,
	Account_Status,
	Account_Role,
	Account_Type
) VALUES (
	'root',
	0,
	0,
	0,
	'Super User',
	'enabled',
	'primary',
	'pseudouser'
);

SELECT person_manip.setup_unix_account(
	in_account_id := (select account_id from account where login = 'root'),
	in_account_type := 'pseudouser',
	in_uid := '0'
);
	

INSERT INTO
	Device_Collection (Device_Collection_Name, Device_Collection_Type)
VALUES (
	'default',
	'mclass'
	);


insert into val_auth_resource (auth_resource) values ('radius');

insert into val_diet (diet) values ( 'Carnivore');
insert into val_diet (diet) values ( 'Omnivore');
insert into val_diet (diet) values ( 'Vegetarian');
insert into val_diet (diet) values ( 'Pescatarian');

--  XXX - need to insert these for the default companies!!
-- consider renaming to company_relation

insert into val_company_type_purpose (company_type_purpose) values ('default');

insert into val_company_type(company_type) values  ('corporate family');
insert into val_company_type(company_type) values  ('vendor');
insert into val_company_type(company_type) values  ('consultant provider');
insert into val_company_type(company_type) values  ('hardware provider');
insert into val_company_type(company_type) values  ('software provider');

insert into val_physical_address_type
	(physical_address_type, description)
values
	('location', 'physical location');

insert into val_physical_address_type
	(physical_address_type, description)
values
	('mailing', 'physical location');

insert into val_physical_address_type
	(physical_address_type, description)
values
	('legal', 'physical location');

--- XXX these may be optional
INSERT INTO Device_Type (
	Company_Id,
	Device_type_Name
) VALUES (
	0,
	'unknown'
);

INSERT INTO Operating_System (
	Operating_System_ID,
	Operating_System_Name,
	Major_Version,
	Version,
	Company_ID, processor_architecture
) VALUES (
	0,
	'unknown',
	'unknown',
	'unknown',
	0, 'noarch'
);
UPDATE Operating_System SET Operating_System_ID = 0 where Company_ID = 0;

insert into val_person_image_usage (
	person_image_usage, is_multivalue
) values (
	'corpdirectory', 'N'
);

insert into val_ip_group_protocol
	(ip_group_protocol) values ('vrrp');
insert into val_ip_group_protocol
	(ip_group_protocol) values ('hsrp');
insert into val_ip_group_protocol
	(ip_group_protocol) values ('bgp');

insert into val_encapsulation_type
	(encapsulation_type) values ('802.1q');
insert into val_encapsulation_type
	(encapsulation_type) values ('MPLS');

insert into val_encapsulation_mode
	(encapsulation_mode, encapsulation_type) values ('trunk', '802.1q');
insert into val_encapsulation_mode
	(encapsulation_mode, encapsulation_type) values ('access', '802.1q');
insert into val_encapsulation_mode
	(encapsulation_mode, encapsulation_type) values ('native', '802.1q');

-- add port speed, port mediumm port protocaol (look at dropped things from
--	interface type above)

insert into val_device_collection_type 
	(device_collection_type,
	max_num_members, can_have_hierarchy
	) 
values 
	('per-device', 
	1, 'N'
	);

--- stab stuff
insert into val_property_type (property_type, description, is_multivalue)
values
	('StabRole', 'roles for users in stab', 'Y');

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	permit_account_collection_id
) values 
	('StabAccess', 'StabRole', 'N', 'boolean', 'REQUIRED'),
	('PermitStabSection', 'StabRole', 'Y', 'list', 'REQUIRED')
;

insert into val_property_value (
	property_name, property_type, valid_property_value
) values
	('PermitStabSection', 'StabRole', 'Device'),
	('PermitStabSection', 'StabRole', 'DNS'),
	('PermitStabSection', 'StabRole', 'Netblock'),
	('PermitStabSection', 'StabRole', 'Sites'),
	('PermitStabSection', 'StabRole', 'StabAccess'),
	('PermitStabSection', 'StabRole', 'Attest'),
	('PermitStabSection', 'StabRole', 'Approval'),
	('PermitStabSection', 'StabRole', 'X509'),
	('PermitStabSection', 'StabRole', 'FullAdmin')
;

insert into val_property (
	property_name, property_type, is_multivalue, property_data_type,
	description
) values (
	'_stab_root', 'Defaults', 'N', 'string',
	'root of url for stab, if apps need to direct people'
);


-- DNS zone generation
insert into val_property_type (property_type, description, is_multivalue) 
values ('DNSZonegen', 'properties for defining dns zone generation', 'Y');

insert into val_property 
	(property_name, property_type, 
	 description, is_multivalue, 
	 property_data_type, permit_device_collection_id, permit_site_code) 
values (
	'DNSDistHosts', 'DNSZonegen', 
	'indicates hosts that should get dns zones', 'Y', 
	'none', 'REQUIRED', 'ALLOWED');

insert into val_property
	(property_name, property_type,
	 description, is_multivalue,
	 property_data_type,permit_netblock_collection_id)
values (
	'DNSACLs', 'DNSZonegen',
	'indicates netblocks that should be in a named acl', 'Y',
	'string', 'REQUIRED');

--- approval stuff

insert into val_property (
	property_name, property_type, is_multivalue, property_data_type,
	description
) values (
	'_approval_email_sender', 'Defaults', 'N', 'string',
	'Email address to send approvals from '
);

insert into val_property (
	property_name, property_type, is_multivalue, property_data_type,
	description
) values (
	'_approval_email_signer', 'Defaults', 'N', 'string',
	'Email address to sign aproval emails from (in body)'
);

insert into val_property (
	property_name, property_type, is_multivalue, property_data_type,
	description, permit_account_collection_id
) values (
	'_can_approve_all', 'Defaults', 'Y', 'string',
	'Stored Procedures will allow these people to execute any approval.  Assign sparingly, if at all.',
	'REQUIRED'
);

insert into val_property (
	property_name, property_type, is_multivalue, property_data_type,
	description
) values (
	'_approval_faq_site', 'Defaults', 'N', 'string',
	'URL to include in emails that tell people where to find more info'
);

-------------------------------------------------------------------------
-- BEGIN legacy port related stuff used by layer1_connection and elsewhere

insert into val_component_property_type (component_property_type, description)
values ('serial-connection', 'characteristics of serial connections');

insert into val_component_property (
	component_property_name, component_property_type, is_multivalue,
	property_data_type, permit_intcomp_conn_id
) values (
	'baud', 'serial-connection', 'N',
	'list', 'REQUIRED');
insert into val_component_property_value (
	component_property_name, component_property_type, valid_property_value
) SELECT 'baud', 'serial-connection',
	unnest(ARRAY[110,300,1200,2400,4800,9600,19200,38400,57600,115200]);

insert into val_component_property (
	component_property_name, component_property_type, is_multivalue,
	property_data_type, permit_intcomp_conn_id
) values (
	'flow-control', 'serial-connection', 'N',
	'list', 'REQUIRED');
insert into val_component_property_value (
	component_property_name, component_property_type, 
	valid_property_value,
	description
) SELECT 'flow-control', 'serial-connection',
	unnest(ARRAY['ctsrts',	'dsrdte',	'dtrdce',	'xonxoff']),
	unnest(ARRAY['CTS/RTS', 'DSR/DTE',	'DTE/DCE',	'Xon/Xoff'])
;

insert into val_component_property (
	component_property_name, component_property_type, is_multivalue,
	property_data_type, permit_intcomp_conn_id
) values (
	'stop-bits', 'serial-connection', 'N',
	'list', 'REQUIRED');
insert into val_component_property_value (
	component_property_name, component_property_type, valid_property_value
) SELECT 'stop-bits', 'serial-connection',
	unnest(ARRAY['1','2','1.5'])
;

insert into val_component_property (
	component_property_name, component_property_type, is_multivalue,
	property_data_type, permit_intcomp_conn_id
) values (
	'data-bits', 'serial-connection', 'N',
	'list', 'REQUIRED');
insert into val_component_property_value (
	component_property_name, component_property_type, valid_property_value
) SELECT 'data-bits', 'serial-connection',
	unnest(ARRAY[7,8])
;

insert into val_component_property (
	component_property_name, component_property_type, is_multivalue,
	property_data_type, permit_intcomp_conn_id
) values (
	'parity', 'serial-connection', 'N',
	'list', 'REQUIRED');
insert into val_component_property_value (
	component_property_name, component_property_type, valid_property_value
) SELECT 'parity', 'serial-connection',
	unnest(ARRAY['none', 'even', 'odd', 'mark', 'space'])
;


insert into val_component_property_type (component_property_type, description)
values ('tcpsrv-connections', 'rtty tcpsrv connection properties');

-- probably want to limit to component types that are devices but that appears
-- to be hard
insert into val_component_property (
	component_property_name, component_property_type, is_multivalue,
	property_data_type, permit_intcomp_conn_id, permit_component_id
) values (
	'tcpsrv_device_id', 'tcpsrv-connections', 'N',
	'none', 'REQUIRED', 'REQUIRED')
;

insert into val_component_property (
	component_property_name, component_property_type, is_multivalue,
	property_data_type, permit_intcomp_conn_id
) values (
	'tcpsrv_enabled', 'tcpsrv-connections', 'N',
	'boolean', 'REQUIRED')
;


/*****************************************************************************

=== Things used to be directly support that are not directly supported. ====

These concepts really are connection properties, not port --

insert into val_port_protocol (port_protocol) values ( 'Ethernet' );
insert into val_port_protocol (port_protocol) values ( 'DS1' );
insert into val_port_protocol (port_protocol) values ( 'DS3' );
insert into val_port_protocol (port_protocol) values ( 'E1' );
insert into val_port_protocol (port_protocol) values ( 'E3' );
insert into val_port_protocol (port_protocol) values ( 'OC3' );
insert into val_port_protocol (port_protocol) values ( 'OC12' );
insert into val_port_protocol (port_protocol) values ( 'OC48' );
insert into val_port_protocol (port_protocol) values ( 'OC192' );
insert into val_port_protocol (port_protocol) values ( 'OC768' );
insert into val_port_protocol (port_protocol) values ( 'serial' );

insert into val_port_plug_style (port_plug_style) values ('GBIC');
insert into val_port_plug_style (port_plug_style) values ('XENPAK');

-- need to do sr, lr, cat6, cat5, twinax, etc
insert into val_port_medium (port_medium,port_plug_style) values
	('serial', 'db9');
insert into val_port_medium (port_medium,port_plug_style) values
	('serial', 'rj45');
insert into val_port_medium (port_medium,port_plug_style) values
	('TwinAx', 'SFP+');

These concepts are likely component_functions or inferred from slot_type

insert into val_port_speed (port_speed, port_speed_bps) values
	('10Mb', 10000);
insert into val_port_speed (port_speed, port_speed_bps) values
	('100Mb', 1000000);
insert into val_port_speed (port_speed, port_speed_bps) values
	('1G', 1000000000);
insert into val_port_speed (port_speed, port_speed_bps) values
	('10G', 10000000000);
insert into val_port_speed (port_speed, port_speed_bps) values
	('40G', 40000000000);
insert into val_port_speed (port_speed, port_speed_bps) values
	('100G', 100000000000);

These concepts are likely component_functions

insert into val_port_protocol_speed (port_protocol, port_speed)
	values ('Ethernet', '10Mb');
insert into val_port_protocol_speed (port_protocol, port_speed)
	values ('Ethernet', '100Mb');
insert into val_port_protocol_speed (port_protocol, port_speed)
	values ('Ethernet', '1G');
insert into val_port_protocol_speed (port_protocol, port_speed)
	values ('Ethernet', '10G');
insert into val_port_protocol_speed (port_protocol, port_speed)
	values ('Ethernet', '40G');
insert into val_port_protocol_speed (port_protocol, port_speed)
	values ('Ethernet', '100G');

*****************************************************************************/

-- END legacy port related stuff used by layer1_connection and elsewhere
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- BEGIN automated account collection infrastructure (tied to properties)

insert into val_property_type (
	property_type, is_multivalue,
	description
) values (
	'auto_acct_coll', 'Y',
	'properties that define how people are added to account collections automatically based on column changes'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'exempt', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'non_exempt', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'male', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'female', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'unspecified_gender', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'management', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'non_management', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'full_time', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'non_full_time', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'account_type', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'list',
	'N'
);

insert into val_property_value (
	property_name, property_type, valid_property_value
) values (
	'account_type', 'auto_acct_coll', 'person'
);

insert into val_property_value (
	property_name, property_type, valid_property_value
) values (
	'account_type', 'auto_acct_coll', 'pseudouser'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'site', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'REQUIRED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_id,
	permit_account_realm_id,
	property_data_type,
	is_multivalue
) values (
	'AutomatedDirectsAC', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'account_collection_id',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_id,
	permit_account_realm_id,
	property_data_type,
	is_multivalue
) values (
	'AutomatedRollupsAC', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'account_collection_id',
	'N'
);

-- END automated account collection infrastructure (tied to properties)
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- BEGIN certificate

insert into val_x509_certificate_file_fmt
	(x509_file_format, description)
values	 
	('pem', 'human readable rsa certificate'),
	('der', 'binary representation'),
	('keytool', 'Java keystore .jks'),
	('pkcs12', 'PKCS12 .p12 file')
;

insert into val_x509_key_usage
	(x509_key_usg, description, is_extended)
values
	('digitalSignature',	'verifying digital signatures other than other certs/CRLs,  such as those used in an entity authentication service, a data origin authentication service, and/or an integrity service', 'N'),
	('nonRepudiation',	'verifying digital signatures other than other certs/CRLs, to provide a non-repudiation service that protects against the signing entity falsely denying some action.  Also known as contentCommitment', 'N'),
	('keyEncipherment',	'key is used for enciphering private or secret keys', 'N'),
	('dataEncipherment',	'key is used for directly enciphering raw user data without the use of an intermediate symmetric cipher', 'N'),
	('keyAgreement',	NULL, 'N'),
	('keyCertSign',		'key signs other certificates; must be set with ca bit', 'N'),
	('cRLSign',		'key is for verifying signatures on certificate revocation lists', 'N'),
	('encipherOnly',	'with keyAgreement bit, key used for enciphering data while performing key agreement', 'N'),
	('decipherOnly',	'with keyAgreement bit, key used for deciphering data while performing key agreement', 'N'),
	('serverAuth',		'SSL/TLS Web Server Authentication', 'Y'),
	('clientAuth',		'SSL/TLS Web Client Authentication', 'Y'),
	('codeSigning',		'Code signing', 'Y'),
	('emailProtection',	'E-mail Protection (S/MIME)', 'Y'),
	('timeStamping',	'Trusted Timestamping', 'Y'),
	('OCSPSigning',		'Signing OCSP Responses', 'Y')
;

insert into val_x509_key_usage_category
	(x509_key_usg_cat, description)
values
	('ca', 'used to identify a certificate authority'),
	('revocation', 'Used to identify entity that signs crl/ocsp responses'),
	('service', 'used to identify a service on the netowrk'),
	('server', 'used to identify a server as a client'),
	('application', 'cross-authenticate applications'),
	('account', 'used to identify an account/user/person')
;

insert into x509_key_usage_categorization
	(x509_key_usg_cat, x509_key_usg)
values
	('ca',  'keyCertSign'),
	('revocation',  'cRLSign'),
	('revocation',  'OCSPSigning'),
	('service',  'digitalSignature'),
	('service',  'keyEncipherment'),
	('service',  'serverAuth'),
	('application',  'digitalSignature'),
	('application',  'keyEncipherment'),
	('application',  'serverAuth')
;

INSERT INTO val_x509_revocation_reason
	(x509_revocation_reason)
values 
	('unspecified'),
	('keyCompromise'),
	('CACompromise'),
	('affiliationChanged'),
	('superseded'),
	('cessationOfOperation'),
	('certificateHold'),
	('removeFromCRL'),
	('privilegeWithdrawn'),
	('AACompromise')
;
	
-- END certificate
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- logical volumes

INSERT INTO val_logical_volume_type (
	logical_volume_type, description
) VALUES (
	'legacy', 'data that predates existance of this table'
);

-- END logical volumes
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- tokens

INSERT INTO val_token_status (token_status, description)
VALUES
        ('disabled', NULL),
        ('enabled', NULL),
        ('lost', NULL),
        ('destored', NULL),
        ('stolen', NULL),
        ('pending', 'pending confirmation')
;

INSERT INTO val_token_type 
	(token_type, description, token_digit_count)
VALUES
        ('soft_seq', 'sequence based soft token', 6),
        ('soft_time', 'time-based soft token', 6);

INSERT INTO val_encryption_key_purpose (
        encryption_key_purpose, encryption_key_purpose_version, description
) VALUES (
        'tokenkey', 1, 'Passwords for Token Keys'
);


-- END tokens
-------------------------------------------------------------------------
