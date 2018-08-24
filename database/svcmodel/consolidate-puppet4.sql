WITH base as (
	SELECT	service_id, service_endpoint_id, 
		dns.dns_record_id, dns.dns_name, dom.dns_domain_name,
		service_name, service_endpoint_provider_name,
		service_endpoint_provider_collection_name,
		service_instance_id, service_version_id, device_id, device_name
	FROM	service
		JOIN service_endpoint USING (service_id)
		JOIN dns_record dns USING (dns_record_id)
		JOIN dns_domain dom ON dns.dns_domain_id = dom.dns_domain_id
		JOIN port_range pr USING (port_range_id)
		JOIN service_endpoint_service_endpoint_provider 
			USING (service_endpoint_id)
		JOIN service_endpoint_provider_collection
			USING (service_endpoint_provider_collection_id)
		JOIN service_endpoint_provider_collection_service_endpoint_provider
			USING (service_endpoint_provider_collection_id)
		JOIN service_endpoint_provider USING (service_endpoint_provider_id)
		JOIN service_endpoint_provider_member 
			USING (service_endpoint_provider_id)
		JOIN service_instance 
			USING (service_instance_id)
		JOIN device
			USING (device_id)
	WHERE pr.port_start = 8140 and is_singleton = 'Y'
	AND service_endpoint_provider_name ~ 'puppet4-'
	AND service_endpoint_provider_id IN (
		SELECT service_endpoint_provider_id
		FROM cloud_jazz.lb_pool
		WHERE customer_id = 1
	)
), fixone AS (
	UPDATE service
	SET service_name = 'cloud-puppet-server'
	WHERE service_id IN (
		SELECT service_id 
		FROM base 
		WHERE service_endpoint_provider_name = 'puppet4-nym2-https'
		LIMIT 1
	)
	RETURNING *
), fixsvcs AS (
	UPDATE service_endpoint
	SET service_id = (select service_id from fixone)
	WHERE service_id NOT IN (select service_id from fixone)
	AND service_endpoint_id IN (
		SELECT service_endpoint_id FROM base
	)
	RETURNING *
), fixsvcversion AS (
	UPDATE service_version SET service_id =
		(SELECT service_id FROM fixone),
		version_name = '4.9.2'
	WHERE service_version_id IN (
		SELECT service_version_id
		FROM base
		ORDER BY device_id
		LIMIT 1
	)
	RETURNING *
), fixsvcinstversion AS (
	UPDATE service_instance
	SET service_version_id = (SELECT service_version_id FROM fixsvcversion)
	WHERE service_instance_id IN (
		SELECT service_instance_id FROM base
	)
	RETURNING *
) SELECT * FROM fixsvcinstversion;


SELECT	service_id, service_name, service_endpoint_id, 
	dns.dns_record_id, dns.dns_name, dom.dns_domain_name,
	pr.port_start,
	service_name, service_endpoint_provider_name,
	service_endpoint_provider_collection_name,
	service_instance_id, service_version_id, version_name,
	device_id, device_name, client_port
FROM	service
	JOIN service_endpoint USING (service_id)
	JOIN dns_record dns USING (dns_record_id)
	JOIN dns_domain dom ON dns.dns_domain_id = dom.dns_domain_id
	JOIN port_range pr USING (port_range_id)
	JOIN service_endpoint_service_endpoint_provider 
		USING (service_endpoint_id)
	JOIN service_endpoint_provider_collection
		USING (service_endpoint_provider_collection_id)
	JOIN service_endpoint_provider_collection_service_endpoint_provider
		USING (service_endpoint_provider_collection_id)
	JOIN service_endpoint_provider USING (service_endpoint_provider_id)
	JOIN service_endpoint_provider_member 
		USING (service_endpoint_provider_id)
	JOIN (SELECT si.*, ipr.port_start as client_port
		FROM service_instance  si JOIN port_range ipr USING (port_range_id)
		) svcinst USING (service_instance_id)
	JOIN service_version
		USING (service_id, service_version_id)
	JOIN device
		USING (device_id)
WHERE port_start = 8140 and is_singleton = 'Y'
AND service_endpoint_provider_name ~ 'puppet4-'
AND service_endpoint_provider_id IN (
	SELECT service_endpoint_provider_id
	FROM cloud_jazz.lb_pool
	WHERE customer_id = 1
);

savepoint foo;
