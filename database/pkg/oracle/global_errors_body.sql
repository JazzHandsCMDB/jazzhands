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
PACKAGE BODY global_errors
IS

err_msg				err_msg_t;
GC_pkg_name      CONSTANT        USER_OBJECTS.OBJECT_NAME%TYPE:='global_util';

-------------------------------------------------------------------------------------------------------------------
--procedure to generate the Id tag for CM.
-------------------------------------------------------------------------------------------------------------------
FUNCTION id_tag RETURN VARCHAR2
IS
BEGIN
	RETURN('<-- $Id$ -->');
END;    --end of procedure id_tag


--------------------------------------------------------------------------------
   -- Name:        push
   -- Description: Put a message on the stack
   -- Parameters:  msg      Text message
-------------------------------------------------------------------
PROCEDURE push ( msg IN varchar2) IS

BEGIN
err_msg(err_tab_i)        := msg;
err_tab_i                 := err_tab_i + 1;

END push;
---------------
--Overloaded procedure
PROCEDURE push (Errorid IN number default 0,
                serviceID IN varchar2 ,
                error_level IN varchar2,
                timestamp IN varchar2,
                msg      IN VARCHAR2,
                ServiceSpecificErrorLink IN varchar2 DEFAULT NULL) IS
BEGIN

       --err_msg(err_tab_i)        := msg;

       err_msg_rs(err_tab_i).ErrorID := ErrorID;
       err_msg_rs(err_tab_i).ServiceID := ServiceID;
       err_msg_rs(err_tab_i).error_level := error_level;
       err_msg_rs(err_tab_i).timestamp := timestamp;
       err_msg_rs(err_tab_i).text_for_alert := msg;
       err_msg_rs(err_tab_i).ServiceSpecificErrorLink := ServiceSpecificErrorLink;

       err_tab_i                 := err_tab_i + 1;

END push;

--------------------------------------------------------------------------------
   -- Name:        pop
   -- Description: Take a message off stack
   -- Parameters:  msg     Text message
   -- Returns:     TRUE    Message popped successfully
   --              FALSE   Stack was empty
-----------------------------------------------------------------------------------

FUNCTION pop(msg OUT VARCHAR2)
       RETURN BOOLEAN IS
   BEGIN

       IF (err_tab_i > 1 AND err_msg(err_tab_i - 1) IS NOT NULL) THEN
           err_tab_i := err_tab_i - 1;
           msg          := err_msg(err_tab_i);
           err_msg(err_tab_i) := '';
           return TRUE;
       ELSE
           return FALSE;
       END IF;

   END pop;

FUNCTION pop(Errorid OUT number,
                serviceID OUT varchar2 ,
                error_level OUT varchar2,
                timestamp OUT varchar2,
                msg      OUT varchar2,
                ServiceSpecificErrorLink OUT varchar2) RETURN BOOLEAN IS

    BEGIN
       IF (err_tab_i > 1 AND err_msg_rs(err_tab_i - 1).errorID IS NOT NULL) THEN
           err_tab_i := err_tab_i - 1;
           errorid  :=err_msg_rs(err_tab_i).errorID;
           serviceID :=err_msg_rs(err_tab_i).serviceID;
           error_level := err_msg_rs(err_tab_i).error_level;
           timestamp := err_msg_rs(err_tab_i).timestamp;
           msg          := err_msg_rs(err_tab_i).Text_for_alert;
           ServiceSpecificErrorLink := err_msg_rs(err_tab_i).ServiceSpecificErrorLink;

           err_msg(err_tab_i) := '';
           return TRUE;
       ELSE
           return FALSE;
       END IF;

   END pop;




-----------------------------------------------------------------------------
   -- Name:        get_errors
   -- Description: Pops all messages off the stack and returns them in the order
   --              in which they were raised.
   -- Parameters:  none
   -- Returns:     The messages
   -----------------------------------------------------------------------------
  /* FUNCTION GetErrors
         return varchar2  is
      I_ERROR_MESS  varchar2(2000):='';
      I_NEXT_MESS   varchar2(240):='';
   BEGIN
     while global_errors.pop(I_NEXT_MESS) loop
       if I_ERROR_MESS is null then
          I_ERROR_MESS := I_NEXT_MESS;
       else
          I_ERROR_MESS := I_NEXT_MESS || '   ' || I_ERROR_MESS;
       end if;
     end loop;
     return (I_ERROR_MESS);
   END;
*/

FUNCTION GetErrors
         return LONG  is
      I_ERROR_MESS  LONG:='';
      I_ERROR_ID  NUMBER:=0;
      I_SERVICE_ID varchar2(50):='';
      I_ERROR_LEVEL varchar2(50):='';
      I_TIMESTAMP varchar2(30);
      I_MSG varchar2(2000);
      I_link varchar2(2000);
   BEGIN
     while global_errors.pop(I_ERROR_ID, I_SERVICE_ID, I_ERROR_LEVEL, I_TIMESTAMP, I_MSG, I_LINK) loop
       if I_ERROR_MESS is null then
          I_ERROR_MESS := 'ErrorID is- '||I_ERROR_ID ||chr(10)||
                        'ServiceID is- '||I_SERVICE_ID||chr(10)||
                        'Error_Level is- '||I_ERROR_LEVEL||chr(10)||
                        'TimeStamp is- '||I_TIMESTAMP||chr(10)||
                        'Text_For_Alert is- '||I_MSG||chr(10)||
                        'ServiceSpecificErrorLink is- '||I_LINK;
       else
          I_ERROR_MESS :='ErrorID is- '||I_ERROR_ID ||chr(10)||
                        'ServiceID is- '||I_SERVICE_ID||chr(10)||
                        'Error_Level is- '||I_ERROR_LEVEL||chr(10)||
                        'TimeStamp is- '||I_TIMESTAMP||chr(10)||
                        'Text_For_Alert is- '||I_MSG||chr(10)||
                        'ServiceSpecificErrorLink is- '||I_LINK
                        || '   ' || I_ERROR_MESS;
       end if;
     end loop;
     return (I_ERROR_MESS);
   END;


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
	global_errors.push(	p_err_num, p_proc_name, 'Fatal Error',
			to_char(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'), p_err_msg, NULL);
END log_error; 



END;    --end of package body GLOBAL_ERRORS
/
