/*
 * Copyright (c) 2012-2014 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

CREATE OR REPLACE FUNCTION dns_rec_before() 
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		PERFORM 1 FROM dns_domain WHERE dns_domain_id IN (
		    OLD.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id)
		)
		FOR UPDATE;

		RETURN OLD;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.netblock_id IS NOT NULL THEN
			PERFORM 1 FROM dns_domain WHERE dns_domain_id IN (
		    	NEW.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
			) FOR UPDATE;
		END IF;

		RETURN NEW;
	ELSE
		IF OLD.netblock_id IS DISTINCT FROM NEW.netblock_id THEN
			IF OLD.netblock_id IS NOT NULL THEN
				PERFORM 1 FROM dns_domain WHERE dns_domain_id IN (
			    	OLD.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id))
				FOR UPDATE;
			END IF;
			IF NEW.netblock_id IS NOT NULL THEN
				PERFORM 1 FROM dns_domain WHERE dns_domain_id IN (
			    	NEW.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
				)
				FOR UPDATE;
			END IF;
		ELSE
			IF NEW.netblock_id IS NOT NULL THEN
				PERFORM 1 FROM dns_domain WHERE dns_domain_id IN (
			    	NEW.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
				) FOR UPDATE;
			END IF;
		END IF;

		RETURN NEW;
	END IF;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_rec_before ON dns_record;
CREATE TRIGGER trigger_dns_rec_before 
	BEFORE INSERT OR DELETE OR UPDATE 
	ON dns_record 
	FOR EACH ROW
	EXECUTE PROCEDURE dns_rec_before();

CREATE OR REPLACE FUNCTION update_dns_zone() 
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
		UPDATE dns_domain SET zone_last_updated = clock_timestamp()
            WHERE dns_domain_id = NEW.dns_domain_id
			AND ( zone_last_updated < last_generated
			OR zone_last_updated is NULL);

		IF TG_OP = 'UPDATE' THEN
			IF OLD.dns_domain_id != NEW.dns_domain_id THEN
				UPDATE dns_domain SET zone_last_updated = clock_timestamp()
					 WHERE dns_domain_id = OLD.dns_domain_id
					 AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
			END IF;
			IF NEW.netblock_id != OLD.netblock_id THEN
				UPDATE dns_domain SET zone_last_updated = clock_timestamp()
					 WHERE dns_domain_id in (
						 netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id),
						 netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
					)
				     AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
			END IF;
		ELSIF TG_OP = 'INSERT' AND NEW.netblock_id is not NULL THEN
			UPDATE dns_domain SET zone_last_updated = clock_timestamp()
				WHERE dns_domain_id = 
					netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
				AND ( zone_last_updated < last_generated or zone_last_updated is NULL );

		END IF;
	END IF;

    IF TG_OP = 'DELETE' THEN
        UPDATE dns_domain SET zone_last_updated = clock_timestamp()
			WHERE dns_domain_id = OLD.dns_domain_id
			AND ( zone_last_updated < last_generated or zone_last_updated is NULL );

		IF OLD.dns_type = 'A' OR OLD.dns_type = 'AAAA' THEN
			UPDATE dns_domain SET zone_last_updated = clock_timestamp()
                 WHERE  dns_domain_id = netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id)
				 AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
        END IF;
    END IF;
	RETURN NEW;
END;
$$ 
LANGUAGE plpgsql 
SET search_path=jazzhands
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_dns_zone ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_update_dns_zone 
	AFTER INSERT OR DELETE OR UPDATE 
	ON dns_record 
	INITIALLY DEFERRED
	FOR EACH ROW 
	EXECUTE PROCEDURE update_dns_zone();

---------------------------------------------------------------------------

--
-- This shall replace all the aforementioned triggers
--

CREATE OR REPLACE FUNCTION dns_record_update_nontime() 
RETURNS TRIGGER AS $$
DECLARE
	_dnsdomainid	DNS_DOMAIN.DNS_DOMAIN_ID%type;
	_ipaddr			NETBLOCK.IP_ADDRESS%type;
	_mkold			boolean;
	_mknew			boolean;
	_mkdom			boolean;
	_mkip			boolean;
BEGIN
	_mkold = false;
	_mkold = false;
	_mknew = true;

	IF TG_OP = 'DELETE' THEN
		_mknew := false;
		_mkold := true;
		_mkdom := true;
		if  OLD.netblock_id is not null  THEN
			_mkip := true;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		_mkold := false;
		_mkdom := true;
		if  NEW.netblock_id is not null  THEN
			_mkip := true;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.DNS_DOMAIN_ID != NEW.DNS_DOMAIN_ID THEN
			_mkold := true;
		END IF;
		_mkdom := true;

		IF (OLD.NETBLOCK_ID is NULL and NEW.NETBLOCK_ID is not NULL )
				OR (OLD.NETBLOCK_ID IS NOT NULL and NEW.NETBLOCK_ID is NULL)
				OR (OLD.NETBLOCK_ID IS NOT NULL and NEW.NETBLOCK_ID IS NOT NULL
					AND OLD.NETBLOCK_ID != NEW.NETBLOCK_ID) THEN
			_mkold := true;
			_mknew := true;
			_mkip := true;
		END IF;
	END IF;
				
	if _mkold THEN
		IF _mkdom THEN
			_dnsdomainid := OLD.dns_domain_id;
		ELSE
			_dnsdomainid := NULL;
		END IF;
		if _mkip and OLD.netblock_id is not NULL THEN
			SELECT	ip_address 
			  INTO	_ipaddr 
			  FROM	netblock 
			 WHERE	netblock_id  = OLD.netblock_id;
		ELSE
			_ipaddr := NULL;
		END IF;
		insert into DNS_CHANGE_RECORD
			(dns_domain_id, ip_address) VALUES (_dnsdomainid, _ipaddr);
	END IF;
	if _mknew THEN
		if _mkdom THEN
			_dnsdomainid := NEW.dns_domain_id;
		ELSE
			_dnsdomainid := NULL;
		END IF;
		if _mkip and NEW.netblock_id is not NULL THEN
			SELECT	ip_address 
			  INTO	_ipaddr 
			  FROM	netblock 
			 WHERE	netblock_id  = NEW.netblock_id;
		ELSE
			_ipaddr := NULL;
		END IF;
		insert into DNS_CHANGE_RECORD
			(dns_domain_id, ip_address) VALUES (_dnsdomainid, _ipaddr);
	END IF;
	IF TG_OP = 'DELETE' THEN
		return OLD;
	END IF;
	return NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_record_update_nontime ON dns_record;
CREATE TRIGGER trigger_dns_record_update_nontime 
	AFTER INSERT OR UPDATE OR DELETE
	ON dns_record 
	FOR EACH ROW 
	EXECUTE PROCEDURE dns_record_update_nontime();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dns_a_rec_validation() RETURNS TRIGGER AS $$
DECLARE
	_ip		netblock.ip_address%type;
BEGIN
	IF NEW.dns_type in ('A', 'AAAA') AND NEW.netblock_id IS NULL THEN
		RAISE EXCEPTION 'Attempt to set % record without a Netblock',
			NEW.dns_type
			USING ERRCODE = 'not_null_violation';
	END IF;

	IF NEW.netblock_Id is not NULL and 
			( NEW.dns_value IS NOT NULL OR NEW.dns_value_record_id IS NOT NULL ) THEN
		RAISE EXCEPTION 'Both dns_value and netblock_id may not be set'
			USING ERRCODE = 'JH001';
	END IF;

	IF NEW.dns_value IS NOT NULL AND NEW.dns_value_record_id IS NOT NULL THEN
		RAISE EXCEPTION 'Both dns_value and dns_value_record_id may not be set'
			USING ERRCODE = 'JH001';
	END IF;

	IF NEW.netblock_id IS NOT NULL AND NEW.dns_value_record_id IS NOT NULL THEN
		RAISE EXCEPTION 'Both netblock_id and dns_value_record_id may not be set'
			USING ERRCODE = 'JH001';
	END IF;

	-- XXX need to deal with changing a netblock type and breaking dns_record.. 
	IF NEW.netblock_id IS NOT NULL THEN
		SELECT ip_address 
		  INTO _ip 
		  FROM netblock
		 WHERE netblock_id = NEW.netblock_id;

		IF NEW.dns_type = 'A' AND family(_ip) != '4' THEN
			RAISE EXCEPTION 'A records must be assigned to non-IPv4 records'
				USING ERRCODE = 'JH200';
		END IF;

		IF NEW.dns_type = 'AAAA' AND family(_ip) != '6' THEN
			RAISE EXCEPTION 'AAAA records must be assigned to non-IPv6 records'
				USING ERRCODE = 'JH200';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_a_rec_validation ON dns_record;
CREATE TRIGGER trigger_dns_a_rec_validation 
	BEFORE INSERT OR UPDATE 
	ON dns_record 
	FOR EACH ROW 
	EXECUTE PROCEDURE dns_a_rec_validation();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_non_a_rec_validation() RETURNS TRIGGER AS $$
DECLARE
	_ip		netblock.ip_address%type;
BEGIN
	IF NEW.dns_type NOT in ('A', 'AAAA', 'REVERSE_ZONE_BLOCK_PTR') AND NEW.dns_value IS NULL THEN
		RAISE EXCEPTION 'Attempt to set % record without a value',
			NEW.dns_type
			USING ERRCODE = 'not_null_violation';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_non_a_rec_validation ON dns_record;
CREATE TRIGGER trigger_dns_non_a_rec_validation 
	BEFORE INSERT OR UPDATE 
	ON dns_record 
	FOR EACH ROW 
	EXECUTE PROCEDURE dns_non_a_rec_validation();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dns_rec_prevent_dups() 
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	-- should not be able to insert the same record(s) twice
	SELECT	count(*)
	  INTO	_tally
	  FROM	dns_record
	  WHERE
	  		( dns_name = NEW.dns_name OR 
				(DNS_name IS NULL AND NEW.dns_name is NULL)
			)
		AND
	  		( dns_domain_id = NEW.dns_domain_id )
		AND
	  		( dns_class = NEW.dns_class )
		AND
	  		( dns_type = NEW.dns_type )
		AND 
	  		( dns_srv_service = NEW.dns_srv_service OR 
				(dns_srv_service IS NULL and NEW.dns_srv_service is NULL)
			)
		AND 
	  		( dns_srv_protocol = NEW.dns_srv_protocol OR 
				(dns_srv_protocol IS NULL and NEW.dns_srv_protocol is NULL)
			)
		AND 
	  		( dns_srv_port = NEW.dns_srv_port OR 
				(dns_srv_port IS NULL and NEW.dns_srv_port is NULL)
			)
		AND 
	  		( dns_value = NEW.dns_value OR 
				(dns_value IS NULL and NEW.dns_value is NULL)
			)
		AND
	  		( netblock_id = NEW.netblock_id OR 
				(netblock_id IS NULL AND NEW.netblock_id is NULL)
			)
		AND	is_enabled = 'Y'
	    AND dns_record_id != NEW.dns_record_id
	;

	IF _tally != 0 THEN
		RAISE EXCEPTION 'Attempt to insert the same dns record'
			USING ERRCODE = 'unique_violation';
	END IF;

	IF NEW.DNS_TYPE = 'A' OR NEW.DNS_TYPE = 'AAAA' THEN
		IF NEW.SHOULD_GENERATE_PTR = 'Y' THEN
			SELECT	count(*)
			 INTO	_tally
			 FROM	dns_record
			WHERE dns_class = 'IN' 
			AND dns_type = 'A' 
			AND should_generate_ptr = 'Y'
			AND is_enabled = 'Y'
			AND netblock_id = NEW.NETBLOCK_ID
			AND dns_record_id != NEW.DNS_RECORD_ID;
	
			IF _tally != 0 THEN
				RAISE EXCEPTION 'May not have more than one SHOULD_GENERATE_PTR record on the same IP on netblock_id %', NEW.netblock_id
					USING ERRCODE = 'JH201';
			END IF;
		END IF;
	END IF;

	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_rec_prevent_dups ON dns_record;
CREATE TRIGGER trigger_dns_rec_prevent_dups 
	BEFORE INSERT OR UPDATE 
	ON dns_record 
	FOR EACH ROW 
	EXECUTE PROCEDURE dns_rec_prevent_dups();
---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_domain_trigger_change()
RETURNS TRIGGER AS $$
BEGIN
	IF new.SHOULD_GENERATE = 'Y' THEN
		insert into DNS_CHANGE_RECORD
			(dns_domain_id) VALUES (NEW.dns_domain_id);
	END IF;	
	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_trigger_change ON dns_domain;
CREATE TRIGGER trigger_dns_domain_trigger_change 
	AFTER INSERT OR UPDATE OF soa_name, soa_class, soa_ttl, 
		soa_refresh, soa_retry, soa_expire, soa_minimum, soa_mname,
		soa_rname, should_generate
	ON dns_domain 
	FOR EACH ROW
	EXECUTE PROCEDURE dns_domain_trigger_change();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_change_record_pgnotify()
RETURNS TRIGGER AS $$
BEGIN
	NOTIFY dns_zone_gen;
	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_change_record_pgnotify ON dns_change_record;
CREATE TRIGGER trigger_dns_change_record_pgnotify 
	AFTER INSERT OR UPDATE 
	ON dns_change_record 
	EXECUTE PROCEDURE dns_change_record_pgnotify();
