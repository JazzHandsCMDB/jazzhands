-- Copyright (c) 2017 Todd Kover
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

SAVEPOINT ip_universe_validation_regression;

\ir ../../ddl/schema/pgsql/create_ip_universe_valid_triggers.sql

-- 
-- Trigger tests
--
CREATE OR REPLACE FUNCTION ip_universe_valid_regression() RETURNS BOOLEAN AS $$
DECLARE
	_dnsdomid	dns_domain.dns_domain_id%TYPE;
	_blk0id		netblock.netblock_id%TYPE;
	_blk1id		netblock.netblock_id%TYPE;
	_ip0id		netblock.netblock_id%TYPE;
	_nb			netblock%ROWTYPE;
	_u0			ip_universe.ip_universe_id%TYPE;
	_u1			ip_universe.ip_universe_id%TYPE;
	_dns		dns_record.dns_record_id%TYPE;
BEGIN
	RAISE NOTICE 'ip_universe_valid_regression: Startup';

	INSERT INTO DNS_DOMAIN (
		soa_name, soa_class, soa_ttl, soa_serial, soa_refresh, soa_retry,
		soa_expire, soa_minimum, soa_mname, soa_rname, should_generate,
		dns_domain_type
	) values (
		'jhtest.example.com', 'IN', 3600, 1, 600, 1800,
		604800, 300, 'ns.example.com', 'hostmaster.example.com', 'Y',
		'service'
	) RETURNING dns_domain_id INTO _dnsdomid;

	INSERT INTO ip_universe (ip_universe_name) VALUES ('jhtest0')
		RETURNING ip_universe_id INTO _u0;
	INSERT INTO ip_universe (ip_universe_name) VALUES ('jhtest1')
		RETURNING ip_universe_id INTO _u1;

	INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description, ip_universe_id
	) VALUES (
		'172.31.30.0/24', 'default',
			'N', 'N', 'Allocated',
			'JHTEST _blk0id', _u0
	) RETURNING netblock_id INTO _blk0id;

	INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description, ip_universe_id
	) VALUES (
		'172.31.30.0/24', 'default',
			'N', 'N', 'Allocated',
			'JHTEST _blk0id', _u1
	) RETURNING netblock_id INTO _blk1id;

	RAISE NOTICE 'Checking if netblock/dns_record mismatch fails... ';
	BEGIN
		INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description, ip_universe_id
		) VALUES (
			'172.31.30.1/24', 'default',
			'Y', 'N', 'Allocated',
			'JHTEST _ip0id', _u0
		) RETURNING netblock_id INTO _ip0id;

		BEGIN
			INSERT INTO dns_record (
				dns_name, dns_domain_id, dns_class, dns_type, netblock_id,
				should_generate_ptr, ip_universe_id
			) VALUES (
				'JHTEST-A1', _dnsdomid, 'IN', 'A', _ip0id, 'Y', _u1
			) RETURNING dns_record_id INTO _dns;
			RAISE NOTICE 'It did NOT (bad)!';
		EXCEPTION WHEN foreign_key_violation THEN
			RAISE NOTICE 'It did!';
		END;
	
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Checking if changing netblock ip universe only fails';
	BEGIN
		INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description, ip_universe_id
		) VALUES (
			'172.31.30.1/24', 'default',
			'Y', 'N', 'Allocated',
			'JHTEST _ip0id', _u0
		) RETURNING netblock_id INTO _ip0id;

		INSERT INTO dns_record (
			dns_name, dns_domain_id, dns_class, dns_type, netblock_id,
			should_generate_ptr, ip_universe_id
		) VALUES (
			'JHTEST-A1', _dnsdomid, 'IN', 'A', _ip0id, 'Y', _u0
		) RETURNING dns_record_id INTO _dns;

		BEGIN
			UPDATE netblock
			SET ip_universe_id = _u1
			WHERE netblock_id = _ip0id;
			RAISE EXCEPTION 'It did not (bad!)';
		EXCEPTION WHEN foreign_key_violation THEN
			RAISE NOTICE 'It did!';
		END;
	
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Checking if changing dns record ip universe only fails';
	BEGIN
		INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description, ip_universe_id
		) VALUES (
			'172.31.30.1/24', 'default',
			'Y', 'N', 'Allocated',
			'JHTEST _ip0id', _u0
		) RETURNING netblock_id INTO _ip0id;

		INSERT INTO dns_record (
			dns_name, dns_domain_id, dns_class, dns_type, netblock_id,
			should_generate_ptr, ip_universe_id
		) VALUES (
			'JHTEST-A1', _dnsdomid, 'IN', 'A', _ip0id, 'Y', _u0
		) RETURNING dns_record_id INTO _dns;

		BEGIN
			UPDATE dns_record
			SET ip_universe_id = _u1
			WHERE dns_record_id = _dns;
			RAISE EXCEPTION 'It did not (bad!)';
		EXCEPTION WHEN foreign_key_violation THEN
			RAISE NOTICE 'It did!';
		END;
	
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Checking if changing both universes works';
	BEGIN
		INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description, ip_universe_id
		) VALUES (
			'172.31.30.1/24', 'default',
			'Y', 'N', 'Allocated',
			'JHTEST _ip0id', _u0
		) RETURNING netblock_id INTO _ip0id;

		INSERT INTO dns_record (
			dns_name, dns_domain_id, dns_class, dns_type, netblock_id,
			should_generate_ptr, ip_universe_id
		) VALUES (
			'JHTEST-A1', _dnsdomid, 'IN', 'A', _ip0id, 'Y', _u0
		) RETURNING dns_record_id INTO _dns;

		SET CONSTRAINTS trigger_check_ip_universe_dns_record DEFERRED;
		SET CONSTRAINTS trigger_check_ip_universe_netblock DEFERRED;

		UPDATE dns_record
		SET ip_universe_id = _u1
		WHERE dns_record_id = _dns;

		UPDATE netblock
		SET ip_universe_id = _u1
		WHERE netblock_id = _ip0id;

		SET CONSTRAINTS trigger_check_ip_universe_dns_record IMMEDIATE;
		SET CONSTRAINTS trigger_check_ip_universe_netblock IMMEDIATE;
	
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	--
	-- This belongs in netblock regressions
	RAISE NOTICE 'Ensure that changing ip universes switches parentage... ';
	BEGIN
		INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description, ip_universe_id
		) VALUES (
			'172.31.30.1/24', 'default',
			'Y', 'N', 'Allocated',
			'JHTEST _ip0id', _u0
		) RETURNING netblock_id INTO _ip0id;

		SELECT * INTO _nb FROM netblock WHERE netblock_id = _ip0id;

		IF _nb.parent_netblock_id != _blk0id THEN
			RAISE EXCEPTION '.. NOT set correctly initially, ugh!';
		END IF;

		UPDATE netblock
		SET ip_universe_id = _u1
		WHERE netblock_id = _ip0id;

		SELECT * INTO _nb FROM netblock WHERE netblock_id = _ip0id;
		IF _nb.parent_netblock_id != _blk1id THEN
			RAISE EXCEPTION '.. NOT set correctly initially, ugh!';
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;


	RAISE NOTICE 'ip_universe_valid_regression: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT ip_universe_valid_regression();
-- set search_path=jazzhands;
DROP FUNCTION ip_universe_valid_regression();

SET jazzhands.permit_company_insert TO default;

ROLLBACK TO ip_universe_validation_regression;

\t off
