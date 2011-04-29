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

CREATE OR REPLACE PACKAGE BODY 
	Sys.Oracle_Passwd_Util
AS

--
-- set_passwd sets the oracle password and/or change time for a user account 
-- to a specific encrypted string or time value
--
PROCEDURE set_passwd
(
	p_user_id			IN	SYS.USER$.USER# % TYPE,
	p_reset_time		IN	SYS.USER$.PTIME %TYPE,
	p_password			IN	SYS.USER$.PASSWORD %TYPE
)
IS

BEGIN

	IF p_user_id IS NULL
	THEN
		RAISE VALUE_ERROR;
	END IF;

	IF p_password IS NULL
	THEN
		IF p_reset_time IS NULL
		THEN
			RAISE VALUE_ERROR;
		ELSE
			UPDATE SYS.USER$ SET
				PTime = TO_DATE(p_reset_time, 'YYYY-MM-DD HH24:MI:SS')
			WHERE
				User# = p_user_id;
		END IF;
	END IF;

	IF p_reset_time IS NULL
	THEN
		UPDATE SYS.USER$ SET
			Password = p_password,
			PTime = SYSDATE
		WHERE
			User# = p_user_id;
	ELSE
		UPDATE SYS.USER$ SET
			Password = p_password,
			PTime = TO_DATE(p_reset_time, 'YYYY-MM-DD HH24:MI:SS')
		WHERE
			User# = p_user_id;
	END IF;

END set_passwd;
END;    --end of package body Oracle_Passwd_Util
/
