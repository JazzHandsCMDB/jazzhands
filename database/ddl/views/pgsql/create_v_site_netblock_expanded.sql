-- Copyright (c) 2013-2025, Todd M. Kover
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


-- This view shows the site code for each entry in the netblock table
-- even when it's one of the ancestor netblocks that has the
-- site_netblock assignments

--
-- This is kind of nasty but includes everything for historical reasons.
-- "f" in the second union is the same as the first query.
--
CREATE OR REPLACE VIEW v_site_netblock_expanded AS
	SELECT site_code, netblock_id
	FROM netblock
	LEFT JOIN (
		SELECT site_code, netblock_id
		FROM (
			SELECT p.site_code,
			n.netblock_id,
			rank() OVER (PARTITION BY n.netblock_id
				ORDER BY array_length(hc.path, 1) , array_length(n.path, 1)
				) as tier
			FROM property p
			JOIN netblock_collection nc USING (netblock_collection_id)
			JOIN jazzhands_cache.ct_netblock_collection_hier_recurse hc
				USING (netblock_collection_id)
			JOIN netblock_collection_netblock ncn
				USING (netblock_collection_id)
			JOIN jazzhands_cache.ct_netblock_hier n
				ON ncn.netblock_id = n.root_netblock_id
			WHERE property_name = 'per-site-netblock_collection'
			AND p.property_type = 'automated'
		) miniq WHERE tier = 1
	) bizness USING (netblock_id)
	WHERE is_single_address = 'N'
UNION ALL
	SELECT site_code, n.netblock_id
	FROM (
		SELECT site_code, netblock_id
			FROM netblock
			LEFT JOIN (
				SELECT site_code, netblock_id
				FROM (
				SELECT p.site_code,
				n.netblock_id,
				rank() OVER (PARTITION BY n.netblock_id
					ORDER BY array_length(hc.path, 1) ,
						array_length(n.path, 1)
						) as tier
				FROM property p
				JOIN netblock_collection nc USING (netblock_collection_id)
				JOIN jazzhands_cache.ct_netblock_collection_hier_recurse hc
					USING (netblock_collection_id)
				JOIN netblock_collection_netblock ncn
					USING (netblock_collection_id)
				JOIN jazzhands_cache.ct_netblock_hier n
					ON ncn.netblock_id = n.root_netblock_id
				WHERE property_name = 'per-site-netblock_collection'
				AND p.property_type = 'automated'
				) miniq WHERE tier = 1
			) bizness USING (netblock_id)
			WHERE is_single_address = 'N'
	) f
	JOIN netblock n ON f.netblock_id = n.parent_netblock_id
	WHERE n.parent_netblock_id IS NOT NULL
	AND is_single_address = 'Y'
UNION ALL
	SELECT NULL, netblock_id
		FROM netblock
		WHERE is_single_address = 'Y' and parent_netblock_id IS NULL
;
