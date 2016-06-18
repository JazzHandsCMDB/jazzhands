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

CREATE OR REPLACE VIEW v_dns_rvs AS
SELECT 	NULL::integer	as dns_record_id,
		network_range_id,
		dns_domain_id,
		CASE WHEN family(ip)= 4
			THEN regexp_replace(host(ip)::text, '^.*[.](\d+)$', '\1', 'i') 
			ELSE regexp_replace(dns_utils.v6_inaddr(ip),
				'.' || replace(dd.soa_name, '.ip6.arpa', '') || '$', '', 'i')
			END as dns_name,
		NULL::integer	as dns_ttl,
		'IN'::text	as dns_class,
		'PTR'::text	as dns_type,
		concat(combo.dns_name, '.', combo.soa_name, '.') AS dns_value,
		NULL::integer as dns_priority,
		combo.ip,
		NULL::integer as rdns_record_id,
		NULL::text as rdns_dns_name,
		NULL::text as dns_srv_service,
		NULL::text as dns_srv_protocol,
		NULL::integer as dns_srv_weight,
		NULL::integer as dns_srv_srv_port,
		'Y'::text as is_enabled,
		NULL::text as val_dns_name,
		NULL::text as val_domain,
		NULL::text as val_value,
		NULL::inet as val_ip
from (
	select  host(nb.ip_address)::inet as ip,
		NULL::integer as network_range_id,
	    dns.dns_name,
	    dom.soa_name,
	    dns.dns_ttl,
	    network(nb.ip_address) as ip_base,
	    dns.is_enabled,
	    nb.netblock_id as netblock_id
	  from  netblock nb
		inner join dns_record dns
		    on nb.netblock_id = dns.netblock_id
		inner join dns_domain dom
		    on dns.dns_domain_id =
			dom.dns_domain_id
	 where
		dns.should_generate_ptr = 'Y'
	   and  dns.dns_class = 'IN'
	   and ( dns.dns_type = 'A' or dns.dns_type = 'AAAA')
UNION
	select host(ip)::inet as ip, 
			network_range_id,
			concat(coalesce(dns_prefix, 'pool'), '-', 
				replace(host(ip)::text, '.', '-')) as dns_name,
			soa_name, NULL as dns_ttl, network(ip) as ip_base,
			'Y' as is_enabled,
			NULL as netblock_id
	from (
       	select  
		network_range_id,
	    	dns_domain_id,
	    	dns_prefix,
		nbstart.ip_address +
			generate_series(0, nbstop.ip_address - nbstart.ip_address)
			as ip
	  	from  network_range dr
			inner join netblock nbstart
		    	on dr.start_netblock_id = nbstart.netblock_id
			inner join netblock nbstop
		    	on dr.stop_netblock_id = nbstop.netblock_id
	) range
		inner join dns_domain dom
		    on range.dns_domain_id =
			dom.dns_domain_id
) combo, netblock root
		inner join dns_record rootd
		    on rootd.netblock_id = root.netblock_id
		    and rootd.dns_type =
			'REVERSE_ZONE_BLOCK_PTR'
	inner join dns_domain dd using (dns_domain_id)
WHERE
	family(root.ip_address) = family(ip)
	AND ( set_masklen(ip, masklen(root.ip_address))
			    <<= root.ip_address
		)
;
