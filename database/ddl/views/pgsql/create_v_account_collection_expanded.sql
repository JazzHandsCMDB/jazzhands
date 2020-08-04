-- Copyright (c) 2013, Matthew Ragan
-- Copyright (c) 2014, Todd M. Kover
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

CREATE OR REPLACE VIEW v_account_collection_expanded AS
WITH RECURSIVE acct_coll_recurse (
	level,
	root_account_collection_id,
	account_collection_id,
	array_path,
	rvs_array_path,
	cycle
) AS (
		SELECT
			0 as level,
			ac.account_collection_id as root_account_collection_id,
			ac.account_collection_id as account_collection_id,
			ARRAY[ac.account_collection_id] as array_path,
			ARRAY[ac.account_collection_id] as rvs_array_path,
			false
		FROM
			account_collection ac
	UNION ALL
		SELECT 
			x.level + 1 as level,
			x.root_account_collection_id as root_account_collection_id,
			ach.account_collection_id as account_collection_id,
			x.array_path || ach.account_collection_id as array_path,
			ach.account_collection_id || x.rvs_array_path 
				as rvs_array_path,
			ach.account_collection_id = ANY(array_path) as cycle
		FROM
			acct_coll_recurse x JOIN account_collection_hier ach ON
				x.account_collection_id = ach.child_account_collection_id
		WHERE
			NOT cycle
) SELECT
		level,
		account_collection_id,
		root_account_collection_id,
		array_to_string(array_path, '/') as text_path,
		array_path,
		rvs_array_path
	FROM
		acct_coll_recurse;
