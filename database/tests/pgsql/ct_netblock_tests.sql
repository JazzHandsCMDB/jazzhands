-- Copyright (c) 2018-2019 Todd Kover
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
SAVEPOINT ct_ct_netblock_tests;

-- \ir ../../ddl/schema/pgsql/create_netblock_triggers.sql
\ir ../../ddl/cache/pgsql/create_ct_netblock_hier.sql

SAVEPOINT readytest;
set client_min_messages to 'debug';

--
-- Trigger tests
--
-- Use of former class e aka 240/4 because they should not be in use anywhere
-- and rfc1918 space is in ip universe zero already
--
CREATE OR REPLACE FUNCTION ct_netblock_hier_cache_tests() RETURNS BOOLEAN AS $$
DECLARE
	_nb1	netblock%ROWTYPE;
	_nb2	netblock%ROWTYPE;
	_nb3	netblock%ROWTYPE;
	_nb4	netblock%ROWTYPE;
	_t	RECORD;
	_r	RECORD;
	_tal	integer;
BEGIN
	RAISE NOTICE 'ct_netblock_hier_cache_tests: Cleanup Records from Previous Tests';
/*
	FOR _r IN SELECT * FROM netblock ORDER BY 1
	LOOP
		RAISE DEBUG '%', to_json(_r);
	END LOOP;
*/

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_hier',
		new_rel := 'ct_netblock_hier',
		prikeys := ARRAY['path']
	);
	SELECT COUNT(*) INTO _tal FROM jazzhands_cache.ct_netblock_hier;
	RAISE DEBUG '% records in cache', _tal;

	BEGIN
		RAISE NOTICE '++ Inserting one off net ';
		INSERT INTO netblock (
			ip_address, netblock_status, can_subnet, is_single_address
		) VALUES (
			'240.30.0.0/24', 'Allocated', false, false
		);
		-- RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		RAISE EXCEPTIOn 'ok.' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ Inserting testing data - 240.30.0.0/16';
	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		'240.30.0.0/16', 'Allocated', true, false
	) RETURNING * INTO _nb1;

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_hier',
		new_rel := 'ct_netblock_hier',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Inserting testing data - 240.30.0.0/15';
	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		'240.30.0.0/15', 'Allocated', true, false
	) RETURNING * INTO _nb2;

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_hier',
		new_rel := 'ct_netblock_hier',
		prikeys := ARRAY['path']
	);

			-- these two were part of a failure scenario but
			-- stopped
			-- '172.31.0.0/16',
			-- '240.30.43.0/24'

	RAISE NOTICE '++ Inserting random siblings...';
	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		unnest(ARRAY[
			'172.28.64.0/24',
			'172.28.64.0/20'
		]::inet[]),
		'Allocated', true, false
	);

	RAISE NOTICE '++ Inserting random parent ..';
	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		unnest(ARRAY[
			'172.28.0.0/15'
		]::inet[]),
		'Allocated', true, false
	);

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_hier',
		new_rel := 'ct_netblock_hier',
		prikeys := ARRAY['path']
	);


	RAISE NOTICE '++ Inserting testing data - 240.30.42.0/24';
	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		'240.30.42.0/24', 'Allocated', false, false
	) RETURNING * INTO _nb3;

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_hier',
		new_rel := 'ct_netblock_hier',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Checking if moving a netblock DTRT [back out]...';
	BEGIN

		UPDATE netblock SET ip_address = '172.28.42.0/24'
		WHERE netblock_id = _nb3.netblock_id;

		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_netblock_hier',
			new_rel := 'ct_netblock_hier',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION '%', 'ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ Inserting testing data - 240.30.42.5/24 addr';
	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		'240.30.42.5/24', 'Allocated', false,  true
	) RETURNING * INTO _nb4;
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_hier',
		new_rel := 'ct_netblock_hier',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Removing top record %', _nb1.netblock_id;
	DELETE FROM netblock WHERE netblock_id = _nb1.netblock_id;
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_hier',
		new_rel := 'ct_netblock_hier',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Removing middle record %', _nb1.netblock_id;
	DELETE FROM netblock WHERE netblock_id = _nb2.netblock_id;
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_hier',
		new_rel := 'ct_netblock_hier',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Checking if moving a block out completely works ...';
	BEGIN

		UPDATE netblock SET ip_address = '1.0.0.0/24'
		WHERE netblock_id = _nb2.netblock_id;

		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_netblock_hier',
			new_rel := 'ct_netblock_hier',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION '%', 'ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;



	RAISE NOTICE 'Cleaning up...';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT ct_netblock_hier_cache_tests();
-- set search_path=jazzhands;
DROP FUNCTION ct_netblock_hier_cache_tests();

ROLLBACK TO ct_ct_netblock_tests;

\t off
