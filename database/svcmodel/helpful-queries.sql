

--
-- This shows from the outside all the way down to the instance.
-- That is, the users talk to service_endpoints and that maps all the way
-- down to instances.  likely this will be some sort of view.
--
-- One weird case is gslb failover, which just points to records right now
-- rather than to devices, so it does not expand the same way.  Conceptually
-- I don't think this is a bug, but I need to revisit. XXX
--
SELECT	service_id, service_name, service_endpoint_id,
	dns.dns_record_id, dns.dns_name, dom.dns_domain_name,
	pr.port_start,
	service_name, service_endpoint_provider_name,
	service_endpoint_provider_collection_name,
	service_endpoint_provider_member_id,
	service_endpoint_relation_type, service_endpoint_relation_key,
	service_instance_id, service_version_id, service_endpoint_provider_id,
	version_name,
	device_id, device_name, client_port
FROM	service
	JOIN service_endpoint USING (service_id)
	LEFT JOIN dns_record dns USING (dns_record_id)
	LEFT JOIN dns_domain dom ON dns.dns_domain_id = dom.dns_domain_id
	JOIN port_range pr USING (port_range_id)
	JOIN service_endpoint_service_endpoint_provider
		USING (service_endpoint_id)
	JOIN service_endpoint_provider_collection
		USING (service_endpoint_provider_collection_id)
	JOIN service_endpoint_provider_collection_service_endpoint_provider
		USING (service_endpoint_provider_collection_id)
	JOIN service_endpoint_provider USING (service_endpoint_provider_id)
	LEFT JOIN service_endpoint_provider_member
		USING (service_endpoint_provider_id)
	LEFT JOIN (SELECT si.*, ipr.port_start as client_port
		FROM service_instance  si 
		JOIN port_range ipr USING (port_range_id)
		) svcinst USING (service_instance_id)
	LEFT JOIN service_version
		USING (service_id, service_version_id)
	LEFT JOIN device
		USING (device_id)
WHERE service_name IN ('stab', 'cloud-puppet-server');
;
