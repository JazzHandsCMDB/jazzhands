-- Copyright (c) 2016, Todd M. Kover
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


\set ON_ERROR_STOP

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'token_utils';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS token_utils;
                CREATE SCHEMA token_utils AUTHORIZATION jazzhands;
                COMMENT ON SCHEMA token_utils IS 'part of jazzhands';
        END IF;
END;
$$;

--
-- set_sequence allows the sequence of a token to be set or reset either
-- due to normal usage or if it's skewed for some reason
--
CREATE OR REPLACE FUNCTION token_utils.set_sequence(
	p_token_id		Token_Sequence.Token_ID % TYPE,
	p_token_sequence	Token_Sequence.Token_Sequence % TYPE,
	p_reset_time		timestamp DEFAULT NULL
) RETURNS void AS $$
DECLARE
	_cur		token_sequence%ROWTYPE;
BEGIN

	IF p_token_id IS NULL THEN
		RAISE EXCEPTION 'Invalid token %', p_token_id
			USING ERRCODE = invalid_parameter_value;
	END IF;

	EXECUTE '
		SELECT *
		FROM token_sequence
		WHERE token_id = $1
	' INTO _cur USING p_token_id;

	IF _cur.token_id IS NULL THEN
		raise notice 'insert';
		EXECUTE '
			INSERT INTO token_sequence (
				token_id, token_sequence, last_updated
			) VALUES (
				$1, $2, $3
			);
		' USING p_token_id, p_token_sequence, p_reset_time;
	ELSE
		IF p_reset_time IS NULL THEN
			-- Using this code path, do not reset the sequence back, ever
			raise notice 'update without date';
			UPDATE Token_Sequence SET
				Token_Sequence = p_token_sequence,
				last_updated = now()
			WHERE
				Token_ID = p_token_id
				AND Token_Sequence < p_token_sequence;
		ELSE
			--
			-- Only reset the sequence back if its newer than what's in the
			-- db
			raise notice 'update with date';
			UPDATE Token_Sequence SET
				Token_Sequence = p_token_sequence,
				Last_Updated = p_reset_time
			WHERE Token_ID = p_token_id
			AND Last_Updated <= p_reset_time;
		END IF;
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/************************************************************************
 *
 * everthing after this needs ot be ported (maybe)
 *
 * Right now, the token bits insert directly into tables.  They should
 * likely be converted to use the stored procedures.
 *

--
-- set_pin allows the PIN for a token to be reset.  Token_PIN is a
-- base64-encoded SHA1 hash of the PIN/Password that is generated outside
-- of the database
--
PROCEDURE set_pin
(
	p_token_id		IN	Token.Token_ID % TYPE,
	p_token_pin		IN	Token.Token_PIN % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.set_pin';

BEGIN

	IF p_token_id IS NULL
	THEN
		RAISE VALUE_ERROR;
	END IF;

	UPDATE Token SET
		Token_PIN = p_token_pin,
		Last_Updated = SYSDATE
	WHERE
		Token_ID = p_token_id;


EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);

END set_pin;

--
-- copy_pin moves a PIN from one token to another
--
PROCEDURE copy_pin
(
	p_source_token_id	IN	Token.Token_ID % TYPE,
	p_dest_token_id		IN	Token.Token_ID % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.copy_pin';

BEGIN

	IF (p_source_token_id IS NULL) OR (p_dest_token_id IS NULL)
	THEN
		RAISE VALUE_ERROR;
	END IF;

	UPDATE Token SET
		Token_PIN = (
			SELECT
				Token_PIN
			FROM
				Token
			WHERE
				Token_ID = p_source_token_id),
		Last_Updated = SYSDATE
	WHERE
		Token_ID = p_dest_token_id;


EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);

END copy_pin;

--
-- replace_token updates all token assignments from one token to another
-- for replacement.  Note that this does not copy the pin, nor does it
-- update the Token_Status of either token. 
--
PROCEDURE replace_token
(
	p_source_token_id	IN	Token.Token_ID % TYPE,
	p_dest_token_id		IN	Token.Token_ID % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.copy_pin';

BEGIN

	IF (p_source_token_id IS NULL) OR (p_dest_token_id IS NULL)
	THEN
		RAISE VALUE_ERROR;
	END IF;

	UPDATE
		System_User_Token
	SET
		Token_ID = p_dest_token_id,
		Issued_Date = SYSDATE,
		Is_User_Token_Locked = 'N',
		Token_Unlock_Time = NULL,
		Bad_Logins = 0,
		Last_Updated = SYSDATE
	WHERE
		Token_ID = p_source_token_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);

END replace_token;

--
-- set_status changes the status of the token.  Token_Status needs to be
-- one of SELECT Token_Status FROM VAL_Token_Status
--
PROCEDURE set_status
(
	p_token_id		IN	Token.Token_ID % TYPE,
	p_token_status	IN	Token.Token_Status % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.set_status';

BEGIN

	IF p_token_id IS NULL
	THEN
		RAISE VALUE_ERROR;
	END IF;

	UPDATE Token SET
		Token_Status = p_token_status,
		Last_Updated = SYSDATE
	WHERE
		Token_ID = p_token_id;


EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);

END set_status;

--
-- set_lock_status changes the lock status of the token.  
--
PROCEDURE set_lock_status
(
	p_token_id		IN	System_User_Token.Token_ID % TYPE,
	p_lock_status	IN	System_User_Token.Is_User_Token_Locked % TYPE,
	p_unlock_time	IN	System_User_Token.Token_Unlock_Time % TYPE,
	p_bad_logins	IN	System_User_Token.Bad_Logins % TYPE,
	p_last_updated	IN	System_User_Token.Last_Updated % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.set_lock_status';
v_last_updated		System_User_Token.Last_Updated % TYPE;

BEGIN

	IF p_token_id IS NULL
	THEN
		RAISE VALUE_ERROR;
	END IF;

	v_last_updated := p_last_updated;
	IF v_last_updated IS NULL
	THEN
		v_last_updated := SYSDATE;
	END IF;

	UPDATE System_User_Token SET
		Is_User_Token_Locked = p_lock_status,
		Token_Unlock_Time = p_unlock_time,
		Bad_Logins = p_bad_logins,
		Last_Updated = v_last_updated
	WHERE
		Token_ID = p_token_id;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);

END set_lock_status;

--
-- assign_token associates a given token with a user
--
PROCEDURE assign_token
(
	p_token_id		IN	Token.Token_ID % TYPE,
	p_user_id		IN	System_User.System_User_ID % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.assign_token';

BEGIN

	IF (p_token_id IS NULL) OR (p_user_id IS NULL)
	THEN
		RAISE VALUE_ERROR;
	END IF;

	INSERT INTO
		System_User_Token (
			System_User_ID,
			Token_ID,
			Is_User_Token_Locked,
			Issued_Date,
			Last_Updated
		) VALUES (
			p_user_id,
			p_token_id,
			'N',
			SYSDATE,
			SYSDATE
		);

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);

END assign_token;

--
-- unassign_token removes token associations
--

PROCEDURE unassign_token
(
	p_token_id		IN	Token.Token_ID % TYPE,
	p_user_id		IN	System_User.System_User_ID % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.unassign_token';

BEGIN

	IF (p_token_id IS NULL)
	THEN
		RAISE VALUE_ERROR;
	END IF;

	if (p_user_id IS NULL)
	THEN
		DELETE FROM
			System_User_Token
		WHERE
			Token_ID = p_token_id;
	ELSE
		DELETE FROM
			System_User_Token
		WHERE
			Token_ID = p_token_id AND
			System_User_ID = p_user_id;
	END IF;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);

END unassign_token;

--
-- set_time_skew allows the time skew of a time-based token to be adjusted.
-- Adjusting the time skew of a sequence-based token does not return an error,
-- but has no effect on the operation of the token.  Time_Skew is the
-- number of Time_Modulo intervals difference between what the token thinks
-- and an NTP source.  This allows us to keep it Real Time.
--
PROCEDURE set_time_skew
(
	p_token_id		IN	Token.Token_ID % TYPE,
	p_time_skew		IN	Token.Time_Skew % TYPE
)
IS
v_std_object_name	VARCHAR2(60) := GC_pkg_name || '.set_sequence';

BEGIN

	IF p_token_id IS NULL
	THEN
		RAISE VALUE_ERROR;
	END IF;

	UPDATE Token SET
		Time_Skew = p_time_skew,
		Last_Updated = SYSDATE
	WHERE
		Token_ID = p_token_id;


EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);

END set_time_skew;

END;    --end of package body Token_Util

*/

grant select on all tables in schema token_utils to iud_role;
grant usage on schema token_utils to iud_role;
revoke all on schema token_utils from public;
revoke all on  all functions in schema token_utils from public;
grant execute on all functions in schema token_utils to iud_role;

