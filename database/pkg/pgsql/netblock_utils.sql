-- Copyright (c) 2013-2014, Todd M. Kover
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


-- Create schema if it does not exist, do nothing otherwise.
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
        END IF;
END;
$$;


CREATE OR REPLACE FUNCTION netblock_utils.id_tag() RETURNS character varying
	LANGUAGE plpgsql
	AS $_$
BEGIN
	RETURN('<-- $Id -->');
END;
$_$;

CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(
	in_IpAddress jazzhands.netblock.ip_address%type,
	in_Netmask_Bits integer DEFAULT NULL,
	in_netblock_type jazzhands.netblock.netblock_type%type DEFAULT 'default',
	in_ip_universe_id jazzhands.ip_universe.ip_universe_id%type DEFAULT 0,
	in_is_single_address jazzhands.netblock.is_single_address%type DEFAULT 'N',
	in_netblock_id jazzhands.netblock.netblock_id%type DEFAULT NULL,
	in_fuzzy_can_subnet boolean DEFAULT false,
	can_fix_can_subnet boolean DEFAULT false
) RETURNS jazzhands.netblock.netblock_id%type AS $$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	IF (in_netmask_bits IS NOT NULL) THEN
		in_IpAddress := set_masklen(in_IpAddress, in_Netmask_Bits);
	END IF;

	select  Netblock_Id
	  into	par_nbid
	  from  ( select Netblock_Id, Ip_Address
		    from netblock
		   where
		   	in_IpAddress <<= ip_address
		    and is_single_address = 'N'
			and netblock_type = in_netblock_type
			and ip_universe_id = in_ip_universe_id
		    and (
				(in_is_single_address = 'N' AND 
					masklen(ip_address) < masklen(In_IpAddress))
				OR
				(in_is_single_address = 'Y' AND can_subnet = 'N' AND
					(in_Netmask_Bits IS NULL 
						OR masklen(Ip_Address) = in_Netmask_Bits))
			)
			and (in_netblock_id IS NULL OR
				netblock_id != in_netblock_id)
		order by masklen(ip_address) desc
	) subq LIMIT 1;

	IF par_nbid IS NULL AND in_is_single_address = 'Y' AND in_fuzzy_can_subnet THEN
		select  Netblock_Id
		  into	par_nbid
		  from  ( select Netblock_Id, Ip_Address, Netmask_Bits
			    from netblock
			   where
			   	in_IpAddress <<= ip_address
			    and is_single_address = 'N'
				and netblock_type = in_netblock_type
				and ip_universe_id = in_ip_universe_id
			    and 
					(in_is_single_address = 'Y' AND can_subnet = 'Y' AND
						(in_Netmask_Bits IS NULL 
							OR masklen(Ip_Address) = in_Netmask_Bits))
				and (in_netblock_id IS NULL OR
					netblock_id != in_netblock_id)
				and netblock_id not IN (
					select parent_netblock_id from netblock 
						where is_single_address = 'N'
						and parent_netblock_id is not null
				)
			order by masklen(ip_address) desc
		) subq LIMIT 1;

		IF can_fix_can_subnet AND par_nbid IS NOT NULL THEN
			UPDATE netblock SET can_subnet = 'N' where netblock_id = par_nbid;
		END IF;
	END IF;


	return par_nbid;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(
	in_netblock_id jazzhands.netblock.netblock_id%type
) RETURNS jazzhands.netblock.netblock_id%type AS $$
DECLARE
	nbrec		RECORD;
BEGIN
	SELECT * INTO nbrec FROM jazzhands.netblock WHERE 
		netblock_id = in_netblock_id;

	RETURN netblock_utils.find_best_parent_id(
		nbrec.ip_address,
		masklen(nbrec.ip_address),
		nbrec.netblock_type,
		nbrec.ip_universe_id,
		nbrec.is_single_address,
		in_netblock_id
	);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.delete_netblock(
	in_netblock_id	jazzhands.netblock.netblock_id%type
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
$$ LANGUAGE plpgsql;

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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.find_rvs_zone_from_netblock_id(
	in_netblock_id	jazzhands.netblock.netblock_id%type
) RETURNS jazzhands.dns_domain.dns_domain_id%type AS $$
DECLARE
	v_rv	jazzhands.dns_domain.dns_domain_id%type;
	v_domid	jazzhands.dns_domain.dns_domain_id%type;
	v_lhsip	jazzhands.netblock.ip_address%type;
	v_rhsip	jazzhands.netblock.ip_address%type;
	nb_match CURSOR ( in_nb_id jazzhands.netblock.netblock_id%type) FOR
		-- The query used to include this in the where clause, but
		-- oracle was uber slow 
		--	net_manip.inet_base(nb.ip_address, root.netmask_bits) =  
		--		net_manip.inet_base(root.ip_address, root.netmask_bits) 
		select  rootd.dns_domain_id,
				 net_manip.inet_base(nb.ip_address, root.netmask_bits),
				 net_manip.inet_base(root.ip_address, root.netmask_bits)
		  from  jazzhands.netblock nb,
			jazzhands.netblock root
				inner join jazzhands.dns_record rootd
					on rootd.netblock_id = root.netblock_id
					and rootd.dns_type = 'REVERSE_ZONE_BLOCK_PTR'
		 where
		  	nb.netblock_id = in_nb_id;
BEGIN
	v_rv := NULL;
	OPEN nb_match(in_netblock_id);
	LOOP
		FETCH  nb_match INTO v_domid, v_lhsip, v_rhsip;
		if NOT FOUND THEN
			EXIT;
		END IF;

		if v_lhsip = v_rhsip THEN
			v_rv := v_domid;
			EXIT;
		END IF;
	END LOOP;
	CLOSE nb_match;
	return v_rv;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblock(
	parent_netblock_id		jazzhands.netblock.netblock_id%TYPE,
	netmask_bits			integer DEFAULT NULL,
	single_address			boolean DEFAULT false,
	allocate_from_bottom	boolean DEFAULT true
) RETURNS TABLE (
	ip_address		inet,
	netblock_type	jazzhands.netblock.netblock_type%TYPE,
	ip_universe_id	jazzhands.netblock.ip_universe_id%TYPE
) AS $$
BEGIN
	RETURN QUERY SELECT netblock_utils.find_free_netblocks(
		parent_netblock_id := parent_netblock_id,
		netmask_bits := netmask_bits,
		single_address := single_address,
		allocate_from_bottom := allocate_from_bottom,
		max_addresses := 1);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(
	parent_netblock_id		jazzhands.netblock.netblock_id%TYPE,
	netmask_bits			integer DEFAULT NULL,
	single_address			boolean DEFAULT false,
	allocate_from_bottom	boolean DEFAULT true,
	max_addresses			integer DEFAULT 1024
) RETURNS TABLE (
	ip_address		inet,
	netblock_type	jazzhands.netblock.netblock_type%TYPE,
	ip_universe_id	jazzhands.netblock.ip_universe_id%TYPE
) AS $$
BEGIN
	RETURN QUERY SELECT netblock_utils.find_free_netblocks(
		parent_netblock_list := ARRAY[parent_netblock_id],
		netmask_bits := netmask_bits,
		single_address := single_address,
		allocate_from_bottom := allocate_from_bottom,
		max_addresses := max_addresses);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(
	parent_netblock_list	integer[],
	netmask_bits			integer DEFAULT NULL,
	single_address			boolean DEFAULT false,
	allocate_from_bottom	boolean DEFAULT true,
	max_addresses			integer DEFAULT 1024
) RETURNS TABLE (
	ip_address		inet,
	netblock_type	jazzhands.netblock.netblock_type%TYPE,
	ip_universe_id	jazzhands.netblock.ip_universe_id%TYPE
) AS $$
DECLARE
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	step			integer;
	nb_size			integer;
	offset			integer;
	netblock_rec	jazzhands.netblock%ROWTYPE;
	current_ip		inet;
	min_ip			inet;
	max_ip			inet;
	matches			integer;
	family_bits		integer;
BEGIN
	matches := 0;
	FOREACH parent_nbid IN ARRAY parent_netblock_list LOOP
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

		IF single_address THEN 
			netmask_bits := family_bits;
		ELSIF netmask_bits <= masklen(netblock_rec.ip_address) THEN
			RAISE EXCEPTION 'netmask_bits must be larger than the netblock (%)',
				masklen(netblock_rec.ip_address);
		END IF;

		IF netmask_bits > family_bits
			THEN
			RAISE EXCEPTION 'netmask_bits must be no more than % for netblock %',
				family_bits,
				netblock_rec.ip_address;
		END IF;

		IF single_address AND netblock_rec.can_subnet = 'Y' THEN
			RAISE EXCEPTION 'single addresses may not be assigned to to a block where can_subnet is Y';
		END IF;

		IF (NOT single_address) AND netblock_rec.can_subnet = 'N' THEN
			RAISE EXCEPTION 'Netblock % (%) may not be subnetted',
				netblock_rec.ip_address,
				netblock_rec.netblock_id;
		END IF;

		-- It would be nice to be able to use generate_series here, but
		-- that could get really huge

		nb_size := 1 << ( family_bits - netmask_bits );
		min_ip := netblock_rec.ip_address;
		max_ip := min_ip + (1 << (family_bits - masklen(min_ip)));

		IF allocate_from_bottom THEN
			current_ip := set_masklen(netblock_rec.ip_address, netmask_bits);
		ELSE
			current_ip := set_masklen(max_ip, netmask_bits) - nb_size;
			nb_size := -nb_size;
		END IF;

		RAISE DEBUG 'Searching netblock % (%)',
			netblock_rec.netblock_id,
			netblock_rec.ip_address;

		-- For single addresses, make the netmask match the netblock of the
		-- containing block, and skip the network and broadcast addresses

		IF single_address THEN
			current_ip := set_masklen(current_ip, masklen(netblock_rec.ip_address));
			IF family(netblock_rec.ip_address) = 4 AND
					masklen(netblock_rec.ip_address) < 31 THEN
				current_ip := current_ip + nb_size;
				min_ip := min_ip - 1;
				max_ip := max_ip - 1;
			END IF;
		END IF;

		RAISE DEBUG 'Starting with IP address % with step of %',
			current_ip,
			nb_size;

		WHILE (
				current_ip >= min_ip AND
				current_ip < max_ip AND
				matches < max_addresses
		) LOOP
			RAISE DEBUG '   Checking netblock %', current_ip;

			PERFORM * FROM netblock n WHERE
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
			IF NOT FOUND THEN
				find_free_netblocks.netblock_type :=
					netblock_rec.netblock_type;
				find_free_netblocks.ip_universe_id :=
					netblock_rec.ip_universe_id;
				find_free_netblocks.ip_address := current_ip;
				RETURN NEXT;
				matches := matches + 1;
			END IF;

			current_ip := current_ip + nb_size;
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
BEGIN
	IF netblock_id IS NOT NULL THEN
		SELECT * INTO netblock_rec FROM netblock n WHERE n.netblock_id = 
			list_unallocated_netblocks.netblock_id;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'netblock_id % not found', netblock_id;
		END IF;
		IF netblock_rec.is_single_address = 'Y' THEN
			RETURN;
		END IF;
		ip_address := netblock_rec.ip_address;
		ip_universe_id := netblock_rec.ip_universe_id;
		netblock_type := netblock_rec.netblock_type;
	ELSIF ip_address IS NULL THEN
		RAISE EXCEPTION 'netblock_id or ip_address must be passed';
	END IF;
	SELECT ARRAY(
		SELECT 
			n.ip_address
		FROM
			netblock n
		WHERE
			n.ip_address <<= list_unallocated_netblocks.ip_address AND
			n.ip_universe_id = list_unallocated_netblocks.ip_universe_id AND
			n.netblock_type = list_unallocated_netblocks.netblock_type AND
			is_single_address = 'N' AND
			can_subnet = 'N'
		ORDER BY
			n.ip_address
	) INTO ip_array;

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
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION netblock_utils.calculate_intermediate_netblocks(
	ip_block_1		inet DEFAULT NULL,
	ip_block_2		inet DEFAULT NULL
) RETURNS TABLE (
	ip_addr			inet
) AS $$
DECLARE
	current_nb		inet;
	new_nb			inet;
	min_addr		inet;
	max_addr		inet;
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

	IF ip_block_1 <<= ip_block_2 OR ip_block_2 <<= ip_block_1 THEN
		RAISE EXCEPTION 'netblocks intersect each other';
	END IF;

	-- Order the blocks correctly

	IF ip_block_1 > ip_block_2 THEN
		new_nb := ip_block_1;
		ip_block_1 := ip_block_2;
		ip_block_2 := new_nb;
	END IF;

	current_nb := ip_block_1;
	max_addr := broadcast(ip_block_1);

	-- Loop through bumping the netmask up and seeing if the destination block is in the new block
	LOOP
		new_nb := network(set_masklen(current_nb, masklen(current_nb) - 1));

		-- If the block is in our new larger netblock, then exit this loop
		IF (new_nb >>= ip_block_2) THEN
			current_nb := broadcast(current_nb) + 1;
			EXIT;
		END IF;
	
		-- If the max address of the new netblock is larger than the last one, then it's empty
		IF set_masklen(broadcast(new_nb), 32) > set_masklen(max_addr, 32) THEN
			ip_addr := set_masklen(max_addr + 1, masklen(current_nb));
			RETURN NEXT;
			max_addr := broadcast(new_nb);
		END IF;
		current_nb := new_nb;
	END LOOP;

	-- Now loop through there to find the unused blocks at the front

	LOOP
		IF host(current_nb) = host(ip_block_2) THEN
			RETURN;
		END IF;
		current_nb := set_masklen(current_nb, masklen(current_nb) + 1);
		IF NOT (current_nb >>= ip_block_2) THEN
			ip_addr := current_nb;
			RETURN NEXT;
			current_nb := broadcast(current_nb) + 1;
			CONTINUE;
		END IF;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql;
