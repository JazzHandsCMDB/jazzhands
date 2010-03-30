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

INSERT INTO VAL_System_User_Type(System_User_Type, Is_Person, Description)
	VALUES ('employee', 'Y', 'Employee');
INSERT INTO VAL_System_User_Type(System_User_Type, Is_Person, Description)
	VALUES ('contractor', 'Y', 'Contractor');
INSERT INTO VAL_System_User_Type(System_User_Type, Is_Person, Description)
	VALUES ('pseudouser', 'N', 'PseudoUser');
INSERT INTO VAL_System_User_Type(System_User_Type, Is_Person, Description)
	VALUES ('vendor', 'Y', 'Vendor');
INSERT INTO VAL_System_User_Type(System_User_Type, Is_Person, Description)
	VALUES ('blacklist', 'N', 'Blacklist');

INSERT INTO VAL_System_User_Status(System_User_Status, Description)
	VALUES ('enabled', 'Enabled');
INSERT INTO VAL_System_User_Status(System_User_Status, Description)
	VALUES ('disabled', 'Disabled');
INSERT INTO VAL_System_User_Status(System_User_Status, Description)
	VALUES ('forcedisable', 'forcedisable - User Forced to Disabled status');
INSERT INTO VAL_System_User_Status(System_User_Status, Description)
	VALUES ('deleted', 'deleted');
INSERT INTO VAL_System_User_Status(System_User_Status, Description)
	VALUES ('terminated', 'terminated - User has been terminated');
INSERT INTO VAL_System_User_Status(System_User_Status, Description)
	VALUES ('onleave', 'onleave - User is disabled due to being on leave');

INSERT INTO VAL_Image_Type(Image_Type) VALUES ('jpeg');
INSERT INTO VAL_Image_Type(Image_Type) VALUES ('tiff');
INSERT INTO VAL_Image_Type(Image_Type) VALUES ('pnm');

INSERT INTO VAL_Reporting_Type(Reporting_Type, Description)
	VALUES ('direct', 'Direct');
INSERT INTO VAL_Reporting_Type(Reporting_Type, Description)
	VALUES ('indirect', 'Indirect');

INSERT INTO VAL_UClass_Type (UClass_Type, Description)
	VALUES ('per-user', 'UClass that contain a single user for assigning individual users to objects that only accept UClass assignments');
INSERT INTO VAL_UClass_Type (UClass_Type, Description)
	VALUES ('systems', 'UClass that can be assigned to system-type objects to control access to system and network resources');
INSERT INTO VAL_UClass_Type (UClass_Type, Description)
	VALUES ('unix-group', 'Uclass representing a Unix group');
INSERT INTO VAL_UClass_Type (UClass_Type, Description)
	VALUES ('doors', 'UClass that can be assigned to door-type objects to control access to physical areas');

INSERT INTO VAL_Status (Status, Description) 
	VALUES ('unknown', 'Unknown or incompletely entered');
INSERT INTO VAL_Status (Status, Description) 
	VALUES ('up', 'Up/Normal');
INSERT INTO VAL_Status (Status, Description) 
	VALUES ('down', 'Intentionally down or offline');
INSERT INTO VAL_Status (Status, Description) 
	VALUES ('removed', 'System has been removed');

INSERT INTO VAL_Production_State (Production_State)
	VALUES ('unspecified');
INSERT INTO VAL_Production_State (Production_State)
	VALUES ('unallocated');
INSERT INTO VAL_Production_State (Production_State)
	VALUES ('production');
INSERT INTO VAL_Production_State (Production_State)
	VALUES ('development');
INSERT INTO VAL_Production_State (Production_State)
	VALUES ('qa');
INSERT INTO VAL_Production_State (Production_State)
	VALUES ('staging');
INSERT INTO VAL_Production_State (Production_State)
	VALUES ('test');

INSERT INTO VAL_Ownership_Status (Ownership_Status)
	VALUES ('owned');
INSERT INTO VAL_Ownership_Status (Ownership_Status)
	VALUES ('leased');
INSERT INTO VAL_Ownership_Status (Ownership_Status)
	VALUES ('onloan');
INSERT INTO VAL_Ownership_Status (Ownership_Status)
	VALUES ('unknown');

INSERT INTO VAL_Phone_Number_Type (Phone_Number_Type)
	VALUES ('office');
INSERT INTO VAL_Phone_Number_Type (Phone_Number_Type)
	VALUES ('home');
INSERT INTO VAL_Phone_Number_Type (Phone_Number_Type)
	VALUES ('mobile');
INSERT INTO VAL_Phone_Number_Type (Phone_Number_Type)
	VALUES ('fax');

insert into VAL_APP_KEY (APP_KEY, DESCRIPTION) values
	('DBType', 'Database Type'); 
insert into VAL_APP_KEY (APP_KEY, DESCRIPTION) values
	('Method', 'Method for Authentication'); 
insert into VAL_APP_KEY (APP_KEY, DESCRIPTION) values
	('Password', 'Password or equivalent'); 
insert into VAL_APP_KEY (APP_KEY, DESCRIPTION) values
	('ServiceName', 'Service Name used for certain methods (DB methods, notably)'); 
insert into VAL_APP_KEY (APP_KEY, DESCRIPTION) values
	('Username', 'Username or equivalent'); 

INSERT INTO VAL_APP_KEY_VALUES (APP_KEY, APP_VALUE)
	VALUES ('Method', 'password');

INSERT INTO VAL_User_Location_Type (System_User_Location_Type)
	VALUES ('office');
INSERT INTO VAL_User_Location_Type (System_User_Location_Type)
	VALUES ('home');

INSERT INTO VAL_APP_KEY_VALUES (APP_KEY, APP_VALUE)
	VALUES ('DBType', 'ftp');
INSERT INTO VAL_APP_KEY_VALUES (APP_KEY, APP_VALUE)
	VALUES ('DBType', 'ldap');
INSERT INTO VAL_APP_KEY_VALUES (APP_KEY, APP_VALUE)
	VALUES ('DBType', 'mysql');
INSERT INTO VAL_APP_KEY_VALUES (APP_KEY, APP_VALUE)
	VALUES ('DBType', 'oracle');
INSERT INTO VAL_APP_KEY_VALUES (APP_KEY, APP_VALUE)
	VALUES ('DBType', 'postgres');
INSERT INTO VAL_APP_KEY_VALUES (APP_KEY, APP_VALUE)
	VALUES ('DBType', 'sqlrelay');
INSERT INTO VAL_APP_KEY_VALUES (APP_KEY, APP_VALUE)
	VALUES ('DBType', 'tds');

INSERT INTO VAL_Device_Collection_Type (Device_Collection_Type)
	VALUES ('mclass');
INSERT INTO VAL_Device_Collection_Type (Device_Collection_Type)
	VALUES ('adhoc');
INSERT INTO VAL_Device_Collection_Type (Device_Collection_Type)
	VALUES ('approle');
INSERT INTO VAL_Device_Collection_Type (Device_Collection_Type)
	VALUES ('undefined');

INSERT INTO VAL_Password_Type (PASSWORD_TYPE)
	VALUES ('star');
INSERT INTO VAL_Password_Type (PASSWORD_TYPE)
	VALUES ('des');
INSERT INTO VAL_Password_Type (PASSWORD_TYPE)
	VALUES ('md5');
INSERT INTO VAL_Password_Type (PASSWORD_TYPE)
	VALUES ('sha1');
INSERT INTO VAL_Password_Type (PASSWORD_TYPE)
	VALUES ('blowfish');
INSERT INTO VAL_Password_Type (PASSWORD_TYPE)
	VALUES ('token');

-- XXX VAL_MClass_Unix_Home_Type

INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('Ethernet');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('FastEthernet');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('GigabitEthernet');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('10GigEthernet');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('DS1');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('DS3');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('E1');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('E3');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('OC3');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('OC12');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('OC48');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('OC192');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('OC768');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('serial');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('virtual');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
	VALUES ('loopback');

insert into val_netblock_status (NETBLOCK_STATUS) values ('Allocated');
insert into val_netblock_status (NETBLOCK_STATUS) values ('Deallocated');
insert into val_netblock_status (NETBLOCK_STATUS) values ('Legacy');
insert into val_netblock_status (NETBLOCK_STATUS) values ('ExternalOwned');
insert into val_netblock_status (NETBLOCK_STATUS) values ('Reserved');

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


-- XXX need to auto-create a uclass all_company_XX
INSERT INTO Company(Company_ID, Company_Name, Is_Corporate_Family)
	VALUES (0, 'none', 'N');

INSERT INTO System_User (
	System_User_ID,
	Login,
	First_Name,
	Last_Name,
	System_User_Status,
	System_User_Type,
	Company_Id
) VALUES (
	SEQ_System_User_ID.nextval,
	'root',
	'Super',
	'User',
	'enabled',
	'pseudouser',
	(SELECT Company_ID FROM Company WHERE Company_Name = 'none')
);

insert into uclass (uclass_id, name, uclass_type)
	values (SEQ_UCLASS_ID.nextval, 'root', 'unix-group');

INSERT INTO Unix_Group (
	Uclass_id,
	Unix_GID,
	Group_Password,
	Group_Name
) VALUES (
	SEQ_UCLASS_ID.currval,
	0,
	'*',
	'root'
);

INSERT INTO User_Unix_Info (
	System_User_ID,
	Unix_UID,
	UNIX_GROUP_UCLASS_ID,
	Shell,
	Default_Home
) VALUES (
	SEQ_System_User_ID.currval,
	0,
	SEQ_UCLASS_ID.currval,
	'/bin/sh',
	'/'
);

INSERT INTO System_Password (
	System_User_ID,
	Password_type,
	User_Password,
	Change_Time
) VALUES (
	SEQ_System_User_ID.currval,
	'des',
	'T6r7sdlVHpZH2',
	SYSDATE
);


INSERT INTO 
	Device_Collection (Name, Device_Collection_Type)
VALUES (
	'default',
	'mclass'
	);
