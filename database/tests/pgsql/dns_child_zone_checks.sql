-- Copyright (c) 2023 Todd Kover
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

-- tests this:
\ir ../../pkg/pgsql/dns_utils.sql


SAVEPOINT dns_child_zone_test;

CREATE OR REPLACE FUNCTION validate_child_zone_checks() RETURNS BOOLEAN AS $$
DECLARE
	_tally		INTEGER;
	_r			RECORD;
	_j			JSONB;
	_rootd		dns_domain.dns_domain_id%TYPE;
BEGIN
	RAISE NOTICE '++ Beginning tests of dns_child_zone...';

	WITH d AS (
		INSERT INTO dns_domain ( dns_domain_name, dns_domain_type )
		VALUES ('example.com', 'service')
		RETURNING *
	) INSERT INTO dns_domain_ip_universe (
		dns_domain_id, ip_universe_id, should_generate,
		soa_class, soa_ttl, soa_serial, soa_refresh, soa_retry,
		soa_expire, soa_minimum, soa_mname, soa_rname
	) SELEct dns_domain_id, 0, true,
		'IN', 3600, 1, 600, 1800,
		604800, 300, 'ns.example.com', 'hostmaster.example.com'
	FROM d RETURNING dns_domain_id INTO _rootd;

	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		'192.0.2.0/24', 'Allocated', false, false
	);
	WITH i AS (
		INSERT INTO netblock (
			ip_address, netblock_status, can_subnet, is_single_address
		) VALUES (
			unnest(ARRAY['192.0.2.10/24','192.0.2.11/24'])::inet, 'Allocated', 
			false, true
		) RETURNING *
	), a AS (
		INSERT INTO dns_record (
			dns_name, dns_type, dns_domain_id, netblock_id
		) SELECT regexp_replace(host(ip_address), '\.', '-'),
			'A', _rootd, netblock_id
		FROM i RETURNING *
	) INSERT INTO dns_record (
			dns_type, dns_domain_id, dns_value_record_id
		) SELECT 
			'NS', _rootd, dns_record_id
		FROM a
	;

	--
	-- setup some default NS records
	--
	SELECT count(*) INTO _tally
	FROM property
	WHERE property_name = '_authdns'
	AND property_type = 'Defaults';
	IF _tally =  0 THEN
		INSERT INTO property (
			property_type, property_name, property_value
		) SELECT 'Defaults', '_authdns', concat_ws('.',dns_name,'example.com.')
		FROM dns_record
			JOIN netblock USING (netblock_id)
		WHERE dns_domain_id = _rootd
		AND dns_type = 'A'
		AND ip_address << '192.0.2.0/24';
	END IF;

	BEGIN
		INSERT INTO property (
			property_type, property_name, property_value
		) VALUES (
			'Defaults', '_dnsmname', 'ns.example.com'
		);
	EXCEPTION WHEN unique_violation THEN NULL;
	END;

	BEGIN
		INSERT INTO property (
			property_type, property_name, property_value
		) VALUES (
			'Defaults', '_dnsrname', 'hostmaster.example.com'
		);
	EXCEPTION WHEN unique_violation THEN NULL;
	END;

	RAISE NOTICE '++ Completed Testing';

	PERFORM dns_manip.add_dns_domain('test1.example.com', 'service');
	PERFORM dns_manip.add_dns_domain('delegated.example.com', 'service');


	SELECT dns_utils.find_dns_domain_from_fqdn(
			'mumblefoo.example.com'
		) INTO _j;
	RAISE NOTICE '%', _j;


	RAISE NOTICE '++ Ending tests of dns_child_zone...';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT jazzhands.validate_child_zone_checks();
-- set search_path=jazzhands;
DROP FUNCTION validate_child_zone_checks();

ROLLBACK TO dns_child_zone_test;

\t off
