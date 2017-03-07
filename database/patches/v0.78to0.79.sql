--
-- Copyright (c) 2017 Todd Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

/*
Invoked:

	--suffix=v78
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();
--
-- Process middle (non-trigger) schema jazzhands
--
--
-- Process middle (non-trigger) schema net_manip
--
--
-- Process middle (non-trigger) schema network_strings
--
--
-- Process middle (non-trigger) schema time_util
--
--
-- Process middle (non-trigger) schema dns_utils
--
--
-- Process middle (non-trigger) schema person_manip
--
--
-- Process middle (non-trigger) schema auto_ac_manip
--
--
-- Process middle (non-trigger) schema company_manip
--
--
-- Process middle (non-trigger) schema token_utils
--
--
-- Process middle (non-trigger) schema port_support
--
--
-- Process middle (non-trigger) schema port_utils
--
--
-- Process middle (non-trigger) schema device_utils
--
--
-- Process middle (non-trigger) schema netblock_utils
--
--
-- Process middle (non-trigger) schema netblock_manip
--
--
-- Process middle (non-trigger) schema physical_address_utils
--
--
-- Process middle (non-trigger) schema component_utils
--
--
-- Process middle (non-trigger) schema snapshot_manip
--
--
-- Process middle (non-trigger) schema lv_manip
--
--
-- Process middle (non-trigger) schema approval_utils
--
--
-- Process middle (non-trigger) schema account_collection_manip
--
--
-- Process middle (non-trigger) schema script_hooks
--
--
-- Process middle (non-trigger) schema backend_utils
--
--
-- Process middle (non-trigger) schema schema_support
--
--
-- Process middle (non-trigger) schema rack_utils
--
-- Creating new sequences....


--------------------------------------------------------------------
-- DEALING WITH TABLE v_dns_sorted
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_sorted', 'v_dns_sorted');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dns_sorted');
DROP VIEW IF EXISTS jazzhands.v_dns_sorted;
CREATE VIEW jazzhands.v_dns_sorted AS
 SELECT dns.dns_record_id,
    dns.network_range_id,
    dns.dns_value_record_id,
    dns.dns_name,
    dns.dns_ttl,
    dns.dns_class,
    dns.dns_type,
    dns.dns_value,
    dns.dns_priority,
    dns.ip,
    dns.netblock_id,
    dns.ref_record_id,
    dns.dns_srv_service,
    dns.dns_srv_protocol,
    dns.dns_srv_weight,
    dns.dns_srv_port,
    dns.should_generate_ptr,
    dns.is_enabled,
    dns.dns_domain_id,
    dns.anchor_record_id,
    dns.anchor_rank
   FROM ( SELECT v_dns.dns_record_id,
            v_dns.network_range_id,
            v_dns.dns_value_record_id,
            v_dns.dns_name,
            v_dns.dns_ttl,
            v_dns.dns_class,
            v_dns.dns_type,
            v_dns.dns_value,
            v_dns.dns_priority,
            host(v_dns.ip) AS ip,
            v_dns.netblock_id,
            v_dns.ref_record_id,
            v_dns.dns_srv_service,
            v_dns.dns_srv_protocol,
            v_dns.dns_srv_weight,
            v_dns.dns_srv_port,
            v_dns.should_generate_ptr,
            v_dns.is_enabled,
            v_dns.dns_domain_id,
            COALESCE(v_dns.ref_record_id, v_dns.dns_value_record_id, v_dns.dns_record_id) AS anchor_record_id,
                CASE
                    WHEN v_dns.ref_record_id IS NOT NULL THEN 2
                    WHEN v_dns.dns_value_record_id IS NOT NULL THEN 3
                    ELSE 1
                END AS anchor_rank
           FROM v_dns) dns
  ORDER BY dns.dns_domain_id, (
        CASE
            WHEN dns.dns_name IS NULL THEN 0
            ELSE 1
        END), (
        CASE
            WHEN dns.dns_type::text = 'NS'::text THEN 0
            WHEN dns.dns_type::text = 'PTR'::text THEN 1
            WHEN dns.dns_type::text = 'A'::text THEN 2
            WHEN dns.dns_type::text = 'AAAA'::text THEN 3
            ELSE 4
        END), (
        CASE
            WHEN dns.dns_type::text = 'PTR'::text THEN lpad(dns.dns_name::text, 10, '0'::text)
            ELSE NULL::text
        END), dns.anchor_record_id, dns.anchor_rank, dns.dns_type, dns.ip, dns.dns_value;

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_dns_sorted';
-- DONE DEALING WITH TABLE v_dns_sorted
--------------------------------------------------------------------
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
--
-- Process drops in jazzhands
--
--
-- Process drops in net_manip
--
--
-- Process drops in network_strings
--
--
-- Process drops in time_util
--
--
-- Process drops in dns_utils
--
--
-- Process drops in person_manip
--
--
-- Process drops in auto_ac_manip
--
--
-- Process drops in company_manip
--
--
-- Process drops in token_utils
--
--
-- Process drops in port_support
--
--
-- Process drops in port_utils
--
--
-- Process drops in device_utils
--
--
-- Process drops in netblock_utils
--
--
-- Process drops in netblock_manip
--
--
-- Process drops in physical_address_utils
--
--
-- Process drops in component_utils
--
--
-- Process drops in snapshot_manip
--
--
-- Process drops in lv_manip
--
--
-- Process drops in approval_utils
--
--
-- Process drops in account_collection_manip
--
--
-- Process drops in script_hooks
--
--
-- Process drops in backend_utils
--
--
-- Process drops in schema_support
--
--
-- Process drops in rack_utils
--
-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- index
-- triggers


-- Clean Up
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
GRANT select on all tables in schema audit to ro_role;
GRANT select on all sequences in schema audit to ro_role;
SELECT schema_support.end_maintenance();
select timeofday(), now();
