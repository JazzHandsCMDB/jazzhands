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
PACKAGE BODY global_util IS

GC_pkg_name	 CONSTANT	 USER_OBJECTS.OBJECT_NAME%TYPE:='global_util';

-------------------------------------------------------------------------------------------------------------------
--procedure to generate the Id tag for CM.
-------------------------------------------------------------------------------------------------------------------
FUNCTION id_tag RETURN VARCHAR2
IS
BEGIN
     RETURN('<-- $Id$ -->');
END;    --end of procedure id_tag


-------------------------------------------------------------------------------------------------------------------
--procedure to assert a condition as true or false
--  The condition should be written for the Positive case (as in  foo>0  if foo should be a positive number)
-------------------------------------------------------------------------------------------------------------------
PROCEDURE assert_condition      (p_pass_condition	IN	BOOLEAN,
			  						 p_message_text		IN	VARCHAR2)
IS
v_std_object_name	VARCHAR2(60):=GC_pkg_name||'.assert_condition';
BEGIN
	IF ( NOT p_pass_condition )
	THEN
	        debug_msg(v_std_object_name||':'||p_message_text);

		-- Call the error procedure and raise a value error
		-- TODO have to put an error value in a global place
                log_error(101,v_std_object_name,NVL(p_message_text, 'Condition Failed - Unspecified'));
		RAISE VALUE_ERROR ;
	END IF;
END; -- assert_condition


-------------------------------------------------------------------------------------------------------------------
--procedure to send debug messages to the screen if G_DEBUG = TRUE
-------------------------------------------------------------------------------------------------------------------
PROCEDURE debug_msg      ( p_message_text		IN	VARCHAR2)
IS
BEGIN
	IF ( global_types.G_DEBUG ) 
	THEN
		dbms_output.enable(20000);
		dbms_output.put_line(SUBSTR(p_message_text,1,20000));
	END IF;
END; -- debug_msg



-------------------------------------------------------------------------------
--Procedure to capture errors and send to routine to insert into error que.
--Any interface changes to the global error stack should be changed here
------------------------------------------------------------------------------
PROCEDURE log_error	(
			p_err_num		IN	NUMBER,
			p_proc_name		IN	VARCHAR2,
			p_err_msg		IN	VARCHAR2)
IS
BEGIN
		 NULL;
	-- TODO fix the global push and change timestamp to date type
--	global_error.push(	p_err_num, p_proc_name, 'Fatal Error',
--			to_char(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'), p_err_msg, NULL);
END; -- tw_error



END;    --end of package body TW_UTIL
/