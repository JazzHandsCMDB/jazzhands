
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
		INSERT INTO account_collection (account_collection_type, account_collection_name)
			VALUES (type, department)
		RETURNING account_collection_id into _account_collection_id;
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
	IF old_account_collection_id IS NULL THEN
		INSERT INTO account_collection_account (account_id, account_collection_id) VALUES (_account_id, _account_collection_id);
	ELSE
		--RAISE NOTICE 'updating account_collection_account with id % for account %', _account_collection_id, _account_id;
		UPDATE account_collection_account SET account_collection_id = _account_collection_id WHERE account_id = _account_id AND account_collection_id=old_account_collection_id;
	END IF;
	RETURN _account_collection_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION person_manip.add_person(
	__person_id INTEGER,
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
	is_manager VARCHAR(1),
	is_exempt VARCHAR(1),
	is_full_time VARCHAR(1),
	employee_id INTEGER,
	hire_date DATE,
	termination_date DATE,
	person_company_relation VARCHAR,
	job_title VARCHAR,
	department VARCHAR, login VARCHAR,
	OUT _person_id INTEGER,
	OUT _account_collection_id INTEGER,
	OUT _account_id INTEGER)
 AS $$
DECLARE
	_account_realm_id INTEGER;
BEGIN
	IF __person_id IS NULL THEN
		INSERT INTO person (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
			VALUES (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
			RETURNING person_id into _person_id;
	ELSE
		INSERT INTO person (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
			VALUES (__person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date);
		_person_id = __person_id;
	END IF;
	INSERT INTO person_company
		(person_id,company_id,external_hr_id,person_company_status,is_management, is_exempt, is_full_time, employee_id,hire_date,termination_date,person_company_relation, position_title)
		VALUES
		(_person_id, _company_id, external_hr_id, person_company_status, is_manager, is_exempt, is_full_time, employee_id, hire_date, termination_date, person_company_relation, job_title);
	SELECT account_realm_id INTO _account_realm_id FROM account_realm_company WHERE company_id = _company_id;
	INSERT INTO person_account_realm_company ( person_id, company_id, account_realm_id) VALUES ( _person_id, _company_id, _account_realm_id);
	INSERT INTO account ( login, person_id, company_id, account_realm_id, account_status, account_role, account_type) 
		VALUES ( login, _person_id, _company_id, _account_realm_id, person_company_status, 'primary', 'person')
		RETURNING account_id INTO _account_id;
	IF department IS NULL THEN
		RETURN;
	END IF;
	_account_collection_id = person_manip.get_account_collection_id(department, 'department');
	INSERT INTO account_collection_account (account_collection_id, account_id) VALUES ( _account_collection_id, _account_id);
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
	INSERT INTO account ( login, person_id, company_id, account_realm_id, account_status, description, account_role, account_type) 
		VALUES (_login, _person_id, _company_id, _account_realm_id, _account_status, _description, 'primary', 'pseudouser')
	RETURNING account_id into _account_id;
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

\i merge_accounts.sql
\i change_company.sql
