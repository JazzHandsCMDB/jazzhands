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
	VALUES ('deleted', 'deleted'');
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

INSERT INTO Company(Company_ID, Company_Name, Is_Corporate_Family)
	VALUES (0, 'none', 'N');

INSERT INTO VAL_Office_Site(Office_Site, Description)
	VALUES ('New York', 'New York, NY');
INSERT INTO VAL_Office_Site(Office_Site, Description)
	VALUES ('London', 'London, UK');
INSERT INTO VAL_Office_Site(Office_Site, Description)
	VALUES ('Washington', 'Washington, DC');

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

INSERT INTO Unix_Group (
	Unix_Group_ID,
	Unix_GID,
	Group_Password,
	Group_Name
) VALUES (
	SEQ_Unix_Group_ID.nextval,
	0,
	'*',
	'root'
);

INSERT INTO User_Unix_Info (
	System_User_ID,
	Unix_UID,
	Unix_Group_ID,
	Shell,
	Default_Home
) VALUES (
	SEQ_System_User_ID.currval,
	0,
	SEQ_Unix_Group_ID.currval,
	'/bin/sh',
	'/'
);

INSERT INTO System_Password (
	System_User_ID,
	Crypt,
	MD5Hash,
	SHA1,
	Change_Time
) VALUES (
	SEQ_System_User_ID.currval,
	'T6r7sdlVHpZH2',
	'921a2a9c834bfb8197680af1e33d507e',
	'5d531165e095c3441bf2685a53d2371e9c20ec4d',
	SYSDATE
);

INSERT INTO Kerberos_Realm (Realm_Name) VALUES ('MIT.EDU');

INSERT INTO VAL_UClass_Type (UClass_Type, Description)
	VALUES ('per-user', 'UClass that contain a single user for assigning individual users to objects that only accept UClass assignments');
INSERT INTO VAL_UClass_Type (UClass_Type, Description)
	VALUES ('systems', 'UClass that can be assigned to system-type objects to control access to system and network resources');
INSERT INTO VAL_UClass_Type (UClass_Type, Description)
	VALUES ('doors', 'UClass that can be assigned to door-type objects to control access to physical areas');


INSERT INTO UClass (UClass_ID, UClass_Type, Name)
	VALUES (SEQ_UClass_ID.nextval, 'systems', 'all_employee');
INSERT INTO UClass (UClass_ID, UClass_Type, Name)
	VALUES (SEQ_UClass_ID.nextval, 'systems', 'all_contractor');
INSERT INTO UClass (UClass_ID, UClass_Type, Name)
	VALUES (SEQ_UClass_ID.nextval, 'systems', 'all_pseudouser');
INSERT INTO UClass (UClass_ID, UClass_Type, Name)
	VALUES (SEQ_UClass_ID.nextval, 'systems', 'all_vendor');

INSERT INTO VAL_Status (Status, Description) 
	VALUES ('unknown', 'Unknown or incompletely entered');
INSERT INTO VAL_Status (Status, Description) 
	VALUES ('up', 'Up/Normal');
INSERT INTO VAL_Status (Status, Description) 
	VALUES ('down', 'Intentionally down or offline');
INSERT INTO VAL_Status (Status, Description) 
	VALUES ('removed', 'System has been removed');

INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('cablemanagement');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('circuitmux');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('cna');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('consolesrv');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('copier');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('das');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('desktop');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('firewall');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('gpsclock');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('loadbalancer');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('monitorappliance');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('nas');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('netcam');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('patchpanel');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('pbx');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('powerrectifier');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('printer');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('router');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('rpc');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('san');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('sanrouter');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('sanswitch');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('searchapp');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('server');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('switch');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('tapelibrary');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('tdmaccess');
INSERT INTO VAL_Device_Function_Type (Device_Function_Type)
	VALUES ('ups');

INSERT INTO VAL_Production_State (Production_State)
	VALUES ('unspecified');
INSERT INTO VAL_Production_State (Production_State)
	VALUES ('unallocated');
INSERT INTO VAL_Production_State (Production_State)
	VALUES ('production');
INSERT INTO VAL_Production_State (Production_State)
	VALUES ('dev');
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

INSERT INTO Partner (Partner_ID, Name)
	VALUES (0, 'Not Applicable');
UPDATE Partner SET Partner_ID = 0 where Name = 'Not Applicable';
INSERT INTO Partner (Name)
	VALUES ('Sun Microsystems');
INSERT INTO Partner (Name)
	VALUES ('IBM');
INSERT INTO Partner (Name)
	VALUES ('RedHat');
INSERT INTO Partner (Name)
	VALUES ('Debian');
INSERT INTO Partner (Name)
	VALUES ('HP');
INSERT INTO Partner (Name)
	VALUES ('Cyclades');

INSERT INTO VAL_Device_Type (
	Partner_ID,
	Model,
	Has_802_3_Interface,
	Has_802_11_Interface,
	SNMP_Capable
) VALUES (
	0,
	'unknown',
	'N',
	'N',
	'N'
);

INSERT INTO VAL_Device_Type (
	Partner_ID,
	Model,
	Has_802_3_Interface,
	Has_802_11_Interface,
	SNMP_Capable
) VALUES (
	(SELECT Partner_ID FROM Partner WHERE Name = 'Sun Microsystems'),
	'SunFire V100',
	'Y',
	'N',
	'Y'
);

INSERT INTO VAL_Device_Type (
	Partner_ID,
	Model,
	Has_802_3_Interface,
	Has_802_11_Interface,
	SNMP_Capable
) VALUES (
	(SELECT Partner_ID FROM Partner WHERE Name = 'Sun Microsystems'),
	'SunFire V120',
	'Y',
	'N',
	'Y'
);

INSERT INTO VAL_Device_Type (
	Partner_ID,
	Model,
	Has_802_3_Interface,
	Has_802_11_Interface,
	SNMP_Capable
) VALUES (
	(SELECT Partner_ID FROM Partner WHERE Name = 'Sun Microsystems'),
	'SunFire V240',
	'Y',
	'N',
	'Y'
);

INSERT INTO VAL_Device_Type (
	Partner_ID,
	Model,
	Has_802_3_Interface,
	Has_802_11_Interface,
	SNMP_Capable
) VALUES (
	(SELECT Partner_ID FROM Partner WHERE Name = 'Sun Microsystems'),
	'SunFire V440',
	'Y',
	'N',
	'Y'
);

INSERT INTO VAL_Device_Type (
	Partner_ID,
	Model,
	Has_802_3_Interface,
	Has_802_11_Interface,
	SNMP_Capable
) VALUES (
	(SELECT Partner_ID FROM Partner WHERE Name = 'IBM'),
	'eServer 326',
	'Y',
	'N',
	'Y'
);

INSERT INTO VAL_Device_Type (
	Partner_ID,
	Model,
	Has_802_3_Interface,
	Has_802_11_Interface,
	SNMP_Capable
) VALUES (
	(SELECT Partner_ID FROM Partner WHERE Name = 'HP'),
	'DL360',
	'Y',
	'N',
	'Y'
);

INSERT INTO VAL_Device_Type (
	Partner_ID,
	Model,
	Has_802_3_Interface,
	Has_802_11_Interface,
	SNMP_Capable
) VALUES (
	(SELECT Partner_ID FROM Partner WHERE Name = 'HP'),
	'DL380',
	'Y',
	'N',
	'Y'
);

INSERT INTO VAL_Device_Type (
	Partner_ID,
	Model,
	Has_802_3_Interface,
	Has_802_11_Interface,
	SNMP_Capable
) VALUES (
	(SELECT Partner_ID FROM Partner WHERE Name = 'Cyclades'),
	'AlterPath ACS48',
	'Y',
	'N',
	'Y'
);

INSERT INTO Operating_System (
	Operating_System_ID,
	Name,
	Version,
	Partner_ID
) VALUES (
	0,
	'unknown',
	'unknown',
	0
);
UPDATE Operating_System SET Operating_System_ID = 0 where Partner_ID = 0;

INSERT INTO Operating_System (
	Name,
	Version,
	Partner_ID
) VALUES (
	'Solaris',
	'8',
	(SELECT Partner_ID FROM Partner WHERE Name = 'Sun Microsystems')
);

INSERT INTO Operating_System (
	Name,
	Version,
	Partner_ID
) VALUES (
	'Solaris',
	'9',
	(SELECT Partner_ID FROM Partner WHERE Name = 'Sun Microsystems')
);

INSERT INTO Operating_System (
	Name,
	Version,
	Partner_ID
) VALUES(
	'Solaris',
	'10',
	(SELECT Partner_ID FROM Partner WHERE Name = 'Sun Microsystems')
);

INSERT INTO Operating_System (
	Name,
	Version,
	Partner_ID
) VALUES(
	'Solaris',
	'11',
	(SELECT Partner_ID FROM Partner WHERE Name = 'Sun Microsystems')
);

INSERT INTO VAL_Phone_Number_Type (Phone_Number_Type)
	VALUES ('office');
INSERT INTO VAL_Phone_Number_Type (Phone_Number_Type)
	VALUES ('home');
INSERT INTO VAL_Phone_Number_Type (Phone_Number_Type)
	VALUES ('mobile');
INSERT INTO VAL_Phone_Number_Type (Phone_Number_Type)
	VALUES ('fax');

INSERT INTO VAL_Authentication_Method (Authentication_Method)
	VALUES ('password');
INSERT INTO VAL_Authentication_Method (Authentication_Method)
	VALUES ('kerberos');

INSERT INTO VAL_Unix_Group_Prop_Type (Unix_Group_Prop_Type)
	VALUES ('forcegid');

INSERT INTO VAL_User_Location_Type (System_User_Location_Type)
	VALUES ('office');
INSERT INTO VAL_User_Location_Type (System_User_Location_Type)
	VALUES ('home');

INSERT INTO VAL_Database_Type (Database_Type)
	VALUES ('oracle');
INSERT INTO VAL_Database_Type (Database_Type)
	VALUES ('mysql');
INSERT INTO VAL_Database_Type (Database_Type)
	VALUES ('postgresql');
INSERT INTO VAL_Database_Type (Database_Type)
	VALUES ('enterprisedb');
INSERT INTO VAL_Database_Type (Database_Type)
	VALUES ('tds');
INSERT INTO VAL_Database_Type (Database_Type)
	VALUES ('ldap');

INSERT INTO VAL_Device_Collection_Type (Device_Collection_Type)
	VALUES ('mclass');
INSERT INTO VAL_Device_Collection_Type (Device_Collection_Type)
	VALUES ('adhoc');
INSERT INTO VAL_Device_Collection_Type (Device_Collection_Type)
	VALUES ('undefined');

INSERT INTO VAL_MClass_Unix_PW_Type (MClass_Unix_PW_Type)
	VALUES ('star');
INSERT INTO VAL_MClass_Unix_PW_Type (MClass_Unix_PW_Type)
	VALUES ('crypt');
INSERT INTO VAL_MClass_Unix_PW_Type (MClass_Unix_PW_Type)
	VALUES ('md5');
INSERT INTO VAL_MClass_Unix_PW_Type (MClass_Unix_PW_Type)
	VALUES ('sha1');
INSERT INTO VAL_MClass_Unix_PW_Type (MClass_Unix_PW_Type)
	VALUES ('blowfish');
INSERT INTO VAL_MClass_Unix_PW_Type (MClass_Unix_PW_Type)
	VALUES ('token');

INSERT INTO VAL_MClass_Unix_Home_Type (MClass_Unix_Home_Type)
	VALUES ('standard');
INSERT INTO VAL_MClass_Unix_Home_Type (MClass_Unix_Home_Type)
	VALUES ('generic');

INSERT INTO VAL_MClass_Extra_File_Type (MClass_Extra_File_Type)
	VALUES ('wwwgroup');

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

INSERT INTO 
	Device_Collection (Name, Device_Collection_Type)
VALUES (
	'default',
	'mclass'
	);
