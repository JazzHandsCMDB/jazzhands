insert into device (device_type_id, device_name, device_status, 
	service_environment_id, 
	operating_system_id, 
	is_locally_managed, is_monitored, is_virtual_device, 
	should_Fetch_config)
values
	(1, 'guinness.omniscient.com', 'up', 
	(select service_environment_id from service_environment where
		service_environment_name = 'production'),
	0, 
	'Y', 'Y', 'N', 'Y')
;

insert into dns_domain
	(soa_name, soa_rname, should_generate, dns_domain_type)
values
	('omniscient.com', 'hostmaster.omniscient.com', 'Y', 'service')
;

insert into dns_domain
	(soa_name, soa_rname, should_generate, dns_domain_type)
values
	('kover.com', 'hostmaster.omniscient.com', 'Y', 'service')
;
insert into dns_domain
	(soa_name, soa_rname, should_generate, dns_domain_type)
values
	('jazzhands.net', 'hostmaster.omniscient.com', 'Y', 'service')
;

insert into physical_port
	(device_id, port_name, port_type)
select	device_id, 'bge0', 'network'
  from	device where device_name = 'guinness.omniscient.com';

insert into netblock
	(ip_address, is_single_address,
		can_subnet, parent_netblock_id, netblock_status,
		netblock_type)
	select '198.18.9.5/26', 'Y',
	 	'N', netblock_id, 'Allocated',
	 	'default'
	from netblock where ip_address = '198.18.9.0/26'
		and is_single_address = 'N'
;

insert into network_interface
	(device_id, network_interface_name, physical_port_id, 
		network_interface_type,
		is_interface_up, mac_addr, 
		should_monitor, provides_nat, should_manage, 
		provides_dhcp,
		netblock_id
	)
	select device_id, 'bge0', physical_port_id, 'broadcast',
		'Y', 'aa:bb:cc:dd:ee:ff',
		'Y', 'N', 'Y',
		'N', 
		(select netblock_id from netblock where
			ip_address = '198.18.9.5/26')
	from physical_port 
	where port_name = 'bge0'
	and device_id in (select device_id from device
		where device_name = 'guinness.omniscient.com')
;

insert into dns_record
	(dns_name, dns_domain_id, dns_class, dns_type, netblock_id)
values ('guinness',
	 (select dns_domain_id from dns_domain 
		where soa_name='omniscient.com'),
	 'IN',
	 'A',
	(select netblock_id from netblock
		where ip_address = net_manip.inet_ptodb('198.18.9.5', 26))
);

