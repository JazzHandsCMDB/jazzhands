INSERT INTO service (service_name) VALUES ('stab');


WITH swpkg AS (
	INSERT INTO sw_package (
		sw_package_name, sw_package_type
	) VALUES (
		'jazzhands-stab', 'rpm'
	) RETURNING *
),  endpoint AS (
	INSERT INTO service_endpoint (
		dns_record_id, uri
	) SELECT dns_record_id, concat('https://', dns_name, '.',soa_name,'/')
	FROM dns_record join dns_domain using (dns_domain_id)
	where dns_name = 'stab' order by dns_domain_id limit 1
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
	SELECT * FROM service WHERE service_name = 'stab'
), src AS (
	INSERT INTO service_source_repository (service_id, source_repository)
	SELECT service_id, 'git@github.com:JazzHandsCMDB/jazzhands'
	FROM svc
	RETURNING *
), svcv AS (
	INSERT INTO service_version 
		(service_id, version_name, software_tag, software_repository_id)
	SELECT service_id, '0.64.8', '0.64.8', software_repository_id
	FROM svc, software_repository
	WHERE software_repository_name = 'common'
	RETURNING *
), svcinst AS (
	INSERT INTO service_instance (
		device_id, service_endpoint_id, service_version_id
	) SELECT
		device_id, service_endpoint_id, service_version_id
	FROM device, endpoint, svcv
	WHERE device_name ~ '^\d+\.stab\..*$'
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
	) SELECT service_collection_id, 'launch-nets', 'launch', netblock_collection_id
	FROM netblock_collection,svccol
	WHERE netblock_collection_name = 'rfc1918-nets'
	AND netblock_collection_type = 'ad-hoc'
	RETURNING *
), svcprop2a AS (
	INSERT INTO service_property (
		service_collection_id, service_property_name, service_property_type, 
			value_layer3_network_collection_id
	) SELECT service_collection_id, 'service-nets', 'launch', layer2_network_collection_id
	FROM layer2_network_collection,svccol
	WHERE layer2_network_collection_name = 'dmz-nets'
	AND layer2_network_collection_type = 'service'
	RETURNING *
), svcprop_admin AS (
	INSERT INTO service_property (
		service_collection_id, service_property_name, service_property_type, 
			value_account_collection_id
	) SELECT service_collection_id, 'admin', 'role', account_collection_id
	FROM account_collection,svccol
	WHERE account_collection_name = 'stab_full_admin'
	AND account_collection_type = 'systems'
	RETURNING *
), svcprop_owner AS (
	INSERT INTO service_property (
		service_collection_id, service_property_name, service_property_type, 
			value_account_collection_id
	) SELECT service_collection_id, 'owner', 'role', account_collection_id
	FROM account_collection,svccol
	WHERE account_collection_name ~ 'Core Sys Infr'
	AND account_collection_type = 'department'
	RETURNING *

), svcprop4 AS (
	INSERT INTO service_property (
		service_collection_id, service_property_name, service_property_type, 
			value_account_collection_id
	) SELECT service_collection_id, 'log_watcher', 'role', account_collection_id
	FROM account_collection,svccol
	WHERE account_collection_name = 'stab_all_access'
	AND account_collection_type = 'systems'
	RETURNING *
), svcprop5 AS (
	INSERT INTO service_property (
		service_collection_id, service_property_name, service_property_type, 
			value_sw_package_id
	) SELECT service_collection_id, 'software', 'pkg', sw_package_id
	FROM swpkg,svccol
	RETURNING *
), svcdep AS (
	INSERT INTO service_depend (
		service_version_id, service_id, service_sla_id
	) SELECT
		v.service_version_id, s.service_id, a.service_sla_id
	FROM svcv v, service s, service_sla a
	WHERE s.service_name = 'jazzhands-db'
	AND a.service_sla_name = 'always'
) select * from svccol;

