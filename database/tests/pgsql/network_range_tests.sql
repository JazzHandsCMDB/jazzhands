-- Copyright (c) 2016 Todd Kover
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
SAVEPOINT net_range_test;

-- 
-- Trigger tests
--
CREATE OR REPLACE FUNCTION network_range_coll_hier_regression() RETURNS BOOLEAN AS $$
DECLARE
	_dom			dns_domain%ROWTYPE;
	_nr1			network_range%ROWTYPE;
	_nr2			network_range%ROWTYPE;
	_nr3			network_range%ROWTYPE;
	_nb0			netblock%ROWTYPE;
	_nb1			netblock%ROWTYPE;
	_nb2			netblock%ROWTYPE;
	_nb_start		netblock%ROWTYPE;
	_nb_stop		netblock%ROWTYPE;
	_nb2_start		netblock%ROWTYPE;
	_nb2_stop		netblock%ROWTYPE;
	_nb6			netblock%ROWTYPE;
	
BEGIN
	RAISE NOTICE 'network_range_coll_hier_regression: Cleanup Records from Previous Tests';

	RAISE NOTICE '++ Inserting testing data';

        INSERT INTO DNS_DOMAIN (
                soa_name, soa_class, soa_ttl, soa_serial, soa_refresh, soa_retry,
                soa_expire, soa_minimum, soa_mname, soa_rname, should_generate,
                dns_domain_type
        ) values (
                'jhtest.example.com', 'IN', 3600, 1, 600, 1800,
                604800, 300, 'ns.example.com', 'hostmaster.example.com', 'Y',
                'service'
        ) RETURNING dns_domain_id INTO _dom;

	INSERT INTO val_netblock_type (
		netblock_type, db_forced_hierarchy, is_validated_hierarchy
	) values ('netrange', 'N', 'N');

	INSERT INTO netblock (ip_address, netblock_type, is_single_address,
		can_subnet, netblock_status, description
	) VALUES (
		'172.31.26.0/24', 'default', 'N',
		'Y', 'Allocated', 'JHTEST0'
	) RETURNING * into _nb1;

	INSERT INTO netblock (ip_address, netblock_type, is_single_address,
		can_subnet, netblock_status, description
	) VALUES (
		'172.31.26.0/26', 'default', 'N',
		'N', 'Allocated', 'JHTEST1'
	) RETURNING * into _nb1;

	INSERT INTO netblock (ip_address, netblock_type, is_single_address,
		can_subnet, netblock_status, description
	) VALUES (
		'172.31.26.3/32', 'netrange', 'Y',
		'N', 'Allocated', 'JHTEST_start'
	) RETURNING * into _nb_start;

	INSERT INTO netblock (ip_address, netblock_type, is_single_address,
		can_subnet, netblock_status, description
	) VALUES (
		'172.31.26.10/32', 'netrange', 'Y',
		'N', 'Allocated', 'JHTEST_stop'
	) RETURNING * into _nb_stop;

	INSERT INTO netblock (ip_address, netblock_type, is_single_address,
		can_subnet, netblock_status, description
	) VALUES (
		'172.31.192.0/26', 'default', 'N',
		'N', 'Allocated', 'JHTEST2'
	) RETURNING * into _nb2;

	INSERT INTO netblock (ip_address, netblock_type, is_single_address,
		can_subnet, netblock_status, description
	) VALUES (
		'172.31.192.3/32', 'default', 'Y',
		'N', 'Allocated', 'JHTEST_start'
	) RETURNING * into _nb2_start;

	INSERT INTO netblock (ip_address, netblock_type, is_single_address,
		can_subnet, netblock_status, description
	) VALUES (
		'172.31.192.10/32', 'default', 'Y',
		'N', 'Allocated', 'JHTEST_stop'
	) RETURNING * into _nb2_stop;

	INSERT INTO val_network_range_type (
		network_range_type, description, dns_domain_required
	) VALUES (
		'needdomain', 'JHTEST', 'REQUIRED'
	);

	INSERT INTO val_network_range_type (
		network_range_type, description, netblock_type, dns_domain_required
	) VALUES (
		'fnetrange', 'JHTEST', 'netrange', 'PROHIBITED'
	);

	INSERT INTO val_network_range_type (
		network_range_type, description, dns_domain_required
	) VALUES (
		'nodomain', 'JHTEST', 'PROHIBITED'
	);

	RAISE NOTICE '++ Now, Tests..';

	RAISE NOTICE 'Checking if prohibited dns domain fails...';
	BEGIN
		INSERT INTO network_range (
			network_range_type, description, parent_netblock_id,
			start_netblock_id, stop_netblock_id, dns_prefix, dns_domain_id
		) VALUES (
			'nodomain', 'JHTEST', _nb1.netblock_id,
			_nb_start.netblock_id, _nb_stop.netblock_id, 'foo', _dom.dns_domain_id
		) RETURNING * INTO _nr1;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if required dns domain fails...';
	BEGIN
		INSERT INTO network_range (
			network_range_type, description, parent_netblock_id,
			start_netblock_id, stop_netblock_id, dns_prefix, dns_domain_id
		) VALUES (
			'needdomain', 'JHTEST', _nb1.netblock_id,
			_nb_start.netblock_id, _nb_stop.netblock_id, 'foo', NULL
		) RETURNING * INTO _nr1;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN not_null_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if required dns domain succeeds...';
	INSERT INTO network_range (
		network_range_type, description, parent_netblock_id,
		start_netblock_id, stop_netblock_id, dns_prefix, dns_domain_id
	) VALUES (
		'needdomain', 'JHTEST', _nb1.netblock_id,
		_nb_start.netblock_id, _nb_stop.netblock_id, 'foo', _dom.dns_domain_id
	) RETURNING * INTO _nr1;
	RAISE NOTICE '... IT DID!';

	RAISE NOTICE 'Checking if prohibited dns domain succeeds...';
	INSERT INTO network_range (
		network_range_type, description, parent_netblock_id,
		start_netblock_id, stop_netblock_id, dns_prefix, dns_domain_id
	) VALUES (
		'nodomain', 'JHTEST', _nb1.netblock_id,
		_nb_start.netblock_id, _nb_stop.netblock_id, 'foo', NULL
	) RETURNING * INTO _nr1;
	RAISE NOTICE '... IT DID!';

	RAISE NOTICE 'Checking if can_subnet = Y start fails...';
	BEGIN
		INSERT INTO network_range (
			network_range_type, description, parent_netblock_id,
			start_netblock_id, stop_netblock_id
		) VALUES (
			'nodomain', 'JHTEST', _nb1.netblock_id,
			_nb0.netblock_id, _nb_stop.netblock_id
		) RETURNING * INTO _nr1;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if is_single_address start fails...';
	BEGIN
		INSERT INTO network_range (
			network_range_type, description, parent_netblock_id,
			start_netblock_id, stop_netblock_id
		) VALUES (
			'nodomain', 'JHTEST', _nb1.netblock_id,
			_nb2.netblock_id, _nb_stop.netblock_id
		) RETURNING * INTO _nr1;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if is_single_address stop fails...';
	BEGIN
		INSERT INTO network_range (
			network_range_type, description, parent_netblock_id,
			start_netblock_id, stop_netblock_id
		) VALUES (
			'nodomain', 'JHTEST', _nb1.netblock_id,
			_nb_start.netblock_id, _nb2.netblock_id
		) RETURNING * INTO _nr1;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if start not in parent fails...';
	BEGIN
		INSERT INTO network_range (
			network_range_type, description, parent_netblock_id,
			start_netblock_id, stop_netblock_id
		) VALUES (
			'nodomain', 'JHTEST', _nb1.netblock_id,
			_nb2_start.netblock_id, _nb_stop.netblock_id
		) RETURNING * INTO _nr1;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if stop not in parent fails...';
	BEGIN
		INSERT INTO network_range (
			network_range_type, description, parent_netblock_id,
			start_netblock_id, stop_netblock_id
		) VALUES (
			'nodomain', 'JHTEST', _nb1.netblock_id,
			_nb_start.netblock_id, _nb2_stop.netblock_id
		) RETURNING * INTO _nr1;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if bad netblock_type fails...';
	BEGIN
		INSERT INTO network_range (
			network_range_type, description, parent_netblock_id,
			start_netblock_id, stop_netblock_id
		) VALUES (
			'fnetrange', 'JHTEST', _nb2.netblock_id,
			_nb2_start.netblock_id, _nb2_stop.netblock_id
		) RETURNING * INTO _nr1;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if good netblock_type Succeeds...';
	INSERT INTO network_range (
		network_range_type, description, parent_netblock_id,
		start_netblock_id, stop_netblock_id
	) VALUES (
		'fnetrange', 'JHTEST', _nb1.netblock_id,
		_nb_start.netblock_id, _nb_stop.netblock_id
	) RETURNING * INTO _nr1;
	RAISE NOTICE '... It did';

	RAISE NOTICE 'Checking if changing start ip fails...';
	BEGIN
		UPDATE	netblock
		SET	ip_address = '10.0.0.1'
		WHERE	netblock_id = _nr1.start_netblock_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if changing stop ip fails...';
	BEGIN
		UPDATE	netblock
		SET	ip_address = '10.0.0.1'
		WHERE	netblock_id = _nr1.stop_netblock_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if changing start.is_single_address fails...';
	BEGIN
		UPDATE	netblock
		SET	is_single_address = 'N'
		WHERE	netblock_id = _nr1.start_netblock_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if changing stop.is_single_address fails...';
	BEGIN
		UPDATE	netblock
		SET	is_single_address = 'N'
		WHERE	netblock_id = _nr1.stop_netblock_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if changing start.network_type fails...';
	BEGIN
		UPDATE	netblock
		SET	netblock_type = 'default'
		WHERE	netblock_id = _nr1.start_netblock_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if changing stop.network_type fails...';
	BEGIN
		UPDATE	netblock
		SET	netblock_type = 'default'
		WHERE	netblock_id = _nr1.stop_netblock_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Cleaning up...';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT network_range_coll_hier_regression();
-- set search_path=jazzhands;
DROP FUNCTION network_range_coll_hier_regression();

ROLLBACK TO net_range_test;

\t off
