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


--------------------------------------------- BEGIN
CREATE INDEX xif2shared_netblock ON jazzhands.shared_netblock USING btree (netblock_id);
-- These should have been created in the past but weren't for reasons not
-- worth investigating.  Future versions of ERWIN DTRT, so not worth
-- investigating.

CREATE INDEX xif3approval_process_chain ON jazzhands.approval_process_chain USING btree (accept_app_process_chain_id);
CREATE UNIQUE INDEX xif5department ON jazzhands.department USING btree (account_collection_id);
CREATE INDEX xif_asset_comp_id ON jazzhands.asset USING btree (component_id);
CREATE INDEX xif_chasloc_chass_devid ON jazzhands.device USING btree (chassis_location_id);
CREATE INDEX xif_component_prnt_slt_id ON jazzhands.component USING btree (parent_slot_id);
CREATE INDEX xif_dev_devtp_id ON jazzhands.device USING btree (device_type_id);
CREATE INDEX xif_dev_rack_location_id ON jazzhands.device USING btree (rack_location_id);
CREATE INDEX xif_intercomp_conn_slot1_id ON jazzhands.inter_component_connection USING btree (slot1_id);
CREATE INDEX xif_intercomp_conn_slot2_id ON jazzhands.inter_component_connection USING btree (slot2_id);
CREATE INDEX xif_layer3_network_netblock_id ON jazzhands.layer3_network USING btree (netblock_id);
CREATE UNIQUE INDEX xif_netint_nb_netint_id ON jazzhands.network_interface_netblock USING btree (netblock_id);
CREATE UNIQUE INDEX xifunixgrp_uclass_id ON jazzhands.unix_group USING btree (account_collection_id);
CREATE UNIQUE INDEX uq_appaal_name ON jazzhands.appaal USING btree (appaal_name);
--------------------------------------------- END

