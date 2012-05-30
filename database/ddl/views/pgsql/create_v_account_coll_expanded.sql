-- Copyright (c) 2012, Todd M. Kover
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
-- THIS SOFTWARE IS PROVIDED BY ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- $Id$
--

CREATE OR REPLACE VIEW v_acct_coll_expanded AS
WITH RECURSIVE var_recurse (
	level,
	root_account_collection_id,
	account_collection_id
) as (
	SELECT	
		0				as level,
		a.account_collection_id		as root_account_collection_id, 
		a.account_collection_id		as account_collection_id
	  FROM	account_collection a
UNION ALL
	SELECT	
		x.level + 1			as level,
		x.root_account_collection_id	as root_account_collection_id, 
		ach.child_account_collection_id	as account_collection_id
	  FROM	var_recurse x
		inner join account_collection_hier ach
			on x.account_collection_id =
				ach.account_collection_id
) SELECT	distinct level,
			root_account_collection_id,
			account_collection_id
  from 		var_recurse;
