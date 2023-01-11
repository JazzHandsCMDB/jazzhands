-- Copyright (c) 2013-2020, Todd M. Kover
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

-- Copyright (c) 2012-2014 Matthew Ragan
-- Copyright (c) 2005-2010, Vonage Holdings Corp.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
/*
 * $Id$
 */

 --
-- Name: id_tag(); Type: FUNCTION; Schema: netblock_utils; Owner: jazzhands
--

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'netblock_utils';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS netblock_utils;
                CREATE SCHEMA netblock_utils AUTHORIZATION jazzhands;
		REVOKE USAGE ON SCHEMA netblock_utils FROM public;
		COMMENT ON SCHEMA netblock_utils IS 'part of jazzhands';
        END IF;
END;
$$;

-----------------------------------------------------------------------------
--
-- BEGIN DEPRECATE BELOW
--
-----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(
	in_IpAddress 			netblock.ip_address%type,
	in_Netmask_Bits 		integer DEFAULT NULL,
	in_netblock_type 		netblock.netblock_type%type DEFAULT 'default',
	in_ip_universe_id 		ip_universe.ip_universe_id%type DEFAULT 0,
	in_is_single_address	TEXT DEFAULT 'N',
	in_netblock_id 			netblock.netblock_id%type DEFAULT NULL,
	in_fuzzy_can_subnet 	boolean DEFAULT false,
	can_fix_can_subnet 		boolean DEFAULT false,
	will_soon_be_dropped    boolean DEFAULT true
) RETURNS netblock.netblock_id%type AS
$$
DECLARE
	p_single	BOOLEAN;
BEGIN
	IF in_is_single_address = 'Y' THEN
		p_single := true;
	ELSE
		p_single := false;
	END IF;

	RETURN netblock_utils.find_best_parent_netblock_id(
		ip_address			:= in_IpAddress,
		netmask_bits		:= in_Netmask_Bits,
		netblock_type		:= in_netblock_type,
		ip_universe_id		:= in_ip_universe_id,
		is_single_address	:= p_single,
		netblock_id			:= in_netblock_id,
		fuzzy_can_subnet	:= in_fuzzy_can_subnet,
		can_fix_can_subnet	:= can_fix_can_subnet
	);
END;
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(
	in_netblock_id jazzhands.netblock.netblock_id%type,
	will_soon_be_dropped    boolean DEFAULT true
) RETURNS jazzhands.netblock.netblock_id%type AS $$
DECLARE
	nbrec		RECORD;
BEGIN
	RETURN netblock_utils.find_best_parent_netblock_id(
			ip_address := in_netblock_id
	);
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = jazzhands;


-----------------------------------------------------------------------------
--
-- END DEPRECATE ABOVE
--
-----------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_netblock_id(
	ip_address 			netblock.ip_address%type,
	netmask_bits 		integer DEFAULT NULL,
	netblock_type 		netblock.netblock_type%type DEFAULT 'default',
	ip_universe_id 		ip_universe.ip_universe_id%type DEFAULT 0,
	is_single_address	netblock.is_single_address%type DEFAULT false,
	netblock_id			netblock.netblock_id%type DEFAULT NULL,
	fuzzy_can_subnet	boolean DEFAULT false,
	can_fix_can_subnet	boolean DEFAULT false
) RETURNS netblock.netblock_id%type AS $$
DECLARE
	par_nbid	netblock.netblock_id%type;
BEGIN
	IF (netmask_bits IS NOT NULL) THEN
		ip_address  := set_masklen(ip_address, netmask_bits);
	END IF;

	select  subq.Netblock_Id
	  into	par_nbid
	  from  ( select n.Netblock_Id, n.Ip_Address
		    from netblock n
		   where
		   	find_best_parent_netblock_id.ip_address <<= n.ip_address
		    and n.is_single_address = false
			and n.netblock_type = find_best_parent_netblock_id.netblock_type
			and n.ip_universe_id = find_best_parent_netblock_id.ip_universe_id
		    and (
				(find_best_parent_netblock_id.is_single_address = false AND
					masklen(n.ip_address) < masklen(find_best_parent_netblock_id.ip_address))
				OR
				(find_best_parent_netblock_id.is_single_address = true AND
					can_subnet = false AND
					(find_best_parent_netblock_id.Netmask_Bits IS NULL
						OR masklen(n.ip_address) =
							netmask_bits))
			)
			and (find_best_parent_netblock_id.netblock_id IS NULL OR
				n.netblock_id != find_best_parent_netblock_id.netblock_id)
		order by masklen(n.ip_address) desc
	) subq LIMIT 1;

	IF par_nbid IS NULL
		AND find_best_parent_netblock_id.is_single_address = true
		AND fuzzy_can_subnet
	THEN
		select  subq.Netblock_Id
		  into	par_nbid
		  from  ( select n.Netblock_Id, n.Ip_Address
			    from netblock n
			   where
			   	find_best_parent_netblock_id.ip_address <<= n.ip_address
			    and n.is_single_address = false
				and n.netblock_type = find_best_parent_netblock_id.netblock_type
				and n.ip_universe_id = find_best_parent_netblock_id.ip_universe_id
			    and
					(find_best_parent_netblock_id.is_single_address = true AND can_subnet = 'Y' AND
						(netmask_bits IS NULL
							OR masklen(n.ip_address) = netmask_bits))
				and (find_best_parent_netblock_id.netblock_id IS NULL OR
					n.netblock_id != find_best_parent_netblock_id.netblock_id)
				and n.netblock_id not IN (
					select p.parent_netblock_id from netblock p
						where p.is_single_address = false
						and p.parent_netblock_id is not null
				)
			order by masklen(n.ip_address) desc
		) subq LIMIT 1;

		IF can_fix_can_subnet AND par_nbid IS NOT NULL THEN
			UPDATE netblock n SET can_subnet = false
			WHERE  n.netblock_id = par_nbid;
		END IF;
	END IF;


	return par_nbid;
END;
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_netblock_id(
	netblock_id netblock.netblock_id%type
) RETURNS netblock.netblock_id%type AS $$
DECLARE
	nbrec		RECORD;
BEGIN
	SELECT * INTO nbrec FROM netblock n WHERE
		n.netblock_id = find_best_parent_netblock_id.netblock_id;

	RETURN netblock_utils.find_best_parent_netblock_id(
		ip_address			:= nbrec.ip_address,
		netmask_bits		:= masklen(nbrec.ip_address),
		netblock_type		:= nbrec.netblock_type,
		ip_universe_id		:= nbrec.ip_universe_id,
		is_single_address	:= nbrec.is_single_address,
		netblock_id			:= nbrec.netblock_id
	);
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = jazzhands;

----------------------------------------------------------------------------
--
-- BEGIN below is going away (to comment)
--
----------------------------------------------------------------------------

--
-- moving to netblock_manip.  TO BE RETIRED
--
CREATE OR REPLACE FUNCTION netblock_utils.delete_netblock(
	in_netblock_id	netblock.netblock_id%type
) RETURNS VOID AS $$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	/*
	 * Update netblocks that use this as a parent to point to my parent
	 */
	SELECT
		netblock_id INTO par_nbid
	FROM
		jazzhands.netblock
	WHERE
		netblock_id = in_netblock_id;

	UPDATE
		jazzhands.netblock
	SET
		parent_netblock_id = par_nbid
	WHERE
		parent_netblock_id = in_netblock_id;

	/*
	 * Now delete the record
	 */
	DELETE FROM jazzhands.netblock WHERE netblock_id = in_netblock_id;
END;
$$ LANGUAGE plpgsql SET search_path = jazzhands;

--
-- moving to netblock_manip.  TO BE RETIRED
--
CREATE OR REPLACE FUNCTION netblock_utils.recalculate_parentage(
	in_netblock_id	jazzhands.netblock.netblock_id%type
) RETURNS INTEGER AS $$
DECLARE
	nbrec		RECORD;
	childrec	RECORD;
	nbid		jazzhands.netblock.netblock_id%type;
	ipaddr		inet;

BEGIN
	SELECT * INTO nbrec FROM jazzhands.netblock WHERE
		netblock_id = in_netblock_id;

	nbid := netblock_utils.find_best_parent_id(in_netblock_id);

	UPDATE jazzhands.netblock SET parent_netblock_id = nbid
		WHERE netblock_id = in_netblock_id;

	FOR childrec IN SELECT * FROM jazzhands.netblock WHERE
		parent_netblock_id = nbid
		AND netblock_id != in_netblock_id
	LOOP
		IF (childrec.ip_address <<= nbrec.ip_address) THEN
			UPDATE jazzhands.netblock SET parent_netblock_id = in_netblock_id
				WHERE netblock_id = childrec.netblock_id;
		END IF;
	END LOOP;
	RETURN nbid;
END;
$$ LANGUAGE plpgsql SET search_path = jazzhands;
----------------------------------------------------------------------------
--
-- END above is going away (to comment)
--
----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblock(
	parent_netblock_id		jazzhands.netblock.netblock_id%TYPE,
	netmask_bits			integer DEFAULT NULL,
	single_address			boolean DEFAULT false,
	allocation_method		text DEFAULT NULL,
	desired_ip_address		inet DEFAULT NULL,
	rnd_masklen_threshold   integer DEFAULT 110,
	rnd_max_count           integer DEFAULT 1024
) RETURNS TABLE (
	ip_address		inet,
	netblock_type	jazzhands.netblock.netblock_type%TYPE,
	ip_universe_id	jazzhands.netblock.ip_universe_id%TYPE
) AS $$
BEGIN
	RETURN QUERY SELECT * FROM netblock_utils.find_free_netblocks(
			parent_netblock_id := parent_netblock_id,
			netmask_bits := netmask_bits,
			single_address := single_address,
			allocate_from_bottom := allocate_from_bottom,
			desired_ip_address := desired_ip_address,
			max_addresses := 1);
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = jazzhands;

CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(
	parent_netblock_id		jazzhands.netblock.netblock_id%TYPE,
	netmask_bits			integer DEFAULT NULL,
	single_address			boolean DEFAULT false,
	allocation_method		text DEFAULT NULL,
	max_addresses			integer DEFAULT 1024,
	desired_ip_address		inet DEFAULT NULL,
	rnd_masklen_threshold   integer DEFAULT 110,
	rnd_max_count           integer DEFAULT 1024
) RETURNS TABLE (
	ip_address		inet,
	netblock_type	jazzhands.netblock.netblock_type%TYPE,
	ip_universe_id	jazzhands.netblock.ip_universe_id%TYPE
) AS $$
BEGIN
	RETURN QUERY SELECT * FROM netblock_utils.find_free_netblocks(
		parent_netblock_list := ARRAY[parent_netblock_id],
		netmask_bits := netmask_bits,
		single_address := single_address,
		allocation_method := allocation_method,
		desired_ip_address := desired_ip_address,
		max_addresses := max_addresses);
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = jazzhands;

CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(
	parent_netblock_list	integer[],
	netmask_bits			integer DEFAULT NULL,
	single_address			boolean DEFAULT false,
	allocation_method		text DEFAULT NULL,
	max_addresses			integer DEFAULT 1024,
	desired_ip_address		inet DEFAULT NULL,
	rnd_masklen_threshold   integer DEFAULT 110,
	rnd_max_count           integer DEFAULT 1024
) RETURNS TABLE (
	ip_address		inet,
	netblock_type	jazzhands.netblock.netblock_type%TYPE,
	ip_universe_id	jazzhands.netblock.ip_universe_id%TYPE
) AS $$
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

		IF single_address AND netblock_rec.can_subnet = true THEN
			RAISE EXCEPTION 'single addresses may not be assigned to to a block where can_subnet is Y';
		END IF;

		IF (NOT single_address) AND netblock_rec.can_subnet = false THEN
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
					family(current_ip) = family(start_nb.ip_address) AND
					family(current_ip) = family(stop_nb.ip_address) AND
					(
						nr.start_netblock_id = start_nb.netblock_id AND
						nr.stop_netblock_id = stop_nb.netblock_id AND
						nr.parent_netblock_id = netblock_rec.netblock_id AND
						start_nb.ip_address <=
							set_masklen(current_ip, masklen(start_nb.ip_address))
						AND stop_nb.ip_address >=
							set_masklen(current_ip, masklen(stop_nb.ip_address))
					);

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
$$ LANGUAGE 'plpgsql';



CREATE OR REPLACE FUNCTION netblock_utils.list_unallocated_netblocks(
	netblock_id		jazzhands.netblock.netblock_id%TYPE DEFAULT NULL,
	ip_address		inet DEFAULT NULL,
	ip_universe_id	integer DEFAULT 0,
	netblock_type	text DEFAULT 'default'
) RETURNS TABLE (
	ip_addr			inet
) AS $$
DECLARE
	ip_array		inet[];
	netblock_rec	RECORD;
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	family_bits		integer;
	idx				integer;
	subnettable		boolean;
BEGIN
	subnettable := true;
	IF netblock_id IS NOT NULL THEN
		SELECT * INTO netblock_rec FROM jazzhands.netblock n WHERE n.netblock_id =
			list_unallocated_netblocks.netblock_id;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'netblock_id % not found', netblock_id;
		END IF;
		IF netblock_rec.is_single_address = true THEN
			RETURN;
		END IF;
		ip_address := netblock_rec.ip_address;
		ip_universe_id := netblock_rec.ip_universe_id;
		netblock_type := netblock_rec.netblock_type;
		subnettable := CASE WHEN netblock_rec.can_subnet = false
			THEN false ELSE true
			END;
	ELSIF ip_address IS NOT NULL THEN
		ip_universe_id := 0;
		netblock_type := 'default';
	ELSE
		RAISE EXCEPTION 'netblock_id or ip_address must be passed';
	END IF;
	IF (subnettable) THEN
		SELECT ARRAY(
			SELECT
				n.ip_address
			FROM
				netblock n
			WHERE
				n.ip_address <<= list_unallocated_netblocks.ip_address AND
				n.ip_universe_id = list_unallocated_netblocks.ip_universe_id AND
				n.netblock_type = list_unallocated_netblocks.netblock_type AND
				is_single_address = false AND
				can_subnet = false
			ORDER BY
				n.ip_address
		) INTO ip_array;
	ELSE
		SELECT ARRAY(
			SELECT
				set_masklen(n.ip_address,
					CASE WHEN family(n.ip_address) = 4 THEN 32
					ELSE 128
					END)
			FROM
				netblock n
			WHERE
				n.ip_address <<= list_unallocated_netblocks.ip_address AND
				n.ip_address != list_unallocated_netblocks.ip_address AND
				n.ip_universe_id = list_unallocated_netblocks.ip_universe_id AND
				n.netblock_type = list_unallocated_netblocks.netblock_type
			ORDER BY
				n.ip_address
		) INTO ip_array;
	END IF;

	IF array_length(ip_array, 1) IS NULL THEN
		ip_addr := ip_address;
		RETURN NEXT;
		RETURN;
	END IF;

	ip_array := array_prepend(
		list_unallocated_netblocks.ip_address - 1,
		array_append(
			ip_array,
			broadcast(list_unallocated_netblocks.ip_address) + 1
			));

	idx := 1;
	WHILE idx < array_length(ip_array, 1) LOOP
		RETURN QUERY SELECT cin.ip_addr FROM
			netblock_utils.calculate_intermediate_netblocks(ip_array[idx], ip_array[idx + 1]) cin;
		idx := idx + 1;
	END LOOP;

	RETURN;
END;
$$ LANGUAGE 'plpgsql'
SECURITY DEFINER
SET search_path = jazzhands;

CREATE OR REPLACE FUNCTION netblock_utils.calculate_intermediate_netblocks(
	ip_block_1		inet DEFAULT NULL,
	ip_block_2		inet DEFAULT NULL,
	netblock_type	text DEFAULT 'default',
	ip_universe_id	integer DEFAULT 0
) RETURNS TABLE (
	ip_addr			inet
) AS $$
DECLARE
	current_nb		inet;
	new_nb			inet;
	min_addr		inet;
	max_addr		inet;
	family_bits		integer;
BEGIN
	IF ip_block_1 IS NULL OR ip_block_2 IS NULL THEN
		RAISE EXCEPTION 'Must specify both ip_block_1 and ip_block_2';
	END IF;

	IF family(ip_block_1) != family(ip_block_2) THEN
		RAISE EXCEPTION 'families of ip_block_1 and ip_block_2 must match';
	END IF;

	-- Make sure these are network blocks
	ip_block_1 := network(ip_block_1);
	ip_block_2 := network(ip_block_2);

	-- If the blocks are subsets of each other, then error

	IF ip_block_1 <<= ip_block_2 AND ip_block_2 <<= ip_block_1 THEN
		RAISE EXCEPTION 'netblocks % and % intersect each other',
			ip_block_1,
			ip_block_2;
	END IF;

	-- Order the blocks correctly

	IF ip_block_1 > ip_block_2 THEN
		new_nb := ip_block_1;
		ip_block_1 := ip_block_2;
		ip_block_2 := new_nb;
	END IF;

	current_nb := ip_block_1;
	max_addr := broadcast(ip_block_1);

	family_bits := CASE WHEN family(ip_block_1) = 4 THEN 32 ELSE 128 END;

	-- Loop through bumping the netmask up and seeing if the destination block is in the new block
	LOOP
		new_nb := network(set_masklen(current_nb, masklen(current_nb) - 1));

		-- If the block is in our new larger netblock, then exit this loop
		IF (new_nb >>= ip_block_2) THEN
			current_nb := broadcast(current_nb) + 1;
			EXIT;
		END IF;

		-- If the max address of the new netblock is larger than the last one, then it's empty
		IF set_masklen(broadcast(new_nb), family_bits) >
			set_masklen(max_addr, family_bits)
		THEN
			ip_addr := set_masklen(max_addr + 1, masklen(current_nb));
			-- Validate that this isn't an empty can_subnet=true block already
			-- If it is, split it in half and return both halves
			PERFORM * FROM netblock n WHERE
				n.ip_address = ip_addr AND
				n.ip_universe_id =
					calculate_intermediate_netblocks.ip_universe_id AND
				n.netblock_type =
					calculate_intermediate_netblocks.netblock_type;
			IF FOUND AND masklen(ip_addr) < family_bits THEN
				ip_addr := set_masklen(ip_addr, masklen(ip_addr) + 1);
				RETURN NEXT;
				ip_addr := broadcast(ip_addr) + 1;
				RETURN NEXT;
			ELSE
				RETURN NEXT;
			END IF;
			max_addr := broadcast(new_nb);
		END IF;
		current_nb := new_nb;
	END LOOP;

	-- Now loop through there to find the unused blocks at the front

	LOOP
		IF host(current_nb) = host(ip_block_2) OR
			masklen(current_nb) >= family_bits
		THEN
			RETURN;
		END IF;

		current_nb := set_masklen(current_nb, masklen(current_nb) + 1);
		IF NOT (current_nb >>= ip_block_2) THEN
			ip_addr := current_nb;
			-- Validate that this isn't an empty can_subnet=true block already
			-- If it is, split it in half and return both halves
			PERFORM * FROM netblock n WHERE
				n.ip_address = ip_addr AND
				n.ip_universe_id =
					calculate_intermediate_netblocks.ip_universe_id AND
				n.netblock_type =
					calculate_intermediate_netblocks.netblock_type;
			IF FOUND AND masklen(ip_addr) < family_bits THEN
				ip_addr := set_masklen(ip_addr, masklen(ip_addr) + 1);
				RETURN NEXT;
				ip_addr := broadcast(ip_addr) + 1;
				RETURN NEXT;
			ELSE
				RETURN NEXT;
			END IF;
			current_nb := broadcast(current_nb) + 1;
			CONTINUE;
		END IF;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = jazzhands;

CREATE OR REPLACE FUNCTION netblock_utils.find_best_ip_universe(
	ip_address	jazzhands.netblock.ip_address%type,
	ip_namespace	jazzhands.ip_universe.ip_namespace%type
				DEFAULT 'default'
) RETURNS jazzhands.ip_universe.ip_universe_id%type AS $$
DECLARE
	u_id	ip_universe.ip_universe_id%TYPE;
	ip	inet;
	nsp	text;
BEGIN
	ip := ip_address;
	nsp := ip_namespace;

	SELECT	nb.ip_universe_id
	INTO	u_id
	FROM	netblock nb
		JOIN ip_universe u USING (ip_universe_id)
	WHERE	is_single_address = false
	AND	nb.ip_address >>= ip
	AND	u.ip_namespace = 'default'
	ORDER BY masklen(nb.ip_address) desc
	LIMIT 1;

	IF u_id IS NOT NULL THEN
		RETURN u_id;
	END IF;
	RETURN 0;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = jazzhands;

CREATE OR REPLACE FUNCTION netblock_utils.find_best_visible_ip_universe(
	ip_address	jazzhands.netblock.ip_address%type,
	ip_universe_id	jazzhands.ip_universe.ip_universe_id%type DEFAULT 0,
	permitted_ip_universe_ids	INTEGER[] DEFAULT NULL
) RETURNS jazzhands.ip_universe.ip_universe_id%type AS $$
DECLARE
	ip	ALIAS FOR ip_address;
	myu	ALIAS FOR ip_universe_id;
	u_id	ip_universe.ip_universe_id%TYPE;
BEGIN
	SELECT	nb.ip_universe_id
	INTO	u_id
	FROM	netblock nb
	WHERE	(
			nb.ip_universe_id IN (
				SELECT v.visible_ip_universe_id FROM ip_universe_visibility  v
					WHERE v.ip_universe_id = myu
			) OR nb.ip_universe_id = myu
	) AND (
		permitted_ip_universe_ids IS NULL
		OR
		nb.ip_universe_id = ANY(permitted_ip_universe_ids)
	)
	AND is_single_address = false
	AND	nb.ip_address >>= find_best_visible_ip_universe.ip_address
	ORDER BY masklen(nb.ip_address) desc
	LIMIT 1;

	IF u_id IS NOT NULL THEN
		RETURN u_id;
	END IF;
	RETURN NULL;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = jazzhands;

REVOKE USAGE ON SCHEMA netblock_utils FROM public;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA netblock_utils FROM public;

GRANT USAGE ON SCHEMA netblock_utils TO ro_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA netblock_utils TO ro_role;
