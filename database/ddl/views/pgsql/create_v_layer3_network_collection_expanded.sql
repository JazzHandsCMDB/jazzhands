--
-- Copyright (c) 2015 Matthew Ragan
-- Copyright (c) 2019 Todd Kover
-- All rights reserved.
-- 
-- Licensed under the Aplayer3he License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.aplayer3he.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
CREATE OR REPLACE VIEW v_layer3_network_collection_expanded AS
WITH RECURSIVE layer3_network_collection_recurse (
    level,
    root_layer3_network_collection_id,
    layer3_network_collection_id,
    array_path,
    rvs_array_path,
    cycle
) AS (
        SELECT
            0 as level,
            layer3.layer3_network_collection_id as root_layer3_network_collection_id,
            layer3.layer3_network_collection_id as layer3_network_collection_id,
            ARRAY[layer3.layer3_network_collection_id] as array_path,
            ARRAY[layer3.layer3_network_collection_id] as rvs_array_path,
            false
        FROM
            layer3_network_collection layer3
    UNION ALL
        SELECT
            x.level + 1 as level,
            x.root_layer3_network_collection_id as root_layer3_network_collection_id,
            layer3h.layer3_network_collection_id as layer3_network_collection_id,
            x.array_path || layer3h.layer3_network_collection_id as array_path,
            layer3h.layer3_network_collection_id || x.rvs_array_path
                as rvs_array_path,
            layer3h.layer3_network_collection_id = ANY(array_path) as cycle
        FROM
            layer3_network_collection_recurse x JOIN layer3_network_collection_hier layer3h ON
                x.layer3_network_collection_id = layer3h.child_layer3_network_collection_id
        WHERE
            NOT cycle
) SELECT
        level,
        layer3_network_collection_id,
        root_layer3_network_collection_id,
        array_to_string(array_path, '/') as text_path,
        array_path,
        rvs_array_path
    FROM
        layer3_network_collection_recurse;

