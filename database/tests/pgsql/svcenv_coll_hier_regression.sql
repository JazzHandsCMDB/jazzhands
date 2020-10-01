-- Copyright (c) 2014-2017 Todd Kover
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

SAVEPOINT servie_environment_collection_hier_regression_test;

\ir ../../ddl/schema/pgsql/create_svcenv_coll_hier_triggers.sql
\ir ../../ddl/schema/pgsql/create_collection_bytype_triggers.sql


-- 
-- Trigger tests
--
CREATE OR REPLACE FUNCTION service_environment_collection_hier_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_sc_onecol1		service_environment_collection%ROWTYPE;
	_sc_onecol2		service_environment_collection%ROWTYPE;
	_sc_onemem		service_environment_collection%ROWTYPE;
	_hsc			service_environment_collection%ROWTYPE;
	_svcenv1		service_environment%ROWTYPE;
	_svcenv2		service_environment%ROWTYPE;
BEGIN
	RAISE NOTICE 'service_environment_collection_hier_regression: Cleanup Records from Previous Tests';

	delete from service_environment_collection_service_environment where service_environment_collection_id
		IN (select service_environment_collection_id FROM
		service_environment_collection where service_environment_collection_name like
		'JHTEST%');

	delete from service_environment_collection where service_environment_collection_type like
		'JHTEST%';
	delete from val_service_environment_collection_type where 
		service_environment_collection_type like
		'JHTEST%';
	delete from service_environment 
	where service_environment_name like 'JHTEST%';

	RAISE NOTICE '++ Inserting testing data';
	INSERT INTO val_service_environment_collection_type (
		service_environment_collection_type, max_num_members
	) VALUES (
		'JHTEST-MEMS', 1
	);
	INSERT INTO val_service_environment_collection_type (
		service_environment_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS', 1
	);
	INSERT INTO val_service_environment_collection_type (
		service_environment_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS2', 1
	);
	INSERT INTO val_service_environment_collection_type (
		service_environment_collection_type, can_have_hierarchy
	) VALUES (
		'JHTEST-HIER', false
	);

	INSERT into service_environment_collection (
		service_environment_collection_name, service_environment_collection_type
	) values (
		'JHTEST-cols-tc', 'JHTEST-COLS'
	) RETURNING * into _sc_onecol1;

	INSERT into service_environment_collection (
		service_environment_collection_name, service_environment_collection_type
	) values (
		'JHTEST-cols-tc-2', 'JHTEST-COLS'
	) RETURNING * into _sc_onecol2;

	INSERT into service_environment_collection (
		service_environment_collection_name, service_environment_collection_type
	) values (
		'JHTEST-mems-tc', 'JHTEST-MEMS'
	) RETURNING * into _sc_onemem;

	INSERT into service_environment_collection (
		service_environment_collection_name, service_environment_collection_type
	) values (
		'JHTEST-nohier', 'JHTEST-HIER'
	) RETURNING * into _hsc;

	------ Beginning of Collection specific stuff
	RAISE NOTICE 'Inserting collection specific records'; 

	INSERT INTO val_service_environment_type (
		service_environment_type
	) VALUES (
		'JHTEST'
	);

	INSERT INTO service_environment (
		service_environment_name,service_environment_type, production_state
	) VALUES (
		'JHTEST01', 'JHTEST', 'production') RETURNING * into _svcenv1;

	INSERT INTO service_environment (
		service_environment_name, service_environment_type, production_state
	) VALUES(
		'JHTEST02', 'JHTEST', 'production') RETURNING * into _svcenv2;
	RAISE NOTICE 'Starting tests...';

	RAISE NOTICE 'Making sure a by-coll-type works...';
	BEGIN
		SELECT count(*)
		INTO _tally
		FROM service_environment_collection sc
			JOIN service_environment_collection_hier h ON sc.service_environment_collection_id =
				h.service_environment_collection_id
		WHERE sc.service_environment_collection_type = 'by-coll-type'
		AND sc.service_environment_collection_NAME = 'JHTEST-COLS'
		AND h.child_service_environment_collection_id IN (
			_sc_onecol1.service_environment_collection_id,
			_sc_onecol2.service_environment_collection_id
		);
		IF _tally != 2 THEN
			RAISE '... failed with % != 2 rows!', _tally;
		END IF;

		SELECT count(*)
		INTO _tally
		FROM service_environment_collection sc
			JOIN service_environment_collection_hier h ON sc.service_environment_collection_id =
				h.service_environment_collection_id
		WHERE sc.service_environment_collection_type = 'by-coll-type'
		AND sc.service_environment_collection_NAME = 'JHTEST-COLS2'
		AND h.child_service_environment_collection_id IN (
			_sc_onecol1.service_environment_collection_id,
			_sc_onecol2.service_environment_collection_id
		);
		IF _tally != 0 THEN
			RAISE 'old type is not initialized right 0 != %', _tally;
		END IF;

		UPDATE service_environment_collection
		SET service_environment_collection_type = 'JHTEST-COLS2'
		WHERE service_environment_collection_id = _sc_onecol1.service_environment_collection_id;

		SELECT count(*)
		INTO _tally
		FROM service_environment_collection sc
			JOIN service_environment_collection_hier h ON sc.service_environment_collection_id =
				h.service_environment_collection_id
		WHERE sc.service_environment_collection_type = 'by-coll-type'
		AND sc.service_environment_collection_NAME = 'JHTEST-COLS'
		AND h.child_service_environment_collection_id IN (
			_sc_onecol1.service_environment_collection_id,
			_sc_onecol2.service_environment_collection_id
		);
		IF _tally != 1 THEN
			RAISE 'old type failed with % != 1 rows!', _tally;
		END IF;

		SELECT count(*)
		INTO _tally
		FROM service_environment_collection sc
			JOIN service_environment_collection_hier h ON sc.service_environment_collection_id =
				h.service_environment_collection_id
		WHERE sc.service_environment_collection_type = 'by-coll-type'
		AND sc.service_environment_collection_NAME = 'JHTEST-COLS2'
		AND h.child_service_environment_collection_id IN (
			_sc_onecol1.service_environment_collection_id,
			_sc_onecol2.service_environment_collection_id
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
		INSERT INTO service_environment_collection_hier (
			service_environment_collection_id, child_service_environment_collection_id
		) VALUES (
			_hsc.service_environment_collection_id, _sc_onemem.service_environment_collection_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO service_environment_collection_service_environment (
		service_environment_collection_id, service_environment_id
	) VALUES (
		_sc_onemem.service_environment_collection_id, _svcenv1.service_environment_id
	);

	INSERT INTO service_environment_collection_service_environment (
		service_environment_collection_id, service_environment_id
	) VALUES (
		_hsc.service_environment_collection_id, _svcenv2.service_environment_id
	);

	RAISE NOTICE 'Testing to see if max_num_members works... ';
	BEGIN
		INSERT INTO service_environment_collection_service_environment (
			service_environment_collection_id, service_environment_id
		) VALUES (
			_sc_onemem.service_environment_collection_id, _svcenv1.service_environment_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO service_environment_collection_service_environment (
		service_environment_collection_id, service_environment_id
	) VALUES (
		_sc_onecol1.service_environment_collection_id, _svcenv1.service_environment_id
	);

	RAISE NOTICE 'Testing to see if max_num_collections works... ';
	BEGIN
		INSERT INTO service_environment_collection_service_environment (
			service_environment_collection_id, service_environment_id
		) VALUES (
			_sc_onecol2.service_environment_collection_id, _svcenv1.service_environment_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Cleaning up...';

	RAISE NOTICE 'service_environment_collection_hier_regression: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT service_environment_collection_hier_regression();
-- set search_path=jazzhands;
DROP FUNCTION service_environment_collection_hier_regression();

ROLLBACK TO servie_environment_collection_hier_regression_test;

\t off
