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
-- $Id$
--
-- This is just a join between the expanded Account_Collection view (details) and the user and Account_Collection tables.  Needed for the rights web page.

CREATE OR REPLACE FORCE VIEW v_joined_user_col_user_detail
(Account_Collection_id,
NAME,
account_id,
login,
assign_method,
Account_Collection_is_leaf,
Account_Collection_inherit_path,
dept_is_leaf,
dept_inherit_path
)
AS
   SELECT v.Account_Collection_id, u.NAME, v.account_id, su.login, v.assign_method,
          v.Account_Collection_is_leaf, v.Account_Collection_inherit_path, v.dept_is_leaf,
          v.dept_inherit_path
     FROM v_Account_Collection_user_expanded_detail v, account su, Account_Collection u
    WHERE su.account_id = v.account_id AND u.Account_Collection_id = v.Account_Collection_id;


