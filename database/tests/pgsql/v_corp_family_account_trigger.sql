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
	_personid		person.person_id%type;
	_companyid		company.company_id%type;
	_defprop		property%rowtype;
	_acc_realm_id	account_realm.account_realm_id%type;
	_acc1			account%rowtype;
	_acc2			account%rowtype;
BEGIN
	RAISE NOTICE 'v_corp_family_account regression: BEGIN';
	RAISE NOTICE 'v_corp_family_account: Cleanup Records from Previous Tests';

	RAISE NOTICE 'v_corp_family_account: Adding prerequisites';

	INSERT INTO person (first_name, last_name)
		VALUES ('JH', 'TEST') RETURNING person_id INTO _personid;

	INSERT INTO company (company_name)
		VALUES ('JHTEST, Inc') RETURNING company_id into _companyid;

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

	RAISE NOTICE 'Testing insert into v_corp_family_account... ';
	INSERT INTO v_corp_family_account (
		login, person_id, company_id,
		account_realm_id, account_status, account_role, account_type
	) VALUES (
		_acc_realm_id, _personid, _companyid,
		_acc_realm_id, 'enabled', 'primary', 'person'
	);

	RAISE NOTICE 'Cleaning up...';

	RAISE NOTICE 'v_corp_family_account regression: DONE';
	RAISE EXCEPTION 'Need to write these';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT v_corp_family_account_regression();
-- set search_path=jazzhands;
DROP FUNCTION v_corp_family_account_regression();


\t off
