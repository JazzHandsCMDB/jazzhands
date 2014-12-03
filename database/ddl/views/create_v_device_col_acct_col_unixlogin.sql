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

-- This view shows which users are mapped to which device collections,
-- which is particularly important for generating passwd files. Please
-- note that the same account_id can be mapped to the same
-- device_collection multiple times via different account_collections. The
-- user_collection_id column is important mostly to join the results of the
-- view back to the account_collection table, and select only certain account_collection
-- types (such as 'system' and 'per-user') to be expanded.

CREATE OR REPLACE VIEW v_device_col_acct_col_unixlogin AS
SELECT DISTINCT dchd.device_collection_id, dcu.account_collection_id, 
	vuue.account_id
FROM v_device_coll_hier_detail dchd
JOIN v_property dcu ON dcu.device_collection_id = 
	dchd.parent_device_collection_id
JOIN v_acct_coll_acct_expanded vuue 
	on vuue.account_collection_id = dcu.account_collection_id
WHERE dcu.property_name in ('UnixLogin')
and dcu.property_type = 'MclassUnixProp';
