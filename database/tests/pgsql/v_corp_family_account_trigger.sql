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
CREATE OR REPLACE FUNCTION v_corp_family_account_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_ar			account_realm%ROWTYPE;
	_ac_onecol1		account_collection%ROWTYPE;
	_ac_onecol2		account_collection%ROWTYPE;
	__ac_onemem		account_collection%ROWTYPE;
	_hac			account_collection%ROWTYPE;
	_acc1			account%ROWTYPE;
	_acc2			account%ROWTYPE;
	_com			company%ROWTYPE;
	_pers1			person%ROWTYPE;
	_pers2			person%ROWTYPE;
BEGIN
	RAISE EXCEPTION 'Need to write these';
	RAISE NOTICE 'v_corp_family_account regression: BEGIN';
	RAISE NOTICE 'AcctCollHier: Cleanup Records from Previous Tests';
	delete from account_unix_info where
		account_id in (
			select account_id from account
			where login like 'jhtest%'
		);
	delete from account_collection_account where
		account_id in (
			select account_id from account
			where login like 'jhtest%'
		);
	delete from unix_group where account_collection_id in (
		select account_collection_id from account_collection where
		account_collection_type like 'JHTEST%'
		or account_collection_name like 'jhtest%');
	delete from account_collection where
		account_collection_type like 'JHTEST%'
		or account_collection_name like 'jhtest%';
	delete from val_account_collection_type where
		account_collection_type like 'JHTEST-%';
	delete from account where login like 'jhtest%';
	delete from person_account_realm_company where person_id in (
		select person_id 
		from person where first_name like 'Jazzhands%');
	delete from account_realm_company where company_id in (
		select company_id from company where company_name like 'JHTEST%');
	delete from person_company where person_id in (
		select person_id 
		from person where first_name like 'Jazzhands%');
	delete from person where first_name like 'Jazzhands%';
	delete from company where company_name like 'JHTEST%';
	delete from account_realm where account_realm_name like 'JHTEST%';

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
		'JHTEST-HIER', 'N'
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

	INSERT INTO company ( company_name, company_short_name,
		is_corporate_family )
		VALUES ('JHTEST, Inc', 'jhtest',
		'Y') RETURNING * into _com;

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

	INSERT INTO person_account_realm_company (
		person_id, company_Id, account_realm_id
	) values (
		_pers1.person_id, _com.company_id, _ar.account_realm_id);
	

	INSERT INTO person_account_realm_company (
		person_id, company_Id, account_realm_id
	) values (
		_pers2.person_id, _com.company_id, _ar.account_realm_id);
	

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

	RAISE NOTICE 'Cleaning up...';
	delete from account_unix_info where
		account_id in (
			select account_id from account
			where login like 'jhtest%'
		);
	delete from account_collection_account where
		account_id in (
			select account_id from account
			where login like 'jhtest%'
		);
	delete from unix_group where account_collection_id in (
		select account_collection_id from account_collection where
		account_collection_type like 'JHTEST%'
		or account_collection_name like 'jhtest%');
	delete from account_collection where
		account_collection_type like 'JHTEST%'
		or account_collection_name like 'jhtest%';
	delete from val_account_collection_type where
		account_collection_type like 'JHTEST-%';
	delete from account where login like 'jhtest%';
	delete from person_account_realm_company where person_id in (
		select person_id 
		from person where first_name like 'Jazzhands%');
	delete from account_realm_company where company_id in (
		select company_id from company where company_name like 'JHTEST%');
	delete from person_company where person_id in (
		select person_id 
		from person where first_name like 'Jazzhands%');
	delete from person where first_name like 'Jazzhands%';
	delete from company where company_name like 'JHTEST%';
	delete from account_realm where account_realm_name like 'JHTEST%';

	RAISE NOTICE 'v_corp_family_account regression: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT v_corp_family_account_regression();
-- set search_path=jazzhands;
DROP FUNCTION v_corp_family_account_regression();

\t off
