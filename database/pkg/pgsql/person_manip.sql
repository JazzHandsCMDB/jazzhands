/*
 * Copyright (c) 2013 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * $Id$
 */

-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'person_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS person_manip;
		CREATE SCHEMA person_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA person_manip IS 'part of jazzhands';
	END IF;
END;
$$;


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

CREATE OR REPLACE FUNCTION person_manip.pick_login(
	in_account_realm_id	account_realm.account_realm_id%TYPE,
	in_first_name VARCHAR DEFAULT NULL,
	in_middle_name VARCHAR DEFAULT NULL,
	in_last_name VARCHAR DEFAULT NULL
) RETURNS varchar AS
$$
DECLARE
	_acctrealmid	integer;
	_login			varchar;
	_trylogin		varchar;
    id				account.account_id%TYPE;
	fn		text;
	ln		text;
BEGIN
	-- remove special characters
	fn = regexp_replace(lower(in_first_name), '[^a-z]', '', 'g');
	ln = regexp_replace(lower(in_last_name), '[^a-z]', '', 'g');
	_acctrealmid := in_account_realm_id;
	-- Try first initial, last name
	_login = lpad(lower(fn), 1) || lower(ln);
	SELECT account_id into id FROM account where account_realm_id = _acctrealmid
		AND login = _login;

	IF id IS NULL THEN
		RETURN _login;
	END IF;

	-- Try first initial, middle initial, last name
	if in_middle_name IS NOT NULL THEN
		_login = lpad(lower(fn), 1) || lpad(lower(in_middle_name), 1) || lower(ln);
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _login;
		IF id IS NULL THEN
			RETURN _login;
		END IF;
	END IF;

	-- if length of first+last is <= 10 then try that.
	_login = lower(fn) || lower(ln);
	IF char_length(_login) < 10 THEN
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _login;
		IF id IS NULL THEN
			RETURN _login;
		END IF;
	END IF;

	-- ok, keep trying to add a number to first initial, last
	_login = lpad(lower(fn), 1) || lower(ln);
	FOR i in 1..500 LOOP
		_trylogin := _login || i;
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _trylogin;
		IF id IS NULL THEN
			RETURN _trylogin;
		END IF;
	END LOOP;

	-- wtf. this should never happen
	RETURN NULL;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

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


--
-- Creates a user.  To add a pseudouser (all maps to the same person),
-- make person_company_relation 'pseudouser'
--
-- This *MUST* be called with named arguments.  Order may change.
--
-- This needs to be expanded to properly deal with the person already being there
-- and what not.
--
CREATE OR REPLACE FUNCTION person_manip.add_user(
	company_id INTEGER,
	person_company_relation VARCHAR,
	login VARCHAR DEFAULT NULL,
	first_name VARCHAR DEFAULT NULL,
	middle_name VARCHAR DEFAULT NULL,
	last_name VARCHAR DEFAULT NULL,
	name_suffix VARCHAR DEFAULT NULL,
	gender VARCHAR(1) DEFAULT NULL,
	preferred_last_name VARCHAR DEFAULT NULL,
	preferred_first_name VARCHAR DEFAULT NULL,
	birth_date DATE DEFAULT NULL,
	external_hr_id VARCHAR DEFAULT NULL,
	person_company_status VARCHAR 			DEFAULT 'enabled',
	is_manager VARCHAR(1) 				DEFAULT 'N',
	is_exempt VARCHAR(1) 				DEFAULT 'Y',
	is_full_time VARCHAR(1) 			DEFAULT 'Y',
	employee_id TEXT 				DEFAULT NULL,
	hire_date DATE DEFAULT NULL,
	termination_date DATE DEFAULT NULL,
	job_title VARCHAR DEFAULT NULL,
	department_name VARCHAR DEFAULT NULL, 
	description VARCHAR DEFAULT NULL,
	unix_uid VARCHAR DEFAULT NULL,
	INOUT person_id INTEGER DEFAULT NULL,
	OUT dept_account_collection_id INTEGER,
	OUT account_id INTEGER
)  RETURNS RECORD AS $$
DECLARE
	_account_realm_id INTEGER;
	_account_type VARCHAR;
	_uid INTEGER;
	_uxaccountid INTEGER;
	_companyid INTEGER;
	_personid INTEGER;
	_accountid INTEGER;
BEGIN
	IF company_id is NULL THEN
		RAISE EXCEPTION 'Must specify company id';
	END IF;
	_companyid := company_id;

	SELECT arc.account_realm_id 
	  INTO _account_realm_id 
	  FROM account_realm_company arc
	 WHERE arc.company_id = _companyid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Cannot find account_realm_id with company id %', company_id;
	END IF;

	IF login is NULL THEN
		IF first_name IS NULL or last_name IS NULL THEN 
			RAISE EXCEPTION 'Must specify login name or first name+last name';
		ELSE 
			login := person_manip.pick_login(
				in_account_realm_id	:= _account_realm_id,
				in_first_name := coalesce(preferred_first_name, first_name),
				in_middle_name := middle_name,
				in_last_name := coalesce(preferred_last_name, last_name)
			);
		END IF;
	END IF;

	IF person_company_relation = 'pseudouser' THEN
		person_id := 0;
		_account_type := 'pseudouser';
	ELSE
		_account_type := 'person';
		IF person_id IS NULL THEN
			INSERT INTO person (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
				VALUES (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
			RETURNING person.person_id into _personid;
			person_id = _personid;
		ELSE
			INSERT INTO person (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
				VALUES (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date);
		END IF;
		INSERT INTO person_company
			(person_id,company_id,external_hr_id,person_company_status,is_management, is_exempt, is_full_time, employee_id,hire_date,termination_date,person_company_relation, position_title)
			VALUES
			(person_id, company_id, external_hr_id, person_company_status, is_manager, is_exempt, is_full_time, employee_id, hire_date, termination_date, person_company_relation, job_title);
		INSERT INTO person_account_realm_company ( person_id, company_id, account_realm_id) VALUES ( person_id, company_id, _account_realm_id);
	END IF;

	INSERT INTO account ( login, person_id, company_id, account_realm_id, account_status, description, account_role, account_type)
		VALUES (login, person_id, company_id, _account_realm_id, person_company_status, description, 'primary', _account_type)
	RETURNING account.account_id INTO account_id;

	IF department_name IS NOT NULL THEN
		dept_account_collection_id = person_manip.get_account_collection_id(department_name, 'department');
		INSERT INTO account_collection_account (account_collection_id, account_id) VALUES ( dept_account_collection_id, account_id);
	END IF;

	IF unix_uid IS NOT NULL THEN
		_accountid = account_id;
		SELECT	aui.account_id
		  INTO	_uxaccountid
		  FROM	account_unix_info aui
		 WHERE	aui.account_id = _accountid;

		--
		-- This is creatd by trigger for non-pseudousers, which will
		-- eventually change, so this is here once it goes away.
		--
		IF _uxaccountid IS NULL THEN
			IF unix_uid = 'auto' THEN
				_uid :=  person_manip.get_unix_uid(_account_type);
			ELSE
				_uid := unix_uid::int;
			END IF;

			PERFORM person_manip.setup_unix_account(
				in_account_id := account_id,
				in_account_type := _account_type,
				in_uid := _uid
			);
		END IF;
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--
-- THIS IS DEPRECATED.  Call add_user instead.
--
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
	employee_id VARCHAR,
	hire_date DATE,
	termination_date DATE,
	person_company_relation VARCHAR,
	job_title VARCHAR,
	department VARCHAR,
	login VARCHAR,
	OUT _person_id INTEGER,
	OUT _account_collection_id INTEGER,
	OUT _account_id INTEGER)
 AS $$
DECLARE
	_account_realm_id INTEGER;
BEGIN
	SELECT	
		xxx.person_id,
		xxx.dept_account_collection_id,
		xxx.account_id
	INTO
		_person_id,
		_account_collection_id,
		_account_id
	FROM	person_manip.add_user (
			person_id := __person_id,
			first_name := first_name,
			middle_name := middle_name,
			last_name := last_name,
			name_suffix := name_suffix,
			gender := gender,
			preferred_last_name := preferred_last_name,
			preferred_first_name := preferred_first_name,
			birth_date := birth_date,
			company_id := _company_id,
			external_hr_id := external_hr_id,
			person_company_status := person_company_status,
			is_manager := is_manager,
			is_exempt := is_exempt,
			is_full_time := is_full_time,
			employee_id := employee_id,
			hire_date := hire_date,
			termination_date := termination_date,
			person_company_relation := person_company_relation,
			job_title := job_title,
			department_name := department,
			login := login
		) xxx; 
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--
-- THIS FUNCTION IS DEPRECATED AND WILL GO AWAY.  Call add_person instead
--
CREATE OR REPLACE FUNCTION person_manip.add_user_non_person(
	_company_id integer, 
	_account_status character varying, 
	_login character varying, 
	_description character varying
) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
	__account_id INTEGER;
BEGIN
    SELECT account_id
     INTO  __account_id
     FROM  person_manip.add_user(
        company_id := _company_id,
        person_company_relation := 'pseudouser',
        login := _login,
        description := _description,
        person_company_status := 'enabled'
    );
	RETURN __account_id;
END;
$$;

CREATE OR REPLACE FUNCTION person_manip.setup_unix_account(
	in_account_id		account.account_id%TYPE,
	in_account_type		account.account_type%TYPE,
	in_uid			account_unix_info.unix_uid%TYPE	DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
	acid			account_collection.account_collection_id%TYPE;
	_login			account.login%TYPE;
	new_uid			account_unix_info.unix_uid%TYPE	DEFAULT NULL;
BEGIN
	SELECT login INTO _login FROM account WHERE account_id = in_account_id;

	INSERT INTO account_collection (
		account_collection_name, account_collection_type)
	values (
		_login, 'unix-group'
	) RETURNING account_collection_id INTO acid;

	insert into account_collection_account (
		account_collection_id, account_id
	) values (
		acid, in_account_id
	);

	IF in_uid is NOT NULL THEN
		new_uid := in_uid;
	ELSE
		new_uid := person_manip.get_unix_uid(in_account_type);
	END IF;

	INSERT INTO account_unix_info (
		account_id,
		unix_uid,
		unix_group_acct_collection_id,
		shell
	) values (
		in_account_id,
		new_uid,
		acid,
		'bash'
	);

	INSERT INTO unix_group (
		account_collection_id,
		unix_gid
	) values (
		acid,
		new_uid
	);
	RETURN in_account_id;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

-- arguably this should be two sequences, one up from 10k, the other
-- down from 10k.
CREATE OR REPLACE FUNCTION person_manip.get_unix_uid(
	account_type CHARACTER VARYING
) RETURNS INTEGER AS $$
DECLARE new_id INTEGER;
BEGIN
        IF account_type = 'people' OR account_type = 'person' THEN
                SELECT
                        coalesce(max(unix_uid),9999)  INTO new_id
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
                        coalesce(min(unix_uid),10000)  INTO new_id
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
                        p.person_id = 0 AND unix_uid >6000;
		new_id = new_id - 1;
        END IF;
        RETURN new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- the other version of this should be retired to apply the same logic
CREATE OR REPLACE FUNCTION person_manip.get_unix_uid(
	person_id	person.person_id%TYPE,
	account_type	account.account_id%TYPE
) RETURNS INTEGER AS $$
DECLARE
	gettype	CHARACTER VARYING;
BEGIN
	IF person_id = 0 OR account.account_type != 'pseduouser' THEN
		gettype := 'people';
	ELSE
		gettype := 'not-people';
	END IF;
	return person_manip.get_unix_uid(gettype);
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
	-- note the per-account account collection is removed in triggers

	DELETE FROM account_assignd_cert where ACCOUNT_ID = in_account_id;
	DELETE FROM account_token where ACCOUNT_ID = in_account_id;
	DELETE FROM account_unix_info where ACCOUNT_ID = in_account_id;
	DELETE FROM klogin where ACCOUNT_ID = in_account_id;
	DELETE FROM property where ACCOUNT_ID = in_account_id;
	DELETE FROM account_password where ACCOUNT_ID = in_account_id;
	DELETE FROM unix_group where account_collection_id in
		(select account_collection_id from account_collection 
			where account_collection_name in
				(select login from account where account_id = in_account_id)
				and account_collection_type in ('unix-group')
		);
	DELETE FROM account_collection_account where ACCOUNT_ID = in_account_id;

	DELETE FROM account_collection where account_collection_name in
		(select login from account where account_id = in_account_id)
		and account_collection_type in ('per-account', 'unix-group');

	DELETE FROM account where ACCOUNT_ID = in_account_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Purge a person from the system.  This will also purge their accounts
-- It will fail if the person has shown up in too many plces (i.e, was in
-- use).    The typical way to get rid of a person is to just mark them as
-- deleted, buf if they were inserted by msitake, this is useful.
CREATE OR REPLACE FUNCTION person_manip.purge_person(
		in_person_id	person.person_id%TYPE
) RETURNS void AS $$
DECLARE
	aid	INTEGER;
BEGIN
	FOR aid IN select account_id 
			FROM account 
			WHERE person_id = in_person_id
	LOOP
		PERFORM person_manip.purge_account ( aid );
	END LOOP; 

	DELETE FROM person_contact WHERE person_id = in_person_id;
	DELETE FROM person_location WHERE person_id = in_person_id;
	DELETE FROM person_company WHERE person_id = in_person_id;
	DELETE FROM person_account_realm_company WHERE person_id = in_person_id;
	DELETE FROM person WHERE person_id = in_person_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION person_manip.merge_accounts(
	merge_from_account_id	account.account_Id%TYPE,
	merge_to_account_id	account.account_Id%TYPE
) RETURNS INTEGER AS $$
DECLARE
	fpc		person_company%ROWTYPE;
	tpc		person_company%ROWTYPE;
	_account_realm_id INTEGER;
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

	IF(tpc.external_hr_id is NOT NULL AND fpc.external_hr_id IS NULL) THEN
		RAISE EXCEPTION 'Destination account has an external HR ID and origin account has none';
	END IF;

	-- move any account collections over that are
	-- not infrastructure ones, and the new person is
	-- not in
	UPDATE	account_collection_account
	   SET	ACCOUNT_ID = merge_to_account_id
	 WHERE	ACCOUNT_ID = merge_from_account_id
	  AND	ACCOUNT_COLLECTION_ID IN (
			SELECT ACCOUNT_COLLECTION_ID
			  FROM	ACCOUNT_COLLECTION
				INNER JOIN VAL_ACCOUNT_COLLECTION_TYPE
					USING (ACCOUNT_COLLECTION_TYPE)
			 WHERE	IS_INFRASTRUCTURE_TYPE = 'N'
		)
	  AND	account_collection_id not in (
			SELECT	account_collection_id
			  FROM	account_collection_account
			 WHERE	account_id = merge_to_account_id
	);


	-- Now begin removing the old account
	PERFORM person_manip.purge_account( merge_from_account_id );

	-- Switch person_ids
	DELETE FROM person_account_realm_company WHERE person_id = fpc.person_id AND company_id = tpc.company_id;
	SELECT account_realm_id INTO _account_realm_id FROM account_realm_company WHERE company_id = tpc.company_id;
	INSERT INTO person_account_realm_company (person_id, company_id, account_realm_id) VALUES ( fpc.person_id , tpc.company_id, _account_realm_id);
	UPDATE account SET account_realm_id = _account_realm_id, person_id = fpc.person_id WHERE person_id = tpc.person_id AND company_id = fpc.company_id;
	DELETE FROM person_company WHERE person_id = tpc.person_id AND company_id = tpc.company_id;
	DELETE FROM person_account_realm_company WHERE person_id = tpc.person_id AND company_id = tpc.company_id;
	UPDATE person_image SET person_id = fpc.person_id WHERE person_id = tpc.person_id;
	-- if there are other relations that may exist, do not delete the person.
	BEGIN
		delete from person where person_id = tpc.person_id;
	EXCEPTION WHEN foreign_key_violation THEN
		NULL;
	END;

	return merge_to_account_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION person_manip.change_company(
	final_company_id 	integer, 
	_person_id		integer, 
	initial_company_id 	integer,
	_account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL
)  RETURNS VOID AS $_$
DECLARE
	initial_person_company  person_company%ROWTYPE;
	_arid			account_realm.account_realm_id%TYPE;
BEGIN
	IF _account_realm_id IS NULL THEN
		SELECT	account_realm_id
		INTO	_arid
		FROM	property
		WHERE	property_type = 'Defaults'
		AND	property_name = '_root_account_realm_id';
	ELSE
		_arid := _account_realm_id;
	END IF;
	set constraints fk_ac_ac_rlm_cpy_act_rlm_cpy DEFERRED;
	set constraints fk_account_prsn_cmpy_acct DEFERRED;
	set constraints fk_account_company_person DEFERRED;

	UPDATE person_account_realm_company
		SET company_id = final_company_id
	WHERE person_id = _person_id
	AND company_id = initial_company_id
	AND account_realm_id = _arid;

	SELECT * 
	INTO initial_person_company 
	FROM person_company 
	WHERE person_id = _person_id 
	AND company_id = initial_company_id;

	UPDATE person_company
	SET company_id = final_company_id
	WHERE company_id = initial_company_id
	AND person_id = _person_id;

	UPDATE account 
	SET company_id = final_company_id 
	WHERE company_id = initial_company_id 
	AND person_id = _person_id
	AND account_realm_id = _arid;

	set constraints fk_ac_ac_rlm_cpy_act_rlm_cpy IMMEDIATE;
	set constraints fk_account_prsn_cmpy_acct IMMEDIATE;
	set constraints fk_account_company_person IMMEDIATE;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands, pg_temp;
