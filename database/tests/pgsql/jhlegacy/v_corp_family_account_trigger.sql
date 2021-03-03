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

SAVEPOINT begin_v_corp_family_account_regression;

\ir  ../../../ddl/schema/pgsql/create_account_triggers.sql
\ir  ../../../ddl/schema/pgsql/create_v_corp_family_account_triggers.sql

\t on

SET search_path=jazzhands_legacy;

-- 
-- Trigger tests
--
CREATE OR REPLACE FUNCTION v_corp_family_account_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_personid		person.person_id%type;
	_companyid		company.company_id%type;
	_defprop		property%rowtype;
	_acc_realm_id	account_realm.account_realm_id%type;
	_acc1			account%rowtype;
	_acc2			account%rowtype;
	_r			RECORD;
BEGIN
	RAISE NOTICE 'v_corp_family_account regression: BEGIN';
	RAISE NOTICE 'v_corp_family_account: Cleanup Records from Previous Tests';

	RAISE NOTICE 'v_corp_family_account: Adding prerequisites';

	INSERT INTO person (first_name, last_name)
		VALUES ('JH', 'TEST') RETURNING person_id INTO _personid;

	SELECT company_manip.add_company (
		_company_name   := 'JHTEST, Inc',
		_company_types  := ARRAY['corporate family']
	) INTO _companyid;

	INSERT INTO person_company (
		company_id,
		person_id,
		person_company_status,
		person_company_relation
	) VALUES (
		_companyid,
		_personid,
		'enabled',
		'employee'
	);

	SELECT account_realm_id
	INTO	_acc_realm_id
	FROM	property
	WHERE	property_name = '_root_account_realm_id'
	AND		property_type = 'Defaults';

	if _acc_realm_id IS NULL THEN
		INSERT INTO account_realm (account_realm_name)
			VALUES ('JHTEST-AR') 
		RETURNING account_realm_id INTO _acc_realm_id;
		insert into property (
				property_name, property_type, account_realm_id
		) VALUES  (
			'_root_account_realm_id', 'Defaults', _acc_realm_id
		) RETURNING account_realm_id INTO _acc_realm_id;
	END IF;

	INSERT INTO account_realm_company (
		account_realm_id, company_id
	) VALUES (
		_acc_realm_id, _companyid
	);

	INSERT INTO person_account_realm_company (
		person_id, company_id, account_realm_id
	) VALUES (
		_personid, _companyid, _acc_realm_id
	);

	RAISE NOTICE 'Testing insert into v_corp_family_account... ';
	INSERT INTO v_corp_family_account (
		login, person_id, company_id,
		account_realm_id, account_status, account_role, account_type,
		is_enabled
	) VALUES (
		'jhtest01', _personid, _companyid,
		_acc_realm_id, 'enabled', 'primary', 'person',
		'Y'
	) RETURNING * INTO _acc1;

	RAISE NOTICE 'Cleaning up...';

	-- rethink this because unix-groups and whatnot tie in.
	RAISE NOTICE 'Changing login...';
	UPDATE v_corp_family_account
		SET login = 'somethingelse'
		WHERE account_id = _acc1.account_id RETURNING * INTO _acc1;
	SELECT * INTO _acc2 FROM account WHERE account_id = _acc1.account_id;
	IF _acc1 != _acc2 THEN
		RAISE NOTICE 'account does not match after update % %',
			to_json(_acc1), to_json(_acc2);
	END IF;

	RAISE NOTICE 'Changing status...';
	UPDATE v_corp_family_account
		SET account_status = 'disabled'
		WHERE account_id = _acc1.account_id RETURNING * INTO _acc1;
	SELECT * INTO _acc2 FROM account WHERE account_id = _acc1.account_id;
	IF _acc1 != _acc2 THEN
		RAISE NOTICE 'account does not match after update % %',
			to_json(_acc1), to_json(_acc2);
	END IF;

	RAISE NOTICE 'Cleaning up...';

	-- unix stuff breaks this
	-- DELETE FROM v_corp_family_account WHERE account_id = _acc1.account_id;

	RAISE NOTICE 'v_corp_family_account regression: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT v_corp_family_account_regression();
-- set search_path=jazzhands;
DROP FUNCTION v_corp_family_account_regression();

ROLLBACK TO begin_v_corp_family_account_regression;


\t off
