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
PACKAGE BODY dbms_job_util IS

GC_pkg_name	 CONSTANT	 USER_OBJECTS.OBJECT_NAME%TYPE:='dbms_job_util';
-- Error Code/Msg variables ------------------
G_err_num               NUMBER;
G_err_msg               VARCHAR2(200);


-------------------------------------------------------------------------------------------------------------------
--procedure to generate the Id tag for CM.
-------------------------------------------------------------------------------------------------------------------
FUNCTION id_tag RETURN VARCHAR2
IS
BEGIN
     RETURN('<-- $Id$ -->');
END;    --end of procedure id_tag


-------------------------------------------------------------------------------------------------------------------
--  This procedure changes the system_user_status to deleted when the hire_date has passed
-------------------------------------------------------------------------------------------------------------------
PROCEDURE terminate_expired_users     
IS
v_std_object_name	VARCHAR2(60):=GC_pkg_name||'.terminate_expired_users';
BEGIN

	-- Have to do this as two updates (easier), as some systems set to 23:59 for terminations, and others 00:00

	UPDATE system_user su
	SET system_user_status='deleted'
	WHERE termination_date < sysdate
	AND exists (select 1 from val_system_user_type vsut
			where vsut.system_user_type=su.system_user_type
			and vsut.is_person='Y')
	AND not exists (select 1 from system_user_xref sux
			where su.system_user_id=sux.system_user_id
			and sux.external_hr_id is not null)
	AND system_user_status not in ('deleted','walked','terminated','forcedisable');

	
	
--	global_util.debug_msg(v_std_object_name || ': '|| SQL%ROWCOUNT ||' records updated');

	UPDATE system_user su
	SET system_user_status='deleted'
	WHERE (termination_date + 1) < sysdate
	AND exists (select 1 from val_system_user_type vsut
			where vsut.system_user_type=su.system_user_type
			and vsut.is_person='Y')
	AND exists (select 1 from system_user_xref sux
			where su.system_user_id=sux.system_user_id
			and sux.external_hr_id is not null)
	AND system_user_status not in ('deleted','walked','terminated','forcedisable');

--	global_util.debug_msg(v_std_object_name || ': '|| SQL%ROWCOUNT ||' records updated');

	EXCEPTION
        WHEN OTHERS THEN
                G_err_num := SQLCODE;
                G_err_msg := substr(SQLERRM, 1, 150);
                global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
                global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
                raise;
END; -- terminate_expired_users

-------------------------------------------------------------------------------------------------------------------
--  This procedure removes entries older than 191 days from the system_user_auth_log table
-------------------------------------------------------------------------------------------------------------------
PROCEDURE cleanup_system_user_auth_log
IS
v_std_object_name	VARCHAR2(60):=GC_pkg_name||'.cleanup_system_user_auth_log';
BEGIN
	DELETE FROM SYSTEM_USER_AUTH_LOG
	 WHERE SYSTEM_USER_AUTH_TS <= (systimestamp - 192);

	EXCEPTION
        WHEN OTHERS THEN
                G_err_num := SQLCODE;
                G_err_msg := substr(SQLERRM, 1, 150);
                global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
                global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
                raise;
END; -- cleanup_system_user_auth_log




END;    --end of package body DBMS_UTIL
/
