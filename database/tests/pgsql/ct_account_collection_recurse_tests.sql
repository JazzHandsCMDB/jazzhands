-- Copyright (c) 2023-2024 Todd Kover
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

set client_min_messages to 'notice';

-- \t on
SAVEPOINT ct_account_tests;

SELECT schema_support.reset_table_sequence('jazzhands','account_collection');

\ir ../../ddl/cache/pgsql/create_ct_account_collection_hier_recurse.sql

CREATE VIEW jazzhands_legacy.same AS
SELECT 
	array_length(path, 1) - 1 as level,
	path AS array_path,
	root_account_collection_id AS account_collection_id,
	account_collection_id AS root_account_collection_id
FROM jazzhands_cache.ct_account_collection_hier_recurse;

SELECT schema_support.relation_diff(
	schema := 'jazzhands_legacy',
	old_rel := 'v_acct_coll_expanded',
	new_rel := 'same',
	prikeys := ARRAY['root_account_collection_id', 'account_collection_id']
);

CREATE VIEW jazzhands_legacy.same2 AS
SELECT DISTINCT
	account_collection_id AS account_collection_id,
	descendent_account_collection_id AS root_account_collection_id
FROM jazzhands.v_account_collection_hier_descendent
;

CREATE VIEW jazzhands_legacy.v_acct_coll_expanded_distinct AS
SELECT DISTINCT account_collection_id,
	root_account_collection_id
 FROM jazzhands_legacy.v_acct_coll_expanded;

SELECT schema_support.relation_diff(
	schema := 'jazzhands_legacy',
	old_rel := 'v_acct_coll_expanded_distinct',
	new_rel := 'same2',
	prikeys := ARRAY['root_account_collection_id', 'account_collection_id']
);

CREATE VIEW jazzhands.new_v_account_collection_account_expanded AS
SELECT DISTINCT r.account_collection_id,
	account_id
FROM jazzhands.v_account_collection_hier_descendent r
	JOIN jazzhands.account_collection_account aca
	ON r.descendent_account_collection_id = aca.account_collection_id
;

SELECT schema_support.relation_diff(
	schema := 'jazzhands',
	old_rel := 'v_account_collection_account_descendent',
	new_rel := 'v_account_collection_account_descendent',
	prikeys := ARRAY['account_collection_id', 'account_id']
);

SAVEPOINT readytest;

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION ct_account_collection_hier_tests() RETURNS BOOLEAN AS $$
DECLARE
	_tally		INTEGER;
	_tal		INTEGER;
	_id		account_collection.account_collection_id%TYPE;
	_members	INTEGER[];
	_colls		INTEGER[];
	_compid		company.company_id%TYPE;
	_t		RECORD;
	_r		RECORD;
	_i		INTEGER;
BEGIN
	RAISE NOTICE '++ Begin Account Collection Hier Testing';
	RAISE NOTICE '++ Inserting testing data';

	INSERT INTO val_account_collection_type (
		account_collection_type
	) VALUES (
		'JHTEST'
	);

	FOR _i IN 1..8 LOOP
		INSERT INTO account_collection (
			account_collection_name, account_collection_type
		) VALUES (
			'JHTEST ' || _i, 'JHTEST'
		) RETURNING account_collection_id INTO _id;
		_colls = array_append(_colls, _id);
	END LOOP;

	RAISE NOTICE 'new collections are %', to_json(_colls);

	SELECT COUNT(*) INTO _tal FROM jazzhands_cache.ct_account_collection_hier_recurse;
	RAISE DEBUG '> % records in cache', _tal;

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_account_collection_hier_recurse',
		new_rel := 'ct_account_collection_hier_recurse',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Testing first hierarchy insert ...';
	INSERT INTO account_collection_hier (
		account_collection_id, child_account_collection_id
	) VALUES (
		_colls[3], _colls[5]
	) RETURNING * INTO _r;
	RAISE NOTICE 'Inserted %', to_json(_r);
	SELECT COUNT(*) INTO _tal FROM jazzhands_cache.ct_account_collection_hier_recurse;
	RAISE DEBUG '> % records in cache', _tal;

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_account_collection_hier_recurse',
		new_rel := 'ct_account_collection_hier_recurse',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Testing first insert up top...';
	INSERT INTO account_collection_hier (
		account_collection_id, child_account_collection_id
	) VALUES (
		_colls[2], _colls[3]
	);
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_account_collection_hier_recurse',
		new_rel := 'ct_account_collection_hier_recurse',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Testing second insert up top...';
	INSERT INTO account_collection_hier (
		account_collection_id, child_account_collection_id
	) VALUES (
		_colls[1], _colls[2]
	);
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_account_collection_hier_recurse',
		new_rel := 'ct_account_collection_hier_recurse',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Testing second insert as parent of first...';
	INSERT INTO account_collection_hier (
		account_collection_id, child_account_collection_id
	) VALUES (
		_colls[5], _colls[6]
	);

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_account_collection_hier_recurse',
		new_rel := 'ct_account_collection_hier_recurse',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '+++ Inserting some random records on top...';
	SET client_min_messages to 'debug';
	WITH ac AS (
		INSERT INTO account_collection (
			account_collection_name, account_collection_type
		) VALUES ( unnest(ARRAY[ '_JHTEST995' ]), 'JHTEST')
		RETURNING *
	) INSERT INTO account_collection_hier (
		account_collection_id, child_account_collection_id
	) SELECT account_collection_id, _colls[5]
	FROM ac;

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_account_collection_hier_recurse',
		new_rel := 'ct_account_collection_hier_recurse',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '+++ Inserting some random records down below...';
	WITH ac AS (
		INSERT INTO account_collection (
			account_collection_name, account_collection_type
		) VALUES ( unnest(ARRAY[ '_JHTEST885' ]), 'JHTEST')
		RETURNING *
	) INSERT INTO account_collection_hier (
		account_collection_id, child_account_collection_id
	) SELECT _colls[6], account_collection_id
	FROM ac;

	RAISE NOTICE '++ Testing middle insert ...';
	INSERT INTO account_collection_hier (
		account_collection_id, child_account_collection_id
	) VALUES (
		_colls[4], _colls[6]
	);
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_account_collection_hier_recurse',
		new_rel := 'ct_account_collection_hier_recurse',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Testing overlapping insert ...';
	INSERT INTO account_collection_hier (
		account_collection_id, child_account_collection_id
	) VALUES (
		_colls[1], _colls[6]
	);
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_account_collection_hier_recurse',
		new_rel := 'ct_account_collection_hier_recurse',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Testing cycle I ...';
	BEGIN
		INSERT INTO account_collection_hier (
			account_collection_id, child_account_collection_id
		) VALUES (
			_colls[3], _colls[1]
		);
		RAISE EXCEPTION 'Failed to detect! Danger!';
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '... detected correctly...';
	END;

	RAISE NOTICE '++ Testing cycle II ...';
	BEGIN
		INSERT INTO account_collection_hier (
			account_collection_id, child_account_collection_id
		) VALUES (
			_colls[6], _colls[5]
		);
		RAISE EXCEPTION 'Failed to detect! Danger!';
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '... detected correctly...';
	END;

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_account_collection_hier_recurse',
		new_rel := 'ct_account_collection_hier_recurse',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Deleting overlapping insert ...';
	DELETE FROM account_collection_hier
	 	WHERE account_collection_id = _colls[1]
		AND child_account_collection_id = _colls[6]
	;
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_account_collection_hier_recurse',
		new_rel := 'ct_account_collection_hier_recurse',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Delete middle insert ...';
	DELETE FROM account_collection_hier
		WHERE account_collection_id = _colls[4]
		AND child_account_collection_id = _colls[6];
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_account_collection_hier_recurse',
		new_rel := 'ct_account_collection_hier_recurse',
		prikeys := ARRAY['path']
	);

	RAISE NOTICE '++ Updating middle ...';
	UPDATE account_collection_hier
		SET account_collection_id = _colls[4]
		WHERE account_collection_id = _colls[3];
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands_cache',
		old_rel := 'v_account_collection_hier_recurse',
		new_rel := 'ct_account_collection_hier_recurse',
		prikeys := ARRAY['path']
	);

	BEGIN
		RAISE NOTICE '++ Updating middle II ...';
		UPDATE account_collection_hier
			SET account_collection_id = _colls[7]
			WHERE account_collection_id = _colls[2];
		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_account_collection_hier_recurse',
			new_rel := 'ct_account_collection_hier_recurse',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;


	BEGIN
		RAISE NOTICE '++ Deleting top ...';
		DELETE FROM account_collection_hier
			WHERE account_collection_id = _colls[1]
			AND child_account_collection_id = _colls[2];
		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_account_collection_hier_recurse',
			new_rel := 'ct_account_collection_hier_recurse',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	BEGIN
		RAISE NOTICE '++ Deleting bottom ...';
		DELETE FROM account_collection_hier
			WHERE account_collection_id = _colls[5]
			AND child_account_collection_id = _colls[6];
		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_account_collection_hier_recurse',
			new_rel := 'ct_account_collection_hier_recurse',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	BEGIN
		RAISE NOTICE '++ Updating bottom ...';
		UPDATE account_collection_hier
			SET account_collection_id = _colls[7]
			WHERE account_collection_id = _colls[5]
			AND child_account_collection_id = _colls[6];
		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_account_collection_hier_recurse',
			new_rel := 'ct_account_collection_hier_recurse',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	BEGIN
		RAISE NOTICE '++ Updating top ...';
		UPDATE account_collection_hier
			SET account_collection_id = _colls[7]
			WHERE account_collection_id = _colls[1]
			AND child_account_collection_id = _colls[2];
		PERFORM schema_support.relation_diff(
			schema := 'jazzhands_cache',
			old_rel := 'v_account_collection_hier_recurse',
			new_rel := 'ct_account_collection_hier_recurse',
			prikeys := ARRAY['path']
		);
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Cleaning up...';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT ct_account_collection_hier_tests();
-- set search_path=jazzhands;
DROP FUNCTION ct_account_collection_hier_tests();

ROLLBACK TO ct_account_tests;

\t off
