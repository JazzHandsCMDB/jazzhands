INSERT INTO service (service_name) VALUES ('kvm');

--
-- This comes with none of the endpoint overhead and is closer to a minimum
-- set of tables.  need to reconsider endpoint.
--
WITH  endpoint AS (
        INSERT INTO service_endpoint (
                uri
        ) VALUES ( '/var/run/libvirt/libvirt-sock' )
        RETURNING *
), svc AS (
	SELECT * FROM service WHERE service_name = 'kvm'
), svcv AS (
	INSERT INTO service_version
		(service_id, service_type, version_name)
	SELECT service_id, 'socket', '2.5'
	FROM svc
	RETURNING *
), svcinst AS (
	INSERT INTO service_instance (
		device_id, service_endpoint_id, service_version_id
	) SELECT
		device_id, service_endpoint_id, service_version_id
	FROM device, endpoint, svcv
	WHERE device_name = '0380.dbk.nym2.appnexus.net'
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

