
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

CREATE OR REPLACE VIEW v_dns_fwd AS
SELECT * FROM  (
       SELECT
	    d.dns_record_id,
		NULL::integer as network_range_id,
		d.dns_domain_id,
		d.dns_name, d.dns_ttl, d.dns_class,
	    d.dns_type, d.dns_value,
	    d.dns_priority,
	    ni.ip_address as ip,
	    rdns.dns_record_Id as ref_record_id,
	    rdns.dns_name as ref_dns_name,
	    d.dns_srv_service, d.dns_srv_protocol,
	    d.dns_srv_weight, d.dns_srv_port,
	    d.is_enabled,
	    dv.dns_name as val_dns_name,
	    dv.soa_name as val_domain,
	    dv.dns_value as val_value,
	    dv.ip as val_ip
	  FROM  dns_record d
	    LEFT join netblock ni USING (netblock_id)
	    left join dns_record rdns
		on rdns.dns_record_id =
		    d.reference_dns_record_id
	    left join (
		select  dr.dns_record_id, dr.dns_name,
		    dom.dns_domain_id, dom.soa_name,
		    dr.dns_value,
		    dnb.ip_address as ip
		  from  dns_record dr
		    inner join dns_domain dom
			using (dns_domain_id)
		    left join netblock dnb
			using (netblock_id)
	    ) dv on d.dns_value_record_id = dv.dns_record_id
	UNION
       SELECT
			NULL as dns_record_id,
			network_range_id,
			dns_domain_id,
			concat(coalesce(dns_prefix, 'pool'), '-',
				replace(host(ip)::text, '.', '-')) as dns_name,
			NULL as dns_ttl, 'IN' as dns_class,
			CASE WHEN family(ip::inet) = 4 THEN 'A' ELSE 'AAAA' END as dns_type,
			NULL as dns_value,
			NULL as dns_prority,
			ip::inet,
	    NULL as ref_dns_record_Id,
	    NULL as ref_dns_name,
			NULL as dns_srv_service,
			NULL as dns_srv_protocol,
			NULL as dns_srv_weight,
			NULL as dns_srv_port,
			'Y' as is_enabled,
			NULL as val_dns_name,
			NULL as val_domain,
			NULL as val_value,
	    NULL as val_ip
	FROM (
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
) u
WHERE  dns_type != 'REVERSE_ZONE_BLOCK_PTR'
	UNION
	SELECT
		dns_record_id,
		NULL::integer AS network_range_id,
		parent_dns_domain_id as dns_domain_id,
		regexp_replace(soa_name, '\.' || pdom.parent_soa_name || '$', '') as dns_name,
		dns_ttl,
		dns_class,
		dns_type,
		CASE WHEN dns_value ~ '\.$' THEN dns_value
			ELSE concat(dns_value, '.', soa_name, '.') END as 
				dns_value,
		dns_priority,
		NULL::inet AS ip,
		NULL::integer AS ref_record_id,
		NULL::text AS ref_dns_name,
		NULL::text AS dns_srv_service,
		NULL::text AS dns_srv_protocol,
		NULL::integer AS dns_srv_weight,
		NULL::integer AS dns_srv_port,
		is_enabled AS is_enabled,
		NULL AS val_dns_name,
		NULL AS val_domain,
		NULL AS val_value,
		NULL::inet AS val_ip
	FROM	dns_record join dns_domain using (dns_domain_id)
		join (select dns_domain_id as parent_dns_domain_id,
			soa_name as parent_soa_name from dns_domain)  pdom
			USING(parent_dns_domain_id)
	WHERE	dns_class = 'IN' AND dns_type = 'NS'
	AND dns_name IS NULL
	AND	parent_dns_domain_id is not NULL
;
