INSERT INTO device (device_type_id, device_name, device_status,
	service_environment_id,
	operating_system_id, is_monitored, is_virtual_device
) VALUES
	(1, 'guinness.omniscient.com', 'up',
	(select service_environment_id from service_environment where
		service_environment_name = 'production'),
	0, 'Y', 'N')
;

INSERT INTO property
	(property_name, property_type, property_value)
VALUES
	('_dnsrname', 'Defaults', 'hostmaster.omniscient.com'),
	('_dnsmname', 'Defaults', 'auth00.omniscient.com');

SELECT dns_utils.add_dns_domain(dns_domain_name := 'omniscient.com', dns_domain_type := 'service');
SELECT dns_utils.add_dns_domain(dns_domain_name := 'kover.com', dns_domain_type := 'service');
SELECT dns_utils.add_dns_domain(dns_domain_name := 'jazzhands.net', dns_domain_type := 'service');

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

WITH ni AS (
insert into network_interface
	(device_id, network_interface_name, network_interface_type, mac_addr
	)
	select device_id, 'bge0', 'broadcast', 'aa:bb:cc:dd:ee:ff'
	from device
	where device_name = 'guinness.omniscient.com'
	RETURNING *
) INSERT INTO network_interface_netblock
	(network_interface_id, netblock_id)
SELECT network_interface_id, netblock_Id
FROM ni, netblock
WHERE ip_address = '198.18.9.5/26';


insert into dns_record
	(dns_name, dns_domain_id, dns_class, dns_type, netblock_id)
values ('guinness',
	 (select dns_domain_id from dns_domain
		where dns_domain_name='omniscient.com'),
	 'IN',
	 'A',
	(select netblock_id from netblock
		where ip_address = net_manip.inet_ptodb('198.18.9.5', 26))
);

