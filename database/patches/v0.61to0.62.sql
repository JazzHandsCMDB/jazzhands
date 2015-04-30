/*
Invoked:

	--suffix=v62
	--scan-tables
	val_x509_revocation_reason
	x509_certificate
	component_property
	val_property
	v_dns_changes_pending
	net_manip.expand_ipv6_address
	logical_volume
	volume_group_physicalish_vol
	component_utils.create_component_template_slots
	do_layer1_connection_trigger
	person_manip.pick_login
	port_utils.setup_device_power
	department
	device_utils.retire_device
	v_dev_col_user_prop_expanded
	v_unix_passwd_mappings
	v_l1_all_physical_ports
	v_corp_family_account
*/

COMMENT ON SCHEMA netblock_manip IS 'part of jazzhands';

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();

--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_unix_passwd_mappings
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'v_unix_passwd_mappings');
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_passwd_mappings', 'v_unix_passwd_mappings');
DROP VIEW v_unix_passwd_mappings;
CREATE VIEW v_unix_passwd_mappings AS
 WITH passtype AS (
         SELECT ap.account_id,
            ap.password,
            ap.expire_time,
            ap.change_time,
            subq.device_collection_id,
            subq.password_type,
            subq.ord
           FROM ( SELECT dchd.device_collection_id,
                    p.property_value_password_type AS password_type,
                    row_number() OVER (PARTITION BY dchd.device_collection_id) AS ord
                   FROM jazzhands.v_property p
                     JOIN jazzhands.v_device_coll_hier_detail dchd ON dchd.parent_device_collection_id = p.device_collection_id
                  WHERE p.property_name::text = 'UnixPwType'::text AND p.property_type::text = 'MclassUnixProp'::text) subq
             JOIN jazzhands.account_password ap USING (password_type)
             JOIN jazzhands.account_unix_info a USING (account_id)
          WHERE subq.ord = 1
        ), accts AS (
         SELECT a.account_id,
            a.login,
            a.person_id,
            a.company_id,
            a.account_realm_id,
            a.account_status,
            a.account_role,
            a.account_type,
            a.description,
            a.data_ins_user,
            a.data_ins_date,
            a.data_upd_user,
            a.data_upd_date,
            aui.unix_uid,
            aui.unix_group_acct_collection_id,
            aui.shell,
            aui.default_home
           FROM jazzhands.account a
             JOIN jazzhands.account_unix_info aui USING (account_id)
             JOIN jazzhands.val_person_status vps ON a.account_status::text = vps.person_status::text
          WHERE vps.is_disabled = 'N'::bpchar
        ), extra_groups AS (
         SELECT p.device_collection_id,
            acae.account_id,
            array_agg(ac.account_collection_name) AS group_names
           FROM jazzhands.v_property p
             JOIN jazzhands.device_collection dc USING (device_collection_id)
             JOIN jazzhands.account_collection ac USING (account_collection_id)
             JOIN jazzhands.account_collection pac ON pac.account_collection_id = p.property_value_account_coll_id
             JOIN jazzhands.v_acct_coll_acct_expanded acae ON pac.account_collection_id = acae.account_collection_id
          WHERE p.property_type::text = 'MclassUnixProp'::text AND p.property_name::text = 'UnixGroupMemberOverride'::text AND dc.device_collection_type::text <> 'mclass'::text
          GROUP BY p.device_collection_id, acae.account_id
        )
 SELECT s.device_collection_id,
    s.account_id,
    s.login,
    s.crypt,
    s.unix_uid,
    s.unix_group_name,
    regexp_replace(s.gecos, ' +'::text, ' '::text, 'g'::text) AS gecos,
    regexp_replace(
        CASE
            WHEN s.forcehome IS NOT NULL AND s.forcehome::text ~ '/$'::text THEN concat(s.forcehome, s.login)
            WHEN s.home IS NOT NULL AND s.home::text ~ '^/'::text THEN s.home::text
            WHEN s.hometype::text = 'generic'::text THEN concat(COALESCE(s.homeplace, '/home'::character varying), '/', 'generic')
            WHEN s.home IS NOT NULL AND s.home::text ~ '/$'::text THEN concat(s.home, '/', s.login)
            WHEN s.homeplace IS NOT NULL AND s.homeplace::text ~ '/$'::text THEN concat(s.homeplace, '/', s.login)
            ELSE concat(COALESCE(s.homeplace, '/home'::character varying), '/', s.login)
        END, '/+'::text, '/'::text, 'g'::text) AS home,
    s.shell,
    s.ssh_public_key,
    s.setting,
    s.mclass_setting,
    s.group_names AS extra_groups
   FROM ( SELECT o.device_collection_id,
            a.account_id,
            a.login,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceCrypt'::text)]::text,
                CASE
                    WHEN pwt.expire_time IS NOT NULL AND now() < pwt.expire_time OR (now() - pwt.change_time) < concat(COALESCE((( SELECT v_property.property_value
                       FROM jazzhands.v_property
                      WHERE v_property.property_type::text = 'Defaults'::text AND v_property.property_name::text = '_maxpasswdlife'::text))::text, 90::text), 'days')::interval THEN pwt.password
                    ELSE NULL::character varying
                END::text, '*'::text) AS crypt,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceUserUID'::text)]::integer, a.unix_uid) AS unix_uid,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceUserGroup'::text)]::character varying(255), ugac.account_collection_name) AS unix_group_name,
                CASE
                    WHEN a.description IS NOT NULL THEN a.description::text
                    ELSE concat(COALESCE(p.preferred_first_name, p.first_name), ' ',
                    CASE
                        WHEN p.middle_name IS NOT NULL AND length(p.middle_name::text) = 1 THEN concat(p.middle_name, '.')::character varying
                        ELSE p.middle_name
                    END, ' ', COALESCE(p.preferred_last_name, p.last_name))
                END AS gecos,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceHome'::text)], a.default_home) AS home,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceShell'::text)], a.shell) AS shell,
            o.setting,
            mcs.mclass_setting,
            o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceHome'::text)] AS forcehome,
            mcs.mclass_setting[( SELECT i.i + 1
                   FROM generate_subscripts(mcs.mclass_setting, 1) i(i)
                  WHERE mcs.mclass_setting[i.i]::text = 'HomePlace'::text)] AS homeplace,
            mcs.mclass_setting[( SELECT i.i + 1
                   FROM generate_subscripts(mcs.mclass_setting, 1) i(i)
                  WHERE mcs.mclass_setting[i.i]::text = 'UnixHomeType'::text)] AS hometype,
            ssh.ssh_public_key,
            extra_groups.group_names
           FROM accts a
             JOIN jazzhands.v_device_col_account_cart o USING (account_id)
             JOIN jazzhands.device_collection dc USING (device_collection_id)
             JOIN jazzhands.person p USING (person_id)
             JOIN jazzhands.unix_group ug ON a.unix_group_acct_collection_id = ug.account_collection_id
             JOIN jazzhands.account_collection ugac ON ugac.account_collection_id = ug.account_collection_id
             LEFT JOIN extra_groups USING (device_collection_id, account_id)
             LEFT JOIN jazzhands.v_device_collection_account_ssh_key ssh ON a.account_id = ssh.account_id AND (ssh.device_collection_id IS NULL OR ssh.device_collection_id = o.device_collection_id)
             LEFT JOIN jazzhands.v_unix_mclass_settings mcs ON mcs.device_collection_id = dc.device_collection_id
             LEFT JOIN passtype pwt ON o.device_collection_id = pwt.device_collection_id AND a.account_id = pwt.account_id) s
  ORDER BY s.device_collection_id, s.account_id;

delete from __recreate where type = 'view' and object = 'v_unix_passwd_mappings';
-- DONE DEALING WITH TABLE v_unix_passwd_mappings [3845308]
--------------------------------------------------------------------


-- Creating new sequences....


-- Copyright (c) 2015, Kurt Adam
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

\set ON_ERROR_STOP

DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'snapshot_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS snapshot_manip CASCADE;
		-- CREATE SCHEMA snapshot_manip AUTHORIZATION jazzhands;
		CREATE SCHEMA snapshot_manip;
		COMMENT ON SCHEMA snapshot_manip IS 'part of jazzhands';
	END IF;
END;
$$;

CREATE OR REPLACE FUNCTION snapshot_manip.add_snapshot(
	os_name       operating_system.operating_system_name%type,
	os_version    operating_system.version%type,
	snapshot_name operating_system_snapshot.operating_system_snapshot_name%type,
	snapshot_type operating_system_snapshot.operating_system_snapshot_type%type
) RETURNS integer AS $$

DECLARE
	major_version text;
	companyid     company.company_id%type;
	osid          operating_system.operating_system_id%type;
	snapid        operating_system_snapshot.operating_system_snapshot_id%type;
	dcid          device_collection.device_collection_id%type;

BEGIN
	SELECT company.company_id INTO companyid FROM company
		INNER JOIN company_type USING (company_id)
		WHERE company_short_name = os_name
		AND company_type = 'os provider';

	IF NOT FOUND THEN
		RAISE 'Operating system vendor not found';
	END IF;

	SELECT operating_system_id INTO osid FROM operating_system
		WHERE operating_system_name = os_name
		AND version = os_version;

	IF NOT FOUND THEN
		major_version := substring(os_version, '^[^.]+');

		INSERT INTO operating_system (
			operating_system_name, 
			company_id, 
			major_version, 
			version, 
			operating_system_family
		) VALUES (
			os_name,
			companyid,
			major_version,
			os_version,
			'Linux'
		) RETURNING * INTO osid;

		INSERT INTO property (
			property_type, 
			property_name, 
			operating_system_id,
			property_value
		) VALUES (
			'OperatingSystem',
			'AllowOSDeploy',
			osid,
			'N'
		);
	END IF;

	INSERT INTO operating_system_snapshot (
		operating_system_snapshot_name, 
		operating_system_snapshot_type, 
		operating_system_id
	) VALUES (
		snapshot_name, 
		snapshot_type, 
		osid
	) RETURNING * INTO snapid;

	INSERT INTO device_collection (
		device_collection_name, 
		device_collection_type, 
		description
	) VALUES (
		CONCAT(os_name, '-', os_version, '-', snapshot_name),
		'os-snapshot', 
		NULL
	) RETURNING * INTO dcid;

	INSERT INTO property (
		property_type, 
		property_name, 
		device_collection_id,
		operating_system_snapshot_id,
		property_value
	) VALUES (
		'OperatingSystem',
		'DeviceCollection',
		dcid,
		snapid,
		NULL
	), (
		'OperatingSystem',
		'AllowSnapDeploy',
		NULL,
		snapid,
		'N'
	);

	RETURN snapid;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION snapshot_manip.set_default_snapshot(
	os_name       operating_system.operating_system_name%type,
	os_version    operating_system.version%type,
	snapshot_name operating_system_snapshot.operating_system_snapshot_name%type
) RETURNS void AS $$

DECLARE
	osrec           RECORD;
	previous_snapid operating_system_snapshot.operating_system_snapshot_id%type;

BEGIN
	SELECT os.operating_system_id, oss.operating_system_snapshot_id INTO osrec FROM operating_system os
		INNER JOIN operating_system_snapshot oss USING(operating_system_id)
		WHERE operating_system_name = os_name
		AND version = os_version
		AND operating_system_snapshot_name = snapshot_name;

	IF NOT FOUND THEN
		RAISE 'Operating system snapshot not found';
	END IF;

	SELECT oss.operating_system_snapshot_id INTO previous_snapid FROM operating_system_snapshot oss
		INNER JOIN operating_system USING (operating_system_id)
		INNER JOIN property USING (operating_system_snapshot_id)
		WHERE version = os_version
		AND operating_system_name = os_name
		AND property_type = 'OperatingSystem'
		AND property_name = 'DefaultSnapshot';

	IF previous_snapid IS NOT NULL THEN
		IF osrec.operating_system_snapshot_id = previous_snapid THEN
			RETURN;
		END IF;

		DELETE FROM property
			WHERE operating_system_snapshot_id = previous_snapid
			AND property_type = 'OperatingSystem'
			AND property_name = 'DefaultSnapshot';
	END IF;

	INSERT INTO property (
		property_type, 
		property_name, 
		operating_system_id, 
		operating_system_snapshot_id
	) VALUES (
		'OperatingSystem', 
		'DefaultSnapshot', 
		osrec.operating_system_id, 
		osrec.operating_system_snapshot_id
	);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION snapshot_manip.set_default_os_version(
	os_name       operating_system.operating_system_name%type,
	os_version    operating_system.version%type
) RETURNS void AS $$

DECLARE
	osid          operating_system.operating_system_id%type;
	previous_osid operating_system.operating_system_id%type;

BEGIN
	SELECT os.operating_system_id INTO osid FROM operating_system os
		WHERE operating_system_name = os_name
		AND version = os_version;

	IF NOT FOUND THEN
		RAISE 'Operating system not found';
	END IF;

	SELECT os.operating_system_id INTO previous_osid FROM operating_system os
		INNER JOIN property USING (operating_system_id)
		WHERE operating_system_name = os_name
		AND property_type = 'OperatingSystem'
		AND property_name = 'DefaultVersion';

	IF previous_osid IS NOT NULL THEN
		IF osid = previous_osid THEN
			RAISE NOTICE 'samey same';
			RETURN;
		END IF;

		DELETE FROM property
			WHERE operating_system_id = previous_osid
			AND property_type = 'OperatingSystem'
			AND property_name = 'DefaultVersion';
	END IF;

	INSERT INTO property (
		property_type, 
		property_name, 
		operating_system_id
	) VALUES (
		'OperatingSystem', 
		'DefaultVersion', 
		osid
	);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION snapshot_manip.delete_snapshot(
	os_name       operating_system.operating_system_name%type,
	os_version    operating_system.version%type,
	snapshot_name operating_system_snapshot.operating_system_snapshot_name%type
) RETURNS void AS $$

DECLARE
	snapid  operating_system_snapshot.operating_system_snapshot_id%type;
	dcid    device_collection.device_collection_id%type;
	dccount integer;

BEGIN
	SELECT operating_system_snapshot_id INTO snapid FROM operating_system
		INNER JOIN operating_system_snapshot USING (operating_system_id)
		WHERE operating_system_name = os_name
		AND operating_system_snapshot_name = snapshot_name
		AND version = os_version;

	IF NOT FOUND THEN
		RAISE 'Operating system snapshot not found';
	END IF;

	SELECT device_collection_id INTO dcid FROM property
		INNER JOIN operating_system_snapshot USING (operating_system_snapshot_id)
		WHERE property_type = 'OperatingSystem'
		AND property_name = 'DeviceCollection'
		AND property.operating_system_snapshot_id = snapid;

	SELECT COUNT(*) INTO dccount FROM device_collection_device where device_collection_id = dcid;

	IF dccount != 0 THEN
		RAISE 'Operating system snapshot still in use by some devices';
	END IF;

	DELETE FROM property WHERE operating_system_snapshot_id = snapid;
	DELETE FROM device_collection WHERE device_collection_name = CONCAT(os_name, '-', os_version, '-', snapshot_name);
	DELETE FROM operating_system_snapshot WHERE operating_system_snapshot_id = snapid;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

GRANT USAGE ON SCHEMA snapshot_manip TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA snapshot_manip TO iud_role;

-- Copyright (c) 2013-2015, Todd M. Kover
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

\set ON_ERROR_STOP

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'dns_utils';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS dns_utils;
                CREATE SCHEMA dns_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA dns_utils IS 'part of jazzhands';
        END IF;
END;
$$;

------------------------------------------------------------------------------
--
-- Add default NS records to a domain
--
------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dns_utils.add_ns_records(
	dns_domain_id	dns_domain.dns_domain_id%type
) RETURNS void AS
$$
BEGIN
	EXECUTE '
		INSERT INTO dns_record (
			dns_domain_id, dns_class, dns_type, dns_value
		) select $1, $2, $3, property_value
		FROM property
		WHERE property_name = $4
		AND property_type = $5
	' USING dns_domain_id, 'IN', 'NS', '_authdns', 'Defaults';
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql;


------------------------------------------------------------------------------
--
-- Given a cidr block, returns a list of all in-addr zones for that block.
-- Note that for ip6, it just makes it a /64.  This may or may not be correct.
--
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_utils.get_all_domains_for_cidr(
	block		netblock.ip_address%TYPE
) returns text[]
AS
$$
DECLARE
	cur			inet;
	rv			text[];
BEGIN
	IF family(block) = 4 THEN
		FOR cur IN SELECT set_masklen((block + o), 24) 
					FROM generate_series(0, (256 * (2 ^ (24 - 
						masklen(block))) - 1)::integer, 256) as x(o)
		LOOP
			rv = rv || dns_utils.get_domain_from_cidr(block);
			rv = rv || dns_utils.get_domain_from_cidr(cur);
		END LOOP;
	ELSIF family(block) = 6 THEN
			-- note sure if we should do this or not, but we are..
			cur := set_masklen(block, 64);
			rv = rv || dns_utils.get_domain_from_cidr(cur);
	ELSE
		RAISE EXCEPTION 'Not IPv% aware.', family(block);
	END IF;
    return rv;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;



------------------------------------------------------------------------------
--
-- Given a cidr block, return its dns domain
--
-- Does /24 for v4 and /64 for v6.  (this happens in a called function)
--
-- Works for both v4 and v6
--
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_utils.get_domain_from_cidr(
	block		inet
) returns text
AS
$$
DECLARE
	ipaddr		text;
	ipnodes		text[];
	domain		text;
	j			text;
BEGIN
	IF family(block) != 4 THEN
		j := '';
		-- this needs to be tweaked to expand ::, which postgresql does
		-- not easily do.  This requires more thinking than I was up for today.
		ipaddr := net_manip.expand_ipv6_address(block);
		ipaddr := regexp_replace(ipaddr, ':', '', 'g');
		ipaddr := lpad(ipaddr, masklen(block)/4, '0');
	ELSE
		j := '\.';
		ipaddr := host(block);
	END IF;

	EXECUTE 'select array_agg(member order by rn desc)
		from (
        select
			row_number() over () as rn, *
			from
			unnest(regexp_split_to_array($1, $2)) as member
		) x
	' INTO ipnodes USING ipaddr, j;

	IF family(block) = 4 THEN
		domain := array_to_string(ARRAY[ipnodes[2],ipnodes[3],ipnodes[4]], '.')
			|| '.in-addr.arpa';
	ELSE
		domain := array_to_string(ipnodes, '.') 
			|| '.ip6.arpa';
	END IF;

	RETURN domain;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;


------------------------------------------------------------------------------
--
-- If the host is an in-addr block, figure out the netblock and setup linkage
-- for it.  This just works on one zone
--
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_utils.get_or_create_rvs_netblock_link(
	soa_name		dns_domain.soa_name%type,
	dns_domain_id	dns_domain.dns_domain_id%type
) RETURNS netblock.netblock_id%type AS $$
DECLARE
	nblk_id	netblock.netblock_id%type;
	blk text;
	root	text;
	brk	text[];
	ipmember text[];
	ip	inet;
	j text;
BEGIN
	brk := regexp_matches(soa_name, '^(.+)\.(in-addr|ip6)\.arpa$');
	IF brk[2] = 'in-addr' THEN
		j := '.';
	ELSE
		j := ':';
	END IF;

	EXECUTE 'select array_agg(member order by rn desc), $2
		from (
        select
			row_number() over () as rn, *
			from
			unnest(regexp_split_to_array($1, $3)) as member
		) x
	' INTO ipmember USING brk[1], j, '\.';

	IF brk[2] = 'in-addr' THEN
		IF array_length(ipmember, 1) > 4 THEN
			RAISE EXCEPTION 'Unable to work with anything smaller than a /24';
		ELSIF array_length(ipmember, 1) != 3 THEN
			-- If this is not a /24, then do not add any rvs association
			RETURN NULL;
		END IF;
		WHILE array_length(ipmember, 1) < 4
		LOOP
			ipmember := array_append(ipmember, '0');
		END LOOP;
		ip := concat(array_to_string(ipmember, j),'/24')::inet;
	ELSE
		ip := concat(
			regexp_replace(
				array_to_string(ipmember, ''), '(....)', '\1:', 'g'),
			':/64')::inet;
	END IF;

	SELECT netblock_id
		INTO	nblk_id
		FROM	netblock
		WHERE	netblock_type = 'dns'
		AND		is_single_address = 'N'
		AND		can_subnet = 'N'
		AND		netblock_status = 'Allocated'
		AND		ip_universe_id = 0
		AND		ip_address = ip;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address, netblock_type, is_single_address,
			can_subnet, netblock_status, ip_universe_id
		) VALUES (
			ip, 'dns', 'N',
			'N', 'Allocated', 0
		) RETURNING netblock_id INTO nblk_id;
	END IF;

	EXECUTE '
		INSERT INTO dns_record(
			dns_domain_id, dns_class, dns_type, netblock_id
		) values (
			$1, $2, $3, $4
		)
	' USING dns_domain_id, 'IN', 'REVERSE_ZONE_BLOCK_PTR', nblk_id;

	RETURN nblk_id;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql;


------------------------------------------------------------------------------
--
-- given a dns domain, type and boolean, add the domain with that type and
-- optionally (tho defaulting to true) at default nameservers
--
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_utils.add_dns_domain(
	soa_name			dns_domain.soa_name%type,
	dns_domain_type		dns_domain.dns_domain_type%type DEFAULT NULL,
	add_nameservers		boolean DEFAULT true
) RETURNS dns_domain.dns_domain_id%type AS $$
DECLARE
	elements		text[];
	parent_zone		text;
	parent_id		dns_domain.dns_domain_id%type;
	domain_id		dns_domain.dns_domain_id%type;
	elem			text;
	sofar			text;
	rvs_nblk_id		netblock.netblock_id%type;
BEGIN
	elements := regexp_split_to_array(soa_name, '\.');
	sofar := '';
	FOREACH elem in ARRAY elements
	LOOP
		IF octet_length(sofar) > 0 THEN
			sofar := sofar || '.';
		END IF;
		sofar := sofar || elem;
		parent_zone := regexp_replace(soa_name, '^'||sofar||'.', '');
		EXECUTE 'SELECT dns_domain_id FROM dns_domain 
			WHERE soa_name = $1' INTO parent_id USING soa_name;
		IF parent_id IS NOT NULL THEN
			EXIT;
		END IF;
	END LOOP;

	IF dns_domain_type IS NULL THEN
		IF soa_name ~ '^.*(in-addr|ip6)\.arpa$' THEN
			dns_domain_type := 'reverse';
		END IF;
	END IF;

	IF dns_domain_type IS NULL THEN
		RAISE EXCEPTION 'Unable to guess dns_domain_type for %',
			soa_name USING ERRCODE = 'not_null_violation'; 
	END IF;

	EXECUTE '
		INSERT INTO dns_domain (
			soa_name,
			soa_class,
			soa_mname,
			soa_rname,
			parent_dns_domain_id,
			should_generate,
			dns_domain_type
		) VALUES (
			$1,
			$2,
			$3,
			$4,
			$5,
			$6,
			$7
		) RETURNING dns_domain_id' INTO domain_id 
		USING soa_name, 
			'IN',
			(select property_value from property where property_type = 'Defaults'
				and property_name = '_dnsmname'),
			(select property_value from property where property_type = 'Defaults'
				and property_name = '_dnsrname'),
			parent_id,
			'Y',
			dns_domain_type
	;

	IF dns_domain_type = 'reverse' THEN
		rvs_nblk_id := dns_utils.get_or_create_rvs_netblock_link(
			soa_name, domain_id);
	END IF;

	IF add_nameservers THEN
		PERFORM dns_utils.add_ns_records(domain_id);
	END IF;

	RETURN domain_id;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql;


------------------------------------------------------------------------------
--
-- Given a cidr block, add a dns domain for it, which will take care of linkage
-- to an in-addr record for ipv4 addresses or ipv6 addresses as appropriate.
--
--
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_utils.add_domain_from_cidr(
	block		inet
) returns dns_domain.dns_domain_id%TYPE
AS
$$
DECLARE
	ipaddr		text;
	ipnodes		text[];
	domain		text;
	domain_id	dns_domain.dns_domain_id%TYPE;
	j			text;
BEGIN
	-- silently fail for ipv6
	IF family(block) != 4 THEN
		RETURN NULL;
	END IF;
	IF family(block) != 4 THEN
		j := '';
		-- this needs to be tweaked to expand ::, which postgresql does
		-- not easily do.  This requires more thinking than I was up for today.
		ipaddr := regexp_replace(host(block)::text, ':', '', 'g');
	ELSE
		j := '\.';
		ipaddr := host(block);
	END IF;

	EXECUTE 'select array_agg(member order by rn desc)
		from (
        select
			row_number() over () as rn, *
			from
			unnest(regexp_split_to_array($1, $2)) as member
		) x
	' INTO ipnodes USING ipaddr, j;

	IF family(block) = 4 THEN
		domain := array_to_string(ARRAY[ipnodes[2],ipnodes[3],ipnodes[4]], '.')
			|| '.in-addr.arpa';
	ELSE
		domain := array_to_string(ipnodes, '.') 
			|| '.ip6.arpa';
	END IF;

	SELECT dns_domain_id INTO domain_id FROM dns_domain where soa_name = domain;
	IF NOT FOUND THEN
		-- domain_id := dns_utils.add_dns_domain(domain);
	END IF;

	RETURN domain_id;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

------------------------------------------------------------------------------
--
-- Given a netblock, add all the dns domains so in-addr lookups work,
-- including the A<>PTR association magic.
--
-- Works for both v4 and v6
--
-- This is called from the routines that add netblocks to automatically setup
-- DNS
--
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_utils.add_domains_from_netblock(
	netblock_id		netblock.netblock_id%TYPE
) returns void
AS
$$
DECLARE
	block		inet;
	domain		text;
	domain_id	dns_domain.dns_domain_id%TYPE;
BEGIN
	EXECUTE 'SELECT ip_address FROM netblock WHERE netblock_id = $1'
		INTO block
		USING netblock_id;

	FOREACH domain in ARRAY dns_utils.get_all_domains_for_cidr(block)
	LOOP
		SELECT dns_domain_id INTO domain_id 
			FROM dns_domain where soa_name = domain;

		IF NOT FOUND THEN
			domain_id := dns_utils.add_dns_domain(domain);
		END IF;
	END LOOP;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;


--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_x509_revocation_reason
CREATE TABLE val_x509_revocation_reason
(
	x509_revocation_reason	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_x509_revocation_reason', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_x509_revocation_reason ADD CONSTRAINT pk_val_x509_revocation_reason PRIMARY KEY (x509_revocation_reason);

-- Table/Column Comments
COMMENT ON TABLE val_x509_revocation_reason IS 'Reasons, based on RFC, that a certificate can be revoked.  These are typically encoded in revocation lists (CRLs, etc).';
COMMENT ON COLUMN val_x509_revocation_reason.x509_revocation_reason IS 'valid reason for revoking certificates';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_x509_revocation_reason and x509_certificate
--ALTER TABLE x509_certificate
--	ADD CONSTRAINT fk_x509_cert_revoc_reason
--	FOREIGN KEY (x509_revocation_reason) REFERENCES val_x509_revocation_reason(x509_revocation_reason);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_x509_revocation_reason');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_x509_revocation_reason');
-- DONE DEALING WITH TABLE val_x509_revocation_reason [3770398]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE x509_certificate [3552729]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'x509_certificate', 'x509_certificate');

-- FOREIGN KEYS FROM
ALTER TABLE x509_key_usage_attribute DROP CONSTRAINT IF EXISTS fk_x509_certificate;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS fk_x509_cert_cert;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS fk_x509cert_enc_id_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'x509_certificate');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS ak_x509_cert_cert_ca_ser;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS pk_x509_certificate;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS check_yes_no_293461963;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS check_yes_no_31190954;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_x509_certificate ON jazzhands.x509_certificate;
DROP TRIGGER IF EXISTS trigger_audit_x509_certificate ON jazzhands.x509_certificate;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'x509_certificate');
---- BEGIN audit.x509_certificate TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'x509_certificate', 'x509_certificate');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'x509_certificate');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."x509_certificate_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'x509_certificate');
---- DONE audit.x509_certificate TEARDOWN


ALTER TABLE x509_certificate RENAME TO x509_certificate_v62;
ALTER TABLE audit.x509_certificate RENAME TO x509_certificate_v62;


CREATE TABLE x509_certificate
(
	x509_cert_id	integer NOT NULL,
	friendly_name	varchar(255) NOT NULL,
	is_active	character(1) NOT NULL,
	is_certificate_authority	character(1) NOT NULL,
	signing_cert_id	integer  NULL,
	x509_ca_cert_serial_number	numeric  NULL,
	public_key	text NOT NULL,
	private_key	text  NULL,
	certificate_sign_req	text  NULL,
	subject	varchar(255) NOT NULL,
	subject_key_identifier	varchar(255) NOT NULL,
	valid_from	timestamp(6) without time zone NOT NULL,
	valid_to	timestamp(6) without time zone NOT NULL,
	x509_revocation_date	timestamp with time zone  NULL,
	x509_revocation_reason	varchar(50)  NULL,
	passphrase	varchar(255)  NULL,
	encryption_key_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);

SELECT schema_support.build_audit_table('audit', 'jazzhands', 'x509_certificate', false);
ALTER TABLE x509_certificate
	ALTER x509_cert_id
	SET DEFAULT nextval('x509_certificate_x509_cert_id_seq'::regclass);
ALTER TABLE x509_certificate
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE x509_certificate
	ALTER is_certificate_authority
	SET DEFAULT 'N'::bpchar;
INSERT INTO x509_certificate (
	x509_cert_id,
	friendly_name,		-- new column (friendly_name)
	is_active,		-- new column (is_active)
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
	subject,
	subject_key_identifier,		-- new column (subject_key_identifier)
	valid_from,
	valid_to,
	x509_revocation_date,		-- new column (x509_revocation_date)
	x509_revocation_reason,		-- new column (x509_revocation_reason)
	passphrase,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	x509_cert_id,
	subject,		-- new column (friendly_name)
	'Y'::bpchar,		-- new column (is_active)
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
	subject,
	subject,		-- new column (subject_key_identifier)
	valid_from,
	valid_to,
	CASE WHEN is_cert_revoked = 'Y' THEN now() ELSE NULL END, -- x509_revocation_date
	NULL,		-- new column (x509_revocation_reason)
	passphrase,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM x509_certificate_v62;

INSERT INTO audit.x509_certificate (
	x509_cert_id,
	friendly_name,		-- new column (friendly_name)
	is_active,		-- new column (is_active)
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
	subject,
	subject_key_identifier,		-- new column (subject_key_identifier)
	valid_from,
	valid_to,
	x509_revocation_date,		-- new column (x509_revocation_date)
	x509_revocation_reason,		-- new column (x509_revocation_reason)
	passphrase,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	x509_cert_id,
	subject,		-- new column (friendly_name)
	'Y',		-- new column (is_active)
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
	subject,
	subject,		-- new column (subject_key_identifier)
	valid_from,
	valid_to,
	CASE WHEN is_cert_revoked = 'Y' THEN now() ELSE NULL END, -- x509_revocation_date
	NULL,		-- new column (x509_revocation_reason)
	passphrase,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.x509_certificate_v62;

ALTER TABLE x509_certificate
	ALTER x509_cert_id
	SET DEFAULT nextval('x509_certificate_x509_cert_id_seq'::regclass);
ALTER TABLE x509_certificate
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE x509_certificate
	ALTER is_certificate_authority
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE x509_certificate ADD CONSTRAINT pk_x509_certificate PRIMARY KEY (x509_cert_id);
ALTER TABLE x509_certificate ADD CONSTRAINT ak_x509_cert_cert_ca_ser UNIQUE (signing_cert_id, x509_ca_cert_serial_number);
ALTER TABLE x509_certificate ADD CONSTRAINT ak_x509_cert_ski UNIQUE (subject_key_identifier);

-- Table/Column Comments
COMMENT ON TABLE x509_certificate IS 'X509 specification Certificate.';
COMMENT ON COLUMN x509_certificate.x509_cert_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN x509_certificate.friendly_name IS 'human readable name for certificate.  often just the CN.';
COMMENT ON COLUMN x509_certificate.is_active IS 'indicates certificate is in active use.  This is used by tools to decide how to show it; does not indicate revocation';
COMMENT ON COLUMN x509_certificate.signing_cert_id IS 'x509_cert_id for the certificate that has signed this one.';
COMMENT ON COLUMN x509_certificate.x509_ca_cert_serial_number IS 'Serial INTEGER assigned to the certificate within Certificate Authority. It uniquely identifies certificate within the realm of the CA.';
COMMENT ON COLUMN x509_certificate.public_key IS 'Textual representation of Certificate Public Key. Public Key is a component of X509 standard and is used for encryption.';
COMMENT ON COLUMN x509_certificate.private_key IS 'Textual representation of Certificate Private Key. Private Key is a component of X509 standard and is used for encryption.';
COMMENT ON COLUMN x509_certificate.subject IS 'Textual representation of a certificate subject. Certificate subject is a part of X509 certificate specifications.  This is the full subject from the certificate.  Friendly Name provides a human readable one.';
COMMENT ON COLUMN x509_certificate.subject_key_identifier IS 'colon seperate byte hex string with X509v3 SKIextension of this certificate';
COMMENT ON COLUMN x509_certificate.valid_from IS 'Timestamp indicating when the certificate becomes valid and can be used.';
COMMENT ON COLUMN x509_certificate.valid_to IS 'Timestamp indicating when the certificate becomes invalid and can''t be used.';
COMMENT ON COLUMN x509_certificate.x509_revocation_date IS 'if certificate was revoked, when it was revokeed.  reason must also be set.   NULL means not revoked';
COMMENT ON COLUMN x509_certificate.x509_revocation_reason IS 'if certificate was revoked, why iit was revokeed.  date must also be set.   NULL means not revoked';
COMMENT ON COLUMN x509_certificate.passphrase IS 'passphrase to decrypt key.  If encrypted, encryption_key_id indicates how to decrypt.';
COMMENT ON COLUMN x509_certificate.encryption_key_id IS 'if set, encryption key information for decrypting passphrase.';
-- INDEXES
CREATE INDEX xif3x509_certificate ON x509_certificate USING btree (x509_revocation_reason);

-- CHECK CONSTRAINTS
ALTER TABLE x509_certificate ADD CONSTRAINT check_yes_no_1933598984
	CHECK (is_active = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE x509_certificate ADD CONSTRAINT check_yes_no_31190954
	CHECK (is_certificate_authority = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK x509_certificate and x509_key_usage_attribute
ALTER TABLE x509_key_usage_attribute
	ADD CONSTRAINT fk_x509_certificate
	FOREIGN KEY (x509_cert_id) REFERENCES x509_certificate(x509_cert_id);

-- FOREIGN KEYS TO
-- consider FK x509_certificate and encryption_key
ALTER TABLE x509_certificate
	ADD CONSTRAINT fk_x509cert_enc_id_id
	FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id);
-- consider FK x509_certificate and val_x509_revocation_reason
ALTER TABLE x509_certificate
	ADD CONSTRAINT fk_x509_cert_revoc_reason
	FOREIGN KEY (x509_revocation_reason) REFERENCES val_x509_revocation_reason(x509_revocation_reason);
-- consider FK x509_certificate and x509_certificate
ALTER TABLE x509_certificate
	ADD CONSTRAINT fk_x509_cert_cert
	FOREIGN KEY (signing_cert_id) REFERENCES x509_certificate(x509_cert_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'x509_certificate');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'x509_certificate');
ALTER SEQUENCE x509_certificate_x509_cert_id_seq
	 OWNED BY x509_certificate.x509_cert_id;
DROP TABLE IF EXISTS x509_certificate_v62;
DROP TABLE IF EXISTS audit.x509_certificate_v62;
-- DONE DEALING WITH TABLE x509_certificate [3770504]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE component_property [3550427]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'component_property', 'component_property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.component_property DROP CONSTRAINT IF EXISTS fk_comp_prop_sltfuncid;
ALTER TABLE jazzhands.component_property DROP CONSTRAINT IF EXISTS fk_comp_prop_slt_slt_id;
ALTER TABLE jazzhands.component_property DROP CONSTRAINT IF EXISTS fk_comp_prop_comp_func;
ALTER TABLE jazzhands.component_property DROP CONSTRAINT IF EXISTS fk_comp_prop_prop_nmty;
ALTER TABLE jazzhands.component_property DROP CONSTRAINT IF EXISTS fk_comp_prop_comp_typ_id;
ALTER TABLE jazzhands.component_property DROP CONSTRAINT IF EXISTS fk_comp_prop_slt_typ_id;
ALTER TABLE jazzhands.component_property DROP CONSTRAINT IF EXISTS fk_comp_prop_cmp_id;
ALTER TABLE jazzhands.component_property DROP CONSTRAINT IF EXISTS r_680;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'component_property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.component_property DROP CONSTRAINT IF EXISTS pk_component_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif8component_property";
DROP INDEX IF EXISTS "jazzhands"."xif_comp_prop_sltfuncid";
DROP INDEX IF EXISTS "jazzhands"."xif_comp_prop_prop_nmty";
DROP INDEX IF EXISTS "jazzhands"."xif_comp_prop_cmp_id";
DROP INDEX IF EXISTS "jazzhands"."xif_comp_prop_comp_func";
DROP INDEX IF EXISTS "jazzhands"."xif_comp_prop_comp_typ_id";
DROP INDEX IF EXISTS "jazzhands"."xif_comp_prop_slt_typ_id";
DROP INDEX IF EXISTS "jazzhands"."xif_comp_prop_slt_slt_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_component_property ON jazzhands.component_property;
DROP TRIGGER IF EXISTS trigger_audit_component_property ON jazzhands.component_property;
DROP TRIGGER IF EXISTS trigger_validate_component_property ON jazzhands.component_property;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'component_property');
---- BEGIN audit.component_property TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'component_property', 'component_property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'component_property');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."component_property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'component_property');
---- DONE audit.component_property TEARDOWN


ALTER TABLE component_property RENAME TO component_property_v62;
ALTER TABLE audit.component_property RENAME TO component_property_v62;

CREATE TABLE component_property
(
	component_property_id	integer NOT NULL,
	component_function	varchar(50)  NULL,
	component_type_id	integer  NULL,
	component_id	integer  NULL,
	inter_component_connection_id	integer  NULL,
	slot_function	varchar(50)  NULL,
	slot_type_id	integer  NULL,
	slot_id	integer  NULL,
	component_property_name	varchar(50)  NULL,
	component_property_type	varchar(50)  NULL,
	property_value	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'component_property', false);
ALTER TABLE component_property
	ALTER component_property_id
	SET DEFAULT nextval('component_property_component_property_id_seq'::regclass);
INSERT INTO component_property (
	component_property_id,
	component_function,
	component_type_id,
	component_id,
	inter_component_connection_id,
	slot_function,
	slot_type_id,
	slot_id,
	component_property_name,
	component_property_type,
	property_value,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	component_property_id,
	component_function,
	component_type_id,
	component_id,
	inter_component_connection_id,
	slot_function,
	slot_type_id,
	slot_id,
	component_property_name,
	component_property_type,
	property_value,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM component_property_v62;

INSERT INTO audit.component_property (
	component_property_id,
	component_function,
	component_type_id,
	component_id,
	inter_component_connection_id,
	slot_function,
	slot_type_id,
	slot_id,
	component_property_name,
	component_property_type,
	property_value,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	component_property_id,
	component_function,
	component_type_id,
	component_id,
	inter_component_connection_id,
	slot_function,
	slot_type_id,
	slot_id,
	component_property_name,
	component_property_type,
	property_value,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.component_property_v62;

ALTER TABLE component_property
	ALTER component_property_id
	SET DEFAULT nextval('component_property_component_property_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE component_property ADD CONSTRAINT pk_component_property PRIMARY KEY (component_property_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_comp_prop_comp_func ON component_property USING btree (component_function);
CREATE INDEX xif_comp_prop_comp_typ_id ON component_property USING btree (component_type_id);
CREATE INDEX xif_comp_prop_slt_slt_id ON component_property USING btree (slot_id);
CREATE INDEX xif_comp_prop_slt_typ_id ON component_property USING btree (slot_type_id);
CREATE INDEX xif_comp_prop_sltfuncid ON component_property USING btree (slot_function);
CREATE INDEX xif8component_property ON component_property USING btree (inter_component_connection_id);
CREATE INDEX xif_comp_prop_cmp_id ON component_property USING btree (component_id);
CREATE INDEX xif_comp_prop_prop_nmty ON component_property USING btree (component_property_name, component_property_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK component_property and slot_type
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_slt_typ_id
	FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id);
-- consider FK component_property and inter_component_connection
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_int_cmp_conn_id
	FOREIGN KEY (inter_component_connection_id) REFERENCES inter_component_connection(inter_component_connection_id);
-- consider FK component_property and component
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_cmp_id
	FOREIGN KEY (component_id) REFERENCES component(component_id);
-- consider FK component_property and slot
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_slt_slt_id
	FOREIGN KEY (slot_id) REFERENCES slot(slot_id);
-- consider FK component_property and val_slot_function
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_sltfuncid
	FOREIGN KEY (slot_function) REFERENCES val_slot_function(slot_function);
-- consider FK component_property and val_component_function
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_comp_func
	FOREIGN KEY (component_function) REFERENCES val_component_function(component_function);
-- consider FK component_property and component_type
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_comp_typ_id
	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id) DEFERRABLE;
-- consider FK component_property and val_component_property
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_prop_nmty
	FOREIGN KEY (component_property_name, component_property_type) REFERENCES val_component_property(component_property_name, component_property_type);

-- TRIGGERS
CREATE CONSTRAINT TRIGGER trigger_validate_component_property AFTER INSERT OR UPDATE ON component_property DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE validate_component_property();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'component_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'component_property');
ALTER SEQUENCE component_property_component_property_id_seq
	 OWNED BY component_property.component_property_id;
DROP TABLE IF EXISTS component_property_v62;
DROP TABLE IF EXISTS audit.component_property_v62;
-- DONE DEALING WITH TABLE component_property [3768191]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_property [3552375]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property', 'val_property');

-- FOREIGN KEYS FROM
ALTER TABLE val_property_value DROP CONSTRAINT IF EXISTS fk_valproval_namtyp;
ALTER TABLE property_collection_property DROP CONSTRAINT IF EXISTS fk_prop_col_propnamtyp;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_nmtyp;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_propdttyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_pv_actyp_rst;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_proptyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_nblk_coll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS r_683;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS pk_val_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1val_property";
DROP INDEX IF EXISTS "jazzhands"."xif5val_property";
DROP INDEX IF EXISTS "jazzhands"."xif2val_property";
DROP INDEX IF EXISTS "jazzhands"."xif3val_property";
DROP INDEX IF EXISTS "jazzhands"."xif4val_property";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_cmp_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_354296970;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1279736503;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdevcol_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2016888554;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pacct_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_271462566;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_606225804;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_ismulti;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2139007167;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1279736247;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdnsdomid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_prodstate;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pucls_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_osid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1804972034;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_sitec;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_val_property ON jazzhands.val_property;
DROP TRIGGER IF EXISTS trig_userlog_val_property ON jazzhands.val_property;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_property');
---- BEGIN audit.val_property TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_property', 'val_property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_property');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_property');
---- DONE audit.val_property TEARDOWN


ALTER TABLE val_property RENAME TO val_property_v62;
ALTER TABLE audit.val_property RENAME TO val_property_v62;

CREATE TABLE val_property
(
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	is_multivalue	character(1) NOT NULL,
	prop_val_acct_coll_type_rstrct	varchar(50)  NULL,
	prop_val_dev_coll_type_rstrct	varchar(50)  NULL,
	prop_val_nblk_coll_type_rstrct	varchar(50)  NULL,
	property_data_type	varchar(50) NOT NULL,
	permit_account_collection_id	character(10) NOT NULL,
	permit_account_id	character(10) NOT NULL,
	permit_account_realm_id	character(10) NOT NULL,
	permit_company_id	character(10) NOT NULL,
	permit_device_collection_id	character(10) NOT NULL,
	permit_dns_domain_id	character(10) NOT NULL,
	permit_layer2_network_id	character(10) NOT NULL,
	permit_layer3_network_id	character(10) NOT NULL,
	permit_netblock_collection_id	character(10) NOT NULL,
	permit_operating_system_id	character(10) NOT NULL,
	permit_os_snapshot_id	character(10) NOT NULL,
	permit_person_id	character(10) NOT NULL,
	permit_property_collection_id	character(10) NOT NULL,
	permit_service_env_collection	character(10) NOT NULL,
	permit_site_code	character(10) NOT NULL,
	permit_property_rank	character(10) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_property', false);
ALTER TABLE val_property
	ALTER is_multivalue
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_realm_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_company_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_operating_system_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_os_snapshot_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_person_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_service_env_collection
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;
INSERT INTO val_property (
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_layer2_network_id,
	permit_layer3_network_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_layer2_network_id,
	permit_layer3_network_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_property_v62;

INSERT INTO audit.val_property (
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_layer2_network_id,
	permit_layer3_network_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_layer2_network_id,
	permit_layer3_network_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_property_v62;

ALTER TABLE val_property
	ALTER is_multivalue
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_realm_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_company_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_operating_system_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_os_snapshot_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_person_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_service_env_collection
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_property ADD CONSTRAINT pk_val_property PRIMARY KEY (property_name, property_type);

-- Table/Column Comments
COMMENT ON TABLE val_property IS 'valid values and attributes for (name,type) pairs in the property table.  This defines how triggers enforce aspects of the property table';
COMMENT ON COLUMN val_property.property_name IS 'property name for validation purposes';
COMMENT ON COLUMN val_property.property_type IS 'property type for validation purposes';
COMMENT ON COLUMN val_property.is_multivalue IS 'If N, acts like an alternate key on property.(lhs,property_name,property_type)';
COMMENT ON COLUMN val_property.prop_val_acct_coll_type_rstrct IS 'if property_value is account_collection_Id, this limits the account_collection_types that can be used in that column.';
COMMENT ON COLUMN val_property.prop_val_dev_coll_type_rstrct IS 'if property_value is devicet_collection_Id, this limits the devicet_collection_types that can be used in that column.';
COMMENT ON COLUMN val_property.prop_val_nblk_coll_type_rstrct IS 'if property_value isnetblockt_collection_Id, this limits the netblockt_collection_types that can be used in that column.';
COMMENT ON COLUMN val_property.property_data_type IS 'which, if any, of the property_table_* columns should be used for this value.   May turn more complex enforcement via trigger';
COMMENT ON COLUMN val_property.permit_account_collection_id IS 'defines permissibility/requirement of account_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_account_id IS 'defines permissibility/requirement of account_idon LHS of property';
COMMENT ON COLUMN val_property.permit_account_realm_id IS 'defines permissibility/requirement of account_realm_id on LHS of property';
COMMENT ON COLUMN val_property.permit_company_id IS 'defines permissibility/requirement of company_id on LHS of property';
COMMENT ON COLUMN val_property.permit_device_collection_id IS 'defines permissibility/requirement of device_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_dns_domain_id IS 'defines permissibility/requirement of dns_domain_id on LHS of property';
COMMENT ON COLUMN val_property.permit_layer2_network_id IS 'defines permissibility/requirement of layer2_network_id on LHS of property';
COMMENT ON COLUMN val_property.permit_layer3_network_id IS 'defines permissibility/requirement of layer3_network_id on LHS of property';
COMMENT ON COLUMN val_property.permit_netblock_collection_id IS 'defines permissibility/requirement of netblock_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_operating_system_id IS 'defines permissibility/requirement of operating_system_id on LHS of property';
COMMENT ON COLUMN val_property.permit_os_snapshot_id IS 'defines permissibility/requirement of operating_system_snapshot_id on LHS of property';
COMMENT ON COLUMN val_property.permit_person_id IS 'defines permissibility/requirement of person_id on LHS of property';
COMMENT ON COLUMN val_property.permit_property_collection_id IS 'defines permissibility/requirement of property_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_service_env_collection IS 'defines permissibility/requirement of service_env_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_site_code IS 'defines permissibility/requirement of site_code on LHS of property';
COMMENT ON COLUMN val_property.permit_property_rank IS 'defines permissibility of property_rank, and if it should be part of the "lhs" of the given property';
-- INDEXES
CREATE INDEX xif5val_property ON val_property USING btree (prop_val_dev_coll_type_rstrct);
CREATE INDEX xif2val_property ON val_property USING btree (property_type);
CREATE INDEX xif1val_property ON val_property USING btree (property_data_type);
CREATE INDEX xif4val_property ON val_property USING btree (prop_val_nblk_coll_type_rstrct);
CREATE INDEX xif3val_property ON val_property USING btree (prop_val_acct_coll_type_rstrct);

-- CHECK CONSTRAINTS
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_271462566
	CHECK (permit_property_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pacct_id
	CHECK (permit_account_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2016888554
	CHECK (permit_account_realm_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1279736503
	CHECK (permit_layer2_network_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdevcol_id
	CHECK (permit_device_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_354296970
	CHECK (permit_netblock_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_cmp_id
	CHECK (permit_company_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_ismulti
	CHECK (is_multivalue = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_606225804
	CHECK (permit_person_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdnsdomid
	CHECK (permit_dns_domain_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1279736247
	CHECK (permit_layer3_network_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2139007167
	CHECK (permit_property_rank = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_sitec
	CHECK (permit_site_code = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1804972034
	CHECK (permit_os_snapshot_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_osid
	CHECK (permit_operating_system_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pucls_id
	CHECK (permit_account_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_prodstate
	CHECK (permit_service_env_collection = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_property and val_property_value
ALTER TABLE val_property_value
	ADD CONSTRAINT fk_valproval_namtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK val_property and property_collection_property
ALTER TABLE property_collection_property
	ADD CONSTRAINT fk_prop_col_propnamtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK val_property and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);

-- FOREIGN KEYS TO
-- consider FK val_property and val_device_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_val_devcol_typ_rstr_dc
	FOREIGN KEY (prop_val_dev_coll_type_rstrct) REFERENCES val_device_collection_type(device_collection_type);
-- consider FK val_property and val_property_data_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_propdttyp
	FOREIGN KEY (property_data_type) REFERENCES val_property_data_type(property_data_type);
-- consider FK val_property and val_account_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_pv_actyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_property and val_property_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_proptyp
	FOREIGN KEY (property_type) REFERENCES val_property_type(property_type);
-- consider FK val_property and val_netblock_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_nblk_coll_type
	FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_property');
DROP TABLE IF EXISTS val_property_v62;
DROP TABLE IF EXISTS audit.val_property_v62;
-- DONE DEALING WITH TABLE val_property [3770140]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dns_changes_pending
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_changes_pending', 'v_dns_changes_pending');
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_changes_pending', 'v_dns_changes_pending');
DROP VIEW IF EXISTS v_dns_changes_pending;
CREATE VIEW v_dns_changes_pending AS
 WITH chg AS (
         SELECT dns_change_record.dns_change_record_id,
            dns_change_record.dns_domain_id,
                CASE
                    WHEN family(dns_change_record.ip_address) = 4 THEN set_masklen(dns_change_record.ip_address, 24)
                    ELSE set_masklen(dns_change_record.ip_address, 64)
                END AS ip_address,
            dns_utils.get_domain_from_cidr(dns_change_record.ip_address) AS cidrdns
           FROM dns_change_record
          WHERE dns_change_record.ip_address IS NOT NULL
        )
 SELECT DISTINCT x.dns_change_record_id,
    x.dns_domain_id,
    x.should_generate,
    x.last_generated,
    x.soa_name,
    x.ip_address
   FROM ( SELECT chg.dns_change_record_id,
            n.dns_domain_id,
            n.should_generate,
            n.last_generated,
            n.soa_name,
            chg.ip_address
           FROM chg
             JOIN dns_domain n ON chg.cidrdns = n.soa_name::text
        UNION
         SELECT chg.dns_change_record_id,
            d.dns_domain_id,
            d.should_generate,
            d.last_generated,
            d.soa_name,
            NULL::inet
           FROM dns_change_record chg
             JOIN dns_domain d USING (dns_domain_id)
          WHERE chg.dns_domain_id IS NOT NULL) x;

delete from __recreate where type = 'view' and object = 'v_dns_changes_pending';
-- DONE DEALING WITH TABLE v_dns_changes_pending [3775929]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc net_manip.expand_ipv6_address -> expand_ipv6_address 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 3775716
CREATE OR REPLACE FUNCTION net_manip.expand_ipv6_address(ip inet)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
	parts	text[];
	proc	text[];
	elem	text;
	zero	text;
	tally	integer;
	rv		text;
BEGIN
	IF family(ip) != 6 THEN
		RAISE EXCEPTION 'net_manip.expand_ipv6_address only works on IPv6 addresses'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	-- end up with an array for each element, with an empty block being a
	-- spot that should be zero filled.  Due to regexp matching, a :: at the
	-- end will leave extra empty blocks at the end.
	-- This basically makes it so the empty array element needs to be zero
	-- expanded.
	parts := regexp_split_to_array(
		regexp_replace(
			regexp_replace(ip::text, '::/\d+$', ':'),
				'^:?([a-f0-9:]*):?(/\d+)?$', E'\\1', 'i'), ':'
		);

	--
	-- go through elements and zero fill them.
	tally := 0;
	FOREACH elem in ARRAY parts
	LOOP
		IF char_length(elem) > 0 THEN
			proc = proc || lpad(elem, 4, '0');
			tally := tally + 1;
		ELSE
			proc = proc || elem;
		END IF;
	END LOOP;

	-- figure out how big the zero expansion needs to be for later placement
	zero := '';
	tally := 8 - tally;
	WHILE tally > 0
	LOOP
		zero := zero || ':' || lpad('', 4, '0');
		tally := tally - 1;
	END LOOP;
	zero := regexp_replace(zero, '^:', '');

	--
	-- to through all the elements and find the empty one that should be
	-- zero filled
	parts := ARRAY[]::text[];
	FOREACH elem in ARRAY proc
	LOOP
		IF char_length(elem) > 0 THEN
			parts := parts || elem;
		ELSE
			parts := parts || zero;
		END IF;
	END LOOP;
	rv := array_to_string(parts, ':');
	RETURN rv;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc net_manip.expand_ipv6_address -> expand_ipv6_address 
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE logical_volume [3777165]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'logical_volume', 'logical_volume');

-- FOREIGN KEYS FROM
-- Skipping this FK since table been dropped
ALTER TABLE physicalish_volume DROP CONSTRAINT IF EXISTS fk_physvol_lvid;

-- Skipping this FK since table been dropped
ALTER TABLE logical_volume_property DROP CONSTRAINT IF EXISTS fk_lvol_prop_lvid_fstyp;

-- Skipping this FK since table been dropped
ALTER TABLE logical_volume_purpose DROP CONSTRAINT IF EXISTS fk_lvpurp_lvid;


-- FOREIGN KEYS TO
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_fstype;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_vgid;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_device_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'logical_volume');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS ak_logvol_devid_lvname;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS ak_logical_volume_filesystem;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS pk_logical_volume;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS ak_logvol_lv_devid;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_logvol_fstype";
DROP INDEX IF EXISTS "jazzhands"."xif_logvol_vgid";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_logical_volume ON jazzhands.logical_volume;
DROP TRIGGER IF EXISTS trig_userlog_logical_volume ON jazzhands.logical_volume;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'logical_volume');
---- BEGIN audit.logical_volume TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'logical_volume', 'logical_volume');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'logical_volume');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."logical_volume_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'logical_volume');
---- DONE audit.logical_volume TEARDOWN


ALTER TABLE logical_volume RENAME TO logical_volume_v62;
ALTER TABLE audit.logical_volume RENAME TO logical_volume_v62;

CREATE TABLE logical_volume
(
	logical_volume_id	integer NOT NULL,
	volume_group_id	integer NOT NULL,
	device_id	integer  NULL,
	logical_volume_name	varchar(50) NOT NULL,
	logical_volume_size_in_bytes	bigint NOT NULL,
	logical_volume_offset_in_bytes	bigint  NULL,
	filesystem_type	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'logical_volume', false);
ALTER TABLE logical_volume
	ALTER logical_volume_id
	SET DEFAULT nextval('logical_volume_logical_volume_id_seq'::regclass);
INSERT INTO logical_volume (
	logical_volume_id,
	volume_group_id,
	device_id,
	logical_volume_name,
	logical_volume_size_in_bytes,
	logical_volume_offset_in_bytes,
	filesystem_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	logical_volume_id,
	volume_group_id,
	device_id,
	logical_volume_name,
	logical_volume_size_in_bytes,
	logical_volume_offset_in_bytes,
	filesystem_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM logical_volume_v62;

INSERT INTO audit.logical_volume (
	logical_volume_id,
	volume_group_id,
	device_id,
	logical_volume_name,
	logical_volume_size_in_bytes,
	logical_volume_offset_in_bytes,
	filesystem_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	logical_volume_id,
	volume_group_id,
	device_id,
	logical_volume_name,
	logical_volume_size_in_bytes,
	logical_volume_offset_in_bytes,
	filesystem_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.logical_volume_v62;

ALTER TABLE logical_volume
	ALTER logical_volume_id
	SET DEFAULT nextval('logical_volume_logical_volume_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE logical_volume ADD CONSTRAINT ak_logical_volume_filesystem UNIQUE (logical_volume_id, filesystem_type);
ALTER TABLE logical_volume ADD CONSTRAINT ak_logvol_devid_lvname UNIQUE (device_id, logical_volume_name, filesystem_type);
ALTER TABLE logical_volume ADD CONSTRAINT ak_logvol_lv_devid UNIQUE (logical_volume_id);
ALTER TABLE logical_volume ADD CONSTRAINT pk_logical_volume PRIMARY KEY (logical_volume_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_logvol_fstype ON logical_volume USING btree (filesystem_type);
CREATE INDEX xif_logvol_vgid ON logical_volume USING btree (volume_group_id, device_id);
DROP INDEX IF EXISTS xif_logvol_device_id;
CREATE INDEX xif_logvol_device_id ON logical_volume USING btree (device_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK logical_volume and logical_volume_purpose
-- Skipping this FK since table does not exist yet
--ALTER TABLE logical_volume_purpose
--	ADD CONSTRAINT fk_lvpurp_lvid
--	FOREIGN KEY (logical_volume_id) REFERENCES logical_volume(logical_volume_id);

-- consider FK logical_volume and logical_volume_property
-- Skipping this FK since table does not exist yet
--ALTER TABLE logical_volume_property
--	ADD CONSTRAINT fk_lvol_prop_lvid_fstyp
--	FOREIGN KEY (logical_volume_id, filesystem_type) REFERENCES logical_volume(logical_volume_id, filesystem_type);

-- consider FK logical_volume and physicalish_volume
-- Skipping this FK since table does not exist yet
--ALTER TABLE physicalish_volume
--	ADD CONSTRAINT fk_physvol_lvid
--	FOREIGN KEY (logical_volume_id) REFERENCES logical_volume(logical_volume_id);


-- FOREIGN KEYS TO
-- consider FK logical_volume and device
-- Skipping this FK since table does not exist yet
--ALTER TABLE logical_volume
--	ADD CONSTRAINT fk_logvol_device_id
--	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- consider FK logical_volume and volume_group
-- Skipping this FK since table does not exist yet
--ALTER TABLE logical_volume
--	ADD CONSTRAINT fk_logvol_vgid
--	FOREIGN KEY (volume_group_id, device_id) REFERENCES volume_group(volume_group_id, device_id);

-- consider FK logical_volume and val_filesystem_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE logical_volume
--	ADD CONSTRAINT fk_logvol_fstype
--	FOREIGN KEY (filesystem_type) REFERENCES val_filesystem_type(filesystem_type);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'logical_volume');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'logical_volume');
ALTER SEQUENCE logical_volume_logical_volume_id_seq
	 OWNED BY logical_volume.logical_volume_id;
GRANT SELECT ON logical_volume TO ro_role;
GRANT ALL ON logical_volume TO jazzhands;
GRANT INSERT,UPDATE,DELETE ON logical_volume TO iud_role;
DROP TABLE IF EXISTS logical_volume_v62;
DROP TABLE IF EXISTS audit.logical_volume_v62;
-- DONE DEALING WITH TABLE logical_volume [3768741]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE volume_group_physicalish_vol [3778889]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'volume_group_physicalish_vol', 'volume_group_physicalish_vol');

-- FOREIGN KEYS FROM
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS fk_volgrp_vg_devid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_volgrp_vg_devid;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_volgrp_vg_devid;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vgp_phy_vgrpid_devid;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_physvol_vg_phsvol_dvid;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vgp_phy_vgrpid;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vgp_phy_phyid;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vg_physvol_vgrel;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'volume_group_physicalish_vol');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS ak_volume_group_vg_devid;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS ak_volgrp_pv_position;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS pk_volume_group_physicalish_vo;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_vgp_phy_vgrpid";
DROP INDEX IF EXISTS "jazzhands"."xif_vg_physvol_vgrel";
DROP INDEX IF EXISTS "jazzhands"."xif_physvol_vg_phsvol_dvid";
DROP INDEX IF EXISTS "jazzhands"."xif_vgp_phy_phyid";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_volume_group_physicalish_vol ON jazzhands.volume_group_physicalish_vol;
DROP TRIGGER IF EXISTS trigger_audit_volume_group_physicalish_vol ON jazzhands.volume_group_physicalish_vol;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'volume_group_physicalish_vol');
---- BEGIN audit.volume_group_physicalish_vol TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'volume_group_physicalish_vol', 'volume_group_physicalish_vol');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'volume_group_physicalish_vol');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."volume_group_physicalish_vol_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'volume_group_physicalish_vol');
---- DONE audit.volume_group_physicalish_vol TEARDOWN


ALTER TABLE volume_group_physicalish_vol RENAME TO volume_group_physicalish_vol_v62;
ALTER TABLE audit.volume_group_physicalish_vol RENAME TO volume_group_physicalish_vol_v62;

CREATE TABLE volume_group_physicalish_vol
(
	physicalish_volume_id	integer NOT NULL,
	volume_group_id	integer NOT NULL,
	device_id	integer  NULL,
	volume_group_position	integer NOT NULL,
	volume_group_relation	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'volume_group_physicalish_vol', false);
INSERT INTO volume_group_physicalish_vol (
	physicalish_volume_id,
	volume_group_id,
	device_id,
	volume_group_position,
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	physicalish_volume_id,
	volume_group_id,
	device_id,
	volume_group_position,
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM volume_group_physicalish_vol_v62;

INSERT INTO audit.volume_group_physicalish_vol (
	physicalish_volume_id,
	volume_group_id,
	device_id,
	volume_group_position,
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	physicalish_volume_id,
	volume_group_id,
	device_id,
	volume_group_position,
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.volume_group_physicalish_vol_v62;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE volume_group_physicalish_vol ADD CONSTRAINT ak_volgrp_pv_position UNIQUE (volume_group_id, volume_group_position);
ALTER TABLE volume_group_physicalish_vol ADD CONSTRAINT pk_volume_group_physicalish_vo PRIMARY KEY (physicalish_volume_id, volume_group_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_vgp_phy_vgrpid ON volume_group_physicalish_vol USING btree (volume_group_id);
DROP INDEX IF EXISTS xif_vgp_phy_vgrpid_devid;
CREATE INDEX xif_vgp_phy_vgrpid_devid ON volume_group_physicalish_vol USING btree (device_id, volume_group_id);
CREATE INDEX xif_vgp_phy_phyid ON volume_group_physicalish_vol USING btree (physicalish_volume_id);
CREATE INDEX xif_physvol_vg_phsvol_dvid ON volume_group_physicalish_vol USING btree (physicalish_volume_id, device_id);
CREATE INDEX xif_vg_physvol_vgrel ON volume_group_physicalish_vol USING btree (volume_group_relation);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK volume_group_physicalish_vol and volume_group
-- Skipping this FK since table does not exist yet
--ALTER TABLE volume_group_physicalish_vol
--	ADD CONSTRAINT fk_vgp_phy_vgrpid
--	FOREIGN KEY (volume_group_id) REFERENCES volume_group(volume_group_id);

-- consider FK volume_group_physicalish_vol and physicalish_volume
-- Skipping this FK since table does not exist yet
--ALTER TABLE volume_group_physicalish_vol
--	ADD CONSTRAINT fk_vgp_phy_phyid
--	FOREIGN KEY (physicalish_volume_id) REFERENCES physicalish_volume(physicalish_volume_id);

-- consider FK volume_group_physicalish_vol and val_volume_group_relation
-- Skipping this FK since table does not exist yet
--ALTER TABLE volume_group_physicalish_vol
--	ADD CONSTRAINT fk_vg_physvol_vgrel
--	FOREIGN KEY (volume_group_relation) REFERENCES val_volume_group_relation(volume_group_relation);

-- consider FK volume_group_physicalish_vol and volume_group
-- Skipping this FK since table does not exist yet
--ALTER TABLE volume_group_physicalish_vol
--	ADD CONSTRAINT fk_vgp_phy_vgrpid_devid
--	FOREIGN KEY (volume_group_id, device_id) REFERENCES volume_group(volume_group_id, device_id);

-- consider FK volume_group_physicalish_vol and physicalish_volume
-- Skipping this FK since table does not exist yet
--ALTER TABLE volume_group_physicalish_vol
--	ADD CONSTRAINT fk_physvol_vg_phsvol_dvid
--	FOREIGN KEY (physicalish_volume_id, device_id) REFERENCES physicalish_volume(physicalish_volume_id, device_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'volume_group_physicalish_vol');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'volume_group_physicalish_vol');
GRANT SELECT ON volume_group_physicalish_vol TO ro_role;
GRANT ALL ON volume_group_physicalish_vol TO jazzhands;
GRANT INSERT,UPDATE,DELETE ON volume_group_physicalish_vol TO iud_role;
DROP TABLE IF EXISTS volume_group_physicalish_vol_v62;
DROP TABLE IF EXISTS audit.volume_group_physicalish_vol_v62;
-- DONE DEALING WITH TABLE volume_group_physicalish_vol [3770477]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc component_utils.create_component_template_slots -> create_component_template_slots 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('component_utils', 'create_component_template_slots', 'create_component_template_slots');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
-- consider old oid 3784390
DROP FUNCTION IF EXISTS component_utils.create_component_template_slots(component_id integer);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 3776015
CREATE OR REPLACE FUNCTION component_utils.create_component_template_slots(component_id integer)
 RETURNS SETOF slot
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	ctid	jazzhands.component_type.component_type_id%TYPE;
	s		jazzhands.slot%ROWTYPE;
	cid 	ALIAS FOR component_id;
BEGIN
	FOR s IN
		INSERT INTO jazzhands.slot (
			component_id,
			slot_name,
			slot_type_id,
			slot_index,
			component_type_slot_tmplt_id,
			physical_label,
			slot_x_offset,
			slot_y_offset,
			slot_z_offset,
			slot_side
		) SELECT
			cid,
			ctst.slot_name_template,
			ctst.slot_type_id,
			ctst.slot_index,
			ctst.component_type_slot_tmplt_id,
			ctst.physical_label,
			ctst.slot_x_offset,
			ctst.slot_y_offset,
			ctst.slot_z_offset,
			ctst.slot_side
		FROM
			component_type_slot_tmplt ctst JOIN
			component c USING (component_type_id)
		WHERE
			c.component_id = cid AND
			ctst.component_type_slot_tmplt_id NOT IN (
				SELECT component_type_slot_tmplt_id FROM slot WHERE
					slot.component_id = cid
				)
		ORDER BY ctst.component_type_slot_tmplt_id
		RETURNING *
	LOOP
		RAISE DEBUG 'Creating slot for component % from template %',
			cid, s.component_type_slot_tmplt_id;
		RETURN NEXT s;
	END LOOP;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc component_utils.create_component_template_slots -> create_component_template_slots 
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE layer1_connection [3793156]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'layer1_connection', 'layer1_connection');
CREATE VIEW layer1_connection AS
 WITH conn_props AS (
         SELECT component_property.inter_component_connection_id,
            component_property.component_property_name,
            component_property.component_property_type,
            component_property.property_value
           FROM component_property
          WHERE component_property.component_property_type::text = 'serial-connection'::text
        ), tcpsrv_device_id AS (
         SELECT component_property.inter_component_connection_id,
            device.device_id
           FROM component_property
             JOIN device USING (component_id)
          WHERE component_property.component_property_type::text = 'tcpsrv-connections'::text AND component_property.component_property_name::text = 'tcpsrv_device_id'::text
        ), tcpsrv_enabled AS (
         SELECT component_property.inter_component_connection_id,
            component_property.property_value
           FROM component_property
          WHERE component_property.component_property_type::text = 'tcpsrv-connections'::text AND component_property.component_property_name::text = 'tcpsrv_enabled'::text
        )
 SELECT icc.inter_component_connection_id AS layer1_connection_id,
    icc.slot1_id AS physical_port1_id,
    icc.slot2_id AS physical_port2_id,
    icc.circuit_id,
    baud.property_value::integer AS baud,
    dbits.property_value::integer AS data_bits,
    sbits.property_value::integer AS stop_bits,
    parity.property_value AS parity,
    flow.property_value AS flow_control,
    tcpsrv.device_id AS tcpsrv_device_id,
    COALESCE(tcpsrvon.property_value, 'N'::character varying)::character(1) AS is_tcpsrv_enabled,
    icc.data_ins_user,
    icc.data_ins_date,
    icc.data_upd_user,
    icc.data_upd_date
   FROM inter_component_connection icc
     JOIN slot s1 ON icc.slot1_id = s1.slot_id
     JOIN slot_type st1 ON st1.slot_type_id = s1.slot_type_id
     JOIN slot s2 ON icc.slot2_id = s2.slot_id
     JOIN slot_type st2 ON st2.slot_type_id = s2.slot_type_id
     LEFT JOIN tcpsrv_device_id tcpsrv USING (inter_component_connection_id)
     LEFT JOIN tcpsrv_enabled tcpsrvon USING (inter_component_connection_id)
     LEFT JOIN conn_props baud ON baud.inter_component_connection_id = icc.inter_component_connection_id AND baud.component_property_name::text = 'baud'::text
     LEFT JOIN conn_props dbits ON dbits.inter_component_connection_id = icc.inter_component_connection_id AND dbits.component_property_name::text = 'data-bits'::text
     LEFT JOIN conn_props sbits ON sbits.inter_component_connection_id = icc.inter_component_connection_id AND sbits.component_property_name::text = 'stop-bits'::text
     LEFT JOIN conn_props parity ON parity.inter_component_connection_id = icc.inter_component_connection_id AND parity.component_property_name::text = 'parity'::text
     LEFT JOIN conn_props flow ON flow.inter_component_connection_id = icc.inter_component_connection_id AND flow.component_property_name::text = 'flow-control'::text
  WHERE (st1.slot_function::text = ANY (ARRAY['network'::character varying, 'serial'::character varying, 'patchpanel'::character varying]::text[])) OR (st1.slot_function::text = ANY (ARRAY['network'::character varying, 'serial'::character varying, 'patchpanel'::character varying]::text[]));

delete from __recreate where type = 'view' and object = 'layer1_connection';
-- DONE DEALING WITH TABLE layer1_connection [3775776]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc do_layer1_connection_trigger -> do_layer1_connection_trigger 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'do_layer1_connection_trigger', 'do_layer1_connection_trigger');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
DROP TRIGGER IF EXISTS trigger_layer1_connection_insteadof ON jazzhands.layer1_connection;
-- consider old oid 3784567
DROP FUNCTION IF EXISTS do_layer1_connection_trigger();

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 3776188
CREATE OR REPLACE FUNCTION jazzhands.do_layer1_connection_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF TG_OP = 'INSERT' THEN
		INSERT INTO inter_component_connection (
			slot1_id,
			slot2_id,
			circuit_id
		) VALUES (
			NEW.physical_port1_id,
			NEW.physical_port2_id,
			NEW.circuit_id
		) RETURNING inter_component_connection_id INTO NEW.layer1_connection_id;
		RETURN NEW;
	ELSIF TG_OP = 'UPDATE' THEN
		IF (NEW.layer1_connection_id IS DISTINCT FROM
				OLD.layer1_connection_id) OR
			(NEW.physical_port1_id IS DISTINCT FROM OLD.physical_port1_id) OR
			(NEW.physical_port2_id IS DISTINCT FROM OLD.physical_port2_id) OR
			(NEW.circuit_id IS DISTINCT FROM OLD.circuit_id)
		THEN
			UPDATE inter_component_connection
			SET
				inter_component_connection_id = NEW.layer1_connection_id,
				slot1_id = NEW.physical_port1_id,
				slot2_id = NEW.physical_port2_id,
				circuit_id = NEW.circuit_id
			WHERE
				inter_component_connection_id = OLD.layer1_connection_id;
		END IF;
		RETURN NEW;
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM inter_component_connection WHERE
			inter_component_connection_id = OLD.layer1_connection_id;
		RETURN OLD;
	END IF;
END; $function$
;
-- triggers on this function (if applicable)
CREATE TRIGGER trigger_layer1_connection_insteadof INSTEAD OF INSERT OR DELETE OR UPDATE ON layer1_connection FOR EACH ROW EXECUTE PROCEDURE do_layer1_connection_trigger();

-- DONE WITH proc do_layer1_connection_trigger -> do_layer1_connection_trigger 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc person_manip.pick_login -> pick_login 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('person_manip', 'pick_login', 'pick_login');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
-- consider old oid 3784313
DROP FUNCTION IF EXISTS person_manip.pick_login(in_account_realm_id integer, in_first_name character varying, in_middle_name character varying, in_last_name character varying);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 3775944
CREATE OR REPLACE FUNCTION person_manip.pick_login(in_account_realm_id integer, in_first_name character varying DEFAULT NULL::character varying, in_middle_name character varying DEFAULT NULL::character varying, in_last_name character varying DEFAULT NULL::character varying)
 RETURNS character varying
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_acctrealmid	integer;
	_login			varchar;
	_trylogin		varchar;
    id				account.account_id%TYPE;
	fn		text;
	ln		text;
BEGIN
	-- remove special characters
	fn = regexp_replace(lower(in_first_name), '[^a-z]', '', 'g');
	ln = regexp_replace(lower(in_last_name), '[^a-z]', '', 'g');
	_acctrealmid := in_account_realm_id;
	-- Try first initial, last name
	_login = lpad(lower(fn), 1) || lower(ln);
	SELECT account_id into id FROM account where account_realm_id = _acctrealmid
		AND login = _login;

	IF id IS NULL THEN
		RETURN _login;
	END IF;

	-- Try first initial, middle initial, last name
	if in_middle_name IS NOT NULL THEN
		_login = lpad(lower(fn), 1) || lpad(lower(in_middle_name), 1) || lower(ln);
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _login;
		IF id IS NULL THEN
			RETURN _login;
		END IF;
	END IF;

	-- if length of first+last is <= 10 then try that.
	_login = lower(fn) || lower(ln);
	IF char_length(_login) < 10 THEN
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _login;
		IF id IS NULL THEN
			RETURN _login;
		END IF;
	END IF;

	-- ok, keep trying to add a number to first initial, last
	_login = lpad(lower(fn), 1) || lower(ln);
	FOR i in 1..500 LOOP
		_trylogin := _login || i;
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _trylogin;
		IF id IS NULL THEN
			RETURN _trylogin;
		END IF;
	END LOOP;

	-- wtf. this should never happen
	RETURN NULL;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc person_manip.pick_login -> pick_login 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc port_utils.setup_device_power -> setup_device_power 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('port_utils', 'setup_device_power', 'setup_device_power');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
-- consider old oid 3784347
DROP FUNCTION IF EXISTS port_utils.setup_device_power(in_device_id integer);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 3775972
CREATE OR REPLACE FUNCTION port_utils.setup_device_power(in_device_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	dt_id	device.device_type_id%type;
BEGIN
	return;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc port_utils.setup_device_power -> setup_device_power 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE department [3829623]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'department', 'department');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_badge_type;
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_usr_col_id;
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_company;
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_mgr_acct_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'department');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS pk_deptid;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif6department";
DROP INDEX IF EXISTS "jazzhands"."idx_dept_deptcode_companyid";
DROP INDEX IF EXISTS "jazzhands"."xifdept_badge_type";
DROP INDEX IF EXISTS "jazzhands"."xifdept_company";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS ckc_is_active_dept;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_department ON jazzhands.department;
DROP TRIGGER IF EXISTS trig_userlog_department ON jazzhands.department;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'department');
---- BEGIN audit.department TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'department', 'department');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'department');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."department_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'department');
---- DONE audit.department TEARDOWN


ALTER TABLE department RENAME TO department_v62;
ALTER TABLE audit.department RENAME TO department_v62;

CREATE TABLE department
(
	account_collection_id	integer NOT NULL,
	company_id	integer NOT NULL,
	manager_account_id	integer  NULL,
	is_active	character(1) NOT NULL,
	dept_code	varchar(30)  NULL,
	cost_center	varchar(10)  NULL,
	default_badge_type_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'department', false);
ALTER TABLE department
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
INSERT INTO department (
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center,
	default_badge_type_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center,
	default_badge_type_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM department_v62;

INSERT INTO audit.department (
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center,
	default_badge_type_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center,
	default_badge_type_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.department_v62;

ALTER TABLE department
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE department ADD CONSTRAINT pk_deptid PRIMARY KEY (account_collection_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX idx_dept_deptcode_companyid ON department USING btree (dept_code, company_id);
CREATE INDEX xif6department ON department USING btree (manager_account_id);
CREATE INDEX xifdept_company ON department USING btree (company_id);
CREATE INDEX xifdept_badge_type ON department USING btree (default_badge_type_id);

-- CHECK CONSTRAINTS
ALTER TABLE department ADD CONSTRAINT ckc_is_active_dept
	CHECK ((is_active = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_active)::text = upper((is_active)::text)));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK department and account_collection
ALTER TABLE department
	ADD CONSTRAINT fk_dept_usr_col_id
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK department and company
ALTER TABLE department
	ADD CONSTRAINT fk_dept_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK department and badge_type
ALTER TABLE department
	ADD CONSTRAINT fk_dept_badge_type
	FOREIGN KEY (default_badge_type_id) REFERENCES badge_type(badge_type_id);
-- consider FK department and account
ALTER TABLE department
	ADD CONSTRAINT fk_dept_mgr_acct_id
	FOREIGN KEY (manager_account_id) REFERENCES account(account_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'department');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'department');
DROP TABLE IF EXISTS department_v62;
DROP TABLE IF EXISTS audit.department_v62;
-- DONE DEALING WITH TABLE department [3830202]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc device_utils.retire_device -> retire_device 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 3845442
CREATE OR REPLACE FUNCTION device_utils.retire_device(in_device_id integer, retire_modules boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally		INTEGER;
	_r			RECORD;
	_d			DEVICE%ROWTYPE;
	_mgrid		DEVICE.DEVICE_ID%TYPE;
	_purgedev	boolean;
BEGIN
	_purgedev := false;

	BEGIN
		PERFORM local_hooks.device_retire_early(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT * INTO _d FROM device WHERE device_id = in_Device_id;
	delete from dns_record where netblock_id in (
		select netblock_id 
		from network_interface where device_id = in_Device_id
	);

	delete from network_interface_purpose where device_id = in_Device_id;
	delete from network_interface where device_id = in_Device_id;

	PERFORM device_utils.purge_physical_ports( in_Device_id);
--	PERFORM device_utils.purge_power_ports( in_Device_id);

	delete from property where device_collection_id in (
		SELECT	dc.device_collection_id 
		  FROM	device_collection dc
				INNER JOIN device_collection_device dcd
		 			USING (device_collection_id)
		WHERE	dc.device_collection_type = 'per-device'
		  AND	dcd.device_id = in_Device_id
	);

	delete from device_collection_device where device_id = in_Device_id;
	delete from snmp_commstr where device_id = in_Device_id;

		
	IF _d.rack_location_id IS NOT NULL  THEN
		UPDATE device SET rack_location_id = NULL 
		WHERE device_id = in_Device_id;

		-- This should not be permitted based on constraints, but in case
		-- that constraint had to be disabled...
		SELECT	count(*)
		  INTO	tally
		  FROM	device
		 WHERE	rack_location_id = _d.RACK_LOCATION_ID;

		IF tally = 0 THEN
			DELETE FROM rack_location 
			WHERE rack_location_id = _d.RACK_LOCATION_ID;
		END IF;
	END IF;

	IF _d.chassis_location_id IS NOT NULL THEN
		RAISE EXCEPTION 'Retiring modules is not supported yet.';
	END IF;

	SELECT	manager_device_id
	INTO	_mgrid
	 FROM	device_management_controller
	WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
	LIMIT 1;

	IF _mgrid IS NOT NULL THEN
		DELETE FROM device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
			AND manager_device_id = _mgrid;

		PERFORM device_utils.retire_device( manager_device_id)
		  FROM	device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc';
	END IF;

	BEGIN
		PERFORM local_hooks.device_retire_late(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT count(*)
	INTO tally
	FROM device_note
	WHERE device_id = in_Device_id;

	--
	-- If there is no notes or serial number its save to remove
	-- 
	IF tally = 0 AND _d.ASSET_ID is NULL THEN
		_purgedev := true;
	END IF;

	IF _purgedev THEN
		--
		-- If there is an fk violation, we just preserve the record but
		-- delete all the identifying characteristics
		--
		BEGIN
			DELETE FROM device where device_id = in_Device_Id;
			return false;
		EXCEPTION WHEN foreign_key_violation THEN
			PERFORM 1;
		END;
	END IF;

	UPDATE device SET 
		device_name =NULL,
		service_environment_id = (
			select service_environment_id from service_environment
			where service_environment_name = 'unallocated'),
		device_status = 'removed',
		voe_symbolic_track_id = NULL,
		is_monitored = 'N',
		should_fetch_config = 'N',
		description = NULL
	WHERE device_id = in_Device_id;

	return true;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc device_utils.retire_device -> retire_device 
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_dev_col_user_prop_expanded
CREATE VIEW v_dev_col_user_prop_expanded AS
 SELECT dchd.device_collection_id,
    s.account_id,
    s.login,
    s.account_status,
    upo.property_type,
    upo.property_name,
    upo.property_value,
        CASE
            WHEN upn.is_multivalue = 'N'::bpchar THEN 0
            ELSE 1
        END AS is_multievalue,
        CASE
            WHEN pdt.property_data_type::text = 'boolean'::text THEN 1
            ELSE 0
        END AS is_boolean
   FROM jazzhands.v_acct_coll_acct_expanded_detail uued
     JOIN jazzhands.account_collection u ON uued.account_collection_id = u.account_collection_id
     JOIN jazzhands.v_property upo ON upo.account_collection_id = u.account_collection_id AND (upo.property_type::text = ANY (ARRAY['CCAForceCreation'::character varying, 'CCARight'::character varying, 'ConsoleACL'::character varying, 'RADIUS'::character varying, 'TokenMgmt'::character varying, 'UnixPasswdFileValue'::character varying, 'UserMgmt'::character varying, 'cca'::character varying, 'feed-attributes'::character varying, 'proteus-tm'::character varying, 'wwwgroup'::character varying]::text[]))
     JOIN jazzhands.val_property upn ON upo.property_name::text = upn.property_name::text AND upo.property_type::text = upn.property_type::text
     JOIN jazzhands.val_property_data_type pdt ON upn.property_data_type::text = pdt.property_data_type::text
     LEFT JOIN jazzhands.v_device_coll_hier_detail dchd ON dchd.parent_device_collection_id = upo.device_collection_id
     JOIN jazzhands.account s ON uued.account_id = s.account_id
  ORDER BY dchd.device_collection_level,
        CASE
            WHEN u.account_collection_type::text = 'per-user'::text THEN 0
            WHEN u.account_collection_type::text = 'property'::text THEN 1
            WHEN u.account_collection_type::text = 'systems'::text THEN 2
            ELSE 3
        END,
        CASE
            WHEN uued.assign_method = 'Account_CollectionAssignedToPerson'::text THEN 0
            WHEN uued.assign_method = 'Account_CollectionAssignedToDept'::text THEN 1
            WHEN uued.assign_method = 'ParentAccount_CollectionOfAccount_CollectionAssignedToPerson'::text THEN 2
            WHEN uued.assign_method = 'ParentAccount_CollectionOfAccount_CollectionAssignedToDept'::text THEN 2
            WHEN uued.assign_method = 'Account_CollectionAssignedToParentDept'::text THEN 3
            WHEN uued.assign_method = 'ParentAccount_CollectionOfAccount_CollectionAssignedToParentDep'::text THEN 3
            ELSE 6
        END, uued.dept_level, uued.acct_coll_level, dchd.device_collection_id, u.account_collection_id;

delete from __recreate where type = 'view' and object = 'v_dev_col_user_prop_expanded';
-- DONE DEALING WITH TABLE v_dev_col_user_prop_expanded [3845204]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_l1_all_physical_ports [3854317]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_l1_all_physical_ports', 'v_l1_all_physical_ports');
SELECT schema_support.save_dependant_objects_for_replay('audit', 'v_l1_all_physical_ports');
DROP VIEW v_l1_all_physical_ports ;
CREATE VIEW v_l1_all_physical_ports AS
 WITH pp AS (
         SELECT sl.slot_id,
            ds.device_id,
            sl.slot_name,
            st.slot_function
           FROM slot sl
             JOIN slot_type st USING (slot_type_id)
             LEFT JOIN v_device_slots ds USING (slot_id)
        )
 SELECT icc.inter_component_connection_id AS layer1_connection_id,
    s1.slot_id AS physical_port_id,
    s1.device_id,
    s1.slot_name AS port_name,
    s1.slot_function AS port_type,
    NULL::text AS port_purpose,
    s2.slot_id AS other_physical_port_id,
    s2.device_id AS other_device_id,
    s2.slot_name AS other_port_name,
    NULL::text AS other_port_purpose,
    NULL::integer AS baud,
    NULL::integer AS data_bits,
    NULL::integer AS stop_bits,
    NULL::character varying AS parity,
    NULL::character varying AS flow_control
   FROM pp s1
     JOIN inter_component_connection icc ON s1.slot_id = icc.slot1_id
     JOIN pp s2 ON s2.slot_id = icc.slot2_id
UNION
 SELECT icc.inter_component_connection_id AS layer1_connection_id,
    s2.slot_id AS physical_port_id,
    s2.device_id,
    s2.slot_name AS port_name,
    s2.slot_function AS port_type,
    NULL::text AS port_purpose,
    s1.slot_id AS other_physical_port_id,
    s1.device_id AS other_device_id,
    s1.slot_name AS other_port_name,
    NULL::text AS other_port_purpose,
    NULL::integer AS baud,
    NULL::integer AS data_bits,
    NULL::integer AS stop_bits,
    NULL::character varying AS parity,
    NULL::character varying AS flow_control
   FROM pp s1
     JOIN inter_component_connection icc ON s1.slot_id = icc.slot1_id
     JOIN pp s2 ON s2.slot_id = icc.slot2_id
UNION
 SELECT NULL::integer AS layer1_connection_id,
    s1.slot_id AS physical_port_id,
    s1.device_id,
    s1.slot_name AS port_name,
    s1.slot_function AS port_type,
    NULL::text AS port_purpose,
    NULL::integer AS other_physical_port_id,
    NULL::integer AS other_device_id,
    NULL::character varying AS other_port_name,
    NULL::text AS other_port_purpose,
    NULL::integer AS baud,
    NULL::integer AS data_bits,
    NULL::integer AS stop_bits,
    NULL::character varying AS parity,
    NULL::character varying AS flow_control
   FROM pp s1
     LEFT JOIN inter_component_connection icc ON s1.slot_id = icc.slot1_id OR s1.slot_id = icc.slot2_id
  WHERE icc.inter_component_connection_id IS NULL;

delete from __recreate where type = 'view' and object = 'v_l1_all_physical_ports';
GRANT INSERT,UPDATE,DELETE ON v_l1_all_physical_ports TO iud_role;
GRANT SELECT ON v_l1_all_physical_ports TO ro_role;
GRANT ALL ON v_l1_all_physical_ports TO jazzhands;
-- DONE DEALING WITH TABLE v_l1_all_physical_ports [3845147]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_corp_family_account [4134661]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_corp_family_account', 'v_corp_family_account');
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'v_corp_family_account');
SELECT schema_support.save_trigger_for_replay('jazzhands', 'v_corp_family_account');
DROP VIEW v_corp_family_account;
CREATE VIEW v_corp_family_account AS
 SELECT a.account_id,
    a.login,
    a.person_id,
    a.company_id,
    a.account_realm_id,
    a.account_status,
    a.account_role,
    a.account_type,
    a.description,
        CASE
            WHEN vps.is_disabled = 'N'::bpchar THEN 'Y'::text
            ELSE 'N'::text
        END AS is_enabled,
    a.data_ins_user,
    a.data_ins_date,
    a.data_upd_user,
    a.data_upd_date
   FROM account a
     JOIN val_person_status vps ON a.account_status::text = vps.person_status::text
  WHERE (a.account_realm_id IN ( SELECT property.account_realm_id
           FROM property
          WHERE property.property_name::text = '_root_account_realm_id'::text AND property.property_type::text = 'Defaults'::text));

delete from __recreate where type = 'view' and object = 'v_corp_family_account';
-- DONE DEALING WITH TABLE v_corp_family_account [4143053]
--------------------------------------------------------------------


-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
ALTER TABLE component_property DROP CONSTRAINT IF EXISTS r_680;
ALTER TABLE component_property DROP CONSTRAINT IF EXISTS fk_comp_prop_int_cmp_conn_id;
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_int_cmp_conn_id
	FOREIGN KEY (inter_component_connection_id) REFERENCES inter_component_connection(inter_component_connection_id);

ALTER TABLE logical_volume
	ADD CONSTRAINT fk_logvol_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);

ALTER TABLE val_property DROP CONSTRAINT IF EXISTS r_683;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_prop_val_devcol_typ_rstr_dc;
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_val_devcol_typ_rstr_dc
	FOREIGN KEY (prop_val_dev_coll_type_rstrct) REFERENCES val_device_collection_type(device_collection_type);

ALTER TABLE volume_group DROP CONSTRAINT IF EXISTS fk_volgrp_devid;
ALTER TABLE volume_group
	ADD CONSTRAINT fk_volgrp_devid
	FOREIGN KEY (device_id) REFERENCES device(device_id);

ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT fk_vgp_phy_vgrpid_devid
	FOREIGN KEY (volume_group_id, device_id) REFERENCES volume_group(volume_group_id, device_id);

ALTER TABLE ONLY volume_group
	DROP CONSTRAINT IF EXISTS ak_volume_group_vg_devid ;
ALTER TABLE ONLY volume_group
	ADD CONSTRAINT ak_volume_group_vg_devid 
	UNIQUE (volume_group_id, device_id);

ALTER TABLE ONLY logical_volume
	DROP CONSTRAINT IF EXISTS fk_logvol_fstype ;
ALTER TABLE ONLY logical_volume
	ADD CONSTRAINT fk_logvol_fstype FOREIGN KEY (filesystem_type) 
	REFERENCES val_filesystem_type(filesystem_type);

ALTER TABLE ONLY logical_volume
	DROP CONSTRAINT IF EXISTS fk_logvol_vgid ;
ALTER TABLE ONLY logical_volume
	ADD CONSTRAINT fk_logvol_vgid FOREIGN KEY (volume_group_id, device_id)
	REFERENCES volume_group(volume_group_id, device_id);

ALTER TABLE ONLY logical_volume_property
	DROP CONSTRAINT IF EXISTS fk_lvol_prop_lvid_fstyp ;
ALTER TABLE ONLY logical_volume_property
	ADD CONSTRAINT fk_lvol_prop_lvid_fstyp 
	FOREIGN KEY (logical_volume_id, filesystem_type) 
	REFERENCES logical_volume(logical_volume_id, filesystem_type);

ALTER TABLE ONLY logical_volume_purpose
	DROP CONSTRAINT IF EXISTS fk_lvpurp_lvid ;
ALTER TABLE ONLY logical_volume_purpose
	ADD CONSTRAINT fk_lvpurp_lvid FOREIGN KEY (logical_volume_id) 
	REFERENCES logical_volume(logical_volume_id);

ALTER TABLE ONLY physicalish_volume
	DROP CONSTRAINT IF EXISTS fk_physvol_lvid ;
ALTER TABLE ONLY physicalish_volume
	ADD CONSTRAINT fk_physvol_lvid FOREIGN KEY (logical_volume_id) 
	REFERENCES logical_volume(logical_volume_id);

ALTER TABLE ONLY volume_group_physicalish_vol
	ADD CONSTRAINT fk_physvol_vg_phsvol_dvid 
	FOREIGN KEY (physicalish_volume_id, device_id) 
	REFERENCES physicalish_volume(physicalish_volume_id, device_id);
ALTER TABLE ONLY volume_group_physicalish_vol
	ADD CONSTRAINT fk_vg_physvol_vgrel 
	FOREIGN KEY (volume_group_relation) 
	REFERENCES val_volume_group_relation(volume_group_relation);
ALTER TABLE ONLY volume_group_physicalish_vol
	ADD CONSTRAINT fk_vgp_phy_phyid 
	FOREIGN KEY (physicalish_volume_id) 
	REFERENCES physicalish_volume(physicalish_volume_id);
ALTER TABLE ONLY volume_group_physicalish_vol
	ADD CONSTRAINT fk_vgp_phy_vgrpid 
	FOREIGN KEY (volume_group_id) 
	REFERENCES volume_group(volume_group_id);

DROP INDEX IF EXISTS xif_volgrp_devid;
CREATE INDEX xif_volgrp_devid ON volume_group USING btree (device_id);

DROP TRIGGER IF EXISTS trigger_create_device_component 
	ON device ;
CREATE TRIGGER trigger_create_device_component 
	BEFORE INSERT OR UPDATE OF device_type_id
	ON device 
	FOR EACH ROW 
	EXECUTE PROCEDURE create_device_component_by_trigger();


insert into val_x509_certificate_file_fmt
	(x509_file_format, description)
values	 
	('pem', 'human readable rsa certificate'),
	('der', 'binary representation'),
	('keytool', 'Java keystore .jks'),
	('pkcs12', 'PKCS12 .p12 file')
;

insert into val_x509_key_usage
	(x509_key_usg, description, is_extended)
values
	('digitalSignature',	'verifying digital signatures other than other certs/CRLs,  such as those used in an entity authentication service, a data origin authentication service, and/or an integrity service', 'N'),
	('nonRepudiation',	'verifying digital signatures other than other certs/CRLs, to provide a non-repudiation service that protects against the signing entity falsely denying some action.  Also known as contentCommitment', 'N'),
	('keyEncipherment',	'key is used for enciphering private or secret keys', 'N'),
	('dataEncipherment',	'key is used for directly enciphering raw user data without the use of an intermediate symmetric cipher', 'N'),
	('keyAgreement',	NULL, 'N'),
	('keyCertSign',		'key signs other certificates; must be set with ca bit', 'N'),
	('cRLSign',		'key is for verifying signatures on certificate revocation lists', 'N'),
	('encipherOnly',	'with keyAgreement bit, key used for enciphering data while performing key agreement', 'N'),
	('decipherOnly',	'with keyAgreement bit, key used for deciphering data while performing key agreement', 'N'),
	('serverAuth',		'SSL/TLS Web Server Authentication', 'Y'),
	('clientAuth',		'SSL/TLS Web Client Authentication', 'Y'),
	('codeSigning',		'Code signing', 'Y'),
	('emailProtection',	'E-mail Protection (S/MIME)', 'Y'),
	('timeStamping',	'Trusted Timestamping', 'Y'),
	('OCSPSigning',		'Signing OCSP Responses', 'Y')
;

insert into val_x509_key_usage_category
	(x509_key_usg_cat, description)
values
	('ca', 'used to identify a certificate authority'),
	('revocation', 'Used to identify entity that signs crl/ocsp responses'),
	('service', 'used to identify a service on the netowrk'),
	('server', 'used to identify a server as a client'),
	('application', 'cross-authenticate applications'),
	('account', 'used to identify an account/user/person')
;

insert into x509_key_usage_categorization
	(x509_key_usg_cat, x509_key_usg)
values
	('ca',  'keyCertSign'),
	('revocation',  'cRLSign'),
	('revocation',  'OCSPSigning'),
	('service',  'digitalSignature'),
	('service',  'keyEncipherment'),
	('service',  'serverAuth'),
	('application',  'digitalSignature'),
	('application',  'keyEncipherment'),
	('application',  'serverAuth')
;

INSERT INTO val_x509_revocation_reason
	(x509_revocation_reason)
values
	('unspecified'),
	('keyCompromise'),
	('CACompromise'),
	('affiliationChanged'),
	('superseded'),
	('cessationOfOperation'),
	('certificateHold'),
	('removeFromCRL'),
	('privilegeWithdrawn'),
	('AACompromise')
;


-- triggers

delete  from __recreate where object = 'layer1_connection' and type = 'trigger' and ddl like '%trigger_layer1_connection_insteadof%';

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
