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
--
-- $Id$
--
CREATE OR REPLACE PACKAGE BODY 
	Time_Util
AS

GC_pkg_name	 CONSTANT	 USER_OBJECTS.OBJECT_NAME % TYPE := 'time_util';
-- Error Code/Msg variables ------------------
G_err_num		NUMBER;
G_err_msg		VARCHAR2(200);


FUNCTION epoch (DateTime TIMESTAMP WITH LOCAL TIME ZONE)
        RETURN NUMBER
IS
        EpochSeconds INTEGER;
	v_std_object_name   VARCHAR2(60) := GC_pkg_name || '.epoch';
BEGIN
        RETURN (CAST(SYS_EXTRACT_UTC(DATETIME) AS DATE) - 
		TO_DATE('1970-01-01','YYYY-MM-DD')) * (86400);
EXCEPTION
	WHEN OTHERS THEN
		G_err_num := SQLCODE;
		G_err_msg := substr(SQLERRM, 1, 150);
		global_util.debug_msg(v_std_object_name || ':(' || G_err_num || ') "' || G_err_msg || '"');
		global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);

END epoch;

END;
/
