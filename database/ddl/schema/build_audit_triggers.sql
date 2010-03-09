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
--audit_triggers.sql creates (or replaces) triggers on audit tables.
--
--
-- $Id$
--
--

SET SERVEROUTPUT ON SIZE 1000000
SET FEEDBACK OFF

 

SPOOL generated_audit_triggers.sql
   

DECLARE
  v_prefix      VARCHAR2(5)   := NULL;
  v_condition   VARCHAR2(30)  := NULL;


  --Select all user tables with a corresponding audit table.
  CURSOR cur_tbl2audit IS
    SELECT table_name 
      FROM user_tables a
      WHERE table_name NOT LIKE 'AUD$%'
	AND table_name NOT LIKE 'BIN$%'
       AND table_name NOT IN ('PLAN_TABLE',
                              'TOKEN_SEQUENCE')
      AND EXISTS 
       (SELECT 'x'
          FROM user_tables b
          WHERE b.table_name  
          = 'AUD$'||SUBSTR(a.table_name,1,26) )
	AND NOT EXISTS ( select '1' FROM user_triggers c
			WHERE c.table_name=a.table_name
			and c.trigger_name like 'AUDTRG$%')
	ORDER BY TABLE_NAME;
 

  --Select table def of audit table, sans audit columns.          
  CURSOR cur_col2audit(p_audittbl USER_TABLES.TABLE_NAME%TYPE) IS 
    SELECT column_name 
      FROM user_tab_columns 
      WHERE table_name  = p_audittbl 
      AND column_name NOT IN 
      ('AUD#ACTION','AUD#TIMESTAMP','AUD#USER')
       AND data_type NOT IN ('BLOB', 'CLOB','RAW')
      ORDER BY column_id;  


BEGIN
  FOR cur_tbl2audit_rec IN cur_tbl2audit LOOP 
    DBMS_OUTPUT.PUT_LINE('CREATE OR REPLACE TRIGGER '||
     'AUDTRG$'||SUBSTR(cur_tbl2audit_rec.table_name,1,23)||CHR(10)||
     ' AFTER INSERT OR DELETE OR UPDATE '||
     'ON '||cur_tbl2audit_rec.table_name||
     ' FOR EACH ROW ');
 
    v_prefix       := ':new';
    v_condition    := 'IF INSERTING OR UPDATING THEN';
 
    DBMS_OUTPUT.PUT_LINE('DECLARE '||CHR(10)||
     'v_operation VARCHAR2(10) := NULL;');
    DBMS_OUTPUT.PUT_LINE('V_CONTEXT_USER  VARCHAR2(256):=NULL;');

    DBMS_OUTPUT.PUT_LINE('BEGIN ');
    DBMS_OUTPUT.PUT_LINE(' V_CONTEXT_USER:=SYS_CONTEXT(''USERENV'',''CLIENT_IDENTIFIER'');');
    DBMS_OUTPUT.PUT_LINE(' V_CONTEXT_USER:=UPPER(SUBSTR((USER||''/''||V_CONTEXT_USER),1,30));');
    IF v_prefix = ':new' THEN 
       DBMS_OUTPUT.PUT_LINE(  
        '    IF INSERTING THEN '||CHR(10)||
        '       v_operation := ''INS''; '||CHR(10)||
        '    ELSIF UPDATING THEN '||CHR(10)||
        '       v_operation := ''UPD''; '||CHR(10)||
        '    ELSE '||CHR(10)||
        '       v_operation := ''DEL''; '||CHR(10)||
        '    END IF; '||CHR(10));
    END IF;


    LOOP 
      DBMS_OUTPUT.PUT_LINE(v_condition||CHR(10));
      DBMS_OUTPUT.PUT_LINE('   INSERT INTO '||
       'AUD$'||SUBSTR(cur_tbl2audit_rec.table_name,1,26)|| ' (');
      
      --Loop through 1st to get column names:
      FOR cur_col2audit_rec IN cur_col2audit
       (cur_tbl2audit_rec.table_name) LOOP      
       DBMS_OUTPUT.PUT_LINE(cur_col2audit_rec.column_name|| ',');
      END LOOP;

      
      DBMS_OUTPUT.PUT_LINE('aud#action,aud#timestamp,aud#user) '||
         'VALUES (');

      
      --Loop a 2nd time for the values: 
      FOR cur_col2audit_rec IN cur_col2audit(
       cur_tbl2audit_rec.table_name) LOOP                         
       DBMS_OUTPUT.PUT_LINE(v_prefix||'.'||
        cur_col2audit_rec.column_name|| ',');
      END LOOP;

      
      DBMS_OUTPUT.PUT_LINE('V_OPERATION,SYSDATE,V_CONTEXT_USER);'||CHR(10));
       EXIT WHEN v_prefix = ':old';
         v_prefix := ':old';
         v_condition := 'ELSE ';
     END LOOP;

     
     DBMS_OUTPUT.PUT_LINE('   END IF;'||CHR(10)||
      'END;'||CHR(10)||'/'||CHR(10));
     DBMS_OUTPUT.PUT_LINE('SHOW ERRORS;'||CHR(10));
   END LOOP; 


EXCEPTION 
   --Any additional error checking would go here.
   WHEN OTHERS THEN 
     DBMS_OUTPUT.PUT_LINE('Failure building audit triggers : '||
      SUBSTR(SQLERRM,1,200));
     RAISE;
END;

/


SPOOL OFF

--Build the audit triggers:

--@build_audit_triggers.sql

 
