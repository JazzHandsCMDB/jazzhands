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
CREATE OR REPLACE FUNCTION company_coll_hier_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_nc_onecol1		company_collection%ROWTYPE;
	_nc_onecol2		company_collection%ROWTYPE;
	_nc_onemem		company_collection%ROWTYPE;
	_hnc			company_collection%ROWTYPE;
	_c1			company%ROWTYPE;
	_c2			company%ROWTYPE;
BEGIN
	RAISE NOTICE 'company_coll_hier_regression: Cleanup Records from Previous Tests';

	delete from company_collection_company where company_collection_id
		IN (select company_collection_id FROM
		company_collection where company_collection_type like
		'JHTEST%');
	delete from company_collection where company_collection_type like
		'JHTEST%';
	delete from val_company_collection_type where 
		company_collection_type like
		'JHTEST%';
	delete from company where description like 'JHTEST%';

	RAISE NOTICE '++ Inserting testing data';
	INSERT INTO val_company_collection_Type (
		company_collection_type, max_num_members
	) VALUES (
		'JHTEST-MEMS', 1
	);
	INSERT INTO val_company_collection_Type (
		company_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS', 1
	);
	INSERT INTO val_company_collection_Type (
		company_collection_type, can_have_hierarchy
	) VALUES (
		'JHTEST-HIER', 'N'
	);

	INSERT into company_collection (
		company_collection_name, company_collection_type
	) values (
		'JHTEST-cols-nc', 'JHTEST-COLS'
	) RETURNING * into _nc_onecol1;

	INSERT into company_collection (
		company_collection_name, company_collection_type
	) values (
		'JHTEST-cols-nc-2', 'JHTEST-COLS'
	) RETURNING * into _nc_onecol2;

	INSERT into company_collection (
		company_collection_name, company_collection_type
	) values (
		'JHTEST-mems-nc', 'JHTEST-MEMS'
	) RETURNING * into _nc_onemem;

	INSERT into company_collection (
		company_collection_name, company_collection_type
	) values (
		'JHTEST-nohier', 'JHTEST-HIER'
	) RETURNING * into _hnc;

	------ Beginning of Collection specific stuff
	RAISE NOTICE 'Inserting collection specific records'; 

	INSERT INTO company (
		company_name
	) values (
		'JHTEST01, Inc.'
	) RETURNING * into _c1;

	INSERT INTO company (
		company_name
	) values (
		'JHTEST02, Inc., A Borg Company'
	) RETURNING * into _c2;

	RAISE NOTICE 'Starting tests...';

	RAISE NOTICE 'Testing to see if can_have_hierarachy works... ';
	BEGIN
		INSERT INTO company_collection_hier (
			company_collection_id, child_company_collection_id
		) VALUES (
			_hnc.company_collection_id, _nc_onemem.company_collection_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO company_collection_company (
		company_collection_id, company_Id
	) VALUES (
		_nc_onemem.company_collection_id, _c1.company_id
	);

	INSERT INTO company_collection_company (
		company_collection_id, company_Id
	) VALUES (
		_hnc.company_collection_id, _c2.company_id
	);

	RAISE NOTICE 'Testing to see if max_num_members works... ';
	BEGIN
		INSERT INTO company_collection_company (
			company_collection_id, company_Id
		) VALUES (
			_nc_onemem.company_collection_id, _c1.company_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO company_collection_company (
		company_collection_id, company_Id
	) VALUES (
		_nc_onecol1.company_collection_id, _c1.company_id
	);

	RAISE NOTICE 'Testing to see if max_num_collections works... ';
	BEGIN
		INSERT INTO company_collection_company (
			company_collection_id, company_Id
		) VALUES (
			_nc_onecol2.company_collection_id, _c1.company_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Cleaning up...';

	delete from company_collection_company where company_collection_id
		IN (select company_collection_id FROM
		company_collection where company_collection_type like
		'JHTEST%');
	delete from company_collection where company_collection_type like
		'JHTEST%';
	delete from val_company_collection_type where 
		company_collection_type like
		'JHTEST%';
	delete from company where description like 'JHTEST%';
	RAISE NOTICE 'company_coll_hier_regression: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT company_coll_hier_regression();
-- set search_path=jazzhands;
DROP FUNCTION company_coll_hier_regression();

\t off
