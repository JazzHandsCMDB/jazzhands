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

-- set client_min_messages to 'debug';

-- \t on
SAVEPOINT ct_ct_netblock_tests;

-- \ir ../../ddl/cache/pgsql/create_ct_netblock_collection_hier_from_ancestor.sql

SAVEPOINT readytest;

alter sequence netblock_collection_netblock_collection_id_seq
	restart with 3000;

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION ct_netblock_collection_hier_tests() RETURNS BOOLEAN AS $$
DECLARE
	_tally		INTEGER;
	_tal		INTEGER;
	_id		netblock_collection.netblock_collection_id%TYPE;
	_members	INTEGER[];
	_colls		INTEGER[];
	_compid		company.company_id%TYPE;
	_t		RECORD;
	_r		RECORD;
	_i		INTEGER;
BEGIN
	RAISE NOTICE '++ Begin netblock Collection Hier Testing';
	RAISE NOTICE '++ Inserting testing data';

	INSERT INTO val_netblock_collection_type (
		netblock_collection_type
	) VALUES (
		'JHTEST'
	);

	--
	-- XXX - the last  one (8) is special
	--
	FOR _i IN 1..8 LOOP
		RAISE DEBUG '... inserting collection %', _i;

		INSERT INTO netblock_collection (
			netblock_collection_name, netblock_collection_type
		) VALUES (
			'JHTEST ' || _i, 'JHTEST'
		) RETURNING netblock_collection_id INTO _id;
		RAISE DEBUG '... collection id is %', _id;
		_colls = array_append(_colls, _id);

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_collection_hier_from_ancestor',
		new_rel := 'ct_netblock_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);
	END LOOP;

	SELECT * INTO _r
	FROM netblock_collection WHERE netblock_collection_id =_colls[1] - 1;
	RAISE NOTICE ':: %', to_json(_r);

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_collection_hier_from_ancestor',
		new_rel := 'ct_netblock_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Setup complex inheritence case...';
	FOR _i IN 1..7 LOOP
		INSERT INTO netblock_collection_hier (
			netblock_collection_id, child_netblock_collection_id
		) VALUES (
			_colls[8], _colls[_i]
		) ;
	END LOOP;

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_collection_hier_from_ancestor',
		new_rel := 'ct_netblock_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '=========================================================';

	RAISE NOTICE 'new collections are %', to_json(_colls);

	RAISE NOTICE '++ inserting first new parent/child';
	INSERT INTO netblock_collection_hier (
		netblock_collection_id, child_netblock_collection_id
	) VALUES (
		_colls[3], _colls[5]
	) RETURNING * INTO _r;
	RAISE NOTICE 'Test Inserted %', to_json(_r);

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_collection_hier_from_ancestor',
		new_rel := 'ct_netblock_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);


	RAISE NOTICE '++ Testing first insert up top...';
	INSERT INTO netblock_collection_hier (
		netblock_collection_id, child_netblock_collection_id
	) VALUES (
		_colls[2], _colls[3]
	);
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_collection_hier_from_ancestor',
		new_rel := 'ct_netblock_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Testing second insert up top...';
	INSERT INTO netblock_collection_hier (
		netblock_collection_id, child_netblock_collection_id
	) VALUES (
		_colls[1], _colls[2]
	);
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_collection_hier_from_ancestor',
		new_rel := 'ct_netblock_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Testing second insert as parent of first...';
	INSERT INTO netblock_collection_hier (
		netblock_collection_id, child_netblock_collection_id
	) VALUES (
		_colls[5], _colls[6]
	);

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_collection_hier_from_ancestor',
		new_rel := 'ct_netblock_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Testing middle insert ...';
	INSERT INTO netblock_collection_hier (
		netblock_collection_id, child_netblock_collection_id
	) VALUES (
		_colls[4], _colls[6]
	);
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_collection_hier_from_ancestor',
		new_rel := 'ct_netblock_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Delete middle insert ...';
	DELETE FROM netblock_collection_hier
		WHERE netblock_collection_id = _colls[4]
		AND child_netblock_collection_id = _colls[6];
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_collection_hier_from_ancestor',
		new_rel := 'ct_netblock_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);

/*
FOR _r IN SELECT * FROM netblock_collection_hier WHERE
	netblock_collection_id = _colls[1] - 1
LOOP
	RAISE NOTICE '== %', to_json(_r);
END LOOP;
FOR _r IN SELECT * FROM netblock_collection WHERE
	netblock_collection_id > 2000
LOOP
	RAISE NOTICE '--> %', to_json(_r);
END LOOP;
FOR _r IN SELECT * FROM netblock_collection_hier WHERE
	netblock_collection_id > 2000
LOOP
	RAISE NOTICE '==> %', to_json(_r);
END LOOP;
FOR _r IN SELECT * FROM jazzhands_cache.ct_netblock_collection_hier_from_ancestor WHERE
	netblock_collection_id > 2000
LOOP
	RAISE NOTICE 'CC> %', to_json(_r);
END LOOP;
 */

	RAISE NOTICE '++ Updating middle ...';
	UPDATE netblock_collection_hier
		SET netblock_collection_id = _colls[4]
		WHERE netblock_collection_id = _colls[3];
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_netblock_collection_hier_from_ancestor',
		new_rel := 'ct_netblock_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);

	BEGIN
		RAISE NOTICE '++ Updating middle II ...';
		UPDATE netblock_collection_hier
			SET netblock_collection_id = _colls[7]
			WHERE netblock_collection_id = _colls[2];
		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_netblock_collection_hier_from_ancestor',
			new_rel := 'ct_netblock_collection_hier_from_ancestor',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;


	BEGIN
		RAISE NOTICE '++ Deleting top ...';
		DELETE FROM netblock_collection_hier
			WHERE netblock_collection_id = _colls[1]
			AND child_netblock_collection_id = _colls[2];
		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_netblock_collection_hier_from_ancestor',
			new_rel := 'ct_netblock_collection_hier_from_ancestor',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	BEGIN
		RAISE NOTICE '++ Deleting bottom ...';
		DELETE FROM netblock_collection_hier
			WHERE netblock_collection_id = _colls[5]
			AND child_netblock_collection_id = _colls[6];
		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_netblock_collection_hier_from_ancestor',
			new_rel := 'ct_netblock_collection_hier_from_ancestor',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	BEGIN
		RAISE NOTICE '++ Updating bottom ...';
		UPDATE netblock_collection_hier
			SET netblock_collection_id = _colls[7]
			WHERE netblock_collection_id = _colls[5]
			AND child_netblock_collection_id = _colls[6];
		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_netblock_collection_hier_from_ancestor',
			new_rel := 'ct_netblock_collection_hier_from_ancestor',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	BEGIN
		RAISE NOTICE '++ Updating top ...';
		UPDATE netblock_collection_hier
			SET netblock_collection_id = _colls[7]
			WHERE netblock_collection_id = _colls[1]
			AND child_netblock_collection_id = _colls[2];
		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_netblock_collection_hier_from_ancestor',
			new_rel := 'ct_netblock_collection_hier_from_ancestor',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	-- need to test stuffing one in the middle

	RAISE NOTICE 'Cleaning up...';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT ct_netblock_collection_hier_tests();
-- set search_path=jazzhands;
DROP FUNCTION ct_netblock_collection_hier_tests();

ROLLBACK TO ct_ct_netblock_tests;

\t off
