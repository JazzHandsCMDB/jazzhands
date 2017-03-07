-- Copyright (c) 2016, Todd M. Kover
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

CREATE OR REPLACE VIEW v_dns_sorted AS
SELECT * 
FROM (
select  dns_record_id,
	network_range_id,
	dns_value_record_id,
	dns_name,
	dns_ttl,
	dns_class,
	dns_type,
	dns_value,
	dns_priority,
	host(ip) as ip,
	netblock_id,
	ref_record_id,
	dns_srv_service,
	dns_srv_protocol,
	dns_srv_weight,
	dns_srv_port,
	should_generate_ptr,
	dns_domain_id,
	coalesce(ref_record_id, dns_value_record_id, dns_record_id) as anchor_record_id,
	CASE WHEN ref_record_id is NOT NULL THEN 2
		WHEN dns_value_record_id IS NOT NULL THEN 3
		ELSE 1
	END as anchor_rank
  from	v_dns
) dns
order by 
	dns_domain_id,
	CASE WHEN dns_name IS NULL THEN 0 ELSE 1 END,
	CASE WHEN dns_type = 'NS' THEN 0
		WHEN dns_type = 'PTR' THEN 1
		WHEN dns_type = 'A' THEN 2
		WHEN dns_type = 'AAAA' THEN 3
		ELSE 4
	END,
	CASE WHEN DNS_TYPE = 'PTR' THEN lpad(dns_name, 10, '0') END,
	anchor_record_id, anchor_rank,
	dns_type,
	ip, dns_value
;
