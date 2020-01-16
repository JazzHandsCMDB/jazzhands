--
-- Copyright (c) 2019 Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

-- was originally in netblock/index.pl from stab.  It originally had
-- 	connect by prior nb.netblock_id = parent_netblock_id
-- 	start with nb.parent_netblock_id = ?
-- 	order siblings by ip_address, netmask_bits
-- and this makes the root selection by including root_netblock_id.
-- This may break down the "everything can be represented by a view" because
-- the recursive table takes too long to build.

-- the postgresql query would have the restriction in the non recursive part
-- of the with query


CREATE OR REPLACE VIEW v_netblock_hier_expanded AS
SELECT
	array_length(path, 1) as netblock_level,
	root_netblock_id,
	site_code,
	path,
	nb.*
FROM jazzhands_cache.ct_netblock_hier
	JOIN netblock nb USING (netblock_id)
	LEFT JOIN v_site_netblock_expanded USING (netblock_id)
;

