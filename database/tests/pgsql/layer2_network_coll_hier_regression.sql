-- Copyright (c) 2014 Todd Kover
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

SAVEPOINT l2_network_coll_hier_regression_test;

\ir ../../ddl/schema/pgsql/create_l2network_coll_hier_triggers.sql
\ir ../../ddl/schema/pgsql/create_collection_bytype_triggers.sql

\t on
-- 
-- Trigger tests
--
CREATE OR REPLACE FUNCTION layer2_network_coll_hier_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_nc_onecol1		layer2_network_collection%ROWTYPE;
	_nc_onecol2		layer2_network_collection%ROWTYPE;
	_nc_onemem		layer2_network_collection%ROWTYPE;
	_hnc			layer2_network_collection%ROWTYPE;
	_c1			layer2_network%ROWTYPE;
	_c2			layer2_network%ROWTYPE;
BEGIN
	RAISE NOTICE 'layer2_network_coll_hier_regression: Cleanup Records from Previous Tests';

	delete from l2_network_coll_l2_network where layer2_network_collection_id
		IN (select layer2_network_collection_id FROM
		layer2_network_collection where layer2_network_collection_type like
		'JHTEST%');
	delete from layer2_network_collection where layer2_network_collection_type like
		'JHTEST%';
	delete from val_layer2_network_coll_type where 
		layer2_network_collection_type like
		'JHTEST%';
	delete from layer2_network where description like 'JHTEST%';

	RAISE NOTICE '++ Inserting testing data';
	INSERT INTO val_layer2_network_coll_type (
		layer2_network_collection_type, max_num_members
	) VALUES (
		'JHTEST-MEMS', 1
	);
	INSERT INTO val_layer2_network_coll_type (
		layer2_network_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS', 1
	);
	INSERT INTO val_layer2_network_coll_type (
		layer2_network_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS2', 1
	);
	INSERT INTO val_layer2_network_coll_type (
		layer2_network_collection_type, can_have_hierarchy
	) VALUES (
		'JHTEST-HIER', 'N'
	);

	INSERT into layer2_network_collection (
		layer2_network_collection_name, layer2_network_collection_type
	) values (
		'JHTEST-cols-nc', 'JHTEST-COLS'
	) RETURNING * into _nc_onecol1;

	INSERT into layer2_network_collection (
		layer2_network_collection_name, layer2_network_collection_type
	) values (
		'JHTEST-cols-nc-2', 'JHTEST-COLS'
	) RETURNING * into _nc_onecol2;

	INSERT into layer2_network_collection (
		layer2_network_collection_name, layer2_network_collection_type
	) values (
		'JHTEST-mems-nc', 'JHTEST-MEMS'
	) RETURNING * into _nc_onemem;

	INSERT into layer2_network_collection (
		layer2_network_collection_name, layer2_network_collection_type
	) values (
		'JHTEST-nohier', 'JHTEST-HIER'
	) RETURNING * into _hnc;

	------ Beginning of Collection specific stuff
	RAISE NOTICE 'Inserting collection specific records'; 

	INSERT INTO layer2_network (
		encapsulation_name, description
	) values (
		'JHTEST01', 'JHTEST'
	) RETURNING * into _c1;

	INSERT INTO layer2_network (
		encapsulation_name, description
	) values (
		'JHTEST02', 'JHTEST'
	) RETURNING * into _c2;

	RAISE NOTICE 'Starting tests...';

	RAISE NOTICE 'Making sure a by-type works...';
	BEGIN
		SELECT count(*)
		INTO _tally
		FROM layer2_network_collection nc
			JOIN layer2_network_collection_hier h ON nc.layer2_network_collection_id =
				h.layer2_network_collection_id
		WHERE nc.layer2_network_collection_type = 'by-type'
		AND nc.layer2_network_collection_NAME = 'JHTEST-COLS'
		AND child_l2_network_coll_id IN (
			_nc_onecol1.layer2_network_collection_id,
			_nc_onecol2.layer2_network_collection_id
		);
		IF _tally != 2 THEN
			RAISE '... failed with % != 2 rows!', _tally;
		END IF;

		SELECT count(*)
		INTO _tally
		FROM layer2_network_collection nc
			JOIN layer2_network_collection_hier h ON nc.layer2_network_collection_id =
				h.layer2_network_collection_id
		WHERE nc.layer2_network_collection_type = 'by-type'
		AND nc.layer2_network_collection_NAME = 'JHTEST-COLS2'
		AND child_l2_network_coll_id IN (
			_nc_onecol1.layer2_network_collection_id,
			_nc_onecol2.layer2_network_collection_id
		);
		IF _tally != 0 THEN
			RAISE 'old type is not initialized right 0 != %', _tally;
		END IF;

		UPDATE layer2_network_collection
		SET layer2_network_collection_type = 'JHTEST-COLS2'
		WHERE layer2_network_collection_id = _nc_onecol1.layer2_network_collection_id;

		SELECT count(*)
		INTO _tally
		FROM layer2_network_collection nc
			JOIN layer2_network_collection_hier h ON nc.layer2_network_collection_id =
				h.layer2_network_collection_id
		WHERE nc.layer2_network_collection_type = 'by-type'
		AND nc.layer2_network_collection_NAME = 'JHTEST-COLS'
		AND child_l2_network_coll_id IN (
			_nc_onecol1.layer2_network_collection_id,
			_nc_onecol2.layer2_network_collection_id
		);
		IF _tally != 1 THEN
			RAISE 'old type failed with % != 1 rows!', _tally;
		END IF;

		SELECT count(*)
		INTO _tally
		FROM layer2_network_collection nc
			JOIN layer2_network_collection_hier h ON nc.layer2_network_collection_id =
				h.layer2_network_collection_id
		WHERE nc.layer2_network_collection_type = 'by-type'
		AND nc.layer2_network_collection_NAME = 'JHTEST-COLS2'
		AND child_l2_network_coll_id IN (
			_nc_onecol1.layer2_network_collection_id,
			_nc_onecol2.layer2_network_collection_id
		);
		IF _tally != 1 THEN
			RAISE 'new type failed with % != 2 rows!', _tally;
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;


	RAISE NOTICE 'Testing to see if can_have_hierarachy works... ';
	BEGIN
		INSERT INTO layer2_network_collection_hier (
			layer2_network_collection_id, child_l2_network_coll_id
		) VALUES (
			_hnc.layer2_network_collection_id, _nc_onemem.layer2_network_collection_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO l2_network_coll_l2_network (
		layer2_network_collection_id, layer2_network_Id
	) VALUES (
		_nc_onemem.layer2_network_collection_id, _c1.layer2_network_id
	);

	INSERT INTO l2_network_coll_l2_network (
		layer2_network_collection_id, layer2_network_Id
	) VALUES (
		_hnc.layer2_network_collection_id, _c2.layer2_network_id
	);

	RAISE NOTICE 'Testing to see if max_num_members works... ';
	BEGIN
		INSERT INTO l2_network_coll_l2_network (
			layer2_network_collection_id, layer2_network_Id
		) VALUES (
			_nc_onemem.layer2_network_collection_id, _c1.layer2_network_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO l2_network_coll_l2_network (
		layer2_network_collection_id, layer2_network_Id
	) VALUES (
		_nc_onecol1.layer2_network_collection_id, _c1.layer2_network_id
	);

	RAISE NOTICE 'Testing to see if max_num_collections works... ';
	BEGIN
		INSERT INTO l2_network_coll_l2_network (
			layer2_network_collection_id, layer2_network_Id
		) VALUES (
			_nc_onecol2.layer2_network_collection_id, _c1.layer2_network_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Cleaning up...';

	delete from l2_network_coll_l2_network where layer2_network_collection_id
		IN (select layer2_network_collection_id FROM
		layer2_network_collection where layer2_network_collection_type like
		'JHTEST%');
	delete from layer2_network_collection where layer2_network_collection_type like
		'JHTEST%';
	delete from val_layer2_network_coll_type where 
		layer2_network_collection_type like
		'JHTEST%';
	delete from layer2_network where description like 'JHTEST%';
	RAISE NOTICE 'layer2_network_coll_hier_regression: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT layer2_network_coll_hier_regression();
-- set search_path=jazzhands;
DROP FUNCTION layer2_network_coll_hier_regression();

ROLLBACK TO l2_network_coll_hier_regression_test;


\t off
