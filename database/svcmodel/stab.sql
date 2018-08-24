\set ON_ERROR_STOP

--
-- This is written so it works shim'd without gslb stuff converted over
-- but it aslo works with that.
--

DO $$
DECLARE
	svcend	service_endpoint%ROWTYPE;
BEGIN
	SELECT 	se.*
	INTO	svcend
	FROM	service_endpoint se
		JOIN dns_domain USING (dns_domain_id)
	WHERE	dns_domain_name = 'stab.appnexus.net'
	LIMIT 1;

	IF FOUND THEN
		UPDATE service
		SET	service_name = 'stab'
		WHERE	service_id = svcend.service_id;
	ELSE
		INSERT INTO service (service_name) VALUES ('stab');

		INSERT INTO service_endpoint (
			service_id, dns_record_id, uri, port_range_id
		) SELECT service_id, dns_record_id,
			concat('https://', dns_name, '.',soa_name,'/'), port_range_id
		FROM service, port_range, dns_record
				JOIN dns_domain using (dns_domain_id)
		WHERE dns_name = 'stab'
		AND service_name = 'stab'
		AND port_range_name = 'https'
		AND port_range_type = 'services'
		ORDER BY dns_domain_id limit 1;
	END IF;
END;
$$;


WITH svc AS (
	SELECT * FROM service WHERE service_name = 'stab'
), swpkg AS (
	INSERT INTO sw_package (
		sw_package_name, sw_package_type
	) VALUES (
		'jazzhands-stab', 'rpm'
	) RETURNING *
),  endpoint AS (
	SELECT se.*
	FROM service_endpoint se
		JOIN svc USING (service_id)
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
), src AS (	-- inserted in jazzhands-db
	SELECT * FROM source_repository
	WHERE source_repository_name = 'jazzhands'
	AND source_repository_type = 'software'
), srcrepo AS (
	INSERT INTO service_source_repository (
		service_id, source_repository_id, source_repository_path
	) SELECT service_id, source_repository_id, 'management/stab'
	FROM svc,src
	RETURNING *
), svcv AS (
	INSERT INTO service_version
		(service_id, service_type, version_name)
	SELECT service_id, 'network', '0.64.8'
	FROM svc
	RETURNING *
), svcvsrc AS (
	INSERT INTO service_version_source_repository (
		service_version_id,source_repository_id,software_tag
	) SELECT service_version_id, source_repository_id,version_name
	FROM svcv, srcrepo
), svcswpkg AS (
	INSERT INTO service_version_sw_package_repository (
		service_version_id, sw_package_repository_id
	) SELECT service_version_id, sw_package_repository_id
	FROM svcv, sw_package_repository
	WHERE sw_package_repository_type = 'obs'
	AND sw_package_repository_name = 'common'
	RETURNING *
) SELECT * FROM svcv;

DO $$
DECLARE
	svcend	service_endpoint%ROWTYPE;
	_r		RECORD;
BEGIN
	--
	-- NOTE:  This should point to an apex A record and not the domain
	-- but those need to be setup.
	--
	SELECT 	se.*
	INTO	svcend
	FROM	service_endpoint se
		JOIN dns_domain USING (dns_domain_id)
	WHERE	dns_domain_name = 'stab.appnexus.net'
	LIMIT 1;

	IF FOUND THEN
		UPDATE service_instance
		SET service_version_id = (
			SELECT service_version_id
			FROM service_version sv
				JOIN service USING (service_id)
			WHERE service_name = 'stab'
			LIMIT 1
		) WHERE service_instance_id IN (
			SELECT service_instance_id
			FROM service_instance
				JOIN device USING (device_id)
			WHERE device_name ~ 'stab'
			AND site_code != 'DEV2'
		);
	ELSE
		WITH svcv AS (
			SELECT sv.*
			FROM service_version sv
				JOIN service USING (service_id)
			WHERE service_name = 'stab'
		), svcinst AS (
			INSERT INTO service_instance (
				device_id, service_version_id,port_range_id,
				netblock_id
			) SELECT
				device_id, service_version_id,p.port_range_id,
				netblock_id
			FROM device
				JOIN network_interface_netblock USING (device_id)
				JOIN netblock nb USING (netblock_id),
				svcv, port_range p
			WHERE device_name ~ '^\d+\.stab\..*$'
			AND p.port_range_name IN ('https') AND p.port_range_type = 'services'
			AND nb.netblock_type = 'default' and host(ip_address) = '68.67.155.145'
			RETURNING *
		), svcendpointprovider AS (
			INSERT INTO service_endpoint_provider (
				service_endpoint_provider_name, service_endpoint_provider_type,
				netblock_id
			) SELECT 'stab', 'lb', netblock_id
			FROM  netblock
			WHERE host(ip_address) = '68.67.154.123' and netblock_type = 'default'
			RETURNING *
		) SELECT * INTO _r FROM svcendpointprovider;
	END IF;
END;
$$;

--
-- insert all the rest of the stab related properties.
--
WITH endpoint AS (
	SELECT se.*
	FROM service_endpoint se
		JOIN service USING (service_id)
	WHERE service_name = 'stab'
), swpkg AS (
	SELECT * FROM sw_package where sw_package_name = 'jazzhands-stab'
), svc AS (
	SELECT * FROM service WHERE service_name = 'stab'
), svcv AS (
	SELECT * FROM service_version JOIN svc USING (service_id)
), svcinst AS (
	SELECT *
	FROM service_instance
		JOIN service_version USING (service_version_id)
		JOIN svc USING (service_id)
), svcendpointprovider AS (
	SELECT * FROM service_endpoint_provider
		WHERE service_endpoint_provider_name = 'stab'
		AND service_endpoint_provider_type = 'lb'
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
