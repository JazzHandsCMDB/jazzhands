-- Copyright (c) 2012 Matthew Ragan
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

--
-- Test netblock triggers
--
\t on

CREATE FUNCTION validate_netblock_triggers() RETURNS BOOLEAN AS $$
DECLARE
	v_netblock_id			netblock.netblock_id%TYPE;
	v_parent_netblock_id	netblock.parent_netblock_id%TYPE;
	v_ip_universe_id		ip_universe.ip_universe_id%TYPE;
	a_netblock_list			integer[];
	a_ip_universe			integer[];
	netblock_rec			record;
	parent_netblock_rec		record;
BEGIN

--
-- Clean up just in case
--

	DELETE FROM netblock WHERE netblock_type IN 
		('JHTEST-auto', 'JHTEST-auto2', 'JHTEST-manual',
			'JHTEST-freeforall');
	DELETE FROM val_netblock_type WHERE netblock_type IN 
		('JHTEST-auto', 'JHTEST-auto2', 'JHTEST-manual',
		'JHTEST-freeforall');
	DELETE FROM ip_universe WHERE ip_universe_name IN
		('JHTEST-testuniverse', 'JHTEST-testuniverse2');

--
-- Set up val_netblock_type for test data
--
	RAISE NOTICE 'Creating test netblock types...';

	INSERT INTO val_netblock_type 
		( netblock_type, db_forced_hierarchy, is_validated_hierarchy )
	VALUES
		('JHTEST-auto', 'Y', 'Y');

	INSERT INTO val_netblock_type 
		( netblock_type, db_forced_hierarchy, is_validated_hierarchy )
	VALUES
		('JHTEST-auto2', 'Y', 'Y');

	INSERT INTO val_netblock_type 
		( netblock_type, db_forced_hierarchy, is_validated_hierarchy )
	VALUES
		('JHTEST-manual', 'Y', 'Y');

	INSERT INTO val_netblock_type 
		( netblock_type, db_forced_hierarchy, is_validated_hierarchy )
	VALUES
		('JHTEST-freeforall', 'Y', 'Y');

--
-- Set up a couple of test universes
--
	RAISE NOTICE 'Creating test universes...';
	INSERT INTO ip_universe (ip_universe_name) VALUES ('testuniverse')
		RETURNING ip_universe_id INTO v_ip_universe_id;
	a_ip_universe[0] := v_ip_universe_id;
	INSERT INTO ip_universe (ip_universe_name) VALUES ('testuniverse')
		RETURNING ip_universe_id INTO v_ip_universe_id;
	a_ip_universe[1] := v_ip_universe_id;


--
--  Test netblock trigger
--


	--
	-- Force all queued triggers to fire
	--

	SET CONSTRAINTS trigger_validate_netblock_parentage IMMEDIATE;
	SET CONSTRAINTS trigger_validate_netblock_parentage DEFERRED;

	RAISE NOTICE 'Testing netblock triggers';

	RAISE NOTICE '    Inserting a netblock with NULL netblock_bits';
	BEGIN
		INSERT INTO netblock 
			(ip_address, netmask_bits, netblock_type, is_ipv4_address,
			 is_single_address, can_subnet, parent_netblock_id, netblock_status,
			 ip_universe_id)
		VALUES
			('172.31.0.0/16', NULL, 'JHTEST-freeforall', 'Y', 'N', 'Y', NULL,
				'Allocated', a_ip_universe[0]);
		RAISE '       SUCCEEDED -- THIS IS A PROBLEM' USING
			ERRCODE = 'error_in_assignment';
	EXCEPTION
		WHEN not_null_violation THEN
			RAISE NOTICE '        ... Failed correctly';
	END;

	RAISE NOTICE '    Inserting a netblock with can_subnet=Y and is_single_address=Y';
	BEGIN
		INSERT INTO netblock 
			(ip_address, netmask_bits, netblock_type, is_ipv4_address,
			 is_single_address, can_subnet, parent_netblock_id, netblock_status,
			 ip_universe_id)
		VALUES
			('172.31.0.1/16', 16, 'JHTEST-freeforall', 'Y', 'Y', 'Y', NULL,
				'Allocated', a_ip_universe[0]);
		RAISE '       SUCCEEDED -- THIS IS A PROBLEM' USING
			ERRCODE = 'error_in_assignment';
	EXCEPTION
		WHEN SQLSTATE '22106' THEN
			RAISE NOTICE '        ... Failed correctly';
	END;

	RAISE NOTICE '    Inserting a netblock with is_single_address=N with set non-network bits';
	BEGIN
		INSERT INTO netblock 
			(ip_address, netmask_bits, netblock_type, is_ipv4_address,
			 is_single_address, can_subnet, parent_netblock_id, netblock_status,
			 ip_universe_id)
		VALUES
			('172.31.0.1/16', 16, 'JHTEST-freeforall', 'Y', 'N', 'N', NULL,
				'Allocated', a_ip_universe[0]);
		RAISE '       SUCCEEDED -- THIS IS A PROBLEM' USING
			ERRCODE = 'error_in_assignment';
	EXCEPTION
		WHEN SQLSTATE '22103' THEN
			RAISE NOTICE '        ... Failed correctly';
	END;

	SET CONSTRAINTS trigger_validate_netblock_parentage IMMEDIATE;
	SET CONSTRAINTS trigger_validate_netblock_parentage DEFERRED;

--
-- Insert some new "root"s
--
	RAISE NOTICE '    Inserting JHTEST-auto top 172.31.0.0/16';
	INSERT INTO netblock 
		(ip_address, netmask_bits, netblock_type, is_ipv4_address,
		 is_single_address, can_subnet, parent_netblock_id, netblock_status,
		 ip_universe_id)
	VALUES
		('172.31.0.0/16', 16, 'JHTEST-auto', 'Y', 'N', 'Y', NULL,
			'Allocated', a_ip_universe[0])
		RETURNING netblock_id INTO v_netblock_id;
	a_netblock_list[0] = v_netblock_id;

	RAISE NOTICE '    Inserting JHTEST-auto top 172.31.0.0/16 to test unique constraint';
	BEGIN
		INSERT INTO netblock 
			(ip_address, netmask_bits, netblock_type, is_ipv4_address,
			 is_single_address, can_subnet, parent_netblock_id, netblock_status,
			 ip_universe_id)
		VALUES
			('172.31.0.0/16', 16, 'JHTEST-auto', 'Y', 'N', 'Y', NULL,
				'Allocated', a_ip_universe[0]);
	EXCEPTION
		WHEN unique_violation THEN
			RAISE NOTICE '        ... Failed correctly';
	END;

	RAISE NOTICE '    Inserting JHTEST-auto2 top 172.31.0.0/16';
	INSERT INTO netblock 
		(ip_address, netmask_bits, netblock_type, is_ipv4_address,
		 is_single_address, can_subnet, parent_netblock_id, netblock_status,
		 ip_universe_id)
	VALUES
		('172.31.0.0/16', 16, 'JHTEST-auto2', 'Y', 'N', 'Y', NULL,
			'Allocated', a_ip_universe[0]);

	RAISE NOTICE '    Inserting JHTEST-manual top 172.31.0.0/16';
	INSERT INTO netblock 
		(ip_address, netmask_bits, netblock_type, is_ipv4_address,
		 is_single_address, can_subnet, parent_netblock_id, netblock_status,
		 ip_universe_id)
	VALUES
		('172.31.0.0/16', 16, 'JHTEST-manual', 'Y', 'N', 'Y', NULL,
			'Allocated', a_ip_universe[0])
		RETURNING netblock_id INTO v_netblock_id;
	a_netblock_list[1] = v_netblock_id;

	RAISE NOTICE '    Inserting JHTEST-freeforall top 172.31.0.0/16';
	INSERT INTO netblock 
		(ip_address, netmask_bits, netblock_type, is_ipv4_address,
		 is_single_address, can_subnet, parent_netblock_id, netblock_status,
		 ip_universe_id)
	VALUES
		('172.31.0.0/16', 16, 'JHTEST-freeforall', 'Y', 'N', 'Y', NULL,
			'Allocated', a_ip_universe[0])
		RETURNING netblock_id INTO v_netblock_id;
	a_netblock_list[2] = v_netblock_id;


	SET CONSTRAINTS trigger_validate_netblock_parentage IMMEDIATE;
	SET CONSTRAINTS trigger_validate_netblock_parentage DEFERRED;
--
-- Insert some children of the auto-maintained type and validate that
-- Things should be what we think they should be
--

	RAISE NOTICE 'Validating parentage management...';
	RAISE NOTICE '    Inserting 172.31.1.0/24';
	INSERT INTO netblock 
		(ip_address, netmask_bits, netblock_type, is_ipv4_address,
		 is_single_address, can_subnet, parent_netblock_id, netblock_status,
		 ip_universe_id)
	VALUES
		('172.31.1.0/24', 24, 'JHTEST-auto', 'Y', 'N', 'Y', NULL,
			'Allocated', a_ip_universe[0])
		RETURNING * INTO netblock_rec;
	IF netblock_rec.parent_netblock_id = a_netblock_list[0] THEN
		RAISE NOTICE '        parent should be % and is', a_netblock_list[0];
	ELSE
		RAISE '        parent should be %, but is %', a_netblock_list[0],
			netblock_rec.parent_netblock_id;
	END IF;
	a_netblock_list[3] = netblock_rec.netblock_id;

	RAISE NOTICE '    Inserting 172.31.128.0/17';
	INSERT INTO netblock 
		(ip_address, netmask_bits, netblock_type, is_ipv4_address,
		 is_single_address, can_subnet, parent_netblock_id, netblock_status,
		 ip_universe_id)
	VALUES
		('172.31.128.0/17', 17, 'JHTEST-auto', 'Y', 'N', 'Y', NULL,
			'Allocated', a_ip_universe[0])
		RETURNING * INTO netblock_rec;
	IF netblock_rec.parent_netblock_id = a_netblock_list[0] THEN
		RAISE NOTICE '        parent should be % and is', a_netblock_list[0];
	ELSE
		RAISE '        parent should be %, but is %', a_netblock_list[0],
			netblock_rec.parent_netblock_id;
	END IF;
	a_netblock_list[4] = netblock_rec.netblock_id;


	RAISE NOTICE '    Inserting 172.31.0.0/22 between two netblocks';
	INSERT INTO netblock 
		(ip_address, netmask_bits, netblock_type, is_ipv4_address,
		 is_single_address, can_subnet, parent_netblock_id, netblock_status,
		 ip_universe_id)
	VALUES
		('172.31.0.0/22', 22, 'JHTEST-auto', 'Y', 'N', 'Y', NULL,
			'Allocated', a_ip_universe[0])
		RETURNING * INTO netblock_rec;
	IF netblock_rec.parent_netblock_id = a_netblock_list[0] THEN
		RAISE NOTICE '        parent should be and is %', a_netblock_list[0];
	ELSE
		RAISE '        parent should be %, but is %', a_netblock_list[0],
			netblock_rec.parent_netblock_id;
	END IF;
	a_netblock_list[5] = netblock_rec.netblock_id;

	SELECT parent_netblock_id INTO v_netblock_id FROM netblock WHERE
		netblock_id = a_netblock_list[3];

	IF v_netblock_id != a_netblock_list[5] THEN
		RAISE '        parent for 172.31.1.0/24 should now be %, but is %', 
			a_netblock_list[5],
			v_netblock_id;
	ELSE
		RAISE NOTICE '        parent for netblock % should now be and is %',
			a_netblock_list[3],
			a_netblock_list[5];
	END IF;


	SELECT parent_netblock_id INTO v_netblock_id FROM netblock WHERE
		netblock_id = a_netblock_list[4];

	IF v_netblock_id != a_netblock_list[0] THEN
		RAISE '        parent for 172.31.1.0/24 should still be %, but is %', 
			a_netblock_list[5],
			v_netblock_id;
	ELSE
		RAISE NOTICE '        parent for netblock % should still be and is %',
			a_netblock_list[4],
			a_netblock_list[0];
	END IF;

	SET CONSTRAINTS trigger_validate_netblock_parentage IMMEDIATE;
	SET CONSTRAINTS trigger_validate_netblock_parentage DEFERRED;

--
-- Insert a leaf record that does not have a corresponding container netblock
-- (i.e. is_single_address=Y without having the subnet block exist)
--

	RAISE NOTICE '    Inserting 172.31.16.1/24 that is a single address which will not have a matching parent';
	BEGIN
		INSERT INTO netblock 
			(ip_address, netmask_bits, netblock_type, is_ipv4_address,
			 is_single_address, can_subnet, parent_netblock_id, netblock_status,
			 ip_universe_id)
		VALUES
			('172.31.16.1/24', 22, 'JHTEST-auto', 'Y', 'Y', 'N', NULL,
				'Allocated', a_ip_universe[0]);
		SET CONSTRAINTS trigger_validate_netblock_parentage IMMEDIATE;
		SET CONSTRAINTS trigger_validate_netblock_parentage DEFERRED;
		RAISE '        INSERT ALLOWED - THIS IS A PROBLEM';
	EXCEPTION
		WHEN SQLSTATE '22105' THEN
			SET CONSTRAINTS trigger_validate_netblock_parentage DEFERRED;
			RAISE NOTICE '        insert failed correctly';
	END;

--
-- Insert a leaf record that does have a corresponding container netblock
-- (i.e. is_single_address=Y where the subnet block exists)
--

	RAISE NOTICE '    Inserting 172.31.1.1/24 that is a single address which will have a matching parent';
	INSERT INTO netblock 
		(ip_address, netmask_bits, netblock_type, is_ipv4_address,
		 is_single_address, can_subnet, parent_netblock_id, netblock_status,
		 ip_universe_id)
	VALUES
		('172.31.1.1/24', 24, 'JHTEST-auto', 'Y', 'Y', 'N', NULL,
			'Allocated', a_ip_universe[0])
	RETURNING * INTO netblock_rec;

	IF netblock_rec.parent_netblock_id = a_netblock_list[3] THEN
		RAISE NOTICE '        parent should be and is %', a_netblock_list[3];
	ELSE
		SELECT * INTO parent_netblock_rec FROM netblock WHERE 
			netblock_id = netblock_rec.parent_netblock_id;
		RAISE '        parent should be %, but is % (%)',
			a_netblock_list[3],
			netblock_rec.parent_netblock_id,
			parent_netblock_rec.ip_address
			;
	END IF;

	SET CONSTRAINTS trigger_validate_netblock_parentage IMMEDIATE;
	SET CONSTRAINTS trigger_validate_netblock_parentage DEFERRED;

--
-- Ensure that it's possible to change the netmask on a block, provided
-- that everything gets handled before the after trigger
--

	


--
-- Yay!  We're done!
--

	RAISE NOTICE 'ALL TESTS PASSED';
	SET CONSTRAINTS trigger_validate_netblock_parentage DEFERRED;
	--
	-- Clean up
	--

	RAISE NOTICE 'Cleaning up...';

	DELETE FROM netblock WHERE netblock_type IN 
		('JHTEST-auto', 'JHTEST-auto2', 'JHTEST-manual',
		'JHTEST-freeforall');
	DELETE FROM val_netblock_type WHERE netblock_type IN 
		('JHTEST-auto', 'JHTEST-auto2', 'JHTEST-manual',
		'JHTEST-freeforall');
	DELETE FROM ip_universe WHERE ip_universe_name IN
		('JHTEST-testuniverse', 'JHTEST-testuniverse2');


	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT validate_netblock_triggers();
DROP FUNCTION validate_netblock_triggers();

\t off
