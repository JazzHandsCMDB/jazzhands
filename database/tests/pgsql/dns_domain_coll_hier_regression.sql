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
CREATE OR REPLACE FUNCTION dns_domain_coll_hier_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_nc_onecol1		dns_domain_collection%ROWTYPE;
	_nc_onecol2		dns_domain_collection%ROWTYPE;
	_nc_onemem		dns_domain_collection%ROWTYPE;
	_hnc			dns_domain_collection%ROWTYPE;
	_c1			dns_domain%ROWTYPE;
	_c2			dns_domain%ROWTYPE;
BEGIN
	RAISE NOTICE 'dns_domain_coll_hier_regression: Cleanup Records from Previous Tests';

	delete from dns_domain_collection_dns_dom where dns_domain_collection_id
		IN (select dns_domain_collection_id FROM
		dns_domain_collection where dns_domain_collection_type like
		'JHTEST%');
	delete from dns_domain_collection where dns_domain_collection_type like
		'JHTEST%';
	delete from val_dns_domain_collection_type where 
		dns_domain_collection_type like
		'JHTEST%';
	delete from dns_domain where soa_name like 'jhtest%example.com';

	RAISE NOTICE '++ Inserting testing data';
	INSERT INTO val_dns_domain_collection_Type (
		dns_domain_collection_type, max_num_members
	) VALUES (
		'JHTEST-MEMS', 1
	);
	INSERT INTO val_dns_domain_collection_Type (
		dns_domain_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS', 1
	);
	INSERT INTO val_dns_domain_collection_Type (
		dns_domain_collection_type, can_have_hierarchy
	) VALUES (
		'JHTEST-HIER', 'N'
	);

	INSERT into dns_domain_collection (
		dns_domain_collection_name, dns_domain_collection_type
	) values (
		'JHTEST-cols-nc', 'JHTEST-COLS'
	) RETURNING * into _nc_onecol1;

	INSERT into dns_domain_collection (
		dns_domain_collection_name, dns_domain_collection_type
	) values (
		'JHTEST-cols-nc-2', 'JHTEST-COLS'
	) RETURNING * into _nc_onecol2;

	INSERT into dns_domain_collection (
		dns_domain_collection_name, dns_domain_collection_type
	) values (
		'JHTEST-mems-nc', 'JHTEST-MEMS'
	) RETURNING * into _nc_onemem;

	INSERT into dns_domain_collection (
		dns_domain_collection_name, dns_domain_collection_type
	) values (
		'JHTEST-nohier', 'JHTEST-HIER'
	) RETURNING * into _hnc;

	------ Beginning of Collection specific stuff
	RAISE NOTICE 'Inserting collection specific records'; 

	INSERT INTO dns_domain (
		soa_name, soa_rname, should_generate, dns_domain_type
	) values (
		'jhtest1.example.com', 'rname', 'N', 'service'
	) RETURNING * into _c1;

	INSERT INTO dns_domain (
		soa_name, soa_rname, should_generate, dns_domain_type
	) values (
		'jhtest2.example.com', 'rname', 'N', 'service'
	) RETURNING * into _c2;

	RAISE NOTICE 'Starting tests...';

	RAISE NOTICE 'Testing to see if can_have_hierarachy works... ';
	BEGIN
		INSERT INTO dns_domain_collection_hier (
			dns_domain_collection_id, child_dns_domain_collection_id
		) VALUES (
			_hnc.dns_domain_collection_id, _nc_onemem.dns_domain_collection_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO dns_domain_collection_dns_dom (
		dns_domain_collection_id, dns_domain_Id
	) VALUES (
		_nc_onemem.dns_domain_collection_id, _c1.dns_domain_id
	);

	INSERT INTO dns_domain_collection_dns_dom (
		dns_domain_collection_id, dns_domain_Id
	) VALUES (
		_hnc.dns_domain_collection_id, _c2.dns_domain_id
	);

	RAISE NOTICE 'Testing to see if max_num_members works... ';
	BEGIN
		INSERT INTO dns_domain_collection_dns_dom (
			dns_domain_collection_id, dns_domain_Id
		) VALUES (
			_nc_onemem.dns_domain_collection_id, _c1.dns_domain_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO dns_domain_collection_dns_dom (
		dns_domain_collection_id, dns_domain_Id
	) VALUES (
		_nc_onecol1.dns_domain_collection_id, _c1.dns_domain_id
	);

	RAISE NOTICE 'Testing to see if max_num_collections works... ';
	BEGIN
		INSERT INTO dns_domain_collection_dns_dom (
			dns_domain_collection_id, dns_domain_Id
		) VALUES (
			_nc_onecol2.dns_domain_collection_id, _c1.dns_domain_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Cleaning up...';

	delete from dns_domain_collection_dns_dom where dns_domain_collection_id
		IN (select dns_domain_collection_id FROM
		dns_domain_collection where dns_domain_collection_type like
		'JHTEST%');
	delete from dns_domain_collection where dns_domain_collection_type like
		'JHTEST%';
	delete from val_dns_domain_collection_type where 
		dns_domain_collection_type like
		'JHTEST%';
	delete from dns_domain where soa_name like 'jhtest%example.com';
	RAISE NOTICE 'Netblock CollHier: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT dns_domain_coll_hier_regression();
-- set search_path=jazzhands;
DROP FUNCTION dns_domain_coll_hier_regression();

\t off
