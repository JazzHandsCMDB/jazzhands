-- Copyright (c) 2014 Todd M. Kover
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
-- Test retirement triggers
--
\t on

--
-- This explicitly does not test validation, so it uses type dns.
--
CREATE FUNCTION validate_netblock_colretire() RETURNS BOOLEAN AS $$
DECLARE
	_nb		netblock%ROWTYPE;
BEGIN
	RAISE NOTICE 'Cleanup...';
	delete from netblock where description like 'JHTEST%';

	RAISE NOTICE 'Attempting to insert an IP address without legacy columns and see if they autopopulate...';
	INSERT INTO netblock ( 
		ip_address, is_single_address, can_subnet, netblock_status, 
		netblock_type, description
	) values (
		'10.42.42.1/26', true, false, 'Allocated',
		'dns', 'JHTEST netblock'
	) RETURNING * into _nb;

	RAISE NOTICE '.. Got %', _nb;

	RAISE NOTICE 'IS_IPV4_ADDRESS... ';
	IF _nb.IS_IPV4_ADDRESS != true THEN
		RAISE EXCEPTION '... was not set. %', _nb.IS_IPV4_ADDRESS;
	ELSE 
		RAISE NOTICE '... was set.';
	END IF;

	RAISE NOTICE 'NETMASK_BITS... ';
	IF _nb.NETMASK_BITS != masklen(_nb.IP_ADDRESS) THEN
		RAISE EXCEPTION '... was not set. % %', _nb.NETMASK_BITS,
			masklen(_nb.IP_ADDRESS);
	ELSE 
		RAISE NOTICE '... was set.';
	END IF;

	RAISE NOTICE 'host(ip_address) correctness... ';
	IF host(_nb.IP_ADDRESS) != '10.42.42.1' THEN
		RAISE EXCEPTION '... was not set.';
	ELSE 
		RAISE NOTICE '... was set.';
	END IF;

	RAISE NOTICE 'masklen(ip_address) correctness... ';
	IF masklen(_nb.IP_ADDRESS) != 26 THEN
		RAISE EXCEPTION '... was not set.';
	ELSE 
		RAISE NOTICE '... was set.';
	END IF;

	RAISE NOTICE 'Testing update to 192.168.41.6/27 ...';
	UPDATE netblock SET ip_address = '192.168.41.6/27'
		WHERE netblock_id = _nb.netblock_id;
	SELECT * into _nb FROM netblock WHERE netblock_id = _nb.netblock_id;

	RAISE NOTICE 'Update .. Got %', _nb;

	RAISE NOTICE 'IS_IPV4_ADDRESS... ';
	IF _nb.IS_IPV4_ADDRESS != true THEN
		RAISE EXCEPTION '... was not set. %', _nb.IS_IPV4_ADDRESS;
	ELSE 
		RAISE NOTICE '... was set.';
	END IF;

	RAISE NOTICE 'NETMASK_BITS... ';
	IF _nb.NETMASK_BITS != masklen(_nb.IP_ADDRESS) THEN
		RAISE EXCEPTION '... was not set. % %', _nb.NETMASK_BITS,
			masklen(_nb.IP_ADDRESS);
	ELSE 
		RAISE NOTICE '... was set.';
	END IF;

	RAISE NOTICE 'host(ip_address) correctness... ';
	IF host(_nb.IP_ADDRESS) != '192.168.41.6' THEN
		RAISE EXCEPTION '... was not set.';
	ELSE 
		RAISE NOTICE '... was set.';
	END IF;

	RAISE NOTICE 'masklen(ip_address) correctness... ';
	IF masklen(_nb.IP_ADDRESS) != 27 THEN
		RAISE EXCEPTION '... was not set.';
	ELSE 
		RAISE NOTICE '... was set.';
	END IF;

	RAISE NOTICE 'Testing update to fc00::dead:beef/55 ...';
	UPDATE netblock SET ip_address = 'fc00::dead:beef/55'
		WHERE netblock_id = _nb.netblock_id;
	SELECT * into _nb FROM netblock WHERE netblock_id = _nb.netblock_id;

	RAISE NOTICE 'Update .. Got %', _nb;

	RAISE NOTICE 'IS_IPV4_ADDRESS... ';
	IF _nb.IS_IPV4_ADDRESS != false THEN
		RAISE EXCEPTION '... was not set. %', _nb.IS_IPV4_ADDRESS;
	ELSE 
		RAISE NOTICE '... was set.';
	END IF;

	RAISE NOTICE 'NETMASK_BITS... ';
	IF _nb.NETMASK_BITS != masklen(_nb.IP_ADDRESS) THEN
		RAISE EXCEPTION '... was not set. % %', _nb.NETMASK_BITS,
			masklen(_nb.IP_ADDRESS);
	ELSE 
		RAISE NOTICE '... was set.';
	END IF;

	RAISE NOTICE 'host(ip_address) correctness... ';
	IF host(_nb.IP_ADDRESS) != 'fc00::dead:beef' THEN
		RAISE EXCEPTION '... was not set.';
	ELSE 
		RAISE NOTICE '... was set.';
	END IF;

	RAISE NOTICE 'masklen(ip_address) correctness... ';
	IF masklen(_nb.IP_ADDRESS) != 55 THEN
		RAISE EXCEPTION '... was not set.';
	ELSE 
		RAISE NOTICE '... was set.';
	END IF;

	RAISE NOTICE 'Testing if you ipv4 address and is_ipv4_address can mismatch...';
	BEGIN
		INSERT INTO netblock ( 
			ip_address, is_ipv4_address, is_single_address, can_subnet, 
			netblock_status, 
			netblock_type, description
		) values (
			'10.41.90.1/26', false, true, false, 
			'Allocated',
			'dns', 'JHTEST netblock'
		) RETURNING * into _nb;
		RAISE EXCEPTION '.. IT CAN NOT.';
	EXCEPTION WHEN SQLSTATE 'JH0FF' THEN
		RAISE NOTICE '.. It can';
	END;

	RAISE NOTICE 'Testing if you ipv6 address and is_ipv4_address can mismatch...';
	BEGIN
		INSERT INTO netblock ( 
			ip_address, is_ipv4_address, is_single_address, can_subnet, 
			netblock_status, 
			netblock_type, description
		) values (
			'fc00::dead:beef:f00d:1/64', true, true, false, 
			'Allocated',
			'dns', 'JHTEST netblock'
		) RETURNING * into _nb;
		RAISE EXCEPTION '.. IT CAN NOT.';
	EXCEPTION WHEN SQLSTATE 'JH0FF' THEN
		RAISE NOTICE '.. It can';
	END;


	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT validate_netblock_colretire();
DROP FUNCTION validate_netblock_colretire();

\t off
