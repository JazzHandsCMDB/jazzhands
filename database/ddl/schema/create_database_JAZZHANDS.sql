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
-- $Id$
--

CONNECT / AS JazzHandsA

STARTUP NOMOUNT

CREATE DATABASE JAZZHANDS
   USER SYS IDENTIFIED BY somepassword
   USER SYSTEM IDENTIFIED BY somepassword
   LOGFILE GROUP 1 ('/u01/oradata/dbp1/redo01.log') SIZE 100M,
           GROUP 2 ('/u02/oradata/dbp1/redo02.log') SIZE 100M,
           GROUP 3 ('/u03/oradata/dbp1/redo03.log') SIZE 100M
   ARCHIVELOG
   MAXLOGFILES 5
   MAXLOGMEMBERS 5
   MAXLOGHISTORY 1
   MAXDATAFILES 100
   MAXINSTANCES 1
   CHARACTER SET UTF8
   NATIONAL CHARACTER SET UTF8
   DATAFILE '/u01/oradata/dbp1/system01.dbf'
	SIZE 500M REUSE
	AUTOEXTEND ON
	EXTENT MANAGEMENT LOCAL
   SYSAUX DATAFILE '/u01/oradata/dbp1/sysaux01.dbf'
	SIZE 325M REUSE
	AUTOEXTEND ON
   DEFAULT TABLESPACE data
	DATAFILE '/u01/oradata/dbp1/data01.dbf'
	SIZE 300M REUSE
	AUTOEXTEND ON
	EXTENT MANAGEMENT LOCAL AUTOALLOCATE
	SEGMENT SPACE MANAGEMENT AUTO
   DEFAULT TEMPORARY TABLESPACE temp
	TEMPFILE '/u02/oradata/dbp1/temp01.dbf' 
	SIZE 200M REUSE
	AUTOEXTEND ON
   UNDO TABLESPACE undotbs
	DATAFILE '/u03/oradata/dbp1/undotbs01.dbf'
	SIZE 300M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;
	

CREATE TABLESPACE INDEX01 DATAFILE '/u02/oradata/dbp1/index01.dbf'
	SIZE 500M REUSE
	AUTOEXTEND ON
	EXTENT MANAGEMENT LOCAL AUTOALLOCATE
	SEGMENT SPACE MANAGEMENT AUTO;

CREATE TABLESPACE DATA_BLOB DATAFILE '/u03/oradata/dbp1/data_blob01.dbf'
	SIZE 500M REUSE
	AUTOEXTEND ON
	EXTENT MANAGEMENT LOCAL AUTOALLOCATE
	SEGMENT SPACE MANAGEMENT AUTO;

CREATE TABLESPACE RPT_DATA01
        DATAFILE '/u02/oradata/dbp1/rpt_data01.dbf'
        SIZE 500M REUSE
        AUTOEXTEND ON
        EXTENT MANAGEMENT LOCAL AUTOALLOCATE
        SEGMENT SPACE MANAGEMENT AUTO;

CREATE TABLESPACE RPT_INDEX01
        DATAFILE '/u01/oradata/dbp1/rpt_index01.dbf'
        SIZE 500M REUSE
        AUTOEXTEND ON
        EXTENT MANAGEMENT LOCAL AUTOALLOCATE
        SEGMENT SPACE MANAGEMENT AUTO;

@@/u01/app/oracle/product/10.2.0/rdbms/admin/catalog.sql
@@/u01/app/oracle/product/10.2.0/rdbms/admin/catproc.sql
@@/u01/app/oracle/product/10.2.0/javavm/install/initjvm.sql

CREATE USER jazzhands IDENTIFIED BY somepassword 
	DEFAULT TABLESPACE DATA
	QUOTA 100M ON DATA
	QUOTA 100M ON INDEX01;

CREATE ROLE jazzhands_role;

GRANT jazzhands_role TO jazzhands;

GRANT CONNECT TO jazzhands_role;
GRANT RESOURCE TO jazzhands_role;
GRANT CREATE VIEW TO jazzhands_role;

DISCONNECT

CONNECT SYSTEM/somepassword

@/u01/app/oracle/product/10.2.0/sqlplus/admin/pupbld.sql

exit
