
-- Copyright (c) 2012, AppNexus, Inc.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
/*
 * $Id$
 */

drop schema if exists person_manip cascade;
create schema person_manip authorization jazzhands;

-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION person_manip.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id$ -->');
END;
$$ LANGUAGE plpgsql;
-- end of procedure id_tag
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION person_manip.get_account_collection_id( department varchar, type varchar )
	RETURNS INTEGER AS $$
DECLARE
	_account_collection_id INTEGER;
BEGIN
	SELECT account_collection_id INTO _account_collection_id FROM account_collection WHERE account_collection_type= type
		AND account_collection_name= department;
	IF NOT FOUND THEN
		_account_collection_id = nextval('account_collection_account_collection_id_seq');
		INSERT INTO account_collection (account_collection_id, account_collection_type, account_collection_name)
			VALUES (_account_collection_id, type, department);
		--RAISE NOTICE 'Created new department % with account_collection_id %', department, _account_collection_id;
	END IF;
	RETURN _account_collection_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION person_manip.update_department( department varchar, _account_id integer, old_account_collection_id integer) 
	RETURNS INTEGER AS $$
DECLARE
	_account_collection_id INTEGER;
BEGIN
	_account_collection_id = person_manip.get_account_collection_id( department, 'department' ); 
	--RAISE NOTICE 'updating account_collection_account with id % for account %', _account_collection_id, _account_id; 
	UPDATE account_collection_account SET account_collection_id = _account_collection_id WHERE account_id = _account_id AND account_collection_id=old_account_collection_id;
	RETURN _account_collection_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION person_manip.add_person(
	first_name VARCHAR, 
	middle_name VARCHAR, 
	last_name VARCHAR,
	name_suffix VARCHAR, 
	gender VARCHAR(1), 
	preferred_last_name VARCHAR,
	preferred_first_name VARCHAR,
	birth_date DATE,
	_company_id INTEGER, 
	external_hr_id VARCHAR, 
	person_company_status VARCHAR, 
	is_exempt VARCHAR(1),
	employee_id INTEGER,
	hire_date DATE,
	termination_date DATE,
	person_company_relation VARCHAR,
	job_title VARCHAR,
	department VARCHAR, login VARCHAR,
	OUT person_id INTEGER,
	OUT _account_collection_id INTEGER,
	OUT account_id INTEGER)
 AS $$
DECLARE
	_account_realm_id INTEGER;
BEGIN
	person_id = nextval('person_person_id_seq');
	INSERT INTO person (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
		VALUES (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date);
	INSERT INTO person_company
		(person_id,company_id,external_hr_id,person_company_status,is_exempt,employee_id,hire_date,termination_date,person_company_relation, position_title)
		VALUES
		(person_id, _company_id, external_hr_id, person_company_status, is_exempt, employee_id, hire_date, termination_date, person_company_relation, job_title);
	SELECT account_realm_id INTO _account_realm_id FROM account_realm_company WHERE company_id = _company_id;
	INSERT INTO person_account_realm_company ( person_id, company_id, account_realm_id) VALUES ( person_id, _company_id, _account_realm_id);
	account_id = nextval('account_account_id_seq');
	INSERT INTO account ( account_id, login, person_id, company_id, account_realm_id, account_status, account_role, account_type) 
		VALUES (account_id, login, person_id, _company_id, _account_realm_id, person_company_status, 'primary', 'person');
	IF department IS NULL THEN
		RETURN;
	END IF;
	_account_collection_id = person_manip.get_account_collection_id(department, 'department');
	INSERT INTO account_collection_account (account_collection_id, account_id) VALUES ( _account_collection_id, account_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION person_manip.add_account_non_person(_company_id integer, _account_status character varying, _login character varying, _description character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
	_account_realm_id INTEGER;
	_person_id INTEGER;
	_account_id INTEGER;
BEGIN
	_person_id := 0;
	SELECT account_realm_id INTO _account_realm_id FROM account_realm_company WHERE company_id = _company_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Cannot find account_realm_id with company id %',_company_id;
	END IF;
	_account_id = nextval('public.account_account_id_seq');
	INSERT INTO account ( account_id, login, person_id, company_id, account_realm_id, account_status, description, account_role, account_type) 
		VALUES (_account_id, _login, _person_id, _company_id, _account_realm_id, _account_status, _description, 'primary', 'pseudouser');
	RETURN _account_id;
END;
$$;

CREATE OR REPLACE FUNCTION person_manip.get_unix_uid(account_type CHARACTER VARYING) RETURNS INTEGER AS $$
DECLARE new_id INTEGER;
BEGIN
        IF account_type = 'people' THEN
                SELECT 
                        coalesce(max(unix_uid),10199) INTO new_id 
                FROM
                        account_unix_info aui
                JOIN
                        account a 
                USING
                        (account_id)
                JOIN
                        person p 
                USING
                        (person_id)
                WHERE
                        p.person_id != 0;
		new_id = new_id + 1;
        ELSE
                SELECT
                        coalesce(min(unix_uid),10000) INTO new_id
                FROM
                        account_unix_info aui
                JOIN
                        account a
                USING
                        (account_id)
                JOIN
                        person p
                USING
                        (person_id)
                WHERE
                        p.person_id = 0 AND unix_uid >0;
		new_id = new_id - 1;
        END IF;
        RETURN new_id;
END;

$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Purge account from system.  This is called rarely and does not hit
-- a number of tables where account_id may appear.  The caller needs
-- to deal with those manually because they are not properties of the
-- account
CREATE OR REPLACE FUNCTION person_manip.purge_account(
		in_account_id	account.account_id%TYPE
) RETURNS void AS $$
BEGIN
	DELETE FROM account_assignd_cert where ACCOUNT_ID = in_account_id;
	DELETE FROM account_token where ACCOUNT_ID = in_account_id;
	DELETE FROM account_unix_info where ACCOUNT_ID = in_account_id;
	DELETE FROM klogin where ACCOUNT_ID = in_account_id;
	DELETE FROM property where ACCOUNT_ID = in_account_id;
	DELETE FROM account_password where ACCOUNT_ID = in_account_id;
	DELETE FROM unix_group where account_collection_id in 
		(select account_collection_id from account_collection where account_collection_name in
			(select login from account where account_id = in_account_id)
			and account_collection_type in ('unix-group')
		);
	DELETE FROM account_collection_account where ACCOUNT_ID = in_account_id;

	DELETE FROM account_collection where account_collection_name in 
		(select login from account where account_id = in_account_id)
		and account_collection_type in ('per-user', 'unix-group');

	DELETE FROM account where ACCOUNT_ID = in_account_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION person_manip.merge_accounts(
	merge_from_account_id	account.account_Id%TYPE,
	merge_to_account_id	account.account_Id%TYPE
) RETURNS INTEGER AS $$
DECLARE
	fpc		person_company%ROWTYPE;
	tpc		person_company%ROWTYPE;
BEGIN
	select	*
	  into	fpc
	  from	person_company
	 where	(person_id, company_id) in
		(select person_id, company_id 
		   from account where account_id = merge_from_account_id);

	select	*
	  into	tpc
	  from	person_company
	 where	(person_id, company_id) in
		(select person_id, company_id 
		   from account where account_id = merge_to_account_id);

	IF (fpc.company_id != tpc.company_id) THEN
		RAISE EXCEPTION 'Accounts are in different companies';
	END IF;

	IF (fpc.person_company_relation != tpc.person_company_relation) THEN
		RAISE EXCEPTION 'People have different relationships';
	END IF;

	IF(tpc.external_hr_id is NOT NULL) THEN
		RAISE EXCEPTION 'Destination account has an external HR ID';
	END IF;

	-- Switch the HR ID
	UPDATE PERSON_COMPANY
	  SET  EXTERNAL_HR_ID = NULL
	WHERE	PERSON_ID = fpc.person_id
	  AND	COMPANY_ID = fpc.company_id;

	UPDATE PERSON_COMPANY
	  SET  EXTERNAL_HR_ID = fpc.external_hr_id
	WHERE	PERSON_ID = tpc.person_id
	  AND	COMPANY_ID = tpc.company_id;

	-- move any account collections over that are
	-- not infrastructure ones, and the new person is
	-- not in
	UPDATE	account_collection_account
	   SET	ACCOUNT_ID = merge_to_account_id
	 WHERE	ACCOUNT_ID = merge_from_account_id
	  AND	ACCOUNT_COLLECTION_ID NOT IN (
			SELECT ACCOUNT_COLLECTION_ID
			  FROM	ACCOUNT_COLLECTION
				INNER JOIN VAL_ACCOUNT_COLLECTION_TYPE
					USING (ACCOUNT_COLLECTION_TYPE)
			 WHERE	IS_INFRASTRUCTURE_TYPE = 'N'
		)
	  AND	account_collection_id not in (
			SELECT	account_collection_id
			  FROM	account_collection_account
			 WHERE	account_id != merge_to_account_id
	);

	-- Now begin removing the old account
	PERFORM person_manip.purge_account( merge_from_account_id );

	update person_contact set person_id = tpc.person_id where person_id = fpc.person_id;
	update person_image set person_id = tpc.person_id where person_id = fpc.person_id;
	update person_vehicle set person_id = tpc.person_id where person_id = fpc.person_id;
	update property set person_id = tpc.person_id where person_id = fpc.person_id;
	delete from person_account_realm_company where person_id = fpc.person_id AND company_id = fpc.company_id;
	delete from person_company where person_id = fpc.person_id AND company_id = fpc.company_id;
	-- if there are other relations that may exist, do not delete the person.
	BEGIN
		delete from person where person_id = fpc.person_id;
	EXCEPTION WHEN foreign_key_violation THEN
		NULL;
	END;
	return merge_to_account_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
