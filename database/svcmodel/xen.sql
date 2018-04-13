INSERT INTO service (service_name) VALUES ('xen');

WITH  endpoint AS (
	INSERT INTO service_endpoint (
		uri
	) VALUES ( '/var/lib/xend/xend-socket' )
	RETURNING *
), svc AS (
	SELECT * FROM service WHERE service_name = 'xen'
), svcv AS (
	INSERT INTO service_version
		(service_id, service_type, version_name)
	SELECT service_id, 'socket', '4.4.4'
	FROM svc
	RETURNING *
), svcswpkg AS (
	INSERT INTO service_version_sw_package_repository (
		service_version_id, sw_package_repository_id
	) SELECT service_version_id, sw_package_repository_id
	FROM svcv, sw_package_repository
	WHERE sw_package_repository_type = 'os'
	AND sw_package_repository_name = 'os'
), svcinst AS (
	INSERT INTO service_instance (
		device_id, service_endpoint_id, service_version_id
	) SELECT
		device_id, service_endpoint_id, service_version_id
	FROM device, endpoint, svcv
	WHERE device_name = '0380.dbk.nym2.appnexus.net'
	RETURNING *
), svcendpointprovider AS (
	INSERT INTO service_endpoint_provider (
		service_endpoint_provider_name, service_endpoint_provider_type
	) SELECT 'direct', 'direct'
	RETURNING *
), svcendpointprovidercol AS (
	INSERT INTO service_endpoint_provider_collection (
		service_endpoint_provider_collection_name,
		service_endpoint_provider_collection_type
	) SELECT
		service_endpoint_provider_name,
		'per-service-endpoint-provider'
	FROM svcendpointprovider
	RETURNING *
), se_secol AS (
	INSERT INTO service_endpoint_provider_collection_service_endpoint_provider (
		service_endpoint_provider_collection_id,
		service_endpoint_provider_id
	) SELECT
		service_endpoint_provider_collection_id,
		service_endpoint_provider_id
	FROM svcendpointprovider, svcendpointprovidercol
	RETURNING *
), se_sep AS (
	INSERT INTO service_endpoint_service_endpoint_provider (
		service_endpoint_id,
		service_endpoint_provider_collection_id,
		service_endpoint_relation_type
	) SELECT
		service_endpoint_id,
		service_endpoint_provider_collection_id,
		'direct'
	FROM endpoint, svcendpointprovidercol
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
		((SELECT service_collection_id FROM svccol), 'location', 'launch', 'baremetal')
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
) select * from svccol;

