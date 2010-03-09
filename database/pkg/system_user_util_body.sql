-- Copyright (c) 2005-2010, Vonage Holdings Corp.
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
CREATE OR REPLACE
PACKAGE BODY system_user_util IS

G_login_length		CONSTANT	INTEGER := 20;
G_login_digits		CONSTANT	INTEGER := 2;
GC_pkg_name		CONSTANT	 USER_OBJECTS.OBJECT_NAME % TYPE := 'system_user_util';

-- Error Code/Msg variables ------------------
G_err_num		NUMBER;
G_err_msg		VARCHAR2(200);


-------------------------------------------------------------------------------------------------------------------
--procedure to generate the Id tag for CM.
-------------------------------------------------------------------------------------------------------------------
FUNCTION id_tag RETURN VARCHAR2
IS
BEGIN
     RETURN('<-- $Id$ -->');
END;

--
-- build up dynamic sql statements
--
PROCEDURE dsql_update_term
(
	p_sql				IN OUT	VARCHAR2,
	p_name				IN	VARCHAR2,
	p_value				IN	VARCHAR2,
	p_type				IN	VARCHAR2 DEFAULT NULL
)
IS
v_value			VARCHAR2(200);

BEGIN
	IF NOT(p_value IS NULL)
	THEN
		IF NOT(p_sql IS NULL)
		THEN
			p_sql := p_sql || ', ';
		END IF;
		IF (p_type = 'date' AND substr(p_value, 1, 10) = '1800-01-01')
			OR (p_type = 'id' AND p_value = -1)
			OR (p_value = '%null')
		THEN
			v_value := 'null';
		ELSE
			v_value := '''' || REPLACE(p_value, '''', '''''') || '''';
		END IF;
		p_sql := p_sql || p_name || ' = ' || v_value;
	END IF;
END dsql_update_term;

FUNCTION alphanumeric
(
	p_string			IN	VARCHAR2
)
RETURN VARCHAR2
IS
v_char			CHAR(1);
v_string		VARCHAR2(1024);
v_pos			INTEGER;

BEGIN
	FOR v_pos IN 1 .. length(p_string)
	LOOP
		v_char := substr(p_string, v_pos, 1);
		IF (ascii(v_char) >= ascii('A') AND ascii(v_char) <= ascii('Z'))
			OR (ascii(v_char) >= ascii('a') AND ascii(v_char) <= ascii('z'))
			OR (ascii(v_char) >= ascii('0') AND ascii(v_char) <= ascii('9'))
		THEN
			v_string := v_string || v_char;
		END IF;
	END LOOP;

	RETURN v_string;

END alphanumeric;


--
-- cascade of possibilities matching MIS code exactly
--
--	1 - tom a. templetonizique => ttempletoniziq
--	2 - tom templetonizique    => ttempletonizi1
--	3 - tom a. templetonizique => tatempletonizi
--	4 - tom a. templetonizique => tatempletoniz1
--	5 - tom a. templetonizique => tatempletoniz2
--
--	1 - tom a. qix => tqix
--	2 - tom b. qix => tbqix
--	3 - tom b. qix => tqix1
--
FUNCTION choose_login
(
	p_login				IN	SYSTEM_USER.LOGIN % TYPE,
	p_first				IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle			IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last				IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_company_id		IN	SYSTEM_USER.COMPANY_ID % TYPE,
	p_system_user_type	IN	SYSTEM_USER.SYSTEM_USER_TYPE % TYPE,
	p_iteration			IN	INTEGER
)
RETURN VARCHAR2
IS
v_char			CHAR(1);
v_first			SYSTEM_USER.FIRST_NAME % TYPE;
v_int			INTEGER;
v_last			SYSTEM_USER.LAST_NAME % TYPE;
v_last2			SYSTEM_USER.LAST_NAME % TYPE;
v_login			SYSTEM_USER.LOGIN % TYPE;
v_middle		SYSTEM_USER.MIDDLE_NAME % TYPE := '';
v_seq			INTEGER;
v_seqstr		VARCHAR2(10);
v_prefix		COMPANY.ACCOUNT_PREFIX % TYPE;
v_iteration		INTEGER;

BEGIN
	--
	-- build a login
	--
	IF NOT(p_login IS NULL)
	THEN
		RETURN lower(p_login);
	END IF;

	--
	-- we need names for our job
	--
	IF p_first IS NULL OR p_last IS NULL
	THEN
		raise_application_error(-20000, 'first_name or last_name is null');
	END IF;

	v_iteration := p_iteration;
	--
	-- prefix + first initial(s) + last name, up to G_login_length characters
	--

	-- Get rid of any non-alphanumeric characters
	v_first := regexp_replace(convert(p_first, 'US7ASCII', 'UTF8'), '[^A-Za-z0-9]', '');
	v_login := substr(v_first, 1, 1);
	IF p_company_id IS NOT NULL
	THEN
		BEGIN
			SELECT Account_Prefix INTO v_prefix FROM Company 
				WHERE Company_ID = p_company_id AND Is_Corporate_Family = 'N';
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				v_prefix := NULL;
		END;
	END IF;
	IF v_prefix IS NOT NULL
	THEN
		v_login := v_prefix || '-' || v_login;
	ELSE
		IF p_system_user_type IN ('vendor', 'badge') THEN
			v_login := p_system_user_type || '-' || v_login;
		END IF;
	END IF;

	--
	-- If this is the second iteration, try middle name if we have one
	--
	IF v_iteration = 2
	THEN
		IF p_middle IS NOT NULL
		THEN
			v_middle := regexp_replace(convert(p_middle, 'US7ASCII', 'UTF8'), '[^A-Za-z0-9]', '');
			v_login := v_login || substr(v_middle, 1, 1);
		ELSE
			--
			-- If middle is null, then this is going to return the same thing as the previous
			-- iteration, so we might as well just skip it and pretend that we're further along
			--
			v_iteration := v_iteration + 1;
		END IF;
	END IF;

	v_last := regexp_replace(convert(p_last, 'US7ASCII', 'UTF8'), '[^A-Za-z0-9]', '');
	v_login := v_login || substr(v_last, 1, G_login_length - length(v_login));

	--
	-- If we're not appending sequences, then just return what we have
	--
	IF v_iteration <= 2
	THEN
		RETURN lower(v_login);
	END IF;

	--
	-- figure out sequence number and textify it
	--
	v_seq := v_iteration - 2;
	v_seqstr := v_seq;

	--
	-- validate there's no overflow
	--
	IF length(v_seqstr) > G_login_digits
	THEN
		raise_application_error(-20001, 'Login sequence number larger than G_login_digits ('
			|| G_login_digits || ')');
	END IF;

	--
	-- tack on sequence number
	--
	v_login := substr(v_login, 1, G_login_length - length(v_seqstr)) || v_seqstr;

	RETURN lower(v_login);

END choose_login;

-------------------------------------------------------------------------------------------------------------------
-- SYSTEM_USER
-------------------------------------------------------------------------------------------------------------------
PROCEDURE user_add2
(
	p_system_user_id	OUT	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_employee_id		IN OUT	SYSTEM_USER.EMPLOYEE_ID % TYPE,
	p_manager_id		IN	SYSTEM_USER.MANAGER_SYSTEM_USER_ID % TYPE,
	p_badge_id		IN	SYSTEM_USER.BADGE_ID % TYPE,
	p_login			IN OUT	SYSTEM_USER.LOGIN % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_name_suffix		IN	SYSTEM_USER.NAME_SUFFIX % TYPE,
	p_system_user_status	IN	SYSTEM_USER.SYSTEM_USER_STATUS % TYPE,
	p_system_user_type	IN	SYSTEM_USER.SYSTEM_USER_TYPE % TYPE,
	p_position_title	IN	SYSTEM_USER.POSITION_TITLE % TYPE,
	p_company_id		IN	SYSTEM_USER.COMPANY_ID % TYPE,
	p_gender		IN	SYSTEM_USER.GENDER % TYPE,
	p_preferred_first_name	IN	SYSTEM_USER.PREFERRED_FIRST_NAME % TYPE,
	p_preferred_last_name	IN	SYSTEM_USER.PREFERRED_LAST_NAME % TYPE,
	p_hire_date		IN	SYSTEM_USER.HIRE_DATE % TYPE,
	p_termination_date	IN	SYSTEM_USER.TERMINATION_DATE % TYPE,
	p_shirt_size		IN	SYSTEM_USER.SHIRT_SIZE % TYPE,
	p_pant_size		IN	SYSTEM_USER.PANT_SIZE % TYPE,
	p_hat_size		IN	SYSTEM_USER.HAT_SIZE % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.user_add2';
v_iteration		INTEGER := 0;
v_login			System_User.Login % TYPE;
v_uclass_id		UClass.UClass_ID % TYPE;
v_prefix		Company.Account_Prefix % TYPE;

BEGIN

	-- Save our place in case we need to roll things back later
	SAVEPOINT user_add2_sp;
	--
	-- i don't feel comfortable by just inserting records into here
	-- w/o first checking to make sure it's not a pseudo or black
	-- listed type, but it's just not economical to make a copy here
	-- in order to be able to run this from the usermgr cli.
	--
	-- in case that wasn't clear, do not check system_user_type
	-- because this function is being called from unix_util.
	--
	IF p_login = ''
	THEN
		p_login := NULL;
	END IF;

	IF NOT (p_login IS NULL)
	THEN
		IF LENGTH(p_login) > G_login_length
		THEN
			raise_application_error(-20003,
				'login parameter is greater than ' || G_login_length ||
				' characters');
		END IF;
		IF REGEXP_INSTR(p_login, '^[a-z][-a-z0-9]*$') = 0
		THEN
			raise_application_error(-20002,
				'login parameter contains invalid characters');
		END IF;
	END IF;
	LOOP
	BEGIN
		--
		-- choose a possible login
		--
		v_iteration := v_iteration + 1;
		v_login := choose_login(p_login, p_first_name, p_middle_name, p_last_name, p_company_id, p_system_user_type, v_iteration);

		--
		-- try it out along with the regular insert
		--
		INSERT INTO system_user
		(
			login,
			manager_system_user_id,
			badge_id,
			employee_id,
			first_name,
			middle_name,
			last_name,
			name_suffix,
			system_user_status,
			system_user_type,
			position_title,
			company_id,
			gender,
			preferred_first_name,
			preferred_last_name,
			hire_date,
			termination_date,
			shirt_size,
			pant_size,
			hat_size
		)
		VALUES
		(
			v_login,
			p_manager_id,
			p_badge_id,
			p_employee_id,
			p_first_name,
			p_middle_name,
			p_last_name,
			p_name_suffix,
			p_system_user_status,
			p_system_user_type,
			p_position_title,
			p_company_id,
			p_gender,
			p_preferred_first_name,
			p_preferred_last_name,
			p_hire_date,
			p_termination_date,
			p_shirt_size,
			p_pant_size,
			p_hat_size
		)
		RETURNING system_user_id, employee_id INTO p_system_user_id, p_employee_id;

		EXIT WHEN SQL % ROWCOUNT > 0;

	EXCEPTION
		WHEN DUP_VAL_ON_INDEX THEN
			IF instr(SQLERRM, 'UQ_SYSUSR_LOGIN') = 0 OR NOT(p_login IS NULL)
			THEN
				raise;
			END IF;

	END;
	END LOOP;

	--
	-- may not be the same as requested
	--
	p_login := v_login;

	BEGIN
		INSERT INTO UClass (
			Name, 
			UClass_Type
		)  VALUES (
			v_login,
			'per-user'
		) RETURNING UClass_ID INTO v_uclass_id;
	EXCEPTION
		WHEN DUP_VAL_ON_INDEX THEN
			ROLLBACK TO user_add2_sp;
			raise_application_error(-20003,
				'per-user uclass for ' || v_login || ' already exists');
	END;
	INSERT INTO UClass_User (
		Uclass_ID,
		System_User_ID,
		Approval_Type,
		Approval_Ref_Num
	) VALUES (
		v_uclass_id,
		p_system_user_id,
		'rule',
		'user_add2'
	);
EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		ROLLBACK TO user_add2_sp;
		raise;
END user_add2;

PROCEDURE user_add
(
	p_system_user_id	OUT	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_employee_id		IN OUT	SYSTEM_USER.EMPLOYEE_ID % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_name_suffix		IN	SYSTEM_USER.NAME_SUFFIX % TYPE,
	p_system_user_status	IN	SYSTEM_USER.SYSTEM_USER_STATUS % TYPE,
	p_system_user_type	IN	SYSTEM_USER.SYSTEM_USER_TYPE % TYPE,
	p_position_title	IN	SYSTEM_USER.POSITION_TITLE % TYPE,
	p_company_id		IN	SYSTEM_USER.COMPANY_ID % TYPE,
	p_gender		IN	SYSTEM_USER.GENDER % TYPE,
	p_preferred_first_name	IN	SYSTEM_USER.PREFERRED_FIRST_NAME % TYPE,
	p_preferred_last_name	IN	SYSTEM_USER.PREFERRED_LAST_NAME % TYPE,
	p_hire_date		IN	SYSTEM_USER.HIRE_DATE % TYPE,
	p_shirt_size		IN	SYSTEM_USER.SHIRT_SIZE % TYPE,
	p_pant_size		IN	SYSTEM_USER.PANT_SIZE % TYPE,
	p_hat_size		IN	SYSTEM_USER.HAT_SIZE % TYPE
)
IS
v_login			SYSTEM_USER.LOGIN % TYPE := p_login;

BEGIN

	user_add2
	(
		p_system_user_id,
		p_employee_id,
		null,
		null,
		v_login,
		p_first_name,
		p_middle_name,
		p_last_name,
		p_name_suffix,
		p_system_user_status,
		p_system_user_type,
		p_position_title,
		p_company_id,
		p_gender,
		p_preferred_first_name,
		p_preferred_last_name,
		p_hire_date,
		null,
		p_shirt_size,
		p_pant_size,
		p_hat_size
	);

END user_add;

PROCEDURE user_delete
(
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.user_delete';
v_is_person		VAL_SYSTEM_USER_TYPE.IS_PERSON % TYPE;

BEGIN

	--
	-- i hate doing two accesses, but better to be safe than sorry...
	--
	SELECT is_person
	INTO v_is_person
	FROM system_user u, val_system_user_type t
	WHERE u.system_user_id = p_system_user_id
	AND u.system_user_type = t.system_user_type;

	--
	-- in case anyone can trick application into doing this...
	--
	IF v_is_person <> 'Y' THEN
		raise VALUE_ERROR;
	END IF;

	--
	-- update table
	--
	UPDATE system_user SET
		system_user_status = 'deleted',
		termination_date = current_date
	WHERE  system_user_id = p_system_user_id;

	--
	-- update department data too?
	--
	UPDATE dept_member SET
		finish_date = current_date,
		approval_type = 'rule',
		approval_ref_num = 'user_delete, hris feed'
	WHERE system_user_id = p_system_user_id
	AND finish_date is null;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END user_delete;

PROCEDURE user_update
(
	p_system_user_id		IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_employee_id			IN	SYSTEM_USER.EMPLOYEE_ID % TYPE,
	p_manager_id			IN	SYSTEM_USER.MANAGER_SYSTEM_USER_ID % TYPE,
	p_badge_id			IN	SYSTEM_USER.BADGE_ID % TYPE,
	p_login				IN	SYSTEM_USER.LOGIN % TYPE,
	p_first_name			IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name			IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name			IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_name_suffix			IN	SYSTEM_USER.NAME_SUFFIX % TYPE,
	p_system_user_status		IN	SYSTEM_USER.SYSTEM_USER_STATUS % TYPE,
	p_system_user_type		IN	SYSTEM_USER.SYSTEM_USER_TYPE % TYPE,
	p_position_title		IN	SYSTEM_USER.POSITION_TITLE % TYPE,
	p_company_id			IN	SYSTEM_USER.COMPANY_ID % TYPE,
	p_gender			IN	SYSTEM_USER.GENDER % TYPE,
	p_preferred_first_name		IN	SYSTEM_USER.PREFERRED_FIRST_NAME % TYPE,
	p_preferred_last_name		IN	SYSTEM_USER.PREFERRED_LAST_NAME % TYPE,
	p_hire_date			IN	SYSTEM_USER.HIRE_DATE % TYPE,
	p_termination_date		IN	SYSTEM_USER.TERMINATION_DATE % TYPE,
	p_shirt_size			IN	SYSTEM_USER.SHIRT_SIZE % TYPE,
	p_pant_size			IN	SYSTEM_USER.PANT_SIZE % TYPE,
	p_hat_size			IN	SYSTEM_USER.HAT_SIZE % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.user_update';
v_is_person		VAL_SYSTEM_USER_TYPE.IS_PERSON % TYPE;
v_sql			VARCHAR2(2048);

BEGIN
	--
	-- system_user_id must not be null
	--
	IF p_system_user_id IS NULL
	THEN
		raise VALUE_ERROR;
	END IF;

	--
	-- must only handle people, do not permit
	-- changes to become a non-person.
	--
	IF p_system_user_type IS NULL
	THEN
		SELECT is_person
		INTO v_is_person
		FROM val_system_user_type t, system_user u
		WHERE u.system_user_id = p_system_user_id
		AND u.system_user_type = t.system_user_type;
	ELSE
		SELECT is_person
		INTO v_is_person
		FROM val_system_user_type t
		WHERE t.system_user_type = p_system_user_type;
	END IF;

	IF v_is_person <> 'Y' THEN
		raise VALUE_ERROR;
	END IF;

	--
	-- put together some sql
	--
	dsql_update_term(v_sql, 'employee_id', p_employee_id, 'id');
	dsql_update_term(v_sql, 'manager_system_user_id', p_manager_id, 'id');
	dsql_update_term(v_sql, 'badge_id', p_badge_id);
	dsql_update_term(v_sql, 'login', p_login);
	dsql_update_term(v_sql, 'first_name', p_first_name);
	dsql_update_term(v_sql, 'last_name', p_last_name);
	dsql_update_term(v_sql, 'middle_name', p_middle_name);
	dsql_update_term(v_sql, 'name_suffix', p_name_suffix);
	dsql_update_term(v_sql, 'system_user_status', p_system_user_status);
	dsql_update_term(v_sql, 'system_user_type', p_system_user_type);
	dsql_update_term(v_sql, 'position_title', p_position_title);
	dsql_update_term(v_sql, 'company_id', p_company_id, 'id');
	dsql_update_term(v_sql, 'gender', p_gender);
	dsql_update_term(v_sql, 'preferred_first_name', p_preferred_first_name);
	dsql_update_term(v_sql, 'preferred_last_name', p_preferred_last_name);
	dsql_update_term(v_sql, 'hire_date', p_hire_date, 'date');
	dsql_update_term(v_sql, 'termination_date', p_termination_date, 'date');
	dsql_update_term(v_sql, 'shirt_size', p_shirt_size);
	dsql_update_term(v_sql, 'pant_size', p_pant_size);
	dsql_update_term(v_sql, 'hat_size', p_hat_size);

	--
	-- better make sure they actually want something
	--
	IF v_sql IS NULL
	THEN
		raise VALUE_ERROR;
	END IF;

	--
	-- finish it
	--
	v_sql := 'UPDATE system_user SET ' || v_sql || ' WHERE system_user_id = ' || p_system_user_id;

	--
	-- run it
	--
	EXECUTE IMMEDIATE v_sql;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END user_update;

PROCEDURE self_update
(
	p_system_user_id		IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_name_suffix			IN	SYSTEM_USER.NAME_SUFFIX % TYPE,
	p_preferred_first_name		IN	SYSTEM_USER.PREFERRED_FIRST_NAME % TYPE,
	p_preferred_last_name		IN	SYSTEM_USER.PREFERRED_LAST_NAME % TYPE,
	p_shirt_size			IN	SYSTEM_USER.SHIRT_SIZE % TYPE,
	p_pant_size			IN	SYSTEM_USER.PANT_SIZE % TYPE,
	p_hat_size			IN	SYSTEM_USER.HAT_SIZE % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.self_update';

BEGIN

	--
	-- purposefully left off these:
	--
	--	name_suffix
	--
	UPDATE system_user SET
		preferred_first_name	= p_preferred_first_name,
		preferred_last_name	= p_preferred_last_name,
		shirt_size		= p_shirt_size,
		pant_size		= p_pant_size,
		hat_size		= p_hat_size
	WHERE  system_user_id = p_system_user_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);

END self_update;

-------------------------------------------------------------------------------------------------------------------
-- SYSTEM_USER_LOCATION
-------------------------------------------------------------------------------------------------------------------
PROCEDURE location_add
(
	p_system_user_location_id	OUT	SYSTEM_USER_LOCATION.SYSTEM_USER_LOCATION_ID % TYPE,
	p_system_user_id		IN	SYSTEM_USER_LOCATION.SYSTEM_USER_ID % TYPE,
	p_system_user_location_type	IN	SYSTEM_USER_LOCATION.SYSTEM_USER_LOCATION_TYPE % TYPE,
	p_office_site			IN	SYSTEM_USER_LOCATION.OFFICE_SITE % TYPE,
	p_address_1			IN	SYSTEM_USER_LOCATION.ADDRESS_1 % TYPE,
	p_address_2			IN	SYSTEM_USER_LOCATION.ADDRESS_2 % TYPE,
	p_city				IN	SYSTEM_USER_LOCATION.CITY % TYPE,
	p_state				IN	SYSTEM_USER_LOCATION.STATE % TYPE,
	p_postal_code			IN	SYSTEM_USER_LOCATION.POSTAL_CODE % TYPE,
	p_country			IN	SYSTEM_USER_LOCATION.COUNTRY % TYPE,
	p_building			IN	SYSTEM_USER_LOCATION.BUILDING % TYPE,
	p_floor				IN	SYSTEM_USER_LOCATION.FLOOR % TYPE,
	p_section			IN	SYSTEM_USER_LOCATION.SECTION % TYPE,
	p_seat_number			IN	SYSTEM_USER_LOCATION.SEAT_NUMBER % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.location_add';

BEGIN

	INSERT INTO system_user_location
	(
		system_user_id,
		system_user_location_type,
		office_site,
		address_1,
		address_2,
		city,
		state,
		postal_code,
		country,
		building,
		floor,
		section,
		seat_number
	)
	VALUES
	(
		p_system_user_id,
		p_system_user_location_type,
		p_office_site,
		p_address_1,
		p_address_2,
		p_city,
		p_state,
		p_postal_code,
		p_country,
		p_building,
		p_floor,
		p_section,
		p_seat_number
	)
	RETURNING system_user_location_id INTO p_system_user_location_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END location_add;

PROCEDURE location_update
(
	p_system_user_location_id	IN	SYSTEM_USER_LOCATION.SYSTEM_USER_LOCATION_ID % TYPE,
	p_system_user_location_type	IN	SYSTEM_USER_LOCATION.SYSTEM_USER_LOCATION_TYPE % TYPE,
	p_office_site			IN	SYSTEM_USER_LOCATION.OFFICE_SITE % TYPE,
	p_address_1			IN	SYSTEM_USER_LOCATION.ADDRESS_1 % TYPE,
	p_address_2			IN	SYSTEM_USER_LOCATION.ADDRESS_2 % TYPE,
	p_city				IN	SYSTEM_USER_LOCATION.CITY % TYPE,
	p_state				IN	SYSTEM_USER_LOCATION.STATE % TYPE,
	p_postal_code			IN	SYSTEM_USER_LOCATION.POSTAL_CODE % TYPE,
	p_country			IN	SYSTEM_USER_LOCATION.COUNTRY % TYPE,
	p_building			IN	SYSTEM_USER_LOCATION.BUILDING % TYPE,
	p_floor				IN	SYSTEM_USER_LOCATION.FLOOR % TYPE,
	p_section			IN	SYSTEM_USER_LOCATION.SECTION % TYPE,
	p_seat_number			IN	SYSTEM_USER_LOCATION.SEAT_NUMBER % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.location_update';
v_sql			VARCHAR2(2048);

BEGIN

	--
	-- system_user_id must not be null
	--
	IF p_system_user_location_id IS NULL
	THEN
		raise VALUE_ERROR;
	END IF;

	--
	-- put together some sql
	--
	dsql_update_term(v_sql, 'system_user_location_type', p_system_user_location_type);
	dsql_update_term(v_sql, 'office_site', p_office_site);
	dsql_update_term(v_sql, 'address_1', p_address_1);
	dsql_update_term(v_sql, 'address_2', p_address_2);
	dsql_update_term(v_sql, 'city', p_city);
	dsql_update_term(v_sql, 'state', p_state);
	dsql_update_term(v_sql, 'postal_code', p_postal_code);
	dsql_update_term(v_sql, 'country', p_country);
	dsql_update_term(v_sql, 'building', p_building);
	dsql_update_term(v_sql, 'floor', p_floor);
	dsql_update_term(v_sql, 'section', p_section);
	dsql_update_term(v_sql, 'seat_number', p_seat_number);

	--
	-- better make sure they actually want something
	--
	IF v_sql IS NULL
	THEN
		raise VALUE_ERROR;
	END IF;

	--
	-- finish it
	--
	v_sql := 'UPDATE system_user_location SET ' || v_sql ||
		' WHERE system_user_location_id = ' || p_system_user_location_id;

	--
	-- run it
	--
	EXECUTE IMMEDIATE v_sql;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END location_update;

PROCEDURE location_delete
(
	p_system_user_location_id	IN	SYSTEM_USER_LOCATION.SYSTEM_USER_LOCATION_ID % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.location_delete';

BEGIN

	DELETE FROM system_user_location
	WHERE  system_user_location_id = p_system_user_location_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END location_delete;

-------------------------------------------------------------------------------------------------------------------
-- SYSTEM_USER_VEHICLE
-------------------------------------------------------------------------------------------------------------------
PROCEDURE vehicle_add
(
	p_system_user_vehicle_id		OUT	SYSTEM_USER_VEHICLE.SYSTEM_USER_VEHICLE_ID % TYPE,
	p_system_user_id			IN	SYSTEM_USER_VEHICLE.SYSTEM_USER_ID % TYPE,
	p_vehicle_make				IN	SYSTEM_USER_VEHICLE.VEHICLE_MAKE % TYPE,
	p_vehicle_model				IN	SYSTEM_USER_VEHICLE.VEHICLE_MODEL % TYPE,
	p_vehicle_year				IN	SYSTEM_USER_VEHICLE.VEHICLE_YEAR % TYPE,
	p_vehicle_color				IN	SYSTEM_USER_VEHICLE.VEHICLE_COLOR % TYPE,
	p_vehicle_license_plate			IN	SYSTEM_USER_VEHICLE.VEHICLE_LICENSE_PLATE % TYPE,
	p_vehicle_license_state			IN	SYSTEM_USER_VEHICLE.VEHICLE_LICENSE_STATE % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.vehicle_add';

BEGIN

	INSERT INTO system_user_vehicle
	(
		system_user_id,
		vehicle_make,
		vehicle_model,
		vehicle_year,
		vehicle_color,
		vehicle_license_plate,
		vehicle_license_state
	)
	VALUES
	(
		p_system_user_id,
		p_vehicle_make,
		p_vehicle_model,
		p_vehicle_year,
		p_vehicle_color,
		p_vehicle_license_plate,
		p_vehicle_license_state
	)
	RETURNING system_user_vehicle_id INTO p_system_user_vehicle_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END vehicle_add;

PROCEDURE vehicle_update
(
	p_system_user_vehicle_id		IN	SYSTEM_USER_VEHICLE.SYSTEM_USER_VEHICLE_ID % TYPE,
	p_vehicle_make				IN	SYSTEM_USER_VEHICLE.VEHICLE_MAKE % TYPE,
	p_vehicle_model				IN	SYSTEM_USER_VEHICLE.VEHICLE_MODEL % TYPE,
	p_vehicle_year				IN	SYSTEM_USER_VEHICLE.VEHICLE_YEAR % TYPE,
	p_vehicle_color				IN	SYSTEM_USER_VEHICLE.VEHICLE_COLOR % TYPE,
	p_vehicle_license_plate			IN	SYSTEM_USER_VEHICLE.VEHICLE_LICENSE_PLATE % TYPE,
	p_vehicle_license_state			IN	SYSTEM_USER_VEHICLE.VEHICLE_LICENSE_STATE % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.vehicle_update';

BEGIN

	UPDATE system_user_vehicle SET
		vehicle_make = p_vehicle_make,
		vehicle_model = p_vehicle_model,
		vehicle_year = p_vehicle_year,
		vehicle_color = p_vehicle_color,
		vehicle_license_plate = p_vehicle_license_plate,
		vehicle_license_state = p_vehicle_license_state
	WHERE system_user_vehicle_id = p_system_user_vehicle_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END vehicle_update;

PROCEDURE vehicle_delete
(
	p_system_user_vehicle_id		IN	SYSTEM_USER_VEHICLE.SYSTEM_USER_VEHICLE_ID % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.vehicle_delete';

BEGIN

	DELETE FROM system_user_vehicle
	WHERE system_user_vehicle_id = p_system_user_vehicle_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END vehicle_delete;

-------------------------------------------------------------------------------------------------------------------
-- SYSTEM_USER_PHONE
-------------------------------------------------------------------------------------------------------------------
PROCEDURE phone_add
(
	p_system_user_phone_id		OUT	SYSTEM_USER_PHONE.SYSTEM_USER_PHONE_ID % TYPE,
	p_system_user_id		IN	SYSTEM_USER_PHONE.SYSTEM_USER_ID % TYPE,
	p_phone_type_order		IN	SYSTEM_USER_PHONE.PHONE_TYPE_ORDER % TYPE,
	p_phone_number_type		IN	SYSTEM_USER_PHONE.PHONE_NUMBER_TYPE % TYPE,
	p_iso_country_code		IN	SYSTEM_USER_PHONE.ISO_COUNTRY_CODE % TYPE,
	p_phone_number			IN	SYSTEM_USER_PHONE.PHONE_NUMBER % TYPE,
	p_phone_extension		IN	SYSTEM_USER_PHONE.PHONE_EXTENSION % TYPE,
	p_contact_notes			IN	SYSTEM_USER_PHONE.CONTACT_NOTES % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.phone_add';

BEGIN

	INSERT INTO system_user_phone
	(
		system_user_id,
		phone_number_type,
		phone_type_order,
		iso_country_code,
		phone_number,
		phone_extension,
		contact_notes
	)
	VALUES
	(
		p_system_user_id,
		p_phone_number_type,
		p_phone_type_order,
		p_iso_country_code,
		p_phone_number,
		p_phone_extension,
		p_contact_notes
	)
	RETURNING system_user_phone_id INTO p_system_user_phone_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END phone_add;

PROCEDURE phone_update
(
	p_system_user_phone_id		IN	SYSTEM_USER_PHONE.SYSTEM_USER_PHONE_ID % TYPE,
	p_phone_type_order		IN	SYSTEM_USER_PHONE.PHONE_TYPE_ORDER % TYPE,
	p_phone_number_type		IN	SYSTEM_USER_PHONE.PHONE_NUMBER_TYPE % TYPE,
	p_iso_country_code		IN	SYSTEM_USER_PHONE.ISO_COUNTRY_CODE % TYPE,
	p_phone_number			IN	SYSTEM_USER_PHONE.PHONE_NUMBER % TYPE,
	p_phone_extension		IN	SYSTEM_USER_PHONE.PHONE_EXTENSION % TYPE,
	p_contact_notes			IN	SYSTEM_USER_PHONE.CONTACT_NOTES % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.phone_update';
v_sql			VARCHAR2(2048);

BEGIN
	--
	-- system_user_id must not be null
	--
	IF p_system_user_phone_id IS NULL
	THEN
		raise VALUE_ERROR;
	END IF;

	--
	-- put together some sql
	--
	dsql_update_term(v_sql, 'phone_type_order', p_phone_type_order);
	dsql_update_term(v_sql, 'phone_number_type', p_phone_number_type);
	dsql_update_term(v_sql, 'iso_country_code', p_iso_country_code);
	dsql_update_term(v_sql, 'phone_number', p_phone_number);
	dsql_update_term(v_sql, 'phone_extension', p_phone_extension);
	dsql_update_term(v_sql, 'contact_notes', p_contact_notes);

	--
	-- better make sure they actually want something
	--
	IF v_sql IS NULL
	THEN
		raise VALUE_ERROR;
	END IF;

	--
	-- finish it
	--
	v_sql := 'UPDATE system_user_phone SET ' || v_sql ||
		' WHERE system_user_phone_id = ' || p_system_user_phone_id;

	--
	-- run it
	--
	EXECUTE IMMEDIATE v_sql;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END phone_update;

PROCEDURE phone_delete
(
	p_system_user_phone_id		IN	SYSTEM_USER_PHONE.SYSTEM_USER_PHONE_ID % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.phone_delete';

BEGIN

	DELETE FROM system_user_phone
	WHERE system_user_phone_id = p_system_user_phone_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END phone_delete;

PROCEDURE phone_delete_type
(
	p_system_user_id		IN	SYSTEM_USER_PHONE.SYSTEM_USER_ID % TYPE,
	p_phone_number_type		IN	SYSTEM_USER_PHONE.PHONE_NUMBER_TYPE % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.phone_delete_type';

BEGIN

	DELETE FROM system_user_phone
	WHERE system_user_id = p_system_user_id
	AND phone_number_type = p_phone_number_type;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END phone_delete_type;

PROCEDURE phone_search
(
	p_system_user_id		IN	SYSTEM_USER_PHONE.SYSTEM_USER_ID % TYPE,
	p_system_user_phone_id		IN	SYSTEM_USER_PHONE.SYSTEM_USER_PHONE_ID % TYPE,
	p_phone_number_type		IN	SYSTEM_USER_PHONE.PHONE_NUMBER_TYPE % TYPE,
	p_iso_country_code		IN	SYSTEM_USER_PHONE.ISO_COUNTRY_CODE % TYPE,
	p_phone_number			IN	varchar2,
	p_phone_extension		IN	varchar2,
	p_contact_notes			IN	SYSTEM_USER_PHONE.CONTACT_NOTES % TYPE,
	p_cursor			OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.phone_search';

BEGIN

	OPEN p_cursor FOR
		SELECT
			u.system_user_id,
			u.login,
			u.first_name,
			u.middle_name,
			u.last_name,
			u.name_suffix,
			u.preferred_first_name,
			u.preferred_last_name,
			u.employee_id,
			u.gender,
			u.system_user_status,
			u.system_user_type,
			u.employee_id,
			u.position_title,
			p.system_user_phone_id,
			p.phone_number_type,
			p.phone_type_order,
			p.iso_country_code,
			p.phone_number,
			p.phone_extension,
			p.contact_notes
		FROM system_user_phone p, system_user u
		WHERE u.system_user_id = p.system_user_id
		AND u.system_user_status = 'enabled'
		AND ((p_system_user_id IS NULL) OR (p_system_user_id = p.system_user_id))
		AND ((p_system_user_phone_id IS NULL) OR (p_system_user_phone_id = p.system_user_phone_id))
		AND ((p_phone_number_type IS NULL) OR (p_phone_number_type = p.phone_number_type))
		AND ((p_iso_country_code IS NULL) OR (p_iso_country_code = p.iso_country_code))
		AND ((p_contact_notes IS NULL) OR (lower(p.contact_notes) LIKE lower(p_contact_notes)))
		AND ((p_phone_extension IS NULL) OR (p.phone_extension LIKE lower(p_phone_extension)))
		AND ((p_phone_number IS NULL) OR (p.phone_number LIKE lower(p_phone_number)));

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END phone_search;

-------------------------------------------------------------------------------------------------------------------
--add to the dept_member table
-------------------------------------------------------------------------------------------------------------------
PROCEDURE dept_add
(
	p_dept_id			IN	DEPT_MEMBER.DEPT_ID % TYPE,
	p_system_user_id		IN	DEPT_MEMBER.SYSTEM_USER_ID % TYPE,
	p_reporting_type		IN	DEPT_MEMBER.REPORTING_TYPE % TYPE,
	p_start_date			IN	DEPT_MEMBER.START_DATE % TYPE,
	p_finish_date			IN	DEPT_MEMBER.FINISH_DATE % TYPE,
	p_approval_type			IN	DEPT_MEMBER.APPROVAL_TYPE %TYPE DEFAULT NULL,
	p_approval_ref			IN	DEPT_MEMBER.APPROVAL_REF_NUM %TYPE DEFAULT NULL
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.dept_add';
v_approval_type		DEPT_MEMBER.APPROVAL_TYPE %TYPE;
v_approval_ref		DEPT_MEMBER.APPROVAL_REF_NUM %TYPE;

BEGIN

	-- this is horribly disgusting, but it is not as horribly
	-- disgusting as figuring out the HR import code to make it
	-- pass correctly.  Jesus.
	if p_approval_type is null  then
		v_approval_type := 'feed';
		v_approval_ref := 'hris-import';
	end if;

	INSERT INTO dept_member
	(
		dept_id,
		system_user_id,
		reporting_type,
		start_date,
		finish_date,
		approval_type,
		approval_ref_num
	)
	VALUES
	(
		p_dept_id,
		p_system_user_id,
		p_reporting_type,
		p_start_date,
		p_finish_date,
		v_approval_type,
		v_approval_ref
	);

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END dept_add;

PROCEDURE dept_update
(
	p_prev_id			IN	DEPT_MEMBER.DEPT_ID % TYPE,
	p_system_user_id		IN	DEPT_MEMBER.SYSTEM_USER_ID % TYPE,
	p_dept_id			IN	DEPT_MEMBER.DEPT_ID % TYPE,
	p_reporting_type		IN	DEPT_MEMBER.REPORTING_TYPE % TYPE,
	p_start_date			IN	DEPT_MEMBER.START_DATE % TYPE,
	p_finish_date			IN	DEPT_MEMBER.FINISH_DATE % TYPE,
	p_approval_type			IN	DEPT_MEMBER.APPROVAL_TYPE %TYPE DEFAULT NULL,
	p_approval_ref			IN	DEPT_MEMBER.APPROVAL_REF_NUM %TYPE DEFAULT NULL
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.dept_update';
v_sql			VARCHAR2(2048);
v_approval_type		DEPT_MEMBER.APPROVAL_TYPE %TYPE;
v_approval_ref		DEPT_MEMBER.APPROVAL_REF_NUM %TYPE;

BEGIN
	--
	-- system_user_id must not be null
	--
	IF p_system_user_id IS NULL OR p_prev_id IS NULL
	THEN
		raise VALUE_ERROR;
	END IF;

	-- this is horribly disgusting, but it is not as horribly
	-- disgusting as figuring out the HR import code to make it
	-- pass correctly.  Jesus.
	if p_approval_type is null  then
		v_approval_type := 'feed';
		v_approval_ref := 'hris-import';
	end if;

	--
	-- put together some sql
	--
	dsql_update_term(v_sql, 'dept_id', p_dept_id);
	dsql_update_term(v_sql, 'reporting_type', p_reporting_type);
	dsql_update_term(v_sql, 'start_date', p_start_date, 'date');
	dsql_update_term(v_sql, 'finish_date', p_finish_date, 'date');

	--
	-- better make sure they actually want something
	--
	IF v_sql IS NULL
	THEN
		raise VALUE_ERROR;
	END IF;

	--
	-- finish it
	--
	v_sql := 'UPDATE dept_member SET ' || v_sql ||
		' WHERE system_user_id = ' || p_system_user_id ||
		' AND dept_id = ' || p_prev_id;

	--
	-- run it
	--
	EXECUTE IMMEDIATE v_sql;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END dept_update;

PROCEDURE dept_delete
(
	p_system_user_id		IN	DEPT_MEMBER.SYSTEM_USER_ID % TYPE,
	p_dept_id			IN	DEPT_MEMBER.DEPT_ID % TYPE,
	p_approval_type			IN	DEPT_MEMBER.APPROVAL_TYPE %TYPE DEFAULT NULL,
	p_approval_ref			IN	DEPT_MEMBER.APPROVAL_REF_NUM %TYPE DEFAULT NULL
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.dept_delete';
v_approval_type		DEPT_MEMBER.APPROVAL_TYPE %TYPE;
v_approval_ref		DEPT_MEMBER.APPROVAL_REF_NUM %TYPE;

BEGIN

	-- this is horribly disgusting, but it is not as horribly
	-- disgusting as figuring out the HR import code to make it
	-- pass correctly.  Jesus.
	if p_approval_type is null  then
		v_approval_type := 'feed';
		v_approval_ref := 'hris-import';
	end if;

	-- we do this to keep track of the reason for the deletion
	UPDATE dept_member
    SET approval_type = v_approval_type,
		approval_ref_num = v_approval_ref
	WHERE system_user_id = p_system_user_id
	AND dept_id = p_dept_id;

	DELETE FROM dept_member
	WHERE system_user_id = p_system_user_id
	AND dept_id = p_dept_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END dept_delete;

PROCEDURE dept_delete_type
(
	p_system_user_id		IN	DEPT_MEMBER.SYSTEM_USER_ID % TYPE,
	p_reporting_type		IN	DEPT_MEMBER.REPORTING_TYPE % TYPE,
	p_approval_type			IN	DEPT_MEMBER.APPROVAL_TYPE %TYPE DEFAULT NULL,
	p_approval_ref			IN	DEPT_MEMBER.APPROVAL_REF_NUM %TYPE DEFAULT NULL
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.dept_delete_type';
v_approval_type		DEPT_MEMBER.APPROVAL_TYPE %TYPE;
v_approval_ref		DEPT_MEMBER.APPROVAL_REF_NUM %TYPE;

BEGIN
	-- this is horribly disgusting, but it is not as horribly
	-- disgusting as figuring out the HR import code to make it
	-- pass correctly.  Jesus.
	if p_approval_type is null  then
		v_approval_type := 'feed';
		v_approval_ref := 'hris-import';
	end if;

	-- we do this to keep track of the reason for the deletion
	UPDATE dept_member
    	SET approval_type = v_approval_type,
		approval_ref_num = v_approval_ref
	WHERE system_user_id = p_system_user_id
	AND reporting_type = p_reporting_type;

	DELETE FROM dept_member
	WHERE system_user_id = p_system_user_id
	AND reporting_type = p_reporting_type;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END dept_delete_type;

-------------------------------------------------------------------------------------------------------------------
-- SYSTEM_USER_XREF
-------------------------------------------------------------------------------------------------------------------
PROCEDURE xref_add
(
	p_system_user_id		IN	SYSTEM_USER_XREF.SYSTEM_USER_ID % TYPE,
	p_external_hr_id			IN	SYSTEM_USER_XREF.EXTERNAL_HR_ID % TYPE,
	p_payroll_id			IN	SYSTEM_USER_XREF.PAYROLL_ID % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.xref_add';

BEGIN

	--
	-- mapping
	--
	INSERT INTO system_user_xref
	(
		system_user_id,
		external_hr_id,
		payroll_id
	)
	VALUES
	(
		p_system_user_id,
		p_external_hr_id,
		p_payroll_id
	);

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END xref_add;

PROCEDURE xref_update
(
	p_system_user_id		IN	SYSTEM_USER_XREF.SYSTEM_USER_ID % TYPE,
	p_external_hr_id			IN	SYSTEM_USER_XREF.EXTERNAL_HR_ID % TYPE,
	p_payroll_id			IN	SYSTEM_USER_XREF.PAYROLL_ID % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.xref_add';
v_sql			VARCHAR2(2048);

BEGIN
	IF p_system_user_id IS NULL
	THEN
		raise VALUE_ERROR;
	END IF;

	dsql_update_term(v_sql, 'payroll_id', p_payroll_id);
	dsql_update_term(v_sql, 'external_hr_id', p_external_hr_id);

	IF v_sql IS NULL
	THEN
		raise VALUE_ERROR;
	END IF;

	v_sql := 'UPDATE system_user_xref SET ' || v_sql ||
		' WHERE system_user_id = ' || p_system_user_id;

	EXECUTE IMMEDIATE v_sql;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END xref_update;

-------------------------------------------------------------------------------------------------------------------
-- return company information
-------------------------------------------------------------------------------------------------------------------
PROCEDURE info_company
(
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.info_company';

BEGIN

	OPEN p_cursor FOR
		SELECT company_id,
			company_name,
			company_code,
			is_corporate_family,
			description,
			account_prefix
		FROM company;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END info_company;

-------------------------------------------------------------------------------------------------------------------
-- return reporting types
-------------------------------------------------------------------------------------------------------------------
PROCEDURE info_reporting
(
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.info_reporting';

BEGIN

	OPEN p_cursor FOR
		SELECT reporting_type, description
		FROM val_reporting_type;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END info_reporting;

-------------------------------------------------------------------------------------------------------------------
-- return country_code information
-------------------------------------------------------------------------------------------------------------------
PROCEDURE info_countrycode
(
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.info_countrycode';

BEGIN

	OPEN p_cursor FOR
		SELECT dial_country_code, iso_country_code, country_name
		FROM val_country_code;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END info_countrycode;

-------------------------------------------------------------------------------------------------------------------
-- return department information
-------------------------------------------------------------------------------------------------------------------
PROCEDURE info_dept
(
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.info_dept';

BEGIN

	OPEN p_cursor FOR
		SELECT d.dept_id,
			d.dept_code,
			d.cost_center,
			d.name,
			d.company_id,
			d.is_active,
			d.parent_dept_id,
			p.dept_code parent_dept_code,
			c.company_name,
			c.company_code,
			d.manager_system_user_id,
			u.first_name,
			u.last_name
		FROM dept d, system_user u, company c, dept p
		WHERE d.company_id = c.company_id
		AND d.manager_system_user_id = u.system_user_id(+)
		AND d.parent_dept_id = p.dept_id(+)
		ORDER BY c.company_id ASC, d.dept_code ASC;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END info_dept;

-------------------------------------------------------------------------------------------------------------------
-- return office_site information
-------------------------------------------------------------------------------------------------------------------
PROCEDURE info_site
(
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.info_site';

BEGIN

	OPEN p_cursor FOR
		SELECT office_site, description
		FROM val_office_site;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END info_site;

-------------------------------------------------------------------------------------------------------------------
-- return user type information
-------------------------------------------------------------------------------------------------------------------
PROCEDURE info_types
(
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.info_types';

BEGIN

	OPEN p_cursor FOR
		SELECT system_user_type, description
		FROM val_system_user_type
		WHERE is_person = 'Y';

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END info_types;

-------------------------------------------------------------------------------------------------------------------
-- return user status information
-------------------------------------------------------------------------------------------------------------------
PROCEDURE info_status
(
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.info_status';

BEGIN

	OPEN p_cursor FOR
		SELECT system_user_status, description
		FROM val_system_user_status;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END info_status;

-------------------------------------------------------------------------------------------------------------------
-- return user location_type information
-------------------------------------------------------------------------------------------------------------------
PROCEDURE info_location_type
(
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.info_location_type';

BEGIN

	OPEN p_cursor FOR
		SELECT system_user_location_type, description
		FROM val_user_location_type;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END info_location_type;

PROCEDURE info_xref
(
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.info_xref';

BEGIN

	OPEN p_cursor FOR
		SELECT x.system_user_id,
			x.external_hr_id,
			x.payroll_id,
			c.company_code
		FROM system_user_xref x, company c, system_user u
		WHERE x.system_user_id = u.system_user_id
		AND u.company_id(+) = c.company_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END info_xref;

PROCEDURE info_phone
(
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.info_phone';

BEGIN

	OPEN p_cursor FOR
		SELECT p.system_user_id,
			p.system_user_phone_id,
			p.phone_type_order,
			p.phone_number_type,
			p.iso_country_code,
			p.phone_number,
			p.phone_extension,
			p.contact_notes
		FROM system_user_phone p;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END info_phone;

PROCEDURE info_location
(
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.info_location';

BEGIN

	OPEN p_cursor FOR
		SELECT l.system_user_id,
			l.system_user_location_id,
			l.system_user_location_type,
			l.office_site,
			l.address_1,
			l.address_2,
			l.city,
			l.state,
			l.postal_code,
			l.country,
			l.building,
			l.floor,
			l.section,
			l.seat_number
		FROM system_user_location l;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END info_location;

PROCEDURE info_vehicle
(
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.info_vehicle';

BEGIN

	OPEN p_cursor FOR
		SELECT v.system_user_id,
			v.system_user_vehicle_id,
			v.vehicle_make,
			v.vehicle_model,
			v.vehicle_year,
			v.vehicle_color,
			v.vehicle_license_plate,
			v.vehicle_license_state
		FROM system_user_vehicle v;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END info_vehicle;

PROCEDURE info_member
(
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.info_member';

BEGIN

	OPEN p_cursor FOR
		SELECT
			m.system_user_id,
			m.dept_id,
			to_char(m.start_date, 'YYYY-MM-DD') START_DATE,
			to_char(m.finish_date, 'YYYY-MM-DD') FINISH_DATE,
			m.reporting_type,
			d.name "DEPT_NAME",
			d.dept_code,
			d.parent_dept_id,
			d.is_active,
			u.manager_system_user_id,
			mgr.first_name "MANAGER_FIRST_NAME",
			mgr.middle_name "MANAGER_MIDDLE_NAME",
			mgr.last_name "MANAGER_LAST_NAME",
			d.company_id,
			c.company_code,
			c.company_name
		FROM system_user u, dept_member m, company c, dept d, system_user mgr
		WHERE m.system_user_id = u.system_user_id
		AND m.dept_id = d.dept_id
		AND d.company_id = c.company_id
		AND mgr.system_user_id(+) = u.manager_system_user_id
		AND m.reporting_type = 'direct';

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END info_member;

----------------------------------------------------------------------------------------------------------------------
----- search on user information
----------------------------------------------------------------------------------------------------------------------

PROCEDURE user_search
(
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_employee_id		IN	SYSTEM_USER.EMPLOYEE_ID % TYPE,
	p_manager_id		IN	SYSTEM_USER.MANAGER_SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_legal_only		IN	VARCHAR2,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_gender		IN	SYSTEM_USER.GENDER % TYPE,
	p_title			IN	SYSTEM_USER.POSITION_TITLE % TYPE,
	p_badge			IN	SYSTEM_USER.BADGE_ID % TYPE,
	p_company_id		IN	SYSTEM_USER.COMPANY_ID % TYPE,
	p_use_dept_company	IN	VARCHAR2,
	p_status		IN	SYSTEM_USER.SYSTEM_USER_STATUS % TYPE,
	p_type			IN	SYSTEM_USER.SYSTEM_USER_TYPE % TYPE,
	p_dept_code		IN	DEPT.DEPT_CODE % TYPE,
	p_dept_id		IN	DEPT.DEPT_ID % TYPE,
	p_phone_number		IN	VARCHAR2,
	p_phone_number_type	IN	SYSTEM_USER_PHONE.PHONE_NUMBER_TYPE % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.user_search';
v_legal_only		VARCHAR2(1);
v_use_dept_company	VARCHAR2(1);

BEGIN
	--
	-- 'cause i'm stupid and can't get default in procedure
	-- declaration to work for me.  neither could i get boolean
	-- specifications in the query below to work.
	--
	IF p_legal_only IS NULL
	OR p_legal_only = '0'
	OR lower(p_legal_only) = 'n'
	OR lower(p_legal_only) = 'false'
	THEN
		v_legal_only := 'N';
	ELSE
		v_legal_only := 'Y';
	END IF;

	--
	-- same as above for dept_company
	--
	IF p_use_dept_company IS NULL
	OR p_use_dept_company = '0'
	OR lower(p_use_dept_company) = 'n'
	OR lower(p_use_dept_company) = 'false'
	THEN
		v_use_dept_company := 'N';
	ELSE
		v_use_dept_company := 'Y';
	END IF;

	--
	-- even though one of the search parameters is a phone number, don't
	-- actually return it.  the problem with returning it is that there
	-- may be more than one phone number per user record.  just search
	-- on it.
	--
	-- the same holds true for dept_code's.
	--
	OPEN p_cursor FOR
		SELECT
			u.system_user_id,
			u.login,
			u.first_name,
			u.middle_name,
			u.last_name,
			u.name_suffix,
			u.system_user_status,
			u.system_user_type,
			u.employee_id,
			u.badge_id,
			u.manager_system_user_id,
			u.position_title,
			u.company_id,
			u.gender,
			u.preferred_first_name,
			u.preferred_last_name,
			to_char(u.hire_date, 'YYYY-MM-DD HH24:MI') hire_date,
			to_char(u.termination_date, 'YYYY-MM-DD HH24:MI') termination_date,
			u.shirt_size,
			u.pant_size,
			u.hat_size,
			c.company_name,
			c.company_code,
			c.description company_description,
			c.is_corporate_family,
			d.parent_dept_id,
			d.manager_system_user_id dept_manager_system_user_id,
			d.company_id dept_company_id,
			d.dept_code,
			d.cost_center dept_cost_center,
			d.dept_ou,
			d.is_active,
			m.dept_id,
			m.start_date dept_start_date,
			m.finish_date dept_finish_date,
			x.external_hr_id,
			x.payroll_id,
			u.data_ins_user,
			u.data_upd_user,
			u.data_ins_date,
			u.data_upd_date
                FROM system_user u, company c, dept_member m, dept d, val_system_user_type t, system_user_xref x

		--
		-- ensure that only one record per person is output
		--
		WHERE u.company_id = c.company_id
		AND t.system_user_type = u.system_user_type
		AND t.is_person = 'Y'
		AND u.system_user_id = x.system_user_id (+)
		AND u.system_user_id = m.system_user_id (+)
		AND m.dept_id = d.dept_id (+)
		AND (m.reporting_type IS NULL OR m.reporting_type = 'direct')

		--
		-- simple parameters
		--
		AND (p_system_user_id IS NULL OR p_system_user_id = u.system_user_id)
		AND (p_employee_id IS NULL OR p_employee_id = u.employee_id)
		AND (p_login IS NULL OR lower(u.login) LIKE lower(p_login))
		AND (p_gender IS NULL OR lower(u.gender) LIKE lower(p_gender))
		AND (p_title IS NULL OR lower(u.position_title) LIKE lower(p_title))
		AND (p_badge IS NULL OR u.badge_id = p_badge)
		AND (p_status IS NULL OR lower(u.system_user_status) LIKE lower(p_status))
		AND (p_type IS NULL OR lower(u.system_user_type) LIKE lower(p_type))
		AND (p_manager_id IS NULL OR u.manager_system_user_id = p_manager_id)
		AND (p_middle_name IS NULL OR lower(u.middle_name) LIKE lower(p_middle_name))

		--
		-- match names based on legal_only OR preferred too
		--
		AND (p_first_name IS NULL OR
			(
				lower(u.first_name) LIKE lower(p_first_name) OR
				(v_legal_only = 'N' AND lower(u.preferred_first_name) LIKE lower(p_first_name))
			))
		AND (p_last_name IS NULL OR
			(
				lower(u.last_name) LIKE lower(p_last_name) OR
				(v_legal_only = 'N' AND (lower(u.preferred_last_name) LIKE lower(p_last_name)))
			))

		--
		-- companies are weird... need to look into dept when use_dept_company requested
		--
		AND ((p_company_id IS NULL) OR
			((v_use_dept_company = 'N' AND u.company_id = p_company_id)) OR
			((v_use_dept_company = 'Y' AND (u.company_id = p_company_id OR d.company_id = p_company_id)))
		)

		--
		-- limit by phone number, phone isn't actually in output (can't be)
		--
		AND ((p_phone_number IS NULL) OR (u.system_user_id IN
		(
			SELECT p.system_user_id
			FROM system_user_phone p
			WHERE p.phone_number LIKE p_phone_number
			AND ((p_phone_number_type IS NULL) OR (p.phone_number_type LIKE p_phone_number_type))
		)))

		--
		-- limit by dept_code
		--
		AND ((p_dept_code IS NULL) OR (u.system_user_id IN
		(
			SELECT m.system_user_id
			FROM dept_member m, dept d
			WHERE m.dept_id = d.dept_id
			AND m.reporting_type = 'direct'
			AND d.dept_code = p_dept_code
		)))

		--
		-- limit by dept_id
		--
		AND ((p_dept_id IS NULL) OR (u.system_user_id IN
		(
			SELECT m.system_user_id
			FROM dept_member m, dept d
			WHERE m.dept_id = d.dept_id
			AND m.reporting_type = 'direct'
			AND d.dept_id = p_dept_id
		)))
		;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END user_search;

--
-- parameters need to be the same as user_search() for ease of use
--
PROCEDURE seating_search
(
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_employee_id		IN	SYSTEM_USER.EMPLOYEE_ID % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.seating_search';

BEGIN

	OPEN p_cursor FOR
		SELECT
			u.system_user_id,
			u.login,
			u.first_name,
			u.middle_name,
			u.last_name,
			u.employee_id,
			u.position_title,
			l.system_user_location_id,
			l.building,
			l.floor,
			l.section,
			l.seat_number
		FROM system_user u, system_user_location l, val_system_user_type t
		WHERE u.system_user_id = l.system_user_id
		AND t.system_user_type = u.system_user_type
		AND t.is_person = 'Y'
		AND l.system_user_location_type = 'office'
		AND lower(l.office_site) = lower('holmdel')
		AND ((p_first_name IS NULL) OR (lower(first_name) LIKE lower(p_first_name)))
		AND ((p_middle_name IS NULL) OR (lower(middle_name) LIKE lower(p_middle_name)))
		AND ((p_last_name IS NULL) OR (lower(last_name) LIKE lower(p_last_name)))
		AND ((p_login IS NULL) OR (lower(login) LIKE lower(p_login)))
		AND ((p_employee_id IS NULL) OR (u.employee_id = p_employee_id));

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END seating_search;

PROCEDURE seating_update
(
	p_system_user_location_id	IN	SYSTEM_USER_LOCATION.SYSTEM_USER_LOCATION_ID % TYPE,
	p_building			IN	SYSTEM_USER_LOCATION.BUILDING % TYPE,
	p_floor				IN	SYSTEM_USER_LOCATION.FLOOR % TYPE,
	p_section			IN	SYSTEM_USER_LOCATION.SECTION % TYPE,
	p_seat_number			IN	SYSTEM_USER_LOCATION.SEAT_NUMBER % TYPE
)
AS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.seating_update';

BEGIN

	UPDATE system_user_location SET
		building = p_building,
		floor = p_floor,
		section = p_section,
		seat_number = p_seat_number
	WHERE system_user_location_id = p_system_user_location_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END seating_update;

----------------------------------------------------------------------------------------------------------------------
----- return supporting location information
----------------------------------------------------------------------------------------------------------------------

PROCEDURE matching_location
(
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.matching_location';

BEGIN

	OPEN p_cursor FOR
		SELECT
			system_user_location_id,
			system_user_id,
			system_user_location_type,
			office_site,
			address_1,
			address_2,
			city,
			state,
			postal_code,
			country,
			building,
			floor,
			section,
			seat_number
		FROM system_user_location
		WHERE p_system_user_id = system_user_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END matching_location;

PROCEDURE matching_dept
(
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.matching_dept';

BEGIN

	OPEN p_cursor FOR
		SELECT
			m.system_user_id,
			m.dept_id,
			to_char(m.start_date, 'YYYY-MM-DD') START_DATE,
			to_char(m.finish_date, 'YYYY-MM-DD') FINISH_DATE,
			m.reporting_type,
			d.name "DEPT_NAME",
			d.dept_code,
			d.parent_dept_id,
			d.manager_system_user_id,
			d.is_active,
			mgr.first_name "MANAGER_FIRST_NAME",
			mgr.middle_name "MANAGER_MIDDLE_NAME",
			mgr.last_name "MANAGER_LAST_NAME",
			d.company_id,
			c.company_code,
			c.company_name
		FROM dept_member m, company c, dept d, system_user mgr
		WHERE m.system_user_id = p_system_user_id
		AND m.dept_id = d.dept_id
		AND d.company_id = c.company_id
		AND mgr.system_user_id(+) = d.manager_system_user_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END matching_dept;

PROCEDURE matching_phone
(
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.matching_phone';

BEGIN

	OPEN p_cursor FOR
		SELECT
			system_user_phone_id,
			system_user_id,
			phone_type_order,
			phone_number_type,
			iso_country_code,
			phone_number,
			phone_extension,
			contact_notes
		FROM system_user_phone
		WHERE p_system_user_id = system_user_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END matching_phone;

PROCEDURE matching_vehicle
(
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.matching_vehicle';

BEGIN

	OPEN p_cursor FOR
		SELECT
			system_user_vehicle_id,
			system_user_id,
			vehicle_make,
			vehicle_model,
			vehicle_year,
			vehicle_color,
			vehicle_license_plate,
			vehicle_license_state
		FROM system_user_vehicle
		WHERE p_system_user_id = system_user_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END matching_vehicle;

----------------------------------------------------------------------------------------------------------------------
----- change reports
----------------------------------------------------------------------------------------------------------------------

PROCEDURE report_change_user
(
	p_reference_date	IN	SYSTEM_USER.DATA_INS_DATE % TYPE,
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.report_change_user';

BEGIN

	OPEN p_cursor FOR
		SELECT
			u.system_user_id,
			u.data_ins_user,
			u.data_ins_date,
			u.data_upd_user,
			u.data_upd_date,
			u.login,
			u.first_name,
			u.middle_name,
			u.last_name,
			u.employee_id,
			x.external_hr_id,
			x.payroll_id
		FROM system_user u, val_system_user_type t, system_user_xref x
		WHERE (u.data_ins_date > p_reference_date OR u.data_upd_date > p_reference_date)
		AND t.system_user_type = u.system_user_type
		AND t.is_person = 'Y'
		AND u.system_user_id = x.system_user_id (+)
		AND ((p_system_user_id IS NULL) OR (u.system_user_id = p_system_user_id))
		AND ((p_login IS NULL) OR (lower(login) LIKE lower(p_login)))
		AND ((p_first_name IS NULL) OR (lower(first_name) LIKE lower(p_first_name)))
		AND ((p_middle_name IS NULL) OR (lower(middle_name) LIKE lower(p_middle_name)))
		AND ((p_last_name IS NULL) OR (lower(last_name) LIKE lower(p_last_name)));

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END report_change_user;

PROCEDURE report_change_location
(
	p_reference_date	IN	SYSTEM_USER.DATA_INS_DATE % TYPE,
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.report_change_location';

BEGIN

	OPEN p_cursor FOR
		SELECT
			u.system_user_id,
			l.data_ins_user,
			l.data_ins_date,
			l.data_upd_user,
			l.data_upd_date,
			u.login,
			u.first_name,
			u.middle_name,
			u.last_name,
			u.employee_id
		FROM system_user u, system_user_location l, val_system_user_type t
		WHERE (l.data_ins_date > p_reference_date OR l.data_upd_date > p_reference_date)
		AND t.system_user_type = u.system_user_type
		AND t.is_person = 'Y'
		AND u.system_user_id = l.system_user_id
		AND ((p_system_user_id IS NULL) OR (u.system_user_id = p_system_user_id))
		AND ((p_login IS NULL) OR (lower(u.login) LIKE lower(p_login)))
		AND ((p_first_name IS NULL) OR (lower(u.first_name) LIKE lower(p_first_name)))
		AND ((p_middle_name IS NULL) OR (lower(u.middle_name) LIKE lower(p_middle_name)))
		AND ((p_last_name IS NULL) OR (lower(u.last_name) LIKE lower(p_last_name)));

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END report_change_location;

PROCEDURE report_change_phone
(
	p_reference_date	IN	SYSTEM_USER.DATA_INS_DATE % TYPE,
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.report_change_phone';

BEGIN

	OPEN p_cursor FOR
		SELECT
			u.system_user_id,
			p.system_user_phone_id,
			p.phone_type_order,
			p.phone_number,
			p.phone_number_type,
			p.data_ins_user,
			p.data_ins_date,
			p.data_upd_user,
			p.data_upd_date,
			u.login,
			u.first_name,
			u.middle_name,
			u.last_name,
			u.employee_id
		FROM system_user u, val_system_user_type t, system_user_phone p
		WHERE (p.data_ins_date > p_reference_date OR p.data_upd_date > p_reference_date)
		AND t.system_user_type = u.system_user_type
		AND t.is_person = 'Y'
		AND u.system_user_id = p.system_user_id
		AND ((p_system_user_id IS NULL) OR (u.system_user_id = p_system_user_id))
		AND ((p_login IS NULL) OR (lower(u.login) LIKE lower(p_login)))
		AND ((p_first_name IS NULL) OR (lower(u.first_name) LIKE lower(p_first_name)))
		AND ((p_middle_name IS NULL) OR (lower(u.middle_name) LIKE lower(p_middle_name)))
		AND ((p_last_name IS NULL) OR (lower(u.last_name) LIKE lower(p_last_name)));

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END report_change_phone;

PROCEDURE report_change_vehicle
(
	p_reference_date	IN	SYSTEM_USER.DATA_INS_DATE % TYPE,
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.report_change_vehicle';

BEGIN

	OPEN p_cursor FOR
		SELECT
			u.system_user_id,
			v.system_user_vehicle_id,
			v.data_ins_user,
			v.data_ins_date,
			v.data_upd_user,
			v.data_upd_date,
			u.login,
			u.first_name,
			u.middle_name,
			u.last_name,
			u.employee_id
		FROM system_user u, system_user_vehicle v, val_system_user_type t
		WHERE (v.data_ins_date > p_reference_date OR v.data_upd_date > p_reference_date)
		AND t.system_user_type = u.system_user_type
		AND t.is_person = 'Y'
		AND u.system_user_id = v.system_user_id
		AND ((p_system_user_id IS NULL) OR (u.system_user_id = p_system_user_id))
		AND ((p_login IS NULL) OR (lower(u.login) LIKE lower(p_login)))
		AND ((p_first_name IS NULL) OR (lower(u.first_name) LIKE lower(p_first_name)))
		AND ((p_middle_name IS NULL) OR (lower(u.middle_name) LIKE lower(p_middle_name)))
		AND ((p_last_name IS NULL) OR (lower(u.last_name) LIKE lower(p_last_name)));

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END report_change_vehicle;

PROCEDURE report_change_dept
(
	p_reference_date	IN	SYSTEM_USER.DATA_INS_DATE % TYPE,
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.report_change_dept';

BEGIN

	OPEN p_cursor FOR
		SELECT
			u.system_user_id,
			d.data_ins_user,
			d.data_ins_date,
			d.data_upd_user,
			d.data_upd_date,
			u.login,
			u.first_name,
			u.middle_name,
			u.last_name,
			u.employee_id,
			d.is_active,
			d.dept_code,
			d.name "DEPT_NAME"
		FROM system_user u, dept d, val_system_user_type t
		WHERE (d.data_ins_date > p_reference_date OR d.data_upd_date > p_reference_date)
		AND t.system_user_type = u.system_user_type
		AND t.is_person = 'Y'
		AND u.system_user_id = d.manager_system_user_id
		AND ((p_system_user_id IS NULL) OR (u.system_user_id = p_system_user_id))
		AND ((p_login IS NULL) OR (lower(u.login) LIKE lower(p_login)))
		AND ((p_first_name IS NULL) OR (lower(u.first_name) LIKE lower(p_first_name)))
		AND ((p_middle_name IS NULL) OR (lower(u.middle_name) LIKE lower(p_middle_name)))
		AND ((p_last_name IS NULL) OR (lower(u.last_name) LIKE lower(p_last_name)));

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END report_change_dept;

PROCEDURE report_change_member
(
	p_reference_date	IN	SYSTEM_USER.DATA_INS_DATE % TYPE,
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.JazzHands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.report_change_member';

BEGIN

	OPEN p_cursor FOR
		SELECT
			u.system_user_id,
			m.data_ins_user,
			m.data_ins_date,
			m.data_upd_user,
			m.data_upd_date,
			u.login,
			u.first_name,
			u.middle_name,
			u.last_name,
			u.employee_id
		FROM system_user u, dept_member m, val_system_user_type t
		WHERE (m.data_ins_date > p_reference_date OR m.data_upd_date > p_reference_date)
		AND t.system_user_type = u.system_user_type
		AND t.is_person = 'Y'
		AND u.system_user_id = m.system_user_id
		AND ((p_system_user_id IS NULL) OR (u.system_user_id = p_system_user_id))
		AND ((p_login IS NULL) OR (lower(u.login) LIKE lower(p_login)))
		AND ((p_first_name IS NULL) OR (lower(u.first_name) LIKE lower(p_first_name)))
		AND ((p_middle_name IS NULL) OR (lower(u.middle_name) LIKE lower(p_middle_name)))
		AND ((p_last_name IS NULL) OR (lower(u.last_name) LIKE lower(p_last_name)));

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END report_change_member;

--
-- return historical records
--
PROCEDURE system_user_history
(
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.history';
v_is_person		VAL_SYSTEM_USER_TYPE.IS_PERSON % TYPE;

BEGIN

	--
	-- only real people
	--
	SELECT is_person
	INTO v_is_person
	FROM system_user u, val_system_user_type t
	WHERE u.system_user_id = p_system_user_id
	AND u.system_user_type = t.system_user_type;

	--
	-- in case anyone can trick application into doing this...
	--
	IF v_is_person <> 'Y' THEN
		raise VALUE_ERROR;
	END IF;

	OPEN p_cursor FOR
		SELECT
			u.system_user_id,
			u.login,
			u.first_name,
			u.middle_name,
			u.last_name,
			u.name_suffix,
			u.system_user_status,
			u.system_user_type,
			u.employee_id,
			u.manager_system_user_id,
			u.position_title,
			u.company_id,
			u.badge_id,
			u.gender,
			u.preferred_first_name,
			u.preferred_last_name,
			to_char(u.hire_date, 'YYYY-MM-DD HH24:MI') hire_date,
			to_char(u.termination_date, 'YYYY-MM-DD HH24:MI') termination_date,
			u.shirt_size,
			u.pant_size,
			u.hat_size,
			u.dn_name,
			u.data_ins_user,
			u.data_upd_user,
			u.data_ins_date,
			u.data_upd_date,
			u.aud#action,
			u.aud#timestamp,
			u.aud#user
		FROM aud$system_user u
		WHERE u.system_user_id = p_system_user_id
		ORDER BY aud#timestamp
		;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END system_user_history;

----------------------------------------------------------------------------------------------------------------------
----- IMAGE
----------------------------------------------------------------------------------------------------------------------

PROCEDURE image_byid
(
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.image_byid';

BEGIN
	--
	-- should only be exactly 0 or 1 values
	--
	OPEN p_cursor FOR
		SELECT
			system_user_image_id,
			system_user_id,
			image_type,
			image_blob
		FROM system_user_image
		WHERE system_user_id = p_system_user_id;


EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END image_byid;

PROCEDURE image_inorup
(
	p_system_user_image_id	IN OUT	SYSTEM_USER_IMAGE.SYSTEM_USER_IMAGE_ID % TYPE,
	p_system_user_id	IN	SYSTEM_USER_IMAGE.SYSTEM_USER_ID % TYPE,
	p_image_type		IN	SYSTEM_USER_IMAGE.IMAGE_TYPE % TYPE,
	p_image_blob		IN OUT	SYSTEM_USER_IMAGE.IMAGE_BLOB % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.image_inorup';
v_control		INTEGER := 1;
v_actual_id		SYSTEM_USER_IMAGE.SYSTEM_USER_IMAGE_ID % TYPE;
v_actual_type		SYSTEM_USER_IMAGE.IMAGE_TYPE % TYPE;
v_actual_blob		SYSTEM_USER_IMAGE.IMAGE_BLOB % TYPE;
v_requested_type	SYSTEM_USER_IMAGE.IMAGE_TYPE % TYPE;

BEGIN
	--
	-- default image type
	--
	IF p_image_type IS NULL
	THEN
		v_requested_type := 'jpeg';
	ELSE
		v_requested_type := p_image_type;
	END IF;

	--
	-- use a block to capture query failure
	--
	BEGIN
		SELECT system_user_image_id, image_type, image_blob
		INTO v_actual_id, v_actual_type, v_actual_blob
		FROM system_user_image
		WHERE system_user_id = p_system_user_id;

	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			v_control := 0;

		WHEN TOO_MANY_ROWS THEN
			raise;

		WHEN OTHERS THEN
			raise;
	END;

	--
	-- disposition
	--
	IF v_control = 0
	THEN
		--
		-- easy, just do an insert, let the caller update the blob
		--
		INSERT INTO system_user_image
		(
			system_user_id,
			image_type,
			image_blob
		)
		VALUES
		(
			p_system_user_id,
			v_requested_type,
			EMPTY_BLOB()
		)
		RETURNING system_user_image_id INTO v_actual_id;

	ELSE
		--
		-- check before calling here to avoid "noise" in jazzhands
		-- audit records.
		--
		IF v_actual_type <> v_requested_type
		THEN
			UPDATE system_user_image SET
				image_type = v_requested_type
			WHERE system_user_image_id = v_actual_id;
		END IF;

		--
		-- force an update of the DATA_UPD_DATE field.
		-- the trigger will overwrite my value with sysdate.
		--
		UPDATE system_user_image SET
			data_upd_date = sysdate
		WHERE system_user_image_id = v_actual_id;
	END IF;

	--
	-- return to caller as a courtesy
	--
	p_system_user_image_id := v_actual_id;

	--
	-- now return a LOB for update, let the caller do updates as they see fit
	--
	SELECT image_blob
	INTO p_image_blob
	FROM system_user_image
	WHERE system_user_image_id = v_actual_id
	FOR UPDATE;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END image_inorup;

PROCEDURE image_search
(
	p_system_user_image_id	IN	SYSTEM_USER_IMAGE.SYSTEM_USER_IMAGE_ID % TYPE,
	p_system_user_id	IN	SYSTEM_USER_IMAGE.SYSTEM_USER_ID % TYPE,
	p_image_type		IN	SYSTEM_USER_IMAGE.IMAGE_TYPE % TYPE,
	p_badge_id		IN	SYSTEM_USER.BADGE_ID % TYPE,
	p_manager_id		IN	SYSTEM_USER.MANAGER_SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_gender		IN	SYSTEM_USER.GENDER % TYPE,
	p_title			IN	SYSTEM_USER.POSITION_TITLE % TYPE,
	p_company_id		IN	SYSTEM_USER.COMPANY_ID % TYPE,
	p_dept_code		IN	DEPT.DEPT_CODE % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.image_search';

BEGIN

	OPEN p_cursor FOR
		SELECT
			i.system_user_image_id,
			i.image_type,
			i.image_blob,
			u.system_user_id,
			u.login,
			u.badge_id,
			u.first_name,
			u.middle_name,
			u.last_name,
			u.name_suffix,
			u.system_user_status,
			u.system_user_type,
			u.employee_id,
			u.manager_system_user_id,
			u.position_title,
			u.company_id,
			u.gender,
			u.preferred_first_name,
			u.preferred_last_name,
			c.company_name,
			c.company_code,
			c.description "COMPANY_DESCRIPTION",
			c.is_corporate_family,
			i.data_upd_user,
			i.data_upd_date,
			i.data_ins_user,
			i.data_ins_date
                FROM system_user u, company c, val_system_user_type t, system_user_image i
		WHERE u.company_id = c.company_id
		AND t.system_user_type = u.system_user_type
		AND t.is_person = 'Y'
		AND u.system_user_id = i.system_user_id(+)
		AND u.badge_id IS NOT NULL
		AND ((p_system_user_id IS NULL) OR (p_system_user_id = u.system_user_id))
		AND ((p_first_name IS NULL) OR (lower(u.first_name) LIKE lower(p_first_name)))
		AND ((p_middle_name IS NULL) OR (lower(u.middle_name) LIKE lower(p_middle_name)))
		AND ((p_last_name IS NULL) OR (lower(u.last_name) LIKE lower(p_last_name)))
		AND ((p_login IS NULL) OR (lower(u.login) LIKE lower(p_login)))
		AND ((p_gender IS NULL) OR (lower(u.gender) LIKE lower(p_gender)))
		AND ((p_title IS NULL) OR (lower(u.position_title) LIKE lower(p_title)))
		AND ((p_company_id IS NULL) OR (u.company_id = p_company_id))
		AND ((p_manager_id IS NULL) OR (u.manager_system_user_id = p_manager_id))
		AND ((p_dept_code IS NULL) OR (u.system_user_id IN
		(
			SELECT m.system_user_id
			FROM dept_member m, dept d
			WHERE m.dept_id = d.dept_id
			AND m.reporting_type = 'direct'
			AND ((p_dept_code IS NULL) OR (d.dept_code = p_dept_code))
		)))
		;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END image_search;

-------------------------------------------------------------------------------------------------------------------
-- Company Data
-------------------------------------------------------------------------------------------------------------------
PROCEDURE company_insert
(
	p_company_id			OUT	COMPANY.COMPANY_ID % TYPE,
	p_company_name			IN	COMPANY.COMPANY_NAME % TYPE,
	p_company_code			IN	COMPANY.COMPANY_CODE % TYPE,
	p_description			IN	COMPANY.DESCRIPTION % TYPE,
	p_is_corporate_family		IN	COMPANY.IS_CORPORATE_FAMILY % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.company_insert';

BEGIN

	INSERT INTO company
	(
		company_id,
		company_name,
		company_code,
		description,
		is_corporate_family
	)
	VALUES
	(
		p_company_id,
		p_company_name,
		p_company_code,
		p_description,
		p_is_corporate_family
	);

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END company_insert;

PROCEDURE company_update
(
	p_company_id			IN	COMPANY.COMPANY_ID % TYPE,
	p_company_name			IN	COMPANY.COMPANY_NAME % TYPE,
	p_company_code			IN	COMPANY.COMPANY_CODE % TYPE,
	p_description			IN	COMPANY.DESCRIPTION % TYPE,
	p_is_corporate_family		IN	COMPANY.IS_CORPORATE_FAMILY % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.company_update';
v_sql			VARCHAR2(2048);

BEGIN

	--
	-- validation
	--
	IF p_company_id IS NULL
	THEN
		raise VALUE_ERROR;
	END IF;

	--
	-- put together some sql
	--
	dsql_update_term(v_sql, 'company_name', p_company_name);
	dsql_update_term(v_sql, 'company_code', p_company_code);
	dsql_update_term(v_sql, 'description', p_description);
	dsql_update_term(v_sql, 'is_corporate_family', p_is_corporate_family);

	--
	-- better make sure they actually want something
	--
	IF v_sql IS NULL
	THEN
		raise VALUE_ERROR;
	END IF;

	--
	-- finish it
	--
	v_sql := 'UPDATE company SET ' || v_sql || ' WHERE company_id = ' || p_company_id;

	--
	-- run it
	--
	EXECUTE IMMEDIATE v_sql;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END company_update;

-------------------------------------------------------------------------------------------------------------------
-- Department Data
-------------------------------------------------------------------------------------------------------------------
PROCEDURE department_insert
(
	p_dept_id			OUT	DEPT.DEPT_ID % TYPE,
	p_dept_name			IN	DEPT.NAME % TYPE,
	p_dept_code			IN	DEPT.DEPT_CODE % TYPE,
	p_manager_id			IN	DEPT.MANAGER_SYSTEM_USER_ID % TYPE,
	p_cost_center			IN	DEPT.COST_CENTER % TYPE,
	p_parent			IN	DEPT.PARENT_DEPT_ID % TYPE,
	p_company_id			IN	DEPT.COMPANY_ID % TYPE,
	p_badge_type_id			IN	DEPT.DEFAULT_BADGE_TYPE_ID % TYPE,
	p_dept_ou			IN	DEPT.DEPT_OU % TYPE,
	p_active			IN	DEPT.IS_ACTIVE % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.department_insert';

BEGIN

	INSERT INTO dept
	(
		name,
		dept_code,
		manager_system_user_id,
		cost_center,
		parent_dept_id,
		company_id,
		default_badge_type_id,
		dept_ou,
		is_active
	)
	VALUES
	(
		p_dept_name,
		p_dept_code,
		p_manager_id,
		p_cost_center,
		p_parent,
		p_company_id,
		p_badge_type_id,
		p_dept_ou,
		p_active
	)
	RETURNING dept_id INTO p_dept_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END department_insert;

PROCEDURE department_update
(
	p_dept_id			IN	DEPT.DEPT_ID % TYPE,
	p_dept_name			IN	DEPT.NAME % TYPE,
	p_dept_code			IN	DEPT.DEPT_CODE % TYPE,
	p_manager_id			IN	DEPT.MANAGER_SYSTEM_USER_ID % TYPE,
	p_cost_center			IN	DEPT.COST_CENTER % TYPE,
	p_parent			IN	DEPT.PARENT_DEPT_ID % TYPE,
	p_company_id			IN	DEPT.COMPANY_ID % TYPE,
	p_badge_type_id			IN	DEPT.DEFAULT_BADGE_TYPE_ID % TYPE,
	p_dept_ou			IN	DEPT.DEPT_OU % TYPE,
	p_active			IN	DEPT.IS_ACTIVE % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.department_update';
v_sql			VARCHAR2(2048);

BEGIN

	--
	-- put together some sql
	--
	dsql_update_term(v_sql, 'name', p_dept_name);
	dsql_update_term(v_sql, 'dept_code', p_dept_code);
	dsql_update_term(v_sql, 'manager_system_user_id', p_manager_id, 'id');
	dsql_update_term(v_sql, 'cost_center', p_cost_center);
	dsql_update_term(v_sql, 'parent_dept_id', p_parent, 'id');
	dsql_update_term(v_sql, 'company_id', p_company_id, 'id');
	dsql_update_term(v_sql, 'default_badge_type_id', p_badge_type_id, 'id');
	dsql_update_term(v_sql, 'dept_ou', p_dept_ou);
	dsql_update_term(v_sql, 'is_active', p_active);

	--
	-- better make sure they actually want something
	--
	IF v_sql IS NULL
	THEN
		raise VALUE_ERROR;
	END IF;

	--
	-- finish it
	--
	v_sql := 'UPDATE dept SET ' || v_sql || ' WHERE dept_id = ' || p_dept_id;

	--
	-- run it
	--
	EXECUTE IMMEDIATE v_sql;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END department_update;

PROCEDURE s2log_search
(
	p_log_id		IN	V_PORTAL_ACCESS.LOG_ID % TYPE,
	p_type_id		IN	V_PORTAL_ACCESS.TYPE_ID % TYPE,
	p_reason_id		IN	V_PORTAL_ACCESS.REASON_ID % TYPE,
	p_card_id		IN	V_PORTAL_ACCESS.CARD_ID % TYPE,
	p_portal_id		IN	V_PORTAL_ACCESS.PORTAL_ID % TYPE,
	p_timestamp		IN	DATE,
	p_wantrows		IN	NUMBER,
	p_wantdays		IN	NUMBER,
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_employee_id		IN	SYSTEM_USER.EMPLOYEE_ID % TYPE,
	p_manager_id		IN	SYSTEM_USER.MANAGER_SYSTEM_USER_ID % TYPE,
	p_first_name		IN	SYSTEM_USER.FIRST_NAME % TYPE,
	p_middle_name		IN	SYSTEM_USER.MIDDLE_NAME % TYPE,
	p_last_name		IN	SYSTEM_USER.LAST_NAME % TYPE,
	p_legal_only		IN	VARCHAR2,
	p_login			IN	SYSTEM_USER.LOGIN % TYPE,
	p_gender		IN	SYSTEM_USER.GENDER % TYPE,
	p_title			IN	SYSTEM_USER.POSITION_TITLE % TYPE,
	p_badge			IN	SYSTEM_USER.BADGE_ID % TYPE,
	p_company_id		IN	SYSTEM_USER.COMPANY_ID % TYPE,
	p_use_dept_company	IN	VARCHAR2,
	p_status		IN	SYSTEM_USER.SYSTEM_USER_STATUS % TYPE,
	p_type			IN	SYSTEM_USER.SYSTEM_USER_TYPE % TYPE,
	p_dept_code		IN	DEPT.DEPT_CODE % TYPE,
	p_dept_id		IN	DEPT.DEPT_ID % TYPE,
	p_phone_number		IN	VARCHAR2,
	p_phone_number_type	IN	SYSTEM_USER_PHONE.PHONE_NUMBER_TYPE % TYPE,
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.s2log_search';
v_legal_only		VARCHAR2(1);
v_use_dept_company	VARCHAR2(1);
v_time_limit		DATE := TO_DATE('2000-01-01', 'YYYY-MM-DD');

BEGIN
	--
	-- 'cause i'm stupid and can't get default in procedure
	-- declaration to work for me.  neither could i get boolean
	-- specifications in the query below to work.
	--
	IF p_legal_only IS NULL
	OR p_legal_only = '0'
	OR lower(p_legal_only) = 'n'
	OR lower(p_legal_only) = 'false'
	THEN
		v_legal_only := 'N';
	ELSE
		v_legal_only := 'Y';
	END IF;

	--
	-- same as above for dept_company
	--
	IF p_use_dept_company IS NULL
	OR p_use_dept_company = '0'
	OR lower(p_use_dept_company) = 'n'
	OR lower(p_use_dept_company) = 'false'
	THEN
		v_use_dept_company := 'N';
	ELSE
		v_use_dept_company := 'Y';
	END IF;

	--
	-- need limitations
	--
	IF p_wantdays IS NOT NULL
	THEN
		v_time_limit := sysdate - p_wantdays;
	END IF;

	--
	-- see the query comments for user_search().  they're applicable here too.
	-- should be basically the same query except for being driven by v_log.
	--
	OPEN p_cursor FOR
		SELECT *
		FROM
		(
			SELECT
				log.log_id,
				log.timestamp,
				log.reason_id,
				log.type_id,
				log.portal_id,
				log.portal_name,
				log.card_id,
				log.card_number,
				log.format_id,
				log.badge_id,
				to_char(u.hire_date, 'YYYY-MM-DD HH24:MI') hire_date,
				to_char(u.termination_date, 'YYYY-MM-DD HH24:MI') termination_date,
				c.company_name,
				c.company_code,
				c.description company_description,
				c.is_corporate_family,
				d.parent_dept_id,
				d.manager_system_user_id dept_manager_system_user_id,
				d.company_id dept_company_id,
				d.dept_code,
				d.cost_center dept_cost_center,
				d.dept_ou,
				d.is_active,
				m.dept_id,
				m.start_date dept_start_date,
				m.finish_date dept_finish_date,
				x.external_hr_id,
				x.payroll_id,
				u.system_user_id,
				u.first_name,
				u.middle_name,
				u.last_name,
				u.name_suffix,
				u.system_user_status,
				u.system_user_type,
				u.employee_id,
				u.login,
				u.company_id,
				u.gender,
				u.preferred_first_name,
				u.preferred_last_name,
				u.manager_system_user_id,
				u.description,
				u.data_ins_user,
				u.data_ins_date,
				u.data_upd_user,
				u.data_upd_date
			FROM system_user u, company c, dept_member m, dept d, system_user_xref x, v_portal_access log

			--
			-- ensure that only one record per person is output
			--
			WHERE u.company_id = c.company_id
			AND u.system_user_id = x.system_user_id (+)
			AND u.system_user_id = m.system_user_id (+)
			AND m.dept_id = d.dept_id (+)
			AND (m.reporting_type IS NULL OR m.reporting_type = 'direct')
			AND log.badge_id = u.badge_id (+)

			--
			-- try and limit data returns to reasonable chunks
			--
			AND (log.timestamp > v_time_limit)

			--
			-- portal parameters
			--
			AND (p_log_id IS NULL OR p_log_id = log.log_id)
			AND (p_type_id IS NULL OR p_type_id = log.type_id)
			AND (p_reason_id IS NULL OR p_reason_id = log.reason_id)
			AND (p_card_id IS NULL OR p_card_id = log.card_id)
			AND (p_portal_id IS NULL OR p_portal_id = log.portal_id)
			AND (p_timestamp IS NULL OR p_timestamp = log.timestamp)

			--
			-- simple parameters
			--
			AND (p_system_user_id IS NULL OR p_system_user_id = u.system_user_id)
			AND (p_employee_id IS NULL OR p_employee_id = u.employee_id)
			AND (p_login IS NULL OR lower(u.login) LIKE lower(p_login))
			AND (p_gender IS NULL OR lower(u.gender) LIKE lower(p_gender))
			AND (p_title IS NULL OR lower(u.position_title) LIKE lower(p_title))
			AND (p_badge IS NULL OR u.badge_id = p_badge)
			AND (p_status IS NULL OR lower(u.system_user_status) LIKE lower(p_status))
			AND (p_type IS NULL OR lower(u.system_user_type) LIKE lower(p_type))
			AND (p_manager_id IS NULL OR u.manager_system_user_id = p_manager_id)
			AND (p_middle_name IS NULL OR lower(u.middle_name) LIKE lower(p_middle_name))

			--
			-- match names based on legal_only OR preferred too
			--
			AND (p_first_name IS NULL OR
				(
					lower(u.first_name) LIKE lower(p_first_name) OR
					(v_legal_only = 'N' AND lower(u.preferred_first_name) LIKE lower(p_first_name))
				))
			AND (p_last_name IS NULL OR
				(
					lower(u.last_name) LIKE lower(p_last_name) OR
					(v_legal_only = 'N' AND (lower(u.preferred_last_name) LIKE lower(p_last_name)))
				))

			--
			-- companies are weird... need to look into dept when use_dept_company requested
			--
			AND ((p_company_id IS NULL) OR
				((v_use_dept_company = 'N' AND u.company_id = p_company_id)) OR
				((v_use_dept_company = 'Y' AND (u.company_id = p_company_id OR d.company_id = p_company_id)))
			)

			--
			-- limit by phone number, phone isn't actually in output (can't be)
			--
			AND ((p_phone_number IS NULL) OR (u.system_user_id IN
			(
				SELECT p.system_user_id
				FROM system_user_phone p
				WHERE p.phone_number LIKE p_phone_number
				AND ((p_phone_number_type IS NULL) OR (p.phone_number_type LIKE p_phone_number_type))
			)))

			--
			-- limit by dept_code
			--
			AND ((p_dept_code IS NULL) OR (u.system_user_id IN
			(
				SELECT m.system_user_id
				FROM dept_member m, dept d
				WHERE m.dept_id = d.dept_id
				AND m.reporting_type = 'direct'
				AND d.dept_code = p_dept_code
			)))

			--
			-- limit by dept_id
			--
			AND ((p_dept_id IS NULL) OR (u.system_user_id IN
			(
				SELECT m.system_user_id
				FROM dept_member m, dept d
				WHERE m.dept_id = d.dept_id
				AND m.reporting_type = 'direct'
				AND d.dept_id = p_dept_id
			)))

			--
			-- if we're limiting data, better sort it properly
			--
			ORDER BY log_id DESC
		)
		WHERE (p_wantrows IS NULL OR ROWNUM <= p_wantrows)
		;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END s2log_search;

PROCEDURE info_portal
(
	p_cursor		OUT	GLOBAL_TYPES.jazzhands_ref_cur
)
AS

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.info_portal';

BEGIN

	OPEN p_cursor FOR
		SELECT portal_id, portal_name
		FROM s2portal;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END info_portal;

END;
/
