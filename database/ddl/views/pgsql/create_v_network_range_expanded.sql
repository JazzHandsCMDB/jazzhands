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

CREATE OR REPLACE VIEW jazzhands.v_network_range_expanded
AS
SELECT
	nr.network_range_id,
	nr.network_range_type,
	nr.description,
	nr.parent_netblock_id,
	p.ip_address,
	p.netblock_type,
	p.ip_universe_id,
	start_netblock_id,
	start.ip_address as start_ip_address,
	start.netblock_type as start_netblock_type,
	start.ip_universe_id as start_ip_universe_id,
	stop_netblock_id,
	stop.ip_address as stop_ip_address,
	stop.netblock_type as stop_netblock_type,
	stop.ip_universe_id as stop_ip_universe_id,
	nr.dns_prefix,
	nr.dns_domain_id,
	dd.soa_name
FROM
	jazzhands.network_range nr JOIN
	jazzhands.netblock p ON (nr.parent_netblock_id = p.netblock_id) JOIN
	jazzhands.netblock start ON (nr.start_netblock_id = start.netblock_id) JOIN
	jazzhands.netblock stop ON (nr.stop_netblock_id = stop.netblock_id)
		LEFT JOIN
	jazzhands.dns_domain dd USING (dns_domain_id);
