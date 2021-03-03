insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION, CAN_SUBNET)
values
	('198.18.9.0/25', false,
	'Allocated', 'default', 'Omniscient Technologies VA Routable Block', true);

insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION, 
	 PARENT_NETBLOCK_ID, CAN_SUBNET)
values
	('198.18.9.0/26', false,
	'Allocated', 'default', 'Omniscient Technologies Server Block', 
	(select netblock_id from netblock where
		ip_address = '198.18.9.0/25'), false
);

insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION, CAN_SUBNET)
values
	('172.25.64.0/20', false,
	'Allocated', 'default', 'Czech Public Network', true);

insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION,
	 PARENT_NETBLOCK_ID, CAN_SUBNET)
values
	('172.25.64.0/24', false,
	'Allocated', 'default', 'Omniscient Čerčany CZ',
	(select netblock_id from netblock where
		ip_address = net_manip.inet_ptodb('172.25.64.0', 20)),
	true
);

insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION,
	 PARENT_NETBLOCK_ID, CAN_SUBNET)
values
	('172.25.64.0/26', false,
	'Allocated', 'default', 'Server Network',
	(select netblock_id from netblock where
		ip_address = net_manip.inet_ptodb('172.25.64.0', 24)), false
);

insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION,
	 PARENT_NETBLOCK_ID, CAN_SUBNET)
values
	('172.25.64.64/26', false,
	'Allocated', 'default', 'Desktop Network',
	(select netblock_id from netblock where
		ip_address = net_manip.inet_ptodb('172.25.64.0', 24)), false
);

insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION,
	 PARENT_NETBLOCK_ID, CAN_SUBNET)
values
	('172.25.64.128/27', false,
	'Allocated', 'default', 'Wireless Network',
	(select netblock_id from netblock where
		ip_address = net_manip.inet_ptodb('172.25.64.0', 24)), true
);

insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION,
	 PARENT_NETBLOCK_ID, CAN_SUBNET)
values
	('172.25.64.224/27', false,
	'Allocated', 'default', 'Infrastructure',
	(select netblock_id from netblock where
		ip_address = net_manip.inet_ptodb('172.25.64.0', 24)), true
);

insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION,
	 PARENT_NETBLOCK_ID, CAN_SUBNET)
values
	('172.25.65.0/24', false,
	'Allocated', 'default', 'Omniscient Purcellville, VA',
	(select netblock_id from netblock where
		ip_address = net_manip.inet_ptodb('172.25.64.0', 20)), true
);

INSERT INTO Kerberos_Realm (Realm_Name) VALUES ('OMNISCIENT.COM');
INSERT INTO Kerberos_Realm (Realm_Name) VALUES ('SUCKSLESS.NET');


insert into site_netblock (site_code, netblock_id)
        values ('CORP0', 
	(select netblock_id from netblock where ip_address =
		net_manip.inet_ptodb('172.25.65.0', 24))
	);
insert into site_netblock (site_code, netblock_id)
        values ('CORP0', 
	(select netblock_id from netblock where ip_address =
		net_manip.inet_ptodb('198.18.9.0', 25) )
	);


insert into site_netblock (site_code, netblock_id)
        values ('CZ0', 
	(select netblock_id from netblock where ip_address =
		net_manip.inet_ptodb('172.25.64.0', 24))
	);

insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION, CAN_SUBNET)
values
	('192.18.244.128/25', false,
	'Allocated', 'default', 'Old VA Public Block', true);

insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION, CAN_SUBNET)
values
	('192.19.49.16/30', false,
	'Allocated', 'default', 'Omniscient VA Level 3 /30', true);

insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION, CAN_SUBNET)
values
	('192.19.49.20/30', false,
	'Allocated', 'default', 'Omniscient VA Level 3 LAN /30', true);

insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION, CAN_SUBNET)
values
	('198.18.165.0/24', false,
	'Allocated', 'default', '', true);

-- rfc3849
insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION, CAN_SUBNET)
values
	('2001:db8:2100::25C/126', false,
	'Allocated', 'default', 'IPv6 WAN Omniscient VA', false);


insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION, CAN_SUBNET)
values
	('2001:db8:2209::/48', false,
	'Allocated', 'default', 'IPv6 LAN Omniscient VA', true);


insert into netblock
	(IP_ADDRESS, IS_SINGLE_ADDRESS,
	 NETBLOCK_STATUS, NETBLOCK_TYPE, DESCRIPTION, CAN_SUBNET)
values
	('2001:db8:2012::/48', false,
	'Allocated', 'default', 'IPv6 Legacy LAN Omniscient VA', true);

