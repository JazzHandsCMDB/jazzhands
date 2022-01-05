-- Copyright (c) 2021 Todd Kover
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

-- $Id$


\set ON_ERROR_STOP

\t on
SAVEPOINT service_manip_regression;

\ir ../../pkg/pgsql/service_manip.sql

SAVEPOINT pretest;

/*

	If it's upposed to work, instead of "ugh it worked", raise an exception
	with ERRCODE+'JH999'.  That will cause rollback of the outer begin/end
	block.
	RAISE NOTICE 'Example... ';
	BEGIN
		do stuff
		BEGIN
			test a thing
		EXCEPTION WHEN unique_violation THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;
*/

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION service_manip_regression() RETURNS BOOLEAN AS $$
DECLARE
	_dt	RECORD;
	_d	RECORD;
	_dns	RECORD;
	_senv	RECORD;
	_send	RECORD;
	_r	RECORD;
	_s	service%ROWTYPE;
	_sv	service_version%ROWTYPE;
BEGIN
	RAISE NOTICE 'service_manip_regression: Begin';

	RAISE NOTICE 'Inserting test data...';

	INSERT INTO service (
		service_name, service_type
	) VALUES (
		'jhsvc', 'network'
	) RETURNING * INTO _s;

	INSERT INTO service_version (
		service_id, service_version_name
	) VALUES (
		_s.service_id, '1.0.0'
	) RETURNING * INTO _sv;

	WITH c AS (
	        SELECT company_manip.add_company(_company_name := 'JHTEST')
			AS company_id
	) INSERT INTO device_type (
		company_id, device_type_name
	)  SELECT c.company_id, 'jhtestmodel' FROM c
	RETURNING * INTO _dt;

	INSERT INTO service_environment (
		service_environment_name, service_environment_type,
		production_state
	) VALUES (
		'jhtest', 'default',
		'production'
	) RETURNING * INTO _senv;

	WITH os AS (
		INSERT INTO operating_system (
			company_id, operating_system_name,
			major_version, version
		) SELECT company_id, 'test',
			'1', '1.0'
		FROM company WHERE company_name = 'JHTEST' LIMIT 1
		RETURNING *
	) INSERT INTO device (
		device_type_id, device_name, device_status,
		operating_system_id, service_environment_id
	) SELECT
		_dt.device_type_id, 'jhtest.example.com', 'up',
		os.operating_system_id, _senv.service_environment_id
	FROM os
	RETURNING * INTO _d;

	INSERT INTO netblock (ip_address, netblock_status, is_single_address,
			can_subnet)
		VALUES ('192.0.2.0/24', 'Allocated', false, false);
	INSERT INTO netblock (ip_address, netblock_status, is_single_address)
		VALUES ('192.0.2.5/24', 'Allocated', true);

	WITH dom AS (
		INSERT INTO dns_domain (
			dns_domain_name, dns_domain_type
		) VALUES (
			'example.com', 'service'
		) RETURNING *
	) INSERT INTO dns_record (
		dns_name, dns_domain_id, dns_type, netblock_id
	) SELECT 'foo', dns_domain_id, 'A', netblock_id
	FROM dom, netblock WHERE ip_address = '192.0.2.5/24'
	RETURNING * INTO _dns;

	RAISE NOTICE 'Creating direct record link with new service_endpoint... ';
	BEGIN
		PERFORM service_manip.direct_connect_endpoint_to_device(
			device_id := _d.device_id,
			service_version_id := _sv.service_version_id,
			service_environment_id := _senv.service_environment_id,
			dns_record_id := _dns.dns_record_id,
			port_range_id := port_range_id
		) FROM port_range
		WHERE port_range_name = 'https'
		AND port_range_type = 'services';
		RAISE EXCEPTION 'It worked!' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Creating direct record link with existing service_endpoint... ';
	BEGIN
		INSERT INTO service_endpoint (
			service_id, dns_record_id, port_range_id
		) SELECT _sv.service_id, _dns.dns_record_id, port_range_id
		FROM port_range
		WHERE port_range_name = 'https'
		AND port_range_type = 'services'
		RETURNING * INTO _send;

		PERFORM service_manip.direct_connect_endpoint_to_device(
			device_id := _d.device_id,
			service_environment_id := _senv.service_environment_id,
			service_version_id := _sv.service_version_id,
			service_endpoint_id := _send.service_endpoint_id
		);
		RAISE EXCEPTION 'It worked!' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;


	RAISE NOTICE 'Cleaning up...';
	RAISE NOTICE 'END service_manip_regression...';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT service_manip_regression();
-- set search_path=jazzhands;
DROP FUNCTION service_manip_regression();

ROLLBACK TO service_manip_regression;

\t off
