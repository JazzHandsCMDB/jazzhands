-- Copyright (c) 2017, Matthew Ragan
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

CREATE OR REPLACE VIEW jazzhands.v_layer3_network_expanded
AS
SELECT
	l3.layer3_network_id,
	l3.description AS layer3_network_description,
	n.netblock_id,
	n.ip_address,
	n.netblock_type,
	n.ip_universe_id,
	l3.default_gateway_netblock_id,
	dg.ip_address AS default_gateway_ip_address,
	dg.netblock_type AS default_gateway_netblock_type,
	dg.ip_universe_id AS default_gateway_ip_universe_id,
	l2.layer2_network_id,
	l2.encapsulation_name,
	l2.encapsulation_domain,
	l2.encapsulation_type,
	l2.encapsulation_tag,
	l2.description AS layer2_network_description
FROM
	jazzhands.layer3_network l3 JOIN
	jazzhands.netblock n USING (netblock_id) LEFT JOIN
	jazzhands.netblock dg ON 
		(l3.default_gateway_netblock_id = dg.netblock_id) LEFT JOIN
	jazzhands.layer2_network l2 USING (layer2_network_id);
