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
-- Example Items that may be used for a real life instantiation of the system
-- You probably do NOT want to 

insert into account_realm(account_realm_name) values ('Omniscient');

insert into company (company_name, is_corporate_family)
	values ('Omniscient Technologies', 'Y');

insert into company (company_name, is_corporate_family, parent_company_id)
	select 'Sucksless Industries', 'Y', company_id
	from company
	where company_name = 'Omniscient Technologies'
;

insert into company_type (company_id, company_type)
select company_id, 'corporate family'
  from company
where	company_name = 'Omniscient'
  and	is_corporate_family = 'Y';

insert into company_type (company_id, company_type)
select company_id, 'corporate family'
  from company
where	company_name = 'Sucksless Industries'
  and	is_corporate_family = 'Y';

insert into property (
	property_name, property_type, 
	property_value_company_id
) VALUES  (
	'_rootcompanyid', 'Defaults', 
	(select company_id from company where company_name = 'Omniscient Technologies')
 );

insert into property (
	property_name, property_type, 
	account_realm_id
) VALUES  (
	'_root_account_realm_id', 'Defaults',
	(select account_realm_id 
	from account_realm where account_realm_name = 'Omniscient')
);


insert into account_realm_company (
	account_realm_id, 
	company_id
) values (
	(select account_realm_id from account_realm 
		where account_realm_name = 'Omniscient'),
	(select company_id from company 
		where company_name = 'Omniscient Technologies')
);

insert into account_realm_company (
	account_realm_id, 
	company_id
) values (
	(select account_realm_id from account_realm 
		where account_realm_name = 'Omniscient'),
	(select company_id from company 
		where company_name = 'Sucksless Industries')
);

/*   These now go in SITE

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

*/

INSERT INTO Kerberos_Realm (Realm_Name) VALUES ('OMNISCIENT.COM');

insert into site (site_code, colo_company_id, site_status, description)
	values ('CORP0', 0, 'ACTIVE', 'Corporate Headquarters');

insert into rack (
	SITE_CODE, ROOM, SUB_ROOM, RACK_ROW, RACK_NAME, RACK_HEIGHT_IN_U,
	RACK_STYLE, DISPLAY_FROM_BOTTOM
) values (
	'CORP0', 'DC-A', 'CAGE 1', '1', '1', 50,
	'CABINET', 'Y'
);

insert into rack (
	SITE_CODE, ROOM, SUB_ROOM, RACK_ROW, RACK_NAME, RACK_HEIGHT_IN_U,
	RACK_STYLE, DISPLAY_FROM_BOTTOM
) values (
	'CORP0', 'DC-A', 'CAGE 1', '1', '2', 50,
	'RELAY', 'Y'
);

insert into site (site_code, colo_company_id, site_status, description)
	values ('CZ0', 0, 'ACTIVE', 'Czech Satellite Office');

-- 334969971398294010747267358593998913536
insert into  netblock (ip_address, is_single_address, netblock_status, 
	description, netblock_type, parent_netblock_id, can_subnet) values
('FC00:DEAD:BEEF::/48', 'N', 'Allocated', 
	'Test Block 1', 'default', (select netblock_id from netblock where ip_address = 'fc00::/7'), 'Y');

-- 334969971398294010747267358593998913536
insert into  netblock (ip_address, is_single_address, netblock_status, description, netblock_type, parent_netblock_id, can_subnet) values
        ('fc00:dead:beef::/64', 'N', 'Allocated', 'Test Block 2', 'default', (select netblock_id from netblock where ip_address = 'FC00:DEAD:BEEF::/48'), 'N');
-- 334969971398294010931734799331094429696
insert into  netblock (ip_address, is_single_address, netblock_status, description, netblock_type, parent_netblock_id, can_subnet) values
        ('fc00:dead:beef:a::/64', 'N', 'Allocated', 'Test Block 3', 'default', (select netblock_id from netblock where ip_address = 'FC00:DEAD:BEEF::/48'), 'N');

--	++	-- 334969971398294010931734799331094429697
--	++	insert into  netblock (ip_address, is_single_address, netblock_status, description, netblock_type, parent_netblock_id) values
--	++	        ('fc00:dead:beef:a::1/64', 'Y', 'Reserved', 'test address 1', 'default', (select netblock_id from netblock where ip_address = 'FC00:DEAD:BEEF:a::/64));
--	++	-- 334969971398294010931734799331094429698
--	++	insert into  netblock (ip_address, is_single_address, netblock_status, description, netblock_type, parent_netblock_id) values
--	++	        ('fc00:dead:beef:a::2/64', 'Y', 'Reserved', 'test address 2', 'default', (select netblock_id from netblock where ip_address = 'FC00:DEAD:BEEF:a::/64));
--	++	-- 334969971398294010931734799331094429705
--	++	insert into  netblock (ip_address, is_single_address, netblock_status, description, netblock_type, parent_netblock_id) values
--	++	        ('fc00:dead:beef:a::9/64', 'Y', 'Reserved', 'test address 3', 'default', (select netblock_id from netblock where ip_address = 'FC00:DEAD:BEEF:a::/64));
--	++	-- 334969971398294010931734799331094429999
--	++	insert into  netblock (ip_address, is_single_address, netblock_status, description, netblock_type, parent_netblock_id) values
--	++	        ('fc00:dead:beef:a::12f/64', 'Y', 'Reserved', 'test address 4', 'default', (select netblock_id from netblock where ip_address = 'FC00:DEAD:BEEF:a::/64));
--	++	-- 334969971398294010931734799331094500000
--	++	insert into  netblock (ip_address, is_single_address, netblock_status, description, netblock_type, parent_netblock_id) values
--	++	        ('fc00:dead:beef:a::1:12a0/64', 'Y', 'Reserved', 'test address 5', 'default', (select netblock_id from netblock where ip_address = 'FC00:DEAD:BEEF:a::/64));

--
-- This stuff will probably go away
--
insert into device_collection 
	(DEVICE_COLLECTION_NAME, DEVICE_COLLECTION_TYPE)
values
	('cots1', 'applicense');
insert into device_collection 
	(DEVICE_COLLECTION_NAME, DEVICE_COLLECTION_TYPE)
values
	('cots2', 'applicense');

--- 
-- add some example user data
--


--- deal with system wide default

-- insert test user - kovert
insert into person (first_name, middle_name, last_name, gender)
	values ('Todd', 'M', 'Kover', 'M');

insert into person_company (company_id, person_id, 
	employee_id, is_exempt,
	person_company_status, person_company_relation
	) 
values(
	(select company_id from company 
		where company_name = 'Omniscient Technologies'),
	(select person_id from person where first_name = 'Todd' and
		last_name = 'Kover'),
	10, 'Y',
	'enabled', 'employee'
);

insert into person_account_realm_company (
	person_id,
	account_realm_id,
	company_id
) values (
	(select person_id from person 
		where last_name = 'Kover'),
	(select account_realm_id from account_realm 
		where account_realm_name = 'Omniscient'),
	(select company_id from company 
		where company_name = 'Omniscient Technologies')
);

insert into account (login, person_id, account_realm_id, company_id,
	account_status, account_type, account_role)
values ('kovert', 
	(select person_id from person where first_name = 'Todd'
		and last_name = 'Kover'), 
	(select account_realm_id from account_realm where 
		account_realm_name = 'Omniscient'),
	(select company_id from company 
		where company_name = 'Omniscient Technologies'),
	'enabled', 'person', 'primary'
);

-- insert test user - mdr
insert into person (first_name, middle_name, last_name, gender)
	values ('Matthew', 'D', 'Ragan', 'M');

insert into person_company (company_id, person_id, 
	employee_id, is_exempt,
	person_company_status, person_company_relation
	) 
values(
	(select company_id from company where company_name = 'Sucksless Industries'),
	(select person_id from person where first_name = 'Matthew' and
		last_name = 'Ragan'),
	5, 'Y',
	'enabled', 'employee'
);

insert into person_account_realm_company (
	person_id,
	account_realm_id,
	company_id
) values (
	(select person_id from person 
		where last_name = 'Ragan'),
	(select account_realm_id from account_realm 
		where account_realm_name = 'Omniscient'),
	(select company_id from company 
		where company_name = 'Sucksless Industries')
);

insert into account (login, person_id, account_realm_id, company_id,
	account_status, account_type, account_role)
values ('mdr', 
	(select person_id from person where first_name = 'Matthew'
		and last_name = 'Ragan'), 
	(select account_realm_id from account_realm where 
		account_realm_name = 'Omniscient'),
	(select company_id from company 
		where company_name = 'Sucksless Industries'),
	'enabled', 'person', 'primary'
);


-- insert characteristics about directory (should perhaps fold into default)
insert into val_person_image_usage (
        person_image_usage, is_multivalue
) values (
        'headshot', 'N'
);


insert into val_person_image_usage (
	person_image_usage, is_multivalue
) values (
	'yearbook', 'N'
);

-- token testing (needs to be fleshed out)
insert into val_token_collection_type (
	token_collection_type
) values (
	'default'
);

insert into token_collection (
	token_collection_name,
	token_collection_type
) values (
	'test',
	'default'
);


--
insert into account_realm_password_type (
	account_realm_id, password_type)
values (
	0, 'des'
);

INSERT INTO Account_Password (
	Account_Id,
	Password_type,
	Password,
	Change_Time
) VALUES (
	(select account_Id from account where login = 'root'),
	'des',
	'T6r7sdlVHpZH2',
	now()
);

