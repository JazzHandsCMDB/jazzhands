/*
 * Copyright (c) 2013-2024 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

create sequence x509_ca_cert_serial_number_seq;

CREATE INDEX netblock_case_idx ON netblock USING btree ((
CASE
WHEN (family(ip_address) = 4) THEN (ip_address - '0.0.0.0'::inet)
	ELSE NULL::bigint
END));

CREATE UNIQUE INDEX ak_dns_record_generate_ptr
        ON dns_record ( netblock_id, should_generate_ptr )
WHERE should_generate_ptr AND dns_type IN ('A','AAAA')
	AND netblock_id IS NOT NULL;

/*

requires postgresql 15; enforces is_multivalue

CREATE UNIQUE INDEX uq_non_multivalue_property ON property (
	property_name, property_type, account_collection_id,
	account_id, account_realm_id, company_collection_id,
	company_id, device_collection_id, dns_domain_collection_id,
	layer2_network_collection_id, layer3_network_collection_id,
	netblock_collection_id, network_range_id,
	operating_system_id, operating_system_snapshot_id,
	property_name_collection_id,
	service_environment_collection_id,
	service_version_collection_id, site_code,
	x509_signed_certificate_id
) NULLS NOT DISTINCT WHERE NOT is_multivalue;

*/

CREATE UNIQUE INDEX ak_service_instance_device_is_primary
        ON service_instance ( device_id, is_primary )
WHERE is_primary;

create index idx_netblock_host_ip_address  ON netblock
USING btree (host(ip_address));

CREATE INDEX idx_dns_record_lower_dns_name ON dns_record USING btree
	(lower(dns_name));

-- need to sort this out better
drop trigger IF EXISTS trig_userlog_token_sequence on token_sequence;
drop trigger IF EXISTS trigger_audit_token_sequence on token_sequence;


-- indices on materialized view
-- CREATE UNIQUE INDEX ON mv_dev_col_root (leaf_id);
-- CREATE INDEX ON mv_dev_col_root (leaf_type);
-- CREATE INDEX ON mv_dev_col_root (root_id);
-- CREATE INDEX ON mv_dev_col_root (root_type);
