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

SAVEPOINT dns_domain_coll_hier_regression_test;

\ir ../../ddl/schema/pgsql/create_dns_domain_coll_hier_triggers.sql
\ir ../../ddl/schema/pgsql/create_collection_bytype_triggers.sql

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

	delete from dns_domain_collection_dns_domain where dns_domain_collection_id
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
		dns_domain_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS2', 1
	);
	INSERT INTO val_dns_domain_collection_Type (
		dns_domain_collection_type, can_have_hierarchy
	) VALUES (
		'JHTEST-HIER', false
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
		soa_name, dns_domain_type
	) values (
		'jhtest1.example.com', 'service'
	) RETURNING * into _c1;

	INSERT INTO dns_domain (
		soa_name, dns_domain_type
	) values (
		'jhtest2.example.com', 'service'
	) RETURNING * into _c2;

	RAISE NOTICE 'Starting tests...';

	RAISE NOTICE 'Making sure a by-coll-type works...';
	BEGIN
		SELECT count(*)
		INTO _tally
		FROM dns_domain_collection nc
			JOIN dns_domain_collection_hier h ON nc.dns_domain_collection_id =
				h.dns_domain_collection_id
		WHERE nc.dns_domain_collection_type = 'by-coll-type'
		AND nc.dns_domain_collection_NAME = 'JHTEST-COLS'
		AND h.child_dns_domain_collection_id IN (
			_nc_onecol1.dns_domain_collection_id,
			_nc_onecol2.dns_domain_collection_id
		);
		IF _tally != 2 THEN
			RAISE '... failed with % != 2 rows!', _tally;
		END IF;

		SELECT count(*)
		INTO _tally
		FROM dns_domain_collection nc
			JOIN dns_domain_collection_hier h ON nc.dns_domain_collection_id =
				h.dns_domain_collection_id
		WHERE nc.dns_domain_collection_type = 'by-coll-type'
		AND nc.dns_domain_collection_NAME = 'JHTEST-COLS2'
		AND h.child_dns_domain_collection_id IN (
			_nc_onecol1.dns_domain_collection_id,
			_nc_onecol2.dns_domain_collection_id
		);
		IF _tally != 0 THEN
			RAISE 'old type is not initialized right 0 != %', _tally;
		END IF;

		UPDATE dns_domain_collection
		SET dns_domain_collection_type = 'JHTEST-COLS2'
		WHERE dns_domain_collection_id = _nc_onecol1.dns_domain_collection_id;

		SELECT count(*)
		INTO _tally
		FROM dns_domain_collection nc
			JOIN dns_domain_collection_hier h ON nc.dns_domain_collection_id =
				h.dns_domain_collection_id
		WHERE nc.dns_domain_collection_type = 'by-coll-type'
		AND nc.dns_domain_collection_NAME = 'JHTEST-COLS'
		AND h.child_dns_domain_collection_id IN (
			_nc_onecol1.dns_domain_collection_id,
			_nc_onecol2.dns_domain_collection_id
		);
		IF _tally != 1 THEN
			RAISE 'old type failed with % != 1 rows!', _tally;
		END IF;

		SELECT count(*)
		INTO _tally
		FROM dns_domain_collection nc
			JOIN dns_domain_collection_hier h ON nc.dns_domain_collection_id =
				h.dns_domain_collection_id
		WHERE nc.dns_domain_collection_type = 'by-coll-type'
		AND nc.dns_domain_collection_NAME = 'JHTEST-COLS2'
		AND h.child_dns_domain_collection_id IN (
			_nc_onecol1.dns_domain_collection_id,
			_nc_onecol2.dns_domain_collection_id
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
		INSERT INTO dns_domain_collection_hier (
			dns_domain_collection_id, child_dns_domain_collection_id
		) VALUES (
			_hnc.dns_domain_collection_id, _nc_onemem.dns_domain_collection_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO dns_domain_collection_dns_domain (
		dns_domain_collection_id, dns_domain_Id
	) VALUES (
		_nc_onemem.dns_domain_collection_id, _c1.dns_domain_id
	);

	INSERT INTO dns_domain_collection_dns_domain (
		dns_domain_collection_id, dns_domain_Id
	) VALUES (
		_hnc.dns_domain_collection_id, _c2.dns_domain_id
	);

	RAISE NOTICE 'Testing to see if max_num_members works... ';
	BEGIN
		INSERT INTO dns_domain_collection_dns_domain (
			dns_domain_collection_id, dns_domain_Id
		) VALUES (
			_nc_onemem.dns_domain_collection_id, _c1.dns_domain_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO dns_domain_collection_dns_domain (
		dns_domain_collection_id, dns_domain_Id
	) VALUES (
		_nc_onecol1.dns_domain_collection_id, _c1.dns_domain_id
	);

	RAISE NOTICE 'Testing to see if max_num_collections works... ';
	BEGIN
		INSERT INTO dns_domain_collection_dns_domain (
			dns_domain_collection_id, dns_domain_Id
		) VALUES (
			_nc_onecol2.dns_domain_collection_id, _c1.dns_domain_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Cleaning up...';

	delete from dns_domain_collection_dns_domain where dns_domain_collection_id
		IN (select dns_domain_collection_id FROM
		dns_domain_collection where dns_domain_collection_type like
		'JHTEST%');
	delete from dns_domain_collection where dns_domain_collection_type like
		'JHTEST%' and dns_domain_collection_type NOT IN ('by-coll-type');
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

ROLLBACK TO dns_domain_coll_hier_regression_test;

\t off
