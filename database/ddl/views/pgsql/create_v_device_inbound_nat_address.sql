CREATE VIEW v_device_inbound_nat_address AS
SELECT	device_id,
	'direct-nat'::text AS nat_type,
	array_agg(
		DISTINCT host(n.ip_address)::INET
		ORDER BY host(n.ip_address)::INET
	) FILTER (WHERE family(n.ip_address) = 4) AS ipv4_addresses,
	array_agg(
		DISTINCT host(n.ip_address)::INET
		ORDER BY host(n.ip_address)::INET
	) FILTER (WHERE family(n.ip_address) = 6) AS ipv6_addresses
FROM service_instance si
JOIN service_endpoint_provider_service_instance sepsi
	USING (service_instance_id)
JOIN service_endpoint_provider sep
	USING (service_endpoint_provider_id)
JOIN service_endpoint_provider_collection_service_endpoint_provider sepcsep
	USING (service_endpoint_provider_id)
JOIN service_endpoint_service_endpoint_provider_collection sesepc
	USING (service_endpoint_provider_collection_id)
JOIN netblock n ON n.netblock_id = sep.netblock_id
AND sep.service_endpoint_provider_type = 'direct-nat'
AND sesepc.service_endpoint_relation_type = 'direct'
GROUP BY si.device_id;
