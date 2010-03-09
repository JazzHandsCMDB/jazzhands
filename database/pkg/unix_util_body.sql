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
PACKAGE BODY unix_util IS

GC_pkg_name		CONSTANT USER_OBJECTS.OBJECT_NAME % TYPE := 'unix_util';
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



-------------------------------------------------------------------------------------------------------------------
--local procedures
-------------------------------------------------------------------------------------------------------------------
PROCEDURE select_ids
(
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_gid			OUT	UNIX_GROUP.UNIX_GID % TYPE,
	p_uid			OUT	USER_UNIX_INFO.UNIX_UID % TYPE
)
IS
v_loopcount				integer := 0;
v_matches				integer;
v_type					SYSTEM_USER.SYSTEM_USER_TYPE % TYPE;

BEGIN

	--
	-- retrieve the type
	--
	SELECT system_user_type
	INTO v_type
	FROM system_user
	WHERE system_user_id = p_system_user_id;

	--
	-- get a suitable starting place for a gid
	--
	IF v_type = 'pseudouser'
	THEN
		SELECT min(unix_gid) - 1
		INTO p_gid
		FROM unix_group
		WHERE unix_gid >= 5001
		AND unix_gid < 10000;

	ELSIF v_type = 'blacklist'
	THEN
		SELECT min(unix_gid) - 1
		INTO p_gid
		FROM unix_group
		WHERE unix_gid >= 4000
		AND unix_gid < 5000;

	ELSE
		SELECT max(unix_gid) + 1
		INTO p_gid
		FROM unix_group
		WHERE unix_gid >= 10000;
	END IF;

	--
	-- error checking
	--
	IF p_gid IS NULL
	THEN
		raise VALUE_ERROR;
	END IF;

	--
	-- search for a short while
	--
	LOOP
		--
		-- failsafe
		--
		EXIT WHEN v_loopcount > 100;
		v_loopcount := v_loopcount + 1;

		--
		-- see if we're done
		--
		SELECT count(*)
		INTO v_matches
		FROM user_unix_info
		WHERE unix_uid = p_gid;

		--
		-- yes!
		--
		EXIT WHEN v_matches = 0;

		--
		-- try again
		--
		IF v_type = 'pseudouser' OR v_type = 'blacklist'
		THEN
			p_gid := p_gid - 1;
		ELSE
			p_gid := p_gid + 1;
		END IF;

	END LOOP;

	--
	-- loop ended in failure
	--
	IF v_loopcount > 100
	THEN
		raise VALUE_ERROR;
	END IF;

	--
	-- return the uid
	--
	p_uid := p_gid;

END select_ids;

-------------------------------------------------------------------------------------------------------------------
--exported procedures
-------------------------------------------------------------------------------------------------------------------

--
-- add a logical person assuming that a system_user record has already been added
-- if you want to add a system_user record, call system_user_util.user_add() and
-- this function will be called as well.
--
PROCEDURE unix_add
(
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_shell			IN	USER_UNIX_INFO.SHELL % TYPE,
	p_home			IN	USER_UNIX_INFO.DEFAULT_HOME % TYPE,
	p_gpass			IN	UNIX_GROUP.GROUP_PASSWORD % TYPE,
	p_uid			OUT	USER_UNIX_INFO.UNIX_UID % TYPE,
	p_gid			OUT	UNIX_GROUP.UNIX_GID % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.unix_add';
v_group_id		UNIX_GROUP.UNIX_GROUP_ID % TYPE;
v_login			SYSTEM_USER.LOGIN % TYPE;

BEGIN
	--
	-- will be needing login name to make it the same as group name
	--
	SELECT login
	INTO v_login
	FROM system_user
	WHERE system_user_id = p_system_user_id;

	--
	-- try and select reasonable id's
	--
	select_ids(p_system_user_id, p_uid, p_gid);

	--
	-- needs to be first to get id for next insert(s)
	--
	group_add(v_group_id, p_gid, p_gpass, v_login);

	--
	-- user being inserted should be a member of the group too
	--
	member_add(p_system_user_id, v_group_id);

	--
	-- finally the thing that hooks them together
	--
	user_add(p_system_user_id, p_uid, v_group_id, p_shell, p_home);

	EXCEPTION
		WHEN OTHERS THEN
			G_err_num := SQLCODE;
			G_err_msg := substr(SQLERRM, 1, 150);
			global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
			global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
			raise;

END unix_add;

-------------------------------------------------------------------------------------------------------------------
PROCEDURE group_add
(
	p_group_id		OUT	UNIX_GROUP.UNIX_GROUP_ID % TYPE,
	p_gid			IN	UNIX_GROUP.UNIX_GID % TYPE,
	p_passwd		IN	UNIX_GROUP.GROUP_PASSWORD % TYPE,
	p_name			IN	UNIX_GROUP.GROUP_NAME % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.group_add';

BEGIN

	--
	-- basic insert
	--
	INSERT INTO unix_group
	(
		unix_gid,
		group_password,
		group_name
	)
	VALUES
	(
		p_gid,
		p_passwd,
		p_name
	)
	RETURNING unix_group_id INTO p_group_id;

	EXCEPTION
		WHEN OTHERS THEN
			G_err_num := SQLCODE;
			G_err_msg := substr(SQLERRM, 1, 150);
			global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
			global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
			raise;

END group_add;

-------------------------------------------------------------------------------------------------------------------
PROCEDURE member_add
(
	p_system_user_id	IN	SYSTEM_USER.SYSTEM_USER_ID % TYPE,
	p_group_id		IN	UNIX_GROUP.UNIX_GROUP_ID % TYPE
)
IS
v_uclass_id UCLASS.UCLASS_ID % TYPE;

v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.member_add';

BEGIN
	-- per-user uclass should ALWAYS exist
	SELECT
		UClass_ID
	INTO
		v_uclass_id
	FROM
		Uclass
	WHERE
		Uclass_Type = 'per-user' AND
		NAME = (
			SELECT 
				Login
			FROM
				System_User
			WHERE
				System_User_ID = p_system_user_id
		);

	IF v_uclass_id IS NULL THEN
		RAISE VALUE_ERROR;
	END IF;

	INSERT INTO unix_group_uclass
	(
		Unix_Group_ID,
		UClass_ID,
		Approval_Type,
		Approval_Ref_Num
	)
	VALUES
	(
		p_group_id,
		v_uclass_id,
		'feed',
		'member_add'
	);

	EXCEPTION
		WHEN OTHERS THEN
			G_err_num := SQLCODE;
			G_err_msg := substr(SQLERRM, 1, 150);
			global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
			global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
			raise;

END member_add;

-------------------------------------------------------------------------------------------------------------------
PROCEDURE user_add
(
	p_system_user_id	IN	USER_UNIX_INFO.SYSTEM_USER_ID % TYPE,
	p_uid			IN	USER_UNIX_INFO.UNIX_UID % TYPE,
	p_group_id		IN	USER_UNIX_INFO.UNIX_GROUP_ID % TYPE,
	p_shell			IN	USER_UNIX_INFO.SHELL % TYPE,
	p_home			IN	USER_UNIX_INFO.DEFAULT_HOME % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.user_add';
v_shell			USER_UNIX_INFO.SHELL % TYPE;
v_home			USER_UNIX_INFO.DEFAULT_HOME % TYPE;
v_uid			USER_UNIX_INFO.UNIX_UID % TYPE;

BEGIN

	--
	-- arbitrary and hard-coded sorry
	--
	IF p_shell IS NULL
	THEN
		v_shell := 'bash';
	ELSE
		v_shell := p_shell;
	END IF;

	--
	-- build home directory from login
	--
	IF p_home IS NULL
	THEN
		SELECT '/home/' || login
		INTO v_home
		FROM system_user
		WHERE system_user_id = p_system_user_id;
	ELSE
		v_home := p_home;
	END IF;

	--
	-- pick the same uid as gid
	--
	IF p_uid IS NULL
	THEN
		SELECT unix_gid
		INTO v_uid
		FROM unix_group
		WHERE unix_group_id = p_group_id;
	ELSE
		v_uid := p_uid;
	END IF;

	--
	-- do actual insert
	--
	INSERT INTO user_unix_info
	(
		system_user_id,
		unix_uid,
		unix_group_id,
		shell,
		default_home
	)
	VALUES
	(
		p_system_user_id,
		v_uid,
		p_group_id,
		v_shell,
		v_home
	);

	EXCEPTION
		WHEN OTHERS THEN
			G_err_num := SQLCODE;
			G_err_msg := substr(SQLERRM, 1, 150);
			global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
			global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
			raise;

END user_add;

END;
/
