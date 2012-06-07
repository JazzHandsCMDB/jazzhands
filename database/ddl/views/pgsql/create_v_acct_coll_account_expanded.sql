-- Copyright (c) 2011, Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- $Id$
--

DROP VIEW IF EXISTS v_acct_coll_account_expanded;
CREATE OR REPLACE VIEW v_acct_coll_account_expanded AS
SELECT	ace.level,
	ace.root_account_collection_id as account_collection_id,
	ace.account_collection_id as reference_account_collection_id,
	aca.account_id,
	CASE WHEN ace.root_account_collection_id = ace.account_collection_id THEN 'N' ELSE 'Y' END as is_recursive
  FROM	v_account_collection_expanded ace
	INNER JOIN v_account_collection_account aca
		using (account_collection_id)
;
