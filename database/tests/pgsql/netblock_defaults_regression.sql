-- Copyright (c) 2018 Todd Kover
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

--
-- This tests the defaults on netblocks across namespaces to see that
-- what is expected works.

\set ON_ERROR_STOP

\t on

SAVEPOINT netblock_defaults_regression;

\ir ../../pkg/pgsql/netblock_utils.sql
\ir ../../ddl/schema/pgsql/create_netblock_triggers.sql
\ir ../../ddl/schema/pgsql/create_ip_universe_valid_triggers.sql

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION netblock_defaults_regression() RETURNS BOOLEAN AS $$
DECLARE
	_dnsdomid	dns_domain.dns_domain_id%TYPE;
	_blk0id		netblock.netblock_id%TYPE;
	_blk1id		netblock.netblock_id%TYPE;
	_ip0id		netblock.netblock_id%TYPE;
	_nb			netblock%ROWTYPE;
	_u0			ip_universe.ip_universe_id%TYPE;
	_u0a		ip_universe.ip_universe_id%TYPE;
	_defu		ip_universe.ip_universe_id%TYPE;
	_prvu		ip_universe.ip_universe_id%TYPE;
BEGIN
	RAISE NOTICE 'netblock_defaults_regression: Startup';

	--
	-- these are inserted elsewhere
	--
	SELECT ip_universe_id INTO _defu
		FROM ip_universe WHERE ip_universe_name = 'default';
	SELECT ip_universe_id INTO _prvu
		FROM ip_universe WHERE ip_universe_name = 'private';

	INSERT INTO val_ip_namespace (ip_namespace) VALUES
		('jhtest0');

	INSERT INTO ip_universe
		(ip_universe_name, ip_namespace, should_generate_dns)
		VALUES ('jhtest0', 'jhtest0', 'Y')
		RETURNING ip_universe_id INTO _u0;

	INSERT INTO ip_universe
		(ip_universe_name, ip_namespace, should_generate_dns)
		VALUES ('jhtest0a', 'jhtest0', 'Y')
		RETURNING ip_universe_id INTO _u0a;

	--
	-- This is inserted so there's a duplicate in another universe.
	INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description, ip_universe_id
	) VALUES (
		'172.31.30.0/24', 'default',
			'N', 'N', 'Allocated',
			'JHTEST _blk0id_u0', _u0
	) RETURNING netblock_id INTO _blk0id;
	INSERT INTO NETBLOCK (ip_address, netblock_type,
			is_single_address, can_subnet, netblock_status,
			description, ip_universe_id
	) VALUES (
		'172.31.31.0/24', 'default',
			'N', 'N', 'Allocated',
			'JHTEST _blk0id_u0', _u0a
	) RETURNING netblock_id INTO _blk0id;

	RAISE NOTICE 'Testing universes: % %', _u0, _u0a;

	--
	-- Check if default ip_universe works for 172.31.30.0/24
	--
	-- This assumes the ip universe defaults are there.
	--
	RAISE NOTICE 'Check if private v4 insert finds right default... ';
	BEGIN
		INSERT INTO NETBLOCK (ip_address,
			can_subnet, is_single_address, netblock_status,
			description
		) VALUES (
			'172.31.30.0/24',
			'N', 'N', 'Allocated',
			'JHTEST test private'
		) RETURNING netblock_id INTO _ip0id;

		SELECT * INTO _nb FROM netblock  WHERE netblock_id = _ip0id;

		IF _nb.ip_universe_id != _prvu THEN
			RAISE EXCEPTION 'IT did not, bad! (%,%)',
				_nb.ip_universe_id, _prvu;
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	--
	-- Check if default ip_universe works for 1.2.3.4/24, which is random
	-- routable but shouldn't ever be used.
	--
	--
	RAISE NOTICE 'Check if routable v4 insert finds right default... ';
	BEGIN
		INSERT INTO NETBLOCK (ip_address,
			can_subnet, is_single_address, netblock_status,
			description
		) VALUES (
			'1.2.3.0/24',
			'N', 'N', 'Allocated',
			'JHTEST test public'
		) RETURNING netblock_id INTO _ip0id;

		SELECT * INTO _nb FROM netblock  WHERE netblock_id = _ip0id;

		IF _nb.ip_universe_id != _defu THEN
			RAISE EXCEPTION 'IT did not, bad! (%,%)',
				_nb.ip_universe_id, _defu;
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'netblock_defaults_regression: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT netblock_defaults_regression();
-- set search_path=jazzhands;
DROP FUNCTION netblock_defaults_regression();

SET jazzhands.permit_company_insert TO default;

ROLLBACK TO netblock_defaults_regression;

\t off
