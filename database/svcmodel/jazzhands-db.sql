INSERT INTO service (service_name) VALUES ('jazzhands-db');

WITH endpoint AS (
	INSERT INTO service_endpoint (
		dns_record_id, uri
	) SELECT dns_record_id, concat('psql://', dns_name, '.',soa_name,'/')
	FROM dns_record join dns_domain using (dns_domain_id)
	where dns_name = 'jazzhands-db' order by dns_domain_id limit 1
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
	SELECT * FROM service where service_name = 'jazzhands-db'
), src AS (
	INSERT INTO source_repository (
		source_repository_name, source_repository_type,
		source_repository_technology, source_repository_url
	) VALUES (
		'jazzhands', 'software',
		'git', 'git@github.com:JazzHandsCMDB/jazzhands'
	) RETURNING *
), srcrepo AS (
	INSERT INTO service_source_repository (
		service_id, source_repository_id, source_repository_path
	) SELECT service_id, source_repository_id, 'database'
	FROM svc,src
	RETURNING *
), svcv AS (
	INSERT INTO service_version
		(service_id, service_type, version_name)
	SELECT service_id, 'network', '0.64'
	FROM svc
	RETURNING *
), svcvsrc AS (
	INSERT INTO service_version_source_repository (
		service_version_id,source_repository_id,software_tag
	) SELECT service_version_id, source_repository_id,version_name
	FROM svcv, srcrepo
), svcswpkg AS (
	INSERT INTO service_version_sw_package_repository (
		service_version_id, sw_package_repository_id
	) SELECT service_version_id, sw_package_repository_id
	FROM svcv, sw_package_repository
	WHERE sw_package_repository_name = 'obs' 
	AND sw_package_repository_project = 'common'
), svcinst AS (
	INSERT INTO service_instance (
		device_id, service_endpoint_id, service_version_id,
		port_range_id, netblock_id
	) SELECT
		device_id, service_endpoint_id, service_version_id,
		p.port_range_id, nb.netblock_id
	FROM device, endpoint, svcv, port_range p, netblock nb
	WHERE device_name ~ '^\d+\.jazzhands-db\..*$'
	AND p.port_range_name IN ('postgresql')
	AND nb.netblock_type = 'default' AND host(nb.ip_address) = '10.1.32.62'
	RETURNING *
), svcendpointprovider AS (
	INSERT INTO service_endpoint_provider (
		service_endpoint_provider_name, service_endpoint_provider_type,
		service_endpoint_id, netblock_id
	) SELECT 'jazzhands-db', 'direct', service_endpoint_id, netblock_id
	FROM  endpoint, netblock
	WHERE host(ip_address) = '10.1.32.62' and netblock_type = 'default'
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
		((SELECT service_collection_id FROM svccol), 'location', 'launch', 'baremetal'),
		((SELECT service_collection_id FROM svccol), 'min_cpu', 'launch', '4'),
		((SELECT service_collection_id FROM svccol), 'min_mem', 'launch', '32gb'),
		((SELECT service_collection_id FROM svccol), 'manual', 'docs', 'https://github.com/JazzHandsCMDB/jazzhands/tree/master/doc')
	RETURNING *
), svcprop2 AS (
	INSERT INTO service_property (
		service_collection_id, service_property_name, service_property_type,
			value_layer3_network_collection_id
	) SELECT service_collection_id, 'service-nets', 'launch', layer2_network_collection_id
	FROM layer2_network_collection, svccol
	WHERE layer2_network_collection_name = 'internal-nets'
	AND layer2_network_collection_type = 'service'
	RETURNING *
), svcprop3 AS (
	INSERT INTO service_property (
		service_collection_id, service_property_name, service_property_type,
			value_account_collection_id
	) SELECT service_collection_id, 'admin', 'role', account_collection_id
	FROM account_collection, svccol
	WHERE account_collection_name = 'drt_iud'
	AND account_collection_type = 'dbole'
	RETURNING *
), svcprop4 AS (
	INSERT INTO service_property (
		service_collection_id, service_property_name, service_property_type,
			value_account_collection_id
	) SELECT service_collection_id, 'iud_role', 'role', account_collection_id
	FROM account_collection,svccol
	WHERE account_collection_name = 'drt_iud'
	AND account_collection_type = 'dbrole'
	RETURNING *
) select * from svccol;

