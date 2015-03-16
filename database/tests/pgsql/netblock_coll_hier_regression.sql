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
CREATE OR REPLACE FUNCTION netblock_coll_hier_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_nc_onecol1		netblock_collection%ROWTYPE;
	_nc_onecol2		netblock_collection%ROWTYPE;
	_nc_onemem		netblock_collection%ROWTYPE;
	_hnc			netblock_collection%ROWTYPE;
	_nb1			netblock%ROWTYPE;
	_nb2			netblock%ROWTYPE;
BEGIN
	RAISE NOTICE 'Netblock CollHier: Cleanup Records from Previous Tests';

	delete from netblock_collection_netblock where netblock_collection_id
		IN (select netblock_collection_id FROM
		netblock_collection where netblock_collection_type like
		'JHTEST%');
	delete from netblock_collection where netblock_collection_type like
		'JHTEST%';
	delete from val_netblock_collection_type where 
		netblock_collection_type like
		'JHTEST%';
	delete from netblock where description like 'JHTEST%';

	RAISE NOTICE '++ Inserting testing data';
	INSERT INTO val_netblock_collection_Type (
		netblock_collection_type, max_num_members
	) VALUES (
		'JHTEST-MEMS', 1
	);
	INSERT INTO val_netblock_collection_Type (
		netblock_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS', 1
	);
	INSERT INTO val_netblock_collection_Type (
		netblock_collection_type, can_have_hierarchy
	) VALUES (
		'JHTEST-HIER', 'N'
	);

	INSERT into netblock_collection (
		netblock_collection_name, netblock_collection_type
	) values (
		'JHTEST-cols-nc', 'JHTEST-COLS'
	) RETURNING * into _nc_onecol1;

	INSERT into netblock_collection (
		netblock_collection_name, netblock_collection_type
	) values (
		'JHTEST-cols-nc-2', 'JHTEST-COLS'
	) RETURNING * into _nc_onecol2;

	INSERT into netblock_collection (
		netblock_collection_name, netblock_collection_type
	) values (
		'JHTEST-mems-nc', 'JHTEST-MEMS'
	) RETURNING * into _nc_onemem;

	INSERT into netblock_collection (
		netblock_collection_name, netblock_collection_type
	) values (
		'JHTEST-nohier', 'JHTEST-HIER'
	) RETURNING * into _hnc;

	------ Beginning of Collection specific stuff
	RAISE NOTICE 'Inserting collection specific records'; 

	insert into netblock (ip_address, netblock_type, is_single_address,
		can_subnet, netblock_status, description
		) values (
			'172.31.26.0/26', 'default', 'N',
			'Y', 'Allocated', 'JHTEST1') RETURNING * into _nb1;
	insert into netblock (ip_address, netblock_type, is_single_address,
		can_subnet, netblock_status, description
		) values (
			'ff00:dead:f00d::/64', 'default', 'N',
			'Y', 'Allocated', 'JHTEST1') RETURNING * into _nb2;

	RAISE NOTICE 'Starting tests...';

	RAISE NOTICE 'Testing to see if can_have_hierarachy works... ';
	BEGIN
		INSERT INTO netblock_collection_hier (
			netblock_collection_id, child_netblock_collection_id
		) VALUES (
			_hnc.netblock_collection_id, _nc_onemem.netblock_collection_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO netblock_collection_netblock (
		netblock_collection_id, netblock_Id
	) VALUES (
		_nc_onemem.netblock_collection_id, _nb1.netblock_id
	);

	INSERT INTO netblock_collection_netblock (
		netblock_collection_id, netblock_Id
	) VALUES (
		_hnc.netblock_collection_id, _nb2.netblock_id
	);

	RAISE NOTICE 'Testing to see if max_num_members works... ';
	BEGIN
		INSERT INTO netblock_collection_netblock (
			netblock_collection_id, netblock_Id
		) VALUES (
			_nc_onemem.netblock_collection_id, _nb1.netblock_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO netblock_collection_netblock (
		netblock_collection_id, netblock_Id
	) VALUES (
		_nc_onecol1.netblock_collection_id, _nb1.netblock_id
	);

	RAISE NOTICE 'Testing to see if max_num_collections works... ';
	BEGIN
		INSERT INTO netblock_collection_netblock (
			netblock_collection_id, netblock_Id
		) VALUES (
			_nc_onecol2.netblock_collection_id, _nb1.netblock_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Cleaning up...';

	delete from netblock_collection_netblock where netblock_collection_id
		IN (select netblock_collection_id FROM
		netblock_collection where netblock_collection_type like
		'JHTEST%');
	delete from netblock_collection where netblock_collection_type like
		'JHTEST%';
	delete from val_netblock_collection_type where 
		netblock_collection_type like
		'JHTEST%';
	delete from netblock where description like 'JHTEST%';
	RAISE NOTICE 'Netblock CollHier: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT netblock_coll_hier_regression();
-- set search_path=jazzhands;
DROP FUNCTION netblock_coll_hier_regression();

\t off
