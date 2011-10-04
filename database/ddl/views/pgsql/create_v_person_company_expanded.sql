-- Copyright (c) 2011 Todd M. Kover
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
-- $Id: create_v_user_coll_account_expanded.sql 60 2011-10-03 09:11:29Z kovert $
--

CREATE OR REPLACE VIEW v_person_company_expanded AS
WITH RECURSIVE var_recurse (
	level,
	root_company_id,
	company_id,
	person_id
) as (
	SELECT	
		0				as level,
		c.company_id			as root_company_id,
		c.company_id			as company_id,
		pc.person_id			as person_id
	  FROM	company c
		inner join person_company pc
			on c.company_id = pc.company_id
UNION ALL
	SELECT	
		x.level + 1			as level,
		x.company_id			as root_company_id,
		c.company_id			as company_id,
		pc.person_id			as person_id
	  FROM	var_recurse x
		inner join company c
			on c.parent_company_id = x.company_id
		inner join person_company pc
			on c.company_id = pc.company_id
) SELECT	distinct root_company_id as company_id, person_id
  from 		var_recurse;






