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
-- $Id$
--

CREATE OR REPLACE VIEW v_department_company_expanded AS
WITH RECURSIVE var_recurse (
	level,
	root_company_id,
	company_id,
	account_collection_id,
	array_path,
	cycle
) as (
	SELECT	
		0				as level,
		c.company_id			as root_company_id,
		c.company_id			as company_id,
		d.account_collection_id		as account_collection_id,
		ARRAY[c.company_id]		as array_path,
		false
	  FROM	company c
		inner join department d USING (company_id)
UNION ALL
	SELECT	
		x.level + 1			as level,
		x.company_id			as root_company_id,
		c.company_id			as company_id,
		d.account_collection_id		as account_collection_id,
		c.company_id || x.array_path	as array_path,
		c.company_id = ANY (x.array_path)	as cycle
	  FROM	var_recurse x
		inner join company c
			on c.parent_company_id = x.company_id
		inner join department d
			on c.company_id = d.company_id
	WHERE
		NOT x.cycle
) SELECT	distinct root_company_id as company_id, account_collection_id
  from 		var_recurse;
