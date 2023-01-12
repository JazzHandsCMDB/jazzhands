--
-- Copyright (c) 2010-2023, Todd M. Kover
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
--
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
-- Items that are essential.

--
-- triggers want this for by-coll-type but they should be smarter about not setting
-- a row for this because max_num_members is zero for by-coll-type.  Still that
-- requires by-directional checking, so not introducing that complexity.
--
-- for now, there is no account_collection by-coll-type; need to sort out how
-- the account_realm_id restrictions fit into those.
--
insert into val_account_collection_relation
	(account_collection_relation, description)
values
	('direct', 'Direct Assignment');

-----------------------------------------------------------------------------
--
-- These need to be early.  (collection triggers depend on them)
--
-- INSERT INTO val_account_collection_type (
-- 	account_collection_type, description, max_num_members
-- ) VALUES (
-- 	'by-coll-type', 'automated collection for accounts of this type', 0
-- );
INSERT INTO val_netblock_collection_type (
	netblock_collection_type, description, max_num_members
) VALUES (
	'by-coll-type', 'automated collection for netblocks of this type', 0
);
INSERT INTO val_company_collection_type (
	company_collection_type, description, max_num_members
) VALUES (
	'by-coll-type', 'automated collection for companies of this type', 0
);
INSERT INTO val_device_collection_type (
	device_collection_type, description,
	max_num_collections, can_have_hierarchy
) VALUES (
	'by-coll-type', 'automated collection for devices of this type',
	1, true
);
INSERT INTO val_dns_domain_collection_type (
	dns_domain_collection_type, description,
	max_num_collections, max_num_members
) VALUES (
	'by-coll-type', 'automated collection for dns_domains of this type',
	1, 0
);
INSERT INTO val_layer2_network_collection_type (
	layer2_network_collection_type, description,
	max_num_collections, max_num_members
) VALUES (
	'by-coll-type', 'automated collection for layer2_networks of this type',
	1, 0
);
INSERT INTO val_layer3_network_collection_type (
	layer3_network_collection_type, description,
	max_num_collections, max_num_members
) VALUES (
	'by-coll-type', 'automated collection for layer3_networks of this type',
	1, 0
);
INSERT INTO val_service_environment_collection_type (
	service_environment_collection_type, description,
	max_num_collections, max_num_members
) VALUES (
	'by-coll-type', 'automated collection for service_environments of this type',
	1, 0
);

-----------------------------------------------------------------------------

INSERT INTO VAL_Account_Type(Account_Type, Is_Person, Uid_Gid_Forced,
		Description)
	VALUES ('person', true, true, 'person_id is meaningful');
INSERT INTO VAL_Account_Type(Account_Type, Is_Person, Uid_Gid_Forced,
		Description)
	VALUES ('pseudouser', false, false, 'person_id is not useful');
INSERT INTO VAL_Account_Type(Account_Type, Is_Person, Uid_Gid_Forced,
	Description)
	VALUES ('blacklist', false, false, 'login name blacklist');

INSERT INTO VAL_Person_Status(Person_Status, Description,
		is_enabled, propagate_from_person)
	VALUES ('enabled', 'Enabled',
		true, true);
INSERT INTO VAL_Person_Status(Person_Status, Description,
		is_enabled, propagate_from_person)
	VALUES ('disabled', 'Disabled',
		false, false);
INSERT INTO VAL_Person_Status(Person_Status, Description,
		is_enabled, propagate_from_person)
	VALUES ('forcedisabled', 'User Forced to Disabled status',
		false, false);
INSERT INTO VAL_Person_Status(Person_Status, Description,
		is_enabled, propagate_from_person)
	VALUES ('terminated', 'User has been terminated',
		false, false);
INSERT INTO VAL_Person_Status(Person_Status, Description,
		is_enabled, propagate_from_person)
	VALUES ('autoterminated', 'User has been terminated by auto process',
		false, true);
INSERT INTO VAL_Person_Status(Person_Status, Description,
		is_enabled, propagate_from_person)
	VALUES ('onleave', 'User is disabled due to being on leave',
		false, true);

--
-- This needs attention; it ties to automated account collections so that all
-- also needs to be overhauled before this val table is meaningful.
--
INSERT INTO val_gender (
	gender, description
) VALUES
	('male', 'Identifies as male'),
	('female', 'Identifies as female'),
	('unspecified', 'Unspecified')
;

INSERT INTO Val_Person_Company_Relation(Person_Company_Relation, Description)
	VALUES ('employee', 'Employee');
INSERT INTO Val_Person_Company_Relation(Person_Company_Relation, Description)
	VALUES ('consultant', 'Consultant');
INSERT INTO Val_Person_Company_Relation(Person_Company_Relation, Description)
	VALUES ('vendor', 'Vendor');
INSERT INTO Val_Person_Company_Relation(Person_Company_Relation, Description)
	VALUES ('n/a', 'Not a person');

INSERT INTO VAL_ACCOUNT_ROLE (Account_Role, Uid_Gid_Forced, Description)
	VALUES ('primary', false,
		'Primary account for user in this Account Realm');
INSERT INTO VAL_ACCOUNT_ROLE (Account_Role, Uid_Gid_Forced, Description)
	VALUES ('administrator', false,
	'Administrative account for user in this Account Realm');
INSERT INTO VAL_ACCOUNT_ROLE (Account_Role, Uid_Gid_Forced, Description)
	VALUES ('test', false, 'Test Account for User');

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
	1, false
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

insert into val_service_environment_collection_type
	( service_environment_collection_type ) values ('per-environment');

INSERT INTO val_service_environment_type (
	service_environment_type, description
) VALUES (
	'default', 'universalish concepts'
);

INSERT INTO service_environment (
	service_environment_name, service_environment_type, production_state
) VALUES
	('unspecified', 'default', 'unspecified'),
	('unallocated', 'default', 'unallocated'),
	('production', 'default', 'production'),
	('development', 'default', 'development'),
	('qa', 'default', 'test'),
	('staging', 'default', 'test'),
	('test', 'default', 'test');

INSERT INTO VAL_Ownership_Status (Ownership_Status)
VALUES
	('owned'),
	('leased'),
	('onloan'),
	('unknown');

insert into Val_Person_Contact_Type(person_contact_type)
VALUES
	('chat'),
	('email'),
	('phone');

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

INSERT INTO val_person_contact_location_type (Person_Contact_Location_Type)
	VALUES ('home');
INSERT INTO val_person_contact_location_type (Person_Contact_Location_Type)
	VALUES ('personal');
INSERT INTO val_person_contact_location_type (Person_Contact_Location_Type)
	VALUES ('office');

--INSERT INTO VAL_User_Location_Type (System_User_Location_Type)
--	VALUES ('office');
--INSERT INTO VAL_User_Location_Type (System_User_Location_Type)
--	VALUES ('home');

-- Database AppAuthAL methods

INSERT INTO val_appaal_group_name (appaal_group_name, description) VALUES
	('database', 'keys related to database connections');

insert into VAL_application_KEY (application_KEY, appaal_group_name, DESCRIPTION) values
	('DBType', 'database', 'Database Type');
insert into VAL_application_KEY (application_KEY, appaal_group_name, DESCRIPTION) values
	('Method', 'database', 'Method for Authentication');
insert into VAL_application_KEY (application_KEY, appaal_group_name, DESCRIPTION) values
	('Password', 'database', 'Password or equivalent');
insert into VAL_application_KEY (application_KEY, appaal_group_name, DESCRIPTION) values
	('ServiceName',  'database',
	'Service Name used for certain methods (DB methods, notably)');
insert into VAL_application_KEY (application_KEY, appaal_group_name, DESCRIPTION) values
	('Username', 'database', 'Username or equivalent');

INSERT INTO VAL_application_KEY_VALUES (application_KEY, appaal_group_name, application_VALUE)
	VALUES ('Method', 'database', 'password');

INSERT INTO VAL_application_KEY_VALUES (application_KEY, appaal_group_name, application_VALUE)
	VALUES ('DBType', 'database', 'mysql');
INSERT INTO VAL_application_KEY_VALUES (application_KEY, appaal_group_name, application_VALUE)
	VALUES ('DBType', 'database', 'oracle');
INSERT INTO VAL_application_KEY_VALUES (application_KEY, appaal_group_name, application_VALUE)
	VALUES ('DBType', 'database', 'postgres');
INSERT INTO VAL_application_KEY_VALUES (application_KEY, appaal_group_name, application_VALUE)
	VALUES ('DBType', 'database', 'sqlrelay');
INSERT INTO VAL_application_KEY_VALUES (application_KEY, appaal_group_name, application_VALUE)
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

insert into VAL_application_KEY (application_KEY, appaal_group_name, DESCRIPTION) values
	('ServerName', 'ldap', 'Server to Connect to');

insert into VAL_application_KEY (application_KEY, appaal_group_name, DESCRIPTION) values
	('Username', 'ldap', 'Username to connect as');
insert into VAL_application_KEY (application_KEY, appaal_group_name, DESCRIPTION) values
	('Password', 'ldap', 'Password to connect with');
insert into VAL_application_KEY (application_KEY, appaal_group_name, DESCRIPTION) values
	('Domain', 'ldap', 'Domain to connect as');

-- LDAP AppAuthAL

INSERT INTO val_appaal_group_name (appaal_group_name, description) VALUES
	('web', 'keys related to http(s) connections');

insert into VAL_application_KEY (application_KEY, appaal_group_name, DESCRIPTION) values
	('URL', 'web', 'URL to connect to');
insert into VAL_application_KEY (application_KEY, appaal_group_name, DESCRIPTION) values
	('Username', 'web', 'Username to connect as');
insert into VAL_application_KEY (application_KEY, appaal_group_name, DESCRIPTION) values
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

INSERT INTO val_layer3_interface_Type (layer3_interface_Type)
	VALUES ('point-to-point');
INSERT INTO val_layer3_interface_Type (layer3_interface_Type)
	VALUES ('broadcast');
INSERT INTO val_layer3_interface_Type (layer3_interface_Type)
	VALUES ('loopback');
INSERT INTO val_layer3_interface_Type (layer3_interface_Type)
	VALUES ('virtual');

insert into val_netblock_status (NETBLOCK_STATUS) values ('Allocated');
insert into val_netblock_status (NETBLOCK_STATUS) values ('Deallocated');
insert into val_netblock_status (NETBLOCK_STATUS) values ('Legacy');
insert into val_netblock_status (NETBLOCK_STATUS) values ('ExternalOwned');
insert into val_netblock_status (NETBLOCK_STATUS) values ('Reserved');

INSERT INTO val_ip_namespace (
	ip_namespace, description
) VALUES
	( 'default', 'default namespace'    );

INSERT INTO ip_universe (
	ip_universe_id, ip_universe_name, ip_namespace, should_generate_dns,
	description
) VALUES
	( 0, 'default', 'default', true,
	'default IP universe'    );

-- some sites may not want this to be unique, but this is the default.
INSERT INTO ip_universe (
	ip_universe_name, ip_namespace, should_generate_dns, description
) VALUES
	('private', 'default', false, 'RFC 1918 Space'    );

INSERT INTO val_netblock_type(
	netblock_type, description, db_forced_hierarchy, is_validated_hierarchy
) VALUES (
	'default', 'standard hierarchical netblock type', true, true
);

INSERT INTO val_netblock_type(
	netblock_type, description, db_forced_hierarchy, is_validated_hierarchy
) VALUES (
	'adhoc', 'standard non-hierarchical netblock type', false, true
);

INSERT INTO val_netblock_type(
	netblock_type, description, db_forced_hierarchy, is_validated_hierarchy
) VALUES (
	'dns', 'organizational groupings used for assigning DNS', false, false
);

INSERT INTO val_netblock_type(
	netblock_type, description, db_forced_hierarchy, is_validated_hierarchy
) VALUES (
	'network_range', 'stop/start network range', false, false
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

insert into val_CABLE_TYPE (CABLE_TYPE) values ('straight');
insert into val_CABLE_TYPE (CABLE_TYPE) values ('rollover');
insert into val_CABLE_TYPE (CABLE_TYPE) values ('crossover');

insert into val_layer3_interface_purpose
	(layer3_interface_PURPOSE,DESCRIPTION)
	values ('api', 'Interface used to manage device via API');
insert into val_layer3_interface_purpose
	(layer3_interface_PURPOSE,DESCRIPTION)
	values ('radius', 'Interface used for radius');
insert into val_layer3_interface_purpose
	(layer3_interface_PURPOSE)
	values ('login');

insert into val_property_data_type (PROPERTY_DATA_TYPE, DESCRIPTION)
	values ('none', 'No value should be set');
insert into val_property_data_type (PROPERTY_DATA_TYPE) values
	('list'),
	('number'),
	('string'),
	('account_collection_id'),
	('boolean'),
	('device_collection_id'),
	('encryption_key_id'),
	('json'),
	('netblock_collection_id'),
	('password_type'),
	('private_key_id'),
	('service_endpoint_id'),
	('software_version_collection_id'),
	('timestamp'),
	('token_collection_id');

insert into val_person_company_attribute_data_type (person_company_attribute_data_type) values
	('boolean'),
	('number'),
	('string'),
	('list'),
	('timestamp'),
	('person_id');

-- system wide defaults concepts used by various tools
insert into val_property_type (property_type, description)
	values ( 'Defaults', 'System Wide Defaults');

----------------------- DNS

INSERT INTO val_property
	(property_type, property_name, property_data_type, is_multivalue,
	 description)
VALUES
	('Defaults', '_dnsrname', 'string', false,
		'Default Role Name (contact) for zone'),
	('Defaults', '_dnsmname', 'string', false,
		'Default contact for zone'),
	('Defaults', '_authdns', 'string', true,
		'Default Nameserver for zone');

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

INSERT INTO val_dns_type (
        dns_type, description, id_type
) VALUES (
        'DEFAULT_DNS_DOMAIN', 'used by integrations to determine associated dns domain', 'LINK'
);

----------------------- Misc Property Types

insert into val_property_type (property_type, description,is_multivalue)
	VALUES
	('TokenMgmt', 'Allow administrators to manage OTP tokens', true),
	('UserMgmt', 'Allow administrators to manage users', true),
	('feed-attributes','configurable attributes on user feeds', true),
	('HOTPants','define HOTPants behavior', true),
	('RADIUS','RADIUS properties', true),
	('ConsoleACL','console access control properties', true),
	('DeviceProvisioning','properties related to automatic device provisioning', true),
	('DeviceInventory','properties for device inventory functions', true),
	('UnixPasswdFileValue','override value set in the Unix passwd file',true),
	('SystemInstallation','Properties associated with the system loading process',true),
	('wwwgroup','WWW Group properties',true);

insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID) VALUES
('AllMclasses', 'ConsoleACL', 'console access control for all mclasses', false, 'string', 'REQUIRED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID) VALUES
('PerMclass', 'ConsoleACL', 'per mclass console access control', false, 'string', 'REQUIRED', 'REQUIRED');
insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID) VALUES
('SudoGrantsConsole', 'ConsoleACL', 'sudo grants console Account_Collection attribute', false, 'string', 'REQUIRED');

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

insert into val_property (
	property_name, property_type, property_data_type,
	description,
	permit_account_collection_id, permit_device_collection_id
) VALUES (
	'AuthorizePasswordlessAccess', 'HOTPants', 'boolean',
	'Authorize via radius without a password',
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
INSERT INTO val_property  (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) VALUES (
	'Class', 'RADIUS', 'Radius Class from RFC2138', true, 'string', 'ALLOWED', 'REQUIRED'
);
INSERT INTO val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) VALUES (
	'Foundry-Privilege-Level', 'RADIUS', 'Privilege level on a Foundry device', false, 'string', 'ALLOWED', 'REQUIRED');
INSERT INTO val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID
) VALUES (
	'Juniper-Allow-Commands', 'RADIUS', 'Extended regex of additional operational commands to allow to be run', true, 'string', 'REQUIRED'
);
INSERT INTO val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID
) VALUES (
	 'Juniper-Allow-Configuration', 'RADIUS', 'Extended regex of portions of the configuration to allow the user to modify', true, 'string', 'REQUIRED'
);
INSERT INTO val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID
) VALUES (
	'Juniper-Deny-Commands', 'RADIUS', 'Extended regex of operational commands to deny', true, 'string', 'REQUIRED'
);
INSERT INTO val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID
) VALUES (
	'Juniper-Deny-Configuration', 'RADIUS', 'Extended regex of portions of the configuration to deny the user to modify', true, 'string', 'REQUIRED'
);
INSERT INTO val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) VALUES (
	'Juniper-Local-User-Name', 'RADIUS', 'Name of Juniper user template', false, 'string', 'ALLOWED', 'REQUIRED'
);
INSERT INTO val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) VALUES (
	'NS-Admin-Privilege', 'RADIUS', 'Netscreen Admin Level', false, 'string', 'ALLOWED', 'REQUIRED'
);
INSERT INTO val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID
) VALUES (
	'NS-User-Group', 'RADIUS', 'Netscreen User Group Name', true, 'string', 'REQUIRED'
);
INSERT INTO val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) VALUES (
	'Service-Type', 'RADIUS', 'RADIUS Service-Type from RFC2138', false, 'string', 'ALLOWED', 'REQUIRED'
);
INSERT INTO val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) VALUES (
	'cisco-avpair=shell:priv-lvl', 'RADIUS', 'Enable level of user on a Cisco device', false, 'string', 'ALLOWED', 'REQUIRED'
);

INSERT INTO val_property (
	property_name, property_type,
        permit_device_collection_id,  permit_account_collection_id,
        property_data_type, description
) VALUES (
        'Group', 'RADIUS',
        'REQUIRED', 'REQUIRED',
        'string', 'group used by radius client'
);

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID
) VALUES (
	'GlobalAdmin', 'TokenMgmt', 'User can manage any token', false, 'boolean', 'REQUIRED'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID
) VALUES (
	'ManageTokenCollection', 'TokenMgmt', 'User can manage any token in the token collection', false, 'token_collection_id', 'REQUIRED'
);

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) VALUES (
	'ForceCrypt', 'UnixPasswdFileValue', 'Sets the users Crypt to something other than the default (OS dependent)', false, 'string', 'ALLOWED', 'REQUIRED'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) VALUES (
	'ForceHome', 'UnixPasswdFileValue', 'Sets the users Home directory to something other than the default', false, 'string', 'ALLOWED', 'REQUIRED'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) VALUES (
	'ForceShell', 'UnixPasswdFileValue', 'Sets the users Shell to something other than the default', false, 'string', 'ALLOWED', 'REQUIRED'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) VALUES (
	'ForceStdShell', 'UnixPasswdFileValue', 'Prevents the users shell from being set to anything but the default', false, 'boolean', 'ALLOWED', 'REQUIRED'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) VALUES (
	'ForceUserGroup', 'UnixPasswdFileValue', 'Sets the users GID to something other than the default', false, 'string', 'ALLOWED', 'REQUIRED'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) VALUES (
	'ForceUserUID', 'UnixPasswdFileValue', 'Sets the users UID to something other than the default', false, 'string', 'ALLOWED', 'REQUIRED'
);

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID
) VALUES (
	'GlobalPasswordAdmin', 'UserMgmt', 'User can reset passwords for any user', false, 'boolean', 'REQUIRED'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID
) VALUES (
	'GlobalTokenAdmin', 'UserMgmt', 'User can manage token assignments for any user', false, 'boolean', 'REQUIRED'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID
) VALUES (
	'MasterPasswordAdmin', 'UserMgmt', 'Admin can reset passwords without answering challenge questions', false, 'boolean', 'REQUIRED'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID
) VALUES (
	'PasswordAdminForAccount_Collection', 'UserMgmt', 'User can reset passwords for the Account_Collection', false, 'boolean', 'REQUIRED'
);

insert into val_property
	(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID
) VALUES (
	'TokenAdminForAccount_Collection', 'UserMgmt', 'User can manage token assignments for any user in the Account_Collection', false, 'token_collection_id', 'REQUIRED'
);

INSERT into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID
) VALUES
	('Needs2FAEnroll', 'UserMgmt', 'User needs Token Setup', 'none', 'REQUIRED'),
	('NeedsPasswdChange', 'UserMgmt', 'User needs Password Change', 'none', 'REQUIRED');

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_Account_Collection_ID
) VALUES
	('prohibit-feed', 'feed-attributes', 'prevent feeding a user for a given feed', true, 'string', 'REQUIRED'),
	('WWWGroupName', 'wwwgroup', 'WWW Group name overrides', false, 'string', 'REQUIRED')
;

-- properties to replace old columns
insert into val_property_type (
	property_type, description, is_multivalue
) values (
	'sudoers', 'customize sudoer behavior', true);

insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID) values
('sudo-default','sudoers', 'sudo default values', false, 'number', 'REQUIRED');

insert into val_property
(PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE, PROPERTY_DATA_TYPE, PERMIT_DEVICE_COLLECTION_ID) values
('generate-sudoers','sudoers', 'indicates that sudoers should be generated for this collection', false, 'boolean', 'REQUIRED');


insert into val_property_type (
	PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE
) values (
	'MclassUnixProp', 'unix specific device collection types', true
);

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	PERMIT_DEVICE_COLLECTION_ID
) values (
	'UnixHomeType', 'MclassUnixProp', false, 'list', 'REQUIRED'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	PERMIT_DEVICE_COLLECTION_ID
) values (
	'UnixPwType', 'MclassUnixProp', false, 'password_type', 'REQUIRED'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	PERMIT_DEVICE_COLLECTION_ID
) values (
	'HomePlace', 'MclassUnixProp', false, 'string', 'REQUIRED'
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) values (
	'UnixLogin', 'MclassUnixProp', false, 'none',
	'REQUIRED', 'REQUIRED'
);

-- this puts a group on a given mclass/device collection
insert into val_property
	(property_name, property_type, is_multivalue,
	permit_account_collection_id, permit_device_collection_id,
	property_data_type
) values (
	'UnixGroup', 'MclassUnixProp', false,
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
	'UnixGroupMemberOverride', 'MclassUnixProp', true,
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
	'ShouldDeploy', 'MclassUnixProp', false, 'boolean',
	'If credentials managmeent should deploy files or not',
	'REQUIRED'
);

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	DESCRIPTION,
	PERMIT_DEVICE_COLLECTION_ID
) values (
	'PermitUIDOverride', 'MclassUnixProp', false, 'boolean',
	'Allow Credentials Mangement to override uids locally',
	'REQUIRED'
);

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	DESCRIPTION,
	PERMIT_DEVICE_COLLECTION_ID
) values (
	'PermitGIDOverride', 'MclassUnixProp', false, 'boolean',
	'Allow Credentials Mangement to override uids locally',
	'REQUIRED'
);

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	DESCRIPTION,
	PERMIT_DEVICE_COLLECTION_ID, PERMIT_ACCOUNT_COLLECTION_ID
) values (
	'PreferLocal', 'MclassUnixProp', false, 'boolean',
	'If credentials management client should prefer local uid,gid,shell',
	'REQUIRED', 'REQUIRED'
);

-- XXX Consider if type UnixGroupAssign should be folded into MclassUnixProp
insert into val_property_type (
	PROPERTY_TYPE, DESCRIPTION, IS_MULTIVALUE
) values (
	'UnixGroupFileProperty', 'properties on unix group files', true
);
insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	PERMIT_DEVICE_COLLECTION_ID, PERMIT_Account_Collection_ID
) values (
	'ForceGroupGID', 'UnixGroupFileProperty', false, 'none',
	'REQUIRED', 'REQUIRED'
);

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, PROPERTY_DATA_TYPE
) VALUES
	('_defaultdomain', 'Defaults', 'defines domain used for defaults where necessary', 'string'),
	('_supportemail', 'Defaults', 'defines support email used by tools', 'string'),
	('_Forced2FA', 'Defaults', '2FA is Mandatory', 'boolean');

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, DESCRIPTION, PROPERTY_DATA_TYPE, PERMIT_ACCOUNT_REALM_ID
) VALUES
	('_root_account_realm_id', 'Defaults', 'define the corporate root identity default', 'none', 'REQUIRED');


INSERT INTO val_property (
	property_name, property_type, is_multivalue, property_data_type,
	description
) VALUES (
	'_max_default_login_length', 'Defaults', false, 'number',
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
	false,
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
	false,
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
	false,
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
	false,
	'boolean',
	'REQUIRED',
	'REQUIRED'
);
--
-- Device provisioning properties
--
--   These need to move to various component_property tables, but we need
--   company_collection_id and friends in there first
--

INSERT INTO val_property(
	property_name, property_type, description, is_multivalue,
	property_data_type,
	permit_company_collection_id,
	company_collection_type
	)
VALUES (
	'DeviceVendorProbeString',
	'DeviceProvisioning',
	'Vendor string that may be found during a device probe',
	true,
	'string',
	'REQUIRED',
	'per-company'
);

INSERT INTO val_property(
	property_name, property_type, description, is_multivalue,
	property_data_type,
	permit_company_collection_id,
	company_collection_type
	)
VALUES (
	'CPUVendorProbeString',
	'DeviceProvisioning',
	'Vendor string that may be found during a CPU probe',
	true,
	'string',
	'REQUIRED',
	'per-company'
);

INSERT INTO val_property(
	property_name, property_type, description, is_multivalue,
	property_data_type,
	permit_company_collection_id,
	company_collection_type
	)
VALUES (
	'PCIVendorID',
	'DeviceProvisioning',
	'numeric PCI Vendor ID',
	true,
	'number',
	'REQUIRED',
	'per-company'
);

INSERT INTO val_property(
	property_name, property_type, description, is_multivalue,
	property_data_type,
	permit_company_collection_id,
	company_collection_type
	)
VALUES (
	'DeviceComponentManagementInterface',
	'DeviceProvisioning',
	'Default name of the management interface for a given device component vendor',
	true,
	'string',
	'REQUIRED',
	'per-company'
);

-- System installation properties

INSERT INTO val_property(
	property_name, property_type, description, is_multivalue,
	property_data_type,
	permit_device_collection_id,
	permit_layer2_network_collection_id,
	permit_layer3_network_collection_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_site_code
	)
VALUES (
	'InstallationProfile',
	'SystemInstallation',
	'Specify the name of the system installation profile to use',
	false,
	'string',
	'ALLOWED',
	'ALLOWED',
	'ALLOWED',
	'ALLOWED',
	'ALLOWED',
	'ALLOWED'
);

insert into val_company_collection_type
	(company_collection_type,
	max_num_members, can_have_hierarchy
	)
values
	('per-company',
	1, false
	);

-- XXX need to auto-create a Account_Collection all_company_XX

-- consider renaming to company_relation
insert into val_company_type_purpose (company_type_purpose) values ('default');

insert into val_company_type(company_type) values  ('corporate family');
insert into val_company_type(company_type) values  ('vendor');
insert into val_company_type(company_type) values  ('consultant provider');
insert into val_company_type(company_type) values  ('hardware provider');
insert into val_company_type(company_type) values  ('software provider');

-- consider switching this to company_manip.add_company.
set jazzhands.permit_company_insert = 'permit';
INSERT INTO Company(Company_ID, Company_Name)
	VALUES (0, 'none');
set jazzhands.permit_company_insert TO default;

INSERT INTO Person(Person_Id, first_name, last_name)
	VALUES (0, 'Non', 'Person');

INSERT INTO Account_Realm(Account_Realm_Id, Account_Realm_Name)
	VALUES (0, 'Non Realm');

INSERT INTO PERSON_COMPANY (company_id, person_id, person_company_status,
	person_company_relation, is_exempt)
values (0, 0, 'enabled',
	'n/a', false);

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


insert into val_authentication_resource (authentication_resource) values ('radius');

insert into val_diet (diet) values ( 'Carnivore');
insert into val_diet (diet) values ( 'Omnivore');
insert into val_diet (diet) values ( 'Vegetarian');
insert into val_diet (diet) values ( 'Pescatarian');

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
	Company_ID
) VALUES (
	0,
	'unknown',
	'unknown',
	'unknown',
	0
);
UPDATE Operating_System SET Operating_System_ID = 0 where Company_ID = 0;

insert into val_person_image_usage (
	person_image_usage, is_multivalue
) values (
	'corpdirectory', false
);

insert into val_shared_netblock_protocol
	(shared_netblock_protocol) values ('BGP');
insert into val_shared_netblock_protocol
	(shared_netblock_protocol) values ('HSRP');
insert into val_shared_netblock_protocol
	(shared_netblock_protocol) values ('VARP');
insert into val_shared_netblock_protocol
	(shared_netblock_protocol) values ('VRRP');

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
	1, false
	);

--- stab stuff
insert into val_property_type (property_type, description, is_multivalue)
values
	('StabRole', 'roles for users in stab', true);

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	permit_account_collection_id
) values
	('StabAccess', 'StabRole', false, 'boolean', 'REQUIRED'),
	('PermitStabSection', 'StabRole', true, 'list', 'REQUIRED')
;

insert into val_property_value (
	property_name, property_type, valid_property_value
) values
	('PermitStabSection', 'StabRole', 'AccountCol'),
	('PermitStabSection', 'StabRole', 'Device'),
	('PermitStabSection', 'StabRole', 'DNS'),
	('PermitStabSection', 'StabRole', 'Network'),
	('PermitStabSection', 'StabRole', 'Netblock'),
	('PermitStabSection', 'StabRole', 'Sites'),
	('PermitStabSection', 'StabRole', 'StabAccess'),
	('PermitStabSection', 'StabRole', 'Attest'),
	('PermitStabSection', 'StabRole', 'Approval'),
	('PermitStabSection', 'StabRole', 'X509'),
	('PermitStabSection', 'StabRole', 'FullAdmin')
;

insert into val_property (
	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
	permit_account_collection_id
) values
	('AccountCollectionAdmin', 'StabRole', true, 'none', 'REQUIRED')
;

INSERT INTO val_property (
	property_name, property_type, property_data_type,
	permit_account_collection_id, description
) VALUES
	('AccountCollectionRO', 'StabRole', 'account_collection_id',
		'REQUIRED', 'ro to direct descendent children collections'),
	('AccountCollectionRW', 'StabRole', 'account_collection_id',
		'REQUIRED', 'r/w to direct descendent children collections')
;


insert into val_property (
	property_name, property_type, is_multivalue, property_data_type,
	description
) values (
	'_stab_root', 'Defaults', false, 'string',
	'root of url for stab, if apps need to direct people'
);

insert into val_property (
	property_name, property_type, is_multivalue, property_data_type,
	description,
	permit_account_realm_id
) values (
	'login_restriction', 'Defaults', false, 'string',
	'per-account realm validation of login names',
	'REQUIRED'
);


-- DNS zone generation
insert into val_property_type (property_type, description, is_multivalue)
values ('DNSZonegen', 'properties for defining dns zone generation', true);

insert into val_property
	(property_name, property_type,
	 description, is_multivalue,
	 property_data_type, permit_device_collection_id, permit_site_code)
values (
	'DNSDistHosts', 'DNSZonegen',
	'indicates hosts that should get dns zones', true,
	'none', 'REQUIRED', 'ALLOWED');

insert into val_property
	(property_name, property_type,
	 description, is_multivalue,
	 property_data_type,permit_netblock_collection_id)
values (
	'DNSACLs', 'DNSZonegen',
	'indicates netblocks that should be in a named acl', true,
	'string', 'REQUIRED');

--- approval stuff

insert into val_property (
	property_name, property_type, is_multivalue, property_data_type,
	description
) values (
	'_approval_email_sender', 'Defaults', false, 'string',
	'Email address to send approvals from '
);

insert into val_property (
	property_name, property_type, is_multivalue, property_data_type,
	description
) values (
	'_approval_email_signer', 'Defaults', false, 'string',
	'Email address to sign aproval emails from (in body)'
);

insert into val_property (
	property_name, property_type, is_multivalue, property_data_type,
	description, permit_account_collection_id
) values (
	'_can_approve_all', 'Defaults', true, 'string',
	'Stored Procedures will allow these people to execute any approval.  Assign sparingly, if at all.',
	'REQUIRED'
);

insert into val_property (
	property_name, property_type, is_multivalue, property_data_type,
	description
) values (
	'_approval_faq_site', 'Defaults', false, 'string',
	'URL to include in emails that tell people where to find more info'
);

insert into val_property (
	property_name,property_type,property_data_type,
	description
) values (
	'_2fa_docurl', 'Defaults', 'string',
	'Used as the URL for enrollment in 2FA'
);

-------------------------------------------------------------------------
-- BEGIN legacy port related stuff used by layer1_connection and elsewhere

insert into val_component_property_type (component_property_type, description)
values ('serial-connection', 'characteristics of serial connections');

insert into val_component_property (
	component_property_name, component_property_type, is_multivalue,
	property_data_type, permit_inter_component_connection_id
) values (
	'baud', 'serial-connection', false,
	'list', 'REQUIRED');
insert into val_component_property_value (
	component_property_name, component_property_type, valid_property_value
) SELECT 'baud', 'serial-connection',
	unnest(ARRAY[110,300,1200,2400,4800,9600,19200,38400,57600,115200]);

insert into val_component_property (
	component_property_name, component_property_type, is_multivalue,
	property_data_type, permit_inter_component_connection_id
) values (
	'flow-control', 'serial-connection', false,
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
	property_data_type, permit_inter_component_connection_id
) values (
	'stop-bits', 'serial-connection', false,
	'list', 'REQUIRED');
insert into val_component_property_value (
	component_property_name, component_property_type, valid_property_value
) SELECT 'stop-bits', 'serial-connection',
	unnest(ARRAY['1','2','1.5'])
;

insert into val_component_property (
	component_property_name, component_property_type, is_multivalue,
	property_data_type, permit_inter_component_connection_id
) values (
	'data-bits', 'serial-connection', false,
	'list', 'REQUIRED');
insert into val_component_property_value (
	component_property_name, component_property_type, valid_property_value
) SELECT 'data-bits', 'serial-connection',
	unnest(ARRAY[7,8])
;

insert into val_component_property (
	component_property_name, component_property_type, is_multivalue,
	property_data_type, permit_inter_component_connection_id
) values (
	'parity', 'serial-connection', false,
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
	property_data_type, permit_inter_component_connection_id, permit_component_id
) values (
	'tcpsrv_device_id', 'tcpsrv-connections', false,
	'none', 'REQUIRED', 'REQUIRED')
;

insert into val_component_property (
	component_property_name, component_property_type, is_multivalue,
	property_data_type, permit_inter_component_connection_id
) values (
	'tcpsrv_enabled', 'tcpsrv-connections', false,
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
	'auto_account_coll', true,
	'properties that define how people are added to account collections automatically based on column changes'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_collection_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'exempt', 'auto_account_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	false
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_collection_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'non_exempt', 'auto_account_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	false
);

--
-- XXX - this needs to be overhauled.
--
insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_collection_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'male', 'auto_account_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	false
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_collection_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'female', 'auto_account_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	false
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_collection_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'unspecified_gender', 'auto_account_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	false
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_collection_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'management', 'auto_account_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	false
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_collection_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'non_management', 'auto_account_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	false
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_collection_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'full_time', 'auto_account_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	false
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_collection_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'non_full_time', 'auto_account_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	false
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_collection_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'account_type', 'auto_account_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'list',
	false
);

insert into val_property_value (
	property_name, property_type, valid_property_value
) values (
	'account_type', 'auto_account_coll', 'person'
);

insert into val_property_value (
	property_name, property_type, valid_property_value
) values (
	'account_type', 'auto_account_coll', 'pseudouser'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_collection_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'site', 'auto_account_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'REQUIRED',
	'none',
	false
);

insert into val_property (
	property_name, property_type,
	permit_account_id,
	permit_account_realm_id,
	property_data_type,
	is_multivalue
) values (
	'AutomatedDirectsAC', 'auto_account_coll',
	'REQUIRED',
	'REQUIRED',
	'account_collection_id',
	false
);

insert into val_property (
	property_name, property_type,
	permit_account_id,
	permit_account_realm_id,
	property_data_type,
	is_multivalue
) values (
	'AutomatedRollupsAC', 'auto_account_coll',
	'REQUIRED',
	'REQUIRED',
	'account_collection_id',
	false
);

INSERT INTO val_property_name_collection_type (
	property_name_collection_type, description
) VALUES
	('auto_ac_assignment',
		'defines which properties to setup for a company by default'),
	('jazzhands-internal',
		'internal jazzhands automations, in triggers/functions');

WITH i AS (
	INSERT INTO property_name_collection (
		property_name_collection_name, property_name_collection_type
	) VALUES (
		'corporate family', 'auto_ac_assignment'
	) RETURNING *
)  INSERT INTO property_name_collection_property_name
	(property_name_collection_id, property_name, property_type)
SELECT i.property_name_collection_id, p.property_name, p.property_type
FROM i, val_property p
WHERE p.property_type = 'auto_account_coll'
AND p.property_data_type = 'none';
;

-- END automated account collection infrastructure (tied to properties)
-------------------------------------------------------------------------

-------------------------------------------------------------------------
--
-- Begin automated properties/colletions
--
INSERT INTO val_netblock_collection_type (
	netblock_collection_type, description, can_have_hierarchy
) VALUES (
	'per-site', 'automated collection named after sites', false
);

INSERT INTO val_property_type (
	property_type, description
) VALUES (
	'automated', 'properties that are automatically managed by jazzhands'
);

INSERT INTO val_property (
	property_type, property_name, permit_netblock_collection_id,
	permit_site_code, property_data_type
) VALUES (
	'automated', 'per-site-netblock_collection', 'REQUIRED',
	'REQUIRED', 'none'
);

--
-- End automated properties/colletions
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- BEGIN certificate

insert into val_encryption_key_purpose
	(encryption_key_purpose, encryption_key_purpose_version, description)
values
	('certpassphrase', 1, 'SSL Crtificates Key Passphrase');

insert into val_x509_fingerprint_hash_algorithm
	(x509_fingerprint_hash_algorithm, description)
values
	('sha1', 'SHA1 hash'),
	('sha256', 'SHA256 hash');

insert into val_x509_certificate_file_format
	(x509_certificate_file_format, description)
values
	('pem', 'human readable rsa certificate'),
	('der', 'binary representation'),
	('keytool', 'Java keystore .jks'),
	('pkcs12', 'PKCS12 .p12 file')
;

insert into val_x509_key_usage
	(x509_key_usage, description, is_extended)
values
	('digitalSignature',	'verifying digital signatures other than other certs/CRLs,  such as those used in an entity authentication service, a data origin authentication service, and/or an integrity service', false),
	('nonRepudiation',	'verifying digital signatures other than other certs/CRLs, to provide a non-repudiation service that protects against the signing entity falsely denying some action.  Also known as contentCommitment', false),
	('keyEncipherment',	'key is used for enciphering private or secret keys', false),
	('dataEncipherment',	'key is used for directly enciphering raw user data without the use of an intermediate symmetric cipher', false),
	('keyAgreement',	NULL, false),
	('keyCertSign',		'key signs other certificates; must be set with ca bit', false),
	('cRLSign',		'key is for verifying signatures on certificate revocation lists', false),
	('encipherOnly',	'with keyAgreement bit, key used for enciphering data while performing key agreement', false),
	('decipherOnly',	'with keyAgreement bit, key used for deciphering data while performing key agreement', false),
	('serverAuth',		'SSL/TLS Web Server Authentication', true),
	('clientAuth',		'SSL/TLS Web Client Authentication', true),
	('codeSigning',		'Code signing', true),
	('emailProtection',	'E-mail Protection (S/MIME)', true),
	('timeStamping',	'Trusted Timestamping', true),
	('OCSPSigning',		'Signing OCSP Responses', true)
;

insert into val_x509_key_usage_category
	(x509_key_usage_category, description)
values
	('ca', 'used to identify a certificate authority'),
	('revocation', 'Used to identify entity that signs crl/ocsp responses'),
	('service', 'used to identify a service on the netowrk'),
	('server', 'used to identify a server as a client'),
	('application', 'cross-authenticate applications'),
	('account', 'used to identify an account/user/person')
;

insert into x509_key_usage_categorization
	(x509_key_usage_category, x509_key_usage)
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

INSERT INTO val_x509_certificate_type
	(x509_certificate_type)
values
	('default')
;

INSERT INTO val_private_key_encryption_type
	(private_key_encryption_type)
values
	('rsa'),
	('dsa'),
	('ecc')
;

-- END certificate
-------------------------------------------------------------------------

-- END certificate
-------------------------------------------------------------------------

-- END certificate
-------------------------------------------------------------------------

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

-------------------------------------------------------------------------
-- BEGIN Phone Directory
insert into val_property_type (
	property_type,
	description
) values (
	'PhoneDirectoryAttributes',
	'attributes for user directory'
);

insert into val_property (
        property_name,
        property_type,
        permit_account_collection_id,
        property_data_type,
        description
) values (
        'PhoneDirectoryAdmin',
        'PhoneDirectoryAttributes',
        'PROHIBITED',
        'account_collection_id',
        'Administrators'
);


insert into val_property (
        property_name,
        property_type,
        permit_company_collection_id,
        property_data_type,
        description
) values (
        'ShowBirthday',
        'PhoneDirectoryAttributes',
        'REQUIRED',
        'none',
        'accounts associated with this company will have their birthday shown'
);

-- END Phone Directory
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- BEGIN Device Inventory

INSERT INTO val_property_type (
	property_type, description
) VALUES
	('DeviceInventory', 'properties for device inventory functions')
;

INSERT INTO val_property (
	property_type, property_name, property_data_type,
	permit_device_collection_id,
	description
) VALUES
	('DeviceInventory', 'AdminAccountCollection', 'account_collection_id',
	'ALLOWED',
	'account collection of administrators allowed to run device inventory')
;

INSERT INTO val_property (
	property_type, property_name, property_data_type,
	description
) VALUES
	('DeviceInventory', 'IgnoreProbedNetblocks', 'netblock_collection_id',
	'When probing devices, prevent any netblocks which are sub-blocks of those in the referenced collection from being assigned to a network interface')
;

INSERT INTO val_netblock_collection_type (
	netblock_collection_type, description
) VALUES (
	'DeviceInventory', 'netblock collections for various automated device inventory function')
;

-- END Device Inventory
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- BEGIN Account Name Overrides

INSERT INTO val_property_type
	(property_type, description)
VALUES
	('account_name_override', 'All properties related to the overriding of account name data')
;

INSERT INTO val_property
    (property_type, property_name, description, property_data_type, account_collection_type, permit_account_collection_id)
VALUES
    ('account_name_override', 'first_name', 'Override what would normally be used for first_name', 'string', 'per-account', 'REQUIRED'),
    ('account_name_override', 'last_name', 'Override what would normally be used for last_name', 'string', 'per-account', 'REQUIRED'),
    ('account_name_override', 'display_name', 'Override what would normally be used for display_name', 'string', 'per-account', 'REQUIRED')
;

-- END Account Name Overrides
-------------------------------------------------------------------------
-------------------------------------------------------------------------
-- BEGIN logical ports

insert into val_logical_port_type (logical_port_type, description) values
	('LACP', 'LACP aggregate'),
	('MLAG', 'Multi-chassis aggregate');

-- END logical ports
-------------------------------------------------------------------------


INSERT INTO val_encryption_key_purpose (
        encryption_key_purpose, encryption_key_purpose_version, description
) VALUES (
        'external', 1, 'Key is stored  outside the database'
);

-------------------------------------------------------------------------
--
-- Begin automated account collections
--
-------------------------------------------------------------------------

INSERT INTO val_property_type (property_type) VALUES ('auto_acct_coll');

ALTER TABLE val_property DISABLE TRIGGER trigger_validate_val_property;
INSERT INTO val_property (
	property_type, 		property_name, 		property_data_type, 		permit_account_collection_id, permit_account_id, permit_account_realm_id, permit_company_id, permit_company_collection_id, permit_site_code
) VALUES
	('auto_acct_coll', 'exempt',			'none',						'REQUIRED',		'PROHIBITED',	'REQUIRED', 'PROHIBITED',	'REQUIRED',		'PROHIBITED'),
	('auto_acct_coll', 'site',				'none',						'REQUIRED',		'PROHIBITED',	'REQUIRED', 'ALLOWED',		'PROHIBITED',	'PROHIBITED'),
	('auto_acct_coll', 'AutomatedDirectsAC','account_collection_id',	'PROHIBITED',	'REQUIRED',		'REQUIRED', 'PROHIBITED',	'PROHIBITED',	'PROHIBITED'),
	('auto_acct_coll', 'AutomatedRollupsAC','account_collection_id',	'PROHIBITED',	'REQUIRED',		'REQUIRED', 'PROHIBITED',	'PROHIBITED',	'PROHIBITED'),
	('auto_acct_coll', 'non_exempt',		'none',						'REQUIRED',		'PROHIBITED',	'REQUIRED', 'PROHIBITED',	'REQUIRED',		'PROHIBITED'),
	('auto_acct_coll', 'male',				'none',						'REQUIRED',		'PROHIBITED',	'REQUIRED', 'PROHIBITED',	'REQUIRED',		'PROHIBITED'),
	('auto_acct_coll', 'female',			'none',						'REQUIRED',		'PROHIBITED',	'REQUIRED', 'PROHIBITED',	'REQUIRED',		'PROHIBITED'),
	('auto_acct_coll', 'unspecified_gender','none',						'REQUIRED',		'PROHIBITED',	'REQUIRED', 'PROHIBITED',	'REQUIRED',		'PROHIBITED'),
	('auto_acct_coll', 'management',		'none',						'REQUIRED',		'PROHIBITED',	'REQUIRED', 'PROHIBITED',	'REQUIRED',		'PROHIBITED'),
	('auto_acct_coll', 'non_management',	'none',						'REQUIRED',		'PROHIBITED',	'REQUIRED', 'PROHIBITED',	'REQUIRED',		'PROHIBITED'),
	('auto_acct_coll', 'full_time',			'none',						'REQUIRED',		'PROHIBITED',	'REQUIRED', 'PROHIBITED',	'REQUIRED',		'PROHIBITED'),
	('auto_acct_coll', 'non_full_time',		'none',						'REQUIRED',		'PROHIBITED',	'REQUIRED', 'PROHIBITED',	'REQUIRED',		'PROHIBITED'),
	('auto_acct_coll', 'account_type',		'list',						'REQUIRED',		'PROHIBITED',	'REQUIRED', 'PROHIBITED',	'REQUIRED',		'PROHIBITED')
;
ALTER TABLE val_property ENABLE TRIGGER trigger_validate_val_property;

-- end automated account collections

-------------------------------------------------------------------------
--
-- This is required to make the attestation subsystem work.
--
-------------------------------------------------------------------------
INSERT INTO val_approval_type (approval_type)
	VALUES (unnest(ARRAY['account','jira-hr']));
INSERT INTO val_property_type ( property_type, description )
	VALUES ('attestation', 'define elements of regular attestation process');

INSERT INTO val_property (
	property_name,
	property_type,
	property_data_type
) VALUES (
	unnest(ARRAY['ReportAttest', 'FieldAttest',
	'account_collection_membership']),
	'attestation', 'string'
);

INSERT INTO val_property (
	property_name, property_type,
	permit_account_collection_id, property_data_type,
	description
) VALUES (
	'AlternateApprovers', 'attestation',
	'REQUIRED', 'account_collection_id',
	'indicates additional users permitted to approve attestation assigned to accounts'
);

INSERT INTO val_property (
	property_name, property_type,
	account_collection_type,
	property_value_account_collection_type_restriction,
	permit_account_collection_id, property_data_type,
	description
) VALUES (
	'Delegate', 'attestation',
	'per-account',
	'per-account',
	'REQUIRED', 'account_collection_id',
	'Indicates an alternate account who acts on behalf.'
);

INSERT INTO val_approval_process_type ( approval_process_type )
	VALUES ('attestation');
INSERT INTO val_approval_expiration_action ( approval_expiration_action )
	VALUES ('pester');
INSERT INTO val_attestation_frequency ( attestation_frequency )
	VALUES ('quarterly');
INSERT INTO val_approval_chain_response_period (
	approval_chain_response_period
) VALUES (
	'1 week'
);

INSERT INTO property (
	property_name, property_type, property_value
) VALUES
	('ReportAttest', 'attestation', 'auto_acct_colll:AutomateddDirectsAC'),
	('FieldAttest', 'attestation', 'person_company:position_title'),
	('account_collection_membership', 'attestation', 'department')
;

INSERT INTO val_property_name_collection_type (
	property_name_collection_type, description
) VALUES (
	'attestation', 'properties that make up attestation chains'
);

WITH x AS (
	INSERT INTO property_name_collection (
		property_name_collection_name, property_name_collection_type
	) VALUES (
		'ReportingAttestation', 'attestation'
	) RETURNING *
) INSERT INTO property_name_collection_property_name (
	property_name_collection_id,
	property_name,
	property_type
) SELECT property_name_collection_id,
	unnest(ARRAY['ReportAttest', 'FieldAttest', 'account_collection_membership']),
	'attestation'
FROM x;


-------------------------------------------------------------------------
--
-- End requirements for attestation subsystem
--
-------------------------------------------------------------------------

-------------------------------------------------------------------------
--
-- BEGIN Services
--
-------------------------------------------------------------------------

INSERT INTO val_service_namespace (service_namespace)
VALUES
	('default');

INSERT INTO val_service_type (service_type)
VALUES
	('network'),
	('socket');


INSERT INTO service_sla (
	service_sla_name, service_availability
) VALUES (
	'always', 100
);


INSERT INTO  val_service_affinity
(service_affinity, service_affinity_rank)
VALUES
	('device', 100),
	('parent_device', 200),
	('rack', 300),
	('rack_row', 400),
	('site', 500)
;

INSERT INTO service_sla (
	service_sla_name, minimum_service_affinity, maximum_service_affinity
) VALUES
	('same-site', 'site', 'site'),
	('same-parent', 'parent_device', 'parent_device'),
	('same-device', 'device', 'device')
;

-- XXX - these need to be rethunk for health checks
INSERT INTO protocol (
	protocol, protocol_number
) VALUES
	('none', 0),
	('tcpconnect', 0),
	('ssl', 0),
	('tcp', 6),
	('udp', 17)
;

INSERT INTO val_port_range_type (
	port_range_type, protocol, range_permitted
) VALUES
	('services', 'tcp', false),
	('services', 'udp', false),
	('localservices', 'tcp', false),
	('localservices', 'udp', false)
;

INSERT INTO port_range (
	port_range_name, protocol, port_range_type,
	port_start, port_end, is_singleton
) VALUES
	('postgresql', 'tcp', 'services', 5432, 5432, true),
	('http', 'tcp', 'services', 80, 80, true),
	('https', 'tcp', 'services', 443, 443, true),
	('domain', 'tcp', 'services', 53, 53, true),
	('domain', 'udp', 'services', 53, 53, true)
;


INSERT INTO val_service_feature (
	service_feature
) values
	('read'),
	('write')
;

INSERT INTO  val_source_repository_method
(source_repository_method)
VALUES
	('git'),
	('svn'),
	('cvs'),
	('mercurial')
;

INSERT INTO  val_source_repository_uri_purpose
	(source_repository_uri_purpose)
VALUES
	('checkout'),
	('browse')
;


INSERT INTO val_property_type ( property_type)
VALUES
	('launch'),
	('documentation');

INSERT INTO val_property (
	property_type, property_name,
	permit_service_version_collection_id, property_data_type, is_multivalue
) VALUES
	('launch', 'location', 'REQUIRED', 'list', true),
	('launch', 'dedicated', 'REQUIRED', 'boolean', false),
	('launch', 'minimum_cpu', 'REQUIRED', 'number', false),
	('launch', 'minimum_memory', 'REQUIRED', 'number', false),
	('launch', 'minimum_disk', 'REQUIRED', 'number', false),
	('documentation', 'manual', 'REQUIRED', 'string', false)
;

INSERT INTO val_property_value (
	property_type, property_name, valid_property_value
) VALUES
	('launch', 'location', 'baremetal'),
	('launch', 'location', 'virtual-machine')
;

INSERT INTO val_property (
	property_type, property_name,
	permit_service_version_collection_id, permit_netblock_collection_id, property_data_type
) VALUES
	('launch', 'launch-netblocks', 'REQUIRED', 'REQUIRED', 'none')
;


INSERT INTO val_property_type ( property_type)
VALUES
	('role');

--
-- this should probably trigger automated account collections
-- somehow
--
INSERT INTO val_property (
	property_type, property_name,
	permit_service_version_collection_id, property_data_type
) VALUES
	('role', 'owner', 'REQUIRED', 'account_collection_id'),
	('role', 'admin', 'REQUIRED', 'account_collection_id'),
	('role', 'iud_role', 'REQUIRED', 'account_collection_id'),
	('role', 'ro_role', 'REQUIRED', 'account_collection_id'),
	('role', 'log_watcher', 'REQUIRED', 'account_collection_id')
;

INSERT INTO  val_service_endpoint_provider_type
(service_endpoint_provider_type, proxies_connections, translates_addresses)
VALUES
	('direct', false, false),
	('loadbalancer', true, false),
	('ecmp', false, false)
;

INSERT INTO  val_service_endpoint_provider_collection_type
(service_endpoint_provider_collection_type, max_num_members, can_have_hierarchy)
VALUES
	('per-service-endpoint-provider', 1, false)
;

INSERT INTO  val_service_version_collection_type
(service_version_collection_type, max_num_members, can_have_hierarchy)
VALUES
	('current-services', NULL, false),
	('all-services', NULL, false)
;

INSERT INTO val_checksum_algorithm (
	checksum_algorithm
) VALUES (
	'none'
);

INSERT INTO val_software_artifact_relationship (
	software_artifact_relationship
) VALUES (
	'depend'
);

INSERT INTO val_service_relationship_type (
	service_relationship_type
) VALUES
	('depend');

INSERT INTO val_source_repository_protocol (
	source_repository_protocol
) VALUES
	('https'),
	('ssh');

-------------------------------------------------------------------------
--
-- END Services
--
-------------------------------------------------------------------------
