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
	_trunclen		integer;
    id				account.account_id%TYPE;
	fn		text;
	ln		text;
BEGIN
	SELECT	property_value::int
	INTO	_trunclen
	FROM	property
	WHERE	property_type = 'Defaults'
	AND	 	property_name = '_max_default_login_length';

	IF NOT FOUND THEN
		_trunclen := 15;
	END IF;

	-- remove special characters
	fn = regexp_replace(lower(in_first_name), '[^a-z]', '', 'g');
	ln = regexp_replace(lower(in_last_name), '[^a-z]', '', 'g');
	_acctrealmid := in_account_realm_id;
	-- Try first initial, last name
	_login = lpad(lower(fn), 1) || lower(ln);

	IF _trunclen IS NOT NULL AND _trunclen > 0 THEN
		_login := left(_login, _trunclen);
	END IF;

	SELECT account_id into id FROM account where account_realm_id = _acctrealmid
		AND login = _login;

	IF id IS NULL THEN
		RETURN _login;
	END IF;

	-- Try first initial, middle initial, last name
	if in_middle_name IS NOT NULL THEN
		_login = lpad(lower(fn), 1) || lpad(lower(in_middle_name), 1) || lower(ln);

		IF _trunclen IS NOT NULL AND _trunclen > 0 THEN
			_login := left(_login, _trunclen);
		END IF;
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _login;
		IF id IS NULL THEN
			RETURN _login;
		END IF;
	END IF;

	-- if length of first+last is <= 10 then try that.
	_login = lower(fn) || lower(ln);
	IF _trunclen IS NOT NULL AND _trunclen > 0 THEN
		_login := left(_login, _trunclen);
	END IF;
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
		IF _trunclen IS NOT NULL AND _trunclen > 0 THEN
			_login := left(_login, _trunclen - 2);
		END IF;
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
    company_id                      INTEGER,
    person_company_relation         VARCHAR,
    login                           VARCHAR     DEFAULT NULL,
    first_name                      VARCHAR     DEFAULT NULL,
    middle_name                     VARCHAR     DEFAULT NULL,
    last_name                       VARCHAR     DEFAULT NULL,
    name_suffix                     VARCHAR     DEFAULT NULL,
    gender                          VARCHAR(1)  DEFAULT NULL,
    preferred_last_name             VARCHAR     DEFAULT NULL,
    preferred_first_name            VARCHAR     DEFAULT NULL,
    birth_date                      DATE        DEFAULT NULL,
    external_hr_id                  VARCHAR     DEFAULT NULL,
    person_company_status           VARCHAR     DEFAULT 'enabled',
    is_management                   VARCHAR(1)  DEFAULT 'N',
    is_manager                      VARCHAR(1)  DEFAULT NULL,
    is_exempt                       VARCHAR(1)  DEFAULT 'Y',
    is_full_time                    VARCHAR(1)  DEFAULT 'Y',
    employee_id                     TEXT        DEFAULT NULL,
    hire_date                       DATE        DEFAULT NULL,
    termination_date                DATE        DEFAULT NULL,
    position_title                  VARCHAR     DEFAULT NULL,
    job_title		                VARCHAR     DEFAULT NULL,
    department_name                 VARCHAR     DEFAULT NULL,
    manager_person_id               INTEGER     DEFAULT NULL,
    site_code                       VARCHAR     DEFAULT NULL,
    physical_address_id             INTEGER     DEFAULT NULL,
    person_location_type            VARCHAR     DEFAULT 'office',
    description                     VARCHAR     DEFAULT NULL,
    unix_uid                        VARCHAR     DEFAULT NULL,
    INOUT person_id                 INTEGER     DEFAULT NULL,
    OUT dept_account_collection_id  INTEGER,
    OUT account_id                  INTEGER
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
	IF is_manager IS NOT NULL THEN
		is_management := is_manager;
	END IF;

	IF job_title IS NOT NULL THEN
		position_title := job_title;
	END IF;

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
                in_account_realm_id := _account_realm_id,
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
        INSERT INTO v_person_company
            (person_id, company_id, external_hr_id, person_company_status, is_management, is_exempt, is_full_time, employee_id, hire_date, termination_date, person_company_relation, position_title, manager_person_id)
            VALUES
            (person_id, company_id, external_hr_id, person_company_status, is_management, is_exempt, is_full_time, employee_id, hire_date, termination_date, person_company_relation, position_title, manager_person_id);
        INSERT INTO person_account_realm_company ( person_id, company_id, account_realm_id) VALUES ( person_id, company_id, _account_realm_id);
    END IF;

    INSERT INTO account ( login, person_id, company_id, account_realm_id, account_status, description, account_role, account_type)
        VALUES (login, person_id, company_id, _account_realm_id, person_company_status, description, 'primary', _account_type)
    RETURNING account.account_id INTO account_id;

    IF department_name IS NOT NULL THEN
        dept_account_collection_id = person_manip.get_account_collection_id(department_name, 'department');
        INSERT INTO account_collection_account (account_collection_id, account_id) VALUES ( dept_account_collection_id, account_id);
    END IF;

    IF site_code IS NOT NULL AND physical_address_id IS NOT NULL THEN
        RAISE EXCEPTION 'You must provide either site_code or physical_address_id NOT both';
    END IF;

    IF site_code IS NULL AND physical_address_id IS NOT NULL THEN
        site_code = person_manip.get_site_code_from_physical_address_id(physical_address_id);
    END IF;

    IF physical_address_id IS NULL AND site_code IS NOT NULL THEN
        physical_address_id = person_manip.get_physical_address_from_site_code(site_code);
    END IF;

    IF physical_address_id IS NOT NULL AND site_code IS NOT NULL THEN
        INSERT INTO person_location
            (person_id, person_location_type, site_code, physical_address_id)
        VALUES
            (person_id, person_location_type, site_code, physical_address_id);
    END IF;


    IF unix_uid IS NOT NULL THEN
        _accountid = account_id;
        SELECT  aui.account_id
          INTO  _uxaccountid
          FROM  account_unix_info aui
        WHERE  aui.account_id = _accountid;

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

	SELECT account_collection_id
	INTO	acid
	FROM	account_collection
	WHERE	account_collection_name = _login
	AND	account_collection_type = 'unix-group';

	IF NOT FOUND THEN
		INSERT INTO account_collection (
			account_collection_name, account_collection_type)
		values (
			_login, 'unix-group'
		) RETURNING account_collection_id INTO acid;
	END IF;

	PERFORM	*
	FROM	account_collection_account
	WHERE	account_collection_id = acid
	AND	account_id = in_account_id;

	IF NOT FOUND THEN
		insert into account_collection_account (
			account_collection_id, account_id
		) values (
			acid, in_account_id
		);
	END IF;

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

	PERFORM	*
	FROM	unix_group
	WHERE	account_collection_id = acid
	AND	unix_gid = new_uid;

	IF NOT FOUND THEN
		INSERT INTO unix_group (
			account_collection_id,
			unix_gid
		) values (
			acid,
			new_uid
		);
	END IF;
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
	DELETE FROM property where account_collection_id in
		(select account_collection_id from account_collection
			where account_collection_name in
				(select login from account where account_id = in_account_id)
				and account_collection_type in ('per-account')
		);
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

	DELETE FROM account_ssh_key where ACCOUNT_ID = in_account_id;
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

	DELETE FROM person_company_attr WHERE person_id = in_person_id;
	DELETE FROM person_contact WHERE person_id = in_person_id;
	DELETE FROM person_location WHERE person_id = in_person_id;
	DELETE FROM v_person_company WHERE person_id = in_person_id;
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
	fpc		v_person_company%ROWTYPE;
	tpc		v_person_company%ROWTYPE;
	_account_realm_id INTEGER;
BEGIN
	select	*
	  into	fpc
	  from	v_person_company
	 where	(person_id, company_id) in
		(select person_id, company_id
		   from account where account_id = merge_from_account_id);

	select	*
	  into	tpc
	  from	v_person_company
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
	DELETE FROM person_company_attr WHERE person_id = tpc.person_id AND company_id = tpc.company_id;
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
	set constraints fk_pers_comp_attr_person_comp_ DEFERRED;

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

	UPDATE person_company_attr
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
	set constraints fk_pers_comp_attr_person_comp_ IMMEDIATE;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands, pg_temp;

--------------------------------------------------------------------------------

--
-- given some data, attempt to figure out if the same person exists already.
-- This is imperfect
--
CREATE OR REPLACE FUNCTION person_manip.guess_person_id(
	first_name 	text,
	last_name	text,
	login 		text,
	company_id	company.company_id%TYPE DEFAULT NULL
)  RETURNS person.person_id%TYPE AS $_$
DECLARE
	pid		person.person_id%TYPE;
	_l		text;
BEGIN
	-- see if that login name is alradeady associated with someone with the
	-- same first and last name
	EXECUTE '
		SELECT person_id
		FROM	person
				JOIN account USING (person_id,$2)
		WHERE	login = $1
		AND		first_name = $3
		AND		last_name = $4
	' INTO pid USING login, company_id, first_name, last_name;

	IF pid IS NOT NULL THEN
		RETURN pid;
	END IF;

	_l = regexp_replace(login, '@.*$', '');

	IF _l != login THEN
		EXECUTE '
			SELECT person_id
			FROM	person
					JOIN account USING (person_id,$2)
			WHERE	login = $1
			AND		first_name = $3
			AND		last_name = $4
		' INTO pid USING _l, company_id, first_name, last_name;

		IF pid IS NOT NULL THEN
			RETURN pid;
		END IF;
	END IF;

	RETURN NULL;
END;
$_$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = jazzhands, pg_temp;

--------------------------------------------------------------------------------
-- two functions. they take either a physical_address_id or a site_code and
-- return the matching site_code or physical_address_id
--------------------------------------------------------------------------------

DROP FUNCTION IF EXISTS person_manip.get_physical_address_from_site_code(varchar);
CREATE OR REPLACE FUNCTION person_manip.get_physical_address_from_site_code(_site_code VARCHAR)
	RETURNS INTEGER AS $$
DECLARE
	_physical_address_id INTEGER;
BEGIN
	SELECT physical_address_id INTO _physical_address_id
		FROM physical_address
		INNER JOIN site USING(physical_address_id)
		WHERE site_code = _site_code;
	RETURN _physical_address_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS person_manip.get_site_code_from_physical_address_id(integer);
CREATE OR REPLACE FUNCTION person_manip.get_site_code_from_physical_address_id(_physical_address_id INTEGER)
	RETURNS VARCHAR AS $$
DECLARE
	_site_code VARCHAR;
BEGIN
	SELECT site_code INTO _site_code
		FROM physical_address
		INNER JOIN site USING(physical_address_id)
		WHERE physical_address_id = _physical_address_id;
	RETURN _site_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------------------
-- function to change a persons location.  takes person_id AND either
-- phsyical_address_id OR site_code and sets the person_location entry for the
-- for the given person_id
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION person_manip.set_location(
	person_id 						INTEGER,
	new_site_code					VARCHAR DEFAULT NULL,
	new_physical_address_id		    INTEGER DEFAULT NULL,
	person_location_type            VARCHAR DEFAULT 'office'
) RETURNS VOID AS $$
DECLARE
	_person_id INTEGER;
	_person_location_type VARCHAR;
	_existing_person_location_id INTEGER;
BEGIN
	_person_id = person_id;
	_person_location_type = person_location_type;

	IF ( new_site_code IS NULL AND new_physical_address_id IS NULL )
		OR ( new_site_code IS NOT NULL AND new_physical_address_id IS NOT NULL ) THEN
			RAISE EXCEPTION 'Must specify either new_site_code or new_physical_address';
	END IF;

	IF new_site_code IS NOT NULL AND new_physical_address_id IS NULL THEN
		new_physical_address_id = person_manip.get_physical_address_from_site_code(new_site_code);
	END IF;

	IF new_physical_address_id IS NOT NULL AND new_site_code IS NULL THEN
		new_site_code = person_manip.get_site_code_from_physical_address_id(new_physical_address_id);
	END IF;

	SELECT person_location_id INTO _existing_person_location_id
	FROM person_location pl
	WHERE pl.person_id = _person_id AND pl.person_location_type = _person_location_type;

	IF _existing_person_location_id IS NULL THEN
		INSERT INTO person_location
			(person_id, person_location_type, site_code, physical_address_id)
		VALUES
			(_person_id, _person_location_type, new_site_code, new_physical_address_id);
	ELSE
		UPDATE person_location
		SET (site_code, physical_address_id, building, floor, section, seat_number)
		= (new_site_code, new_physical_address_id, NULL, NULL, NULL, NULL)
		WHERE person_location_id = _existing_person_location_id;
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------------------
--
-- Used to purge accounts from account from account collections when the
-- members have been terminated for more than an interval.
--
-- The default is a year, but its possible to pass in an interval or set up
-- a system wide default.
--
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION person_manip.cleanup_account_collection_account (
	lifespan	INTERVAL DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
	rv	INTEGER;
BEGIN
	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_collection_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		lifespan := '1 year'::interval;
	END IF;

	--
	-- It is possible that this will fail if there are surprise foreign
	-- keys to the accounts.  Thisis
	--
	EXECUTE '
		WITH x AS (
			SELECT account_collection_id, account_id
			FROM    account a
        			JOIN account_collection_account aca USING (account_id)
        			JOIN account_collection ac USING (account_collection_id)
        			JOIN person_company pc USING (person_id, company_id)
			WHERE   pc.termination_date IS NOT NULL
			AND     pc.termination_date < now() - $1::interval
			AND     account_collection_type != $2
			AND
				(account_collection_id, account_id)  NOT IN
					( SELECT unix_group_acct_collection_id, account_id from
						account_unix_info)
			) DELETE FROM account_collection_account aca
			WHERE (account_collection_id, account_id) IN
				(SELECT account_collection_id, account_id FROM x)
		' USING lifespan, 'per-account';
	GET DIAGNOSTICS rv = ROW_COUNT;
	RETURN rv;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------------------
--
-- Used to purge inactive departments from various places where the database
-- maintains them.
--
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION person_manip.purge_inactive_departments(
	lifespan	INTERVAL DEFAULT NULL,
	raise_exception	boolean DEFAULT true
) RETURNS INTEGER AS $$
DECLARE
	_r	RECORD;
	rv	INTEGER;
	i	INTEGER;
BEGIN
	rv := 0;

	--
	-- delete login assignment to linux machines for departments that are
	-- disabled and not in use
	--
	FOR _r IN SELECT	p.property_id
			FROM	account_collection ac
				JOIN department d USING (account_collection_id)
				JOIN property p USING (account_collection_id)
			WHERE 	d.is_active = 'N'
			AND	property_type = 'MclassUnixProp' AND property_name = 'UnixLogin'
			AND	account_collection_id NOT IN (
					SELECT child_account_collection_id
					FROM account_collection_hier
				)
			AND	account_collection_id NOT IN (
					SELECT account_collection_id
					FROM account_collection_account
				)
	LOOP
		BEGIN
			DELETE FROM property
			WHERE property_id = _r.property_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;


	--
	-- delete unix group overrides to linux machines for departments that are
	-- disabled and not in use
	--
	FOR _r IN SELECT	p.property_id
			FROM	account_collection ac
				JOIN department d USING (account_collection_id)
				JOIN property p ON p.property_value_account_coll_id =
					ac.account_collection_id
			WHERE 	d.is_active = 'N'
			AND	property_type = 'MclassUnixProp'
			AND	property_name = 'UnixGroupMemberOverride'
			AND	p.property_value_account_coll_id NOT IN (
					SELECT child_account_collection_id
					FROM account_collection_hier
				)
			AND	p.property_value_account_coll_id NOT IN (
					SELECT account_collection_id
					FROM account_collection_account
				)
	LOOP
		BEGIN
			DELETE FROM property
			WHERE property_id = _r.property_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	--
	-- remove child account collection membership
	--
	FOR _r IN SELECT	ac.*
			FROM	account_collection ac
				JOIN department d USING (account_collection_id)
			WHERE	d.is_active = 'N'
			AND	account_collection_id IN (
				SELECT child_account_collection_id FROM account_collection_hier
			)
	LOOP
		BEGIN
			DELETE FROM account_collection_hier
				WHERE child_account_collection_id = _r.account_collection_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	RETURN rv;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------------------
--
-- Used to purge account collections that are empty from children account
-- collections if they have no properties assigned.  Since container-only
-- account collections should have properties attached, if it fails to
-- delete, it means its attached elsewhere.  properties are skipped because
-- they are obvious.
--
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION person_manip.purge_inactive_account_collections(
	lifespan	INTERVAL DEFAULT NULL,
	raise_exception	boolean DEFAULT true
) RETURNS INTEGER AS $$
DECLARE
	_r	RECORD;
	i	INTEGER;
	rv	INTEGER;
BEGIN
	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_collection_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;
	IF lifespan IS NULL THEN
		lifespan := '1 year'::interval;
	END IF;

	--
	-- remove unused account collections
	--
	rv := 0;
	FOR _r IN
		SELECT ac.*
		FROM	account_collection ac
			JOIN val_account_collection_type act USING (account_collection_type)
		WHERE	now() -
			coalesce(ac.data_upd_date,ac.data_ins_date) > lifespan::interval
		AND	act.is_infrastructure_type = 'N'
		AND	account_collection_id NOT IN
			(SELECT child_account_collection_id FROM account_collection_hier)
		AND	account_collection_id NOT IN
			(SELECT account_collection_id FROM account_collection_hier)
		AND	account_collection_id NOT IN
			(SELECT account_collection_id FROM account_collection_account)
		AND	account_collection_id NOT IN
			(SELECT account_collection_id FROM property
				WHERE account_collection_id IS NOT NULL)
		AND	account_collection_id NOT IN
			(SELECT property_value_account_coll_id FROM property
				WHERE property_value_account_coll_id IS NOT NULL)
	LOOP
		BEGIN
			DELETE FROM account_collection
				WHERE account_collection_id = _r.account_collection_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	RETURN rv;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

