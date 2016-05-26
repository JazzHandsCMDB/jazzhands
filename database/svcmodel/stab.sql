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
	INSERT INTO service (service_name, software_repo)
	VALUES ('stab', 'git@github.com:JazzHandsCMDB/jazzhands')
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
			value_network_collection_id
	) SELECT 'launch-nets', 'launch', netblock_collection_id
	FROM netblock_collection
	WHERE netblock_collection_name = 'rfc1918-nets'
	AND netblock_collection_type = 'ad-hoc'
	RETURNING *
), svcprop3 AS (
	INSERT INTO service_property (
		service_property_name, service_property_type, 
			value_account_collection_id
	) SELECT 'admin', 'role', account_collection_id
	FROM account_collection
	WHERE account_collection_name = 'stab_full_admin'
	AND account_collection_type = 'systems'
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
			value_sw_package_id
	) SELECT 'software', 'pkg', sw_package_id
	FROM swpkg
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
), svcdep AS (
	INSERT INTO service_depend (
		service_version_id, service_id, service_sla_id
	) SELECT
		v.service_version_id, s.service_id, a.service_sla_id
	FROM svcv v, service s, service_sla a
	WHERE s.service_name = 'jazzhands-db'
	AND a.service_sla_name = 'always'
) select * from svsp;

