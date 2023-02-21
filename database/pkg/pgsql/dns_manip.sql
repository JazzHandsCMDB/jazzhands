-- Copyright (c) 2021, Todd M. Kover
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
        where nspname = 'dns_manip';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS dns_manip;
                CREATE SCHEMA dns_manip AUTHORIZATION jazzhands;
		REVOKE ALL ON SCHEMA dns_manip FROM public;
		COMMENT ON SCHEMA dns_manip IS 'part of jazzhands';
        END IF;
END;
$$;

------------------------------------------------------------------------------
--
-- Add default NS records to a domain, idempotently, optionally removing the
-- ones that do not match the default.
--
------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dns_manip.add_ns_records(
	dns_domain_id	dns_domain.dns_domain_id%type,
	purge			boolean DEFAULT false
) RETURNS void AS
$$
BEGIN
	IF purge THEN
		EXECUTE '
			DELETE FROM dns_record
			WHERE dns_domain_id = $1
			AND dns_name IS NULL
			AND dns_class = $2
			AND dns_type = $3
			AND dns_value NOT IN (
				SELECT property_value
				FROM property
				WHERE property_name = $4
				AND property_type = $5
			)
		' USING dns_domain_id, 'IN', 'NS', '_authdns', 'Defaults';
	END IF;
	EXECUTE '
		INSERT INTO dns_record (
			dns_domain_id, dns_class, dns_type, dns_value
		) select $1, $2, $3, property_value
		FROM property
		WHERE property_name = $4
		AND property_type = $5
		AND property_value NOT IN (
			SELECT dns_value
			FROM dns_record
			WHERE dns_domain_id = $1
			AND dns_class = $2
			AND dns_type = $3
			AND dns_name IS NULL
		)
	' USING dns_domain_id, 'IN', 'NS', '_authdns', 'Defaults';
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
CREATE OR REPLACE FUNCTION dns_manip.get_or_create_inaddr_domain_netblock_link(
	dns_domain_name	dns_domain.dns_domain_name%type,
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
	brk := regexp_matches(dns_domain_name, '^(.+)\.(in-addr|ip6)\.arpa$');
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
		AND		is_single_address = false
		AND		can_subnet = false
		AND		netblock_status = 'Allocated'
		AND		ip_universe_id = 0
		AND		ip_address = ip;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address, netblock_type, is_single_address,
			can_subnet, netblock_status, ip_universe_id
		) VALUES (
			ip, 'dns', false,
			false, 'Allocated', 0
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
-- XXX ip universes need to be folded in better, particularly with reverse
-- and default nameservers
--
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_manip.add_dns_domain(
	dns_domain_name		dns_domain.dns_domain_name%type,
	dns_domain_type		dns_domain.dns_domain_type%type DEFAULT NULL,
	ip_universes		integer[] DEFAULT NULL,
	add_nameservers		boolean DEFAULT NULL
) RETURNS dns_domain.dns_domain_id%type AS $$
DECLARE
	elements		text[];
	parent_zone		text;
	short_name		TEXT;
	parent_id		dns_domain.dns_domain_id%type;
	domain_id		dns_domain.dns_domain_id%type;
	parent_type		TEXT;
	elem			text;
	sofar			text;
	rvs_nblk_id		netblock.netblock_id%type;
	univ			ip_universe.ip_universe_id%type;
	can_haz_generate	boolean;
BEGIN
	IF dns_domain_name IS NULL THEN
		RETURN NULL;
	END IF;

	elements := regexp_split_to_array(dns_domain_name, '\.');
	sofar := '';
	FOREACH elem in ARRAY elements
	LOOP
		IF octet_length(sofar) > 0 THEN
			sofar := sofar || '.';
		END IF;
		sofar := sofar || elem;
		parent_zone := regexp_replace(dns_domain_name, '^'||sofar||'.', '');
		EXECUTE 'SELECT dns_domain_id, dns_domain_type FROM dns_domain
			WHERE dns_domain_name = $1'
			INTO parent_id, parent_type
			USING parent_zone;
		IF parent_id IS NOT NULL THEN
			EXIT;
		END IF;
	END LOOP;

	short_name := regexp_replace(dns_domain_name, concat('.', parent_zone), '');

	IF ip_universes IS NULL THEN
		SELECT array_agg(ip_universe_id)
		INTO	ip_universes
		FROM	ip_universe
		WHERE	ip_universe_name = 'default';
	END IF;

	IF dns_domain_type IS NULL THEN
		IF dns_domain_name ~ '^.*(in-addr|ip6)\.arpa$' THEN
			dns_domain_type := 'reverse';
		ELSIF parent_type IS NOT NULL THEN
			dns_domain_type := parent_type;
		ELSE
			RAISE EXCEPTION 'Unable to guess dns_domain_type for %',
				dns_domain_name USING ERRCODE = 'not_null_violation';
		END IF;
	END IF;

	SELECT dt.can_generate
	INTO can_haz_generate
	FROM val_dns_domain_type dt
	WHERE dt.dns_domain_type = add_dns_domain.dns_domain_type;

	EXECUTE '
		INSERT INTO dns_domain (
			dns_domain_name,
			parent_dns_domain_id,
			dns_domain_type
		) VALUES (
			$1,
			$2,
			$3
		) RETURNING dns_domain_id' INTO domain_id
		USING dns_domain_name,
			parent_id,
			dns_domain_type
	;

	FOREACH univ IN ARRAY ip_universes
	LOOP
		EXECUTE '
			INSERT INTO dns_domain_ip_universe (
				dns_domain_id,
				ip_universe_id,
				soa_class,
				soa_mname,
				soa_rname,
				should_generate
			) VALUES (
				$1,
				$2,
				$3,
				$4,
				$5,
				$6
			);'
			USING domain_id, univ,
				'IN',
				(select property_value from property
					where property_type = 'Defaults'
					and property_name = '_dnsmname' ORDER BY property_id LIMIT 1),
				(select property_value from property
					where property_type = 'Defaults'
					and property_name = '_dnsrname' ORDER BY property_id LIMIT 1),
				can_haz_generate
		;
	END LOOP;

	IF dns_domain_type = 'reverse' THEN
		rvs_nblk_id := dns_manip.get_or_create_inaddr_domain_netblock_link(
			dns_domain_name, domain_id);
	END IF;

	--
	-- migrate any records _in_ the parent zone over to this zone.
	--
	IF short_name IS NOT NULL AND parent_id IS NOT NULL THEN
		UPDATE  dns_record
			SET dns_name =
				CASE WHEN lower(dns_name) = lower(short_name) THEN NULL
				ELSE regexp_replace(dns_name, concat('.', short_name, '$'), '')
				END,
				dns_domain_id =  domain_id
		WHERE dns_domain_id = parent_id
		AND lower(dns_name) ~ concat('\.?', lower(short_name), '$');

		--
		-- check to see if NS servers already exist, in which case, reuse them
		--
		IF add_nameservers IS NULL THEN
			PERFORM *
			FROM dns_record
			WHERE dns_domain_id = domain_id
			AND dns_type = 'NS'
			AND dns_name IS NULL;

			IF FOUND THEN
				add_nameservers := false;
			ELSE
				add_nameservers := true;
			END IF;
		END IF;
	ELSIF add_nameservers IS NULL THEN
		add_nameservers := true;
	END IF;

	IF add_nameservers THEN
		PERFORM dns_manip.add_ns_records(domain_id);
	END IF;

	-- XXX - need to reconsider how ip universes fit into this.
	IF parent_id IS NOT NULL THEN
		INSERT INTO dns_change_record (
			dns_domain_id
		) SELECT dns_domain_id
		FROM dns_domain
		WHERE dns_domain_id = parent_id
		AND dns_domain_id IN (
			SELECT dns_domain_id
			FROM dns_domain_ip_universe
			WHERE should_generate = true
		);
	END IF;

	RETURN domain_id;
END;
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;


------------------------------------------------------------------------------
--
-- Given a cidr block, add a dns domain for it, which will take care of linkage
-- to an in-addr record for ipv4 addresses or ipv6 addresses as appropriate.
--
--
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_manip.add_domain_from_cidr(
	block		inet
) RETURNS dns_domain.dns_domain_id%TYPE
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

	SELECT dns_domain_id INTO domain_id FROM dns_domain where dns_domain_name = domain;
	IF NOT FOUND THEN
		-- domain_id := dns_manip.add_dns_domain(domain);
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
DROP FUNCTION IF EXISTS dns_manip.add_domains_from_netblock ( integer );
CREATE OR REPLACE FUNCTION dns_manip.add_domains_from_netblock(
	netblock_id		netblock.netblock_id%TYPE
) RETURNS jsonb
AS
$$
DECLARE
	nid	ALIAS FOR netblock_id;
	block	inet;
	_rv	TEXT;
BEGIN
	SELECT ip_address INTO block FROM netblock n WHERE n.netblock_id = nid;

	RAISE DEBUG 'Creating inverse DNS zones for %s', block;

	SELECT jsonb_agg(jsonb_build_object(
		'dns_domain_id', dns_domain_id,
		'dns_domain_name', dns_domain_name))
	FROM (
		SELECT
			dns_manip.add_dns_domain(
				dns_domain_name := x.dns_domain_name,
				dns_domain_type := 'reverse'
				) as dns_domain_id,
			x.dns_domain_name::text
		FROM dns_utils.get_all_domain_rows_for_cidr(block) x
		LEFT JOIN dns_domain d USING (dns_domain_name)
		WHERE d.dns_domain_id IS NULL
	) i INTO _rv;

	RETURN _rv;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY definer;

REVOKE ALL ON SCHEMA dns_manip FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA dns_manip FROM public;

GRANT ALL ON SCHEMA dns_manip TO iud_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA dns_manip TO iud_role;
