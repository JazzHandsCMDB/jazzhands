-- Copyright (c) 2014-2019 Todd Kover
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

SAVEPOINT l3_network_coll_hier_regression_test;

-- \ir ../../ddl/schema/pgsql/create_l3network_coll_hier_triggers.sql
-- \ir ../../ddl/schema/pgsql/create_collection_bytype_triggers.sql


-- 
-- Trigger tests
--
CREATE OR REPLACE FUNCTION layer3_network_coll_hier_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_nc_onecol1		layer3_network_collection%ROWTYPE;
	_nc_onecol3		layer3_network_collection%ROWTYPE;
	_nc_onemem		layer3_network_collection%ROWTYPE;
	_hnc			layer3_network_collection%ROWTYPE;
	_c1			layer3_network%ROWTYPE;
	_c2			layer3_network%ROWTYPE;
	_nb1			netblock%ROWTYPE;
	_nb2			netblock%ROWTYPE;
	_nb6			netblock%ROWTYPE;
BEGIN
	RAISE NOTICE 'layer3_network_coll_hier_regression: Cleanup Records from Previous Tests';

	delete from l3_network_coll_l3_network where layer3_network_collection_id
		IN (select layer3_network_collection_id FROM
		layer3_network_collection where layer3_network_collection_type like
		'JHTEST%');
	delete from layer3_network_collection where layer3_network_collection_type like
		'JHTEST%';
	delete from val_layer3_network_coll_type where 
		layer3_network_collection_type like
		'JHTEST%';
	delete from layer3_network where description like 'JHTEST%';
	delete from netblock where description like 'JHTEST%';

	RAISE NOTICE '++ Inserting testing data';

	INSERT INTO netblock (ip_address, netblock_type, is_single_address,
		can_subnet, netblock_status, description
		) VALUES (
			'172.31.26.0/26', 'default', 'N',
			'N', 'Allocated', 'JHTEST1') RETURNING * into _nb1;

	INSERT INTO netblock (ip_address, netblock_type, is_single_address,
		can_subnet, netblock_status, description
		) VALUES (
			'172.31.192.0/26', 'default', 'N',
			'N', 'Allocated', 'JHTEST2') RETURNING * into _nb2;

       INSERT INTO netblock (ip_address, netblock_type, is_single_address,
		can_subnet, netblock_status, description
		) VALUES (
			'ff00:dead:f00d::/64', 'default', 'N',
			'Y', 'Allocated', 'JHTEST1') RETURNING * into _nb6;


	INSERT INTO val_layer3_network_coll_type (
		layer3_network_collection_type, max_num_members
	) VALUES (
		'JHTEST-MEMS', 1
	);
	INSERT INTO val_layer3_network_coll_type (
		layer3_network_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS', 1
	);
	INSERT INTO val_layer3_network_coll_type (
		layer3_network_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS2', 1
	);
	INSERT INTO val_layer3_network_coll_type (
		layer3_network_collection_type, can_have_hierarchy
	) VALUES (
		'JHTEST-HIER', 'N'
	);

	INSERT INTO layer3_network_collection (
		layer3_network_collection_name, layer3_network_collection_type
	) VALUES (
		'JHTEST-cols-nc', 'JHTEST-COLS'
	) RETURNING * into _nc_onecol1;

	INSERT INTO layer3_network_collection (
		layer3_network_collection_name, layer3_network_collection_type
	) VALUES (
		'JHTEST-cols-nc-2', 'JHTEST-COLS'
	) RETURNING * into _nc_onecol3;

	INSERT INTO layer3_network_collection (
		layer3_network_collection_name, layer3_network_collection_type
	) VALUES (
		'JHTEST-mems-nc', 'JHTEST-MEMS'
	) RETURNING * into _nc_onemem;

	INSERT INTO layer3_network_collection (
		layer3_network_collection_name, layer3_network_collection_type
	) VALUES (
		'JHTEST-nohier', 'JHTEST-HIER'
	) RETURNING * into _hnc;

	------ Beginning of Collection specific stuff
	RAISE NOTICE 'Inserting collection specific records'; 

	INSERT INTO layer3_network (
		description, netblock_id
	) VALUES (
		'JHTEST01', _nb1.netblock_id
	) RETURNING * into _c1;

	INSERT INTO layer3_network (
		description, netblock_id
	) VALUES (
		'JHTEST02', _nb2.netblock_id
	) RETURNING * into _c2;

	RAISE NOTICE 'Starting tests...';

	RAISE NOTICE 'Making sure a by-coll-type works...';
	BEGIN
		SELECT count(*)
		INTO _tally
		FROM layer3_network_collection nc
			JOIN layer3_network_collection_hier h ON nc.layer3_network_collection_id =
				h.layer3_network_collection_id
		WHERE nc.layer3_network_collection_type = 'by-coll-type'
		AND nc.layer3_network_collection_NAME = 'JHTEST-COLS'
		AND child_l3_network_coll_id IN (
			_nc_onecol1.layer3_network_collection_id,
			_nc_onecol3.layer3_network_collection_id
		);
		IF _tally != 2 THEN
			RAISE '... failed with % != 2 rows!', _tally;
		END IF;

		SELECT count(*)
		INTO _tally
		FROM layer3_network_collection nc
			JOIN layer3_network_collection_hier h ON nc.layer3_network_collection_id =
				h.layer3_network_collection_id
		WHERE nc.layer3_network_collection_type = 'by-coll-type'
		AND nc.layer3_network_collection_NAME = 'JHTEST-COLS2'
		AND child_l3_network_coll_id IN (
			_nc_onecol1.layer3_network_collection_id,
			_nc_onecol3.layer3_network_collection_id
		);
		IF _tally != 0 THEN
			RAISE 'old type is not initialized right 0 != %', _tally;
		END IF;

		UPDATE layer3_network_collection
		SET layer3_network_collection_type = 'JHTEST-COLS2'
		WHERE layer3_network_collection_id = _nc_onecol1.layer3_network_collection_id;

		SELECT count(*)
		INTO _tally
		FROM layer3_network_collection nc
			JOIN layer3_network_collection_hier h ON nc.layer3_network_collection_id =
				h.layer3_network_collection_id
		WHERE nc.layer3_network_collection_type = 'by-coll-type'
		AND nc.layer3_network_collection_NAME = 'JHTEST-COLS'
		AND child_l3_network_coll_id IN (
			_nc_onecol1.layer3_network_collection_id,
			_nc_onecol3.layer3_network_collection_id
		);
		IF _tally != 1 THEN
			RAISE 'old type failed with % != 1 rows!', _tally;
		END IF;

		SELECT count(*)
		INTO _tally
		FROM layer3_network_collection nc
			JOIN layer3_network_collection_hier h ON nc.layer3_network_collection_id =
				h.layer3_network_collection_id
		WHERE nc.layer3_network_collection_type = 'by-coll-type'
		AND nc.layer3_network_collection_NAME = 'JHTEST-COLS2'
		AND child_l3_network_coll_id IN (
			_nc_onecol1.layer3_network_collection_id,
			_nc_onecol3.layer3_network_collection_id
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
		INSERT INTO layer3_network_collection_hier (
			layer3_network_collection_id, child_l3_network_coll_id
		) VALUES (
			_hnc.layer3_network_collection_id, _nc_onemem.layer3_network_collection_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO l3_network_coll_l3_network (
		layer3_network_collection_id, layer3_network_Id
	) VALUES (
		_nc_onemem.layer3_network_collection_id, _c1.layer3_network_id
	);

	INSERT INTO l3_network_coll_l3_network (
		layer3_network_collection_id, layer3_network_Id
	) VALUES (
		_hnc.layer3_network_collection_id, _c2.layer3_network_id
	);

	RAISE NOTICE 'Testing to see if max_num_members works... ';
	BEGIN
		INSERT INTO l3_network_coll_l3_network (
			layer3_network_collection_id, layer3_network_Id
		) VALUES (
			_nc_onemem.layer3_network_collection_id, _c1.layer3_network_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO l3_network_coll_l3_network (
		layer3_network_collection_id, layer3_network_Id
	) VALUES (
		_nc_onecol1.layer3_network_collection_id, _c1.layer3_network_id
	);

	RAISE NOTICE 'Testing to see if max_num_collections works... ';
	BEGIN
		INSERT INTO l3_network_coll_l3_network (
			layer3_network_collection_id, layer3_network_Id
		) VALUES (
			_nc_onecol3.layer3_network_collection_id, _c1.layer3_network_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Cleaning up...';

	delete from l3_network_coll_l3_network where layer3_network_collection_id
		IN (select layer3_network_collection_id FROM
		layer3_network_collection where layer3_network_collection_type like
		'JHTEST%');
	delete from layer3_network_collection where layer3_network_collection_type like
		'JHTEST%';
	delete from val_layer3_network_coll_type where 
		layer3_network_collection_type like
		'JHTEST%';
	delete from layer3_network where description like 'JHTEST%';
	RAISE NOTICE 'layer3_network_coll_hier_regression CollHier: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT layer3_network_coll_hier_regression();
DROP FUNCTION layer3_network_coll_hier_regression();

ROLLBACK TO l3_network_coll_hier_regression_test;

\t off
