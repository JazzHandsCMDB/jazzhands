-- Copyright (c) 2022 Todd Kover
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
\ir ../../pkg/pgsql/netblock_utils.sql
\ir ../../pkg/pgsql/dns_manip.sql


SAVEPOINT dns_domain_trigger_test;

CREATE OR REPLACE FUNCTION validate_dns_domain_triggers() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_dom1		dns_domain.dns_domain_id%TYPE;
	_dom2		dns_domain.dns_domain_id%TYPE;
	_dom3		dns_domain.dns_domain_id%TYPE;
	_r			RECORD;
	_d			RECORD;
	base1		TEXT;
	base2		TEXT;
	_numns			INTEGER;
	_i			INTEGER;
BEGIN
	RAISE NOTICE '++ Beginning tests of dns_domains ...';

	--
	-- should be randomly generated
	--
	base1 := 'example.com';
	base2 := 'example.org';

	_dom1 := dns_manip.add_dns_domain(
		dns_domain_name := base1, dns_domain_type := 'service'
	);

	SELECT count(*) INTO _numns FROM property
	WHERE property_name = '_authdns' AND property_type = 'Defaults';

	INSERT INTO netblock (
		ip_address, netblock_type, can_subnet, netblock_status, is_single_address
	) VALUES (
		'192.0.2.0/28', 'default', false, 'Allocated', false
	);

	IF _numns = 0 THEN
		WITH n AS (
			INSERT INTO netblock (
				ip_address, netblock_type, is_single_address, netblock_status
			) VALUES (
				'192.0.2.5', 'default', true, 'Allocated'
			) RETURNING *
		), a AS (
			INSERT INTO dns_record (
				dns_name, dns_domain_id, dns_type, netblock_id
			) SELECT 'auth00', _dom1, 'A', netblock_id FROM n RETURNING *
		) INSERT INTO dns_record (
			dns_name, dns_domain_id, dns_type, dns_value_record_id
		) SELECT NULL, _dom1, 'NS', dns_record_id FROM a;

		WITH n AS (
			INSERT INTO netblock (
				ip_address, netblock_type, netblock_status, is_single_address
			) VALUES (
				'192.0.2.6', 'default', 'Allocated', true
			) RETURNING *
		), a AS (
			INSERT INTO dns_record (
				dns_name, dns_domain_id, dns_type, netblock_id
			) SELECT 'auth01', _dom1, 'A', netblock_id FROM n RETURNING *
		) INSERT INTO dns_record (
			dns_name, dns_domain_id, dns_type, dns_value_record_id
		) SELECT NULL, _dom1, 'NS', dns_record_id FROM a;

		INSERT INTO property (
			property_type, property_name, property_value
		) VALUES
			('Defaults', '_authns', concat_ws('.', 'auth00', base1)),
			('Defaults', '_authns', concat_ws('.', 'auth01', base1));

		SELECT count(*) INTO _numns FROM property
		WHERE property_name = '_authdns' AND property_type = 'Defaults';
	END IF;

	BEGIN
		_dom2 := dns_manip.add_dns_domain(
			dns_domain_name := concat_ws('.', 'xyz', base1),
			dns_domain_type := 'service'
		);

		SELECT count(*) INTO _i FROM dns_record WHERE dns_type = 'NS'
		AND dns_domain_id = _dom2;

		IF _i != _numns THEN
			RAISE EXCEPTION 'mismatch of expected NS record % v %', _i, _numns;
		END IF;

		RAISE EXCEPTION 'It did' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE 'Success! (%)', SQLERRM;
	END;

	BEGIN
		_dom3 := dns_manip.add_dns_domain(
			dns_domain_name := base2, dns_domain_type := 'service'
		);

		WITH n AS (
			INSERT INTO netblock (
				ip_address, netblock_type, netblock_status, is_single_address
			) VALUES (
				'192.0.2.10', 'default', 'Allocated', true
			) RETURNING *
		) INSERT INTO dns_record (
				dns_name, dns_domain_id, dns_type, netblock_id
			) SELECT 'foo.xyz', _dom3, 'A', netblock_id FROM n;

		WITH n AS (
			INSERT INTO netblock (
				ip_address, netblock_type, netblock_status, is_single_address
			) VALUES (
				'192.0.2.11', 'default', 'Allocated', true
			) RETURNING *
		) INSERT INTO dns_record (
				dns_name, dns_domain_id, dns_type, netblock_id
			) SELECT 'bar.xyz', _dom3, 'A', netblock_id FROM n;

		WITH n AS (
			INSERT INTO netblock (
				ip_address, netblock_type, netblock_status, is_single_address
			) VALUES (
				'192.0.2.12', 'default', 'Allocated', true
			) RETURNING *
		) INSERT INTO dns_record (
				dns_name, dns_domain_id, dns_type, netblock_id
			) SELECT 'baz', _dom3, 'A', netblock_id FROM n;

		SELECT count(*) INTO _i FROM dns_record WHERE dns_type = 'A'
		AND dns_domain_id = _dom3;

		IF _i != 3 THEN
			RAISE EXCEPTION 'Initial mismatch of expected NS record % v %', _i, 3;
		END IF;

		_dom2 := dns_manip.add_dns_domain(
			dns_domain_name := concat_ws('.', 'xyz', base2),
			dns_domain_type := 'service'
		);

		SELECT count(*) INTO _i FROM dns_record WHERE dns_type = 'A'
		AND dns_domain_id = _dom2;

		IF _i != 2 THEN
			RAISE EXCEPTION 'mismatch of expected NS record % v %', _i, 2;
		END IF;

		SELECT count(*) INTO _i FROM dns_record WHERE dns_type = 'A'
		AND dns_domain_id = _dom3;

		IF _i != 1 THEN
			RAISE EXCEPTION 'mismatch of expected parent NS record % v %', _i, 1;
		END IF;

		RAISE EXCEPTION 'It did' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE 'Success! (%)', SQLERRM;
	END;


	RAISE NOTICE 'Cleaning Up....';
	RAISE NOTICE '++ End dns_domain tests...';

	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT jazzhands.validate_dns_domain_triggers();
-- set search_path=jazzhands;
DROP FUNCTION validate_dns_domain_triggers();

ROLLBACK TO dns_domain_trigger_test;

\t off
