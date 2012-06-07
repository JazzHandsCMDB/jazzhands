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

CREATE OR REPLACE VIEW v_nblk_coll_netblock_expanded AS
WITH RECURSIVE var_recurse (
	level,
	root_collection_id,
	netblock_collection_id,
	child_netblock_collection_id,
	netblock_id
) as (
	SELECT	
		0				as level,
		u.netblock_collection_id		as root_collection_id, 
		u.netblock_collection_id		as netblock_collection_id, 
		u.netblock_collection_id		as child_netblock_collection_id,
		ua.netblock_Id			as netblock_id
	  FROM	netblock_collection u
		inner join netblock_collection_netblock ua
			on u.netblock_collection_id =
				ua.netblock_collection_id
UNION ALL
	SELECT	
		x.level + 1			as level,
		x.netblock_collection_id		as root_netblock_collection_id, 
		uch.netblock_collection_id		as netblock_collection_id, 
		uch.child_netblock_collection_id	as child_netblock_collection_id,
		ua.netblock_Id			as netblock_id
	  FROM	var_recurse x
		inner join netblock_collection_hier uch
			on x.child_netblock_collection_id =
				uch.netblock_collection_id
		inner join netblock_collection_netblock ua
			on uch.child_netblock_collection_id =
				ua.netblock_collection_id
) SELECT	distinct root_collection_id as netblock_collection_id,
		netblock_id as netblock_id
  from 		var_recurse;
