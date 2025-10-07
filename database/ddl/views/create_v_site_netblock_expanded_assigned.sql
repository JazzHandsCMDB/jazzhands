
-- Copyright (c) 2025, Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--	http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- $Id$
--

CREATE OR REPLACE VIEW v_site_netblock_expanded_assigned AS
SELECT site_code, netblock_id
FROM (
	SELECT p.site_code, n.netblock_id,
		rank() OVER (PARTITION BY n.netblock_id
		ORDER BY (array_length(hc.path, 1)), (array_length(n.path, 1)))
		AS tier
FROM netblock_collection_netblock ncn
	JOIN jazzhands_cache.ct_netblock_collection_hier_recurse hc
		USING (netblock_collection_id)
	JOIN jazzhands_cache.ct_netblock_hier n
		ON ncn.netblock_id = n.root_netblock_id
	JOIN (select *
		FROM property
		WHERE property_name = 'per-site-netblock_collection'
		AND property_type = 'automated'
	) p USING (netblock_collection_id)
) meat WHERE tier = 1
;
