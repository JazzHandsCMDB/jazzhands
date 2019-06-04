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

-- \set ON_ERROR_STOP
set client_min_messages to 'debug';

\t on
SAVEPOINT ct_ct_netblock_tests;

-- \ir ../../ddl/cache/pgsql/create_ct_netblock_hier.sql

SAVEPOINT readytest;

--
-- Trigger tests
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
			'172.30.0.0/24', 'Allocated', 'N', 'N'
		);
		-- RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		RAISE EXCEPTIOn 'ok.' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ Inserting testing data - 172.30.0.0/16';
	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		'172.30.0.0/16', 'Allocated', 'Y', 'N'
	) RETURNING * INTO _nb1;

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_hier',
		new_rel := 'ct_netblock_hier',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Inserting testing data - 172.30.0.0/15';
	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		'172.30.0.0/15', 'Allocated', 'Y', 'N'
	) RETURNING * INTO _nb2;

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_hier',
		new_rel := 'ct_netblock_hier',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Inserting testing data - 172.30.42.0/24';
	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		'172.30.42.0/24', 'Allocated', 'N', 'N'
	) RETURNING * INTO _nb3;

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_hier',
		new_rel := 'ct_netblock_hier',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Inserting testing data - 172.30.42.5/24 addr';
	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		'172.30.42.5/24', 'Allocated', 'N',  'Y'
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
