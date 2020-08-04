
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
-- distributed under the License is distributed ON an "AS IS" BASIS,
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
		NULL::integer AS network_range_id,
		d.dns_domain_id,
		coalesce(rdns.dns_name, d.dns_name) AS dns_name,
		d.dns_ttl, d.dns_class,
	    d.dns_type,
		CASE WHEN d.dns_value IS NOT NULL THEN d.dns_value
			WHEN d.dns_type IN ('A','AAAA') AND d.netblock_id IS NULL
				AND d.dns_value_record_id IS NOT NULL THEN NULL
			WHEN d.dns_value_record_id IS NULL THEN d.dns_value
			WHEN dv.dns_domain_id = d.dns_domain_id THEN dv.dns_name
			ELSE concat(dv.dns_name, '.', dv.soa_name, '.') END AS dns_value,
	    d.dns_priority,
		CASE WHEN d.dns_value_record_id IS NOT NULL
			AND dns_type IN ('A','AAAA') THEN	dv.ip_address
			ELSE ni.ip_address END AS ip,
		CASE WHEN d.dns_value_record_id IS NOT NULL
			AND dns_type IN ('A','AAAA') THEN	dv.netblock_id
			ELSE ni.netblock_id END AS netblock_id,
	    d.ip_universe_id,
	    rdns.reference_dns_record_id AS ref_record_id,
	    d.dns_srv_service, d.dns_srv_protocol,
	    d.dns_srv_weight, d.dns_srv_port,
	    d.is_enabled,
	    d.should_generate_ptr,
	    d.dns_value_record_id
	  FROM  dns_record d
	    LEFT join netblock ni USING (netblock_id)
	    LEFT JOIN (
			SELECT dns_record_id AS reference_dns_record_id,
					dns_name,
					netblock_id,
					ip_address
			FROM	dns_record
					LEFT JOIN netblock USING (netblock_id)
		) rdns USING (reference_dns_record_id)
	    LEFT JOIN (
			SELECT  dr.dns_record_id, dr.dns_name,
				dom.dns_domain_id, dom.soa_name,
				dr.dns_value,
				dnb.ip_address AS ip,
				dnb.ip_address, dnb.netblock_id
		  	from  dns_record dr
		    	INNER JOIN dns_domain dom USING (dns_domain_id)
		    	LEFT JOIN netblock dnb USING (netblock_id)
	    ) dv ON d.dns_value_record_id = dv.dns_record_id
	UNION ALL
       SELECT
		NULL AS dns_record_id,
		network_range_id,
		dns_domain_id,
		concat(coalesce(dns_prefix, 'pool'), '-',
			replace(host(ip)::text, '.', '-')) AS dns_name,
		NULL AS dns_ttl, 'IN' AS dns_class,
		CASE WHEN family(ip::inet) = 4 THEN 'A' ELSE 'AAAA' END AS dns_type,
		NULL AS dns_value,
		NULL AS dns_prority,
		ip::inet,
		NULL AS netblock_id,
		ip_universe_id,
	    NULL AS ref_dns_record_id,
		NULL AS dns_srv_service,
		NULL AS dns_srv_protocol,
		NULL AS dns_srv_weight,
		NULL AS dns_srv_port,
		true AS is_enabled,
		false AS should_generate_ptr,
		NULL AS dns_value_record_id
	FROM (
       SELECT
		network_range_id,
	    	dns_domain_id,
		nbstart.ip_universe_id,
	    	dns_prefix,
		nbstart.ip_address +
			generate_series(0, nbstop.ip_address - nbstart.ip_address)
			as ip
	  from  network_range dr
		INNER JOIN netblock nbstart
		    ON dr.start_netblock_id = nbstart.netblock_id
		INNER JOIN netblock nbstop
		    ON dr.stop_netblock_id = nbstop.netblock_id
		WHERE dns_domain_id IS NOT NULL
		) range
) u
WHERE  dns_type != 'REVERSE_ZONE_BLOCK_PTR'
	UNION ALL
	SELECT
		NULL::integer AS dns_record_id,	 -- not editable.
		NULL::integer AS network_range_id,
		parent_dns_domain_id AS dns_domain_id,
		regexp_replace(soa_name, '\.' || pdom.parent_soa_name || '$', '') AS dns_name,
		dns_ttl,
		dns_class,
		dns_type,
		CASE WHEN dns_value ~ '\.$' THEN dns_value
			ELSE concat(dns_value, '.', soa_name, '.') END as
				dns_value,
		dns_priority,
		NULL::inet AS ip,
		NULL::integer AS netblock_id,
		dns_record.ip_universe_id,
		NULL::integer AS ref_record_id,
		NULL::text AS dns_srv_service,
		NULL::text AS dns_srv_protocol,
		NULL::integer AS dns_srv_weight,
		NULL::integer AS dns_srv_port,
		is_enabled AS is_enabled,
		false AS should_generate_ptr,
		NULL AS dns_value_record_id
	FROM	dns_record join dns_domain USING (dns_domain_id)
		join (SELECT dns_domain_id AS parent_dns_domain_id,
			soa_name AS parent_soa_name from dns_domain)  pdom
			USING(parent_dns_domain_id)
	WHERE	dns_class = 'IN' AND dns_type = 'NS'
	AND dns_name IS NULL
	AND	parent_dns_domain_id is not NULL
;
