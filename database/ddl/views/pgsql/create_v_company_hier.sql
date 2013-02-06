-- Copyright (c) 2012, Todd M. Kover
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

CREATE OR REPLACE VIEW v_company_hier AS
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
) SELECT	distinct root_company_id as root_company_id, company_id
  from 		var_recurse;






