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

DROP VIEW IF EXISTS v_account_collection_expanded;
CREATE OR REPLACE VIEW v_account_collection_expanded AS
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
) SELECT	level,
		root_account_collection_id,
		account_collection_id
  from 		var_recurse;
