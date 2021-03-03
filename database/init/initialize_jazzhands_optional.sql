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
-- Items that are accurate but are not strictly required

SELECT company_manip.add_company(
	_company_name := 'Sun Microsystems',
	_company_types := ARRAY['hardware provider']
);

SELECT company_manip.add_company(
	_company_name := 'Dell',
	_company_types := ARRAY['hardware provider']
);

SELECT company_manip.add_company(
	_company_name := 'HP',
	_company_types := ARRAY['hardware provider']
);

SELECT company_manip.add_company(
	_company_name := 'Cyclades',
	_company_types := ARRAY['hardware provider']
);

SELECT company_manip.add_company(
	_company_name := 'RedHat',
	_company_types := ARRAY['software provider']
);

SELECT company_manip.add_company(
	_company_name := 'Debian',
	_company_types := ARRAY['software provider']
);

SELECT company_manip.add_company(
	_company_name := 'Xen',
	_company_types := ARRAY['software provider']
);

INSERT INTO Device_Type (
	Company_Id,
	Model,
	Has_802_3_Interface,
	Has_802_11_Interface,
	SNMP_Capable,
	Is_Chassis,
	RACK_UNITS
) VALUES (
	(SELECT Company_Id FROM Company WHERE Company_Name = 'Sun Microsystems'),
	'SunFire T1000',
	'Y',
	'N',
	'Y',
	'Y',
	1
);

INSERT INTO Device_Type (
	Company_ID,
	Model,
	Has_802_3_Interface,
	Has_802_11_Interface,
	SNMP_Capable,
	Is_Chassis,
	RACK_UNITS
) VALUES (
	(SELECT Company_ID FROM Company WHERE Company_Name = 'Sun Microsystems'),
	'SunFire T2000',
	'Y',
	'N',
	'Y',
	'Y',
	1
);

INSERT INTO Device_Type (
	Company_ID,
	Model,
	Has_802_3_Interface,
	Has_802_11_Interface,
	SNMP_Capable, is_chassis, rack_units
) VALUES (
	(SELECT Company_ID FROM Company WHERE Company_Name = 'IBM'),
	'eServer 326',
	'Y',
	'N',
	'Y', 'Y', 2
);

INSERT INTO Device_Type (
	Company_ID,
	Model,
	Has_802_3_Interface,
	Has_802_11_Interface,
	SNMP_Capable, is_chassis, rack_units
) VALUES (
	(SELECT Company_ID FROM Company WHERE Company_Name = 'HP'),
	'DL360',
	'Y',
	'N',
	'Y', 'Y', 1
);

INSERT INTO Device_Type (
	Company_ID,
	Model,
	Has_802_3_Interface,
	Has_802_11_Interface,
	SNMP_Capable,
	Is_Chassis,
	Rack_Units
) VALUES (
	(SELECT Company_ID FROM Company WHERE Company_Name = 'Cyclades'),
	'AlterPath ACS48',
	'Y',
	'N',
	'Y',
	'Y',
	1
);

INSERT INTO Device_Type (
	Company_ID,
	Model,
	Has_802_3_Interface,
	Has_802_11_Interface,
	SNMP_Capable,
	Is_Chassis,
	Rack_Units
) VALUES (
	(SELECT Company_ID FROM Company WHERE Company_Name = 'Xen'),
	'Virtual Machine',
	'Y',
	'N',
	'Y',
	'Y',
	0
);

INSERT INTO Operating_System (
	Operating_System_Name,
	Major_Version,
	Version,
	Company_ID
) VALUES(
	'Solaris',
	'10',
	'10',
	(SELECT Company_ID FROM Company WHERE Company_Name = 'Sun Microsystems')
);

-----------------------------------------------------------------------------------------------------------------------------------------

insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS, NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION, CAN_SUBNET)
values
	('127.0.0.0/8', 'N', 'Allocated', 'default', 'Localhost Network', 'N'),
	('127.0.0.1/8', 'Y', 'Allocated', 'default', 'Localhost', 'N'),
	('::1/128', 'N', 'Allocated', 'default', 'Localhost', 'N'),
	('::1/128', 'Y', 'Allocated', 'default', 'Localhost', 'N'),
	('169.254.0.0/16', 'N', 'Allocated', 'default', 'RFC3927 Autoconfig', 'Y'),
	('224.0.0.0/4', 'N', 'Allocated', 'default', 'IPv4 Multicast', 'Y'),
	('FF00::/8', 'N', 'Allocated', 'default', 'IPv6 Multicast', 'Y');

-- RFC4193 globally unique (private) space
-- FC00::/7
-- 334965454937798799971759379190646833152

-- RFC 1918 space
insert into netblock
	(IP_UNIVERSE_ID, IP_ADDRESS, IS_SINGLE_ADDRESS, NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION, CAN_SUBNET)
values
	((select ip_universe_id from ip_universe where ip_universe_name = 'private'), 'FC00::/7', 'N', 'Allocated', 'default', 'RFC4193 IPV6 Block', 'Y'),
	((select ip_universe_id from ip_universe where ip_universe_name = 'private'), '10.0.0.0/8', 'N', 'Allocated', 'default', 'RFC1918 Space', 'Y'),
	((select ip_universe_id from ip_universe where ip_universe_name = 'private'), '192.168.0.0/16', 'N', 'Allocated', 'default', 'RFC1918 Space', 'Y'),
	((select ip_universe_id from ip_universe where ip_universe_name = 'private'), '172.16.0.0/12', 'N', 'Allocated', 'default', 'RFC1918 Space', 'Y');
