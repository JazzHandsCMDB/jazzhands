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

	--suffix=v76
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
-- DEALING WITH TABLE v_dns_fwd
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_fwd', 'v_dns_fwd');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dns_fwd');
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
    u.netblock_id,
    u.ref_record_id,
    u.dns_srv_service,
    u.dns_srv_protocol,
    u.dns_srv_weight,
    u.dns_srv_port,
    u.is_enabled,
    u.dns_value_record_id
   FROM ( SELECT d.dns_record_id,
            NULL::integer AS network_range_id,
            d.dns_domain_id,
            COALESCE(rdns.dns_name, d.dns_name) AS dns_name,
            d.dns_ttl,
            d.dns_class,
            d.dns_type,
                CASE
                    WHEN d.dns_value IS NOT NULL THEN d.dns_value::text
                    WHEN (d.dns_type::text = ANY (ARRAY['A'::character varying, 'AAAA'::character varying]::text[])) AND d.netblock_id IS NULL AND d.dns_value_record_id IS NOT NULL THEN NULL::text
                    WHEN d.dns_value_record_id IS NULL THEN d.dns_value::text
                    WHEN dv.dns_domain_id = d.dns_domain_id THEN dv.dns_name::text
                    ELSE concat(dv.dns_name, '.', dv.soa_name, '.')
                END AS dns_value,
            d.dns_priority,
                CASE
                    WHEN d.dns_value_record_id IS NOT NULL AND (d.dns_type::text = ANY (ARRAY['A'::character varying, 'AAAA'::character varying]::text[])) THEN dv.ip_address
                    ELSE ni.ip_address
                END AS ip,
                CASE
                    WHEN d.dns_value_record_id IS NOT NULL AND (d.dns_type::text = ANY (ARRAY['A'::character varying, 'AAAA'::character varying]::text[])) THEN dv.netblock_id
                    ELSE ni.netblock_id
                END AS netblock_id,
            rdns.reference_dns_record_id AS ref_record_id,
            d.dns_srv_service,
            d.dns_srv_protocol,
            d.dns_srv_weight,
            d.dns_srv_port,
            d.is_enabled,
            d.dns_value_record_id
           FROM dns_record d
             LEFT JOIN netblock ni USING (netblock_id)
             LEFT JOIN ( SELECT dns_record.dns_record_id AS reference_dns_record_id,
                    dns_record.dns_name,
                    dns_record.netblock_id,
                    netblock.ip_address
                   FROM dns_record
                     LEFT JOIN netblock USING (netblock_id)) rdns USING (reference_dns_record_id)
             LEFT JOIN ( SELECT dr.dns_record_id,
                    dr.dns_name,
                    dom.dns_domain_id,
                    dom.soa_name,
                    dr.dns_value,
                    dnb.ip_address AS ip,
                    dnb.ip_address,
                    dnb.netblock_id
                   FROM dns_record dr
                     JOIN dns_domain dom USING (dns_domain_id)
                     LEFT JOIN netblock dnb USING (netblock_id)) dv ON d.dns_value_record_id = dv.dns_record_id
        UNION ALL
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
            NULL::text AS dns_value,
            NULL::integer AS dns_prority,
            range.ip,
            NULL::integer AS netblock_id,
            NULL::integer AS ref_dns_record_id,
            NULL::character varying AS dns_srv_service,
            NULL::character varying AS dns_srv_protocol,
            NULL::integer AS dns_srv_weight,
            NULL::integer AS dns_srv_port,
            'Y'::bpchar AS is_enabled,
            NULL::integer AS dns_value_record_id
           FROM ( SELECT dr.network_range_id,
                    dr.dns_domain_id,
                    dr.dns_prefix,
                    nbstart.ip_address + generate_series(0::bigint, nbstop.ip_address - nbstart.ip_address) AS ip
                   FROM network_range dr
                     JOIN netblock nbstart ON dr.start_netblock_id = nbstart.netblock_id
                     JOIN netblock nbstop ON dr.stop_netblock_id = nbstop.netblock_id) range) u
  WHERE u.dns_type::text <> 'REVERSE_ZONE_BLOCK_PTR'::text
UNION ALL
 SELECT NULL::integer AS dns_record_id,
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
    NULL::integer AS netblock_id,
    NULL::integer AS ref_record_id,
    NULL::text AS dns_srv_service,
    NULL::text AS dns_srv_protocol,
    NULL::integer AS dns_srv_weight,
    NULL::integer AS dns_srv_port,
    dns_record.is_enabled,
    NULL::integer AS dns_value_record_id
   FROM dns_record
     JOIN dns_domain USING (dns_domain_id)
     JOIN ( SELECT dns_domain_1.dns_domain_id AS parent_dns_domain_id,
            dns_domain_1.soa_name AS parent_soa_name
           FROM dns_domain dns_domain_1) pdom USING (parent_dns_domain_id)
  WHERE dns_record.dns_class::text = 'IN'::text AND dns_record.dns_type::text = 'NS'::text AND dns_record.dns_name IS NULL AND dns_domain.parent_dns_domain_id IS NOT NULL;

-- just in case
SELECT schema_support.prepare_for_object_replay();
delete from __recreate where type = 'view' and object = 'v_dns_fwd';
-- DONE DEALING WITH TABLE v_dns_fwd
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
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_asset_id_fix');
CREATE OR REPLACE FUNCTION jazzhands.device_asset_id_fix()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	v_asset	asset%ROWTYPE;
BEGIN
	IF TG_OP = 'INSERT' AND 
				NEW.asset_id IS NULL AND 
				NEW.component_id IS NULL THEN
		RETURN NEW;
	ELSIF ( TG_OP = 'UPDATE' AND 
				OLD.asset_id IS NOT DISTINCT FROM NEW.asset_id AND
				OLD.component_id IS NOT DISTINCT FROM NEW.component_id ) THEN
		RETURN NEW;
	END IF;

	IF NEW.asset_id IS NULL and NEW.component_id IS NOT NULL THEN
		SELECT a.asset_id
		INTO	NEW.asset_id
		FROM	asset a
		WHERE	a.component_id = NEW.component_id;
	ELSIF NEW.asset_id IS NOT NULL and NEW.component_id IS NULL THEN
		SELECT a.component_id
		INTO	NEW.component_id
		FROM	asset a
		WHERE	a.asset_id = NEW.asset_id;
	END IF;

	IF TG_OP = 'UPDATE' AND NEW.asset_id IS NOT NULL AND 
			OLD.component_id IS DISTINCT FROM NEW.component_id AND
			OLD.asset_id IS NOT DISTINCT FROM NEW.asset_id THEN
		SELECT	asset_id
		INTO	NEW.asset_id
		FROM	asset
		WHERE	component_id = NEW.component_id;

		IF NEW.asset_id IS NULL THEN
			RAISE 'If component id changes, there must be an asset for the new component' 
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	-- fix any assets that were not setup with a component_id.
	UPDATE asset a
	SET	component_id = NEW.component_id
	WHERE a.asset_id = NEW.asset_id
	AND a.component_id IS DISTINCT FROM NEW.component_id;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'network_interface_netblock_to_ni');
CREATE OR REPLACE FUNCTION jazzhands.network_interface_netblock_to_ni()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_r		network_interface_netblock%ROWTYPE;
	_rank	network_interface_netblock.network_interface_rank%TYPE;
	_tally	INTEGER;
	ni_rec	RECORD;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__network_interface_netblocks'
	   AND  relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __network_interface_netblocks (
			network_interface_id INTEGER, netblock_id INTEGER
		);
	END IF;
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		SELECT count(*) INTO _tally FROM __network_interface_netblocks
		WHERE network_interface_id = NEW.network_interface_id
		AND netblock_id = NEW.netblock_id;
		if _tally >  0 THEN
			RETURN NEW;
		END IF;
		INSERT INTO __network_interface_netblocks
			(network_interface_id, netblock_id)
		VALUES (NEW.network_interface_id,NEW.netblock_id);
	ELSIF TG_OP = 'DELETE' THEN
		SELECT count(*) INTO _tally FROM __network_interface_netblocks
		WHERE network_interface_id = OLD.network_interface_id
		AND netblock_id = OLD.netblock_id;
		if _tally >  0 THEN
			RETURN OLD;
		END IF;
		INSERT INTO __network_interface_netblocks
			(network_interface_id, netblock_id)
		VALUES (OLD.network_interface_id,OLD.netblock_id);
	END IF;

	IF TG_OP = 'INSERT' THEN
		SELECT min(network_interface_rank), count(*)
		INTO _rank, _tally
		FROM network_interface_netblock
		WHERE network_interface_id = NEW.network_interface_id;

		IF _tally = 0 OR NEW.network_interface_rank <= _rank THEN
			UPDATE network_interface set netblock_id = NEW.netblock_id
			WHERE network_interface_id = NEW.network_interface_id
			AND netblock_id IS DISTINCT FROM (NEW.netblock_id)
			;
		END IF;
	ELSIF TG_OP = 'DELETE'  THEN
		-- if we started to disallow NULLs, just ignore this for now
		BEGIN
			SELECT
				* INTO ni_rec
			FROM
				network_interface
			WHERE
				network_interface_id = OLD.network_interface_id;

			IF ni_rec.netblock_id = OLD.netblock_id THEN
				UPDATE
					network_interface ni
				SET
					netblock_id = nin.netblock_id
				FROM
					network_interface_netblock nin
				WHERE
					nin.network_interface_id = OLD.network_interface_id AND
					ni.network_interface_id = OLD.network_interface_id AND
					nin.network_interface_rank = (
						SELECT
							MIN(network_interface_rank)
						FROM
							network_interface_netblock nin2
						WHERE
							nin2.network_interface_id = 
								OLD.network_interface_id
					);
			END IF;
		EXCEPTION WHEN null_value_not_allowed THEN
			RAISE DEBUG 'null_value_not_allowed';
		END;
		RETURN OLD;
	ELSIF TG_OP = 'UPDATE'  THEN
		SELECT min(network_interface_rank)
			INTO _rank
			FROM network_interface_netblock
			WHERE network_interface_id = NEW.network_interface_id;

		IF NEW.network_interface_rank <= _rank THEN
			UPDATE network_interface
				SET network_interface_id = NEW.network_interface_id,
					netblock_id = NEW.netblock_id
				WHERE network_interface_Id = OLD.network_interface_id
				AND netblock_id IS NOT DISTINCT FROM ( OLD.netblock_id );
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

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
ALTER TABLE shared_netblock DROP CONSTRAINT IF EXISTS ak_shared_netblock_netblock;
ALTER TABLE shared_netblock
	ADD CONSTRAINT ak_shared_netblock_netblock
	UNIQUE (netblock_id);

CREATE INDEX aud_shared_netblock_ak_shared_netblock_netblock 
	ON audit.shared_netblock USING btree (netblock_id);

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
