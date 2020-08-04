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

SAVEPOINT account_enabled_test;
SET jazzhands.permit_company_insert = 'permit';


-- 
-- Trigger tests
--
CREATE OR REPLACE FUNCTION account_is_enabled_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_ar				account_realm%ROWTYPE;
	_tac			account%ROWTYPE;
	_acc1			account%ROWTYPE;
	_acc2			account%ROWTYPE;
	_ta				account%ROWTYPE;
	_com			company%ROWTYPE;
	_pers1			person%ROWTYPE;
	_pers2			person%ROWTYPE;
BEGIN
	RAISE NOTICE 'AcctIsEnabled: Cleanup Records from Previous Tests';
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


	INSERT INTO company ( company_name, company_short_name)
		VALUES ('JHTEST, Inc', 'jhtest' )
		RETURNING * into _com;

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
		'Jazzhandseth', 'Testington'
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

	RAISE NOTICE 'Testing to see if propagation from person works... ';
	UPDATE person_company set person_company_status = 'autoterminated'
	WHERE person_id = _acc1.person_id
	AND company_id = _acc1.company_id;

	SELECT * INTO _tac FROM account where account_id = _acc1.account_id;
	IF _tac.account_status != 'autoterminated' OR _tac.is_enabled != false THEN
		RAISE EXCEPTION 'status did not propagate: %/%',
			_tac.account_status, _tac.is_enabled;
	END IF;
	RAISE NOTICE '... It does';

	RAISE NOTICE 'Undoing last step...';
	UPDATE person_company set person_company_status = 'enabled'
	WHERE person_id = _acc1.person_id
	AND company_id = _acc1.company_id;

	SELECT * INTO _tac FROM account where account_id = _acc1.account_id;
	IF _tac.account_status != 'enabled' OR _tac.is_enabled != true THEN
		RAISE EXCEPTION 'status did not propagate: %/%',
			_tac.account_status, _tac.is_enabled;
	END IF;
	RAISE NOTICE '... It still does';

	RAISE NOTICE 'Checking to see if is_enabled is immutable... ';
	BEGIN
		UPDATE account set is_enabled = false WHERE account_id =
			_acc1.account_id;
		RAISE EXCEPTION '... IT IS NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It is';
	END;

	RAISE NOTICE 'Checking to see if accounts can be inserted with bad is_enabled... ';
	BEGIN
		INSERT INTO account (login, person_id, company_id,
			account_realm_id, account_status, account_role, account_type,
			is_enabled)
		values (
			'jhtest02', _pers2.person_id, _com.company_id,
			_ar.account_realm_id, 'enabled', 'primary', 'person',
			false);
		RAISE EXCEPTION '... THEY CAN.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... They can''t';
	END;

	RAISE NOTICE 'AcctIsEnabled: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT account_is_enabled_regression();
-- set search_path=jazzhands;
DROP FUNCTION account_is_enabled_regression();

SET jazzhands.permit_company_insert TO default;
ROLLBACK TO account_enabled_test;

\t off
