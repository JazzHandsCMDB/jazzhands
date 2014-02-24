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

drop schema if exists netblock_manip cascade;
create schema netblock_manip authorization jazzhands;

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
	allocate_from_bottom	boolean DEFAULT true,
	description				jazzhands.netblock.description%TYPE DEFAULT NULL,
	netblock_status			jazzhands.netblock.netblock_status%TYPE
								DEFAULT NULL
) RETURNS jazzhands.netblock AS $$
DECLARE
	parent_rec		RECORD;
	netblock_rec	RECORD;
	inet_rec		inet;
	loopback_bits	integer;
BEGIN
	IF parent_netblock_id IS NULL THEN
		RAISE 'parent_netblock_id must be specified'
		USING ERRCODE = 'null_value_not_allowed';
	END IF;

	IF address_type NOT IN ('netblock', 'single', 'loopback') THEN
		RAISE 'address_type must be one of netblock, single, or loopback'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;
		
	-- Lock the parent row, which should keep parallel processes from
	-- trying to obtain the same address

	SELECT * INTO parent_rec FROM netblock WHERE netblock_id = 
		allocate_netblock.parent_netblock_id FOR UPDATE;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'parent_netblock_id % is not valid',
			allocate_netblock.parent_netblock_id
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF parent_rec.is_single_address = 'Y' THEN
		RAISE EXCEPTION 'parent_netblock_id refers to a single_address netblock'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF netmask_bits IS NULL AND address_type = 'netblock' THEN
		RAISE EXCEPTION
			'You must either specify a netmask when address_type is netblock'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF address_type = 'loopback' THEN
		IF parent_rec.can_subnet = 'N' THEN
			RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
				USING ERRCODE = 'JH10B';
		END IF;

		-- If we're allocating a loopback address, then we need to create
		-- a new parent to hold the single loopback address

		loopback_bits := 
			CASE WHEN family(parent_rec.ip_address) = 4 THEN 32 ELSE 128 END;

		SELECT netblock_utils.find_free_netblock(
			parent_netblock_id := parent_netblock_id,
			netmask_bits := loopback_bits,
			single_address := false,
			allocate_from_bottom := allocate_from_bottom) INTO inet_rec;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'No valid netblocks found to allocate'
			USING ERRCODE = 'JH110';
		END IF;

		INSERT INTO netblock (
			ip_address,
			netmask_bits,
			netblock_type,
			is_ipv4_address,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec,
			loopback_bits,
			parent_rec.netblock_type,
			parent_rec.is_ipv4_address,
			'N',
			'N',
			parent_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO parent_rec;

		INSERT INTO netblock (
			ip_address,
			netmask_bits,
			netblock_type,
			is_ipv4_address,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec,
			masklen(inet_rec),
			parent_rec.netblock_type,
			parent_rec.is_ipv4_address,
			'Y',
			'N',
			parent_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		RETURN netblock_rec;
	END IF;

	IF address_type = 'single' THEN
		IF parent_rec.can_subnet = 'Y' THEN
			RAISE EXCEPTION
				'parent subnet for single address must have can_subnet set to N'
				USING ERRCODE = 'JH10B';
		END IF;

		SELECT netblock_utils.find_free_netblock(
			parent_netblock_id := parent_rec.netblock_id,
			single_address := true,
			allocate_from_bottom := allocate_from_bottom) INTO inet_rec;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'No valid netblocks found to allocate'
			USING ERRCODE = 'JH110';
		END IF;

		INSERT INTO netblock (
			ip_address,
			netmask_bits,
			netblock_type,
			is_ipv4_address,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec,
			masklen(inet_rec),
			parent_rec.netblock_type,
			parent_rec.is_ipv4_address,
			'Y',
			'N',
			parent_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		RETURN netblock_rec;
	END IF;
	IF address_type = 'netblock' THEN
		IF parent_rec.can_subnet = 'N' THEN
			RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
				USING ERRCODE = 'JH10B';
		END IF;

		SELECT netblock_utils.find_free_netblock(
			parent_netblock_id := parent_rec.netblock_id,
			netmask_bits := netmask_bits,
			single_address := false,
			allocate_from_bottom := allocate_from_bottom) INTO inet_rec;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'No valid netblocks found to allocate'
			USING ERRCODE = 'JH110';
		END IF;

		INSERT INTO netblock (
			ip_address,
			netmask_bits,
			netblock_type,
			is_ipv4_address,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec,
			masklen(inet_rec),
			parent_rec.netblock_type,
			parent_rec.is_ipv4_address,
			'N',
			CASE WHEN can_subnet THEN 'Y' ELSE 'N' END,
			parent_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		RETURN netblock_rec;
	END IF;
END;
$$ LANGUAGE plpgsql;

GRANT USAGE ON SCHEMA netblock_manip TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA netblock_manip TO iud_role;
