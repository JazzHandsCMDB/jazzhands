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

insert into company (company_name, is_corporate_family)
	values ('Omniscient Technologies', 'Y');
insert into company (company_name, is_corporate_family)
	values ('Sucksless Industries', 'Y');

INSERT INTO VAL_Office_Site(Office_Site, Description,SITE_RANK,COMPANY_ID)
	VALUES ('Virginia', 'Purcellville, VA',0,
	(select company_id from company where company_name =
		'Omniscient Technologies'));
INSERT INTO VAL_Office_Site(Office_Site, Description,SITE_RANK,COMPANY_ID)
	VALUES ('Austin', 'Austin, TX', 0,
	(select company_id from company where company_name =
		'Sucksless Industries'));
INSERT INTO VAL_Office_Site(Office_Site, Description,SITE_RANK,COMPANY_ID)
	VALUES ('Čerčany', 'Cercany, Czech Republic', 1,
	(select company_id from company where company_name =
		'Omniscient Technologies'));
INSERT INTO VAL_Office_Site(Office_Site, Description,SITE_RANK,COMPANY_ID)
	VALUES ('Strančice', 'Strancice, Czech Republic', 2,
	(select company_id from company where company_name =
	'Omniscient Technologies'));

INSERT INTO Kerberos_Realm (Realm_Name) VALUES ('MIT.EDU');

insert into site (site_code, colo_partner_id, site_status, description)
	values ('CORP0', 0, 'ACTIVE', 'Corporate Headquarters');

insert into rack (
	SITE_CODE, ROOM, SUB_ROOM, RACK_ROW, RACK_NAME, RACK_HEIGHT_IN_U,
	RACK_TYPE, DISPLAY_FROM_BOTTOM
) values (
	'CORP0', 'DC-A', 'CAGE 1', '1', '1', 50,
	'CABINET', 'Y'
);

insert into rack (
	SITE_CODE, ROOM, SUB_ROOM, RACK_ROW, RACK_NAME, RACK_HEIGHT_IN_U,
	RACK_TYPE, DISPLAY_FROM_BOTTOM
) values (
	'CORP0', 'DC-A', 'CAGE 1', '1', '2', 50,
	'RELAY', 'Y'
);

insert into site (site_code, colo_partner_id, site_status, description)
	values ('CZ0', 0, 'ACTIVE', 'Czech Satellite Office');

-- FC00::/7
-- 334965454937798799971759379190646833152
insert into  netblock (ip_address, netmask_bits, is_ipv4_address, is_single_address, netblock_status, description, is_organizational, parent_netblock_id) values
        (net_manip.inet_ptodb('FC00::'), 7, 'N', 'N', 'Allocated', 'RFC4193 IPV6 Block', 'N', null);

-- 334969971398294010747267358593998913536
insert into  netblock (ip_address, netmask_bits, is_ipv4_address, is_single_address, netblock_status, description, is_organizational, parent_netblock_id) values
        (net_manip.inet_ptodb('FC00:DEAD:BEEF::'), 48, 'N', 'N', 'Allocated', 'Test Block 1', 'N', (select netblock_id from netblock where ip_address = net_manip.inet_ptodb('fc00::') and netmask_bits = 7));

-- 334969971398294010747267358593998913536
insert into  netblock (ip_address, netmask_bits, is_ipv4_address, is_single_address, netblock_status, description, is_organizational, parent_netblock_id) values
        (net_manip.inet_ptodb('fc00:dead:beef::'), 64, 'N', 'N', 'Allocated', 'Test Block 2', 'N', (select netblock_id from netblock where ip_address = net_manip.inet_ptodb('FC00:DEAD:BEEF::') and netmask_bits = 48));
-- 334969971398294010931734799331094429696
insert into  netblock (ip_address, netmask_bits, is_ipv4_address, is_single_address, netblock_status, description, is_organizational, parent_netblock_id) values
        (net_manip.inet_ptodb('fc00:dead:beef:a::'), 64, 'N', 'N', 'Allocated', 'Test Block 3', 'N', (select netblock_id from netblock where ip_address = net_manip.inet_ptodb('FC00:DEAD:BEEF::') and netmask_bits = 48));

--	++	-- 334969971398294010931734799331094429697
--	++	insert into  netblock (ip_address, netmask_bits, is_ipv4_address, is_single_address, netblock_status, description, is_organizational, parent_netblock_id) values
--	++	        (net_manip.inet_ptodb('fc00:dead:beef:a::1'), 64, 'N', 'Y', 'Reserved', 'test address 1', 'N', (select netblock_id from netblock where ip_address = net_manip.inet_ptodb('FC00:DEAD:BEEF:a::') and netmask_bits = 64));
--	++	-- 334969971398294010931734799331094429698
--	++	insert into  netblock (ip_address, netmask_bits, is_ipv4_address, is_single_address, netblock_status, description, is_organizational, parent_netblock_id) values
--	++	        (net_manip.inet_ptodb('fc00:dead:beef:a::2'), 64, 'N', 'Y', 'Reserved', 'test address 2', 'N', (select netblock_id from netblock where ip_address = net_manip.inet_ptodb('FC00:DEAD:BEEF:a::') and netmask_bits = 64));
--	++	-- 334969971398294010931734799331094429705
--	++	insert into  netblock (ip_address, netmask_bits, is_ipv4_address, is_single_address, netblock_status, description, is_organizational, parent_netblock_id) values
--	++	        (net_manip.inet_ptodb('fc00:dead:beef:a::9'), 64, 'N', 'Y', 'Reserved', 'test address 3', 'N', (select netblock_id from netblock where ip_address = net_manip.inet_ptodb('FC00:DEAD:BEEF:a::') and netmask_bits = 64));
--	++	-- 334969971398294010931734799331094429999
--	++	insert into  netblock (ip_address, netmask_bits, is_ipv4_address, is_single_address, netblock_status, description, is_organizational, parent_netblock_id) values
--	++	        (net_manip.inet_ptodb('fc00:dead:beef:a::12f)', 64, 'N', 'Y', 'Reserved', 'test address 4', 'N', (select netblock_id from netblock where ip_address = net_manip.inet_ptodb('FC00:DEAD:BEEF:a::') and netmask_bits = 64));
--	++	-- 334969971398294010931734799331094500000
--	++	insert into  netblock (ip_address, netmask_bits, is_ipv4_address, is_single_address, netblock_status, description, is_organizational, parent_netblock_id) values
--	++	        (net_manip.inet_ptodb('fc00:dead:beef:a::1:12a0)', 64, 'N', 'Y', 'Reserved', 'test address 5', 'N', (select netblock_id from netblock where ip_address = net_manip.inet_ptodb('FC00:DEAD:BEEF:a::') and netmask_bits = 64));

insert into device_collection 
	(name, DEVICE_COLLECTION_TYPE, SHOULD_GENERATE_SUDOERS)
values
	('cots1', 'applicense', 'N');
insert into device_collection 
	(name, DEVICE_COLLECTION_TYPE, SHOULD_GENERATE_SUDOERS)
values
	('cots2', 'applicense', 'N');
