-- Copyright (c) 2014 Matthew Ragan
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

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'netblock_manip';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS netblock_manip;
                CREATE SCHEMA netblock_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA netblock_manip IS 'part of jazzhands';
        END IF;
END;
$$;

CREATE OR REPLACE FUNCTION netblock_manip.delete_netblock(
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

CREATE OR REPLACE FUNCTION netblock_manip.recalculate_parentage(
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

CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(
	parent_netblock_id		jazzhands.netblock.netblock_id%TYPE,
	netmask_bits			integer DEFAULT NULL,
	address_type			text DEFAULT 'netblock',
	-- alternatvies: 'single', 'loopback'
	can_subnet				boolean DEFAULT true,
	allocation_method		text DEFAULT NULL,
	-- alternatives: 'top', 'bottom', 'random',
	rnd_masklen_threshold	integer DEFAULT 110,
	rnd_max_count			integer DEFAULT 1024,
	ip_address				jazzhands.netblock.ip_address%TYPE DEFAULT NULL,
	description				jazzhands.netblock.description%TYPE DEFAULT NULL,
	netblock_status			jazzhands.netblock.netblock_status%TYPE
								DEFAULT 'Allocated'
) RETURNS jazzhands.netblock AS $$
DECLARE
	netblock_rec	RECORD;
BEGIN
	SELECT * into netblock_rec FROM netblock_manip.allocate_netblock(
		parent_netblock_list := ARRAY[parent_netblock_id],
		netmask_bits := netmask_bits,
		address_type := address_type,
		can_subnet := can_subnet,
		description := description,
		allocation_method := allocation_method,
		ip_address := ip_address,
		rnd_masklen_threshold := rnd_masklen_threshold,
		rnd_max_count := rnd_max_count,
		netblock_status := netblock_status
	);
	RETURN netblock_rec;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(
	parent_netblock_list	integer[],
	netmask_bits			integer DEFAULT NULL,
	address_type			text DEFAULT 'netblock',
	-- alternatives: 'single', 'loopback'
	can_subnet				boolean DEFAULT true,
	allocation_method		text DEFAULT NULL,
	-- alternatives: 'top', 'bottom', 'random',
	rnd_masklen_threshold	integer DEFAULT 110,
	rnd_max_count			integer DEFAULT 1024,
	ip_address				jazzhands.netblock.ip_address%TYPE DEFAULT NULL,
	description				jazzhands.netblock.description%TYPE DEFAULT NULL,
	netblock_status			jazzhands.netblock.netblock_status%TYPE
								DEFAULT 'Allocated'
) RETURNS jazzhands.netblock AS $$
DECLARE
	parent_rec		RECORD;
	netblock_rec	RECORD;
	inet_rec		RECORD;
	loopback_bits	integer;
	inet_family		integer;
BEGIN
	IF parent_netblock_list IS NULL THEN
		RAISE 'parent_netblock_list must be specified'
		USING ERRCODE = 'null_value_not_allowed';
	END IF;

	IF address_type NOT IN ('netblock', 'single', 'loopback') THEN
		RAISE 'address_type must be one of netblock, single, or loopback'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF netmask_bits IS NULL AND address_type = 'netblock' THEN
		RAISE EXCEPTION
			'You must specify a netmask when address_type is netblock'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	-- Lock the parent row, which should keep parallel processes from
	-- trying to obtain the same address

	FOR parent_rec IN SELECT * FROM jazzhands.netblock WHERE netblock_id = 
			ANY(allocate_netblock.parent_netblock_list) FOR UPDATE LOOP

		IF parent_rec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'parent_netblock_id refers to a single_address netblock'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF inet_family IS NULL THEN
			inet_family := family(parent_rec.ip_address);
		ELSIF inet_family != family(parent_rec.ip_address) 
				AND ip_address IS NULL THEN
			RAISE EXCEPTION 'Allocation may not mix IPv4 and IPv6 addresses'
			USING ERRCODE = 'JH10F';
		END IF;

		IF address_type = 'loopback' THEN
			loopback_bits := 
				CASE WHEN 
					family(parent_rec.ip_address) = 4 THEN 32 ELSE 128 END;

			IF parent_rec.can_subnet = 'N' THEN
				RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
					USING ERRCODE = 'JH10B';
			END IF;
		ELSIF address_type = 'single' THEN
			IF parent_rec.can_subnet = 'Y' THEN
				RAISE EXCEPTION
					'parent subnet for single address must have can_subnet set to N'
					USING ERRCODE = 'JH10B';
			END IF;
		ELSIF address_type = 'netblock' THEN
			IF parent_rec.can_subnet = 'N' THEN
				RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
					USING ERRCODE = 'JH10B';
			END IF;
		END IF;
	END LOOP;

 	IF NOT FOUND THEN
 		RETURN NULL;
 	END IF;

	IF address_type = 'loopback' THEN
		-- If we're allocating a loopback address, then we need to create
		-- a new parent to hold the single loopback address

		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := loopback_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN NULL;
		END IF;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'N',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO parent_rec;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			parent_rec.netblock_type,
			'Y',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN netblock_rec;
	END IF;

	IF address_type = 'single' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			single_address := true,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			rnd_masklen_threshold := rnd_masklen_threshold,
			rnd_max_count := rnd_max_count,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN NULL;
		END IF;

		RAISE DEBUG 'ip_address is %', inet_rec.ip_address;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'Y',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		RETURN netblock_rec;
	END IF;
	IF address_type = 'netblock' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := netmask_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1);

		IF NOT FOUND THEN
			RETURN NULL;
		END IF;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'N',
			CASE WHEN can_subnet THEN 'Y' ELSE 'N' END,
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN netblock_rec;
	END IF;
END;
$$ LANGUAGE plpgsql;

GRANT USAGE ON SCHEMA netblock_manip TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA netblock_manip TO iud_role;
