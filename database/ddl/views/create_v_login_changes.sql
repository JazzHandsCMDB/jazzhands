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

-- This view will show all cases where the login changes.


CREATE OR REPLACE VIEW v_login_changes
as
select account_id,current_login,account_type,previous_login,person_company_id,aud#action,aud#timestamp,aud#user,latest_timestamp
from (
	 SELECT a.account_id,a.login CURRENT_LOGIN,a.account_type,b.login PREVIOUS_LOGIN,b.company_id person_company_id,b.aud#action,b.aud#timestamp,b.aud#user,
		first_value(aud#timestamp) over (partition by a.account_id order by aud#timestamp desc nulls last) latest_timestamp
	from AUD$SYSTEM_USER b, account a
	where aud#action='UPD'
	and a.account_id=b.account_id
	and a.login!=b.login
      )
where aud#timestamp=latest_timestamp
;


-- This view filters out the re-used logins


CREATE OR REPLACE VIEW v_login_changes_extract
as
select * from v_login_changes a
where not exists (select 1 from account b
			where a.previous_login=b.login
			and b.account_type = 'employee');

