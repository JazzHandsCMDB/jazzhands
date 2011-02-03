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
--  This script renames a user's login, provided there has been nothing sent to unix/krb
--
-- $Id$
--

undefine sysuid

set linesize 180
set pagesize 500

COLUMN savevar NEW_VALUE oldlogin

-- This retains the value for later use

SELECT login savevar
FROM system_user
WHERE system_user_id=&&sysuid  ;




update system_user
set login='&&NewLogin'
where system_user_id=&&sysuid;

select *
from system_user
where system_user_id='&&sysuid';

update user_unix_info
set default_home=substr(default_home,1,instr(default_home,'&&oldlogin',1)-1)||'&&NewLogin'
				||substr(default_home,(instr(default_home,'&&oldlogin',1)+(length('&&oldlogin'))))
where system_user_id=&&sysuid;


select * 
   from user_unix_info
  where system_user_id=&&sysuid;


