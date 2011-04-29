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
PACKAGE BODY vatt_util IS

GC_pkg_name		CONSTANT	 USER_OBJECTS.OBJECT_NAME % TYPE := 'vatt_util';

-- Error Code/Msg variables ------------------
G_err_num		NUMBER;
G_err_msg		VARCHAR2(200);

PROCEDURE terminate_vendors
IS
BEGIN
	UPDATE system_user SET
		system_user_status = 'deleted'
	WHERE system_user_type = 'vendor'
	AND system_user_status NOT IN ('deleted', 'terminated', 'onleave')
	AND SYSDATE > termination_date;

EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
		raise;

END dbmsjob_terminate;

END;
/
