-- Copyright (c) 2014 Todd Kover
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

-- $Id$


\set ON_ERROR_STOP

\t on

CREATE OR REPLACE FUNCTION validate_dns_triggers() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_dnsdomid		dns_domain.dns_domain_id%TYPE;
	_dnsdomkidid	dns_domain.dns_domain_id%TYPE;
	_dnsrecid1		dns_record.dns_record_id%TYPE;
	_dnsrecid2		dns_record.dns_record_id%TYPE;
	_blkid			netblock.netblock_id%TYPE;
	_ip1id			netblock.netblock_id%TYPE;
	_ip2id			netblock.netblock_id%TYPE;
	_ip3id			netblock.netblock_id%TYPE;
	_ip6blk			netblock.netblock_id%TYPE;
	_ip6id1			netblock.netblock_id%TYPE;
	_dnsrec			dns_record%ROWTYPE;
BEGIN
	RAISE NOTICE 'Cleanup Records from Previous Tests';
	delete from dns_record where dns_name like 'JHTEST%' 
		or dns_value like 'JHTEST%';
	delete from netblock where description like 'JHTEST%' 
		and is_single_address = 'Y';
	delete from netblock where description like 'JHTEST%';
	delete from dns_change_record;
	delete from dns_domain where soa_name = 'jhtest.example.com';

	RAISE NOTICE 'skip tests of dns_rec_before because it is going away';
	RAISE NOTICE 'skip tests of update_dns_zone because it is going away';

	RAISE NOTICE '++ Beginning tests of dns_record_update_nontime...';
	DELETE from dns_change_record;

	SELECT	count(*)
	 INTO	_tally
	 FROM	dns_change_record;

	-- This should never happen due to the earlier delete..
	IF _tally > 0 THEN
		RAISE 'DNS_CHANGE_RECORD has records.  This will confuse testing';
	END IF;

	RAISE NOTICE 'Inserting bootstrapping test records.';

	INSERT INTO DNS_DOMAIN (
		soa_name, soa_class, soa_ttl, soa_serial, soa_refresh, soa_retry,
		soa_expire, soa_minimum, soa_mname, soa_rname, should_generate,
		dns_domain_type
	) values (
		'jhtest.example.com', 'IN', 3600, 1, 600, 1800, 
		604800, 300, 'ns.example.com', 'hostmaster.example.com', 'Y',
		'service'
	) RETURNING dns_domain_id INTO _dnsdomid;

	INSERT INTO DNS_DOMAIN (
		soa_name, soa_class, soa_ttl, soa_serial, soa_refresh, soa_retry,
		soa_expire, soa_minimum, soa_mname, soa_rname, should_generate,
		dns_domain_type
	) values (
		'foo.example.com', 'IN', 3600, 1, 600, 1800, 
		604800, 300, 'ns.example.com', 'hostmaster.example.com', 'Y',
		'service'
	) RETURNING dns_domain_id INTO _dnsdomkidid;

	INSERT INTO NETBLOCK (ip_address, netmask_bits, netblock_type,
			is_ipv4_address, is_single_address, can_subnet, netblock_status,
			description
	) VALUES (
		'172.31.30.0/24', 24, 'default',
			'Y', 'N', 'N', 'Allocated',
			'JHTEST _blkid'
	) RETURNING netblock_id INTO _blkid;

	INSERT INTO NETBLOCK (ip_address, netmask_bits, netblock_type,
			is_ipv4_address, is_single_address, can_subnet, netblock_status,
			description
	) VALUES (
		'172.31.30.1/24', 24, 'default',
			'Y', 'Y', 'N', 'Allocated',
			'JHTEST _ip1id'
	) RETURNING netblock_id INTO _ip1id;

	INSERT INTO NETBLOCK (ip_address, netmask_bits, netblock_type,
			is_ipv4_address, is_single_address, can_subnet, netblock_status,
			description
	) VALUES (
		'172.31.30.2/24', 24, 'default',
			'Y', 'Y', 'N', 'Allocated',
			'JHTEST _ip2id'
	) RETURNING netblock_id INTO _ip2id;

	-- Insert IPv6 block
	INSERT INTO NETBLOCK (ip_address, netmask_bits, netblock_type,
			is_ipv4_address, is_single_address, can_subnet, netblock_status,
			description
	) VALUES (
		'fc00::/64', 64, 'default',
			'N', 'N', 'N', 'Allocated',
			'JHTEST _ip6id1'
	) RETURNING netblock_id INTO _ip6id1;

	-- Insert IPv6 block
	INSERT INTO NETBLOCK (ip_address, netmask_bits, netblock_type,
			is_ipv4_address, is_single_address, can_subnet, netblock_status,
			description
	) VALUES (
		'fc00::/64', 64, 'default',
			'N', 'Y', 'N', 'Allocated',
			'JHTEST _ip6id1'
	) RETURNING netblock_id INTO _ip6id1;

	INSERT INTO DNS_RECORD (
		dns_name, dns_domain_id, dns_class, dns_type, dns_value
	) VALUES (
		'JHTESTns1', _dnsdomid, 'IN', 'NS', 'ns1'
	) RETURNING dns_record_id INTO _dnsrecid1; 

	RAISE NOTICE 'Checking to see if non-netlock dns_change_record trigger does what it should';
	SELECT count(*) 
	  INTO _tally
	  FROM	dns_change_record
	 WHERE dns_domain_id = _dnsdomid
	   AND ip_address is NULL;

	IF _tally != 1 THEN
		RAISE EXCEPTION '% records with domain set and netblock null.  This is a problem',
			_tally;
		
	END IF;
	DELETE from dns_change_record;

	RAISE NOTICE 'Checking to see if second non-netlock dns_records trigger';
	INSERT INTO DNS_RECORD (
		dns_name, dns_domain_id, dns_class, dns_type, netblock_id,
		should_generate_ptr
	) VALUES (
		'JHTEST-A1', _dnsdomid, 'IN', 'A', _ip1id, 'Y'
	) RETURNING dns_record_id INTO _dnsrecid1; 

	SELECT count(*) 
	  INTO _tally
	  FROM dns_change_record
	 WHERE dns_domain_id = _dnsdomid
	   AND ip_address = '172.31.30.1/24';
	IF _tally != 1 THEN
		RAISE EXCEPTION '% records with domain and ip set to 172.31.30.1/24.  This is a problem',
			_tally;
		
	END IF;
	DELETE from dns_change_record;

	-- Note this one is both used immediately and later for a dup test.
	INSERT INTO DNS_RECORD (
		dns_name, dns_domain_id, dns_class, dns_type, netblock_id,
		should_generate_ptr
	) VALUES (
		'JHTEST-A1', _dnsdomid, 'IN', 'A', _ip2id, 'Y'
	) RETURNING dns_record_id INTO _dnsrecid1; 

	SELECT count(*) 
	  INTO _tally
	  FROM dns_change_record
	 WHERE dns_domain_id = _dnsdomid
	   AND ip_address = '172.31.30.2/24';
	IF _tally != 1 THEN
		RAISE EXCEPTION '% records with domain and ip set to 172.31.30.2/24.  This is a problem',
			_tally;
		
	END IF;
	DELETE from dns_change_record;

	RAISE NOTICE 'Deleting excess';
	delete from dns_record where netblock_id in (_ip1id, _ip2id);

	RAISE NOTICE '++ Ending tests of dns_record_update_nontime...';
	RAISE NOTICE '++ Beginning test of dns_a_rec_validation....';

	-- This should just work
	INSERT INTO DNS_RECORD (
		dns_name, dns_domain_id, dns_class, dns_type, netblock_id
	) VALUES (
		'JHTEST-A3', _dnsdomid, 'IN', 'A', _ip1id
	) RETURNING * INTO _dnsrec; 

	BEGIN
		INSERT INTO DNS_RECORD (
			dns_name, dns_domain_id, dns_class, dns_type, dns_value
		) VALUES (
			'JHTEST-A4', _dnsdomid, 'IN', 'A', 'JHTEST'
		) RETURNING * INTO _dnsrec; 
		RAISE EXCEPTION 'inserting an A record without a netblock did not fail';
	EXCEPTION WHEN not_null_violation THEN
		RAISE NOTICE 'inserting an A record without a netblock failed as expected';
	END;

	BEGIN
		INSERT INTO DNS_RECORD (
			dns_name, dns_domain_id, dns_class, dns_type, netblock_id
		) VALUES (
			'JHTEST-A5', _dnsdomid, 'IN', 'CNAME', _ip1id
		) RETURNING * INTO _dnsrec; 
		RAISE EXCEPTION 'inserting a CNAME record without a value did not fail';
	EXCEPTION WHEN not_null_violation THEN
		RAISE NOTICE 'inserting a CNAME record without a value failed as expected';
	END;

	BEGIN
		INSERT INTO DNS_RECORD (
			dns_name, dns_domain_id, dns_class, dns_type, netblock_id, dns_value
		) VALUES (
			'JHTEST-A6', _dnsdomid, 'IN', 'A', _ip6id1, 'JHTEST'
		) RETURNING * INTO _dnsrec; 
		RAISE NOTICE 'inserting a value and netblock id did not fail.';
	EXCEPTION WHEN SQLSTATE 'JH200' THEN
		RAISE NOTICE 'inserting a value and netblock id failed as expected';
	END;

	BEGIN
		INSERT INTO DNS_RECORD (
			dns_name, dns_domain_id, dns_class, dns_type, netblock_id, dns_value_record_id
		) VALUES (
			'JHTEST-A7', _dnsdomid, 'IN', 'A', _ip1id, _ip2id
		) RETURNING * INTO _dnsrec; 
		RAISE EXCEPTION 'inserting a netblock and value netblock_id did not fail';
	EXCEPTION WHEN SQLSTATE 'JH200' THEN
		RAISE NOTICE 'inserting a netblock and value netblock_id failed as expected';
	END;

	BEGIN
		INSERT INTO DNS_RECORD (
			dns_name, dns_domain_id, dns_class, dns_type, netblock_id
		) VALUES (
			'JHTEST-A8', _dnsdomid, 'IN', 'A', _ip6id1
		) RETURNING * INTO _dnsrec; 
		RAISE EXCEPTION 'inserting an A record with v6 netblock did not fail';
	EXCEPTION WHEN SQLSTATE 'JH201' THEN
		RAISE NOTICE 'inserting an A record with v6 netblock failed as expected';
	END;

	BEGIN
		INSERT INTO DNS_RECORD (
			dns_name, dns_domain_id, dns_class, dns_type, netblock_id
		) VALUES (
			'JHTEST-A9', _dnsdomid, 'IN', 'AAAA', _ip1id
	) RETURNING * INTO _dnsrec; 
		RAISE EXCEPTION 'inserting an A record with v4 netblock did not fail';
	EXCEPTION WHEN SQLSTATE 'JH201' THEN
		RAISE NOTICE 'inserting an A record with v4 netblock failed as expected';
	END;
	RAISE NOTICE '++ Ending test of dns_a_rec_validation....';

	RAISE NOTICE '++ Beginning test of dns_rec_prevent_dups....';

	BEGIN
		INSERT INTO DNS_RECORD (
			dns_name, dns_domain_id, dns_class, dns_type, netblock_id
		) VALUES (
			'JHTEST-A1alt', _dnsdomid, 'IN', 'A', _ip1id
		) RETURNING dns_record_id INTO _dnsrecid1; 
		RAISE EXCEPTION 'Inserting two PTR enabled records succeeded';
	EXCEPTION WHEN SQLSTATE 'JH202' THEN
		RAISE NOTICE 'Inserting two PTR enabled A records fails as expeceted';
	END;

	RAISE NOTICE 'Testing if switching a PTR record on fails';
	INSERT INTO DNS_RECORD (
		dns_name, dns_domain_id, dns_class, dns_type, netblock_id,
		should_generate_ptr
	) VALUES (
		'JHTEST-A2alt', _dnsdomid, 'IN', 'A', _ip1id, 'N'
	) RETURNING dns_record_id INTO _dnsrecid2; 

	RAISE NOTICE 'Checking if multi-PTR update fails..';
	BEGIN
		UPDATE dns_record 
		SET should_generate_ptr = 'Y' 
		WHERE dns_record_id = _dnsrecid2;
		RAISE EXCEPTION 'Updating to get two PTR enabled records succeeded';
	EXCEPTION WHEN SQLSTATE 'JH202' THEN
		RAISE NOTICE 'Updating to get two PTR enabled A records fails as expeceted';
	END;


	-- cleanup; note this must be run after the above
	delete from dns_record where dns_name like 'JHTEST%' 
		or dns_value like 'JHTEST%';

	INSERT INTO DNS_RECORD (
		dns_name, dns_domain_id, dns_class, dns_type, netblock_id
	) VALUES (
		'JHTEST-A1', _dnsdomid, 'IN', 'A', _ip1id
	) RETURNING dns_record_id INTO _dnsrecid1; 

	BEGIN
		INSERT INTO DNS_RECORD (
			dns_name, dns_domain_id, dns_class, dns_type, netblock_id
		) VALUES (
			'JHTEST-A1', _dnsdomid, 'IN', 'A', _ip1id
		) RETURNING dns_record_id INTO _dnsrecid1; 
		RAISE EXCEPTION 'Inserting the same A record did not fail';
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE 'Inserting the same A record failed as expected';
	END;

	UPDATE dns_record
	  SET	netblock_id = netblock_id
	WHERE	dns_record_id = _dnsrecid1;
	RAISE NOTICE 'Updating a netblock and setting it to itself worked.';

	UPDATE dns_record
	  SET	netblock_id = _ip2id
	WHERE	dns_record_id = _dnsrecid1;
	RAISE NOTICE 'Updating a netblock to a different IP worked';

	INSERT INTO DNS_RECORD (
		dns_name, dns_domain_id, dns_class, dns_type, dns_value
	) VALUES (
		'JHTEST-CNAME00', _dnsdomid, 'IN', 'CNAME', 'JHTEST-CNAMEVALUE'
	) RETURNING DNS_RECORD_ID into _dnsrecid1;

	BEGIN
		INSERT INTO DNS_RECORD (
			dns_name, dns_domain_id, dns_class, dns_type, dns_value
		) VALUES (
			'JHTEST-CNAME00', _dnsdomid, 'IN', 'CNAME', 'JHTEST-CNAMEVALUE'
		);
	EXCEPTION WHEN unique_violation THEN
		RAISE NOTICE 'Inserting the same CNAME record failed as expected';
	END;

	RAISE NOTICE 'Attempting to change a CNAME';
	UPDATE dns_record
	  SET	dns_value = 'JHTEST-CNAME2'
	WHERE	dns_record_id = _dnsrecid1;
	RAISE NOTICE 'Updating a dns_value and setting it to itself worked.';

	UPDATE dns_record
	  SET	dns_value = dns_value
	WHERE	dns_record_id = _dnsrecid1;
	RAISE NOTICE 'Updating a dns_value and setting it to itself worked.';

	RAISE NOTICE '++ Ending test of dns_rec_prevent_dups....';

	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT jazzhands.validate_dns_triggers();
-- set search_path=jazzhands;
DROP FUNCTION validate_dns_triggers();

\t off
