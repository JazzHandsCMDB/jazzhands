-- Copyright (c) 2016 Todd Kover
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
SAVEPOINT realm_test;
SET jazzhands.permit_company_insert = 'permit';


-- 
-- Trigger tests
--
CREATE OR REPLACE FUNCTION account_coll_realm_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_ar1			account_realm%ROWTYPE;
	_ar2			account_realm%ROWTYPE;
	_at1			val_account_collection_type%ROWTYPE;
	_at2			val_account_collection_type%ROWTYPE;
	_at				val_account_collection_type%ROWTYPE;
	_ac1			account_collection%ROWTYPE;
	_ac11			account_collection%ROWTYPE;
	_ac2			account_collection%ROWTYPE;
	_ac22			account_collection%ROWTYPE;
	_ac				account_collection%ROWTYPE;
	_acc			account_collection%ROWTYPE;
	_com			company;
	_pers1			person%ROWTYPE;
	_pers2			person%ROWTYPE;
	_acc1			account%ROWTYPE;
	_acc2			account%ROWTYPE;
BEGIN
	RAISE NOTICE 'account_coll_realm_regression: Cleanup Records from Previous Tests';

	RAISE NOTICE 'INSERTING TEST DATA';
	INSERT INTO account_realm (account_realm_name) values ('Realm 1')
		RETURNING * INTO _ar1;
	INSERT INTO account_realm (account_realm_name) values ('Realm 2')
		RETURNING * INTO _ar2;

	INSERT INTO val_account_collection_type (
		account_collection_type, account_realm_id
	) VALUES ( 'type1', _ar1.account_realm_id) RETURNING * INTO _at1;
	INSERT INTO val_account_collection_type (
		account_collection_type, account_realm_id
	) VALUES ( 'type2', _ar2.account_realm_id) RETURNING * INTO _at2;
	INSERT INTO val_account_collection_type (
		account_collection_type
	) VALUES ( 'notype') RETURNING * INTO _at;

	INSERT INTO account_collection (
		account_collection_name, account_collection_type
	) VALUES ( 'ac1', _at1.account_collection_type) RETURNING * INTO _ac1;
	INSERT INTO account_collection (
		account_collection_name, account_collection_type
	) VALUES ( 'ac11', _at1.account_collection_type) RETURNING * INTO _ac11;
	INSERT INTO account_collection (
		account_collection_name, account_collection_type
	) VALUES ( 'ac2', _at2.account_collection_type) RETURNING * INTO _ac2;
	INSERT INTO account_collection (
		account_collection_name, account_collection_type
	) VALUES ( 'ac22', _at2.account_collection_type) RETURNING * INTO _ac22;
	INSERT INTO account_collection (
		account_collection_name, account_collection_type
	) VALUES ( 'acn', _at.account_collection_type) RETURNING * INTO _ac;
	INSERT INTO account_collection (
		account_collection_name, account_collection_type
	) VALUES ( 'acn2', _at.account_collection_type) RETURNING * INTO _acc;

	---------------------------------------------------------------------------

	INSERT INTO company ( company_name, company_short_name)
		VALUES ('JHTEST, Inc', 'jhtest' )
		RETURNING * into _com;

	INSERT INTO account_realm_company (
		account_realm_id, company_id) values (
		_ar1.account_realm_id, _com.company_id);

	INSERT INTO account_realm_company (
		account_realm_id, company_id) values (
		_ar2.account_realm_id, _com.company_id);

	INSERT INTO person (
		first_name, last_name
	) values (
		'Jazzhandseth', 'Testington'
	) returning * into _pers1;
	INSERT INTO person_company (
		company_id, person_id, person_company_relation, person_company_status
	) values (
		_com.company_id, _pers1.person_id, 'employee', 'enabled');
	INSERT INTO person_account_realm_company (
		person_id, company_Id, account_realm_id
	) values (
		_pers1.person_id, _com.company_id, _ar1.account_realm_id);
	INSERT INTO account (login, person_id, company_id,
		account_realm_id, account_status, account_role, account_type)
	values (
		'jhtest01', _pers1.person_id, _com.company_id,
		_ar1.account_realm_id, 'enabled', 'primary', 'person')
		RETURNING * INTO _acc1;

	INSERT INTO person (
		first_name, last_name
	) values (
		'Jazzhandseth', 'Testington'
	) returning * into _pers2;
	INSERT INTO person_company (
		company_id, person_id, person_company_relation, person_company_status
	) values (
		_com.company_id, _pers2.person_id, 'employee', 'enabled');
	INSERT INTO person_account_realm_company (
		person_id, company_Id, account_realm_id
	) values (
		_pers2.person_id, _com.company_id, _ar2.account_realm_id);
	INSERT INTO account (login, person_id, company_id,
		account_realm_id, account_status, account_role, account_type)
	values (
		'jhtest02', _pers2.person_id, _com.company_id,
		_ar2.account_realm_id, 'enabled', 'primary', 'person')
		RETURNING * INTO _acc2;


	---------------------------------------------------------------------------
	RAISE NOTICE 'DONE: INSERTING TEST DATA';

	RAISE NOTICE 'Testing if realm mismatches work... ';
	BEGIN
		INSERT INTO account_collection_hier (
			account_collection_id, child_account_collection_id
		) VALUES (
			_ac1.account_collection_id, _ac2.account_collection_id
		);
		RAISE EXCEPTION '... They do when they should not';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '..  They do not';
	END;

	RAISE NOTICE 'Testing if realm mismatches with NULL parent work... ';
	BEGIN
		INSERT INTO account_collection_hier (
			account_collection_id, child_account_collection_id
		) VALUES (
			_ac.account_collection_id, _ac2.account_collection_id
		);
		RAISE EXCEPTION '... They do when they should not';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '..  They do not';
	END;

	RAISE NOTICE 'Testing if realm mismatches with NULL child work... ';
	BEGIN
		INSERT INTO account_collection_hier (
			account_collection_id, child_account_collection_id
		) VALUES (
			_ac1.account_collection_id, _ac.account_collection_id
		);
		RAISE EXCEPTION '... They do when they should not';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '..  They do not';
	END;

	RAISE NOTICE 'Testing to see if matching realm ids work...';
	INSERT INTO account_collection_hier (
		account_collection_id, child_account_collection_id
	) VALUES (
		_ac1.account_collection_id, _ac11.account_collection_id
	);
	RAISE NOTICE '..  They DO!';

	RAISE NOTICE 'Testing to see if no realms ids work...';
	INSERT INTO account_collection_hier (
		account_collection_id, child_account_collection_id
	) VALUES (
		_ac.account_collection_id, _acc.account_collection_id
	);
	RAISE NOTICE '..  They DO!';

	---------------------------------------------------------------------------
	RAISE NOTICE 'Checking to see if accounts can insert in matched realm collections';
	INSERT INTO account_collection_account (
		account_collection_id, account_id
	) VALUES (
		_ac1.account_collection_id, _acc1.account_id
	);
	RAISE NOTICE 'They can!';

	RAISE NOTICE 'Checking to see if accounts can insert in mis-matched realm collections';
	BEGIN
		INSERT INTO account_collection_account (
			account_collection_id, account_id
		) VALUES (
			_ac1.account_collection_id, _acc2.account_id
		);
		RAISE EXCEPTION '... THEY CAN!  DOH!';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE 'They can not!';
	END;

	RAISE NOTICE 'Checking to see if accounts can insert in non-realm collections';
	INSERT INTO account_collection_account (
		account_collection_id, account_id
	) VALUES (
		_ac.account_collection_id, _acc1.account_id
	);
	RAISE NOTICE '... THEY CAN!';

	DELETE FROM account_collection_account
	WHERE account_collection_id = _ac.account_collection_id
	AND account_id = _acc1.account_id;

	RAISE NOTICE 'Checking to see account realms can move when they mismatch the collection ream...';
	BEGIN
		UPDATE account
		SET account_realm_id = _ar2.account_realm_id
		WHERE account_id = _acc1.account_id;
		RAISE EXCEPTION '... THEY CAN!  DOH!';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE 'They can not!';
	END;

	RAISE NOTICE 'Checking to see accounts can change to ignore collection realm restriction';
	BEGIN
		UPDATE account_collection_account
		SET account_id = _acc2.account_id
		WHERE account_id = _acc1.account_id
		AND account_collection_id = _ac1.account_collection_id;
		RAISE EXCEPTION '... THEY CAN!  DOH!';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE 'They can not!';
	END;

	RAISE NOTICE 'Checking to see accounts can change to ignore realm restriction';
	UPDATE account_collection_account
	SET account_collection_id = _ac.account_collection_id
	WHERE account_id = _acc1.account_id
	AND account_collection_id = _ac1.account_collection_id;
	RAISE NOTICE '... THEY CAN!';

	---------------------------------------------------------------------------
	RAISE NOTICE 'Checking to see if type change account mismatch can happen...';
	BEGIN
		UPDATE account_collection
		SET account_collection_type = _ac2.account_collection_type
		WHERE account_collection_id = _ac.account_collection_id;
		RAISE EXCEPTION '... They can, doh!';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE 'They can not!';
	END;

	RAISE NOTICE 'Checking to see if type change hier mismatch can happen...';
	BEGIN
		UPDATE account_collection
		SET account_collection_type = _ac2.account_collection_type
		WHERE account_collection_id = _ac11.account_collection_id;
		RAISE EXCEPTION '... They can, doh!';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE 'They can not!';
	END;

	RAISE NOTICE 'Checking to see if account collection realms can change to mismatch with accounts...';
	INSERT INTO account_collection_account (
		account_collection_id, account_id
	) VALUES (
		_ac1.account_collection_id, _acc1.account_id
	);
	BEGIN
		UPDATE val_account_collection_type
		SET account_realm_id = _ar2.account_realm_id
		WHERE account_collection_type = _ac1.account_collection_type;
		RAISE EXCEPTION '... They can, doh % % %!', _ar2, _ac1, _at1;
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE 'They can not!';
	END;
	DELETE FROM account_collection_account
	WHERE account_collection_id = _ac1.account_collection_id
	AND account_id = _acc1.account_id;

	-- RAISE NOTICE 'Checking to see if account collection realms can change to mismatch with hiers...';
	-- DELETE FROM account_collection_hier
	-- WHERE account_collection_id = _ac1.account_collection_id
	-- AND child_account_collection_id = _ac1.account_collection_id
	-- OR account_collection_id = _ac1.account_collection_id;

	-- INSERT INTO account_collection_hier (
	-- 	account_collection_id, child_account_collection_id
	-- ) VALUES (
	-- 	_ac1.account_collection_id, _ac11.account_collection_id
	-- );

	-- BEGIN
	-- 	UPDATE val_account_collection_type
	-- 	SET account_realm_id = _ar2.account_realm_id
	-- 	WHERE account_collection_type = _ac1.account_collection_type;
	-- 	RAISE EXCEPTION '... They can, doh % % %!', _ar2, _ac1, _at1;
	-- EXCEPTION WHEN integrity_constraint_violation THEN
	-- 	RAISE NOTICE 'They can not!';
	-- END;

	---------------------------------------------------------------------------
	RAISE NOTICE 'account_coll_realm_regression: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT account_coll_realm_regression();
-- set search_path=jazzhands;
DROP FUNCTION account_coll_realm_regression();

SET jazzhands.permit_company_insert TO default;
ROLLBACK TO realm_test;

\t off
