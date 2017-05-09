
-- Copyright (c) 2016-2017, Todd M. Kover
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
--
-- $Id$
--

--
-- This expands ip universes honoring ip_universe_visibility
-- as well as NULLs meaning 'all universes'
--

CREATE OR REPLACE VIEW v_dns AS
SELECT d.dns_record_id,
    d.network_range_id,
    d.dns_domain_id,
    d.dns_name,
    d.dns_ttl,
    d.dns_class,
    d.dns_type,
    d.dns_value,
    d.dns_priority,
    d.ip,
    d.netblock_id,
    d.real_ip_universe_id as ip_universe_Id,
    d.ref_record_id,
    d.dns_srv_service,
    d.dns_srv_protocol,
    d.dns_srv_weight,
    d.dns_srv_port,
    d.is_enabled,
    d.should_generate_ptr,
    d.dns_value_record_id
FROM (
	SELECT  ip_universe_id AS real_ip_universe_id, f.*
	FROM v_dns_fwd f
	UNION
	SELECT x.ip_universe_id AS real_ip_universe_id, f.*
	FROM ip_universe_visibility x, v_dns_fwd f
	WHERE x.visible_ip_universe_id = f.ip_universe_id
	OR    f.ip_universe_id IS NULL

	UNION

	SELECT  ip_universe_id AS real_ip_universe_id, f.*
	FROM v_dns_rvs f
	UNION
	SELECT x.ip_universe_id AS real_ip_universe_id, f.*
	FROM ip_universe_visibility x, v_dns_rvs f
	WHERE x.visible_ip_universe_id = f.ip_universe_id
	OR    f.ip_universe_id IS NULL
) d
