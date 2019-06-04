-- Copyright (c) 2019 Todd Kover
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

set client_min_messages to 'debug';

-- \t on
SAVEPOINT ct_device_tests;

-- \ir ../../ddl/cache/pgsql/create_ct_device_collection_hier_from_ancestor.sql

SAVEPOINT readytest;

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION ct_device_collection_hier_tests() RETURNS BOOLEAN AS $$
DECLARE
	_tally		INTEGER;
	_tal		INTEGER;
	_id		device_collection.device_collection_id%TYPE;
	_members	INTEGER[];
	_colls		INTEGER[];
	_compid		company.company_id%TYPE;
	_t		RECORD;
	_r		RECORD;
	_i		INTEGER;
BEGIN
	RAISE NOTICE '++ Begin Account Collection Hier Testing';
	RAISE NOTICE '++ Inserting testing data';

	INSERT INTO val_device_collection_type (
		device_collection_type
	) VALUES (
		'JHTEST'
	);


	FOR _i IN 1..7 LOOP
		INSERT INTO device_collection (
			device_collection_name, device_collection_type
		) VALUES (
			'JHTEST ' || _i, 'JHTEST'
		) RETURNING device_collection_id INTO _id;
		_colls = array_append(_colls, _id);
	END LOOP;

	RAISE NOTICE 'new collections are %', to_json(_colls);

	SELECT COUNT(*) INTO _tal FROM jazzhands_cache.ct_device_collection_hier_from_ancestor;
	RAISE DEBUG '> % records in cache', _tal;

	INSERT INTO device_collection_hier (
		device_collection_id, child_device_collection_id
	) VALUES (
		_colls[3], _colls[5]
	) RETURNING * INTO _r;
	RAISE NOTICE 'Inserted %', to_json(_r);
	SELECT COUNT(*) INTO _tal FROM jazzhands_cache.ct_device_collection_hier_from_ancestor;
	RAISE DEBUG '> % records in cache', _tal;

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_device_collection_hier_from_ancestor',
		new_rel := 'ct_device_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Testing first insert up top...'; 
	INSERT INTO device_collection_hier (
		device_collection_id, child_device_collection_id
	) VALUES (
		_colls[2], _colls[3]
	);
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_device_collection_hier_from_ancestor',
		new_rel := 'ct_device_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Testing second insert up top...'; 
	INSERT INTO device_collection_hier (
		device_collection_id, child_device_collection_id
	) VALUES (
		_colls[1], _colls[2]
	);
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_device_collection_hier_from_ancestor',
		new_rel := 'ct_device_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Testing second insert as parent of first...'; 
	INSERT INTO device_collection_hier (
		device_collection_id, child_device_collection_id
	) VALUES (
		_colls[5], _colls[6]
	);

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_device_collection_hier_from_ancestor',
		new_rel := 'ct_device_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Testing middle insert ...'; 
	INSERT INTO device_collection_hier (
		device_collection_id, child_device_collection_id
	) VALUES (
		_colls[4], _colls[6]
	);
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_device_collection_hier_from_ancestor',
		new_rel := 'ct_device_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Delete middle insert ...';
	DELETE FROM device_collection_hier
		WHERE device_collection_id = _colls[4]
		AND child_device_collection_id = _colls[6];
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_device_collection_hier_from_ancestor',
		new_rel := 'ct_device_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Updating middle ...';
	UPDATE device_collection_hier
		SET device_collection_id = _colls[4]
		WHERE device_collection_id = _colls[3];
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_device_collection_hier_from_ancestor',
		new_rel := 'ct_device_collection_hier_from_ancestor',
		prikeys := ARRAY['path']
	);

	BEGIN
		RAISE NOTICE '++ Updating middle II ...';
		UPDATE device_collection_hier
			SET device_collection_id = _colls[7]
			WHERE device_collection_id = _colls[2];
		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_device_collection_hier_from_ancestor',
			new_rel := 'ct_device_collection_hier_from_ancestor',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;


	BEGIN
		RAISE NOTICE '++ Deleting top ...';
		DELETE FROM device_collection_hier
			WHERE device_collection_id = _colls[1]
			AND child_device_collection_id = _colls[2];
		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_device_collection_hier_from_ancestor',
			new_rel := 'ct_device_collection_hier_from_ancestor',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	BEGIN
		RAISE NOTICE '++ Deleting bottom ...';
		DELETE FROM device_collection_hier
			WHERE device_collection_id = _colls[5]
			AND child_device_collection_id = _colls[6];
		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_device_collection_hier_from_ancestor',
			new_rel := 'ct_device_collection_hier_from_ancestor',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	BEGIN
		RAISE NOTICE '++ Updating bottom ...';
		UPDATE device_collection_hier
			SET device_collection_id = _colls[7]
			WHERE device_collection_id = _colls[5]
			AND child_device_collection_id = _colls[6];
		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_device_collection_hier_from_ancestor',
			new_rel := 'ct_device_collection_hier_from_ancestor',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	BEGIN
		RAISE NOTICE '++ Updating top ...';
		UPDATE device_collection_hier
			SET device_collection_id = _colls[7]
			WHERE device_collection_id = _colls[1]
			AND child_device_collection_id = _colls[2];
		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_device_collection_hier_from_ancestor',
			new_rel := 'ct_device_collection_hier_from_ancestor',
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
SELECT ct_device_collection_hier_tests();
-- set search_path=jazzhands;
DROP FUNCTION ct_device_collection_hier_tests();

ROLLBACK TO ct_device_tests;

\t off
