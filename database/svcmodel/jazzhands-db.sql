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
	INSERT INTO service (service_name)
	VALUES ('jazzhands-db')
	RETURNING *
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
), svcprop1 AS (
	INSERT INTO service_property (
		service_property_name, service_property_type, value
	) values 
		('location', 'launch', 'baremetal'),
		('min_cpu', 'launch', '4'),
		('min_mem', 'launch', '32gb'),
		('manual', 'docs', 'https://github.com/JazzHandsCMDB/jazzhands/tree/master/doc')
	RETURNING *
), svcprop2 AS (
	INSERT INTO service_property (
		service_property_name, service_property_type, 
			value_layer3_network_collection_id
	) SELECT 'service-nets', 'launch', layer2_network_collection_id
	FROM layer2_network_collection
	WHERE layer2_network_collection_name = 'internal-nets'
	AND layer2_network_collection_type = 'service'
	RETURNING *
), svcprop3 AS (
	INSERT INTO service_property (
		service_property_name, service_property_type, 
			value_account_collection_id
	) SELECT 'admin', 'role', account_collection_id
	FROM account_collection
	WHERE account_collection_name = 'drt_iud'
	AND account_collection_type = 'dbole'
	RETURNING *
), svcprop4 AS (
	INSERT INTO service_property (
		service_property_name, service_property_type, 
			value_account_collection_id
	) SELECT 'log_watcher', 'role', account_collection_id
	FROM account_collection
	WHERE account_collection_name = 'stab_all_access'
	AND account_collection_type = 'systems'
	RETURNING *
), svcprop5 AS (
	INSERT INTO service_property (
		service_property_name, service_property_type, 
			value_account_collection_id
	) SELECT 'iud_role', 'role', account_collection_id
	FROM account_collection
	WHERE account_collection_name = 'drt_iud'
	AND account_collection_type = 'dbrole'
	RETURNING *
), svcprop AS ( 
	select * from svcprop5 UNION 
	select * from svcprop4 UNION 
	select * from svcprop3 UNION
	select * from svcprop2 UNION
	select * from svcprop1
), svsp AS (
	INSERT INTO service_version_service_property (
		service_version_id, service_property_id
	) SELECT service_version_id, service_property_id
	FROM svcv, svcprop
	RETURNING *
) select * from svsp;

