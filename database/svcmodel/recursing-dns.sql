--
-- This will insert both a udp and tcp endpoint
--
--

INSERT INTO service (service_name) VALUES ('dns-recurse');

WITH swpkg AS (
	INSERT INTO sw_package (
		sw_package_name, sw_package_type
	) VALUES (
		'jazzhands-stab', 'rpm'
	) RETURNING *
), snb AS (
	INSERT INTO shared_netblock_collection (
		shared_netblock_collection_name, shared_netblock_collection_type
	) VALUES (
		'intdns-nym2', 'ecmp'
	) RETURNING *
), snbnb AS (
	INSERT INTO shared_netblock_coll_netblock (
		shared_netblock_collection_id, shared_netblock_id
	) SELECT shared_netblock_collection_id, shared_netblock_id
	FROM snb, shared_netblock
		JOIN netblock USING (netblock_id)
	WHERE host(ip_address) = '68.67.163.255'
	RETURNING *
),  endpoint AS (
	INSERT INTO service_endpoint (
		dns_record_id, uri, port_range_id
	) SELECT dns_record_id,
		concat('dns',p.protocol,'://',
			dns_name, '.',soa_name,'/'), port_range_id
	FROM ( SELECT * fROM  dns_record join dns_domain using (dns_domain_id)
		where dns_name ~ 'intdnsrecurse00' order by dns_domain_id  LIMIT 1) d,
		(SELECT unnest(ARRAY['udp','tcp']) as protocol) p,
		port_range pr
	WHERE pr.port_range_name = 'domain' and pr.protocol = p.protocol
	RETURNING *
), endsla AS (
	INSERT INTO service_endpoint_service_sla (
		service_endpoint_id, service_sla_id, service_environment_id
	) SELECT
		service_endpoint_id, service_sla_id, service_environment_id
	FROM endpoint, service_sla, service_environment
	WHERE service_environment_name = 'production'
	AND production_state = 'production'
	AND service_sla_name = 'always'
	RETURNING *
), svc AS (
	SELECT * FROM service WHERE service_name = 'dns-recurse'
), svcv AS (
	INSERT INTO service_version
		(service_id, service_type, version_name)
	SELECT service_id, 'network', '1.0.2'
	FROM svc
	RETURNING *
), svcinst AS (
	INSERT INTO service_instance (
		device_id, service_endpoint_id, service_version_id,port_range_id,
		netblock_id
	) SELECT
		device_id, service_endpoint_id, service_version_id,p.port_range_id,
		netblock_id
	FROM device
			JOIN network_interface USING (device_id),
		endpoint, svcv, port_range p
	WHERE device_name ~ '^(01|02)\.(newdns|dns-recurse)\..*$'
	AND site_code = upper(regexp_replace(endpoint.uri, '^.*\.([a-z]+[0-9])\.appnexus.net.*$', '\1'))
	AND p.port_range_name IN ('domain') AND p.port_range_type = 'services'
	-- XXX need to create an enedpoint for tcp, too
	AND endpoint.uri ~ concat('dns', p.protocol)
	AND netblock_id is not NULL
	RETURNING *
), svcendpointprovider AS (
	INSERT INTO service_endpoint_provider (
		service_endpoint_provider_name, service_endpoint_provider_type,
		service_endpoint_id, shared_netblock_collection_id
	) SELECT 'nym2-recursedns-' || service_endpoint_id, 'ecmp',
		service_endpoint_id, shared_netblock_collection_id
	FROM  endpoint, snb
	RETURNING *
), svcendpointmember AS (
	INSERT INTO service_endpoint_provider_member (
		service_endpoint_provider_id, service_instance_id
	) SELECT service_endpoint_provider_id, service_instance_id
	FROM svcendpointprovider, svcinst
	RETURNING *
), svccol AS (
	select sc.*
	FROM service_collection sc
		JOIN svc s ON s.service_name = sc.service_collection_name
	WHERE service_collection_type = 'all-services'
), svcprop1 AS (
	INSERT INTO service_property (
		service_collection_id, service_property_name, service_property_type, value
	) values
		((SELECT service_collection_id FROM svccol), 'location', 'launch', 'vm'),
		((SELECT service_collection_id FROM svccol), 'location', 'launch', 'baremetal'),
		((SELECT service_collection_id FROM svccol), 'min_cpu', 'launch', '4'),
		((SELECT service_collection_id FROM svccol), 'min_disk', 'launch', '20gb'),
		((SELECT service_collection_id FROM svccol), 'min_mem', 'launch', '4gb'),
		((SELECT service_collection_id FROM svccol), 'manual', 'docs', 'https://docs.example.com/?stab')
	RETURNING *
), svcprop2 AS (
	INSERT INTO service_property (
		service_collection_id, service_property_name, service_property_type,
			value_layer3_network_collection_id
	) SELECT service_collection_id, 'launch-nets', 'launch', layer2_network_collection_id
	FROM layer2_network_collection, svccol
	WHERE layer2_network_collection_name = 'dmz-nets'
	AND layer2_network_collection_type = 'service'
	RETURNING *
), svcprop3 AS (
	INSERT INTO service_property (
		service_collection_id, service_property_name, service_property_type,
			value_layer3_network_collection_id
	) SELECT service_collection_id, 'service-nets', 'launch', layer2_network_collection_id
	FROM layer2_network_collection, svccol
	WHERE layer2_network_collection_name = 'dmz-nets'
	AND layer2_network_collection_type = 'service'
	RETURNING *
) SELECT * from svccol;
