-- Copyright (c) 2011-2014, Todd M. Kover
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
-- $Id: create_v_acct_coll_account_expanded.sql 60 2011-10-03 09:11:29Z kovert $
--

CREATE OR REPLACE VIEW v_person_company_expanded AS
WITH RECURSIVE var_recurse(
	level,
	root_company_id,
	company_id,
	parent_company_id,
	person_id,
	array_path,
	 cycle
) AS (
	SELECT 
		0				AS level,
		c.company_id			AS root_company_id,
		c.company_id			AS company_id,
		c.parent_company_id		AS parent_company_id,
		pc.person_id			AS person_id,
		ARRAY[c.company_id]		AS array_path,
		false 				AS cycle
	FROM company c
		INNER JOIN person_company pc USING (company_id)
UNION ALL
	SELECT
		x.level + 1			AS level,
		x.root_company_id		AS root_company_id,
		c.company_id			AS company_id,
		c.parent_company_id		AS parent_company_id,
		x.person_id			AS person_id,
		c.company_id || x.array_path	AS array_path,
		c.company_id = ANY (x.array_path) AS cycle
	FROM var_recurse x
		INNER JOIN company c ON x.parent_company_id = c.company_id
	WHERE NOT x.cycle
)
SELECT var_recurse.company_id, var_recurse.person_id
FROM var_recurse;

