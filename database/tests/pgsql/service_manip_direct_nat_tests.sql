-- Copyright (c) 2026 Todd Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

\set ON_ERROR_STOP

\t on
SAVEPOINT service_manip_direct_nat_regression;

\ir ../../pkg/pgsql/service_manip.sql

SAVEPOINT pretest;

INSERT INTO protocol (protocol, protocol_number)
SELECT 'all', 0
WHERE NOT EXISTS (
	SELECT 1 FROM protocol WHERE protocol = 'all'
);

INSERT INTO val_port_range_type (port_range_type, protocol, range_permitted)
SELECT 'all', 'all', true
WHERE NOT EXISTS (
	SELECT 1 FROM val_port_range_type
	WHERE port_range_type = 'all' AND protocol = 'all'
);

INSERT INTO port_range (
	port_range_name, protocol, port_range_type,
	port_start, port_end, is_singleton
)
SELECT 'all', 'all', 'all', 0, 65535, false
WHERE NOT EXISTS (
	SELECT 1 FROM port_range
	WHERE port_range_name = 'all'
	AND port_range_type = 'all'
	AND protocol = 'all'
);

INSERT INTO val_service_endpoint_provider_type (
	service_endpoint_provider_type, proxies_connections, translates_addresses
)
SELECT 'direct-nat', false, true
WHERE NOT EXISTS (
	SELECT 1 FROM val_service_endpoint_provider_type
	WHERE service_endpoint_provider_type = 'direct-nat'
);

INSERT INTO service (
	service_name, service_type, is_active, is_synthesized
)
SELECT 'nat', 'network', true, false
WHERE NOT EXISTS (
	SELECT 1 FROM service
	WHERE service_name = 'nat' AND service_type = 'network'
);

INSERT INTO service_version (
	service_id, service_type, service_version_name,
	is_enabled, is_deprecated, is_synthesized
)
SELECT service_id, 'network', '1.0', true, false, false
FROM service s
WHERE s.service_name = 'nat'
AND s.service_type = 'network'
AND NOT EXISTS (
	SELECT 1 FROM service_version sv
	WHERE sv.service_id = s.service_id
	AND sv.service_type = 'network'
	AND sv.service_version_name = '1.0'
);

CREATE OR REPLACE FUNCTION service_manip_direct_nat_regression()
RETURNS BOOLEAN AS $$
DECLARE
	_dt		RECORD;
	_d		RECORD;
	_senv		RECORD;
	_nat_ids	INTEGER[];
	_repeat_ids	INTEGER[];
	_destroyed_ids	INTEGER[];
	_nat_si_id	INTEGER;
	_ipv4_dns_id	INTEGER;
	_ipv6_dns_id	INTEGER;
	_ipv4_netblock_id INTEGER;
	_ipv6_netblock_id INTEGER;
	_public_ips	INET[];
	_verified_ip	INET;
	_invalid_addresses JSONB;
	_count		INTEGER;
	_caught		BOOLEAN;
BEGIN
	RAISE NOTICE 'service_manip_direct_nat_regression: Begin';
	RAISE NOTICE 'Inserting direct NAT test data...';

	WITH c AS (
		SELECT company_manip.add_company(
			_company_name := 'JHTEST_DIRECT_NAT'
		) AS company_id
	)
	INSERT INTO device_type (
		company_id, model
	)
	SELECT company_id, 'jhtest-direct-nat-model'
	FROM c
	RETURNING * INTO _dt;

	INSERT INTO service_environment (
		service_environment_name, service_environment_type,
		production_state
	) VALUES (
		'jhtest-direct-nat', 'default', 'production'
	) RETURNING * INTO _senv;

	WITH os AS (
		INSERT INTO operating_system (
			company_id, operating_system_name,
			major_version, version
		)
		SELECT company_id, 'direct-nat-test', '1', '1.0'
		FROM company
		WHERE company_name = 'JHTEST_DIRECT_NAT'
		RETURNING *
	)
	INSERT INTO device (
		device_type_id, device_name, device_status,
		operating_system_id, service_environment_id
	)
	SELECT
		_dt.device_type_id, 'direct-nat-test.example.com', 'up',
		os.operating_system_id, _senv.service_environment_id
	FROM os
	RETURNING * INTO _d;

	INSERT INTO netblock (
		ip_address, netblock_status, is_single_address, can_subnet
	) VALUES
		('198.51.100.0/24', 'Allocated', false, false),
		('2001:db8:ffff::/64', 'Allocated', false, false);

	INSERT INTO dns_domain (
		dns_domain_name, dns_domain_type
	)
	SELECT 'example.com', 'service'
	WHERE NOT EXISTS (
		SELECT 1 FROM dns_domain
		WHERE dns_domain_name = 'example.com'
	);

	IF EXISTS (
		SELECT 1 FROM netblock
		WHERE is_single_address
		AND host(ip_address) IN ('198.51.100.210', '2001:db8:ffff::210')
	) OR EXISTS (
		SELECT 1
		FROM dns_record dr
			JOIN dns_domain dd USING (dns_domain_id)
		WHERE dd.dns_domain_name = 'example.com'
		AND dr.dns_name IN (
			'nat4-direct-test', 'public.direct-nat-test'
		)
	) THEN
		RAISE EXCEPTION 'Direct NAT test addresses or names existed before create';
	END IF;

	RAISE NOTICE 'Creating direct NAT relationships...';
	_nat_ids := service_manip.create_direct_nat_relationship(
		_d.device_id,
		'[
			{"dns_name":"nat4-direct-test.example.com","ip":"198.51.100.210"},
			{"ip":"2001:db8:ffff::210"}
		]'::JSONB
	);

	IF cardinality(_nat_ids) != 2 OR _nat_ids[1] = _nat_ids[2] THEN
		RAISE EXCEPTION 'Create did not return two distinct endpoint IDs in input order';
	END IF;

	SELECT
		array_agg(
			DISTINCT host(n.ip_address)::INET
			ORDER BY host(n.ip_address)::INET
		)
	INTO _public_ips
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
	WHERE si.device_id = _d.device_id
	AND sep.service_endpoint_provider_type = 'direct-nat'
	AND sesepc.service_endpoint_relation_type = 'direct'
	GROUP BY si.device_id;

	RAISE NOTICE 'Checking public NAT IPs for device_id %: %',
		_d.device_id, _public_ips;
	IF _public_ips IS DISTINCT FROM ARRAY[
		'198.51.100.210'::INET,
		'2001:db8:ffff::210'::INET
	] THEN
		RAISE EXCEPTION 'Public NAT IP query returned unexpected addresses after create: %',
			_public_ips;
	END IF;
	FOREACH _verified_ip IN ARRAY _public_ips
	LOOP
		RAISE NOTICE 'Verified public NAT IP % for device_id %',
			_verified_ip, _d.device_id;
	END LOOP;

	SELECT count(DISTINCT si.service_instance_id), min(si.service_instance_id)
	INTO _count, _nat_si_id
	FROM service_endpoint se
		JOIN service_endpoint_service_endpoint_provider_collection sesepc
			USING (service_endpoint_id)
		JOIN service_endpoint_provider_collection_service_endpoint_provider sepcsep
			USING (service_endpoint_provider_collection_id)
		JOIN service_endpoint_provider sep USING (service_endpoint_provider_id)
		JOIN service_endpoint_provider_service_instance sepsi
			USING (service_endpoint_provider_id)
		JOIN service_instance si USING (service_instance_id)
	WHERE se.service_endpoint_id = ANY(_nat_ids)
	AND sep.service_endpoint_provider_type = 'direct-nat'
	AND si.device_id = _d.device_id;

	IF _count != 1 THEN
		RAISE EXCEPTION 'Direct NAT endpoints did not share one service instance';
	END IF;

	SELECT se.dns_record_id, dr.netblock_id
	INTO STRICT _ipv4_dns_id, _ipv4_netblock_id
	FROM service_endpoint se
		JOIN dns_record dr USING (dns_record_id)
	WHERE se.service_endpoint_id = _nat_ids[1];

	SELECT se.dns_record_id, dr.netblock_id
	INTO STRICT _ipv6_dns_id, _ipv6_netblock_id
	FROM service_endpoint se
		JOIN dns_record dr USING (dns_record_id)
	WHERE se.service_endpoint_id = _nat_ids[2];

	SELECT count(*) INTO _count
	FROM dns_record
	WHERE netblock_id IN (_ipv4_netblock_id, _ipv6_netblock_id);
	IF _count != 2 THEN
		RAISE EXCEPTION 'Create did not produce exactly one DNS record per NAT address';
	END IF;

	IF NOT EXISTS (
		SELECT 1
		FROM dns_record dr
			JOIN dns_domain dd USING (dns_domain_id)
		WHERE dr.dns_record_id = _ipv4_dns_id
		AND dd.dns_domain_name = 'example.com'
		AND dr.dns_name = 'nat4-direct-test'
	) OR NOT EXISTS (
		SELECT 1
		FROM dns_record dr
			JOIN dns_domain dd USING (dns_domain_id)
		WHERE dr.dns_record_id = _ipv6_dns_id
		AND dd.dns_domain_name = 'example.com'
		AND dr.dns_name = 'public.direct-nat-test'
	) THEN
		RAISE EXCEPTION 'Explicit and synthesized DNS names were not created as expected';
	END IF;

	_repeat_ids := service_manip.create_direct_nat_relationship(
		_d.device_id,
		'[
			{"dns_name":"nat4-direct-test.example.com","ip":"198.51.100.210"},
			{"ip":"2001:db8:ffff::210"}
		]'::JSONB
	);
	IF _repeat_ids IS DISTINCT FROM _nat_ids THEN
		RAISE EXCEPTION 'Repeated create was not idempotent';
	END IF;

	SELECT count(*) INTO _count
	FROM dns_record
	WHERE netblock_id IN (_ipv4_netblock_id, _ipv6_netblock_id);
	IF _count != 2 THEN
		RAISE EXCEPTION 'Repeated create added DNS records for existing addresses';
	END IF;

	_caught := false;
	BEGIN
		PERFORM service_manip.create_direct_nat_relationship(
			_d.device_id,
			'[
				{"dns_name":"other-direct-test.example.com","ip":"198.51.100.210"}
			]'::JSONB
		);
	EXCEPTION WHEN SQLSTATE '23000' THEN
		_caught := true;
	END;
	IF NOT _caught THEN
		RAISE EXCEPTION 'Create accepted a second DNS name for a NAT address';
	END IF;

	_caught := false;
	BEGIN
		PERFORM service_manip.create_direct_nat_relationship(
			_d.device_id,
			'[{"ip":"198.51.100.211","extra":true}]'::JSONB
		);
	EXCEPTION WHEN invalid_parameter_value THEN
		_caught := true;
	END;
	IF NOT _caught THEN
		RAISE EXCEPTION 'Create accepted an unknown JSON key';
	END IF;

	FOREACH _invalid_addresses IN ARRAY ARRAY[
		NULL::JSONB,
		'null'::JSONB,
		'{}'::JSONB,
		'"invalid"'::JSONB,
		'[]'::JSONB
	]
	LOOP
		_caught := false;
		BEGIN
			PERFORM service_manip.create_direct_nat_relationship(
				_d.device_id, _invalid_addresses
			);
		EXCEPTION WHEN invalid_parameter_value THEN
			_caught := true;
		END;
		IF NOT _caught THEN
			RAISE EXCEPTION 'Create accepted invalid top-level JSON: %',
				_invalid_addresses;
		END IF;
	END LOOP;

	_destroyed_ids := service_manip.destroy_direct_nat_relationship(
		_d.device_id, ARRAY['2001:db8:ffff::210'::INET]
	);
	IF _destroyed_ids IS DISTINCT FROM ARRAY[_nat_ids[2]] THEN
		RAISE EXCEPTION 'Selective destroy returned the wrong endpoint IDs';
	END IF;
	IF EXISTS (
		SELECT 1 FROM service_endpoint
		WHERE service_endpoint_id = _nat_ids[2]
	) OR NOT EXISTS (
		SELECT 1 FROM service_endpoint
		WHERE service_endpoint_id = _nat_ids[1]
	) OR EXISTS (
		SELECT 1 FROM dns_record
		WHERE dns_record_id = _ipv6_dns_id
	) OR EXISTS (
		SELECT 1 FROM netblock
		WHERE netblock_id = _ipv6_netblock_id
	) OR NOT EXISTS (
		SELECT 1 FROM service_instance
		WHERE service_instance_id = _nat_si_id
	) THEN
		RAISE EXCEPTION 'Selective destroy did not remove only the selected NAT rows';
	END IF;

	SELECT
		array_agg(
			DISTINCT host(n.ip_address)::INET
			ORDER BY host(n.ip_address)::INET
		)
	INTO _public_ips
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
	WHERE si.device_id = _d.device_id
	AND sep.service_endpoint_provider_type = 'direct-nat'
	AND sesepc.service_endpoint_relation_type = 'direct'
	GROUP BY si.device_id;

	RAISE NOTICE 'Checking public NAT IPs after selective destroy for device_id %: %',
		_d.device_id, _public_ips;
	IF _public_ips IS DISTINCT FROM ARRAY['198.51.100.210'::INET] THEN
		RAISE EXCEPTION 'Public NAT IP query returned unexpected addresses after selective destroy: %',
			_public_ips;
	END IF;
	RAISE NOTICE 'Verified public NAT IP % for device_id %',
		_public_ips[1], _d.device_id;

	_caught := false;
	BEGIN
		PERFORM service_manip.destroy_direct_nat_relationship(
			_d.device_id,
			ARRAY['198.51.100.210'::INET, '198.51.100.212'::INET]
		);
	EXCEPTION WHEN no_data_found THEN
		_caught := true;
	END;
	IF NOT _caught OR NOT EXISTS (
		SELECT 1 FROM service_endpoint
		WHERE service_endpoint_id = _nat_ids[1]
	) THEN
		RAISE EXCEPTION 'Unmatched selective destroy changed existing relationships';
	END IF;

	_destroyed_ids := service_manip.destroy_direct_nat_relationship(_d.device_id);
	IF _destroyed_ids IS DISTINCT FROM ARRAY[_nat_ids[1]] THEN
		RAISE EXCEPTION 'Destroy-all returned the wrong endpoint IDs';
	END IF;
	IF EXISTS (
		SELECT 1 FROM service_endpoint
		WHERE service_endpoint_id = ANY(_nat_ids)
	) OR EXISTS (
		SELECT 1 FROM service_instance
		WHERE service_instance_id = _nat_si_id
	) OR EXISTS (
		SELECT 1 FROM dns_record
		WHERE dns_record_id = _ipv4_dns_id
	) OR EXISTS (
		SELECT 1 FROM netblock
		WHERE netblock_id = _ipv4_netblock_id
	) THEN
		RAISE EXCEPTION 'Destroy-all did not remove the remaining NAT-owned rows';
	END IF;

	_public_ips := NULL;
	SELECT
		array_agg(
			DISTINCT host(n.ip_address)::INET
			ORDER BY host(n.ip_address)::INET
		)
	INTO _public_ips
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
	WHERE si.device_id = _d.device_id
	AND sep.service_endpoint_provider_type = 'direct-nat'
	AND sesepc.service_endpoint_relation_type = 'direct'
	GROUP BY si.device_id;

	RAISE NOTICE 'Checking public NAT IPs after destroy-all for device_id %: %',
		_d.device_id, coalesce(_public_ips::TEXT, '<none>');
	IF _public_ips IS NOT NULL THEN
		RAISE EXCEPTION 'Public NAT IP query returned addresses after destroy-all: %',
			_public_ips;
	END IF;
	RAISE NOTICE 'Verified no public NAT IPs remain for device_id %', _d.device_id;

	IF NOT EXISTS (
		SELECT 1 FROM netblock
		WHERE ip_address = '198.51.100.0/24'
		AND NOT is_single_address
	) OR NOT EXISTS (
		SELECT 1 FROM netblock
		WHERE ip_address = '2001:db8:ffff::/64'
		AND NOT is_single_address
	) THEN
		RAISE EXCEPTION 'Direct NAT cleanup removed a parent network';
	END IF;

	RAISE NOTICE 'END service_manip_direct_nat_regression';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT service_manip_direct_nat_regression();
DROP FUNCTION service_manip_direct_nat_regression();

ROLLBACK TO service_manip_direct_nat_regression;

\t off