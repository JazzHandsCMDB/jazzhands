--
-- Copyright (c) 2018 Todd Kover
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

	--suffix=v83
	--post
	post
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
-- Changed function
SELECT schema_support.save_grants_for_replay('dns_utils', 'add_dns_domain');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS dns_utils.add_dns_domain ( soa_name character varying, dns_domain_type character varying, ip_universes integer[], add_nameservers boolean );
CREATE OR REPLACE FUNCTION dns_utils.add_dns_domain(soa_name character varying, dns_domain_type character varying DEFAULT NULL::character varying, ip_universes integer[] DEFAULT NULL::integer[], add_nameservers boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	elements		text[];
	parent_zone		text;
	parent_id		dns_domain.dns_domain_id%type;
	domain_id		dns_domain.dns_domain_id%type;
	elem			text;
	sofar			text;
	rvs_nblk_id		netblock.netblock_id%type;
	univ			ip_universe.ip_universe_id%type;
BEGIN
	IF soa_name IS NULL THEN
		RETURN NULL;
	END IF;
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
			WHERE soa_name = $1' INTO parent_id USING parent_zone;
		IF parent_id IS NOT NULL THEN
			EXIT;
		END IF;
	END LOOP;

	IF ip_universes IS NULL THEN
		SELECT array_agg(ip_universe_id) 
		INTO	ip_universes
		FROM	ip_universe
		WHERE	ip_universe_name = 'default';
	END IF;

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
			parent_dns_domain_id,
			dns_domain_type
		) VALUES (
			$1,
			$2,
			$3
		) RETURNING dns_domain_id' INTO domain_id 
		USING soa_name, 
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
				'Y'
		;
	END LOOP;

	IF dns_domain_type = 'reverse' THEN
		rvs_nblk_id := dns_utils.get_or_create_rvs_netblock_link(
			soa_name, domain_id);
	END IF;

	IF add_nameservers THEN
		PERFORM dns_utils.add_ns_records(domain_id);
	END IF;

	--
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
			WHERE should_generate = 'Y'
		);
	END IF;

	RETURN domain_id;
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
-- Process middle (non-trigger) schema component_connection_utils
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
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblocks ( parent_netblock_list integer[], netmask_bits integer, single_address boolean, allocation_method text, max_addresses integer, desired_ip_address inet, rnd_masklen_threshold integer, rnd_max_count integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocation_method text DEFAULT NULL::text, max_addresses integer DEFAULT 1024, desired_ip_address inet DEFAULT NULL::inet, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	netblock_rec	jazzhands.netblock%ROWTYPE;
	netrange_rec	RECORD;
	inet_list		inet[];
	current_ip		inet;
	saved_method	text;
	min_ip			inet;
	max_ip			inet;
	matches			integer;
	rnd_matches		integer;
	max_rnd_value	bigint;
	rnd_value		bigint;
	family_bits		integer;
BEGIN
	matches := 0;
	saved_method = allocation_method;

	IF allocation_method IS NOT NULL AND allocation_method
			NOT IN ('top', 'bottom', 'random', 'default') THEN
		RAISE 'address_type must be one of top, bottom, random, or default'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	--
	-- Sanitize masklen input.  This is a little complicated.
	--
	-- If a single address is desired, we always use a /32 or /128
	-- in the parent loop and everything else is ignored
	--
	-- Otherwise, if netmask_bits is passed, that wins, otherwise
	-- the netmask of whatever is passed with desired_ip_address wins
	--
	-- If none of these are the case, then things are wrong and we
	-- bail
	--

	IF NOT single_address THEN 
		IF desired_ip_address IS NOT NULL AND netmask_bits IS NULL THEN
			netmask_bits := masklen(desired_ip_address);
		ELSIF desired_ip_address IS NOT NULL AND 
				netmask_bits IS NOT NULL THEN
			desired_ip_address := set_masklen(desired_ip_address,
				netmask_bits);
		END IF;
		IF netmask_bits IS NULL THEN
			RAISE EXCEPTION 'netmask_bits must be set'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF allocation_method = 'random' THEN
			RAISE EXCEPTION 'random netblocks may only be returned for single addresses'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	FOREACH parent_nbid IN ARRAY parent_netblock_list LOOP
		rnd_matches := 0;
		--
		-- Restore this, because we may have overrridden it for a previous
		-- block
		--
		allocation_method = saved_method;
		SELECT 
			* INTO netblock_rec
		FROM
			jazzhands.netblock n
		WHERE
			n.netblock_id = parent_nbid;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'Netblock % does not exist', parent_nbid;
		END IF;

		family_bits := 
			(CASE family(netblock_rec.ip_address) WHEN 4 THEN 32 ELSE 128 END);

		-- If desired_ip_address is passed, then allocation_method is
		-- irrelevant

		IF desired_ip_address IS NOT NULL THEN
			--
			-- If the IP address is not the same family as the parent block,
			-- we aren't going to find it
			--
			IF family(desired_ip_address) != 
					family(netblock_rec.ip_address) THEN
				CONTINUE;
			END IF;
			allocation_method := 'bottom';
		END IF;

		--
		-- If allocation_method is 'default' or NULL, then use 'bottom'
		-- unless it's for a single IPv6 address in a netblock larger than 
		-- rnd_masklen_threshold
		--
		IF allocation_method IS NULL OR allocation_method = 'default' THEN
			allocation_method := 
				CASE WHEN 
					single_address AND 
					family(netblock_rec.ip_address) = 6 AND
					masklen(netblock_rec.ip_address) <= rnd_masklen_threshold
				THEN
					'random'
				ELSE
					'bottom'
				END;
		END IF;

		IF allocation_method = 'random' AND 
				family_bits - masklen(netblock_rec.ip_address) < 2 THEN
			-- Random allocation doesn't work if we don't have enough
			-- bits to play with, so just do sequential.
			allocation_method := 'bottom';
		END IF;

		IF single_address THEN 
			netmask_bits := family_bits;
			IF desired_ip_address IS NOT NULL THEN
				desired_ip_address := set_masklen(desired_ip_address,
					masklen(netblock_rec.ip_address));
			END IF;
		ELSIF netmask_bits <= masklen(netblock_rec.ip_address) THEN
			-- If the netmask is not for a smaller netblock than this parent,
			-- then bounce to the next one, because maybe it's larger
			RAISE DEBUG
				'netblock (%) is not larger than netmask_bits of % - skipping',
				masklen(netblock_rec.ip_address),
				netmask_bits;
			CONTINUE;
		END IF;

		IF netmask_bits > family_bits THEN
			RAISE EXCEPTION 'netmask_bits must be no more than % for netblock %',
				family_bits,
				netblock_rec.ip_address;
		END IF;

		--
		-- Short circuit the check if we're looking for a specific address
		-- and it's not in this netblock
		--

		IF desired_ip_address IS NOT NULL AND
				NOT (desired_ip_address <<= netblock_rec.ip_address) THEN
			RAISE DEBUG 'desired_ip_address % is not in netblock %',
				desired_ip_address,
				netblock_rec.ip_address;
			CONTINUE;
		END IF;

		IF single_address AND netblock_rec.can_subnet = 'Y' THEN
			RAISE EXCEPTION 'single addresses may not be assigned to to a block where can_subnet is Y';
		END IF;

		IF (NOT single_address) AND netblock_rec.can_subnet = 'N' THEN
			RAISE EXCEPTION 'Netblock % (%) may not be subnetted',
				netblock_rec.ip_address,
				netblock_rec.netblock_id;
		END IF;

		RAISE DEBUG 'Searching netblock % (%) using the % allocation method',
			netblock_rec.netblock_id,
			netblock_rec.ip_address,
			allocation_method;

		IF desired_ip_address IS NOT NULL THEN
			min_ip := desired_ip_address;
			max_ip := desired_ip_address + 1;
		ELSE
			min_ip := netblock_rec.ip_address;
			max_ip := broadcast(min_ip) + 1;
		END IF;

		IF allocation_method = 'top' THEN
			current_ip := network(set_masklen(max_ip - 1, netmask_bits));
		ELSIF allocation_method = 'random' THEN
			max_rnd_value := (x'7fffffffffffffff'::bigint >> CASE 
				WHEN family_bits - masklen(netblock_rec.ip_address) >= 63
				THEN 0
				ELSE 63 - (family_bits - masklen(netblock_rec.ip_address))
				END) - 2;
			-- random() appears to only do 32-bits, which is dumb
			-- I'm pretty sure that all of the casts are not required here,
			-- but better to make sure
			current_ip := min_ip + 
					((((random() * x'7fffffff'::bigint)::bigint << 32) + 
					(random() * x'ffffffff'::bigint)::bigint + 1)
					% max_rnd_value) + 1;
		ELSE -- it's 'bottom'
			current_ip := set_masklen(min_ip, netmask_bits);
		END IF;

		-- For single addresses, make the netmask match the netblock of the
		-- containing block, and skip the network and broadcast addresses
		-- We shouldn't need to skip for IPv6 addresses, but some things
		-- apparently suck

		IF single_address THEN
			current_ip := set_masklen(current_ip, 
				masklen(netblock_rec.ip_address));
			--
			-- If we're not allocating a single /31 or /32 for IPv4 or
			-- /127 or /128 for IPv6, then we want to skip the all-zeros
			-- and all-ones addresses
			--
			IF masklen(netblock_rec.ip_address) < (family_bits - 1) AND
					desired_ip_address IS NULL THEN
				current_ip := current_ip + 
					CASE WHEN allocation_method = 'top' THEN -1 ELSE 1 END;
				min_ip := min_ip + 1;
				max_ip := max_ip - 1;
			END IF;
		END IF;

		RAISE DEBUG 'Starting with IP address % with step masklen of %',
			current_ip,
			netmask_bits;

		WHILE (
				current_ip >= min_ip AND
				current_ip < max_ip AND
				matches < max_addresses AND
				rnd_matches < rnd_max_count
		) LOOP
			RAISE DEBUG '   Checking netblock %', current_ip;

			IF single_address THEN
				--
				-- Check to see if netblock is in a network_range, and if it is,
				-- then set the value to the top or bottom of the range, or
				-- another random value as appropriate
				--
				SELECT 
					network_range_id,
					start_nb.ip_address AS start_ip_address,
					stop_nb.ip_address AS stop_ip_address
				INTO netrange_rec
				FROM
					jazzhands.network_range nr,
					jazzhands.netblock start_nb,
					jazzhands.netblock stop_nb
				WHERE
					nr.start_netblock_id = start_nb.netblock_id AND
					nr.stop_netblock_id = stop_nb.netblock_id AND
					nr.parent_netblock_id = netblock_rec.netblock_id AND
					start_nb.ip_address <= 
						set_masklen(current_ip, masklen(start_nb.ip_address))
					AND stop_nb.ip_address >=
						set_masklen(current_ip, masklen(stop_nb.ip_address));

				IF FOUND THEN
					current_ip := CASE 
						WHEN allocation_method = 'bottom' THEN
							netrange_rec.stop_ip_address + 1
						WHEN allocation_method = 'top' THEN
							netrange_rec.start_ip_address - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32) 
							+ 
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1 
					END;
					CONTINUE;
				END IF;
			END IF;
							
				
			PERFORM * FROM jazzhands.netblock n WHERE
				n.ip_universe_id = netblock_rec.ip_universe_id AND
				n.netblock_type = netblock_rec.netblock_type AND
				-- A block with the parent either contains or is contained
				-- by this block
				n.parent_netblock_id = netblock_rec.netblock_id AND
				CASE WHEN single_address THEN
					n.ip_address = current_ip
				ELSE
					(n.ip_address >>= current_ip OR current_ip >>= n.ip_address)
				END;
			IF NOT FOUND AND (inet_list IS NULL OR
					NOT (current_ip = ANY(inet_list))) THEN
				find_free_netblocks.netblock_type :=
					netblock_rec.netblock_type;
				find_free_netblocks.ip_universe_id :=
					netblock_rec.ip_universe_id;
				find_free_netblocks.ip_address := current_ip;
				RETURN NEXT;
				inet_list := array_append(inet_list, current_ip);
				matches := matches + 1;
				-- Reset random counter if we found something
				rnd_matches := 0;
			ELSIF allocation_method = 'random' THEN
				-- Increase random counter if we didn't find something
				rnd_matches := rnd_matches + 1;
			END IF;

			-- Select the next IP address
			current_ip := 
				CASE WHEN single_address THEN
					CASE 
						WHEN allocation_method = 'bottom' THEN current_ip + 1
						WHEN allocation_method = 'top' THEN current_ip - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32) 
							+ 
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1 
					END
				ELSE
					CASE WHEN allocation_method = 'bottom' THEN 
						network(broadcast(current_ip) + 1)
					ELSE 
						network(current_ip - 1)
					END
				END;
		END LOOP;
	END LOOP;
	RETURN;
END;
$function$
;

--
-- Process middle (non-trigger) schema property_utils
--
--
-- Process middle (non-trigger) schema netblock_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'set_interface_addresses');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.set_interface_addresses ( network_interface_id integer, device_id integer, network_interface_name text, network_interface_type text, ip_address_hash jsonb, create_layer3_networks boolean, move_addresses text, address_errors text );
CREATE OR REPLACE FUNCTION netblock_manip.set_interface_addresses(network_interface_id integer DEFAULT NULL::integer, device_id integer DEFAULT NULL::integer, network_interface_name text DEFAULT NULL::text, network_interface_type text DEFAULT 'broadcast'::text, ip_address_hash jsonb DEFAULT NULL::jsonb, create_layer3_networks boolean DEFAULT false, move_addresses text DEFAULT 'if_same_device'::text, address_errors text DEFAULT 'error'::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
--
-- ip_address_hash consists of the following elements
--
--		"ip_addresses" : [ (inet | netblock) ... ]
--		"shared_ip_addresses" : [ (inet | netblock) ... ]
--
-- where inet is a text string that can be legally converted to type inet
-- and netblock is a JSON object with fields:
--		"ip_address" : inet
--		"ip_universe_id" : integer (default 0)
--		"netblock_type" : text (default 'default')
--		"protocol" : text (default 'VRRP')
--
-- If either "ip_addresses" or "shared_ip_addresses" does not exist, it
-- will not be processed.  If the key is present and is an empty array or
-- null, then all IP addresses of those types will be removed from the
-- interface
--
-- 'protocol' is only valid for shared addresses, which is how the address
-- is shared.  Valid values can be found in the val_shared_netblock_protocol
-- table
--
DECLARE
	ni_id			ALIAS FOR network_interface_id;
	dev_id			ALIAS FOR device_id;
	ni_name			ALIAS FOR network_interface_name;
	ni_type			ALIAS FOR network_interface_type;

	addrs_ary		jsonb;
	ipaddr			inet;
	universe		integer;
	nb_type			text;
	protocol		text;

	c				integer;
	i				integer;

	error_rec		RECORD;
	nb_rec			RECORD;
	pnb_rec			RECORD;
	layer3_rec		RECORD;
	sn_rec			RECORD;
	ni_rec			RECORD;
	nin_rec			RECORD;
	nb_id			jazzhands.netblock.netblock_id%TYPE;
	nb_id_ary		integer[];
	ni_id_ary		integer[];
	del_list		integer[];
BEGIN
	--
	-- Validate that we got enough information passed to do things
	--

	IF ip_address_hash IS NULL OR NOT
		(jsonb_typeof(ip_address_hash) = 'object')
	THEN
		RAISE 'Must pass ip_addresses to netblock_manip.set_interface_addresses';
	END IF;

	IF network_interface_id IS NULL THEN
		IF device_id IS NULL OR network_interface_name IS NULL THEN
			RAISE 'netblock_manip.assign_shared_netblock: must pass either network_interface_id or device_id and network_interface_name'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;

		SELECT
			ni.network_interface_id INTO ni_id
		FROM
			network_interface ni
		WHERE
			ni.device_id = dev_id AND
			ni.network_interface_name = ni_name;

		IF NOT FOUND THEN
			INSERT INTO network_interface(
				device_id,
				network_interface_name,
				network_interface_type,
				should_monitor
			) VALUES (
				dev_id,
				ni_name,
				ni_type,
				'N'
			) RETURNING network_interface.network_interface_id INTO ni_id;
		END IF;
	END IF;

	SELECT * INTO ni_rec FROM network_interface ni WHERE 
		ni.network_interface_id = ni_id;

	--
	-- First, loop through ip_addresses passed and process those
	--

	IF ip_address_hash ? 'ip_addresses' AND
		jsonb_typeof(ip_address_hash->'ip_addresses') = 'array'
	THEN
		RAISE DEBUG 'Processing ip_addresses...';
		--
		-- Loop through each member of the ip_addresses array
		-- and process each address
		--
		addrs_ary := ip_address_hash->'ip_addresses';
		c := jsonb_array_length(addrs_ary);
		i := 0;
		nb_id_ary := NULL;
		WHILE (i < c) LOOP
			IF jsonb_typeof(addrs_ary->i) = 'string' THEN
				--
				-- If this is a string, use it as an inet with default
				-- universe and netblock_type
				--
				ipaddr := addrs_ary->>i;
				universe := netblock_utils.find_best_ip_universe(ipaddr);
				nb_type := 'default';
			ELSIF jsonb_typeof(addrs_ary->i) = 'object' THEN
				--
				-- If this is an object, require 'ip_address' key
				-- optionally use 'ip_universe_id' and 'netblock_type' keys
				-- to override the defaults
				--
				IF NOT addrs_ary->i ? 'ip_address' THEN
					RAISE E'Object in array element % of ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses does not contain ip_address key:\n%',
						i, jsonb_pretty(addrs_ary->i);
				END IF;
				ipaddr := addrs_ary->i->>'ip_address';

				IF addrs_ary->i ? 'ip_universe_id' THEN
					universe := addrs_ary->i->'ip_universe_id';
				ELSE
					universe := netblock_utils.find_best_ip_universe(ipaddr);
				END IF;

				IF addrs_ary->i ? 'netblock_type' THEN
					nb_type := addrs_ary->i->>'netblock_type';
				ELSE
					nb_type := 'default';
				END IF;
			ELSE
				RAISE 'Invalid type in array element % of ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses (%)',
					i, jsonb_typeof(addrs_ary->i);
			END IF;
			--
			-- We're done with the array, so increment the counter so
			-- we don't have to deal with it later
			--
			i := i + 1;

			RAISE DEBUG 'Address is %, universe is %, nb type is %',
				ipaddr, universe, nb_type;

			--
			-- This is a hack, because Juniper is really annoying about this.
			-- If masklen < 8, then ignore this netblock (we specifically
			-- want /8, because of 127/8 and 10/8, which someone could
			-- maybe want to not subnet.
			--
			-- This should probably be a configuration parameter, but it's not.
			--
			CONTINUE WHEN masklen(ipaddr) < 8;

			--
			-- Check to see if this is a netblock that we have been
			-- told to explicitly ignore
			--
			PERFORM
				ip_address
			FROM
				netblock n JOIN
				netblock_collection_netblock ncn USING (netblock_id) JOIN
				v_netblock_coll_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_nblk_coll_id =
						nce.root_netblock_collection_id
				)
			WHERE
				ipaddr <<= n.ip_address AND
				n.ip_universe_id = universe
			;

			--
			-- If we found this netblock in the ignore list, then just
			-- skip it
			--
			IF FOUND THEN
				RAISE DEBUG 'Skipping ignored address %', ipaddr;
				CONTINUE;
			END IF;

			--
			-- Look for an is_single_address='Y', can_subnet='N' netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = 'Y' AND
				can_subnet = 'N' AND
				netblock_type = nb_type AND
				ip_universe_id = universe AND
				host(ip_address) = host(ipaddr);

			IF FOUND THEN
				RAISE DEBUG E'Located netblock:\n%',
					jsonb_pretty(to_jsonb(nb_rec));

				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);

				--
				-- Look to see if there's a layer3_network for the
				-- parent netblock
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.netblock_id = nb_rec.parent_netblock_id;

				IF FOUND THEN
					RAISE DEBUG E'Located layer3_network:\n%',
						jsonb_pretty(to_jsonb(layer3_rec));
				ELSE
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
			ELSE
				--
				-- If the parent netblock does not exist, then create it
				-- if we were passed the option to
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.ip_universe_id = universe AND
					n.netblock_type = nb_type AND
					is_single_address = 'N' AND
					can_subnet = 'N' AND
					n.ip_address >>= ipaddr;

				IF NOT FOUND THEN
					RAISE DEBUG 'Parent netblock with ip_address %, netblock_type %, ip_universe_id % not found',
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					--
					-- Check to see if the netblock exists, but is
					-- marked can_subnet='Y'.  If so, fix it
					--
					SELECT 
						* INTO pnb_rec
					FROM
						netblock n
					WHERE
						n.ip_universe_id = universe AND
						n.netblock_type = nb_type AND
						n.is_single_address = 'N' AND
						n.can_subnet = 'Y' AND
						n.ip_address = network(ipaddr);

					IF FOUND THEN
						UPDATE netblock n SET
							can_subnet = 'N'
						WHERE
							n.netblock_id = pnb_rec.netblock_id;
						pnb_rec.can_subnet = 'N';
					ELSE
						INSERT INTO netblock (
							ip_address,
							netblock_type,
							is_single_address,
							can_subnet,
							ip_universe_id,
							netblock_status
						) VALUES (
							network(ipaddr),
							nb_type,
							'N',
							'N',
							universe,
							'Allocated'
						) RETURNING * INTO pnb_rec;
					END IF;

					WITH l3_ins AS (
						INSERT INTO layer3_network(
							netblock_id
						) VALUES (
							pnb_rec.netblock_id
						) RETURNING *
					)
					SELECT
						pnb_rec.netblock_id,
						pnb_rec.ip_address,
						l3_ins.layer3_network_id,
						NULL::inet
					INTO layer3_rec
					FROM
						l3_ins;
				ELSIF layer3_rec.layer3_network_id IS NULL THEN
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--

					RAISE DEBUG 'layer3_network for parent netblock % not found (ip_address %, netblock_type %, ip_universe_id %)',
						layer3_rec.netblock_id,
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
				RAISE DEBUG E'Located layer3_network:\n%',
					jsonb_pretty(to_jsonb(layer3_rec));
				--
				-- Parents should be all set up now.  Insert the netblock
				--
				INSERT INTO netblock (
					ip_address,
					netblock_type,
					ip_universe_id,
					is_single_address,
					can_subnet,
					netblock_status
				) VALUES (
					ipaddr,
					nb_type,
					universe,
					'Y',
					'N',
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;
			--
			-- Now that we have the netblock and everything, check to see
			-- if this netblock is already assigned to this network_interface
			--
			PERFORM * FROM
				network_interface_netblock nin
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id = ni_id;

			IF FOUND THEN
				RAISE DEBUG 'Netblock % already found on network_interface',
					nb_rec.netblock_id;
				CONTINUE;
			END IF;

			--
			-- See if this netblock is on something else, and delete it
			-- if move_addresses is set, otherwise skip it
			--
			SELECT 
				ni.network_interface_id,
				ni.network_interface_name,
				nin.netblock_id,
				d.device_id,
				COALESCE(d.device_name, d.physical_label) AS device_name
			INTO nin_rec
			FROM
				network_interface_netblock nin JOIN
				network_interface ni USING (network_interface_id) JOIN
				device d ON (nin.device_id = d.device_id)
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id != ni_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND 
					nin_rec.device_id = ni_rec.device_id
				)
				THEN
					DELETE FROM
						network_interface_netblock
					WHERE
						netblock_id = nb_rec.netblock_id;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % (%) is assigned to network_interface % (%) on device % (%)',
							nb_rec.netblock_id,
							nb_rec.ip_address,
							nin_rec.network_interface_id,
							nin_rec.network_interface_name,
							nin_rec.device_id,
							nin_rec.device_name;

						CONTINUE;
					ELSE
						RAISE 'Netblock % (%) is assigned to network_interface %(%) on device % (%)',
							nb_rec.netblock_id,
							nb_rec.ip_address,
							nin_rec.network_interface_id,
							nin_rec.network_interface_name,
							nin_rec.device_id,
							nin_rec.device_name;
					END IF;
				END IF;
			END IF;

			--
			-- See if this netblock is on a shared_address somewhere, and
			-- move it only if move_addresses is 'always'
			--
			SELECT * FROM
				shared_netblock sn
			INTO sn_rec
			WHERE
				sn.netblock_id = nb_rec.netblock_id;

			IF FOUND THEN
				IF move_addresses IS NULL OR move_addresses != 'always' THEN
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, sn.shared_netblock_id;
						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % (%) is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, nb_rec.ip_address,
							sn.shared_netblock_id;
						CONTINUE;
					ELSE
						RAISE 'Netblock % (%) is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, nb_rec.ip_address,
							sn.shared_netblock_id;
						CONTINUE;
					END IF;
				END IF;

				DELETE FROM
					shared_netblock_network_int snni
				WHERE
					snni.shared_netblock_id = sn_rec.shared_netblock_id;

				DELETE FROM
					shared_network sn
				WHERE
					sn.netblock_id = sn_rec.shared_netblock_id;
			END IF;

			--
			-- Insert the netblock onto the interface using the next
			-- rank
			--
			INSERT INTO network_interface_netblock (
				network_interface_id,
				netblock_id,
				network_interface_rank
			) SELECT
				ni_id,
				nb_rec.netblock_id,
				COALESCE(MAX(network_interface_rank) + 1, 0)
			FROM
				network_interface_netblock nin
			WHERE
				nin.network_interface_id = ni_id
			RETURNING * INTO nin_rec;

			RAISE DEBUG E'Inserted into:\n%',
				jsonb_pretty(to_jsonb(nin_rec));
		END LOOP;
		--
		-- Remove any netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR nin_rec IN
			DELETE FROM
				network_interface_netblock nin
			WHERE
				(nin.network_interface_id, nin.netblock_id) IN (
				SELECT
					nin2.network_interface_id,
					nin2.netblock_id
				FROM
					network_interface_netblock nin2 JOIN
					netblock n USING (netblock_id)
				WHERE
					nin2.network_interface_id = ni_id AND NOT (
						nin.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_coll_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_nblk_coll_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed netblock % from network_interface %',
				nin_rec.netblock_id,
				nin_rec.network_interface_id;
			--
			-- Remove any DNS records and/or netblocks that aren't used
			--
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = nin_rec.netblock_id;
				DELETE FROM netblock_collection_netblock WHERE
					netblock_id = nin_rec.netblock_id;
				DELETE FROM netblock WHERE netblock_id =
					nin_rec.netblock_id;
			EXCEPTION
				WHEN foreign_key_violation THEN NULL;
			END;
		END LOOP;
	END IF;

	--
	-- Loop through shared_ip_addresses passed and process those
	--

	IF ip_address_hash ? 'shared_ip_addresses' AND
		jsonb_typeof(ip_address_hash->'shared_ip_addresses') = 'array'
	THEN
		RAISE DEBUG 'Processing shared_ip_addresses...';
		--
		-- Loop through each member of the shared_ip_addresses array
		-- and process each address
		--
		addrs_ary := ip_address_hash->'shared_ip_addresses';
		c := jsonb_array_length(addrs_ary);
		i := 0;
		nb_id_ary := NULL;
		WHILE (i < c) LOOP
			IF jsonb_typeof(addrs_ary->i) = 'string' THEN
				--
				-- If this is a string, use it as an inet with default
				-- universe and netblock_type
				--
				ipaddr := addrs_ary->>i;
				universe := netblock_utils.find_best_ip_universe(ipaddr);
				nb_type := 'default';
				protocol := 'VRRP';
			ELSIF jsonb_typeof(addrs_ary->i) = 'object' THEN
				--
				-- If this is an object, require 'ip_address' key
				-- optionally use 'ip_universe_id' and 'netblock_type' keys
				-- to override the defaults
				--
				IF NOT addrs_ary->i ? 'ip_address' THEN
					RAISE E'Object in array element % of shared_ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses does not contain ip_address key:\n%',
						i, jsonb_pretty(addrs_ary->i);
				END IF;
				ipaddr := addrs_ary->i->>'ip_address';

				IF addrs_ary->i ? 'ip_universe_id' THEN
					universe := addrs_ary->i->'ip_universe_id';
				ELSE
					universe := netblock_utils.find_best_ip_universe(ipaddr);
				END IF;

				IF addrs_ary->i ? 'netblock_type' THEN
					nb_type := addrs_ary->i->>'netblock_type';
				ELSE
					nb_type := 'default';
				END IF;

				IF addrs_ary->i ? 'shared_netblock_protocol' THEN
					protocol := addrs_ary->i->>'shared_netblock_protocol';
				ELSIF addrs_ary->i ? 'protocol' THEN
					protocol := addrs_ary->i->>'protocol';
				ELSE
					protocol := 'VRRP';
				END IF;
			ELSE
				RAISE 'Invalid type in array element % of shared_ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses (%)',
					i, jsonb_typeof(addrs_ary->i);
			END IF;
			--
			-- We're done with the array, so increment the counter so
			-- we don't have to deal with it later
			--
			i := i + 1;

			RAISE DEBUG 'Address is %, universe is %, nb type is %',
				ipaddr, universe, nb_type;

			--
			-- Check to see if this is a netblock that we have been
			-- told to explicitly ignore
			--
			PERFORM
				ip_address
			FROM
				netblock n JOIN
				netblock_collection_netblock ncn USING (netblock_id) JOIN
				v_netblock_coll_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_nblk_coll_id =
						nce.root_netblock_collection_id
				)
			WHERE
				ipaddr <<= n.ip_address AND
				n.ip_universe_id = universe AND
				n.netblock_type = nb_type;

			--
			-- If we found this netblock in the ignore list, then just
			-- skip it
			--
			IF FOUND THEN
				RAISE DEBUG 'Skipping ignored address %', ipaddr;
				CONTINUE;
			END IF;

			--
			-- Look for an is_single_address='Y', can_subnet='N' netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = 'Y' AND
				can_subnet = 'N' AND
				netblock_type = nb_type AND
				ip_universe_id = universe AND
				host(ip_address) = host(ipaddr);

			IF FOUND THEN
				RAISE DEBUG E'Located netblock:\n%',
					jsonb_pretty(to_jsonb(nb_rec));

				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);

				--
				-- Look to see if there's a layer3_network for the
				-- parent netblock
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.netblock_id = nb_rec.parent_netblock_id;

				IF FOUND THEN
					RAISE DEBUG E'Located layer3_network:\n%',
						jsonb_pretty(to_jsonb(layer3_rec));
				ELSE
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
			ELSE
				--
				-- If the parent netblock does not exist, then create it
				-- if we were passed the option to
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.ip_universe_id = universe AND
					n.netblock_type = nb_type AND
					is_single_address = 'N' AND
					can_subnet = 'N' AND
					n.ip_address >>= ipaddr;

				IF NOT FOUND THEN
					RAISE DEBUG 'Parent netblock with ip_address %, netblock_type %, ip_universe_id % not found',
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					WITH nb_ins AS (
						INSERT INTO netblock (
							ip_address,
							netblock_type,
							is_single_address,
							can_subnet,
							ip_universe_id,
							netblock_status
						) VALUES (
							network(ipaddr),
							nb_type,
							'N',
							'N',
							universe,
							'Allocated'
						) RETURNING *
					), l3_ins AS (
						INSERT INTO layer3_network(
							netblock_id
						)
						SELECT
							netblock_id
						FROM
							nb_ins
						RETURNING *
					)
					SELECT
						nb_ins.netblock_id,
						nb_ins.ip_address,
						l3_ins.layer3_network_id,
						NULL
					INTO layer3_rec
					FROM
						nb_ins,
						l3_ins;
				ELSIF layer3_rec.layer3_network_id IS NULL THEN
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--

					RAISE DEBUG 'layer3_network for parent netblock % not found (ip_address %, netblock_type %, ip_universe_id %)',
						layer3_rec.netblock_id,
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
				RAISE DEBUG E'Located layer3_network:\n%',
					jsonb_pretty(to_jsonb(layer3_rec));
				--
				-- Parents should be all set up now.  Insert the netblock
				--
				INSERT INTO netblock (
					ip_address,
					netblock_type,
					ip_universe_id,
					is_single_address,
					can_subnet,
					netblock_status
				) VALUES (
					ipaddr,
					nb_type,
					universe,
					'Y',
					'N',
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;

			--
			-- See if this netblock is directly on any network_interface, and
			-- delete it if force is set, otherwise skip it
			--
			ni_id_ary := ARRAY[]::integer[];

			SELECT 
				ni.network_interface_id,
				nin.netblock_id,
				ni.device_id
			INTO nin_rec
			FROM
				network_interface_netblock nin JOIN
				network_interface ni USING (network_interface_id)
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id != ni_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND 
					nin_rec.device_id = ni_rec.device_id
				)
				THEN
					--
					-- Remove the netblocks from the network_interfaces,
					-- but save them for later so that we can migrate them
					-- after we make sure the shared_netblock exists.
					--
					-- Also, append the network_inteface_id that we
					-- specifically care about, and we'll add them all
					-- below
					--
					WITH z AS (
						DELETE FROM
							network_interface_netblock
						WHERE
							netblock_id = nb_rec.netblock_id
						RETURNING network_interface_id
					)
					SELECT array_agg(network_interface_id) FROM
						(SELECT network_interface_id FROM z) v
					INTO ni_id_ary;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSE
						RAISE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;
					END IF;
				END IF;

			END IF;

			IF NOT(ni_id = ANY(ni_id_ary)) THEN
				ni_id_ary := array_append(ni_id_ary, ni_id);
			END IF;

			--
			-- See if this netblock already belongs to a shared_network
			--
			SELECT * FROM
				shared_netblock sn
			INTO sn_rec
			WHERE
				sn.netblock_id = nb_rec.netblock_id;

			IF FOUND THEN
				IF sn_rec.shared_netblock_protocol != protocol THEN
					RAISE 'Netblock % (%) is assigned to shared_network %, but the shared_network_protocol does not match (% vs. %)',
						nb_rec.netblock_id,
						nb_rec.ip_address,
						sn_rec.shared_netblock_id,
						sn_rec.shared_netblock_protocol,
						protocol;
				END IF;
			ELSE
				INSERT INTO shared_netblock (
					shared_netblock_protocol,
					netblock_id
				) VALUES (
					protocol,
					nb_rec.netblock_id
				) RETURNING * INTO sn_rec;
			END IF;

			--
			-- Add this to any interfaces that we found above that
			-- need this
			--

			INSERT INTO shared_netblock_network_int (
				shared_netblock_id,
				network_interface_id,
				priority
			) SELECT
				sn_rec.shared_netblock_id,
				x.network_interface_id,
				0
			FROM
				unnest(ni_id_ary) x(network_interface_id)
			ON CONFLICT ON CONSTRAINT pk_ip_group_network_interface DO NOTHING;

			RAISE DEBUG E'Inserted shared_netblock % onto interfaces:\n%',
				sn_rec.shared_netblock_id, jsonb_pretty(to_jsonb(ni_id_ary));
		END LOOP;
		--
		-- Remove any shared_netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR nin_rec IN
			DELETE FROM
				shared_netblock_network_int snni
			WHERE
				(snni.network_interface_id, snni.shared_netblock_id) IN (
				SELECT
					snni2.network_interface_id,
					snni2.shared_netblock_id
				FROM
					shared_netblock_network_int snni2 JOIN
					shared_netblock sn USING (shared_netblock_id) JOIN
					netblock n USING (netblock_id)
				WHERE
					snni2.network_interface_id = ni_id AND NOT (
						sn.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_coll_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_nblk_coll_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed shared_netblock % from network_interface %',
				nin_rec.shared_netblock_id,
				nin_rec.network_interface_id;

			--
			-- Remove any DNS records, netblocks and shared_netblocks
			-- that aren't used
			--
			SELECT netblock_id INTO nb_id FROM shared_netblock sn WHERE
				sn.shared_netblock_id = nin_rec.shared_netblock_id;
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = nb_id;
				DELETE FROM netblock_collection_netblock ncn WHERE
					ncn.netblock_id = nb_id;
				DELETE FROM shared_netblock WHERE netblock_id = nb_id;
				DELETE FROM netblock WHERE netblock_id = nb_id;
			EXCEPTION
				WHEN foreign_key_violation THEN NULL;
			END;
		END LOOP;
	END IF;
	RETURN true;
END;
$function$
;

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
-- New function
CREATE OR REPLACE FUNCTION account_collection_manip.cleanup_account_collection_account(lifespan interval DEFAULT NULL::interval)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	rv	INTEGER;
BEGIN
	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_collection_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		lifespan := '1 year'::interval;
	END IF;

	--
	-- It is possible that this will fail if there are surprise foreign
	-- keys to the accounts.
	--
	EXECUTE '
		WITH x AS (
			SELECT account_collection_id, account_id
			FROM    account a
				JOIN account_collection_account aca USING (account_id)
				JOIN account_collection ac USING (account_collection_id)
				JOIN person_company pc USING (person_id, company_id)
			WHERE   pc.termination_date IS NOT NULL
			AND     pc.termination_date < now() - $1::interval
			AND	coalesce(aca.data_upd_date, aca.data_ins_date) < pc.termination_date
			AND     account_collection_type != $2
			AND
				(account_collection_id, account_id)  NOT IN
					( SELECT unix_group_acct_collection_id, account_id from
						account_unix_info)
			AND account_collection_id NOT IN (
				SELECT account_collection_id
				FROM account_collection
				WHERE account_collection_type = ''department''
			)
			) DELETE FROM account_collection_account aca
			WHERE (account_collection_id, account_id) IN
				(SELECT account_collection_id, account_id FROM x)
		' USING lifespan, 'per-account';
	GET DIAGNOSTICS rv = ROW_COUNT;
	RETURN rv;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION account_collection_manip.purge_inactive_account_collections(lifespan interval DEFAULT NULL::interval, raise_exception boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_r	RECORD;
	i	INTEGER;
	rv	INTEGER;
BEGIN
	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_collection_purge_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;
	IF lifespan IS NULL THEN
		lifespan := '1 year'::interval;
	END IF;

	--
	-- remove unused account collections
	--
	rv := 0;
	FOR _r IN
		SELECT ac.*
		FROM	account_collection ac
			JOIN val_account_collection_type act USING (account_collection_type)
		WHERE	now() -
			coalesce(ac.data_upd_date,ac.data_ins_date) > lifespan::interval
		AND	act.is_infrastructure_type = 'N'
		AND	account_collection_id NOT IN
			(SELECT child_account_collection_id FROM account_collection_hier)
		AND	account_collection_id NOT IN
			(SELECT account_collection_id FROM account_collection_hier)
		AND	account_collection_id NOT IN
			(SELECT account_collection_id FROM account_collection_account)
		AND	account_collection_id NOT IN
			(SELECT account_collection_id FROM property
				WHERE account_collection_id IS NOT NULL)
		AND	account_collection_id NOT IN
			(SELECT property_value_account_coll_id FROM property
				WHERE property_value_account_coll_id IS NOT NULL)
	LOOP
		BEGIN
			DELETE FROM account_collection
				WHERE account_collection_id = _r.account_collection_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	RETURN rv;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION account_collection_manip.purge_inactive_department_properties(property_type character varying, property_name character varying DEFAULT NULL::character varying, lifespan interval DEFAULT NULL::interval, raise_exception boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r	RECORD;
	rv	INTEGER;
	i	INTEGER;
	_pn	TEXT;
	_pt TEXT;
BEGIN
	_pn := property_name;
	_pt := property_type;
	rv := 0;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_collection_purge_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;
	IF lifespan IS NULL THEN
		lifespan := '1 year'::interval;
	END IF;

	--
	-- delete login assignment to linux machines for departments that are
	-- disabled and not in use
	--
	FOR _r IN SELECT	p.property_id
			FROM	account_collection ac
				JOIN department d USING (account_collection_id)
				JOIN property p USING (account_collection_id)
			WHERE 	d.is_active = 'N'
			AND ((_pn IS NOT NULL AND _pn = p.property_name) OR _pn IS NULL )
			AND	p.property_type = _pt
			AND	account_collection_id NOT IN (
					SELECT child_account_collection_id
					FROM account_collection_hier
				)
			AND	account_collection_id NOT IN (
					SELECT account_collection_id
					FROM account_collection_account
				)
			AND account_collection_id NOT IN (
				SELECT account_collection_id
				FROM	account_collection ac
					JOIN department d USING (account_collection_id)
					JOIN (
						SELECT level, v.account_collection_id,
							ac.account_collection_id as child_account_collection_id,
							account_collection_name as name,
							account_collection_type as type
						FROM	v_acct_coll_expanded 	 v
							JOIN account_collection ac ON v.root_account_collection_id = ac.account_collection_id
							JOIN department d ON ac.account_collection_id = d.account_collection_id
						WHERE	is_active = 'Y'
					) kid USING (account_collection_id)
				WHERE
					is_active = 'N'
			)
	LOOP
		BEGIN
			DELETE FROM property
			WHERE property_id = _r.property_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;


	--
	-- delete unix group overrides to linux machines for departments that are
	-- disabled and not in use
	--
	FOR _r IN SELECT	p.property_id
			FROM	account_collection ac
				JOIN department d USING (account_collection_id)
				JOIN property p ON p.property_value_account_coll_id =
					ac.account_collection_id
			WHERE 	d.is_active = 'N'
			AND ((_pn IS NOT NULL AND _pn = p.property_name) OR _pn IS NULL )
			AND	p.property_type = _pt
			AND	p.property_value_account_coll_id NOT IN (
					SELECT child_account_collection_id
					FROM account_collection_hier
				)
			AND	p.property_value_account_coll_id NOT IN (
					SELECT account_collection_id
					FROM account_collection_account
						JOIN account a USING (account_id)
					WHERE a.is_enabled = 'Y'
				)
			AND p.property_value_account_coll_id NOT IN (
				SELECT account_collection_id
				FROM	account_collection ac
					JOIN department d USING (account_collection_id)
					JOIN (
						SELECT level, v.account_collection_id,
							ac.account_collection_id as child_account_collection_id,
							account_collection_name as name,
							account_collection_type as type
						FROM	v_acct_coll_expanded 	 v
							JOIN account_collection ac ON v.root_account_collection_id = ac.account_collection_id
							JOIN department d ON ac.account_collection_id = d.account_collection_id
						WHERE	is_active = 'Y'
					) kid USING (account_collection_id)
				WHERE
					is_active = 'N'
			)
	LOOP
		BEGIN
			DELETE FROM property
			WHERE property_id = _r.property_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	RETURN rv;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION account_collection_manip.purge_inactive_departments(lifespan interval DEFAULT NULL::interval, raise_exception boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_r	RECORD;
	rv	INTEGER;
	i	INTEGER;
BEGIN
	rv := 0;
	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_collection_purge_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;
	IF lifespan IS NULL THEN
		lifespan := '1 year'::interval;
	END IF;

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'UnixLogin',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'MclassUnixProp',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'StabRole',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'Defaults',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'API',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'DeviceInventory',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'PhoneDirectoryAttributes',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	--
	-- remove child account collection membership
	--
	FOR _r IN SELECT	ac.*
			FROM	account_collection ac
				JOIN department d USING (account_collection_id)
			WHERE	d.is_active = 'N'
			AND	account_collection_id IN (
				SELECT child_account_collection_id FROM account_collection_hier
			)
			AND account_collection_id NOT IN (
				SELECT account_collection_id
				FROM	account_collection ac
					JOIN department d USING (account_collection_id)
					JOIN (
						SELECT level, v.account_collection_id,
							ac.account_collection_id as child_account_collection_id,
							account_collection_name as name,
							account_collection_type as type
						FROM	v_acct_coll_expanded 	 v
							JOIN account_collection ac ON v.root_account_collection_id = ac.account_collection_id
							JOIN department d ON ac.account_collection_id = d.account_collection_id
						WHERE	is_active = 'Y'
					) kid USING (account_collection_id)
				WHERE
					is_active = 'N'
			)

	LOOP
		BEGIN
			DELETE FROM account_collection_hier
				WHERE child_account_collection_id = _r.account_collection_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	RETURN rv;

END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION account_collection_manip.routine_account_collection_cleanup(lifespan interval DEFAULT NULL::interval, raise_exception boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	rv INTEGER;
	c INTEGER;
BEGIN
	select account_collection_manip.cleanup_account_collection_account(lifespan) INTO c;
	rv := c;
	select account_collection_manip.purge_inactive_departments(lifespan, raise_exception) INTO c;

	rv := rv + c;
	select account_collection_manip.purge_inactive_account_collections(lifespan, raise_exception) INTO c;
	rv := rv + c;
	RETURN rv;
END;
$function$
;

--
-- Process middle (non-trigger) schema script_hooks
--
--
-- Process middle (non-trigger) schema backend_utils
--
--
-- Process middle (non-trigger) schema rack_utils
--
--
-- Process middle (non-trigger) schema schema_support
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_diff');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_diff ( schema text, old_rel text, new_rel text, key_relation text, prikeys text[], raise_exception boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_diff(schema text, old_rel text, new_rel text, key_relation text DEFAULT NULL::text, prikeys text[] DEFAULT NULL::text[], raise_exception boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
	_or	RECORD;
	_nr	RECORD;
	_t1	integer;
	_t2	integer;
	_cols TEXT[];
	_q TEXT;
	_f TEXT;
	_c RECORD;
	_w TEXT[];
	_ctl TEXT[];
	_rv	boolean;
	_k	TEXT;
	oj	jsonb;
	nj	jsonb;
BEGIN
	-- do a simple row count
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || old_rel || '"' INTO _t1;
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || new_rel || '"' INTO _t2;

	_rv := true;

	IF _t1 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, old_rel;
		_rv := false;
	END IF;
	IF _t2 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, new_rel;
		_rv := false;
	END IF;

	IF _t1 != _t2 THEN
		RAISE NOTICE 'table % has % rows; table % has % rows', old_rel, _t1, new_rel, _t2;
		_rv := false;
	END IF;

	IF NOT _rv THEN
		IF raise_exception THEN
			RAISE EXCEPTION 'Relations do not match';
		END IF;
		RETURN false;
	END IF;

	IF prikeys IS NULL THEN
		-- read into prikeys the primary key for the table
		IF key_relation IS NULL THEN
			key_relation := old_rel;
		END IF;
		prikeys := schema_support.get_pk_columns(schema, key_relation);
	END IF;

	-- read into _cols the column list in common between old_rel and new_rel
	_cols := schema_support.get_common_columns(schema, old_rel, new_rel);

	FOREACH _f IN ARRAY _cols
	LOOP
		SELECT array_append(_ctl,
			quote_ident(_f) || '::text') INTO _ctl;
	END LOOP;

	_cols := _ctl;

	_q := 'SELECT '|| array_to_string(_cols,',') ||' FROM ' || quote_ident(schema) || '.' ||
		quote_ident(old_rel);

	FOR _or IN EXECUTE _q
	LOOP
		_w = NULL;
		FOREACH _f IN ARRAY prikeys
		LOOP
			FOR _c IN SELECT * FROM json_each_text( row_to_json(_or) )
			LOOP
				IF _c.key = _f THEN
					SELECT array_append(_w,
						quote_ident(_f) || '::text = ' || quote_literal(_c.value))
					INTO _w;
				END IF;
			END LOOP;
		END LOOP;
		_q := 'SELECT ' || array_to_string(_cols,',') ||
			' FROM ' || quote_ident(schema) || '.' ||
			quote_ident(new_rel) || ' WHERE ' ||
			array_to_string(_w, ' AND ' );
		EXECUTE _q INTO _nr;

		IF _or != _nr THEN
			oj = row_to_json(_or);
			nj = row_to_json(_nr);
			FOR _k IN SELECT jsonb_object_keys(oj)
			LOOP
				IF NOT _k = ANY(prikeys) AND oj->>_k IS NOT DISTINCT FROM nj->>_k THEN
					oj = oj - _k;
					nj = nj - _k;
				END IF;
			END LOOP;
			RAISE NOTICE 'mismatched row:';
			RAISE NOTICE 'NEW: %', nj;
			RAISE NOTICE 'OLD: %', oj;
			_rv := false;
		END IF;

	END LOOP;

	IF NOT _rv AND raise_exception THEN
		RAISE EXCEPTION 'Relations do not match';
	END IF;
	return _rv;
END;
$function$
;

--
-- Process middle (non-trigger) schema layerx_network_manip
--
-- Creating new sequences....


--------------------------------------------------------------------
-- DEALING WITH TABLE val_network_range_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_network_range_type', 'val_network_range_type');

-- FOREIGN KEYS FROM
ALTER TABLE network_range DROP CONSTRAINT IF EXISTS fk_netrng_netrng_typ;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_valnetrng_val_prop;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_network_range_type DROP CONSTRAINT IF EXISTS fk_netrange_type_nb_type;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_network_range_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_network_range_type DROP CONSTRAINT IF EXISTS pk_val_network_range_type;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1val_network_range_type";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_network_range_type DROP CONSTRAINT IF EXISTS check_prp_prmt_nrngty_ddom;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_network_range_type ON jazzhands.val_network_range_type;
DROP TRIGGER IF EXISTS trigger_audit_val_network_range_type ON jazzhands.val_network_range_type;
DROP TRIGGER IF EXISTS trigger_validate_val_network_range_type ON jazzhands.val_network_range_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_network_range_type');
---- BEGIN audit.val_network_range_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_network_range_type', 'val_network_range_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_network_range_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.val_network_range_type DROP CONSTRAINT IF EXISTS val_network_range_type_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_val_network_range_type_pk_val_network_range_type";
DROP INDEX IF EXISTS "audit"."val_network_range_type_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."val_network_range_type_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."val_network_range_type_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_network_range_type TEARDOWN


ALTER TABLE val_network_range_type RENAME TO val_network_range_type_v83;
ALTER TABLE audit.val_network_range_type RENAME TO val_network_range_type_v83;

CREATE TABLE val_network_range_type
(
	network_range_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	dns_domain_required	character(10) NOT NULL,
	default_dns_prefix	varchar(50)  NULL,
	netblock_type	varchar(50)  NULL,
	can_overlap	character(1) NOT NULL,
	require_cidr_boundary	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_network_range_type', false);
ALTER TABLE val_network_range_type
	ALTER dns_domain_required
	SET DEFAULT 'REQUIRED'::bpchar;
ALTER TABLE val_network_range_type
	ALTER can_overlap
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_network_range_type
	ALTER require_cidr_boundary
	SET DEFAULT 'N'::bpchar;
INSERT INTO val_network_range_type (
	network_range_type,
	description,
	dns_domain_required,
	default_dns_prefix,
	netblock_type,
	can_overlap,		-- new column (can_overlap)
	require_cidr_boundary,		-- new column (require_cidr_boundary)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	network_range_type,
	description,
	dns_domain_required,
	default_dns_prefix,
	netblock_type,
	'N'::bpchar,		-- new column (can_overlap)
	'N'::bpchar,		-- new column (require_cidr_boundary)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_network_range_type_v83;

INSERT INTO audit.val_network_range_type (
	network_range_type,
	description,
	dns_domain_required,
	default_dns_prefix,
	netblock_type,
	can_overlap,		-- new column (can_overlap)
	require_cidr_boundary,		-- new column (require_cidr_boundary)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	network_range_type,
	description,
	dns_domain_required,
	default_dns_prefix,
	netblock_type,
	NULL,		-- new column (can_overlap)
	NULL,		-- new column (require_cidr_boundary)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.val_network_range_type_v83;

ALTER TABLE val_network_range_type
	ALTER dns_domain_required
	SET DEFAULT 'REQUIRED'::bpchar;
ALTER TABLE val_network_range_type
	ALTER can_overlap
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_network_range_type
	ALTER require_cidr_boundary
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_network_range_type ADD CONSTRAINT pk_val_network_range_type PRIMARY KEY (network_range_type);

-- Table/Column Comments
COMMENT ON COLUMN val_network_range_type.dns_domain_required IS 'indicates how dns_domain_id is required on network_range (thus a NOT NULL constraint)';
COMMENT ON COLUMN val_network_range_type.default_dns_prefix IS 'default dns prefix for ranges of this type, can be overridden in network_range.   Required if dns_domain_required is set.';
-- INDEXES
CREATE INDEX xif_netrange_type_nb_type ON val_network_range_type USING btree (netblock_type);

-- CHECK CONSTRAINTS
ALTER TABLE val_network_range_type ADD CONSTRAINT check_prp_prmt_nrngty_ddom
	CHECK (dns_domain_required = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_network_range_type ADD CONSTRAINT check_yes_no_canoverlap
	CHECK (can_overlap = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_network_range_type ADD CONSTRAINT check_yes_no_cidrboundary
	CHECK (require_cidr_boundary = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between val_network_range_type and network_range
ALTER TABLE network_range
	ADD CONSTRAINT fk_netrng_netrng_typ
	FOREIGN KEY (network_range_type) REFERENCES val_network_range_type(network_range_type);
-- consider FK between val_network_range_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_valnetrng_val_prop
	FOREIGN KEY (network_range_type) REFERENCES val_network_range_type(network_range_type);

-- FOREIGN KEYS TO
-- consider FK val_network_range_type and val_netblock_type
ALTER TABLE val_network_range_type
	ADD CONSTRAINT fk_netrange_type_nb_type
	FOREIGN KEY (netblock_type) REFERENCES val_netblock_type(netblock_type);

-- TRIGGERS
-- consider NEW jazzhands.validate_net_range_toggle_nonoverlap
CREATE OR REPLACE FUNCTION jazzhands.validate_net_range_toggle_nonoverlap()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally INTEGER;
BEGIN
	IF NEW.can_overlap = 'N' THEN
		SELECT COUNT(*)
		INTO _tally
		FROM (
				SELECT nr.*, host(start.ip_address)::inet AS start_ip,
					host(stop.ip_address)::inet AS stop_ip
				FROM network_range nr
				JOIN netblock start ON start.netblock_id = nr.start_netblock_id
				JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
			) n1 JOIN (
				SELECT nr.*, host(start.ip_address)::inet AS start_ip,
					host(stop.ip_address)::inet AS stop_ip
				FROM network_range nr
				JOIN netblock start ON start.netblock_id = nr.start_netblock_id
				JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
			) n2 USING (network_range_type)
		WHERE n1.network_range_id != n2.network_range_id
		AND network_range_type = NEW.network_range_type
		AND (
			( n1.start_ip >= n2.start_ip AND n1.start_ip <= n2.stop_ip)
			OR
			( n1.stop_ip >= n2.start_ip AND n1.stop_ip <= n2.stop_ip)
		);

		IF _tally > 0 THEN
			RAISE EXCEPTION '% has % overlapping network ranges',
				NEW.network_range_type, _tally
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	IF NEW.require_cidr_boundary = 'Y' THEN
		SELECT COUNT(*)
		INTO _tally
		FROM (
				SELECT nr.*, host(start.ip_address)::inet AS start_ip,
					host(stop.ip_address)::inet AS stop_ip
				FROM network_range nr
				JOIN netblock start ON start.netblock_id = nr.start_netblock_id
				JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
			) nr
		WHERE network_range_type = NEW.network_range_type
		AND (
			masklen(start_ip) != masklen(stop_ip)
			OR
			start_ip != network(start_ip)
			OR
			stop_ip != broadcast(stop_ip)
		);

		IF _tally > 0 THEN
			RAISE EXCEPTION '% has % cidr issues in network ranges',
				NEW.network_range_type, _tally
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	RETURN NEW;
END; $function$
;
CREATE CONSTRAINT TRIGGER trigger_validate_net_range_toggle_nonoverlap AFTER UPDATE OF can_overlap, require_cidr_boundary ON val_network_range_type DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE validate_net_range_toggle_nonoverlap();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.validate_val_network_range_type
CREATE OR REPLACE FUNCTION jazzhands.validate_val_network_range_type()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.dns_domain_required = 'REQUIRED' THEN
		PERFORM
		FROM	network_range
		WHERE	network_range_type = NEW.network_range_type
		AND		dns_domain_id IS NULL;

		IF FOUND THEN
			RAISE EXCEPTION 'dns_domain_id is not set on some ranges'
				USING ERRCODE = 'not_null_violation';
		END IF;
	ELSIF NEW.dns_domain_required = 'PROHIBITED' THEN
		PERFORM
		FROM	network_range
		WHERE	network_range_type = NEW.network_range_type
		AND		dns_domain_id IS NOT NULL;

		IF FOUND THEN
			RAISE EXCEPTION 'dns_domain_id is set on some ranges'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	IF NEW.netblock_type IS NOT NULL THEN
		PERFORM
		FROM	netblock_range nr
				JOIN netblock start ON start.netblock_id = nr.start_netblock_id
				JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
		WHERE	nr.network_range_type = NEW.network_range_type
				(
					start.netblock_type != NEW.netblock_type
					OR		stop.netblock_type != NEW.netblock_type
				);

		IF FOUND THEN
			RAISE EXCEPTION 'netblock type is not set to % on some % ranges',
				NEW.netblock_type, NEW.network_range_type
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	RETURN NEW;
END; $function$
;
CREATE CONSTRAINT TRIGGER trigger_validate_val_network_range_type AFTER UPDATE OF dns_domain_required, netblock_type ON val_network_range_type DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE validate_val_network_range_type();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_network_range_type');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'val_network_range_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_network_range_type');
DROP TABLE IF EXISTS val_network_range_type_v83;
DROP TABLE IF EXISTS audit.val_network_range_type_v83;
-- DONE DEALING WITH TABLE val_network_range_type
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE network_interface
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'network_interface', 'network_interface');

-- FOREIGN KEYS FROM
ALTER TABLE network_interface_netblock DROP CONSTRAINT IF EXISTS fk_netint_nb_nblk_id;
ALTER TABLE network_interface_purpose DROP CONSTRAINT IF EXISTS fk_netint_purp_dev_ni_id;
ALTER TABLE network_service DROP CONSTRAINT IF EXISTS fk_netsvc_netint_id;
ALTER TABLE shared_netblock_network_int DROP CONSTRAINT IF EXISTS fk_shrdnet_netint_netint_id;
ALTER TABLE static_route_template DROP CONSTRAINT IF EXISTS fk_static_rt_net_interface;
ALTER TABLE static_route DROP CONSTRAINT IF EXISTS fk_statrt_netintdst_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_net_int_lgl_port_id;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_net_int_phys_port_id;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_device_id;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_netinttyp_id;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_ref_parentnetint;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_slot_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'network_interface');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ak_net_int_devid_netintid;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS fk_netint_devid_name;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS pk_network_interface_id;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_netint_isifaceup";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_provides_dhcp";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_providesnat";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_shouldmange";
DROP INDEX IF EXISTS "jazzhands"."idx_netint_shouldmonitor";
DROP INDEX IF EXISTS "jazzhands"."xif_net_int_lgl_port_id";
DROP INDEX IF EXISTS "jazzhands"."xif_net_int_phys_port_id";
DROP INDEX IF EXISTS "jazzhands"."xif_netint_netdev_id";
DROP INDEX IF EXISTS "jazzhands"."xif_netint_parentnetint";
DROP INDEX IF EXISTS "jazzhands"."xif_netint_slot_id";
DROP INDEX IF EXISTS "jazzhands"."xif_netint_typeid";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS check_any_yes_no_1926994056;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_is_interface_up_network_;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_netint_parent_r_1604677531;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_provides_dhcp_network_;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_provides_nat_network_;
ALTER TABLE jazzhands.network_interface DROP CONSTRAINT IF EXISTS ckc_should_manage_network_;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_network_interface ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_audit_network_interface ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_net_int_device_id_upd ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins_before ON jazzhands.network_interface;
DROP TRIGGER IF EXISTS trigger_net_int_physical_id_to_slot_id_enforce ON jazzhands.network_interface;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'network_interface');
---- BEGIN audit.network_interface TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'network_interface', 'network_interface');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'network_interface');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.network_interface DROP CONSTRAINT IF EXISTS network_interface_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_network_interface_ak_net_int_devid_netintid";
DROP INDEX IF EXISTS "audit"."aud_network_interface_fk_netint_devid_name";
DROP INDEX IF EXISTS "audit"."aud_network_interface_pk_network_interface_id";
DROP INDEX IF EXISTS "audit"."network_interface_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."network_interface_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."network_interface_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.network_interface TEARDOWN


ALTER TABLE network_interface RENAME TO network_interface_v83;
ALTER TABLE audit.network_interface RENAME TO network_interface_v83;

CREATE TABLE network_interface
(
	network_interface_id	integer NOT NULL,
	device_id	integer NOT NULL,
	network_interface_name	varchar(255)  NULL,
	description	varchar(255)  NULL,
	parent_network_interface_id	integer  NULL,
	parent_relation_type	varchar(255)  NULL,
	physical_port_id	integer  NULL,
	slot_id	integer  NULL,
	logical_port_id	integer  NULL,
	network_interface_type	varchar(50) NOT NULL,
	is_interface_up	character(1) NOT NULL,
	mac_addr	macaddr  NULL,
	should_monitor	varchar(255) NOT NULL,
	should_manage	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'network_interface', false);
ALTER TABLE network_interface
	ALTER network_interface_id
	SET DEFAULT nextval('network_interface_network_interface_id_seq'::regclass);
ALTER TABLE network_interface
	ALTER is_interface_up
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE network_interface
	ALTER should_monitor
	SET DEFAULT 'Y'::character varying;
ALTER TABLE network_interface
	ALTER should_manage
	SET DEFAULT 'Y'::bpchar;
INSERT INTO network_interface (
	network_interface_id,
	device_id,
	network_interface_name,
	description,
	parent_network_interface_id,
	parent_relation_type,
	physical_port_id,
	slot_id,
	logical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	should_manage,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	network_interface_id,
	device_id,
	network_interface_name,
	description,
	parent_network_interface_id,
	parent_relation_type,
	physical_port_id,
	slot_id,
	logical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	should_manage,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM network_interface_v83;

INSERT INTO audit.network_interface (
	network_interface_id,
	device_id,
	network_interface_name,
	description,
	parent_network_interface_id,
	parent_relation_type,
	physical_port_id,
	slot_id,
	logical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	should_manage,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	network_interface_id,
	device_id,
	network_interface_name,
	description,
	parent_network_interface_id,
	parent_relation_type,
	physical_port_id,
	slot_id,
	logical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	should_manage,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.network_interface_v83;

ALTER TABLE network_interface
	ALTER network_interface_id
	SET DEFAULT nextval('network_interface_network_interface_id_seq'::regclass);
ALTER TABLE network_interface
	ALTER is_interface_up
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE network_interface
	ALTER should_monitor
	SET DEFAULT 'Y'::character varying;
ALTER TABLE network_interface
	ALTER should_manage
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE network_interface ADD CONSTRAINT ak_net_int_devid_netintid UNIQUE (network_interface_id, device_id);
ALTER TABLE network_interface ADD CONSTRAINT fk_netint_devid_name UNIQUE (device_id, network_interface_name);
ALTER TABLE network_interface ADD CONSTRAINT pk_network_interface_id PRIMARY KEY (network_interface_id);

-- Table/Column Comments
COMMENT ON COLUMN network_interface.physical_port_id IS 'historical column to be dropped in the next release after tools use slot_id.  matches slot_id by trigger.';
COMMENT ON COLUMN network_interface.slot_id IS 'to be dropped after transition to logical_ports are complete.';
-- INDEXES
CREATE INDEX idx_netint_isifaceup ON network_interface USING btree (is_interface_up);
CREATE INDEX idx_netint_shouldmange ON network_interface USING btree (should_manage);
CREATE INDEX idx_netint_shouldmonitor ON network_interface USING btree (should_monitor);
CREATE INDEX xif_net_int_lgl_port_id ON network_interface USING btree (logical_port_id);
CREATE INDEX xif_net_int_phys_port_id ON network_interface USING btree (physical_port_id);
CREATE INDEX xif_netint_netdev_id ON network_interface USING btree (device_id);
CREATE INDEX xif_netint_parentnetint ON network_interface USING btree (parent_network_interface_id);
CREATE INDEX xif_netint_slot_id ON network_interface USING btree (slot_id);
CREATE INDEX xif_netint_typeid ON network_interface USING btree (network_interface_type);

-- CHECK CONSTRAINTS
ALTER TABLE network_interface ADD CONSTRAINT check_any_yes_no_1926994056
	CHECK ((should_monitor)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying, 'ANY'::character varying])::text[]));
ALTER TABLE network_interface ADD CONSTRAINT ckc_is_interface_up_network_
	CHECK ((is_interface_up = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_interface_up)::text = upper((is_interface_up)::text)));
ALTER TABLE network_interface ADD CONSTRAINT ckc_netint_parent_r_1604677531
	CHECK ((parent_relation_type)::text = ANY ((ARRAY['NONE'::character varying, 'SUBINTERFACE'::character varying, 'SECONDARY'::character varying])::text[]));
ALTER TABLE network_interface ADD CONSTRAINT ckc_should_manage_network_
	CHECK ((should_manage = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_manage)::text = upper((should_manage)::text)));

-- FOREIGN KEYS FROM
-- consider FK between network_interface and network_interface_netblock
ALTER TABLE network_interface_netblock
	ADD CONSTRAINT fk_netint_nb_nblk_id
	FOREIGN KEY (network_interface_id, device_id) REFERENCES network_interface(network_interface_id, device_id) DEFERRABLE;
-- consider FK between network_interface and network_interface_purpose
ALTER TABLE network_interface_purpose
	ADD CONSTRAINT fk_netint_purp_dev_ni_id
	FOREIGN KEY (network_interface_id, device_id) REFERENCES network_interface(network_interface_id, device_id);
-- consider FK between network_interface and network_service
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);
-- consider FK between network_interface and shared_netblock_network_int
ALTER TABLE shared_netblock_network_int
	ADD CONSTRAINT fk_shrdnet_netint_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);
-- consider FK between network_interface and static_route_template
ALTER TABLE static_route_template
	ADD CONSTRAINT fk_static_rt_net_interface
	FOREIGN KEY (network_interface_dst_id) REFERENCES network_interface(network_interface_id);
-- consider FK between network_interface and static_route
ALTER TABLE static_route
	ADD CONSTRAINT fk_statrt_netintdst_id
	FOREIGN KEY (network_interface_dst_id) REFERENCES network_interface(network_interface_id);

-- FOREIGN KEYS TO
-- consider FK network_interface and logical_port
ALTER TABLE network_interface
	ADD CONSTRAINT fk_net_int_lgl_port_id
	FOREIGN KEY (logical_port_id) REFERENCES logical_port(logical_port_id);
-- consider FK network_interface and slot
ALTER TABLE network_interface
	ADD CONSTRAINT fk_net_int_phys_port_id
	FOREIGN KEY (physical_port_id) REFERENCES slot(slot_id);
-- consider FK network_interface and device
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK network_interface and val_network_interface_type
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_netinttyp_id
	FOREIGN KEY (network_interface_type) REFERENCES val_network_interface_type(network_interface_type);
-- consider FK network_interface and network_interface
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_ref_parentnetint
	FOREIGN KEY (parent_network_interface_id) REFERENCES network_interface(network_interface_id);
-- consider FK network_interface and slot
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_slot_id
	FOREIGN KEY (slot_id) REFERENCES slot(slot_id);

-- TRIGGERS
-- consider NEW jazzhands.net_int_device_id_upd
CREATE OR REPLACE FUNCTION jazzhands.net_int_device_id_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	UPDATE network_interface_netblock
	SET device_id = NEW.device_id
	WHERE	network_interface_id = NEW.network_interface_id;
	SET CONSTRAINTS fk_netint_nb_nblk_id IMMEDIATE;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_net_int_device_id_upd AFTER UPDATE OF device_id ON network_interface FOR EACH ROW EXECUTE PROCEDURE net_int_device_id_upd();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.net_int_nb_device_id_ins_before
CREATE OR REPLACE FUNCTION jazzhands.net_int_nb_device_id_ins_before()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	SET CONSTRAINTS fk_netint_nb_nblk_id DEFERRED;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_net_int_nb_device_id_ins_before BEFORE UPDATE OF device_id ON network_interface FOR EACH ROW EXECUTE PROCEDURE net_int_nb_device_id_ins_before();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.net_int_physical_id_to_slot_id_enforce
CREATE OR REPLACE FUNCTION jazzhands.net_int_physical_id_to_slot_id_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF TG_OP = 'UPDATE' AND  (NEW.slot_id IS DISTINCT FROM OLD.slot_ID AND
			NEW.physical_port_id IS DISTINCT FROM OLD.physical_port_id) THEN
		RAISE EXCEPTION 'Only slot_id should be updated.'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.physical_port_id IS NOT NULL AND NEW.slot_id IS NOT NULL THEN
			RAISE EXCEPTION 'Only slot_id should be set.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;

	IF TG_OP = 'UPDATE' THEN
		IF OLD.slot_id IS DISTINCT FROM NEW.slot_id THEN
			NEW.physical_port_id = NEW.slot_id;
		ELSIF OLD.physical_port_id IS DISTINCT FROM NEW.physical_port_id THEN
			NEW.slot_id = NEW.physical_port_id;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.slot_id IS NOT NULL THEN
			NEW.physical_port_id = NEW.slot_id;
		ELSIF NEW.physical_port_id IS NOT NULL THEN
			NEW.slot_id = NEW.physical_port_id;
		END IF;
	ELSE
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_net_int_physical_id_to_slot_id_enforce BEFORE INSERT OR UPDATE OF physical_port_id, slot_id ON network_interface FOR EACH ROW EXECUTE PROCEDURE net_int_physical_id_to_slot_id_enforce();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'network_interface');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'network_interface');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'network_interface');
ALTER SEQUENCE network_interface_network_interface_id_seq
	 OWNED BY network_interface.network_interface_id;
DROP TABLE IF EXISTS network_interface_v83;
DROP TABLE IF EXISTS audit.network_interface_v83;
-- DONE DEALING WITH TABLE network_interface
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_network_interface_trans
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_network_interface_trans', 'v_network_interface_trans');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_network_interface_trans');
DROP VIEW IF EXISTS jazzhands.v_network_interface_trans;
CREATE VIEW jazzhands.v_network_interface_trans AS
 WITH x AS (
         SELECT base.network_interface_id,
            base.device_id,
            base.network_interface_name,
            base.description,
            base.parent_network_interface_id,
            base.parent_relation_type,
            base.netblock_id,
            base.physical_port_id,
            base.slot_id,
            base.logical_port_id,
            base.network_interface_type,
            base.is_interface_up,
            base.mac_addr,
            base.should_monitor,
            base.should_manage,
            base.data_ins_user,
            base.data_ins_date,
            base.data_upd_user,
            base.data_upd_date
           FROM ( SELECT ni.network_interface_id,
                    ni.device_id,
                    ni.network_interface_name,
                    ni.description,
                    ni.parent_network_interface_id,
                    ni.parent_relation_type,
                    nin.netblock_id,
                    ni.physical_port_id,
                    ni.slot_id,
                    ni.logical_port_id,
                    ni.network_interface_type,
                    ni.is_interface_up,
                    ni.mac_addr,
                    ni.should_monitor,
                    ni.should_manage,
                    ni.data_ins_user,
                    ni.data_ins_date,
                    ni.data_upd_user,
                    ni.data_upd_date,
                    rank() OVER (PARTITION BY ni.network_interface_id ORDER BY nin.network_interface_rank) AS rnk
                   FROM network_interface ni
                     LEFT JOIN network_interface_netblock nin USING (network_interface_id)) base
          WHERE base.rnk = 1
        )
 SELECT x.network_interface_id,
    x.device_id,
    x.network_interface_name,
    x.description,
    x.parent_network_interface_id,
    x.parent_relation_type,
    x.netblock_id,
    x.physical_port_id,
    x.slot_id,
    x.logical_port_id,
    x.network_interface_type,
    x.is_interface_up,
    x.mac_addr,
    x.should_monitor,
    x.should_manage,
    x.data_ins_user,
    x.data_ins_date,
    x.data_upd_user,
    x.data_upd_date
   FROM x;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE type = 'view' AND object = 'v_network_interface_trans';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_network_interface_trans failed but that is ok';
				NULL;
			END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();
-- DONE DEALING WITH TABLE v_network_interface_trans
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_dev_col_root
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dev_col_root', 'v_dev_col_root');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_dev_col_root');
DROP VIEW IF EXISTS jazzhands.v_dev_col_root;
CREATE VIEW jazzhands.v_dev_col_root AS
 WITH x AS (
         SELECT c.device_collection_id AS leaf_id,
            c.device_collection_name AS leaf_name,
            c.device_collection_type AS leaf_type,
            p.device_collection_id AS root_id,
            p.device_collection_name AS root_name,
            p.device_collection_type AS root_type,
            dch.device_collection_level
           FROM device_collection c
             JOIN v_device_coll_hier_detail dch ON dch.device_collection_id = c.device_collection_id
             JOIN device_collection p ON dch.parent_device_collection_id = p.device_collection_id AND p.device_collection_type::text = c.device_collection_type::text
        )
 SELECT xx.root_id,
    xx.root_name,
    xx.root_type,
    xx.leaf_id,
    xx.leaf_name,
    xx.leaf_type
   FROM ( SELECT x.root_id,
            x.root_name,
            x.root_type,
            x.leaf_id,
            x.leaf_name,
            x.leaf_type,
            x.device_collection_level,
            row_number() OVER (PARTITION BY x.leaf_id ORDER BY x.device_collection_level DESC) AS rn
           FROM x) xx
  WHERE xx.rn = 1;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE type = 'view' AND object = 'v_dev_col_root';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_dev_col_root failed but that is ok';
				NULL;
			END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();
-- DONE DEALING WITH TABLE v_dev_col_root
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_component_summary
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_device_component_summary');
DROP VIEW IF EXISTS jazzhands.v_device_component_summary;
CREATE VIEW jazzhands.v_device_component_summary AS
 WITH cs AS (
         SELECT dc.device_id,
            count(*) FILTER (WHERE cp.component_property_type::text = 'CPU'::text AND cp.component_property_name::text = 'ProcessorCores'::text) AS cpu_count,
            sum(cp.property_value::bigint) FILTER (WHERE cp.component_property_type::text = 'CPU'::text AND cp.component_property_name::text = 'ProcessorCores'::text) AS core_count,
            count(*) FILTER (WHERE cp.component_property_type::text = 'memory'::text AND cp.component_property_name::text = 'MemorySize'::text) AS memory_count,
            sum(cp.property_value::bigint) FILTER (WHERE cp.component_property_type::text = 'memory'::text AND cp.component_property_name::text = 'MemorySize'::text) AS total_memory,
            count(*) FILTER (WHERE cp.component_property_type::text = 'disk'::text AND cp.component_property_name::text = 'DiskSize'::text) AS disk_count,
            ceil(sum(cp.property_value::bigint) FILTER (WHERE cp.component_property_type::text = 'disk'::text AND cp.component_property_name::text = 'DiskSize'::text) / 1073741824::numeric) || 'G'::text AS total_disk
           FROM v_device_components dc
             JOIN component c USING (component_id)
             JOIN component_property cp USING (component_type_id)
          GROUP BY dc.device_id
        ), cm AS (
         SELECT DISTINCT dc.device_id,
            ct.model AS cpu_model
           FROM v_device_components dc
             JOIN component c USING (component_id)
             JOIN component_type ct USING (component_type_id)
             JOIN component_type_component_func ctcf USING (component_type_id)
          WHERE ctcf.component_function::text = 'CPU'::text
        )
 SELECT cs.device_id,
    cm.cpu_model,
    cs.cpu_count,
    cs.core_count,
    cs.memory_count,
    cs.total_memory,
    cs.disk_count,
    cs.total_disk
   FROM cm
     JOIN cs USING (device_id);

DO $$

			BEGIN
				DELETE FROM __recreate WHERE type = 'view' AND object = 'v_device_component_summary';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_component_summary failed but that is ok';
				NULL;
			END;
$$;

-- DONE DEALING WITH TABLE v_device_component_summary
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_components_json
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_device_components_json');
DROP VIEW IF EXISTS jazzhands.v_device_components_json;
CREATE VIEW jazzhands.v_device_components_json AS
 WITH ctf AS (
         SELECT ctcf.component_type_id,
            array_agg(ctcf.component_function ORDER BY ctcf.component_function) AS functions
           FROM component_type_component_func ctcf
          GROUP BY ctcf.component_type_id
        ), cpu_info AS (
         SELECT c.component_id,
            jsonb_build_object('component_id', c.component_id, 'component_type_id', c.component_type_id, 'company_name', comp.company_name, 'model', ct.model, 'core_count', pc.property_value::bigint, 'processor_speed', ps.property_value, 'component_function', 'CPU') AS component_json
           FROM component c
             JOIN component_type ct USING (component_type_id)
             JOIN component_type_component_func ctcf USING (component_type_id)
             JOIN component_property pc ON ct.component_type_id = pc.component_type_id AND pc.component_property_name::text = 'ProcessorCores'::text AND pc.component_property_type::text = 'CPU'::text
             JOIN component_property ps ON ct.component_type_id = ps.component_type_id AND ps.component_property_name::text = 'ProcessorSpeed'::text AND ps.component_property_type::text = 'CPU'::text
             LEFT JOIN company comp USING (company_id)
          WHERE ctcf.component_function::text = 'CPU'::text
        ), disk_info AS (
         SELECT c.component_id,
            jsonb_build_object('component_id', c.component_id, 'component_type_id', c.component_type_id, 'company_name', comp.company_name, 'model', ct.model, 'serial_number', a.serial_number, 'size_bytes', ds.property_value::bigint, 'size', ceil(ds.property_value::bigint::numeric / 1073741824::numeric) || 'G'::text, 'protocol', dp.property_value, 'media_type', mt.property_value, 'component_function', 'disk') AS component_json
           FROM component c
             JOIN component_type ct USING (component_type_id)
             JOIN component_type_component_func ctcf USING (component_type_id)
             LEFT JOIN asset a USING (component_id)
             JOIN component_property ds ON ct.component_type_id = ds.component_type_id AND ds.component_property_name::text = 'DiskSize'::text AND ds.component_property_type::text = 'disk'::text
             JOIN component_property dp ON ct.component_type_id = dp.component_type_id AND dp.component_property_name::text = 'DiskProtocol'::text AND dp.component_property_type::text = 'disk'::text
             JOIN component_property mt ON ct.component_type_id = mt.component_type_id AND mt.component_property_name::text = 'MediaType'::text AND mt.component_property_type::text = 'disk'::text
             LEFT JOIN company comp USING (company_id)
          WHERE ctcf.component_function::text = 'disk'::text
        ), memory_info AS (
         SELECT c.component_id,
            jsonb_build_object('component_id', c.component_id, 'component_type_id', c.component_type_id, 'company_name', comp.company_name, 'model', ct.model, 'serial_number', a.serial_number, 'size', msize.property_value::bigint, 'speed', mspeed.property_value, 'component_function', 'memory') AS component_json
           FROM component c
             JOIN component_type ct USING (component_type_id)
             JOIN component_type_component_func ctcf USING (component_type_id)
             LEFT JOIN asset a USING (component_id)
             JOIN component_property msize ON ct.component_type_id = msize.component_type_id AND msize.component_property_name::text = 'MemorySize'::text AND msize.component_property_type::text = 'memory'::text
             JOIN component_property mspeed ON ct.component_type_id = mspeed.component_type_id AND mspeed.component_property_name::text = 'MemorySpeed'::text AND mspeed.component_property_type::text = 'memory'::text
             LEFT JOIN company comp USING (company_id)
          WHERE ctcf.component_function::text = 'memory'::text
        )
 SELECT dc.device_id,
    jsonb_agg(x.component_json) AS components
   FROM v_device_components dc
     JOIN ( SELECT cpu_info.component_id,
            cpu_info.component_json
           FROM cpu_info
        UNION
         SELECT disk_info.component_id,
            disk_info.component_json
           FROM disk_info
        UNION
         SELECT memory_info.component_id,
            memory_info.component_json
           FROM memory_info) x USING (component_id)
  GROUP BY dc.device_id;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE type = 'view' AND object = 'v_device_components_json';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_components_json failed but that is ok';
				NULL;
			END;
$$;

-- DONE DEALING WITH TABLE v_device_components_json
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
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
--
-- Process drops in jazzhands
--
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_trigger_change');
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_trigger_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM *
	FROM dns_domain_ip_universe
	WHERE dns_domain_id = NEW.dns_domain_id
	AND SHOULD_GENERATE = 'Y';
	IF FOUND THEN
		INSERT INTO dns_change_record
			(dns_domain_id) VALUES (NEW.dns_domain_id);
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'site_netblock_ins');
CREATE OR REPLACE FUNCTION jazzhands.site_netblock_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	WITH i AS (
		INSERT INTO netblock_collection_netblock
			(netblock_collection_id, netblock_id)
		SELECT netblock_collection_id, NEW.netblock_id
			FROM property
			WHERE property_type = 'automated'
			AND property_name = 'per-site-netblock_collection'
			AND site_code = NEW.site_code
		RETURNING *
	) SELECT count(*) INTO _tally FROM i;

	IF _tally != 1 THEN
		RAISE 'Inserted % rows, not 1. (%,%)', _tally, NEW.site_code, NEW.netblock_id;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'update_per_svc_env_svc_env_collection');
CREATE OR REPLACE FUNCTION jazzhands.update_per_svc_env_svc_env_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	secid		service_environment_collection.service_env_collection_id%TYPE;
BEGIN
	IF TG_OP = 'INSERT' THEN
		insert into service_environment_collection
			(service_env_collection_name, service_env_collection_type)
		values
			(NEW.service_environment_name, 'per-environment')
		RETURNING service_env_collection_id INTO secid;
		insert into svc_environment_coll_svc_env
			(service_env_collection_id, service_environment_id)
		VALUES
			(secid, NEW.service_environment_id);
	ELSIF TG_OP = 'UPDATE'  AND OLD.service_environment_id != NEW.service_environment_id THEN
		UPDATE	service_environment_collection
		   SET	service_env_collection_name = NEW.service_environment_name
		 WHERE	service_env_collection_name != NEW.service_environment_name
		   AND	service_env_collection_type = 'per-environment'
		   AND	service_env_collection_id in (
			SELECT	service_env_collection_id
			  FROM	svc_environment_coll_svc_env
			 WHERE	service_environment_id =
				NEW.service_environment_id
			);
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_network_interface_trans_ins');
CREATE OR REPLACE FUNCTION jazzhands.v_network_interface_trans_ins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_ni	network_interface%ROWTYPE;
BEGIN
	INSERT INTO network_interface (
                device_id,
		network_interface_name, description,
		parent_network_interface_id,
                parent_relation_type, physical_port_id,
		slot_id, logical_port_id,
		network_interface_type, is_interface_up,
		mac_addr, should_monitor,
                should_manage
	) VALUES (
                NEW.device_id,
                NEW.network_interface_name, NEW.description,
                NEW.parent_network_interface_id,
                NEW.parent_relation_type, NEW.physical_port_id,
                NEW.slot_id, NEW.logical_port_id,
                NEW.network_interface_type, NEW.is_interface_up,
                NEW.mac_addr, NEW.should_monitor,
                NEW.should_manage
	) RETURNING * INTO _ni;

	IF NEW.netblock_id IS NOT NULL THEN
		INSERT INTO network_interface_netblock (
			network_interface_id, netblock_id
		) VALUES (
			_ni.network_interface_id, NEW.netblock_id
		);
	END IF;

	NEW.network_interface_id := _ni.network_interface_id;
	NEW.device_id := _ni.device_id;
	NEW.network_interface_name := _ni.network_interface_name;
	NEW.description := _ni.description;
	NEW.parent_network_interface_id := _ni.parent_network_interface_id;
	NEW.parent_relation_type := _ni.parent_relation_type;
	NEW.physical_port_id := _ni.physical_port_id;
	NEW.slot_id := _ni.slot_id;
	NEW.logical_port_id := _ni.logical_port_id;
	NEW.network_interface_type := _ni.network_interface_type;
	NEW.is_interface_up := _ni.is_interface_up;
	NEW.mac_addr := _ni.mac_addr;
	NEW.should_monitor := _ni.should_monitor;
	NEW.should_manage := _ni.should_manage;
	NEW.data_ins_user :=_ni.data_ins_user;
	NEW.data_ins_date := _ni.data_ins_date;
	NEW.data_upd_user := _ni.data_upd_user;
	NEW.data_upd_date := _ni.data_upd_date;


	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_network_interface_trans_upd');
CREATE OR REPLACE FUNCTION jazzhands.v_network_interface_trans_upd()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	upd_query		TEXT[];
	_ni				network_interface%ROWTYPE;
BEGIN
	IF OLD.network_interface_id IS DISTINCT FROM NEW.network_interface_id THEN
		RAISE EXCEPTION 'May not update network_interface_id'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF OLD.netblock_id IS DISTINCT FROM NEW.netblock_id THEN
		IF OLD.netblock_id IS NULL THEN
			INSERT INTO network_interface_netblock (
				network_interface_id, netblock_id
			) VALUES (
				NEW.network_interface_id, NEW.netblock_id
			);
		ELSIF NEW.netblock_id IS NULL THEN
			DELETE FROM network_interface_netblock
			WHERE network_interface_id = OLD.network_interface_id
			AND netblock_id = OLD.netblock_id;

			WITH x AS (
				SELECT *,
				rank() OVER (PARTITION BY
					network_interface_id ORDER BY
					network_interface_rank) AS rnk
				FROM network_interface_netblock
				WHERE network_interface_id = NEW.network_interface_id
			) SELECT netblock_id
			INTO NEW.netblock_id
				FROM x
				WHERE x.rnk = 1;
		ELSE
			UPDATE network_interface_netblock
			SET netblock_id = NEW.netblock_id
			WHERE netblock_id = OLD.netblock_id
			AND network_interface_id = NEW.network_interface_id;
		END IF;
	END IF;

	upd_query := NULL;
		IF NEW.device_id IS DISTINCT FROM OLD.device_id THEN
			upd_query := array_append(upd_query,
				'device_id = ' || quote_nullable(NEW.device_id));
		END IF;
		IF NEW.network_interface_name IS DISTINCT FROM OLD.network_interface_name THEN
			upd_query := array_append(upd_query,
				'network_interface_name = ' || quote_nullable(NEW.network_interface_name));
		END IF;
		IF NEW.description IS DISTINCT FROM OLD.description THEN
			upd_query := array_append(upd_query,
				'description = ' || quote_nullable(NEW.description));
		END IF;
		IF NEW.parent_network_interface_id IS DISTINCT FROM OLD.parent_network_interface_id THEN
			upd_query := array_append(upd_query,
				'parent_network_interface_id = ' || quote_nullable(NEW.parent_network_interface_id));
		END IF;
		IF NEW.parent_relation_type IS DISTINCT FROM OLD.parent_relation_type THEN
			upd_query := array_append(upd_query,
				'parent_relation_type = ' || quote_nullable(NEW.parent_relation_type));
		END IF;
		IF NEW.physical_port_id IS DISTINCT FROM OLD.physical_port_id THEN
			upd_query := array_append(upd_query,
				'physical_port_id = ' || quote_nullable(NEW.physical_port_id));
		END IF;
		IF NEW.slot_id IS DISTINCT FROM OLD.slot_id THEN
			upd_query := array_append(upd_query,
				'slot_id = ' || quote_nullable(NEW.slot_id));
		END IF;
		IF NEW.logical_port_id IS DISTINCT FROM OLD.logical_port_id THEN
			upd_query := array_append(upd_query,
				'logical_port_id = ' || quote_nullable(NEW.logical_port_id));
		END IF;
		IF NEW.network_interface_type IS DISTINCT FROM OLD.network_interface_type THEN
			upd_query := array_append(upd_query,
				'network_interface_type = ' || quote_nullable(NEW.network_interface_type));
		END IF;
		IF NEW.is_interface_up IS DISTINCT FROM OLD.is_interface_up THEN
			upd_query := array_append(upd_query,
				'is_interface_up = ' || quote_nullable(NEW.is_interface_Up));
		END IF;
		IF NEW.mac_addr IS DISTINCT FROM OLD.mac_addr THEN
			upd_query := array_append(upd_query,
				'mac_addr = ' || quote_nullable(NEW.mac_addr));
		END IF;
		IF NEW.should_monitor IS DISTINCT FROM OLD.should_monitor THEN
			upd_query := array_append(upd_query,
				'should_monitor = ' || quote_nullable(NEW.should_monitor));
		END IF;
		IF NEW.should_manage IS DISTINCT FROM OLD.should_manage THEN
			upd_query := array_append(upd_query,
				'should_manage = ' || quote_nullable(NEW.should_manage));
		END IF;

		IF upd_query IS NOT NULL THEN
			EXECUTE 'UPDATE network_interface SET ' ||
				array_to_string(upd_query, ', ') ||
				' WHERE network_interface_id = $1 RETURNING *'
			USING OLD.network_interface_id
			INTO _ni;

			NEW.device_id := _ni.device_id;
			NEW.network_interface_name := _ni.network_interface_name;
			NEW.description := _ni.description;
			NEW.parent_network_interface_id := _ni.parent_network_interface_id;
			NEW.parent_relation_type := _ni.parent_relation_type;
			NEW.physical_port_id := _ni.physical_port_id;
			NEW.slot_id := _ni.slot_id;
			NEW.logical_port_id := _ni.logical_port_id;
			NEW.network_interface_type := _ni.network_interface_type;
			NEW.is_interface_up := _ni.is_interface_up;
			NEW.mac_addr := _ni.mac_addr;
			NEW.should_monitor := _ni.should_monitor;
			NEW.should_manage := _ni.should_manage;
			NEW.data_ins_user := _ni.data_ins_user;
			NEW.data_ins_date := _ni.data_ins_date;
			NEW.data_upd_user := _ni.data_upd_user;
			NEW.data_upd_date := _ni.data_upd_date;
		END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_component_property');
CREATE OR REPLACE FUNCTION jazzhands.validate_component_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally				INTEGER;
	v_comp_prop			RECORD;
	v_comp_prop_type	RECORD;
	v_num				bigint;
	v_listvalue			TEXT;
	component_attrs		RECORD;
BEGIN

	-- Pull in the data from the property and property_type so we can
	-- figure out what is and is not valid

	BEGIN
		SELECT * INTO STRICT v_comp_prop FROM val_component_property WHERE
			component_property_name = NEW.component_property_name AND
			component_property_type = NEW.component_property_type;

		SELECT * INTO STRICT v_comp_prop_type FROM val_component_property_type
			WHERE component_property_type = NEW.component_property_type;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE EXCEPTION
				'Component property name or type does not exist'
				USING ERRCODE = 'foreign_key_violation';
			RETURN NULL;
	END;

	-- Check to see if the property itself is multivalue.  That is, if only
	-- one value can be set for this property for a specific property LHS

	IF (v_comp_prop.is_multivalue != 'Y') THEN
		PERFORM 1 FROM component_property WHERE
			component_property_id != NEW.component_property_id AND
			component_property_name = NEW.component_property_name AND
			component_property_type = NEW.component_property_type AND
			component_type_id IS NOT DISTINCT FROM NEW.component_type_id AND
			component_function IS NOT DISTINCT FROM NEW.component_function AND
			component_id iS NOT DISTINCT FROM NEW.component_id AND
			slot_type_id IS NOT DISTINCT FROM NEW.slot_type_id AND
			slot_function IS NOT DISTINCT FROM NEW.slot_function AND
			slot_id IS NOT DISTINCT FROM NEW.slot_id;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property with name % and type % already exists for given LHS and property is not multivalue',
				NEW.component_property_name,
				NEW.component_property_type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- Check to see if the property type is multivalue.  That is, if only
	-- one property and value can be set for any properties with this type
	-- for a specific property LHS

	IF (v_comp_prop_type.is_multivalue != 'Y') THEN
		PERFORM 1 FROM component_property WHERE
			component_property_id != NEW.component_property_id AND
			component_property_type = NEW.component_property_type AND
			component_type_id IS NOT DISTINCT FROM NEW.component_type_id AND
			component_function IS NOT DISTINCT FROM NEW.component_function AND
			component_id iS NOT DISTINCT FROM NEW.component_id AND
			slot_type_id IS NOT DISTINCT FROM NEW.slot_type_id AND
			slot_function IS NOT DISTINCT FROM NEW.slot_function AND
			slot_id IS NOT DISTINCT FROM NEW.slot_id;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property % of type % already exists for given LHS and property type is not multivalue',
				NEW.component_property_name, NEW.component_property_type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- now validate the property_value columns.
	tally := 0;

	--
	-- first determine if the property_value is set properly.
	--

	-- at this point, tally will be set to 1 if one of the other property
	-- values is set to something valid.  Now, check the various options for
	-- PROPERTY_VALUE itself.  If a new type is added to the val table, this
	-- trigger needs to be updated or it will be considered invalid.  If a
	-- new PROPERTY_VALUE_* column is added, then it will pass through without
	-- trigger modification.  This should be considered bad.

	IF NEW.property_value IS NOT NULL THEN
		tally := tally + 1;
		IF v_comp_prop.property_data_type = 'boolean' THEN
			IF NEW.Property_Value != 'Y' AND NEW.Property_Value != 'N' THEN
				RAISE 'Boolean property_value must be Y or N' USING
					ERRCODE = 'invalid_parameter_value';
			END IF;
		ELSIF v_comp_prop.property_data_type = 'number' THEN
			BEGIN
				v_num := to_number(NEW.property_value, '9');
			EXCEPTION
				WHEN OTHERS THEN
					RAISE 'property_value must be numeric' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_comp_prop.property_data_type = 'list' THEN
			BEGIN
				SELECT valid_property_value INTO STRICT v_listvalue FROM
					val_component_property_value WHERE
						component_property_name = NEW.component_property_name AND
						component_property_type = NEW.component_property_type AND
						valid_property_value = NEW.property_value;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					RAISE 'property_value for component_property_name %, component_property_type % must be a valid value ("%")',
						NEW.component_property_name,
						NEW.component_property_type,
						NEW.property_value
						USING ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_comp_prop.property_data_type != 'string' THEN
			RAISE 'property_data_type is not a known type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.property_data_type != 'none' AND tally = 0 THEN
		RAISE 'One of the property_value fields must be set: %',
			NEW
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF tally > 1 THEN
		RAISE 'Only one of the property_value fields may be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	--
	-- At this point, the value itself is valid for this property, now
	-- determine whether the property is allowed on the target
	--
	-- There needs to be a stanza here for every "lhs".  If a new column is
	-- added to the component_property table, a new stanza needs to be added
	-- here, otherwise it will not be validated.  This should be considered bad.

	IF v_comp_prop.permit_component_type_id = 'REQUIRED' THEN
		IF NEW.component_type_id IS NULL THEN
			RAISE 'component_type_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_component_type_id = 'PROHIBITED' THEN
		IF NEW.component_type_id IS NOT NULL THEN
			RAISE 'component_type_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_component_function = 'REQUIRED' THEN
		IF NEW.component_function IS NULL THEN
			RAISE 'component_function is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_component_function = 'PROHIBITED' THEN
		IF NEW.component_function IS NOT NULL THEN
			RAISE 'component_function is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_component_id = 'REQUIRED' THEN
		IF NEW.component_id IS NULL THEN
			RAISE 'component_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_component_id = 'PROHIBITED' THEN
		IF NEW.component_id IS NOT NULL THEN
			RAISE 'component_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_intcomp_conn_id = 'REQUIRED' THEN
		IF NEW.inter_component_connection_id IS NULL THEN
			RAISE 'inter_component_connection_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_intcomp_conn_id = 'PROHIBITED' THEN
		IF NEW.inter_component_connection_id IS NOT NULL THEN
			RAISE 'inter_component_connection_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_slot_type_id = 'REQUIRED' THEN
		IF NEW.slot_type_id IS NULL THEN
			RAISE 'slot_type_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_slot_type_id = 'PROHIBITED' THEN
		IF NEW.slot_type_id IS NOT NULL THEN
			RAISE 'slot_type_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_slot_function = 'REQUIRED' THEN
		IF NEW.slot_function IS NULL THEN
			RAISE 'slot_function is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_slot_function = 'PROHIBITED' THEN
		IF NEW.slot_function IS NOT NULL THEN
			RAISE 'slot_function is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_slot_id = 'REQUIRED' THEN
		IF NEW.slot_id IS NULL THEN
			RAISE 'slot_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_slot_id = 'PROHIBITED' THEN
		IF NEW.slot_id IS NOT NULL THEN
			RAISE 'slot_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	--
	-- LHS population is verified; now validate any particular restrictions
	-- on individual values
	--

	--
	-- For slot_id, validate that the component_type, component_function,
	-- slot_type, and slot_function are all valid
	--
	IF NEW.slot_id IS NOT NULL AND COALESCE(
			v_comp_prop.required_component_type_id::text,
			v_comp_prop.required_component_function,
			v_comp_prop.required_slot_type_id::text,
			v_comp_prop.required_slot_function) IS NOT NULL THEN

		WITH x AS (
			SELECT
				component_type_id,
				array_agg(component_function) as component_function
			FROM
				component_type_component_func
			GROUP BY
				component_type_id
		) SELECT
			component_type_id,
			component_function,
			st.slot_type_id,
			slot_function
		INTO
			component_attrs
		FROM
			slot cs JOIN
			slot_type st USING (slot_type_id) JOIN
			component c USING (component_id) JOIN
			component_type ct USING (component_type_id) LEFT JOIN
			x USING (component_type_id)
		WHERE
			slot_id = NEW.slot_id;

		IF v_comp_prop.required_component_type_id IS NOT NULL AND
				v_comp_prop.required_component_type_id !=
				component_attrs.component_type_id THEN
			RAISE 'component_type for slot_id must be % (is: %)',
					v_comp_prop.required_component_type_id,
					component_attrs.component_type_id
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_component_function IS NOT NULL AND
				NOT (v_comp_prop.required_component_function =
					ANY(component_attrs.component_function)) THEN
			RAISE 'component_function for slot_id must be % (is: %)',
					v_comp_prop.required_component_function,
					component_attrs.component_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_slot_type_id IS NOT NULL AND
				v_comp_prop.required_slot_type_id !=
				component_attrs.slot_type_id THEN
			RAISE 'slot_type_id for slot_id must be % (is: %)',
					v_comp_prop.required_slot_type_id,
					component_attrs.slot_type_id
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_slot_function IS NOT NULL AND
				v_comp_prop.required_slot_function !=
				component_attrs.slot_function THEN
			RAISE 'slot_function for slot_id must be % (is: %)',
					v_comp_prop.required_slot_function,
					component_attrs.slot_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.slot_type_id IS NOT NULL AND
			v_comp_prop.required_slot_function IS NOT NULL THEN

		SELECT
			slot_function
		INTO
			component_attrs
		FROM
			slot_type st
		WHERE
			slot_type_id = NEW.slot_type_id;

		IF v_comp_prop.required_slot_function !=
				component_attrs.slot_function THEN
			RAISE 'slot_function for slot_type_id must be % (is: %)',
					v_comp_prop.required_slot_function,
					component_attrs.slot_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.component_id IS NOT NULL AND COALESCE(
			v_comp_prop.required_component_type_id::text,
			v_comp_prop.required_component_function) IS NOT NULL THEN

		SELECT
			component_type_id,
			array_agg(component_function) as component_function
		INTO
			component_attrs
		FROM
			component c JOIN
			component_type_component_func ctcf USING (component_type_id)
		WHERE
			component_id = NEW.component_id
		GROUP BY
			component_type_id;

		IF v_comp_prop.required_component_type_id IS NOT NULL AND
				v_comp_prop.required_component_type_id !=
				component_attrs.component_type_id THEN
			RAISE 'component_type for component_id must be % (is: %)',
					v_comp_prop.required_component_type_id,
					component_attrs.component_type_id
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_component_function IS NOT NULL AND
				NOT (v_comp_prop.required_component_function =
					ANY(component_attrs.component_function)) THEN
			RAISE 'component_function for component_id must be % (is: %)',
					v_comp_prop.required_component_function,
					component_attrs.component_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.component_type_id IS NOT NULL AND
			v_comp_prop.required_component_function IS NOT NULL THEN

		SELECT
			component_type_id,
			array_agg(component_function) as component_function
		INTO
			component_attrs
		FROM
			component_type_component_func ctcf
		WHERE
			component_type_id = NEW.component_type_id
		GROUP BY
			component_type_id;

		IF v_comp_prop.required_component_function IS NOT NULL AND
				NOT (v_comp_prop.required_component_function =
					ANY(component_attrs.component_function)) THEN
			RAISE 'component_function for component_type_id must be % (is: %)',
					v_comp_prop.required_component_function,
					component_attrs.component_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_inter_component_connection');
CREATE OR REPLACE FUNCTION jazzhands.validate_inter_component_connection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	slot_type_info	RECORD;
	csid_rec	RECORD;
BEGIN
	IF NEW.slot1_id = NEW.slot2_id THEN
		RAISE EXCEPTION 'A slot may not be connected to itself'
			USING ERRCODE = 'check_violation';
	END IF;

	--
	-- Validate that slot_ids are not already connected
	-- to something else
	--

	SELECT
		slot1_id,
		slot2_id
	INTO
		csid_rec
	FROM
		inter_component_connection icc
	WHERE
		icc.inter_component_connection_id != NEW.inter_component_connection_id
			AND
		(icc.slot1_id = NEW.slot1_id OR
		 icc.slot1_id = NEW.slot2_id OR
		 icc.slot2_id = NEW.slot1_id OR
		 icc.slot2_id = NEW.slot2_id )
	LIMIT 1;

	IF FOUND THEN
		IF csid_rec.slot1_id = NEW.slot1_id THEN
			RAISE EXCEPTION
				'slot_id % is already attached to slot_id %',
				NEW.slot1_id, csid_rec.slot2_id
				USING ERRCODE = 'unique_violation';
		ELSIF csid_rec.slot1_id = NEW.slot2_id THEN
			RAISE EXCEPTION
				'slot_id % is already attached to slot_id %',
				NEW.slot1_id, csid_rec.slot1_id
				USING ERRCODE = 'unique_violation';
		ELSIF csid_rec.slot2_id = NEW.slot1_id THEN
			RAISE EXCEPTION
				'slot_id % is already attached to slot_id %',
				NEW.slot2_id, csid_rec.slot2_id
				USING ERRCODE = 'unique_violation';
		ELSIF csid_rec.slot2_id = NEW.slot2_id THEN
			RAISE EXCEPTION
				'slot_id % is already attached to slot_id %',
				NEW.slot2_id, csid_rec.slot1_id
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	PERFORM
		*
	FROM
		(slot cs1 JOIN slot_type st1 USING (slot_type_id)) slot1,
		(slot cs2 JOIN slot_type st2 USING (slot_type_id)) slot2,
		slot_type_prmt_rem_slot_type pst
	WHERE
		slot1.slot_id = NEW.slot1_id AND
		slot2.slot_id = NEW.slot2_id AND
		-- Remove next line if we ever decide to allow cross-function
		-- connections
		slot1.slot_function = slot2.slot_function AND
		((slot1.slot_type_id = pst.slot_type_id AND
				slot2.slot_type_id = pst.remote_slot_type_id) OR
			(slot2.slot_type_id = pst.slot_type_id AND
				slot1.slot_type_id = pst.remote_slot_type_id));

	IF NOT FOUND THEN
		SELECT
			slot1.slot_type_id AS slot1_slot_type_id,
			slot1.slot_id AS slot1_slot_id,
			slot1.component_id AS slot1_component_id,
			slot1.slot_function AS slot1_slot_function,
			slot2.slot_type_id AS slot2_slot_type_id,
			slot2.slot_id AS slot2_slot_id,
			slot2.component_id AS slot2_component_id,
			slot2.slot_function AS slot2_slot_function
		INTO slot_type_info
		FROM
			(slot cs1 JOIN slot_type st1 USING (slot_type_id)) slot1,
			(slot cs2 JOIN slot_type st2 USING (slot_type_id)) slot2
		WHERE
			slot1.slot_id = NEW.slot1_id AND
			slot2.slot_id = NEW.slot2_id;

		RAISE EXCEPTION E'Slot types are not allowed to be connected:\nSlot %, component_id %, slot_type %, slot_function %\nSlot %, component_id %, slot_type %, slot_function %',
			slot_type_info.slot1_slot_id,
			slot_type_info.slot1_component_id,
			slot_type_info.slot1_slot_type_id,
			slot_type_info.slot1_slot_function,
			slot_type_info.slot2_slot_id,
			slot_type_info.slot2_component_id,
			slot_type_info.slot2_slot_type_id,
			slot_type_info.slot2_slot_function
			USING ERRCODE = 'check_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock');
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	nbtype				RECORD;
	v_netblock_id		netblock.netblock_id%TYPE;
	parent_netblock		RECORD;
	tmp_nb				RECORD;
	universes			integer[];
	netmask_bits		integer;
	tally				integer;
BEGIN
	IF NEW.ip_address IS NULL THEN
		RAISE EXCEPTION 'Column ip_address may not be null'
			USING ERRCODE = 'not_null_violation';
	END IF;

	/*
	 * These are trigger enforced later and are basically what anyone
	 * using this means.
	 */
	IF NEW.can_subnet = 'Y' and NEW.is_single_address iS NULL THEN
		NEW.is_single_address = 'N';
	ELSIF NEW.can_subnet IS NULL and NEW.is_single_address = 'Y' THEN
		NEW.can_subnet = 'N';
	END IF;

	/*
	 * If the universe is not set, we used to assume 0/default, but now
	 * its the same namespace.  In the interest of speed, we assume a
	 * default namespace of 0, which is kind of like before, and
	 * assume that if there's no match, 0 should be returned, which
	 * is also like before, which basically is just all the defaults.
	 * The assumption is that if multiple namespaces are used, then
	 * the caller is smart about figuring this out
	 */
	IF NEW.ip_universe_id IS NULL THEN
		NEW.ip_universe_id := netblock_utils.find_best_ip_universe(
				ip_address := NEW.ip_address
			);
	END IF;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	IF NEW.is_single_address = 'Y' THEN
		IF nbtype.db_forced_hierarchy = 'Y' THEN
			RAISE DEBUG 'Calculating netmask for new netblock';

			v_netblock_id := netblock_utils.find_best_parent_id(
				NEW.ip_address,
				NULL,
				NEW.netblock_type,
				NEW.ip_universe_id,
				NEW.is_single_address,
				NEW.netblock_id
				);

			IF v_netblock_id IS NULL THEN
				RAISE EXCEPTION 'A single address (%) must be the child of a parent netblock, which must have can_subnet=N', NEW.ip_address
					USING ERRCODE = 'JH105';
			END IF;

			SELECT masklen(ip_address) INTO netmask_bits FROM
				netblock WHERE netblock_id = v_netblock_id;

			NEW.ip_address := set_masklen(NEW.ip_address, netmask_bits);
		END IF;
	END IF;

	/* Done with handling of netmasks */

	IF NEW.can_subnet = 'Y' AND NEW.is_single_address = 'Y' THEN
		RAISE EXCEPTION 'Single addresses may not be subnettable'
			USING ERRCODE = 'JH106';
	END IF;

	IF NEW.is_single_address = 'N' AND (NEW.ip_address != cidr(NEW.ip_address))
			THEN
		RAISE EXCEPTION
			'Non-network bits must be zero if is_single_address is N for %',
			NEW.ip_address
			USING ERRCODE = 'JH103';
	END IF;

	/*
	 * This used to only happen for not-rfc1918 space, but that sort of
	 * uniqueness enforcement is done through ip universes now.
	 */
	SELECT * FROM netblock INTO tmp_nb
	WHERE
		ip_address = NEW.ip_address AND
		ip_universe_id = NEW.ip_universe_id AND
		netblock_type = NEW.netblock_type AND
		is_single_address = NEW.is_single_address
	LIMIT 1;

	IF (TG_OP = 'INSERT' AND FOUND) THEN
		RAISE EXCEPTION E'Unique Constraint Violated on IP Address: %\nFailing row is %\nConflicts with: %',
			NEW.ip_address, row_to_json(NEW), row_to_json(tmp_nb)
			USING ERRCODE= 'unique_violation';
	END IF;
	IF (TG_OP = 'UPDATE') THEN
		IF (NEW.ip_address != OLD.ip_address AND FOUND) THEN
			RAISE EXCEPTION E'Unique Constraint Violated on IP Address: %\nFailing row is %\nConflicts with: %',
				NEW.ip_address, row_to_json(NEW), row_to_json(tmp_nb)
				USING ERRCODE= 'unique_violation';
		END IF;
	END IF;

	/*
	 * for networks, check for uniqueness across ip universe and ip visibility
	 */
	IF NEW.is_single_address = 'N' THEN
		WITH x AS (
				SELECT	ip_universe_id
				FROM	ip_universe
				WHERE	ip_namespace IN (
							SELECT ip_namespace FROM ip_universe
							WHERE ip_universe_id = NEW.ip_universe_id
						)
				AND		ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	visible_ip_universe_id
				FROM	ip_universe_visibility
				WHERE	ip_universe_id = NEW.ip_universe_id
				AND		ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	ip_universe_id
				FROM	ip_universe_visibility
				WHERE	visible_ip_universe_id = NEW.ip_universe_id
				AND		visible_ip_universe_id != NEW.ip_universe_id
		) SELECT count(*) INTO tally
		FROM netblock
		WHERE ip_address = NEW.ip_address AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id IN (select ip_universe_id FROM x) AND
			is_single_address = 'N' AND
			netblock_id != NEW.netblock_id
		;

		IF tally >  0 THEN
			RAISE EXCEPTION
				'IP Universe Constraint Violated on IP Address: % Universe: %',
				NEW.ip_address, NEW.ip_universe_id
				USING ERRCODE= 'unique_violation';
		END IF;

		IF NEW.can_subnet = 'N' THEN
			WITH x AS (
				SELECT	ip_universe_id
				FROM	ip_universe
				WHERE	ip_namespace IN (
							SELECT ip_namespace FROM ip_universe
							WHERE ip_universe_id = NEW.ip_universe_id
						)
				AND		ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	visible_ip_universe_id
				FROM	ip_universe_visibility
				WHERE	ip_universe_id = NEW.ip_universe_id
				AND		visible_ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	ip_universe_id
				FROM	ip_universe_visibility
				WHERE	visible_ip_universe_id = NEW.ip_universe_id
				AND		ip_universe_id != NEW.ip_universe_id
			) SELECT count(*) INTO tally
			FROM netblock
			WHERE
				ip_universe_id IN (select ip_universe_id FROM x) AND
				(
					ip_address <<= NEW.ip_address OR
					ip_address >>= NEW.ip_address
				) AND
				netblock_type = NEW.netblock_type AND
				is_single_address = 'N' AND
				can_subnet = 'N' AND
				netblock_id != NEW.netblock_id
			;

			IF tally >  0 THEN
				RAISE EXCEPTION
					'Can Subnet = N IP Universe Constraint Violated on IP Address: % Universe: %',
					NEW.ip_address, NEW.ip_universe_id
					USING ERRCODE= 'unique_violation';
			END IF;
		END IF;
	END IF;

	/*
	 * Parent validation is performed in the deferred after trigger
	 */

	 RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock_to_range_changes');
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_to_range_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_vnrt	val_network_range_type%ROWTYPE;
	_r		RECORD;
	_tally	INTEGER;
BEGIN
	--
	-- Check to see if changing these things causes any of the defined
	-- rules about the netblocks to change
	--
	PERFORM
	FROM	network_range nr
			JOIN netblock p ON p.netblock_id = nr.parent_netblock_id
			JOIN netblock start ON start.netblock_id = nr.start_netblock_id
			JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
			JOIN val_network_range_type vnrt USING (network_range_type)
	WHERE	-- Check if this IP is even related to a range
			( p.netblock_id = NEW.netblock_id
				OR start.netblock_id = NEW.netblock_id
				OR stop.netblock_id = NEW.netblock_id
			) AND (
				-- If so, check to make usre that its the right type.
					p.can_subnet = 'Y'
				OR 	start.is_single_address = 'N'
				OR 	stop.is_single_address = 'N'
				-- and the start/stop is in the parent
				OR NOT (
					host(start.ip_address)::inet <<= p.ip_address
					AND host(stop.ip_address)::inet <<= p.ip_address
				)
				-- and if a type is forced, start/top have it
				OR ( vnrt.netblock_type IS NOT NULL
					AND NOT
					( start.netblock_type IS NOT DISTINCT FROM
						vnrt.netblock_type
					AND	stop.netblock_type IS NOT DISTINCT FROM
						vnrt.netblock_type
					)
				) -- and if a cidr boundary is required and its not on AS such
				OR ( vnrt.require_cidr_boundary = 'Y'
					AND NOT (
						start.ip_address = network(start.ip_address)
						AND
						stop.ip_address = broadcast(stop.ip_address)
					)
				)
				OR ( vnrt.require_cidr_boundary = 'Y'
					AND NOT (
						masklen(start.ip_address) !=
							masklen(stop.ip_address)
					)
				)

			)
	;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock changes conflict with network range requirements '
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	--
	-- If an IP changed, check to see if that made ranges overlap
	--
	IF OLD.ip_address IS DISTINCT FROM NEW.ip_address THEN
		FOR _r IN SELECT nr.*, host(start.ip_address)::inet AS start_ip,
					host(stop.ip_address)::inet AS stop_ip
				FROM network_range nr
					JOIN netblock start
						ON start.netblock_id = nr.start_netblock_id
					JOIN netblock stop
						ON stop.netblock_id = nr.stop_netblock_id
				WHERE nr.start_netblock_id = NEW.netblock_id
				OR nr.stop_netblock_id = NEW.netblock_id
		LOOP
			IF _r.stop_ip < _r.start_ip THEN
				RAISE EXCEPTION 'stop ip address can not be before start in network ranges.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
		END LOOP;
		FOR _vnrt IN SELECT *
				FROM val_network_range_type
				WHERE network_range_type IN (
					SELECT network_range_type
					FROM	network_range nr
					WHERE parent_netblock_id = NEW.netblock_id
					OR start_netblock_id = NEW.netblock_id
					OR stop_netblock_id = NEW.netblock_id
				) AND can_overlap = 'N'
		LOOP
			SELECT count(*)
			INTO _tally
			FROM	network_range nr
				JOIN netblock start ON start.netblock_id = nr.start_netblock_id
				JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
			WHERE	network_range_type = _vnrt.network_range_type
			AND
				start.ip_address <= NEW.ip_address
			AND
				stop.ip_address  >= NEW.ip_address
			;

			IF _tally != 1 THEN
				RAISE EXCEPTION 'Netblock changes network range overlap with type % (%)',
					_vnrt.network_range_type, _tally
					USING ERRCODE = 'integrity_constraint_violation';
			END IF;
		END LOOP;

		SELECT count(*)
		INTO _tally
		FROM	network_range nr
			JOIN netblock start ON start.netblock_id = nr.start_netblock_id
			JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
			JOIN val_network_range_type USING (network_range_type)
		WHERE require_cidr_boundary = 'Y'
		AND (
			nr.parent_netblock_id = NEW.netblock_id
			OR start_netblock_id = NEW.netblock_id
			OR stop_netblock_id = NEW.netblock_id
		) AND (
			masklen(start.ip_address) != masklen(stop.ip_address)
			OR start.ip_address != network(start.ip_address)
			OR stop.ip_address != broadcast(stop.ip_address)
		);

		IF _tally > 0 THEN
			RAISE EXCEPTION 'netblock is part of network_range_type % and creatres % violations',
				_vnrt.network_range_type, _tally
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;

	RETURN NEW;
END; $function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_network_range_ips');
CREATE OR REPLACE FUNCTION jazzhands.validate_network_range_ips()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	v_nrt	val_network_range_type%ROWTYPE;
	v_nbt	val_netblock_type.netblock_type%TYPE;
	startip	inet;
	stopip	inet;
BEGIN
	SELECT	*
	INTO	v_nrt
	FROM	val_network_range_type
	WHERE	network_range_type = NEW.network_range_type;

	--
	-- check to make sure type mapping works
	--
	IF v_nrt.netblock_type IS NOT NULL THEN
		SELECT	netblock_type
		INTO	v_nbt
		FROM	netblock
		WHERE	netblock_id = NEW.start_netblock_id
		AND		netblock_type != v_nrt.netblock_type;

		IF FOUND THEN
			RAISE EXCEPTION 'For range %, start netblock_type must be %, not %',
				NEW.network_range_type, v_nrt.netblock_type, v_nbt
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

		SELECT	netblock_type
		INTO	v_nbt
		FROM	netblock
		WHERE	netblock_id = NEW.stop_netblock_id
		AND		netblock_type != v_nrt.netblock_type;

		IF FOUND THEN
			RAISE EXCEPTION 'For range %, stop netblock_type must be %, not %',
				NEW.network_range_type, v_nrt.netblock_type, v_nbt
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	--
	-- Check to ensure both stop and start have is_single_address = 'Y'
	--
	PERFORM
	FROM	netblock
	WHERE	( netblock_id = NEW.start_netblock_id
				OR netblock_id = NEW.stop_netblock_id
			) AND is_single_address = 'N';

	IF FOUND THEN
		RAISE EXCEPTION 'Start and stop types must be single addresses'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	PERFORM
	FROM	netblock
	WHERE	netblock_id = NEW.parent_netblock_id
	AND can_subnet = 'Y';

	IF FOUND THEN
		RAISE EXCEPTION 'Can not set ranges on subnetable netblocks'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	PERFORM
	FROM	netblock parent
			JOIN netblock start ON start.netblock_id = NEW.start_netblock_id
			JOIN netblock stop ON stop.netblock_id = NEW.stop_netblock_id
	WHERE
			parent.netblock_id = NEW.parent_netblock_id
			AND NOT ( host(start.ip_address)::inet <<= parent.ip_address
				AND host(stop.ip_address)::inet <<= parent.ip_address
			)
	;
	IF FOUND THEN
		RAISE EXCEPTION 'start or stop address not within parent netblock'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	IF v_nrt.can_overlap = 'N' THEN
		SELECT host(ip_address) INTO startip
			FROM netblock where netblock_id = NEW.start_netblock_id;
		SELECT host(ip_address) INTO stopip
			FROM netblock where netblock_id = NEW.stop_netblock_id;

		PERFORM *
		FROM (
			SELECT nr.*, host(start.ip_address)::inet AS start_ip,
				host(stop.ip_address)::inet AS stop_ip
			FROM network_range nr
			JOIN netblock start ON start.netblock_id = nr.start_netblock_id
			JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
		) nr
		WHERE nr.network_range_type = NEW.network_range_type
		AND nr.network_range_id != NEW.network_range_id
		AND (
			( startip >= start_ip AND startip <= stop_ip)
			OR
			( stopip >= start_ip AND stopip <= stop_ip)
		);

		IF FOUND THEN
			RAISE EXCEPTION 'overlapping network ranges not permitted for type %',
				NEW.network_range_type
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	IF v_nrt.require_cidr_boundary = 'Y' THEN
		SELECT host(ip_address) INTO startip
			FROM netblock where netblock_id = NEW.start_netblock_id;
		SELECT host(ip_address) INTO stopip
			FROM netblock where netblock_id = NEW.stop_netblock_id;

		PERFORM *
		FROM (
			SELECT nr.*, start.ip_address AS start_ip,
				stop.ip_address AS stop_ip
			FROM network_range nr
			JOIN netblock start ON start.netblock_id = nr.start_netblock_id
			JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
		) nr
		WHERE nr.network_range_id = NEW.network_range_id
		AND (
			masklen(start_ip) != masklen(stop_ip)
			OR start_ip != network(start_ip)
			OR stop_ip != broadcast(stop_ip)
		);
		IF FOUND THEN
			RAISE EXCEPTION 'start/stop must be on matching CIDR boundaries'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	--
	-- make sure that the order of start/stop is not backwards
	--
	PERFORM
	FROM (
		SELECT nr.*, host(start.ip_address)::inet AS start_ip,
				host(stop.ip_address)::inet AS stop_ip
			FROM network_range nr
			JOIN netblock start ON start.netblock_id = nr.start_netblock_id
			JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
		) nr
	WHERE network_range_id = NEW.network_range_id
	AND stop_ip < start_ip;

	IF FOUND THEN
		RAISE EXCEPTION 'stop ip address can not be before start in network ranges.'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	RETURN NEW;
END; $function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.person_company_attr_change_after_row_hooks()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally			integer;
BEGIN
	BEGIN
		PERFORM local_hooks.person_company_attr_change_after_row_hooks(person_company_attr_row => NEW);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
	RETURN NULL;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_net_range_toggle_nonoverlap()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally INTEGER;
BEGIN
	IF NEW.can_overlap = 'N' THEN
		SELECT COUNT(*)
		INTO _tally
		FROM (
				SELECT nr.*, host(start.ip_address)::inet AS start_ip,
					host(stop.ip_address)::inet AS stop_ip
				FROM network_range nr
				JOIN netblock start ON start.netblock_id = nr.start_netblock_id
				JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
			) n1 JOIN (
				SELECT nr.*, host(start.ip_address)::inet AS start_ip,
					host(stop.ip_address)::inet AS stop_ip
				FROM network_range nr
				JOIN netblock start ON start.netblock_id = nr.start_netblock_id
				JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
			) n2 USING (network_range_type)
		WHERE n1.network_range_id != n2.network_range_id
		AND network_range_type = NEW.network_range_type
		AND (
			( n1.start_ip >= n2.start_ip AND n1.start_ip <= n2.stop_ip)
			OR
			( n1.stop_ip >= n2.start_ip AND n1.stop_ip <= n2.stop_ip)
		);

		IF _tally > 0 THEN
			RAISE EXCEPTION '% has % overlapping network ranges',
				NEW.network_range_type, _tally
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	IF NEW.require_cidr_boundary = 'Y' THEN
		SELECT COUNT(*)
		INTO _tally
		FROM (
				SELECT nr.*, host(start.ip_address)::inet AS start_ip,
					host(stop.ip_address)::inet AS stop_ip
				FROM network_range nr
				JOIN netblock start ON start.netblock_id = nr.start_netblock_id
				JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
			) nr
		WHERE network_range_type = NEW.network_range_type
		AND (
			masklen(start_ip) != masklen(stop_ip)
			OR
			start_ip != network(start_ip)
			OR
			stop_ip != broadcast(stop_ip)
		);

		IF _tally > 0 THEN
			RAISE EXCEPTION '% has % cidr issues in network ranges',
				NEW.network_range_type, _tally
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	RETURN NEW;
END; $function$
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
-- Changed function
SELECT schema_support.save_grants_for_replay('dns_utils', 'add_dns_domain');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS dns_utils.add_dns_domain ( soa_name character varying, dns_domain_type character varying, ip_universes integer[], add_nameservers boolean );
CREATE OR REPLACE FUNCTION dns_utils.add_dns_domain(soa_name character varying, dns_domain_type character varying DEFAULT NULL::character varying, ip_universes integer[] DEFAULT NULL::integer[], add_nameservers boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	elements		text[];
	parent_zone		text;
	parent_id		dns_domain.dns_domain_id%type;
	domain_id		dns_domain.dns_domain_id%type;
	elem			text;
	sofar			text;
	rvs_nblk_id		netblock.netblock_id%type;
	univ			ip_universe.ip_universe_id%type;
BEGIN
	IF soa_name IS NULL THEN
		RETURN NULL;
	END IF;
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
			WHERE soa_name = $1' INTO parent_id USING parent_zone;
		IF parent_id IS NOT NULL THEN
			EXIT;
		END IF;
	END LOOP;

	IF ip_universes IS NULL THEN
		SELECT array_agg(ip_universe_id) 
		INTO	ip_universes
		FROM	ip_universe
		WHERE	ip_universe_name = 'default';
	END IF;

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
			parent_dns_domain_id,
			dns_domain_type
		) VALUES (
			$1,
			$2,
			$3
		) RETURNING dns_domain_id' INTO domain_id 
		USING soa_name, 
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
				'Y'
		;
	END LOOP;

	IF dns_domain_type = 'reverse' THEN
		rvs_nblk_id := dns_utils.get_or_create_rvs_netblock_link(
			soa_name, domain_id);
	END IF;

	IF add_nameservers THEN
		PERFORM dns_utils.add_ns_records(domain_id);
	END IF;

	--
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
			WHERE should_generate = 'Y'
		);
	END IF;

	RETURN domain_id;
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
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblocks ( parent_netblock_list integer[], netmask_bits integer, single_address boolean, allocation_method text, max_addresses integer, desired_ip_address inet, rnd_masklen_threshold integer, rnd_max_count integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocation_method text DEFAULT NULL::text, max_addresses integer DEFAULT 1024, desired_ip_address inet DEFAULT NULL::inet, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	netblock_rec	jazzhands.netblock%ROWTYPE;
	netrange_rec	RECORD;
	inet_list		inet[];
	current_ip		inet;
	saved_method	text;
	min_ip			inet;
	max_ip			inet;
	matches			integer;
	rnd_matches		integer;
	max_rnd_value	bigint;
	rnd_value		bigint;
	family_bits		integer;
BEGIN
	matches := 0;
	saved_method = allocation_method;

	IF allocation_method IS NOT NULL AND allocation_method
			NOT IN ('top', 'bottom', 'random', 'default') THEN
		RAISE 'address_type must be one of top, bottom, random, or default'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	--
	-- Sanitize masklen input.  This is a little complicated.
	--
	-- If a single address is desired, we always use a /32 or /128
	-- in the parent loop and everything else is ignored
	--
	-- Otherwise, if netmask_bits is passed, that wins, otherwise
	-- the netmask of whatever is passed with desired_ip_address wins
	--
	-- If none of these are the case, then things are wrong and we
	-- bail
	--

	IF NOT single_address THEN 
		IF desired_ip_address IS NOT NULL AND netmask_bits IS NULL THEN
			netmask_bits := masklen(desired_ip_address);
		ELSIF desired_ip_address IS NOT NULL AND 
				netmask_bits IS NOT NULL THEN
			desired_ip_address := set_masklen(desired_ip_address,
				netmask_bits);
		END IF;
		IF netmask_bits IS NULL THEN
			RAISE EXCEPTION 'netmask_bits must be set'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF allocation_method = 'random' THEN
			RAISE EXCEPTION 'random netblocks may only be returned for single addresses'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	FOREACH parent_nbid IN ARRAY parent_netblock_list LOOP
		rnd_matches := 0;
		--
		-- Restore this, because we may have overrridden it for a previous
		-- block
		--
		allocation_method = saved_method;
		SELECT 
			* INTO netblock_rec
		FROM
			jazzhands.netblock n
		WHERE
			n.netblock_id = parent_nbid;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'Netblock % does not exist', parent_nbid;
		END IF;

		family_bits := 
			(CASE family(netblock_rec.ip_address) WHEN 4 THEN 32 ELSE 128 END);

		-- If desired_ip_address is passed, then allocation_method is
		-- irrelevant

		IF desired_ip_address IS NOT NULL THEN
			--
			-- If the IP address is not the same family as the parent block,
			-- we aren't going to find it
			--
			IF family(desired_ip_address) != 
					family(netblock_rec.ip_address) THEN
				CONTINUE;
			END IF;
			allocation_method := 'bottom';
		END IF;

		--
		-- If allocation_method is 'default' or NULL, then use 'bottom'
		-- unless it's for a single IPv6 address in a netblock larger than 
		-- rnd_masklen_threshold
		--
		IF allocation_method IS NULL OR allocation_method = 'default' THEN
			allocation_method := 
				CASE WHEN 
					single_address AND 
					family(netblock_rec.ip_address) = 6 AND
					masklen(netblock_rec.ip_address) <= rnd_masklen_threshold
				THEN
					'random'
				ELSE
					'bottom'
				END;
		END IF;

		IF allocation_method = 'random' AND 
				family_bits - masklen(netblock_rec.ip_address) < 2 THEN
			-- Random allocation doesn't work if we don't have enough
			-- bits to play with, so just do sequential.
			allocation_method := 'bottom';
		END IF;

		IF single_address THEN 
			netmask_bits := family_bits;
			IF desired_ip_address IS NOT NULL THEN
				desired_ip_address := set_masklen(desired_ip_address,
					masklen(netblock_rec.ip_address));
			END IF;
		ELSIF netmask_bits <= masklen(netblock_rec.ip_address) THEN
			-- If the netmask is not for a smaller netblock than this parent,
			-- then bounce to the next one, because maybe it's larger
			RAISE DEBUG
				'netblock (%) is not larger than netmask_bits of % - skipping',
				masklen(netblock_rec.ip_address),
				netmask_bits;
			CONTINUE;
		END IF;

		IF netmask_bits > family_bits THEN
			RAISE EXCEPTION 'netmask_bits must be no more than % for netblock %',
				family_bits,
				netblock_rec.ip_address;
		END IF;

		--
		-- Short circuit the check if we're looking for a specific address
		-- and it's not in this netblock
		--

		IF desired_ip_address IS NOT NULL AND
				NOT (desired_ip_address <<= netblock_rec.ip_address) THEN
			RAISE DEBUG 'desired_ip_address % is not in netblock %',
				desired_ip_address,
				netblock_rec.ip_address;
			CONTINUE;
		END IF;

		IF single_address AND netblock_rec.can_subnet = 'Y' THEN
			RAISE EXCEPTION 'single addresses may not be assigned to to a block where can_subnet is Y';
		END IF;

		IF (NOT single_address) AND netblock_rec.can_subnet = 'N' THEN
			RAISE EXCEPTION 'Netblock % (%) may not be subnetted',
				netblock_rec.ip_address,
				netblock_rec.netblock_id;
		END IF;

		RAISE DEBUG 'Searching netblock % (%) using the % allocation method',
			netblock_rec.netblock_id,
			netblock_rec.ip_address,
			allocation_method;

		IF desired_ip_address IS NOT NULL THEN
			min_ip := desired_ip_address;
			max_ip := desired_ip_address + 1;
		ELSE
			min_ip := netblock_rec.ip_address;
			max_ip := broadcast(min_ip) + 1;
		END IF;

		IF allocation_method = 'top' THEN
			current_ip := network(set_masklen(max_ip - 1, netmask_bits));
		ELSIF allocation_method = 'random' THEN
			max_rnd_value := (x'7fffffffffffffff'::bigint >> CASE 
				WHEN family_bits - masklen(netblock_rec.ip_address) >= 63
				THEN 0
				ELSE 63 - (family_bits - masklen(netblock_rec.ip_address))
				END) - 2;
			-- random() appears to only do 32-bits, which is dumb
			-- I'm pretty sure that all of the casts are not required here,
			-- but better to make sure
			current_ip := min_ip + 
					((((random() * x'7fffffff'::bigint)::bigint << 32) + 
					(random() * x'ffffffff'::bigint)::bigint + 1)
					% max_rnd_value) + 1;
		ELSE -- it's 'bottom'
			current_ip := set_masklen(min_ip, netmask_bits);
		END IF;

		-- For single addresses, make the netmask match the netblock of the
		-- containing block, and skip the network and broadcast addresses
		-- We shouldn't need to skip for IPv6 addresses, but some things
		-- apparently suck

		IF single_address THEN
			current_ip := set_masklen(current_ip, 
				masklen(netblock_rec.ip_address));
			--
			-- If we're not allocating a single /31 or /32 for IPv4 or
			-- /127 or /128 for IPv6, then we want to skip the all-zeros
			-- and all-ones addresses
			--
			IF masklen(netblock_rec.ip_address) < (family_bits - 1) AND
					desired_ip_address IS NULL THEN
				current_ip := current_ip + 
					CASE WHEN allocation_method = 'top' THEN -1 ELSE 1 END;
				min_ip := min_ip + 1;
				max_ip := max_ip - 1;
			END IF;
		END IF;

		RAISE DEBUG 'Starting with IP address % with step masklen of %',
			current_ip,
			netmask_bits;

		WHILE (
				current_ip >= min_ip AND
				current_ip < max_ip AND
				matches < max_addresses AND
				rnd_matches < rnd_max_count
		) LOOP
			RAISE DEBUG '   Checking netblock %', current_ip;

			IF single_address THEN
				--
				-- Check to see if netblock is in a network_range, and if it is,
				-- then set the value to the top or bottom of the range, or
				-- another random value as appropriate
				--
				SELECT 
					network_range_id,
					start_nb.ip_address AS start_ip_address,
					stop_nb.ip_address AS stop_ip_address
				INTO netrange_rec
				FROM
					jazzhands.network_range nr,
					jazzhands.netblock start_nb,
					jazzhands.netblock stop_nb
				WHERE
					nr.start_netblock_id = start_nb.netblock_id AND
					nr.stop_netblock_id = stop_nb.netblock_id AND
					nr.parent_netblock_id = netblock_rec.netblock_id AND
					start_nb.ip_address <= 
						set_masklen(current_ip, masklen(start_nb.ip_address))
					AND stop_nb.ip_address >=
						set_masklen(current_ip, masklen(stop_nb.ip_address));

				IF FOUND THEN
					current_ip := CASE 
						WHEN allocation_method = 'bottom' THEN
							netrange_rec.stop_ip_address + 1
						WHEN allocation_method = 'top' THEN
							netrange_rec.start_ip_address - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32) 
							+ 
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1 
					END;
					CONTINUE;
				END IF;
			END IF;
							
				
			PERFORM * FROM jazzhands.netblock n WHERE
				n.ip_universe_id = netblock_rec.ip_universe_id AND
				n.netblock_type = netblock_rec.netblock_type AND
				-- A block with the parent either contains or is contained
				-- by this block
				n.parent_netblock_id = netblock_rec.netblock_id AND
				CASE WHEN single_address THEN
					n.ip_address = current_ip
				ELSE
					(n.ip_address >>= current_ip OR current_ip >>= n.ip_address)
				END;
			IF NOT FOUND AND (inet_list IS NULL OR
					NOT (current_ip = ANY(inet_list))) THEN
				find_free_netblocks.netblock_type :=
					netblock_rec.netblock_type;
				find_free_netblocks.ip_universe_id :=
					netblock_rec.ip_universe_id;
				find_free_netblocks.ip_address := current_ip;
				RETURN NEXT;
				inet_list := array_append(inet_list, current_ip);
				matches := matches + 1;
				-- Reset random counter if we found something
				rnd_matches := 0;
			ELSIF allocation_method = 'random' THEN
				-- Increase random counter if we didn't find something
				rnd_matches := rnd_matches + 1;
			END IF;

			-- Select the next IP address
			current_ip := 
				CASE WHEN single_address THEN
					CASE 
						WHEN allocation_method = 'bottom' THEN current_ip + 1
						WHEN allocation_method = 'top' THEN current_ip - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32) 
							+ 
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1 
					END
				ELSE
					CASE WHEN allocation_method = 'bottom' THEN 
						network(broadcast(current_ip) + 1)
					ELSE 
						network(current_ip - 1)
					END
				END;
		END LOOP;
	END LOOP;
	RETURN;
END;
$function$
;

--
-- Process drops in property_utils
--
--
-- Process drops in netblock_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'set_interface_addresses');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.set_interface_addresses ( network_interface_id integer, device_id integer, network_interface_name text, network_interface_type text, ip_address_hash jsonb, create_layer3_networks boolean, move_addresses text, address_errors text );
CREATE OR REPLACE FUNCTION netblock_manip.set_interface_addresses(network_interface_id integer DEFAULT NULL::integer, device_id integer DEFAULT NULL::integer, network_interface_name text DEFAULT NULL::text, network_interface_type text DEFAULT 'broadcast'::text, ip_address_hash jsonb DEFAULT NULL::jsonb, create_layer3_networks boolean DEFAULT false, move_addresses text DEFAULT 'if_same_device'::text, address_errors text DEFAULT 'error'::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
--
-- ip_address_hash consists of the following elements
--
--		"ip_addresses" : [ (inet | netblock) ... ]
--		"shared_ip_addresses" : [ (inet | netblock) ... ]
--
-- where inet is a text string that can be legally converted to type inet
-- and netblock is a JSON object with fields:
--		"ip_address" : inet
--		"ip_universe_id" : integer (default 0)
--		"netblock_type" : text (default 'default')
--		"protocol" : text (default 'VRRP')
--
-- If either "ip_addresses" or "shared_ip_addresses" does not exist, it
-- will not be processed.  If the key is present and is an empty array or
-- null, then all IP addresses of those types will be removed from the
-- interface
--
-- 'protocol' is only valid for shared addresses, which is how the address
-- is shared.  Valid values can be found in the val_shared_netblock_protocol
-- table
--
DECLARE
	ni_id			ALIAS FOR network_interface_id;
	dev_id			ALIAS FOR device_id;
	ni_name			ALIAS FOR network_interface_name;
	ni_type			ALIAS FOR network_interface_type;

	addrs_ary		jsonb;
	ipaddr			inet;
	universe		integer;
	nb_type			text;
	protocol		text;

	c				integer;
	i				integer;

	error_rec		RECORD;
	nb_rec			RECORD;
	pnb_rec			RECORD;
	layer3_rec		RECORD;
	sn_rec			RECORD;
	ni_rec			RECORD;
	nin_rec			RECORD;
	nb_id			jazzhands.netblock.netblock_id%TYPE;
	nb_id_ary		integer[];
	ni_id_ary		integer[];
	del_list		integer[];
BEGIN
	--
	-- Validate that we got enough information passed to do things
	--

	IF ip_address_hash IS NULL OR NOT
		(jsonb_typeof(ip_address_hash) = 'object')
	THEN
		RAISE 'Must pass ip_addresses to netblock_manip.set_interface_addresses';
	END IF;

	IF network_interface_id IS NULL THEN
		IF device_id IS NULL OR network_interface_name IS NULL THEN
			RAISE 'netblock_manip.assign_shared_netblock: must pass either network_interface_id or device_id and network_interface_name'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;

		SELECT
			ni.network_interface_id INTO ni_id
		FROM
			network_interface ni
		WHERE
			ni.device_id = dev_id AND
			ni.network_interface_name = ni_name;

		IF NOT FOUND THEN
			INSERT INTO network_interface(
				device_id,
				network_interface_name,
				network_interface_type,
				should_monitor
			) VALUES (
				dev_id,
				ni_name,
				ni_type,
				'N'
			) RETURNING network_interface.network_interface_id INTO ni_id;
		END IF;
	END IF;

	SELECT * INTO ni_rec FROM network_interface ni WHERE 
		ni.network_interface_id = ni_id;

	--
	-- First, loop through ip_addresses passed and process those
	--

	IF ip_address_hash ? 'ip_addresses' AND
		jsonb_typeof(ip_address_hash->'ip_addresses') = 'array'
	THEN
		RAISE DEBUG 'Processing ip_addresses...';
		--
		-- Loop through each member of the ip_addresses array
		-- and process each address
		--
		addrs_ary := ip_address_hash->'ip_addresses';
		c := jsonb_array_length(addrs_ary);
		i := 0;
		nb_id_ary := NULL;
		WHILE (i < c) LOOP
			IF jsonb_typeof(addrs_ary->i) = 'string' THEN
				--
				-- If this is a string, use it as an inet with default
				-- universe and netblock_type
				--
				ipaddr := addrs_ary->>i;
				universe := netblock_utils.find_best_ip_universe(ipaddr);
				nb_type := 'default';
			ELSIF jsonb_typeof(addrs_ary->i) = 'object' THEN
				--
				-- If this is an object, require 'ip_address' key
				-- optionally use 'ip_universe_id' and 'netblock_type' keys
				-- to override the defaults
				--
				IF NOT addrs_ary->i ? 'ip_address' THEN
					RAISE E'Object in array element % of ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses does not contain ip_address key:\n%',
						i, jsonb_pretty(addrs_ary->i);
				END IF;
				ipaddr := addrs_ary->i->>'ip_address';

				IF addrs_ary->i ? 'ip_universe_id' THEN
					universe := addrs_ary->i->'ip_universe_id';
				ELSE
					universe := netblock_utils.find_best_ip_universe(ipaddr);
				END IF;

				IF addrs_ary->i ? 'netblock_type' THEN
					nb_type := addrs_ary->i->>'netblock_type';
				ELSE
					nb_type := 'default';
				END IF;
			ELSE
				RAISE 'Invalid type in array element % of ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses (%)',
					i, jsonb_typeof(addrs_ary->i);
			END IF;
			--
			-- We're done with the array, so increment the counter so
			-- we don't have to deal with it later
			--
			i := i + 1;

			RAISE DEBUG 'Address is %, universe is %, nb type is %',
				ipaddr, universe, nb_type;

			--
			-- This is a hack, because Juniper is really annoying about this.
			-- If masklen < 8, then ignore this netblock (we specifically
			-- want /8, because of 127/8 and 10/8, which someone could
			-- maybe want to not subnet.
			--
			-- This should probably be a configuration parameter, but it's not.
			--
			CONTINUE WHEN masklen(ipaddr) < 8;

			--
			-- Check to see if this is a netblock that we have been
			-- told to explicitly ignore
			--
			PERFORM
				ip_address
			FROM
				netblock n JOIN
				netblock_collection_netblock ncn USING (netblock_id) JOIN
				v_netblock_coll_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_nblk_coll_id =
						nce.root_netblock_collection_id
				)
			WHERE
				ipaddr <<= n.ip_address AND
				n.ip_universe_id = universe
			;

			--
			-- If we found this netblock in the ignore list, then just
			-- skip it
			--
			IF FOUND THEN
				RAISE DEBUG 'Skipping ignored address %', ipaddr;
				CONTINUE;
			END IF;

			--
			-- Look for an is_single_address='Y', can_subnet='N' netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = 'Y' AND
				can_subnet = 'N' AND
				netblock_type = nb_type AND
				ip_universe_id = universe AND
				host(ip_address) = host(ipaddr);

			IF FOUND THEN
				RAISE DEBUG E'Located netblock:\n%',
					jsonb_pretty(to_jsonb(nb_rec));

				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);

				--
				-- Look to see if there's a layer3_network for the
				-- parent netblock
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.netblock_id = nb_rec.parent_netblock_id;

				IF FOUND THEN
					RAISE DEBUG E'Located layer3_network:\n%',
						jsonb_pretty(to_jsonb(layer3_rec));
				ELSE
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
			ELSE
				--
				-- If the parent netblock does not exist, then create it
				-- if we were passed the option to
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.ip_universe_id = universe AND
					n.netblock_type = nb_type AND
					is_single_address = 'N' AND
					can_subnet = 'N' AND
					n.ip_address >>= ipaddr;

				IF NOT FOUND THEN
					RAISE DEBUG 'Parent netblock with ip_address %, netblock_type %, ip_universe_id % not found',
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					--
					-- Check to see if the netblock exists, but is
					-- marked can_subnet='Y'.  If so, fix it
					--
					SELECT 
						* INTO pnb_rec
					FROM
						netblock n
					WHERE
						n.ip_universe_id = universe AND
						n.netblock_type = nb_type AND
						n.is_single_address = 'N' AND
						n.can_subnet = 'Y' AND
						n.ip_address = network(ipaddr);

					IF FOUND THEN
						UPDATE netblock n SET
							can_subnet = 'N'
						WHERE
							n.netblock_id = pnb_rec.netblock_id;
						pnb_rec.can_subnet = 'N';
					ELSE
						INSERT INTO netblock (
							ip_address,
							netblock_type,
							is_single_address,
							can_subnet,
							ip_universe_id,
							netblock_status
						) VALUES (
							network(ipaddr),
							nb_type,
							'N',
							'N',
							universe,
							'Allocated'
						) RETURNING * INTO pnb_rec;
					END IF;

					WITH l3_ins AS (
						INSERT INTO layer3_network(
							netblock_id
						) VALUES (
							pnb_rec.netblock_id
						) RETURNING *
					)
					SELECT
						pnb_rec.netblock_id,
						pnb_rec.ip_address,
						l3_ins.layer3_network_id,
						NULL::inet
					INTO layer3_rec
					FROM
						l3_ins;
				ELSIF layer3_rec.layer3_network_id IS NULL THEN
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--

					RAISE DEBUG 'layer3_network for parent netblock % not found (ip_address %, netblock_type %, ip_universe_id %)',
						layer3_rec.netblock_id,
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
				RAISE DEBUG E'Located layer3_network:\n%',
					jsonb_pretty(to_jsonb(layer3_rec));
				--
				-- Parents should be all set up now.  Insert the netblock
				--
				INSERT INTO netblock (
					ip_address,
					netblock_type,
					ip_universe_id,
					is_single_address,
					can_subnet,
					netblock_status
				) VALUES (
					ipaddr,
					nb_type,
					universe,
					'Y',
					'N',
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;
			--
			-- Now that we have the netblock and everything, check to see
			-- if this netblock is already assigned to this network_interface
			--
			PERFORM * FROM
				network_interface_netblock nin
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id = ni_id;

			IF FOUND THEN
				RAISE DEBUG 'Netblock % already found on network_interface',
					nb_rec.netblock_id;
				CONTINUE;
			END IF;

			--
			-- See if this netblock is on something else, and delete it
			-- if move_addresses is set, otherwise skip it
			--
			SELECT 
				ni.network_interface_id,
				ni.network_interface_name,
				nin.netblock_id,
				d.device_id,
				COALESCE(d.device_name, d.physical_label) AS device_name
			INTO nin_rec
			FROM
				network_interface_netblock nin JOIN
				network_interface ni USING (network_interface_id) JOIN
				device d ON (nin.device_id = d.device_id)
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id != ni_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND 
					nin_rec.device_id = ni_rec.device_id
				)
				THEN
					DELETE FROM
						network_interface_netblock
					WHERE
						netblock_id = nb_rec.netblock_id;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % (%) is assigned to network_interface % (%) on device % (%)',
							nb_rec.netblock_id,
							nb_rec.ip_address,
							nin_rec.network_interface_id,
							nin_rec.network_interface_name,
							nin_rec.device_id,
							nin_rec.device_name;

						CONTINUE;
					ELSE
						RAISE 'Netblock % (%) is assigned to network_interface %(%) on device % (%)',
							nb_rec.netblock_id,
							nb_rec.ip_address,
							nin_rec.network_interface_id,
							nin_rec.network_interface_name,
							nin_rec.device_id,
							nin_rec.device_name;
					END IF;
				END IF;
			END IF;

			--
			-- See if this netblock is on a shared_address somewhere, and
			-- move it only if move_addresses is 'always'
			--
			SELECT * FROM
				shared_netblock sn
			INTO sn_rec
			WHERE
				sn.netblock_id = nb_rec.netblock_id;

			IF FOUND THEN
				IF move_addresses IS NULL OR move_addresses != 'always' THEN
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, sn.shared_netblock_id;
						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % (%) is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, nb_rec.ip_address,
							sn.shared_netblock_id;
						CONTINUE;
					ELSE
						RAISE 'Netblock % (%) is assigned to a shared_network %, but not forcing, so skipping',
							nb_rec.netblock_id, nb_rec.ip_address,
							sn.shared_netblock_id;
						CONTINUE;
					END IF;
				END IF;

				DELETE FROM
					shared_netblock_network_int snni
				WHERE
					snni.shared_netblock_id = sn_rec.shared_netblock_id;

				DELETE FROM
					shared_network sn
				WHERE
					sn.netblock_id = sn_rec.shared_netblock_id;
			END IF;

			--
			-- Insert the netblock onto the interface using the next
			-- rank
			--
			INSERT INTO network_interface_netblock (
				network_interface_id,
				netblock_id,
				network_interface_rank
			) SELECT
				ni_id,
				nb_rec.netblock_id,
				COALESCE(MAX(network_interface_rank) + 1, 0)
			FROM
				network_interface_netblock nin
			WHERE
				nin.network_interface_id = ni_id
			RETURNING * INTO nin_rec;

			RAISE DEBUG E'Inserted into:\n%',
				jsonb_pretty(to_jsonb(nin_rec));
		END LOOP;
		--
		-- Remove any netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR nin_rec IN
			DELETE FROM
				network_interface_netblock nin
			WHERE
				(nin.network_interface_id, nin.netblock_id) IN (
				SELECT
					nin2.network_interface_id,
					nin2.netblock_id
				FROM
					network_interface_netblock nin2 JOIN
					netblock n USING (netblock_id)
				WHERE
					nin2.network_interface_id = ni_id AND NOT (
						nin.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_coll_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_nblk_coll_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed netblock % from network_interface %',
				nin_rec.netblock_id,
				nin_rec.network_interface_id;
			--
			-- Remove any DNS records and/or netblocks that aren't used
			--
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = nin_rec.netblock_id;
				DELETE FROM netblock_collection_netblock WHERE
					netblock_id = nin_rec.netblock_id;
				DELETE FROM netblock WHERE netblock_id =
					nin_rec.netblock_id;
			EXCEPTION
				WHEN foreign_key_violation THEN NULL;
			END;
		END LOOP;
	END IF;

	--
	-- Loop through shared_ip_addresses passed and process those
	--

	IF ip_address_hash ? 'shared_ip_addresses' AND
		jsonb_typeof(ip_address_hash->'shared_ip_addresses') = 'array'
	THEN
		RAISE DEBUG 'Processing shared_ip_addresses...';
		--
		-- Loop through each member of the shared_ip_addresses array
		-- and process each address
		--
		addrs_ary := ip_address_hash->'shared_ip_addresses';
		c := jsonb_array_length(addrs_ary);
		i := 0;
		nb_id_ary := NULL;
		WHILE (i < c) LOOP
			IF jsonb_typeof(addrs_ary->i) = 'string' THEN
				--
				-- If this is a string, use it as an inet with default
				-- universe and netblock_type
				--
				ipaddr := addrs_ary->>i;
				universe := netblock_utils.find_best_ip_universe(ipaddr);
				nb_type := 'default';
				protocol := 'VRRP';
			ELSIF jsonb_typeof(addrs_ary->i) = 'object' THEN
				--
				-- If this is an object, require 'ip_address' key
				-- optionally use 'ip_universe_id' and 'netblock_type' keys
				-- to override the defaults
				--
				IF NOT addrs_ary->i ? 'ip_address' THEN
					RAISE E'Object in array element % of shared_ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses does not contain ip_address key:\n%',
						i, jsonb_pretty(addrs_ary->i);
				END IF;
				ipaddr := addrs_ary->i->>'ip_address';

				IF addrs_ary->i ? 'ip_universe_id' THEN
					universe := addrs_ary->i->'ip_universe_id';
				ELSE
					universe := netblock_utils.find_best_ip_universe(ipaddr);
				END IF;

				IF addrs_ary->i ? 'netblock_type' THEN
					nb_type := addrs_ary->i->>'netblock_type';
				ELSE
					nb_type := 'default';
				END IF;

				IF addrs_ary->i ? 'shared_netblock_protocol' THEN
					protocol := addrs_ary->i->>'shared_netblock_protocol';
				ELSIF addrs_ary->i ? 'protocol' THEN
					protocol := addrs_ary->i->>'protocol';
				ELSE
					protocol := 'VRRP';
				END IF;
			ELSE
				RAISE 'Invalid type in array element % of shared_ip_addresses in ip_address_hash in netblock_manip.set_interface_addresses (%)',
					i, jsonb_typeof(addrs_ary->i);
			END IF;
			--
			-- We're done with the array, so increment the counter so
			-- we don't have to deal with it later
			--
			i := i + 1;

			RAISE DEBUG 'Address is %, universe is %, nb type is %',
				ipaddr, universe, nb_type;

			--
			-- Check to see if this is a netblock that we have been
			-- told to explicitly ignore
			--
			PERFORM
				ip_address
			FROM
				netblock n JOIN
				netblock_collection_netblock ncn USING (netblock_id) JOIN
				v_netblock_coll_expanded nce USING (netblock_collection_id)
					JOIN
				property p ON (
					property_name = 'IgnoreProbedNetblocks' AND
					property_type = 'DeviceInventory' AND
					property_value_nblk_coll_id =
						nce.root_netblock_collection_id
				)
			WHERE
				ipaddr <<= n.ip_address AND
				n.ip_universe_id = universe AND
				n.netblock_type = nb_type;

			--
			-- If we found this netblock in the ignore list, then just
			-- skip it
			--
			IF FOUND THEN
				RAISE DEBUG 'Skipping ignored address %', ipaddr;
				CONTINUE;
			END IF;

			--
			-- Look for an is_single_address='Y', can_subnet='N' netblock
			-- with the given ip_address
			--
			SELECT
				* INTO nb_rec
			FROM
				netblock n
			WHERE
				is_single_address = 'Y' AND
				can_subnet = 'N' AND
				netblock_type = nb_type AND
				ip_universe_id = universe AND
				host(ip_address) = host(ipaddr);

			IF FOUND THEN
				RAISE DEBUG E'Located netblock:\n%',
					jsonb_pretty(to_jsonb(nb_rec));

				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);

				--
				-- Look to see if there's a layer3_network for the
				-- parent netblock
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.netblock_id = nb_rec.parent_netblock_id;

				IF FOUND THEN
					RAISE DEBUG E'Located layer3_network:\n%',
						jsonb_pretty(to_jsonb(layer3_rec));
				ELSE
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
			ELSE
				--
				-- If the parent netblock does not exist, then create it
				-- if we were passed the option to
				--
				SELECT
					n.netblock_id,
					n.ip_address,
					layer3_network_id,
					default_gateway_netblock_id
				INTO layer3_rec
				FROM
					netblock n LEFT JOIN
					layer3_network l3 USING (netblock_id)
				WHERE
					n.ip_universe_id = universe AND
					n.netblock_type = nb_type AND
					is_single_address = 'N' AND
					can_subnet = 'N' AND
					n.ip_address >>= ipaddr;

				IF NOT FOUND THEN
					RAISE DEBUG 'Parent netblock with ip_address %, netblock_type %, ip_universe_id % not found',
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					WITH nb_ins AS (
						INSERT INTO netblock (
							ip_address,
							netblock_type,
							is_single_address,
							can_subnet,
							ip_universe_id,
							netblock_status
						) VALUES (
							network(ipaddr),
							nb_type,
							'N',
							'N',
							universe,
							'Allocated'
						) RETURNING *
					), l3_ins AS (
						INSERT INTO layer3_network(
							netblock_id
						)
						SELECT
							netblock_id
						FROM
							nb_ins
						RETURNING *
					)
					SELECT
						nb_ins.netblock_id,
						nb_ins.ip_address,
						l3_ins.layer3_network_id,
						NULL
					INTO layer3_rec
					FROM
						nb_ins,
						l3_ins;
				ELSIF layer3_rec.layer3_network_id IS NULL THEN
					--
					-- If we're told to create the layer3_network,
					-- then do that, otherwise go to the next address
					--

					RAISE DEBUG 'layer3_network for parent netblock % not found (ip_address %, netblock_type %, ip_universe_id %)',
						layer3_rec.netblock_id,
						network(ipaddr),
						nb_type,
						universe;
					CONTINUE WHEN NOT create_layer3_networks;
					INSERT INTO layer3_network(
						netblock_id
					) VALUES (
						layer3_rec.netblock_id
					) RETURNING layer3_network_id INTO
						layer3_rec.layer3_network_id;
				END IF;
				RAISE DEBUG E'Located layer3_network:\n%',
					jsonb_pretty(to_jsonb(layer3_rec));
				--
				-- Parents should be all set up now.  Insert the netblock
				--
				INSERT INTO netblock (
					ip_address,
					netblock_type,
					ip_universe_id,
					is_single_address,
					can_subnet,
					netblock_status
				) VALUES (
					ipaddr,
					nb_type,
					universe,
					'Y',
					'N',
					'Allocated'
				) RETURNING * INTO nb_rec;
				nb_id_ary := array_append(nb_id_ary, nb_rec.netblock_id);
			END IF;

			--
			-- See if this netblock is directly on any network_interface, and
			-- delete it if force is set, otherwise skip it
			--
			ni_id_ary := ARRAY[]::integer[];

			SELECT 
				ni.network_interface_id,
				nin.netblock_id,
				ni.device_id
			INTO nin_rec
			FROM
				network_interface_netblock nin JOIN
				network_interface ni USING (network_interface_id)
			WHERE
				nin.netblock_id = nb_rec.netblock_id AND
				nin.network_interface_id != ni_id;

			IF FOUND THEN
				IF move_addresses = 'always' OR (
					move_addresses = 'if_same_device' AND 
					nin_rec.device_id = ni_rec.device_id
				)
				THEN
					--
					-- Remove the netblocks from the network_interfaces,
					-- but save them for later so that we can migrate them
					-- after we make sure the shared_netblock exists.
					--
					-- Also, append the network_inteface_id that we
					-- specifically care about, and we'll add them all
					-- below
					--
					WITH z AS (
						DELETE FROM
							network_interface_netblock
						WHERE
							netblock_id = nb_rec.netblock_id
						RETURNING network_interface_id
					)
					SELECT array_agg(network_interface_id) FROM
						(SELECT network_interface_id FROM z) v
					INTO ni_id_ary;
				ELSE
					IF address_errors = 'ignore' THEN
						RAISE DEBUG 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSIF address_errors = 'warn' THEN
						RAISE NOTICE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;

						CONTINUE;
					ELSE
						RAISE 'Netblock % is assigned to network_interface %',
							nb_rec.netblock_id, nin_rec.network_interface_id;
					END IF;
				END IF;

			END IF;

			IF NOT(ni_id = ANY(ni_id_ary)) THEN
				ni_id_ary := array_append(ni_id_ary, ni_id);
			END IF;

			--
			-- See if this netblock already belongs to a shared_network
			--
			SELECT * FROM
				shared_netblock sn
			INTO sn_rec
			WHERE
				sn.netblock_id = nb_rec.netblock_id;

			IF FOUND THEN
				IF sn_rec.shared_netblock_protocol != protocol THEN
					RAISE 'Netblock % (%) is assigned to shared_network %, but the shared_network_protocol does not match (% vs. %)',
						nb_rec.netblock_id,
						nb_rec.ip_address,
						sn_rec.shared_netblock_id,
						sn_rec.shared_netblock_protocol,
						protocol;
				END IF;
			ELSE
				INSERT INTO shared_netblock (
					shared_netblock_protocol,
					netblock_id
				) VALUES (
					protocol,
					nb_rec.netblock_id
				) RETURNING * INTO sn_rec;
			END IF;

			--
			-- Add this to any interfaces that we found above that
			-- need this
			--

			INSERT INTO shared_netblock_network_int (
				shared_netblock_id,
				network_interface_id,
				priority
			) SELECT
				sn_rec.shared_netblock_id,
				x.network_interface_id,
				0
			FROM
				unnest(ni_id_ary) x(network_interface_id)
			ON CONFLICT ON CONSTRAINT pk_ip_group_network_interface DO NOTHING;

			RAISE DEBUG E'Inserted shared_netblock % onto interfaces:\n%',
				sn_rec.shared_netblock_id, jsonb_pretty(to_jsonb(ni_id_ary));
		END LOOP;
		--
		-- Remove any shared_netblocks that are on the interface that are not
		-- supposed to be (and that aren't ignored).
		--

		FOR nin_rec IN
			DELETE FROM
				shared_netblock_network_int snni
			WHERE
				(snni.network_interface_id, snni.shared_netblock_id) IN (
				SELECT
					snni2.network_interface_id,
					snni2.shared_netblock_id
				FROM
					shared_netblock_network_int snni2 JOIN
					shared_netblock sn USING (shared_netblock_id) JOIN
					netblock n USING (netblock_id)
				WHERE
					snni2.network_interface_id = ni_id AND NOT (
						sn.netblock_id = ANY(nb_id_ary) OR
						n.ip_address <<= ANY ( ARRAY (
							SELECT
								n2.ip_address
							FROM
								netblock n2 JOIN
								netblock_collection_netblock ncn USING
									(netblock_id) JOIN
								v_netblock_coll_expanded nce USING
									(netblock_collection_id) JOIN
								property p ON (
									property_name = 'IgnoreProbedNetblocks' AND
									property_type = 'DeviceInventory' AND
									property_value_nblk_coll_id =
										nce.root_netblock_collection_id
								)
						))
					)
			)
			RETURNING *
		LOOP
			RAISE DEBUG 'Removed shared_netblock % from network_interface %',
				nin_rec.shared_netblock_id,
				nin_rec.network_interface_id;

			--
			-- Remove any DNS records, netblocks and shared_netblocks
			-- that aren't used
			--
			SELECT netblock_id INTO nb_id FROM shared_netblock sn WHERE
				sn.shared_netblock_id = nin_rec.shared_netblock_id;
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = nb_id;
				DELETE FROM netblock_collection_netblock ncn WHERE
					ncn.netblock_id = nb_id;
				DELETE FROM shared_netblock WHERE netblock_id = nb_id;
				DELETE FROM netblock WHERE netblock_id = nb_id;
			EXCEPTION
				WHEN foreign_key_violation THEN NULL;
			END;
		END LOOP;
	END IF;
	RETURN true;
END;
$function$
;

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
-- New function
CREATE OR REPLACE FUNCTION account_collection_manip.cleanup_account_collection_account(lifespan interval DEFAULT NULL::interval)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	rv	INTEGER;
BEGIN
	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_collection_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		lifespan := '1 year'::interval;
	END IF;

	--
	-- It is possible that this will fail if there are surprise foreign
	-- keys to the accounts.
	--
	EXECUTE '
		WITH x AS (
			SELECT account_collection_id, account_id
			FROM    account a
				JOIN account_collection_account aca USING (account_id)
				JOIN account_collection ac USING (account_collection_id)
				JOIN person_company pc USING (person_id, company_id)
			WHERE   pc.termination_date IS NOT NULL
			AND     pc.termination_date < now() - $1::interval
			AND	coalesce(aca.data_upd_date, aca.data_ins_date) < pc.termination_date
			AND     account_collection_type != $2
			AND
				(account_collection_id, account_id)  NOT IN
					( SELECT unix_group_acct_collection_id, account_id from
						account_unix_info)
			AND account_collection_id NOT IN (
				SELECT account_collection_id
				FROM account_collection
				WHERE account_collection_type = ''department''
			)
			) DELETE FROM account_collection_account aca
			WHERE (account_collection_id, account_id) IN
				(SELECT account_collection_id, account_id FROM x)
		' USING lifespan, 'per-account';
	GET DIAGNOSTICS rv = ROW_COUNT;
	RETURN rv;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION account_collection_manip.purge_inactive_account_collections(lifespan interval DEFAULT NULL::interval, raise_exception boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_r	RECORD;
	i	INTEGER;
	rv	INTEGER;
BEGIN
	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_collection_purge_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;
	IF lifespan IS NULL THEN
		lifespan := '1 year'::interval;
	END IF;

	--
	-- remove unused account collections
	--
	rv := 0;
	FOR _r IN
		SELECT ac.*
		FROM	account_collection ac
			JOIN val_account_collection_type act USING (account_collection_type)
		WHERE	now() -
			coalesce(ac.data_upd_date,ac.data_ins_date) > lifespan::interval
		AND	act.is_infrastructure_type = 'N'
		AND	account_collection_id NOT IN
			(SELECT child_account_collection_id FROM account_collection_hier)
		AND	account_collection_id NOT IN
			(SELECT account_collection_id FROM account_collection_hier)
		AND	account_collection_id NOT IN
			(SELECT account_collection_id FROM account_collection_account)
		AND	account_collection_id NOT IN
			(SELECT account_collection_id FROM property
				WHERE account_collection_id IS NOT NULL)
		AND	account_collection_id NOT IN
			(SELECT property_value_account_coll_id FROM property
				WHERE property_value_account_coll_id IS NOT NULL)
	LOOP
		BEGIN
			DELETE FROM account_collection
				WHERE account_collection_id = _r.account_collection_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	RETURN rv;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION account_collection_manip.purge_inactive_department_properties(property_type character varying, property_name character varying DEFAULT NULL::character varying, lifespan interval DEFAULT NULL::interval, raise_exception boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r	RECORD;
	rv	INTEGER;
	i	INTEGER;
	_pn	TEXT;
	_pt TEXT;
BEGIN
	_pn := property_name;
	_pt := property_type;
	rv := 0;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_collection_purge_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;
	IF lifespan IS NULL THEN
		lifespan := '1 year'::interval;
	END IF;

	--
	-- delete login assignment to linux machines for departments that are
	-- disabled and not in use
	--
	FOR _r IN SELECT	p.property_id
			FROM	account_collection ac
				JOIN department d USING (account_collection_id)
				JOIN property p USING (account_collection_id)
			WHERE 	d.is_active = 'N'
			AND ((_pn IS NOT NULL AND _pn = p.property_name) OR _pn IS NULL )
			AND	p.property_type = _pt
			AND	account_collection_id NOT IN (
					SELECT child_account_collection_id
					FROM account_collection_hier
				)
			AND	account_collection_id NOT IN (
					SELECT account_collection_id
					FROM account_collection_account
				)
			AND account_collection_id NOT IN (
				SELECT account_collection_id
				FROM	account_collection ac
					JOIN department d USING (account_collection_id)
					JOIN (
						SELECT level, v.account_collection_id,
							ac.account_collection_id as child_account_collection_id,
							account_collection_name as name,
							account_collection_type as type
						FROM	v_acct_coll_expanded 	 v
							JOIN account_collection ac ON v.root_account_collection_id = ac.account_collection_id
							JOIN department d ON ac.account_collection_id = d.account_collection_id
						WHERE	is_active = 'Y'
					) kid USING (account_collection_id)
				WHERE
					is_active = 'N'
			)
	LOOP
		BEGIN
			DELETE FROM property
			WHERE property_id = _r.property_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;


	--
	-- delete unix group overrides to linux machines for departments that are
	-- disabled and not in use
	--
	FOR _r IN SELECT	p.property_id
			FROM	account_collection ac
				JOIN department d USING (account_collection_id)
				JOIN property p ON p.property_value_account_coll_id =
					ac.account_collection_id
			WHERE 	d.is_active = 'N'
			AND ((_pn IS NOT NULL AND _pn = p.property_name) OR _pn IS NULL )
			AND	p.property_type = _pt
			AND	p.property_value_account_coll_id NOT IN (
					SELECT child_account_collection_id
					FROM account_collection_hier
				)
			AND	p.property_value_account_coll_id NOT IN (
					SELECT account_collection_id
					FROM account_collection_account
						JOIN account a USING (account_id)
					WHERE a.is_enabled = 'Y'
				)
			AND p.property_value_account_coll_id NOT IN (
				SELECT account_collection_id
				FROM	account_collection ac
					JOIN department d USING (account_collection_id)
					JOIN (
						SELECT level, v.account_collection_id,
							ac.account_collection_id as child_account_collection_id,
							account_collection_name as name,
							account_collection_type as type
						FROM	v_acct_coll_expanded 	 v
							JOIN account_collection ac ON v.root_account_collection_id = ac.account_collection_id
							JOIN department d ON ac.account_collection_id = d.account_collection_id
						WHERE	is_active = 'Y'
					) kid USING (account_collection_id)
				WHERE
					is_active = 'N'
			)
	LOOP
		BEGIN
			DELETE FROM property
			WHERE property_id = _r.property_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	RETURN rv;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION account_collection_manip.purge_inactive_departments(lifespan interval DEFAULT NULL::interval, raise_exception boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_r	RECORD;
	rv	INTEGER;
	i	INTEGER;
BEGIN
	rv := 0;
	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_collection_purge_interval'
		AND		property_type = '_Defaults';
	END IF;

	IF lifespan IS NULL THEN
		SELECT	property_value::interval
		INTO	lifespan
		FROM	property
		WHERE	property_name = 'account_cleanup_interval'
		AND		property_type = '_Defaults';
	END IF;
	IF lifespan IS NULL THEN
		lifespan := '1 year'::interval;
	END IF;

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'UnixLogin',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'MclassUnixProp',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'StabRole',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'Defaults',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'API',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'DeviceInventory',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	rv := rv + account_collection_manip.purge_inactive_department_properties(
		property_type := 'PhoneDirectoryAttributes',
		lifespan := lifespan,
		raise_exception := raise_exception
	);

	--
	-- remove child account collection membership
	--
	FOR _r IN SELECT	ac.*
			FROM	account_collection ac
				JOIN department d USING (account_collection_id)
			WHERE	d.is_active = 'N'
			AND	account_collection_id IN (
				SELECT child_account_collection_id FROM account_collection_hier
			)
			AND account_collection_id NOT IN (
				SELECT account_collection_id
				FROM	account_collection ac
					JOIN department d USING (account_collection_id)
					JOIN (
						SELECT level, v.account_collection_id,
							ac.account_collection_id as child_account_collection_id,
							account_collection_name as name,
							account_collection_type as type
						FROM	v_acct_coll_expanded 	 v
							JOIN account_collection ac ON v.root_account_collection_id = ac.account_collection_id
							JOIN department d ON ac.account_collection_id = d.account_collection_id
						WHERE	is_active = 'Y'
					) kid USING (account_collection_id)
				WHERE
					is_active = 'N'
			)

	LOOP
		BEGIN
			DELETE FROM account_collection_hier
				WHERE child_account_collection_id = _r.account_collection_id;
			GET DIAGNOSTICS i = ROW_COUNT;
			rv := rv + i;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	RETURN rv;

END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION account_collection_manip.routine_account_collection_cleanup(lifespan interval DEFAULT NULL::interval, raise_exception boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	rv INTEGER;
	c INTEGER;
BEGIN
	select account_collection_manip.cleanup_account_collection_account(lifespan) INTO c;
	rv := c;
	select account_collection_manip.purge_inactive_departments(lifespan, raise_exception) INTO c;

	rv := rv + c;
	select account_collection_manip.purge_inactive_account_collections(lifespan, raise_exception) INTO c;
	rv := rv + c;
	RETURN rv;
END;
$function$
;

--
-- Process drops in script_hooks
--
--
-- Process drops in backend_utils
--
--
-- Process drops in rack_utils
--
--
-- Process drops in layerx_network_manip
--
--
-- Process drops in schema_support
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_diff');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_diff ( schema text, old_rel text, new_rel text, key_relation text, prikeys text[], raise_exception boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_diff(schema text, old_rel text, new_rel text, key_relation text DEFAULT NULL::text, prikeys text[] DEFAULT NULL::text[], raise_exception boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
	_or	RECORD;
	_nr	RECORD;
	_t1	integer;
	_t2	integer;
	_cols TEXT[];
	_q TEXT;
	_f TEXT;
	_c RECORD;
	_w TEXT[];
	_ctl TEXT[];
	_rv	boolean;
	_k	TEXT;
	oj	jsonb;
	nj	jsonb;
BEGIN
	-- do a simple row count
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || old_rel || '"' INTO _t1;
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || new_rel || '"' INTO _t2;

	_rv := true;

	IF _t1 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, old_rel;
		_rv := false;
	END IF;
	IF _t2 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, new_rel;
		_rv := false;
	END IF;

	IF _t1 != _t2 THEN
		RAISE NOTICE 'table % has % rows; table % has % rows', old_rel, _t1, new_rel, _t2;
		_rv := false;
	END IF;

	IF NOT _rv THEN
		IF raise_exception THEN
			RAISE EXCEPTION 'Relations do not match';
		END IF;
		RETURN false;
	END IF;

	IF prikeys IS NULL THEN
		-- read into prikeys the primary key for the table
		IF key_relation IS NULL THEN
			key_relation := old_rel;
		END IF;
		prikeys := schema_support.get_pk_columns(schema, key_relation);
	END IF;

	-- read into _cols the column list in common between old_rel and new_rel
	_cols := schema_support.get_common_columns(schema, old_rel, new_rel);

	FOREACH _f IN ARRAY _cols
	LOOP
		SELECT array_append(_ctl,
			quote_ident(_f) || '::text') INTO _ctl;
	END LOOP;

	_cols := _ctl;

	_q := 'SELECT '|| array_to_string(_cols,',') ||' FROM ' || quote_ident(schema) || '.' ||
		quote_ident(old_rel);

	FOR _or IN EXECUTE _q
	LOOP
		_w = NULL;
		FOREACH _f IN ARRAY prikeys
		LOOP
			FOR _c IN SELECT * FROM json_each_text( row_to_json(_or) )
			LOOP
				IF _c.key = _f THEN
					SELECT array_append(_w,
						quote_ident(_f) || '::text = ' || quote_literal(_c.value))
					INTO _w;
				END IF;
			END LOOP;
		END LOOP;
		_q := 'SELECT ' || array_to_string(_cols,',') ||
			' FROM ' || quote_ident(schema) || '.' ||
			quote_ident(new_rel) || ' WHERE ' ||
			array_to_string(_w, ' AND ' );
		EXECUTE _q INTO _nr;

		IF _or != _nr THEN
			oj = row_to_json(_or);
			nj = row_to_json(_nr);
			FOR _k IN SELECT jsonb_object_keys(oj)
			LOOP
				IF NOT _k = ANY(prikeys) AND oj->>_k IS NOT DISTINCT FROM nj->>_k THEN
					oj = oj - _k;
					nj = nj - _k;
				END IF;
			END LOOP;
			RAISE NOTICE 'mismatched row:';
			RAISE NOTICE 'NEW: %', nj;
			RAISE NOTICE 'OLD: %', oj;
			_rv := false;
		END IF;

	END LOOP;

	IF NOT _rv AND raise_exception THEN
		RAISE EXCEPTION 'Relations do not match';
	END IF;
	return _rv;
END;
$function$
;

--
-- Process drops in component_connection_utils
--
-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
ALTER TABLE dns_record DROP CONSTRAINT IF EXISTS fk_dnsrec_ref_dns_ref_id;
ALTER TABLE dns_record DROP CONSTRAINT IF EXISTS fk_dnsrecord_dnsrecord;
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsvalref_dns_recid
	FOREIGN KEY (dns_value_record_id) REFERENCES dns_record(dns_record_id);

ALTER TABLE dns_record
	ADD CONSTRAINT fk_ref_dnsrec_dnserc
	FOREIGN KEY (reference_dns_record_id, dns_domain_id) REFERENCES dns_record(dns_record_id, dns_domain_id);

-- index
DROP INDEX "jazzhands"."idx_dnsrec_dnstype";
DROP INDEX "jazzhands"."ix_dnsid_domid";
DROP INDEX "jazzhands"."ix_dnsid_netblock_id";
DROP INDEX "jazzhands"."xif8dns_record";
DROP INDEX "jazzhands"."xif9dns_record";
DROP INDEX IF EXISTS "jazzhands"."xif_dns_rec_ip_universe";
CREATE INDEX xif_dns_rec_ip_universe ON dns_record USING btree (ip_universe_id);
DROP INDEX IF EXISTS "jazzhands"."xif_dnsid_dnsdom_id";
CREATE INDEX xif_dnsid_dnsdom_id ON dns_record USING btree (dns_domain_id);
DROP INDEX IF EXISTS "jazzhands"."xif_dnsid_nblk_id";
CREATE INDEX xif_dnsid_nblk_id ON dns_record USING btree (netblock_id);
DROP INDEX IF EXISTS "jazzhands"."xif_dnsrecord_vdnstype";
CREATE INDEX xif_dnsrecord_vdnstype ON dns_record USING btree (dns_type);
DROP INDEX IF EXISTS "jazzhands"."xif_ref_dnsrec_dnserc";
CREATE INDEX xif_ref_dnsrec_dnserc ON dns_record USING btree (reference_dns_record_id, dns_domain_id);
-- triggers
DROP TRIGGER IF EXISTS trigger_validate_network_range_ips ON network_range;
CREATE CONSTRAINT TRIGGER trigger_validate_network_range_ips AFTER INSERT OR UPDATE OF start_netblock_id, stop_netblock_id, parent_netblock_id, network_range_type ON network_range DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE validate_network_range_ips();
DROP TRIGGER IF EXISTS trigger_person_company_attr_change_after_row_hooks ON val_person_company_attr_value;
CREATE TRIGGER trigger_person_company_attr_change_after_row_hooks AFTER INSERT OR UPDATE ON val_person_company_attr_value FOR EACH ROW EXECUTE PROCEDURE person_company_attr_change_after_row_hooks();


-- BEGIN Misc that does not apply to above
CREATE UNIQUE INDEX ON mv_dev_col_root (leaf_id);
CREATE INDEX ON mv_dev_col_root (leaf_type);
CREATE INDEX ON mv_dev_col_root (root_id);
CREATE INDEX ON mv_dev_col_root (root_type);

ALTER VIEW v_network_interface_trans
        alter column is_interface_up set default 'Y'::text;
ALTER VIEW v_network_interface_trans
        alter column should_manage set default 'Y'::text;



-- END Misc that does not apply to above


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
