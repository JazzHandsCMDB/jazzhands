--
-- Copyright (c) 2016 Todd Kover
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

	--suffix=v73
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
-- New function
CREATE OR REPLACE FUNCTION dns_utils.expand_v6(ip_address inet)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
BEGIN
	RETURN array_to_string(array_agg(lpad(n, 4, '0')), ':') from 
	unnest(regexp_split_to_array(
	regexp_replace(
	regexp_replace(host(ip_address)::text,
		'::',
		concat(':', repeat('0:',
			6 -
			(length(regexp_replace(host(ip_address)::text, '::', '')) - 
				length(regexp_replace(
					regexp_replace(host(ip_address)::text, '::', ''),
					':',  '', 'g')))::integer
			)) , 'i'),
		':$', ':0'),
	':')) as n;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION dns_utils.v6_inaddr(ip_address inet)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
BEGIN
	return trim(trailing '.' from
		regexp_replace(reverse(regexp_replace(
			dns_utils.expand_v6(ip_address), ':', '', 
			'g')), '(.)', '\1.', 'g'));
END;
$function$
;

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
-- Process middle (non-trigger) schema schema_support
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_tables');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_tables ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_tables(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
     table_list RECORD;
BEGIN
    FOR table_list IN
	SELECT b.table_name
	FROM information_schema.tables b
		INNER JOIN information_schema.tables a
			USING (table_name,table_type)
	WHERE table_type = 'BASE TABLE'
	AND a.table_schema = aud_schema
	AND b.table_schema = tbl_schema
	ORDER BY table_name
    LOOP
	PERFORM schema_support.save_dependent_objects_for_replay(aud_schema::varchar, table_list.table_name::varchar);
	PERFORM schema_support.save_grants_for_replay(schema, object);
	PERFORM schema_support.rebuild_audit_table
	    ( aud_schema, tbl_schema, table_list.table_name );
	PERFORM schema_support.replay_object_recreates();
	PERFORM schema_support.replay_saved_grants();
    END LOOP;

    PERFORM schema_support.rebuild_audit_triggers(aud_schema, tbl_schema);
END;
$function$
;

--
-- Process middle (non-trigger) schema backend_utils
--
-- Creating new sequences....


--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dns_rvs
DROP VIEW IF EXISTS jazzhands.v_dns_rvs;
CREATE VIEW jazzhands.v_dns_rvs AS
 SELECT NULL::integer AS dns_record_id,
    combo.network_range_id,
    rootd.dns_domain_id,
        CASE
            WHEN family(combo.ip) = 4 THEN regexp_replace(host(combo.ip), '^.*[.](\d+)$'::text, '\1'::text, 'i'::text)
            ELSE regexp_replace(dns_utils.v6_inaddr(combo.ip), ('.'::text || replace(dd.soa_name::text, '.ip6.arpa'::text, ''::text)) || '$'::text, ''::text, 'i'::text)
        END AS dns_name,
    combo.dns_ttl,
    'IN'::text AS dns_class,
    'PTR'::text AS dns_type,
        CASE
            WHEN combo.dns_name IS NULL THEN concat(combo.soa_name, '.')
            ELSE concat(combo.dns_name, '.', combo.soa_name, '.')
        END AS dns_value,
    NULL::integer AS dns_priority,
    combo.ip,
    NULL::integer AS rdns_record_id,
    NULL::text AS rdns_dns_name,
    NULL::text AS dns_srv_service,
    NULL::text AS dns_srv_protocol,
    NULL::integer AS dns_srv_weight,
    NULL::integer AS dns_srv_srv_port,
    combo.is_enabled,
    NULL::text AS val_dns_name,
    NULL::text AS val_domain,
    NULL::text AS val_value,
    NULL::inet AS val_ip
   FROM ( SELECT host(nb.ip_address)::inet AS ip,
            NULL::integer AS network_range_id,
            dns.dns_name,
            dom.soa_name,
            dns.dns_ttl,
            network(nb.ip_address) AS ip_base,
            dns.is_enabled,
            nb.netblock_id
           FROM netblock nb
             JOIN dns_record dns ON nb.netblock_id = dns.netblock_id
             JOIN dns_domain dom ON dns.dns_domain_id = dom.dns_domain_id
          WHERE dns.should_generate_ptr = 'Y'::bpchar AND dns.dns_class::text = 'IN'::text AND (dns.dns_type::text = 'A'::text OR dns.dns_type::text = 'AAAA'::text) AND nb.is_single_address = 'Y'::bpchar
        UNION
         SELECT host(range.ip)::inet AS ip,
            range.network_range_id,
            concat(COALESCE(range.dns_prefix, 'pool'::character varying), '-', replace(host(range.ip), '.'::text, '-'::text)) AS dns_name,
            dom.soa_name,
            NULL::integer AS dns_ttl,
            network(range.ip) AS ip_base,
            'Y'::bpchar AS is_enabled,
            NULL::integer AS netblock_id
           FROM ( SELECT dr.network_range_id,
                    dr.dns_domain_id,
                    dr.dns_prefix,
                    nbstart.ip_address + generate_series(0::bigint, nbstop.ip_address - nbstart.ip_address) AS ip
                   FROM network_range dr
                     JOIN netblock nbstart ON dr.start_netblock_id = nbstart.netblock_id
                     JOIN netblock nbstop ON dr.stop_netblock_id = nbstop.netblock_id) range
             JOIN dns_domain dom ON range.dns_domain_id = dom.dns_domain_id) combo,
    netblock root
     JOIN dns_record rootd ON rootd.netblock_id = root.netblock_id AND rootd.dns_type::text = 'REVERSE_ZONE_BLOCK_PTR'::text
     JOIN dns_domain dd USING (dns_domain_id)
  WHERE family(root.ip_address) = family(combo.ip) AND set_masklen(combo.ip, masklen(root.ip_address)) <<= root.ip_address;

-- DONE DEALING WITH TABLE v_dns_rvs
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dns_fwd
DROP VIEW IF EXISTS jazzhands.v_dns_fwd;
CREATE VIEW jazzhands.v_dns_fwd AS
 SELECT u.dns_record_id,
    u.network_range_id,
    u.dns_domain_id,
    u.dns_name,
    u.dns_ttl,
    u.dns_class,
    u.dns_type,
    u.dns_value,
    u.dns_priority,
    u.ip,
    u.ref_record_id,
    u.ref_dns_name,
    u.dns_srv_service,
    u.dns_srv_protocol,
    u.dns_srv_weight,
    u.dns_srv_port,
    u.is_enabled,
    u.val_dns_name,
    u.val_domain,
    u.val_value,
    u.val_ip
   FROM ( SELECT d.dns_record_id,
            NULL::integer AS network_range_id,
            d.dns_domain_id,
            d.dns_name,
            d.dns_ttl,
            d.dns_class,
            d.dns_type,
            d.dns_value,
            d.dns_priority,
            ni.ip_address AS ip,
            rdns.dns_record_id AS ref_record_id,
            rdns.dns_name AS ref_dns_name,
            d.dns_srv_service,
            d.dns_srv_protocol,
            d.dns_srv_weight,
            d.dns_srv_port,
            d.is_enabled,
            dv.dns_name AS val_dns_name,
            dv.soa_name AS val_domain,
            dv.dns_value AS val_value,
            dv.ip AS val_ip
           FROM dns_record d
             LEFT JOIN netblock ni USING (netblock_id)
             LEFT JOIN dns_record rdns ON rdns.dns_record_id = d.reference_dns_record_id
             LEFT JOIN ( SELECT dr.dns_record_id,
                    dr.dns_name,
                    dom.dns_domain_id,
                    dom.soa_name,
                    dr.dns_value,
                    dnb.ip_address AS ip
                   FROM dns_record dr
                     JOIN dns_domain dom USING (dns_domain_id)
                     LEFT JOIN netblock dnb USING (netblock_id)) dv ON d.dns_value_record_id = dv.dns_record_id
        UNION
         SELECT NULL::integer AS dns_record_id,
            range.network_range_id,
            range.dns_domain_id,
            concat(COALESCE(range.dns_prefix, 'pool'::character varying), '-', replace(host(range.ip), '.'::text, '-'::text)) AS dns_name,
            NULL::integer AS dns_ttl,
            'IN'::character varying AS dns_class,
                CASE
                    WHEN family(range.ip) = 4 THEN 'A'::text
                    ELSE 'AAAA'::text
                END AS dns_type,
            NULL::character varying AS dns_value,
            NULL::integer AS dns_prority,
            range.ip,
            NULL::integer AS ref_dns_record_id,
            NULL::character varying AS ref_dns_name,
            NULL::character varying AS dns_srv_service,
            NULL::character varying AS dns_srv_protocol,
            NULL::integer AS dns_srv_weight,
            NULL::integer AS dns_srv_port,
            'Y'::bpchar AS is_enabled,
            NULL::character varying AS val_dns_name,
            NULL::character varying AS val_domain,
            NULL::character varying AS val_value,
            NULL::inet AS val_ip
           FROM ( SELECT dr.network_range_id,
                    dr.dns_domain_id,
                    dr.dns_prefix,
                    nbstart.ip_address + generate_series(0::bigint, nbstop.ip_address - nbstart.ip_address) AS ip
                   FROM network_range dr
                     JOIN netblock nbstart ON dr.start_netblock_id = nbstart.netblock_id
                     JOIN netblock nbstop ON dr.stop_netblock_id = nbstop.netblock_id) range) u
  WHERE u.dns_type::text <> 'REVERSE_ZONE_BLOCK_PTR'::text
UNION
 SELECT dns_record.dns_record_id,
    NULL::integer AS network_range_id,
    dns_domain.parent_dns_domain_id AS dns_domain_id,
    regexp_replace(dns_domain.soa_name::text, ('\.'::text || pdom.parent_soa_name::text) || '$'::text, ''::text) AS dns_name,
    dns_record.dns_ttl,
    dns_record.dns_class,
    dns_record.dns_type,
        CASE
            WHEN dns_record.dns_value::text ~ '\.$'::text THEN dns_record.dns_value::text
            ELSE concat(dns_record.dns_value, '.', dns_domain.soa_name, '.')
        END AS dns_value,
    dns_record.dns_priority,
    NULL::inet AS ip,
    NULL::integer AS ref_record_id,
    NULL::text AS ref_dns_name,
    NULL::text AS dns_srv_service,
    NULL::text AS dns_srv_protocol,
    NULL::integer AS dns_srv_weight,
    NULL::integer AS dns_srv_port,
    dns_record.is_enabled,
    NULL::character varying AS val_dns_name,
    NULL::character varying AS val_domain,
    NULL::character varying AS val_value,
    NULL::inet AS val_ip
   FROM dns_record
     JOIN dns_domain USING (dns_domain_id)
     JOIN ( SELECT dns_domain_1.dns_domain_id AS parent_dns_domain_id,
            dns_domain_1.soa_name AS parent_soa_name
           FROM dns_domain dns_domain_1) pdom USING (parent_dns_domain_id)
  WHERE dns_record.dns_class::text = 'IN'::text AND dns_record.dns_type::text = 'NS'::text AND dns_record.dns_name IS NULL AND dns_domain.parent_dns_domain_id IS NOT NULL;

-- DONE DEALING WITH TABLE v_dns_fwd
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dns
DROP VIEW IF EXISTS jazzhands.v_dns;
CREATE VIEW jazzhands.v_dns AS
 SELECT v_dns_fwd.dns_record_id,
    v_dns_fwd.network_range_id,
    v_dns_fwd.dns_domain_id,
    v_dns_fwd.dns_name,
    v_dns_fwd.dns_ttl,
    v_dns_fwd.dns_class,
    v_dns_fwd.dns_type,
    v_dns_fwd.dns_value,
    v_dns_fwd.dns_priority,
    v_dns_fwd.ip,
    v_dns_fwd.ref_record_id,
    v_dns_fwd.ref_dns_name,
    v_dns_fwd.dns_srv_service,
    v_dns_fwd.dns_srv_protocol,
    v_dns_fwd.dns_srv_weight,
    v_dns_fwd.dns_srv_port,
    v_dns_fwd.is_enabled,
    v_dns_fwd.val_dns_name,
    v_dns_fwd.val_domain,
    v_dns_fwd.val_value,
    v_dns_fwd.val_ip
   FROM v_dns_fwd
UNION
 SELECT v_dns_rvs.dns_record_id,
    v_dns_rvs.network_range_id,
    v_dns_rvs.dns_domain_id,
    v_dns_rvs.dns_name,
    v_dns_rvs.dns_ttl,
    v_dns_rvs.dns_class,
    v_dns_rvs.dns_type,
    v_dns_rvs.dns_value,
    v_dns_rvs.dns_priority,
    v_dns_rvs.ip,
    v_dns_rvs.rdns_record_id AS ref_record_id,
    v_dns_rvs.rdns_dns_name AS ref_dns_name,
    v_dns_rvs.dns_srv_service,
    v_dns_rvs.dns_srv_protocol,
    v_dns_rvs.dns_srv_weight,
    v_dns_rvs.dns_srv_srv_port AS dns_srv_port,
    v_dns_rvs.is_enabled,
    v_dns_rvs.val_dns_name,
    v_dns_rvs.val_domain,
    v_dns_rvs.val_value,
    v_dns_rvs.val_ip
   FROM v_dns_rvs;

-- DONE DEALING WITH TABLE v_dns
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
-- New function
CREATE OR REPLACE FUNCTION dns_utils.expand_v6(ip_address inet)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
BEGIN
	RETURN array_to_string(array_agg(lpad(n, 4, '0')), ':') from 
	unnest(regexp_split_to_array(
	regexp_replace(
	regexp_replace(host(ip_address)::text,
		'::',
		concat(':', repeat('0:',
			6 -
			(length(regexp_replace(host(ip_address)::text, '::', '')) - 
				length(regexp_replace(
					regexp_replace(host(ip_address)::text, '::', ''),
					':',  '', 'g')))::integer
			)) , 'i'),
		':$', ':0'),
	':')) as n;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION dns_utils.v6_inaddr(ip_address inet)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
BEGIN
	return trim(trailing '.' from
		regexp_replace(reverse(regexp_replace(
			dns_utils.expand_v6(ip_address), ':', '', 
			'g')), '(.)', '\1.', 'g'));
END;
$function$
;

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
-- Process drops in schema_support
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_tables');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_tables ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_tables(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
     table_list RECORD;
BEGIN
    FOR table_list IN
	SELECT b.table_name
	FROM information_schema.tables b
		INNER JOIN information_schema.tables a
			USING (table_name,table_type)
	WHERE table_type = 'BASE TABLE'
	AND a.table_schema = aud_schema
	AND b.table_schema = tbl_schema
	ORDER BY table_name
    LOOP
	PERFORM schema_support.save_dependent_objects_for_replay(aud_schema::varchar, table_list.table_name::varchar);
	PERFORM schema_support.save_grants_for_replay(schema, object);
	PERFORM schema_support.rebuild_audit_table
	    ( aud_schema, tbl_schema, table_list.table_name );
	PERFORM schema_support.replay_object_recreates();
	PERFORM schema_support.replay_saved_grants();
    END LOOP;

    PERFORM schema_support.rebuild_audit_triggers(aud_schema, tbl_schema);
END;
$function$
;

--
-- Process drops in backend_utils
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
