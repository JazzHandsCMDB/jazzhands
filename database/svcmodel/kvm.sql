INSERT INTO service (service_name) VALUES ('kvm');

--
-- This comes with none of the endpoint overhead and is closer to a minimum
-- set of tables, although I think it doesn't make any sense anymore because
-- service_endpoint is not tied in anymore.  It _used_ to be in
-- service_instance but I dropped it. XXX
--
WITH svc AS (
	SELECT * FROM service WHERE service_name = 'kvm'
),  endpoint AS (
        INSERT INTO service_endpoint (
                service_id, uri
        ) SELECT service_id, '/var/run/libvirt/libvirt-sock'
		FROM svc
        RETURNING *
), svcv AS (
	INSERT INTO service_version
		(service_id, service_type, version_name)
	SELECT service_id, 'socket', '2.5'
	FROM svc
	RETURNING *
), svcinst AS (
	INSERT INTO service_instance (
		device_id, service_version_id
	) SELECT
		device_id, service_version_id
	FROM device, svcv
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
), svcprop_owner AS (
	INSERT INTO service_property (
		service_collection_id, service_property_name, service_property_type,
			value_account_collection_id
	) SELECT service_collection_id, 'owner', 'role', account_collection_id
	FROM account_collection,svccol
	WHERE account_collection_name ~ 'Core Sys Infr'
	AND account_collection_type = 'department'
	RETURNING *
) select * from svccol;

