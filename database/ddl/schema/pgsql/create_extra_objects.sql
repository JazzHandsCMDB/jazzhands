/*
 * Copyright (c) 2013-2019 Todd Kover
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

create sequence note_id_seq;

alter table device_note alter column note_id set default nextval('note_id_seq');
alter table person_note alter column note_id set default nextval('note_id_seq');

CREATE INDEX netblock_case_idx ON netblock USING btree ((
CASE
WHEN (family(ip_address) = 4) THEN (ip_address - '0.0.0.0'::inet)
	ELSE NULL::bigint
END));

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


