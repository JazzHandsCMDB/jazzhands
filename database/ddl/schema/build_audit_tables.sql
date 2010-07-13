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
--
--
-- $Id$
--


SET SERVEROUTPUT ON SIZE 100000
SET FEEDBACK OFF


SPOOL generated_audit_tables.sql

DECLARE

   lv_precision_and_scale    VARCHAR2(20);  


   --Select tables w/o an audit table

   CURSOR cur_tbl2audit IS
     SELECT table_name 
       FROM user_tables 
       WHERE 'AUD$'||SUBSTR(table_name,1,26) NOT IN 
        (SELECT table_name 
         FROM user_tables) 
       AND table_name NOT LIKE 'AUD$%'
       --Add ineligible tables here: 
       AND table_name NOT IN ('PLAN_TABLE',
			      'TOKEN_SEQUENCE')
	AND table_name not like 'BIN$%'
	ORDER BY table_name;

 

   --Select table def of unaudited table.
   CURSOR cur_col2audit(p_tbl2audit USER_TABLES.TABLE_NAME%TYPE) IS 
     SELECT column_name,data_type,data_length,data_precision,data_scale
       FROM user_tab_columns 
       WHERE table_name  = p_tbl2audit 
       --Add ineligible datatypes here : 
       AND data_type NOT IN ('BLOB', 'CLOB','RAW')
       ORDER BY column_id; 

      
BEGIN
  --Retrieve table names:     
  FOR cur_tbl2audit_rec IN cur_tbl2audit LOOP 
    DBMS_OUTPUT.PUT_LINE('CREATE TABLE '|| 
     LOWER('AUD$'||SUBSTR(cur_tbl2audit_rec.table_name,1,26))||' (');


     --Retrieve table columns: 
     FOR cur_col2audit_rec 
      IN cur_col2audit(cur_tbl2audit_rec.table_name) LOOP 
        IF cur_col2audit_rec.data_type = 'NUMBER'  THEN
 
           --Add precision for NUMBER or provide a default.
           IF cur_col2audit_rec.data_precision IS NULL THEN
              lv_precision_and_scale := '';
           ELSE
              lv_precision_and_scale := '(' ||
               cur_col2audit_rec.data_precision||','||
               cur_col2audit_rec.data_scale||')';
           END IF;
           --RPAD adds spaces for easier reading.
           DBMS_OUTPUT.PUT_LINE

            (RPAD(LOWER(cur_col2audit_rec.column_name),35)||
            cur_col2audit_rec.data_type||''||
            lv_precision_and_scale||',');


       ELSIF cur_col2audit_rec.data_type IN 
        ('CHAR','VARCHAR','VARCHAR2')  THEN 
         DBMS_OUTPUT.PUT_LINE
          (RPAD(LOWER(cur_col2audit_rec.column_name),35)||
          cur_col2audit_rec.data_type||'('||
          cur_col2audit_rec.data_length||'),');
       ELSE 
         DBMS_OUTPUT.PUT_LINE
          (RPAD(LOWER(cur_col2audit_rec.column_name),35)||
          cur_col2audit_rec.data_type||',');
       END IF;          

     END LOOP; 

        

     --Add audit fields to table: 
     DBMS_OUTPUT.PUT_LINE
      (RPAD('aud#action',35)||'CHAR(3), ');  
     DBMS_OUTPUT.PUT_LINE
      (RPAD('aud#timestamp',35)||'DATE, ');  
     DBMS_OUTPUT.PUT_LINE
      (RPAD('aud#user',35)||'VARCHAR2(30) )');  
     DBMS_OUTPUT.PUT_LINE('/');
     DBMS_OUTPUT.PUT_LINE('--');
      
  END LOOP; 

EXCEPTION 
  WHEN OTHERS THEN 
    DBMS_OUTPUT.PUT_LINE('Failure creating audit tables : '||
     SUBSTR(SQLERRM,1,200));
    RAISE;

END;

/

 

 

SPOOL OFF

--@build_audit_tables.sql

 

