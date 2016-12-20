WITH swpkg AS (
	INSERT INTO sw_package (
		sw_package_name, sw_package_type
	) VALUES (
		'jazzhands-stab', 'rpm'
	) RETURNING *
),  endpoint AS (
	INSERT INTO service_endpoint (
		dns_record_id, uri
	) SELECT dns_record_id, concat('dns://', dns_name, '.',soa_name,'/')
	FROM dns_record join dns_domain using (dns_domain_id)
	where dns_name ~ 'newdns|dns-recurse' order by dns_domain_id limit 1
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
	INSERT INTO service (service_name)
	VALUES ('dns-recurse')
	RETURNING *
), svcv AS (
	INSERT INTO service_version 
		(service_id, version_name)
	SELECT service_id, '1.0.2'
	FROM svc
	RETURNING *
), svcinst AS (
	INSERT INTO service_instance (
		device_id, service_endpoint_id, service_version_id
	) SELECT
		device_id, service_endpoint_id, service_version_id
	FROM device, endpoint, svcv
	WHERE device_name ~ '^\d+\.(newdns|dns-recurse)\..*$'
	RETURNING *
), svcprop1 AS (
	INSERT INTO service_property (
		service_property_name, service_property_type, value
	) values 
		('location', 'launch', 'vm'),
		('location', 'launch', 'baremetal'),
		('min_cpu', 'launch', '4'),
		('min_disk', 'launch', '20gb'),
		('min_mem', 'launch', '4gb'),
		('manual', 'docs', 'https://docs.example.com/?stab')
	RETURNING *
), svcprop2 AS (
	INSERT INTO service_property (
		service_property_name, service_property_type, 
			value_layer3_network_collection_id
	) SELECT 'launch-nets', 'launch', layer2_network_collection_id
	FROM layer2_network_collection
	WHERE layer2_network_collection_name = 'dmz-nets'
	AND layer2_network_collection_type = 'service'
	RETURNING *
), svcprop3 AS (
	INSERT INTO service_property (
		service_property_name, service_property_type, 
			value_layer3_network_collection_id
	) SELECT 'service-nets', 'launch', layer2_network_collection_id
	FROM layer2_network_collection
	WHERE layer2_network_collection_name = 'dmz-nets'
	AND layer2_network_collection_type = 'service'
	RETURNING *
), svcprop AS ( 
	select * from svcprop3 UNION
	select * from svcprop2 UNION
	select * from svcprop1
), svsp AS (
	INSERT INTO service_version_service_property (
		service_version_id, service_property_id
	) SELECT service_version_id, service_property_id
	FROM svcv, svcprop
	RETURNING *
) SELECT * from svsp;
