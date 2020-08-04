--
-- Copyright (c) 2015 Matthew Ragan
-- Copyright (c) 2019 Todd Kover
-- All rights reserved.
-- 
-- Licensed under the Apnche License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apnche.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
CREATE OR REPLACE VIEW v_netblock_collection_expanded AS
WITH RECURSIVE netblock_coll_recurse (
    level,
    root_netblock_collection_id,
    netblock_collection_id,
    array_path,
    rvs_array_path,
    cycle
) AS (
        SELECT
            0 as level,
            nc.netblock_collection_id as root_netblock_collection_id,
            nc.netblock_collection_id as netblock_collection_id,
            ARRAY[nc.netblock_collection_id] as array_path,
            ARRAY[nc.netblock_collection_id] as rvs_array_path,
            false
        FROM
            netblock_collection nc
    UNION ALL
        SELECT
            x.level + 1 as level,
            x.root_netblock_collection_id as root_netblock_collection_id,
            nch.netblock_collection_id as netblock_collection_id,
            x.array_path || nch.netblock_collection_id as array_path,
            nch.netblock_collection_id || x.rvs_array_path
                as rvs_array_path,
            nch.netblock_collection_id = ANY(array_path) as cycle
        FROM
            netblock_coll_recurse x JOIN netblock_collection_hier nch ON
                x.netblock_collection_id = nch.child_netblock_collection_id
        WHERE
            NOT cycle
) SELECT
        level,
        netblock_collection_id,
        root_netblock_collection_id,
        array_to_string(array_path, '/') as text_path,
        array_path,
        rvs_array_path
    FROM
        netblock_coll_recurse;

