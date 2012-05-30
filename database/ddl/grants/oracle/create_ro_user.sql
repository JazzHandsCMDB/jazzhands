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

prompt 'Enter user:'
prompt 'Enter password:' 

create user &&username identified by &passwd;


--
-- create new role
--

grant ro_role to &&username; 

set feedback off
set pagesize 0
set verify off

spool tmpsyns.sql

prompt set echo on

-- token views are currently sensitive.  possession of the keys gives the
-- ability to generate all OTPs

select 'create synonym &&username..'||table_name||' for '||owner||'.'||table_name||';'
from all_tables
where owner='JAZZHANDS' AND table_name NOT IN ('TOKEN', 'AUD$TOKEN');

select 'create synonym &&username..'||object_name||' for '||owner||'.'||object_name||';'
from all_objects
where owner='JAZZHANDS'
and object_type in ('PACKAGE','PROCEDURE','FUNCTION','VIEW');

spool off
@tmpsyns.sql

