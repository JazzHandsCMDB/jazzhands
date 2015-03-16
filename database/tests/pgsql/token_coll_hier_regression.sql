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
CREATE OR REPLACE FUNCTION token_coll_hier_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_tc_onecol1		token_collection%ROWTYPE;
	_tc_onecol2		token_collection%ROWTYPE;
	_tc_onemem		token_collection%ROWTYPE;
	_htc			token_collection%ROWTYPE;
	_tok1			token%ROWTYPE;
	_tok2			token%ROWTYPE;
BEGIN
	RAISE NOTICE 'TokenCollHier: Cleanup Records from Previous Tests';

	delete from token_collection_token where token_collection_id
		IN (select token_collection_id FROM
		token_collection where token_collection_type like
		'JHTEST%');

	delete from token_collection where token_collection_type like
		'JHTEST%';
	delete from val_token_collection_type where 
		token_collection_type like
		'JHTEST%';
	delete from token where token_type like 'JHTEST%';

	RAISE NOTICE '++ Inserting testing data';
	INSERT INTO val_token_collection_Type (
		token_collection_type, max_num_members
	) VALUES (
		'JHTEST-MEMS', 1
	);
	INSERT INTO val_token_collection_Type (
		token_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS', 1
	);
	INSERT INTO val_token_collection_Type (
		token_collection_type, can_have_hierarchy
	) VALUES (
		'JHTEST-HIER', 'N'
	);

	INSERT into token_collection (
		token_collection_name, token_collection_type
	) values (
		'JHTEST-cols-tc', 'JHTEST-COLS'
	) RETURNING * into _tc_onecol1;

	INSERT into token_collection (
		token_collection_name, token_collection_type
	) values (
		'JHTEST-cols-tc-2', 'JHTEST-COLS'
	) RETURNING * into _tc_onecol2;

	INSERT into token_collection (
		token_collection_name, token_collection_type
	) values (
		'JHTEST-mems-tc', 'JHTEST-MEMS'
	) RETURNING * into _tc_onemem;

	INSERT into token_collection (
		token_collection_name, token_collection_type
	) values (
		'JHTEST-nohier', 'JHTEST-HIER'
	) RETURNING * into _htc;

	------ Beginning of Collection specific stuff
	RAISE NOTICE 'Inserting collection specific records'; 

	insert into val_token_type (token_type) values ('JHTEST');

	insert into token (token_serial,token_type,last_updated) 
		values('JHTEST01', 'JHTEST', now()) RETURNING * into _tok1;
	insert into token (token_serial,token_type,last_updated) 
		values('JHTEST01', 'JHTEST', now()) RETURNING * into _tok2;
	RAISE NOTICE 'Starting tests...';

	RAISE NOTICE 'Testing to see if can_have_hierarachy works... ';
	BEGIN
		INSERT INTO token_collection_hier (
			token_collection_id, child_token_collection_id
		) VALUES (
			_htc.token_collection_id, _tc_onemem.token_collection_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO token_collection_token (
		token_collection_id, token_Id
	) VALUES (
		_tc_onemem.token_collection_id, _tok1.token_id
	);

	INSERT INTO token_collection_token (
		token_collection_id, token_Id
	) VALUES (
		_htc.token_collection_id, _tok2.token_id
	);

	RAISE NOTICE 'Testing to see if max_num_members works... ';
	BEGIN
		INSERT INTO token_collection_token (
			token_collection_id, token_Id
		) VALUES (
			_tc_onemem.token_collection_id, _tok1.token_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO token_collection_token (
		token_collection_id, token_Id
	) VALUES (
		_tc_onecol1.token_collection_id, _tok1.token_id
	);

	RAISE NOTICE 'Testing to see if max_num_collections works... ';
	BEGIN
		INSERT INTO token_collection_token (
			token_collection_id, token_Id
		) VALUES (
			_tc_onecol2.token_collection_id, _tok1.token_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Cleaning up...';
	delete from token_collection_token where token_collection_id
		IN (select token_collection_id FROM
		token_collection where token_collection_type like
		'JHTEST%');
	delete from token_collection where token_collection_type like
		'JHTEST%';
	delete from val_token_collection_type where 
		token_collection_type like
		'JHTEST%';
	delete from token where token_type like 'JHTEST%';
	RAISE NOTICE 'TokenCollHier: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT token_coll_hier_regression();
-- set search_path=jazzhands;
DROP FUNCTION token_coll_hier_regression();

\t off
