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
	INSERT INTO service_source_repository (service_id, source_repository)
	SELECT service_id, 'git@github.com:JazzHandsCMDB/jazzhands'
	FROM svc
	RETURNING *
), svcv AS (
	INSERT INTO service_version 
		(service_id, version_name, software_tag, software_repository_id)
	SELECT service_id, '0.64', '0.64', software_repository_id
	FROM svc, software_repository
	WHERE software_repository_name = 'common'
	RETURNING *
), svcinst AS (
	INSERT INTO service_instance (
		device_id, service_endpoint_id, service_version_id
	) SELECT
		device_id, service_endpoint_id, service_version_id
	FROM device, endpoint, svcv
	WHERE device_name ~ '^\d+\.jazzhands-db\..*$'
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
