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

SAVEPOINT device_coll_hier_regression_test;

-- \ir ../../ddl/schema/pgsql/create_device_coll_hier_triggers.sql
-- \ir ../../ddl/schema/pgsql/create_collection_bytype_triggers.sql

-- 
-- Trigger tests
--
CREATE OR REPLACE FUNCTION device_coll_hier_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_dc				device_collection%ROWTYPE;
	_dc_onecol		device_collection%ROWTYPE;
	_dc_onecol2		device_collection%ROWTYPE;
	__dc_onemem		device_collection%ROWTYPE;
	_hdc			device_collection%ROWTYPE;
	_dev1			device%ROWTYPE;
	_dev2			device%ROWTYPE;
BEGIN
	RAISE NOTICE 'device_coll_hier_regression: Cleanup Records from Previous Tests';
	delete from device_collection_device where
		device_collection_id in (
			select device_collection_id from device_collection
			where device_collection_name like 'JHTEST-%'
		);
	delete from device where
		site_code = 'JHTEST01';
	delete from device_collection where
		device_collection_name like 'JHTEST-%';
	delete from val_device_collection_Type where
		device_collection_Type like 'JHTEST-%';
	delete from site where site_code like 'JHTEST%';

	RAISE NOTICE '++ Inserting testing data';
	INSERT INTO site (site_code,site_status) values ('JHTEST01','ACTIVE');

	INSERT INTO val_device_collection_Type (
		device_collection_type, max_num_members
	) VALUES (
		'JHTEST-MEMS', 1
	);
	INSERT INTO val_device_collection_Type (
		device_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS', 1
	);
	INSERT INTO val_device_collection_Type (
		device_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS2', 1
	);

	INSERT INTO val_device_collection_Type (
		device_collection_type, can_have_hierarchy
	) VALUES (
		'JHTEST-HIER', 'N'
	);

	INSERT into device_collection (
		device_collection_name, device_collection_type
	) values (
		'JHTEST-cols-dc', 'JHTEST-COLS'
	) RETURNING * into _dc_onecol;

	INSERT into device_collection (
		device_collection_name, device_collection_type
	) values (
		'JHTEST-cols-dc-2', 'JHTEST-COLS'
	) RETURNING * into _dc_onecol2;

	INSERT into device_collection (
		device_collection_name, device_collection_type
	) values (
		'JHTEST-mems-dc', 'JHTEST-MEMS'
	) RETURNING * into __dc_onemem;

	RAISE NOTICE 'Making sure a by-coll-type works...';
	BEGIN
		SELECT count(*)
		INTO _tally
		FROM device_collection dc
			JOIN device_collection_hier h ON dc.device_collection_id =
				h.device_collection_id
		WHERE dc.device_collection_type = 'by-coll-type'
		AND dc.device_collection_NAME = 'JHTEST-COLS'
		AND h.child_device_collection_id IN (
			_dc_onecol.device_collection_id,
			_dc_onecol2.device_collection_id
		);
		IF _tally != 2 THEN
			RAISE '... failed with % != 2 rows!', _tally;
		END IF;

		SELECT count(*)
		INTO _tally
		FROM device_collection dc
			JOIN device_collection_hier h ON dc.device_collection_id =
				h.device_collection_id
		WHERE dc.device_collection_type = 'by-coll-type'
		AND dc.device_collection_NAME = 'JHTEST-COLS2'
		AND h.child_device_collection_id IN (
			_dc_onecol.device_collection_id,
			_dc_onecol2.device_collection_id
		);
		IF _tally != 0 THEN
			RAISE 'old type is not initialized right 0 != %', _tally;
		END IF;

		UPDATE device_collection
		SET device_collection_type = 'JHTEST-COLS2'
		WHERE device_collection_id = _dc_onecol.device_collection_id;

		SELECT count(*)
		INTO _tally
		FROM device_collection dc
			JOIN device_collection_hier h ON dc.device_collection_id =
				h.device_collection_id
		WHERE dc.device_collection_type = 'by-coll-type'
		AND dc.device_collection_NAME = 'JHTEST-COLS'
		AND h.child_device_collection_id IN (
			_dc_onecol.device_collection_id,
			_dc_onecol2.device_collection_id
		);
		IF _tally != 1 THEN
			RAISE 'old type failed with % != 1 rows!', _tally;
		END IF;

		SELECT count(*)
		INTO _tally
		FROM device_collection dc
			JOIN device_collection_hier h ON dc.device_collection_id =
				h.device_collection_id
		WHERE dc.device_collection_type = 'by-coll-type'
		AND dc.device_collection_NAME = 'JHTEST-COLS2'
		AND h.child_device_collection_id IN (
			_dc_onecol.device_collection_id,
			_dc_onecol2.device_collection_id
		);
		IF _tally != 1 THEN
			RAISE 'new type failed with % != 2 rows!', _tally;
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;


	RAISE NOTICE 'Testing to see if can_have_hierarachy works... ';
	INSERT into device_collection (
		device_collection_name, device_collection_type
	) values (
		'JHTEST-nohier', 'JHTEST-HIER'
	) RETURNING * into _hdc;

	INSERT INTO device (
		device_type_id, device_name, device_status, site_code,
		service_environment_id, operating_system_id
	) values (
		1, 'JHTEST one', 'up', 'JHTEST01',
		(select service_environment_id from service_environment
		where service_environment_name = 'production'),
		0
	) RETURNING * into _dev1;

	INSERT INTO device (
		device_type_id, device_name, device_status, site_code,
		service_environment_id, operating_system_id
	) values (
		1, 'JHTEST two', 'up', 'JHTEST01',
		(select service_environment_id from service_environment
		where service_environment_name = 'production'),
		0
	) RETURNING * into _dev2;

	RAISE NOTICE 'Testing to see if can_have_hierarachy works... ';
	BEGIN
		INSERT INTO device_collection_hier (
			device_collection_id, child_device_collection_id
		) VALUES (
			_hdc.device_collection_id, __dc_onemem.device_collection_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO device_collection_device (
		device_collection_id, device_Id
	) VALUES (
		_dc_onecol.device_collection_id, _dev1.device_id
	);

	INSERT INTO device_collection_device (
		device_collection_id, device_Id
	) VALUES (
		__dc_onemem.device_collection_id, _dev2.device_id
	);

	RAISE NOTICE 'Testing to see if max_num_members works... ';
	BEGIN
		INSERT INTO device_collection_device (
			device_collection_id, device_Id
		) VALUES (
			__dc_onemem.device_collection_id, _dev1.device_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Testing to see if max_num_collections works... ';
	BEGIN
		INSERT INTO device_collection_device (
			device_collection_id, device_Id
		) VALUES (
			_dc_onecol2.device_collection_id, _dev1.device_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Cleaning up...';
	delete from device_collection_device where
		device_collection_id in (
			select device_collection_id from device_collection
			where device_collection_name like 'JHTEST-%'
		);
	delete from device where
		site_code = 'JHTEST01';
	delete from device_collection where
		device_collection_name like 'JHTEST-%'
		and device_collection_type NOT IN ('by-coll-type');
	delete from val_device_collection_Type where
		device_collection_Type like 'JHTEST-%';
	delete from site where site_code like 'JHTEST%';

	RAISE NOTICE 'device_coll_hier_regression: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT device_coll_hier_regression();
DROP FUNCTION device_coll_hier_regression();

ROLLBACK TO device_coll_hier_regression_test;


\t off
