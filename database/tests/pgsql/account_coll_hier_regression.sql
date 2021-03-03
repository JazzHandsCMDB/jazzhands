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

SAVEPOINT acct_coll_regression_tests;

\ir ../../ddl/schema/pgsql/create_account_coll_hier_triggers.sql
\ir ../../ddl/schema/pgsql/create_account_coll_hook_triggers.sql
\ir ../../ddl/schema/pgsql/create_account_coll_realm_triggers.sql
\ir ../../ddl/schema/pgsql/create_account_coll_relation_triggers.sql
\ir ../../ddl/schema/pgsql/create_acct_coll_report_triggers.sql
\ir ../../ddl/schema/pgsql/create_auto_account_coll_triggers.sql
\ir ../../ddl/schema/pgsql/create_v_corp_family_account_triggers.sql

-- This needs to be better thought out with account_realm restrictions.
-- \ir ../../ddl/schema/pgsql/create_collection_bytype_triggers.sql

SET jazzhands.permit_company_insert = 'permit';

-- 
-- Trigger tests
--
CREATE OR REPLACE FUNCTION account_coll_hier_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_ar			account_realm%ROWTYPE;
	_ac_onecol1		account_collection%ROWTYPE;
	_ac_onecol2		account_collection%ROWTYPE;
	__ac_onemem		account_collection%ROWTYPE;
	_ac1			account_collection%ROWTYPE;
	_ac2			account_collection%ROWTYPE;
	_ac3			account_collection%ROWTYPE;
	_hac			account_collection%ROWTYPE;
	_acc1			account%ROWTYPE;
	_acc2			account%ROWTYPE;
	_acc3			account%ROWTYPE;
	_com			company%ROWTYPE;
	_pers1			person%ROWTYPE;
	_pers2			person%ROWTYPE;
	_pers3			person%ROWTYPE;
BEGIN
	RAISE NOTICE 'account_coll_hier_regression: Startup';

	RAISE NOTICE '++ Inserting testing data';
	INSERT INTO account_realm (account_realm_name) values('JHTESTREALM')
		RETURNING * into _ar;

	INSERT INTO val_account_collection_Type (
		account_collection_type, max_num_members
	) VALUES (
		'JHTEST-MEMS', 1
	);
	INSERT INTO val_account_collection_Type (
		account_collection_type, max_num_collections
	) VALUES (
		'JHTEST-COLS', 1
	);
	INSERT INTO val_account_collection_Type (
		account_collection_type, can_have_hierarchy
	) VALUES (
		'JHTEST-HIER', false
	);

	INSERT into account_collection (
		account_collection_name, account_collection_type
	) values (
		'JHTEST-cols-ac', 'JHTEST-COLS'
	) RETURNING * into _ac_onecol1;

	INSERT into account_collection (
		account_collection_name, account_collection_type
	) values (
		'JHTEST-cols-ac-2', 'JHTEST-COLS'
	) RETURNING * into _ac_onecol2;

	INSERT into account_collection (
		account_collection_name, account_collection_type
	) values (
		'JHTEST-mems-ac', 'JHTEST-MEMS'
	) RETURNING * into __ac_onemem;

	INSERT into account_collection (
		account_collection_name, account_collection_type
	) values (
		'JHTEST-nohier', 'JHTEST-HIER'
	) RETURNING * into _hac;

	INSERT INTO company ( company_name, company_short_name
		) VALUES ('JHTEST, Inc', 'jhtest'
		) RETURNING * into _com;

	INSERT INTO account_realm_company (
		account_realm_id, company_id) values (
		_ar.account_realm_id, _com.company_id);

	INSERT INTO person (
		first_name, last_name 
	) values (
		'Jazzhandseth', 'Testus'
	) returning * into _pers1;

	INSERT INTO person (
		first_name, last_name 
	) values (
		'Jazzhandseth', 'Testus'
	) returning * into _pers2;

	INSERT INTO person (
		first_name, last_name 
	) values (
		'Jazzhandius', 'Testus'
	) returning * into _pers3;

	INSERT INTO person_company (
		company_id, person_id, person_company_relation,
		person_company_status
	) values (
		_com.company_id, _pers1.person_id, 'employee',
		'enabled');

	INSERT INTO person_company (
		company_id, person_id, person_company_relation,
		person_company_status
	) values (
		_com.company_id, _pers2.person_id, 'employee',
		'enabled');

	INSERT INTO person_company (
		company_id, person_id, person_company_relation,
		person_company_status
	) values (
		_com.company_id, _pers3.person_id, 'employee',
		'enabled');

	INSERT INTO person_account_realm_company (
		person_id, company_Id, account_realm_id
	) values (
		_pers1.person_id, _com.company_id, _ar.account_realm_id);
	

	INSERT INTO person_account_realm_company (
		person_id, company_Id, account_realm_id
	) values (
		_pers2.person_id, _com.company_id, _ar.account_realm_id);

	INSERT INTO person_account_realm_company (
		person_id, company_Id, account_realm_id
	) values (
		_pers3.person_id, _com.company_id, _ar.account_realm_id);
	
	INSERT INTO account (login, person_id, company_id,
		account_realm_id, account_status, account_role, account_type)
	values (
		'jhtest01', _pers1.person_id, _com.company_id,
		_ar.account_realm_id, 'enabled', 'primary', 'person')
		RETURNING * INTO _acc1;

	INSERT INTO account (login, person_id, company_id,
		account_realm_id, account_status, account_role, account_type)
	values (
		'jhtest02', _pers2.person_id, _com.company_id,
		_ar.account_realm_id, 'enabled', 'primary', 'person')
		RETURNING * INTO _acc2;

	INSERT INTO account (login, person_id, company_id,
		account_realm_id, account_status, account_role, account_type)
	values (
		'jhtest03', _pers3.person_id, _com.company_id,
		_ar.account_realm_id, 'enabled', 'primary', 'person')
		RETURNING * INTO _acc3;

	RAISE NOTICE 'Testing to see if can_have_hierarachy works... ';
	BEGIN
		INSERT INTO account_collection_hier (
			account_collection_id, child_account_collection_id
		) VALUES (
			_hac.account_collection_id, __ac_onemem.account_collection_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	INSERT INTO account_collection_account (
		account_collection_id, account_Id
	) VALUES (
		_ac_onecol1.account_collection_id, _acc1.account_id
	);

	INSERT INTO account_collection_account (
		account_collection_id, account_Id
	) VALUES (
		__ac_onemem.account_collection_id, _acc2.account_id
	);

	RAISE NOTICE 'Testing to see if max_num_members works... ';
	BEGIN
		INSERT INTO account_collection_account (
			account_collection_id, account_Id
		) VALUES (
			__ac_onemem.account_collection_id, _acc1.account_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Testing to see if max_num_collections works... ';
	BEGIN
		INSERT INTO account_collection_account (
			account_collection_id, account_Id
		) VALUES (
			_ac_onecol2.account_collection_id, _acc1.account_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if relation member restictions fail as expected... ';
	BEGIN
		INSERT INTO val_account_collection_relation (
			account_collection_relation
		) VALUES (
			'indirect'
		);

		WITH type AS (
			INSERT INTO val_account_collection_type (
				account_collection_type
			) VALUES (
				'jhtesty'
			) RETURNING *
		) INSERT INTO account_collection_type_relation (
				account_collection_type, account_collection_relation
			) SELECT account_collection_type, 'indirect'
		FROM type;

		UPDATE account_collection_type_relation
		SET max_num_members = 1
		WHERE account_collection_relation = 'direct';

		INSERT INTO account_collection (
			account_collection_name, account_collection_type
		) VALUES (
			'jhtest-01', 'jhtesty'
		) RETURNING * INTO _ac1;
		INSERT INTO account_collection (
			account_collection_name, account_collection_type
		) VALUES (
			'jhtest-02', 'jhtesty'
		) RETURNING * INTO _ac2;
		INSERT INTO account_collection (
			account_collection_name, account_collection_type
		) VALUES (
			'jhtest-03', 'jhtesty'
		) RETURNING * INTO _ac3;

		INSERT INTO account_collection_account (
			account_collection_id, account_collection_relation, account_id
		) VALUES (
			_ac1.account_collection_id, 'direct', _acc1.account_id
		);
		INSERT INTO account_collection_account (
			account_collection_id, account_collection_relation, account_id
		) VALUES (
			_ac2.account_collection_id, 'indirect', _acc1.account_id
		);

		BEGIN
			INSERT INTO account_collection_account (
				account_collection_id, account_collection_relation, account_id
			) VALUES (
				_ac3.account_collection_id, 'direct', _acc1.account_id
			);
			RAISE EXCEPTION 'direct num members check failed!';
		EXCEPTION WHEN unique_violation THEN
			RAISE NOTICE 'direct num members check passed';
		END;

		INSERT INTO account_collection_account (
			account_collection_id, account_collection_relation, account_id
		) VALUES (
			_ac3.account_collection_id, 'indirect', _acc1.account_id
		);

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Checking if relation collection restictions fail as expected... ';
	BEGIN
		INSERT INTO val_account_collection_relation (
			account_collection_relation
		) VALUES (
			'indirect'
		);

		WITH type AS (
			INSERT INTO val_account_collection_type (
				account_collection_type
			) VALUES (
				'jhtesty'
			) RETURNING *
		) INSERT INTO account_collection_type_relation (
				account_collection_type, account_collection_relation
			) SELECT account_collection_type, 'indirect'
		FROM type;

		UPDATE account_collection_type_relation
		SET max_num_collections = 1
		WHERE account_collection_relation = 'indirect';

		INSERT INTO account_collection (
			account_collection_name, account_collection_type
		) VALUES (
			'jhtest-01', 'jhtesty'
		) RETURNING * INTO _ac1;
		INSERT INTO account_collection (
			account_collection_name, account_collection_type
		) VALUES (
			'jhtest-02', 'jhtesty'
		) RETURNING * INTO _ac2;
		INSERT INTO account_collection (
			account_collection_name, account_collection_type
		) VALUES (
			'jhtest-03', 'jhtesty'
		) RETURNING * INTO _ac3;

		INSERT INTO account_collection_account (
			account_collection_id, account_collection_relation, account_id
		) VALUES (
			_ac1.account_collection_id, 'indirect', _acc1.account_id
		);

		BEGIN
			INSERT INTO account_collection_account (
				account_collection_id, account_collection_relation, account_id
			) VALUES (
				_ac3.account_collection_id, 'indirect', _acc1.account_id
			);
			RAISE EXCEPTION 'direct num collections check failed!';
		EXCEPTION WHEN unique_violation THEN
			RAISE NOTICE 'direct num members check passed';
		END;

		INSERT INTO account_collection_account (
			account_collection_id, account_collection_relation, account_id
		) VALUES (
			_ac3.account_collection_id, 'direct', _acc1.account_id
		);

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;


	RAISE NOTICE 'account_coll_hier_regression: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT account_coll_hier_regression();
-- set search_path=jazzhands;
DROP FUNCTION account_coll_hier_regression();

SET jazzhands.permit_company_insert TO default;

ROLLBACK TO acct_coll_regression_tests;

\t off
