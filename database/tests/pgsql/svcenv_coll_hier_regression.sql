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
CREATE OR REPLACE FUNCTION service_env_coll_hier_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_sc_onecol1		service_environment_collection%ROWTYPE;
	_sc_onecol2		service_environment_collection%ROWTYPE;
	_sc_onemem		service_environment_collection%ROWTYPE;
	_hsc			service_environment_collection%ROWTYPE;
	_svcenv1			service_environment%ROWTYPE;
	_svcenv2			service_environment%ROWTYPE;
BEGIN
	RAISE NOTICE 'Service EnvCollHier: Cleanup Records from Previous Tests';

	delete from svc_environment_coll_svc_env where service_env_collection_id
		IN (select service_env_collection_id FROM
		service_environment_collection where service_env_collection_name like
		'JHTEST%');

	delete from service_environment_collection where service_env_collection_type like
		'JHTEST%';
	delete from val_service_env_coll_type where 
		service_env_collection_type like
		'JHTEST%';
	delete from service_environment where service_environment like 'JHTEST%';

	RAISE NOTICE '++ Inserting testing data';
	INSERT INTO val_service_env_coll_type (
		service_env_collection_type, max_num_members
	) VALUES (
		'JHTEST-MEMS', 1
	);
	INSERT INTO val_service_env_coll_type (
		service_env_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS', 1
	);
	INSERT INTO val_service_env_coll_type (
		service_env_collection_type, can_have_hierarchy
	) VALUES (
		'JHTEST-HIER', 'N'
	);

	INSERT into service_environment_collection (
		service_env_collection_name, service_env_collection_type
	) values (
		'JHTEST-cols-tc', 'JHTEST-COLS'
	) RETURNING * into _sc_onecol1;

	INSERT into service_environment_collection (
		service_env_collection_name, service_env_collection_type
	) values (
		'JHTEST-cols-tc-2', 'JHTEST-COLS'
	) RETURNING * into _sc_onecol2;

	INSERT into service_environment_collection (
		service_env_collection_name, service_env_collection_type
	) values (
		'JHTEST-mems-tc', 'JHTEST-MEMS'
	) RETURNING * into _sc_onemem;

	INSERT into service_environment_collection (
		service_env_collection_name, service_env_collection_type
	) values (
		'JHTEST-nohier', 'JHTEST-HIER'
	) RETURNING * into _hsc;

	------ Beginning of Collection specific stuff
	RAISE NOTICE 'Inserting collection specific records'; 

	insert into service_environment (service_environment,production_state) 
		values('JHTEST01', 'production') RETURNING * into _svcenv1;
	insert into service_environment (service_environment,production_state) 
		values('JHTEST02', 'production') RETURNING * into _svcenv2;
	RAISE NOTICE 'Starting tests...';

	RAISE NOTICE 'Testing to see if can_have_hierarachy works... ';
	BEGIN
		INSERT INTO service_environment_coll_hier (
			service_env_collection_id, child_service_env_coll_id
		) VALUES (
			_hsc.service_env_collection_id, _sc_onemem.service_env_collection_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO svc_environment_coll_svc_env (
		service_env_collection_id, service_environment
	) VALUES (
		_sc_onemem.service_env_collection_id, _svcenv1.service_environment
	);

	INSERT INTO svc_environment_coll_svc_env (
		service_env_collection_id, service_environment
	) VALUES (
		_hsc.service_env_collection_id, _svcenv2.service_environment
	);

	RAISE NOTICE 'Testing to see if max_num_members works... ';
	BEGIN
		INSERT INTO svc_environment_coll_svc_env (
			service_env_collection_id, service_environment
		) VALUES (
			_sc_onemem.service_env_collection_id, _svcenv1.service_environment
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO svc_environment_coll_svc_env (
		service_env_collection_id, service_environment
	) VALUES (
		_sc_onecol1.service_env_collection_id, _svcenv1.service_environment
	);

	RAISE NOTICE 'Testing to see if max_num_collections works... ';
	BEGIN
		INSERT INTO svc_environment_coll_svc_env (
			service_env_collection_id, service_environment
		) VALUES (
			_sc_onecol2.service_env_collection_id, _svcenv1.service_environment
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Cleaning up...';

	RAISE NOTICE 'Service EnvCollHier: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT service_env_coll_hier_regression();
-- set search_path=jazzhands;
DROP FUNCTION service_env_coll_hier_regression();

\t off
