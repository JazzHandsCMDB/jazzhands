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

\t on
-- 
-- Trigger tests
--
CREATE OR REPLACE FUNCTION property_coll_hier_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_nc_onecol1		property_name_collection%ROWTYPE;
	_nc_onecol2		property_name_collection%ROWTYPE;
	_nc_onemem		property_name_collection%ROWTYPE;
	_hnc			property_name_collection%ROWTYPE;
	_c1			val_property%ROWTYPE;
	_c2			val_property%ROWTYPE;
BEGIN
	RAISE NOTICE 'property_coll_hier_regression: Cleanup Records from Previous Tests';

	delete from property_name_collection_property_name where property_name_collection_id
		IN (select property_name_collection_id FROM
		property_name_collection where property_name_collection_type like
		'JHTEST%');
	delete from property_name_collection where property_name_collection_type like
		'JHTEST%';
	delete from val_property_name_collection_type where 
		property_name_collection_type like
		'JHTEST%';
	delete from val_property where property_type like 'JHTEST%';
	delete from val_property_type where property_type like 'JHTEST%';

	RAISE NOTICE '++ Inserting testing data';
	INSERT INTO val_property_name_collection_Type (
		property_name_collection_type, max_num_members
	) VALUES (
		'JHTEST-MEMS', 1
	);
	INSERT INTO val_property_name_collection_Type (
		property_name_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS', 1
	);
	INSERT INTO val_property_name_collection_Type (
		property_name_collection_type, can_have_hierarchy
	) VALUES (
		'JHTEST-HIER', false
	);

	INSERT into property_name_collection (
		property_name_collection_name, property_name_collection_type
	) values (
		'JHTEST-cols-nc', 'JHTEST-COLS'
	) RETURNING * into _nc_onecol1;

	INSERT into property_name_collection (
		property_name_collection_name, property_name_collection_type
	) values (
		'JHTEST-cols-nc-2', 'JHTEST-COLS'
	) RETURNING * into _nc_onecol2;

	INSERT into property_name_collection (
		property_name_collection_name, property_name_collection_type
	) values (
		'JHTEST-mems-nc', 'JHTEST-MEMS'
	) RETURNING * into _nc_onemem;

	INSERT into property_name_collection (
		property_name_collection_name, property_name_collection_type
	) values (
		'JHTEST-nohier', 'JHTEST-HIER'
	) RETURNING * into _hnc;

	------ Beginning of Collection specific stuff
	RAISE NOTICE 'Inserting collection specific records'; 

	INSERT INTO val_property_type (
		property_type
	) VALUES (
		'JHTEST'
	);

	INSERT INTO val_property (
		property_name, property_type, description, property_data_type
	) values (
		'JHTEST01', 'JHTEST', 'JHTEST01', 'string'
	) RETURNING * into _c1;

	INSERT INTO val_property (
		property_name, property_type, description, property_data_type
	) values (
		'JHTEST02', 'JHTEST', 'JHTEST01', 'string'
	) RETURNING * into _c2;

	RAISE NOTICE 'Starting tests...';

	RAISE NOTICE 'Testing to see if can_have_hierarachy works... ';
	BEGIN
		INSERT INTO property_name_collection_hier (
			property_name_collection_id, child_property_name_collection_id
		) VALUES (
			_hnc.property_name_collection_id, _nc_onemem.property_name_collection_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO property_name_collection_property_name (
		property_name_collection_id, 
		property_name, property_type
	) VALUES (
		_nc_onemem.property_name_collection_id, 
		_c1.property_name, _c1.property_type
	);

	INSERT INTO property_name_collection_property_name (
		property_name_collection_id, 
		property_name, property_type
	) VALUES (
		_hnc.property_name_collection_id,
		_c2.property_name, _c2.property_type
	);

	RAISE NOTICE 'Testing to see if max_num_members works... ';
	BEGIN
		INSERT INTO property_name_collection_property_name (
			property_name_collection_id,
			property_name, property_type
		) VALUES (
			_nc_onemem.property_name_collection_id, 
			_c1.property_name, _c1.property_type
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO property_name_collection_property_name (
		property_name_collection_id, 
		property_name, property_type
	) VALUES (
		_nc_onecol1.property_name_collection_id, 
		_c1.property_name, _c1.property_type
	);

	RAISE NOTICE 'Testing to see if max_num_collections works... ';
	BEGIN
		INSERT INTO property_name_collection_property_name (
			property_name_collection_id, 
			property_name, property_type
		) VALUES (
			_nc_onecol2.property_name_collection_id, 
			_c1.property_name, _c1.property_type
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Cleaning up...';

	delete from property_name_collection_property_name where property_name_collection_id
		IN (select property_name_collection_id FROM
		property_name_collection where property_name_collection_type like
		'JHTEST%');
	delete from property_name_collection where property_name_collection_type like
		'JHTEST%';
	delete from val_property_name_collection_type where 
		property_name_collection_type like
		'JHTEST%';
	delete from val_property where property_type like 'JHTEST%';
	delete from val_property_type where property_type like 'JHTEST%';
	RAISE NOTICE 'property_coll_hier_regression: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT property_coll_hier_regression();
-- set search_path=jazzhands;
DROP FUNCTION property_coll_hier_regression();

\t off
